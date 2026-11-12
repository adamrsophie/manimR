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
#' Reports which of the programs manimR uses are available: ffmpeg and
#' ffprobe (video output and video metadata), LaTeX and dvisvgm ([Tex()],
#' [MathTex()]), typst ([Typst()]) and Python with Pygments (highlighting
#' every language in [Code()]). This is `manim checkhealth`.
#'
#' @return A named logical vector, invisibly.
#' @export
manim_check <- function() {
  tools <- c(ffmpeg = cfg("ffmpeg") %||% "ffmpeg", ffprobe = "ffprobe", latex = "latex", dvisvgm = "dvisvgm",
             typst = cfg("typst") %||% "typst")
  paths <- Sys.which(path.expand(tools))
  ok <- nzchar(paths)
  names(ok) <- names(tools)
  for (i in seq_along(ok)) message(sprintf("%-9s %s", names(ok)[i], if (ok[i]) paths[[i]] else "NOT FOUND"))
  py <- pygments_python()
  message(sprintf("%-9s %s", "pygments", if (is.null(py)) "NOT FOUND (Code() highlights R and Python only)" else py))
  invisible(c(ok, pygments = !is.null(py)))
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

# A frame as png::writePNG() takes it: native rasters as they are, RGBA
# arrays scaled to [0, 1].
frame_to_png_array <- function(frame) {
  if (inherits(frame, "nativeRaster") || max(frame) <= 1) frame else frame / 255
}

# The audio codec for sound in a WebM video: Vorbis when ffmpeg has it,
# otherwise Opus, as upstream's _webm_audio_codec().
webm_audio_codec <- function() {
  if (is.null(.manim$webm_audio_codec)) {
    enc <- suppressWarnings(system2(ffmpeg_path(), c("-hide_banner", "-encoders"), stdout = TRUE, stderr = TRUE))
    .manim$webm_audio_codec <- if (any(grepl("\\blibvorbis\\b", enc))) "libvorbis" else "libopus"
  }
  .manim$webm_audio_codec
}

frame_bytes <- function(frame) {
  attributes(frame) <- NULL
  writeBin(frame, raw(), size = 4, endian = "little")
}

#' @rdname CairoRenderer
#' @export
SceneFileWriterClass <- R6::R6Class("SceneFileWriter", lock_objects = FALSE,
  public = list(
    settings = NULL,
    output_spec = NULL,
    output_plan = NULL,
    video_encoder = NULL,
    con = NULL,
    partial_path = NULL,
    frame_count = 0,
    sounds = NULL,
    sections = NULL,
    partial_movie_files = NULL,
    subcaptions = NULL,
    final_file_path = NULL,
    includes_sound = FALSE,
    # `settings` comes from the scene: the resolved output plan, the video
    # encoder of the segments, and the cache and asset settings (upstream's
    # _SceneFileWriterSettings).
    initialize = function(settings) {
      self$settings <- settings
      self$output_plan <- settings$plan
      self$output_spec <- settings$plan$output
      self$video_encoder <- settings$video_encoder
      if (isTRUE(self$output_spec$is_video) != !is.null(self$video_encoder)) {
        stop("Video output and resolved video encoder settings must be provided together.", call. = FALSE)
      }
      self$sounds <- list()
      self$sections <- list()
      self$partial_movie_files <- list()
      self$subcaptions <- list()
      self$init_audio()
      if (isTRUE(cfg("flush_cache")) && self$output_spec$is_video) self$flush_cache_directory()
      # The first section is created automatically, as upstream does.
      self$next_section("autocreated", DefaultSectionType$NORMAL, FALSE)
    },
    # The ffmpeg arguments that encode raw RGBA frames into `out`: the
    # segment encoder for video segments.
    output_command = function(out) {
      enc <- self$video_encoder
      c("-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgba",
        "-s", paste0(enc$width, "x", enc$height), "-r", frame_rate_arg(enc$frame_rate), "-i", "-", "-an",
        video_encoder_args(enc), "-f", if (enc$container_format == "mov") "mov" else enc$container_format, out)
    },
    open_pipe = function(path) {
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      pipe(paste(shQuote(ffmpeg_path()), paste(shQuote(self$output_command(path)), collapse = " ")), open = "wb")
    },

    # Sections (manim.scene.section) ------------------------------------------
    finish_last_section = function() {
      k <- length(self$sections)
      if (k && self$sections[[k]]$is_empty()) self$sections[[k]] <- NULL
      invisible(self)
    },
    next_section = function(name = "unnamed", type_ = DefaultSectionType$NORMAL, skip_animations = FALSE) {
      self$finish_last_section()
      # Images have no sections; the section video path is relative to the
      # section index file.
      video <- NULL
      if (isTRUE(self$output_spec$save_sections) && !skip_animations) {
        video <- basename(plan_section_path(self$output_plan, length(self$sections), name))
      }
      self$sections[[length(self$sections) + 1]] <- SectionClass$new(type_, video, name, skip_animations)
      invisible(self)
    },
    current_section = function() self$sections[[length(self$sections)]],

    # Partial movie files, one per play (upstream's segment cache) ------------
    # `hash_animation` names the file; NULL marks a play that is not rendered.
    add_partial_movie_file = function(hash_animation) {
      if (!self$output_spec$is_video) return(invisible(self))
      path <- if (is.null(hash_animation)) NULL else plan_segment_path(self$output_plan, hash_animation)
      self$partial_movie_files[length(self$partial_movie_files) + 1] <- list(path)
      sec <- self$current_section()
      sec$partial_movie_files[length(sec$partial_movie_files) + 1] <- list(path)
      invisible(self)
    },
    is_already_cached = function(hash_invocation) {
      if (!self$output_spec$is_video) return(FALSE)
      path <- plan_segment_path(self$output_plan, hash_invocation)
      if (!file.exists(path)) return(FALSE)
      modify_atime(path)
      TRUE
    },
    begin_animation = function(allow_write = FALSE, animation_index = NULL, file_path = NULL) {
      if (self$output_spec$is_video && allow_write) {
        self$open_partial_movie_stream(animation_index = animation_index, file_path = file_path)
      }
      invisible(self)
    },
    end_animation = function(allow_write = FALSE) {
      if (self$output_spec$is_video && allow_write) self$close_partial_movie_stream()
      invisible(self)
    },
    open_partial_movie_stream = function(animation_index = NULL, file_path = NULL) {
      if (!is.null(self$con)) stop("Cannot open a video segment while another segment is still open.", call. = FALSE)
      if (is.null(file_path)) {
        idx <- if (is.null(animation_index)) length(self$partial_movie_files) else animation_index + 1
        file_path <- if (idx >= 1 && idx <= length(self$partial_movie_files)) self$partial_movie_files[[idx]]
        if (is.null(file_path)) {
          stop("open_partial_movie_stream() called for a play that has no partial movie file path.", call. = FALSE)
        }
      }
      self$partial_path <- file_path
      self$con <- self$open_pipe(paste0(file_path, ".part", self$output_plan$segment_extension))
      invisible(self)
    },
    close_partial_movie_stream = function() {
      if (is.null(self$con)) {
        stop("close_partial_movie_stream() called without an open partial movie stream.", call. = FALSE)
      }
      status <- close(self$con)
      self$con <- NULL
      part <- paste0(self$partial_path, ".part", self$output_plan$segment_extension)
      if (!is.null(status) && status != 0) {
        unlink(part)
        stop("ffmpeg exited with status ", status, call. = FALSE)
      }
      # Renamed only once complete, so an interrupted render never leaves a
      # truncated file in the cache.
      file.rename(part, self$partial_path)
      invisible(self)
    },
    # Segments are encoded in this process while frames are written, so there
    # are no background jobs to wait for (max_inflight_encoders and
    # encoder_queue_size only bound upstream's encoder threads); aborting
    # drops the segment being written.
    join_all_encode_jobs = function() invisible(self),
    abort_encode_jobs = function(reraise_encoder_failures = FALSE) {
      if (!is.null(self$con)) {
        try(close(self$con), silent = TRUE)
        self$con <- NULL
        unlink(paste0(self$partial_path, ".part", self$output_plan$segment_extension))
        logger$info("Discarded partial movie file of aborted animation")
      }
      invisible(self)
    },
    # Writes `pixels` (a frame from the renderer) `repeat` times: to the open
    # segment for video output, as numbered PNG files for a PNG sequence.
    write_frame = function(pixels, `repeat` = 1) {
      if (`repeat` < 1) return(invisible(self))
      if (self$output_spec$is_video && !is.null(self$con)) {
        bytes <- frame_bytes(pixels)
        for (i in seq_len(`repeat`)) writeBin(bytes, self$con)
      }
      if (self$output_spec$is_image_sequence) {
        for (i in seq_len(`repeat`)) self$output_image(pixels)
      }
      invisible(self)
    },
    output_image = function(image) {
      path <- plan_image_frame_path(self$output_plan, self$frame_count)
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      png::writePNG(frame_to_png_array(image), path)
      self$frame_count <- self$frame_count + 1
      invisible(path)
    },
    save_image = function(pixels) {
      if (!self$output_spec$enabled) return(invisible(NULL))
      path <- self$image_file_path
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      png::writePNG(frame_to_png_array(pixels), path)
      self$print_file_ready_message(path)
      invisible(path)
    },
    # Ends the scene: the partial movie files become the movie (and the
    # section videos); an image sequence is already written.
    finish = function() {
      if (self$output_spec$is_video) {
        self$join_all_encode_jobs()
        self$combine_to_movie()
        if (self$output_spec$save_sections) self$combine_to_section_videos()
        self$clean_cache()
      } else if (self$output_spec$is_image_sequence) {
        self$final_file_path <- self$image_sequence_directory
        logger$info("%d images ready at %s", self$frame_count, self$image_sequence_directory)
      }
      if (length(self$subcaptions)) self$write_subcaption_file()
      invisible(self$final_file_path)
    },
    # The ffmpeg concat list of `input_files`, as upstream's concat manifest.
    concat_manifest_lines = function(input_files) {
      c("# This file records the segment order used by Manim.",
        sprintf("file 'file:%s'", gsub("'", "'\\\\''", normalizePath(unlist(input_files), winslash = "/"))))
    },
    write_concat_manifest = function(input_files) {
      path <- self$output_plan$concat_manifest
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      tmp <- tempfile(paste0(".", basename(path), "."), tmpdir = dirname(path), fileext = ".tmp")
      writeLines(self$concat_manifest_lines(input_files), tmp)
      file.rename(tmp, path)
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
      writeLines(self$concat_manifest_lines(input_files), list_file)
      codec <- if (create_gif) {
        palette <- if (self$output_spec$transparent) "palettegen=stats_mode=diff:reserve_transparent=1" else "palettegen=stats_mode=diff"
        c("-vf", paste0("split[s0][s1];[s0]", palette, "[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle"),
          "-loop", "0")
      } else {
        c("-c", "copy", if (self$output_spec$format == "mp4") c("-movflags", "+faststart"))
      }
      args <- c("-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", list_file, if (!includes_sound) "-an",
                codec, "-metadata", paste0("comment=Rendered with manimR v", utils::packageVersion("manimR")),
                output_file)
      status <- system2(ffmpeg_path(), shQuote(args))
      if (status != 0) stop("Combining partial movie files failed (ffmpeg status ", status, ")", call. = FALSE)
      invisible(output_file)
    },
    combine_to_movie = function() {
      files <- Filter(Negate(is.null), self$partial_movie_files)
      if (!length(files)) {
        logger$info("No animations are contained in this scene.")
        return(invisible(NULL))
      }
      logger$info("Combining to Movie file.")
      self$write_concat_manifest(files)
      path <- self$movie_file_path
      self$combine_files(files, path, create_gif = self$output_spec$is_gif)
      if (self$includes_sound && !self$output_spec$is_gif) self$mux_sounds()
      self$print_file_ready_message(path)
      invisible(path)
    },
    combine_to_section_videos = function() {
      self$finish_last_section()
      saved <- Filter(function(s) !is.null(s$video) && length(s$get_clean_partial_movie_files()), self$sections)
      if (!length(saved)) return(invisible(NULL))
      dir <- self$sections_output_dir
      entries <- vapply(saved, function(s) {
        self$combine_files(s$get_clean_partial_movie_files(), file.path(dir, s$video),
                           create_gif = self$output_spec$is_gif)
        json_object(s$get_dict(dir))
      }, "")
      index <- self$output_plan$section_index
      writeLines(c("[", paste(entries, collapse = ",\n"), "]"), index)
      invisible(index)
    },
    # Keeps at most `max_files_cached` partial movie files (-1 keeps all),
    # dropping the least recently used (upstream's prune_segment_cache()).
    clean_cache = function() {
      dir <- self$partial_movie_directory
      ext <- self$output_plan$segment_extension
      files <- list.files(dir, pattern = paste0("\\", ext, "$"), full.names = TRUE)
      files <- files[!grepl("\\.part\\.", files)]
      keep <- self$settings$max_files_cached %||% 100
      if (keep >= 0 && length(files) > keep) {
        atimes <- file.info(files)$atime
        unlink(files[order(atimes)][seq_len(length(files) - keep)])
      }
      invisible(self)
    },
    flush_cache_directory = function() {
      unlink(list.files(self$partial_movie_directory, full.names = TRUE))
      invisible(self)
    },
    print_file_ready_message = function(file_path) {
      self$final_file_path <- file_path
      logger$info("File ready at '%s'", file_path)
      invisible(self)
    },
    write_subcaption_file = function() {
      path <- self$output_plan$subcaption_file
      if (is.null(path)) return(invisible(NULL))
      write_srt(self$subcaptions, path)
      invisible(path)
    },
    add_sound = function(sound_file, time = NULL, gain = NULL, gain_to_background = NULL) {
      path <- if (file.exists(sound_file)) sound_file else get_full_sound_file_path(sound_file)
      self$add_audio_segment(path, time, gain_to_background)
      self$sounds[[length(self$sounds)]]$gain <- gain
      invisible(self)
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
      acodec <- if (self$output_spec$format == "webm") webm_audio_codec() else "aac"
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
    }
  ),
  active = list(
    # Upstream's output paths, from the output plan.
    output_name = function() self$output_plan$output_stem,
    image_file_path = function() {
      plan <- self$output_plan
      path <- if (self$output_spec$is_image_sequence) with_suffix(plan$image_sequence_dir, ".png")
        else if (self$output_spec$is_still) plan$primary_artifact else plan$fallback_image
      if (is.null(path)) stop("This output plan does not contain an image path.", call. = FALSE)
      path
    },
    image_sequence_directory = function() {
      path <- self$output_plan$image_sequence_dir
      if (is.null(path)) stop("This output plan does not contain an image sequence.", call. = FALSE)
      path
    },
    movie_file_path = function() {
      if (!self$output_spec$is_video || is.null(self$output_plan$primary_artifact)) {
        stop("This output plan does not contain a video artifact.", call. = FALSE)
      }
      self$output_plan$primary_artifact
    },
    gif_file_path = function() {
      if (!self$output_spec$is_gif) stop("This output plan does not contain a GIF artifact.", call. = FALSE)
      self$movie_file_path
    },
    sections_output_dir = function() self$output_plan$sections_dir %||% "",
    partial_movie_directory = function() {
      path <- self$output_plan$segment_cache_dir
      if (is.null(path)) stop("This output plan does not contain video segments.", call. = FALSE)
      path
    }
  )
)

#' @rdname CairoRenderer
#' @export
SceneFileWriter <- constructor(SceneFileWriterClass)
