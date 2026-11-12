# Scene file writer: streams raw RGBA frames to ffmpeg.
# Ported in spirit from manim/scene/scene_file_writer.py.

ffmpeg_path <- function() {
  p <- cfg("ffmpeg") %||% "ffmpeg"
  found <- Sys.which(p)
  if (!nzchar(found)) stop("ffmpeg was not found. Install it or set manim_config(ffmpeg = '/path/to/ffmpeg').", call. = FALSE)
  unname(found)
}

#' Check system requirements
#'
#' Reports whether ffmpeg, LaTeX and dvisvgm are available.
#'
#' @return A named logical vector, invisibly.
#' @export
manim_check <- function() {
  tools <- c(ffmpeg = cfg("ffmpeg") %||% "ffmpeg", latex = "latex", dvisvgm = "dvisvgm")
  ok <- nzchar(Sys.which(tools))
  names(ok) <- names(tools)
  for (i in seq_along(ok)) message(sprintf("%-8s %s", names(ok)[i], if (ok[i]) Sys.which(tools[i]) else "NOT FOUND"))
  invisible(ok)
}

# Section file name component, as manim's _slugify_section_name().
section_slug <- function(name) {
  slug <- gsub("^[-_]+|[-_]+$", "", gsub("(*UCP)[^\\w]+", "-", enc2utf8(name), perl = TRUE))
  if (nzchar(slug)) slug else "section"
}

json_string <- function(x) {
  x <- gsub("\\\\", "\\\\\\\\", as.character(x))
  x <- gsub("\"", "\\\\\"", x)
  x <- gsub("\n", "\\\\n", x)
  x <- gsub("\t", "\\\\t", x)
  x <- gsub("\r", "\\\\r", x)
  paste0("\"", x, "\"")
}

# Duration in seconds of an audio or video file, read from ffmpeg's report.
media_duration <- function(path) {
  out <- suppressWarnings(system2(ffmpeg_path(), c("-hide_banner", "-i", shQuote(path)), stdout = TRUE, stderr = TRUE))
  hit <- regmatches(out, regexpr("Duration: [0-9]+:[0-9]+:[0-9.]+", out))
  if (!length(hit)) stop("Could not read the duration of ", path, call. = FALSE)
  p <- as.numeric(strsplit(sub("Duration: ", "", hit[1]), ":")[[1]])
  p[1] * 3600 + p[2] * 60 + p[3]
}

frame_bytes <- function(frame) {
  attributes(frame) <- NULL
  writeBin(frame, raw(), size = 4, endian = "little")
}

#' @rdname CairoRenderer
#' @export
SceneFileWriterClass <- R6::R6Class("SceneFileWriter", lock_objects = FALSE,
  public = list(
    scene_name = NULL,
    module_name = NULL,
    movie_file_path = NULL,
    image_file_path = NULL,
    con = NULL,
    frames_written = 0,
    width = NULL,
    height = NULL,
    fps = NULL,
    format = NULL,
    sounds = NULL,
    sections = NULL,
    partial_movie_files = NULL,
    partial_path = NULL,
    frame_count = 0,
    subcaptions = NULL,
    final_file_path = NULL,
    includes_sound = FALSE,
    initialize = function(scene_name, module_name = NULL, width, height, fps, output_file = NULL) {
      self$scene_name <- scene_name
      self$module_name <- module_name %||% "manimR"
      self$width <- width
      self$height <- height
      self$fps <- fps
      self$sounds <- list()
      media <- cfg("media_dir") %||% "media"
      out <- output_file %||% cfg("output_file")
      has_out <- !is.null(out) && nzchar(out)
      out_ext <- if (has_out) tolower(tools::file_ext(out)) else ""
      fmt <- cfg("format") %||% "mp4"
      # A movie extension on output_file chooses the format, so the file
      # always matches its name.
      if (out_ext %in% c("mp4", "mov", "webm", "gif")) fmt <- out_ext
      if (isTRUE(cfg("transparent")) && fmt == "mp4") {
        if (out_ext == "mp4") message("Transparent video needs a .mov file; writing ", sub("\\.mp4$", ".mov", out, ignore.case = TRUE))
        fmt <- "mov"
      }
      self$format <- fmt
      ext <- if (fmt == "png") "" else paste0(".", fmt)
      if (has_out) {
        # The movie and the last frame image share the output stem, so
        # `-s -o poster.png` writes poster.png.
        stem <- if (out_ext %in% c("mp4", "mov", "webm", "gif", "png")) tools::file_path_sans_ext(out) else out
        self$movie_file_path <- paste0(stem, ext)
        self$image_file_path <- paste0(stem, ".png")
      } else {
        vdir <- file.path(media, "videos", self$module_name, quality_dir_name())
        self$movie_file_path <- file.path(vdir, paste0(scene_name, ext))
        self$image_file_path <- file.path(media, "images", self$module_name, paste0(scene_name, ".png"))
      }
      self$sections <- list()
      self$partial_movie_files <- list()
      self$subcaptions <- list()
      self$init_audio()
      if (isTRUE(cfg("flush_cache"))) self$flush_cache_directory()
      # The first section is created automatically, as upstream does.
      self$next_section("autocreated", "default.normal", FALSE)
    },
    # The ffmpeg arguments that encode raw RGBA frames into `out` in `fmt`.
    # GIFs are assembled from lossless QuickTime partial files.
    output_command = function(out = self$movie_file_path, fmt = self$format) {
      common <- c("-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgba",
                  "-s", paste0(self$width, "x", self$height), "-r", as.character(self$fps), "-i", "-", "-an")
      c(common, self$codec_args(fmt), out)
    },
    codec_args = function(fmt) {
      transparent <- isTRUE(cfg("transparent"))
      switch(fmt,
        mp4 = c("-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18"),
        mov = if (transparent) c("-c:v", "qtrle", "-pix_fmt", "argb") else c("-c:v", "libx264", "-pix_fmt", "yuv420p"),
        webm = c("-c:v", "libvpx-vp9", "-pix_fmt", if (transparent) "yuva420p" else "yuv420p", "-b:v", "0", "-crf", "30"),
        qtrle = c("-c:v", "qtrle", "-pix_fmt", "argb"),
        stop("Unsupported format: ", fmt, call. = FALSE)
      )
    },
    open_pipe = function(path, fmt = self$format) {
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      args <- self$output_command(path, fmt)
      pipe(paste(shQuote(ffmpeg_path()), paste(shQuote(args), collapse = " ")), open = "wb")
    },

    # Paths (upstream's OutputPlan) ------------------------------------------
    output_name = function() tools::file_path_sans_ext(basename(self$movie_file_path)),
    gif_file_path = function() paste0(tools::file_path_sans_ext(self$movie_file_path), ".gif"),
    image_sequence_directory = function() self$movie_file_path,
    partial_movie_directory = function() file.path(dirname(self$movie_file_path), "partial_movie_files", self$scene_name),
    sections_output_dir = function() self$sections_dir(),
    # Partial movie files keep the movie's format, except GIFs, whose pieces
    # are lossless QuickTime files.
    partial_extension = function() if (self$format == "gif") ".mov" else paste0(".", self$format),
    partial_format = function() if (self$format == "gif") "qtrle" else self$format,

    # Partial movie files, one per play (upstream's segment cache) ------------
    # `hash` names the file; NULL marks a play that is not rendered.
    add_partial_movie_file = function(hash) {
      if (self$format == "png") return(invisible(self))
      path <- if (is.null(hash)) NULL else file.path(self$partial_movie_directory(), paste0(hash, self$partial_extension()))
      self$partial_movie_files[length(self$partial_movie_files) + 1] <- list(path)
      sec <- self$current_section()
      sec$partial_movie_files[length(sec$partial_movie_files) + 1] <- list(path)
      invisible(self)
    },
    is_already_cached = function(hash) {
      path <- file.path(self$partial_movie_directory(), paste0(hash, self$partial_extension()))
      if (!file.exists(path)) return(FALSE)
      modify_atime(path)
      TRUE
    },
    begin_animation = function(allow_write = FALSE, file_path = NULL) {
      if (allow_write && isTRUE(cfg("write_to_movie"))) self$open_partial_movie_stream(file_path)
      invisible(self)
    },
    end_animation = function(allow_write = FALSE) {
      if (allow_write) self$close_partial_movie_stream()
      invisible(self)
    },
    open_partial_movie_stream = function(file_path = NULL) {
      if (self$format == "png") return(invisible(self))
      self$close_partial_movie_stream()
      file_path <- file_path %||% self$partial_movie_files[[length(self$partial_movie_files)]]
      if (is.null(file_path)) return(invisible(self))
      self$partial_path <- file_path
      self$con <- self$open_pipe(paste0(file_path, ".part", self$partial_extension()), self$partial_format())
      invisible(self)
    },
    close_partial_movie_stream = function() {
      if (is.null(self$con)) return(invisible(self))
      status <- close(self$con)
      self$con <- NULL
      part <- paste0(self$partial_path, ".part", self$partial_extension())
      if (!is.null(status) && status != 0) {
        unlink(part)
        stop("ffmpeg exited with status ", status, call. = FALSE)
      }
      # Renamed only once complete, so an interrupted render never leaves a
      # truncated file in the cache.
      file.rename(part, self$partial_path)
      invisible(self)
    },
    # Encoding happens in this process, so there are no background jobs to
    # wait for; aborting drops the partial file being written.
    join_all_encode_jobs = function() invisible(self),
    abort_encode_jobs = function(reraise_encoder_failures = FALSE) {
      if (!is.null(self$con)) {
        try(close(self$con), silent = TRUE)
        self$con <- NULL
        unlink(paste0(self$partial_path, ".part", self$partial_extension()))
      }
      invisible(self)
    },
    write_frame = function(frame, num_frames = 1) {
      if (num_frames < 1) return(invisible(self))
      if (self$format == "png") {
        for (i in seq_len(num_frames)) self$output_image(frame, self$image_sequence_directory())
        self$frames_written <- self$frames_written + num_frames
        return(invisible(self))
      }
      if (is.null(self$con)) self$open_partial_movie_stream()
      if (is.null(self$con)) return(invisible(self))
      bytes <- frame_bytes(frame)
      for (i in seq_len(num_frames)) writeBin(bytes, self$con)
      self$frames_written <- self$frames_written + num_frames
      invisible(self)
    },
    # Writes one frame of an image sequence as <scene><number>.png.
    output_image = function(image, target_dir, ext = ".png", zero_pad = 4) {
      dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
      self$frame_count <- self$frame_count + 1
      path <- file.path(target_dir, sprintf(paste0("%s%0", zero_pad, "d%s"), self$scene_name, self$frame_count - 1, ext))
      img <- if (inherits(image, "nativeRaster")) native_raster_to_array(image) / 255 else image
      png::writePNG(img, path)
      invisible(path)
    },
    # Concatenates partial movie files into `output_file` (as a GIF when
    # `create_gif`), with ffmpeg's concat demuxer.
    combine_files = function(input_files, output_file, create_gif = FALSE, includes_sound = FALSE) {
      input_files <- unlist(input_files)
      if (!length(input_files)) return(invisible(NULL))
      dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
      list_file <- tempfile(fileext = ".txt")
      on.exit(unlink(list_file), add = TRUE)
      writeLines(sprintf("file '%s'", gsub("'", "'\\\\''", normalizePath(input_files))), list_file)
      codec <- if (create_gif) {
        c("-vf", "split[s0][s1];[s0]palettegen=reserve_transparent=1[p];[s1][p]paletteuse", "-loop", "0")
      } else {
        c("-c", "copy", if (self$format == "mp4") c("-movflags", "+faststart"))
      }
      args <- c("-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", list_file, codec, output_file)
      status <- system2(ffmpeg_path(), shQuote(args))
      if (status != 0) stop("Combining partial movie files failed (ffmpeg status ", status, ")", call. = FALSE)
      invisible(output_file)
    },
    combine_to_movie = function() {
      files <- Filter(Negate(is.null), self$partial_movie_files)
      if (!length(files)) return(invisible(NULL))
      self$combine_files(files, self$movie_file_path, create_gif = self$format == "gif")
      if (length(self$sounds) && self$format %in% c("mp4", "mov", "webm")) self$mux_sounds()
      self$print_file_ready_message(self$movie_file_path)
      invisible(self$movie_file_path)
    },
    combine_to_section_videos = function() {
      self$finish_last_section()
      saved <- Filter(function(s) !is.null(s$video) && length(s$get_clean_partial_movie_files()), self$sections)
      if (!length(saved)) return(invisible(NULL))
      entries <- vapply(saved, function(s) {
        path <- file.path(self$sections_dir(), s$video)
        self$combine_files(s$get_clean_partial_movie_files(), path, create_gif = self$format == "gif")
        json_object(s$get_dict(self$sections_dir()))
      }, "")
      index <- file.path(self$sections_dir(), paste0(self$output_name(), ".json"))
      writeLines(c("[", paste(entries, collapse = ",\n"), "]"), index)
      invisible(index)
    },
    # Keeps at most `max_files_cached` partial movie files, dropping the
    # least recently used (upstream's clean_cache()).
    clean_cache = function() {
      dir <- self$partial_movie_directory()
      files <- list.files(dir, pattern = paste0("\\", self$partial_extension(), "$"), full.names = TRUE)
      files <- files[!grepl("\\.part\\.", files)]
      keep <- cfg("max_files_cached") %||% 100
      if (keep >= 0 && length(files) > keep) {
        atimes <- file.info(files)$atime
        unlink(files[order(atimes)][seq_len(length(files) - keep)])
      }
      invisible(self)
    },
    flush_cache_directory = function() {
      unlink(list.files(self$partial_movie_directory(), full.names = TRUE))
      invisible(self)
    },
    print_file_ready_message = function(file_path) {
      self$final_file_path <- file_path
      logger$info("File ready at '%s'", file_path)
      invisible(self)
    },
    write_subcaption_file = function() {
      if (!length(self$subcaptions) || self$format == "png") return(invisible(NULL))
      path <- sub("\\.[A-Za-z0-9]+$", ".srt", self$movie_file_path)
      write_srt(self$subcaptions, path)
      invisible(path)
    },

    # Sections (manim.scene.section) ------------------------------------------
    sections_dir = function() file.path(dirname(self$movie_file_path), "sections"),
    current_section = function() self$sections[[length(self$sections)]],
    next_section = function(name = "unnamed", type = "default.normal", skip_animations = FALSE) {
      self$finish_last_section()
      video <- NULL
      if (isTRUE(cfg("save_sections")) && !skip_animations && self$format != "png") {
        video <- sprintf("%s_%04d_%s.%s", self$output_name(), length(self$sections), section_slug(name), self$format)
      }
      self$sections[[length(self$sections) + 1]] <- SectionClass$new(type, video, name, skip_animations)
      invisible(self)
    },
    finish_last_section = function() {
      k <- length(self$sections)
      if (k && self$sections[[k]]$is_empty()) self$sections[[k]] <- NULL
      invisible(self)
    },
    add_sound = function(sound_file, time_offset = 0, gain = NULL, gain_to_background = NULL) {
      path <- if (file.exists(sound_file)) sound_file else get_full_sound_file_path(sound_file)
      self$add_audio_segment(path, time_offset, gain_to_background)
      self$sounds[[length(self$sounds)]]$gain <- gain
      invisible(self)
    },
    # Ends the scene: the partial movie files become the movie (and the
    # section videos), or the image sequence is already written.
    finish = function() {
      self$close_partial_movie_stream()
      if (self$format == "png") {
        if (self$frames_written == 0) return(invisible(NULL))
        self$print_file_ready_message(self$image_sequence_directory())
        return(invisible(self$movie_file_path))
      }
      out <- self$combine_to_movie()
      if (is.null(out)) return(invisible(NULL))
      if (isTRUE(cfg("save_sections"))) self$combine_to_section_videos()
      self$write_subcaption_file()
      self$clean_cache()
      invisible(out)
    },
    has_output = function() {
      if (self$format == "png") return(self$frames_written > 0)
      length(Filter(Negate(is.null), self$partial_movie_files)) > 0
    },

    # Audio (upstream builds one pydub segment; manimR keeps the sounds and
    # mixes them with ffmpeg when the movie is combined) ---------------------
    init_audio = function() {
      self$includes_sound <- FALSE
      invisible(self)
    },
    create_audio_segment = function() {
      self$sounds <- list()
      invisible(self)
    },
    # Adds a sound file at `time` seconds (NULL: after the last sound ends).
    add_audio_segment = function(new_segment, time = NULL, gain_to_background = NULL) {
      if (!self$includes_sound) {
        self$includes_sound <- TRUE
        self$create_audio_segment()
      }
      if (is.null(time)) {
        ends <- vapply(self$sounds, function(s) s$offset + media_duration(s$file), 0)
        time <- if (length(ends)) max(ends) else 0
      }
      if (time < 0) stop("Adding sound at timestamp < 0", call. = FALSE)
      self$sounds[[length(self$sounds) + 1]] <- list(file = normalizePath(new_segment), offset = time, gain = NULL,
                                                     gain_to_background = gain_to_background)
      invisible(self)
    },
    mux_sounds = function() {
      video <- self$movie_file_path
      tmp <- paste0(tools::file_path_sans_ext(video), "_nosound.", tools::file_ext(video))
      file.rename(video, tmp)
      inputs <- c("-i", tmp)
      filters <- character()
      # A sound with gain_to_background lowers every sound added before it
      # while it plays, like pydub's overlay(gain_during_overlay) upstream.
      ducks <- lapply(self$sounds, function(s) {
        if (is.null(s$gain_to_background)) return(NULL)
        c(s$offset, s$offset + media_duration(s$file), s$gain_to_background)
      })
      for (i in seq_along(self$sounds)) {
        s <- self$sounds[[i]]
        inputs <- c(inputs, "-i", s$file)
        delay <- round(s$offset * 1000)
        vol <- if (is.null(s$gain)) "" else sprintf(",volume=%sdB", s$gain)
        # Evaluated per sample (aeval), so the lowering starts and ends
        # exactly with the later sound.
        factors <- character()
        for (k in seq_along(ducks)) {
          d <- ducks[[k]]
          if (k > i && !is.null(d)) factors <- c(factors, sprintf("if(between(t,%.6f,%.6f),%.10g,1)", d[1], d[2], 10^(d[3] / 20)))
        }
        if (length(factors)) vol <- paste0(vol, sprintf(",aeval=exprs='val(ch)*%s':c=same", paste(factors, collapse = "*")))
        filters <- c(filters, sprintf("[%d:a]adelay=%d|%d%s[a%d]", i, delay, delay, vol, i))
      }
      # Silence pads the mix to the full video length, so a short sound never
      # cuts the movie; WebM needs Opus rather than AAC.
      mix <- paste0(paste0("[a", seq_along(self$sounds), "]", collapse = ""),
                    sprintf("amix=inputs=%d:normalize=0,apad[aout]", length(self$sounds)))
      acodec <- if (self$format == "webm") "libopus" else "aac"
      args <- c("-y", "-loglevel", "error", inputs, "-filter_complex", paste(c(filters, mix), collapse = ";"),
                "-map", "0:v", "-map", "[aout]", "-c:v", "copy", "-c:a", acodec,
                "-t", sprintf("%.6f", media_duration(tmp)), video)
      res <- system2(ffmpeg_path(), shQuote(args))
      if (res == 0) {
        unlink(tmp)
      } else {
        file.rename(tmp, video)
        warning("Adding sound failed (ffmpeg status ", res, "); the video was written without sound.", call. = FALSE)
      }
      invisible(video)
    },
    save_image = function(frame, path = NULL) {
      path <- path %||% self$image_file_path
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      png::writePNG(frame, path)
      invisible(path)
    }
  )
)

#' @rdname CairoRenderer
#' @export
SceneFileWriter <- constructor(SceneFileWriterClass)
