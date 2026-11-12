# The output of one render session, ported from manim/_config/output.py,
# render_session.py, video_encoder.py and output_plan.py: which artifact a
# render writes (format), how video segments are encoded, and the exact
# paths of every file.

OUTPUT_FORMATS <- c("none", "auto", "mp4", "webm", "mov", "gif", "png", "png-sequence")
VIDEO_FORMATS <- c("mp4", "webm", "mov", "gif")

# Normalizes a format setting as upstream's OutputFormat.parse(): NULL and ""
# mean "auto", case and underscores are ignored.
parse_output_format <- function(value) {
  if (is.null(value) || identical(value, "")) return("auto")
  if (!is.character(value) || length(value) != 1 || is.na(value)) {
    stop("Invalid output format: ", deparse(value), call. = FALSE)
  }
  fmt <- gsub("_", "-", tolower(value), fixed = TRUE)
  if (!fmt %in% OUTPUT_FORMATS) {
    stop("Invalid output format '", value, "'. Use one of: ", paste(OUTPUT_FORMATS, collapse = ", "), call. = FALSE)
  }
  fmt
}

# Upstream's OutputSpec: the validated output intent of one render.
output_spec <- function(format, transparent = FALSE, save_sections = FALSE, fallback_to_still = FALSE) {
  if (format == "auto") stop("An output specification needs a concrete format.", call. = FALSE)
  is_video <- format %in% VIDEO_FORMATS
  if (fallback_to_still && !is_video) stop("Still image fallback requires a video output format.", call. = FALSE)
  if (transparent && format == "mp4") {
    stop("MP4 output does not support an alpha channel. Use format = \"mov\" or format = \"webm\" ",
         "for transparent video.", call. = FALSE)
  }
  if (save_sections && !is_video) stop("Section output requires a video output format.", call. = FALSE)
  segment <- if (!is_video) NULL else if (format == "gif") (if (transparent) ".mov" else ".mp4") else paste0(".", format)
  list(format = format, transparent = transparent, save_sections = save_sections,
       fallback_to_still = fallback_to_still, enabled = format != "none", is_video = is_video,
       is_still = format == "png", is_image_sequence = format == "png-sequence", is_gif = format == "gif",
       artifact_extension = if (format == "none") NULL else if (format %in% c("png", "png-sequence")) ".png"
                            else paste0(".", format),
       segment_extension = segment)
}

# Upstream's RendererCapabilities: the optional session features a renderer
# implements.
RendererCapabilities <- function(live_preview = FALSE) list(live_preview = isTRUE(live_preview))

# Upstream's resolve_render_session(): output, presentation and encoder
# settings from the current configuration, checked against what the renderer
# can do. The Cairo style renderer has no live preview window (manimR's
# interactive window is scene$interactive_embed()).
resolve_render_session <- function(capabilities = RendererCapabilities(), renderer_name = "CairoRenderer") {
  live <- isTRUE(cfg("live_preview")) || isTRUE(cfg("enable_gui"))
  dry <- isTRUE(cfg("dry_run"))
  transparent <- isTRUE(cfg("transparent"))
  fmt <- parse_output_format(cfg("format"))
  fallback <- FALSE
  if (dry) {
    fmt <- "none"
    sections <- FALSE
  } else {
    sections <- isTRUE(cfg("save_sections"))
    if (fmt == "auto") {
      if (live) {
        fmt <- "none"
      } else {
        fmt <- if (transparent) "mov" else "mp4"
        fallback <- TRUE
      }
    }
  }
  output <- output_spec(fmt, transparent, sections, fallback)
  presentation <- list(open_after_render = isTRUE(cfg("preview")), live_preview = live,
                       show_in_file_browser = isTRUE(cfg("show_in_file_browser")))
  if (live && !isTRUE(capabilities$live_preview)) {
    stop(renderer_name, " does not support live preview. Use scene$interactive_embed() for an interactive ",
         "window, or remove live_preview.", call. = FALSE)
  }
  if (live && dry) stop("live_preview cannot be combined with dry_run.", call. = FALSE)
  if (live && output$is_still) stop("Live preview cannot be combined with last-frame PNG output.", call. = FALSE)
  if (presentation$open_after_render && !output$enabled) {
    stop("preview requires a media artifact; it cannot be combined with format = \"none\" or dry_run.", call. = FALSE)
  }
  if (presentation$show_in_file_browser && !output$enabled) {
    stop("show_in_file_browser requires a media artifact.", call. = FALSE)
  }
  encoder <- resolve_video_encoder(output, width = cfg("pixel_width"), height = cfg("pixel_height"),
                                   frame_rate = cfg("frame_rate"), codec = cfg("video_codec") %||% "auto",
                                   pixel_format = cfg("pixel_format") %||% "auto",
                                   options = cfg("video_encoder_options"))
  list(output = output, presentation = presentation, dry_run = dry, video_encoder = encoder)
}

# Video segment encoding ------------------------------------------------------

VIDEO_ENCODER_DEFAULT_OPTIONS <- list(libx264 = c(crf = "23"), `libvpx-vp9` = c(crf = "23"), qtrle = character())
VIDEO_ENCODER_CONFLICTING_OPTIONS <- c("codec", "codec_name", "framerate", "height", "pix_fmt", "pixel_format",
                                       "rate", "video_size", "width")
ALPHA_PIXEL_FORMATS <- "^(argb|rgba|abgr|bgra|ya8|ya16|yuva|gbrap|rgba64|bgra64|pal8)"

# A positive exact frame rate as c(numerator, denominator), as upstream's
# to_av_frame_rate(): whole numbers stay whole and NTSC rates become n/1001.
to_frame_rate <- function(frame_rate) {
  if (!is.numeric(frame_rate) || length(frame_rate) != 1 || !is.finite(frame_rate) || frame_rate <= 0) {
    stop("frame rate must be a positive finite number", call. = FALSE)
  }
  if (abs(frame_rate - round(frame_rate)) < 1e-4) return(c(round(frame_rate), 1))
  ntsc <- round(frame_rate * 1001 / 1000) * 1000
  if (abs(frame_rate - ntsc / 1001) < 0.02) return(c(ntsc, 1001))
  digits <- nchar(sub("^[^.]*\\.?", "", format(frame_rate, digits = 15, scientific = FALSE)))
  den <- 10^digits
  num <- round(frame_rate * den)
  g <- gcd(num, den)
  c(num / g, den / g)
}

gcd <- function(a, b) if (b == 0) a else gcd(b, a %% b)

# Upstream's resolve_video_encoder(): codec, pixel format and options of the
# cached video segments, or NULL when the output is not a video.
resolve_video_encoder <- function(output, width, height, frame_rate, codec = "auto", pixel_format = "auto",
                                  options = NULL) {
  if (!output$is_video) return(NULL)
  whole <- function(x) is.numeric(x) && length(x) == 1 && is.finite(x) && x > 0 && x == round(x)
  if (!whole(width) || !whole(height)) stop("Video dimensions must be positive integers.", call. = FALSE)
  rate <- to_frame_rate(frame_rate)
  container <- substring(output$segment_extension, 2)
  default <- if (output$segment_extension == ".webm") {
    c("libvpx-vp9", if (output$transparent) "yuva420p" else "yuv420p")
  } else if (output$transparent) {
    c("qtrle", "argb")
  } else {
    c("libx264", "yuv420p")
  }
  resolved_codec <- if (identical(codec, "auto")) default[1] else codec
  resolved_pix <- if (identical(pixel_format, "auto")) default[2] else pixel_format
  supplied <- if (is.null(options)) list() else as.list(options)
  if (length(supplied) && (is.null(names(supplied)) || any(!nzchar(names(supplied))) ||
                           !all(vapply(supplied, function(v) is.character(v) && length(v) == 1, NA)))) {
    stop("Video encoder options must be named strings.", call. = FALSE)
  }
  conflicting <- sort(intersect(names(supplied), VIDEO_ENCODER_CONFLICTING_OPTIONS))
  if (length(conflicting)) {
    stop("Video encoder options conflict with explicit stream settings: ", paste(conflicting, collapse = ", "),
         call. = FALSE)
  }
  opts <- if (resolved_codec == default[1]) VIDEO_ENCODER_DEFAULT_OPTIONS[[default[1]]] else character()
  for (nm in names(supplied)) opts[[nm]] <- supplied[[nm]]
  # 4:2:0 chroma subsampling needs even sizes; say so before ffmpeg fails.
  if (grepl("420", resolved_pix) && (width %% 2 != 0 || height %% 2 != 0)) {
    stop("The pixel format ", resolved_pix, " needs an even width and height; got ", width, " x ", height,
         ". Use even pixel_width and pixel_height, or another pixel_format.", call. = FALSE)
  }
  if (output$transparent && !grepl(ALPHA_PIXEL_FORMATS, resolved_pix)) {
    stop("Transparent output requires an alpha-bearing pixel format; got ", resolved_pix, ".", call. = FALSE)
  }
  if (length(opts)) opts <- opts[order(names(opts))]
  list(container_format = container, codec = resolved_codec, pixel_format = resolved_pix,
       width = as.integer(width), height = as.integer(height), frame_rate = rate, options = opts)
}

# The cache identity of the encoder settings: the SHA-256 of the same
# canonical JSON upstream's video_encoder_fingerprint() hashes.
video_encoder_fingerprint <- function(spec) {
  if (is.null(spec)) return("none")
  opts <- vapply(names(spec$options), function(n) {
    sprintf('{"name":%s,"value":%s}', json_string(n), json_string(spec$options[[n]]))
  }, "")
  payload <- sprintf(paste0('{"codec":%s,"container_format":%s,"frame_rate":{"denominator":%s,"numerator":%s},',
                            '"height":%d,"options":[%s],"pixel_format":%s,"schema":"manim-video-segment-v1",',
                            '"width":%d}'),
                     json_string(spec$codec), json_string(spec$container_format),
                     format(spec$frame_rate[2], scientific = FALSE), format(spec$frame_rate[1], scientific = FALSE),
                     spec$height, paste(opts, collapse = ","), json_string(spec$pixel_format), spec$width)
  digest::digest(enc2utf8(payload), algo = "sha256", serialize = FALSE)
}

# ffmpeg arguments that encode a segment with `spec`.
video_encoder_args <- function(spec) {
  opts <- unlist(lapply(names(spec$options), function(n) c(paste0("-", n), spec$options[[n]])))
  c("-c:v", spec$codec, "-pix_fmt", spec$pixel_format, opts)
}

frame_rate_arg <- function(rate) if (rate[2] == 1) format(rate[1], scientific = FALSE) else paste0(rate[1], "/", rate[2])

# Directories -------------------------------------------------------------

DIR_KEYS <- c("assets_dir", "media_dir", "video_dir", "sections_dir", "images_dir", "text_dir", "tex_dir",
              "log_dir", "input_file", "output_file", "partial_movie_dir")

#' Resolve a directory setting
#'
#' Directory settings may refer to each other and to values known only when
#' a scene renders, with `{name}` placeholders: the default `video_dir` is
#' `"{media_dir}/videos/{module_name}/{quality}"`. `get_dir()` fills them in,
#' as upstream's `config.get_dir()`; `quality` is always known (for example
#' `"480p15"`), other names come from `...`.
#'
#' @param key One of `"assets_dir"`, `"media_dir"`, `"video_dir"`,
#'   `"sections_dir"`, `"images_dir"`, `"text_dir"`, `"tex_dir"`, `"log_dir"`,
#'   `"partial_movie_dir"`, `"input_file"` or `"output_file"`.
#' @param ... Values for placeholders, such as `module_name = "scenes"` or
#'   `scene_name = "Intro"`.
#' @return The path, or `NULL` when the setting is empty.
#' @export
#' @examples
#' get_dir("tex_dir")
#' get_dir("video_dir", module_name = "scenes")
get_dir <- function(key, ...) {
  if (!is.character(key) || length(key) != 1 || !key %in% DIR_KEYS) {
    stop("must pass one of {media,video,images,text,tex,log}_dir or {input,output}_file", call. = FALSE)
  }
  values <- lapply(stats::setNames(DIR_KEYS, DIR_KEYS), function(k) cfg(k) %||% "")
  kwargs <- list(...)
  values[names(kwargs)] <- kwargs
  values$quality <- quality_dir_name()
  path <- as.character(cfg(key) %||% "")
  pattern <- "\\{([A-Za-z_][A-Za-z0-9_]*)\\}"
  for (round in seq_len(50)) {
    if (!grepl(pattern, path)) break
    names_used <- unique(regmatches(path, gregexpr(pattern, path))[[1]])
    for (ph in names_used) {
      nm <- substr(ph, 2, nchar(ph) - 1)
      if (is.null(values[[nm]])) {
        stop(key, " ", cfg(key), " requires the following keyword arguments: ", nm, call. = FALSE)
      }
      path <- gsub(ph, as.character(values[[nm]]), path, fixed = TRUE)
    }
  }
  if (!nzchar(path)) return(NULL)
  path
}

is_absolute_path <- function(path) grepl("^(/|~|[A-Za-z]:[/\\\\]|\\\\\\\\)", path)

# An absolute path without resolving symbolic links, as upstream's
# _absolute_lexical(): "." and ".." components are removed.
absolute_lexical <- function(path, working_directory = getwd()) {
  path <- path.expand(path)
  if (!is_absolute_path(path)) path <- file.path(working_directory, path)
  parts <- strsplit(gsub("\\\\", "/", path), "/", fixed = TRUE)[[1]]
  prefix <- parts[1]
  out <- character()
  for (p in parts[-1]) {
    if (p == "" || p == ".") next
    if (p == "..") {
      if (length(out)) out <- out[-length(out)]
    } else {
      out <- c(out, p)
    }
  }
  paste0(prefix, "/", paste(out, collapse = "/"))
}

required_dir <- function(key, module_name, scene_name, working_directory) {
  path <- get_dir(key, module_name = module_name, scene_name = scene_name)
  if (is.null(path)) stop(key, " must not be empty for the requested output.", call. = FALSE)
  absolute_lexical(path, working_directory)
}

# The module name the directory templates use: the stem of input_file, as
# upstream, or manimR's module_name setting for scenes rendered from R code
# ("manimR" by default).
resolve_module_name <- function() {
  input <- get_dir("input_file")
  if (!is.null(input) && nzchar(input)) return(tools::file_path_sans_ext(basename(input)))
  cfg("module_name") %||% "manimR"
}

# Upstream's resolve_media_layout(): the directories one output needs.
resolve_media_layout <- function(output, module_name, scene_name, working_directory = getwd()) {
  dir <- function(key) required_dir(key, module_name, scene_name, working_directory)
  zero_pad <- cfg("zero_pad") %||% 4
  if (!(zero_pad >= 0 && zero_pad <= 9)) stop("PNG zero padding must be between 0 and 9.", call. = FALSE)
  list(images_dir = if (output$is_still || output$is_image_sequence || output$fallback_to_still) dir("images_dir"),
       video_dir = if (output$is_video) dir("video_dir"),
       partial_movie_dir = if (output$is_video) dir("partial_movie_dir"),
       sections_dir = if (output$is_video && output$save_sections) dir("sections_dir"),
       log_dir = if (isTRUE(cfg("log_to_file"))) dir("log_dir"),
       zero_pad = as.integer(zero_pad))
}

# Python's Path.stem and Path.with_suffix().
path_stem <- function(path) sub("(.)\\.[^./]*$", "\\1", basename(path))
path_suffix <- function(path) {
  b <- basename(path)
  if (grepl("(.)\\.[^./]*$", b)) sub("^.*(\\.[^./]*)$", "\\1", b) else ""
}
with_suffix <- function(path, suffix) {
  base <- basename(path)
  stem <- if (nzchar(path_suffix(path))) sub("\\.[^./]*$", "", base) else base
  file.path(dirname(path), paste0(stem, suffix))
}

add_artifact_extension <- function(name, extension) {
  if (path_suffix(name) == extension) name else paste0(name, extension)
}

# Default names of last frame images and GIFs carry the version that made
# them, as upstream's "_ManimCE_v<version>".
versioned_path <- function(path) {
  file.path(dirname(path), paste0(path_stem(path), "_manimR_v", utils::packageVersion("manimR"), path_suffix(path)))
}

output_path <- function(root, name, extension) {
  name <- add_artifact_extension(name, extension)
  if (is_absolute_path(name)) name else file.path(root, name)
}

# Upstream's resolve_output_plan(): every artifact and cache path of one
# scene's output.
resolve_output_plan <- function(layout, output, scene_name, requested_output_name = NULL) {
  if (!nzchar(scene_name)) stop("A scene name is required for output planning.", call. = FALSE)
  name <- requested_output_name %||% scene_name
  if (basename(name) %in% c("", ".", "..")) stop("The requested output name must contain a filename.", call. = FALSE)
  plan <- list(output = output, primary_artifact = NULL, fallback_image = NULL, image_sequence_dir = NULL,
               segment_cache_dir = NULL, sections_dir = NULL, section_index = NULL, subcaption_file = NULL,
               concat_manifest = NULL, output_stem = path_stem(name), segment_extension = NULL,
               zero_pad = layout$zero_pad)
  if (output$format == "none") return(plan)
  default_name <- is.null(requested_output_name)
  png <- NULL
  if (output$is_still || output$is_image_sequence || output$fallback_to_still) {
    normalized <- output_path(layout$images_dir, name, ".png")
    png <- if (default_name) versioned_path(normalized) else normalized
  }
  if (output$is_still) {
    plan$primary_artifact <- png
    return(plan)
  }
  if (output$is_image_sequence) {
    seq_dir <- with_suffix(output_path(layout$images_dir, name, ".png"), "")
    plan$primary_artifact <- seq_dir
    plan$image_sequence_dir <- seq_dir
    return(plan)
  }
  primary <- output_path(layout$video_dir, name, output$artifact_extension)
  if (output$is_gif && default_name) primary <- versioned_path(primary)
  plan$primary_artifact <- primary
  # `[<-` with list() keeps fields whose value is NULL, as the dataclass does.
  plan["fallback_image"] <- list(if (output$fallback_to_still) png)
  plan["segment_cache_dir"] <- list(layout$partial_movie_dir)
  plan["sections_dir"] <- list(layout$sections_dir)
  plan["section_index"] <- list(if (!is.null(layout$sections_dir)) {
    file.path(layout$sections_dir, paste0(plan$output_stem, ".json"))
  })
  plan$subcaption_file <- with_suffix(primary, ".srt")
  plan$concat_manifest <- file.path(layout$partial_movie_dir, "partial_movie_file_list.txt")
  plan$segment_extension <- output$segment_extension
  plan
}

plan_image_frame_path <- function(plan, frame_index) {
  if (is.null(plan$image_sequence_dir)) stop("This output plan does not contain an image sequence.", call. = FALSE)
  file.path(plan$image_sequence_dir, sprintf(paste0("%0", plan$zero_pad, "d.png"), frame_index))
}

plan_segment_path <- function(plan, cache_key) {
  if (is.null(plan$segment_cache_dir)) stop("This output plan does not contain video segments.", call. = FALSE)
  if (!nzchar(cache_key) || basename(cache_key) != cache_key) {
    stop("A cache key must be a non-empty filename component.", call. = FALSE)
  }
  file.path(plan$segment_cache_dir, paste0(cache_key, plan$segment_extension))
}

plan_section_path <- function(plan, index, name) {
  if (is.null(plan$sections_dir)) stop("This output plan does not contain section output.", call. = FALSE)
  file.path(plan$sections_dir, sprintf("%s_%04d_%s%s", plan$output_stem, index, section_slug(name),
                                        plan$segment_extension))
}

resolve_file_log_path <- function(layout, module_name, scene_name) {
  if (is.null(layout$log_dir)) return(NULL)
  file.path(layout$log_dir, paste0(module_name, "_", scene_name, ".log"))
}

# Everything a scene's file writer needs, as upstream's
# _SceneFileWriterSettings.
scene_file_writer_settings <- function(plan, video_encoder, working_directory = getwd()) {
  inflight <- cfg("max_inflight_encoders") %||% 1
  queue <- cfg("encoder_queue_size") %||% 8
  cached <- cfg("max_files_cached") %||% 100
  if (inflight <= 0) stop("max_inflight_encoders must be positive.", call. = FALSE)
  if (queue <= 0) stop("encoder_queue_size must be positive.", call. = FALSE)
  if (cached < -1) stop("max_files_cached must be non-negative or -1.", call. = FALSE)
  assets <- get_dir("assets_dir") %||% working_directory
  list(plan = plan, video_encoder = video_encoder, max_inflight_encoders = inflight, encoder_queue_size = queue,
       max_files_cached = cached, assets_dir = absolute_lexical(assets, working_directory))
}

# Config files --------------------------------------------------------------

# Reads an INI style .cfg file into a list of sections, each a named
# character vector, as Python's configparser does for manim.cfg.
read_cfg_file <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  out <- list()
  section <- NULL
  last_key <- NULL
  for (ln in lines) {
    if (grepl("^\\s*([#;].*)?$", ln)) next
    if (grepl("^\\s*\\[.+\\]\\s*$", ln)) {
      section <- sub("^\\s*\\[(.+)\\]\\s*$", "\\1", ln)
      if (is.null(out[[section]])) out[[section]] <- list()
      last_key <- NULL
      next
    }
    if (grepl("^\\s+\\S", ln) && !is.null(last_key) && !is.null(section)) {
      out[[section]][[last_key]] <- paste(out[[section]][[last_key]], trimws(ln), sep = "\n")
      next
    }
    m <- regmatches(ln, regexec("^\\s*([^=:]+?)\\s*[=:]\\s*(.*?)\\s*$", ln))[[1]]
    if (!length(m) || is.null(section)) stop("Could not parse line in ", path, ": ", ln, call. = FALSE)
    key <- tolower(m[2])
    out[[section]][[key]] <- m[3]
    last_key <- key
  }
  # configparser's interpolation reads %% as a single %.
  lapply(out, function(sec) lapply(sec, gsub, pattern = "%%", replacement = "%", fixed = TRUE))
}

cfg_bool <- function(x) {
  v <- tolower(trimws(x))
  if (v %in% c("1", "yes", "true", "on")) return(TRUE)
  if (v %in% c("0", "no", "false", "off")) return(FALSE)
  stop("Not a boolean: ", x, call. = FALSE)
}

# Applies the settings of parsed .cfg sections, as upstream's
# ManimConfig.digest_parser() does for the keys a file sets.
digest_cfg <- function(parsed) {
  cli <- parsed[["CLI"]] %||% character()
  s <- list()
  bools <- c("notify_outdated_version", "write_all", "save_sections", "preview", "live_preview",
             "show_in_file_browser", "log_to_file", "disable_caching", "disable_caching_warning", "enable_gui",
             "fullscreen", "use_projection_fill_shaders", "use_projection_stroke_shaders", "enable_wireframe",
             "no_latex_cleanup", "dry_run", "transparent", "save_last_frame", "flush_cache")
  ints <- c("from_animation_number", "upto_animation_number", "max_files_cached", "max_inflight_encoders",
            "encoder_queue_size", "pixel_height", "pixel_width", "seed", "window_monitor", "zero_pad")
  strs <- c("assets_dir", "verbosity", "media_dir", "log_dir", "video_dir", "sections_dir", "images_dir",
            "text_dir", "tex_dir", "partial_movie_dir", "input_file", "output_file", "background_color", "renderer",
            "window_position", "preview_command", "format", "progress_bar", "tex_template_file", "quality")
  nums <- c("background_opacity", "frame_rate", "frame_height", "frame_width")
  for (k in names(cli)) {
    v <- cli[[k]]
    if (k %in% bools) {
      s[[k]] <- cfg_bool(v)
    } else if (k %in% ints) {
      if (nzchar(v)) s[[k]] <- as.integer(v)
    } else if (k %in% nums) {
      if (nzchar(v)) s[[k]] <- as.numeric(v)
    } else if (k %in% strs) {
      s[[k]] <- v
    } else if (k == "plugins") {
      s$plugins <- if (nzchar(v)) trimws(strsplit(v, ",", fixed = TRUE)[[1]]) else character()
    } else if (k %in% c("gui_location", "window_size")) {
      s[[k]] <- if (v == "default") v else as.integer(strsplit(v, "[;,-]")[[1]])
    } else if (k == "tex_template") {
      # Listed in upstream's default.cfg, which reads tex_template_file instead.
    } else {
      stop("Unknown setting '", k, "' in the [CLI] section.", call. = FALSE)
    }
  }
  enc <- parsed[["video_encoder"]]
  if (!is.null(enc)) {
    if (!is.null(enc[["codec"]])) s$video_codec <- enc[["codec"]]
    if (!is.null(enc[["pixel_format"]])) s$pixel_format <- enc[["pixel_format"]]
  }
  opts <- parsed[["video_encoder.options"]]
  if (length(opts)) s$video_encoder_options <- opts
  media <- parsed[["media"]]
  if (!is.null(media[["loglevel"]])) s$media_loglevel <- media[["loglevel"]]
  jup <- parsed[["jupyter"]]
  if (!is.null(jup[["media_embed"]]) && nzchar(jup[["media_embed"]])) s$media_embed <- cfg_bool(jup[["media_embed"]])
  if (!is.null(jup[["media_width"]])) s$media_width <- jup[["media_width"]]
  # The frame width follows the file's pixel size and frame height, on top of
  # the library defaults, as upstream's digest_parser() computes it.
  if (is.null(s$frame_width) && any(c("pixel_width", "pixel_height", "frame_height") %in% names(s))) {
    s$frame_width <- (s$frame_height %||% 8) * (s$pixel_width %||% 1920) / (s$pixel_height %||% 1080)
  }
  # The pixel size comes before the frame size, as upstream digests them.
  first <- intersect(c("quality", "pixel_width", "pixel_height"), names(s))
  if (length(first)) do.call(manim_config, s[first])
  rest <- s[setdiff(names(s), first)]
  if (length(rest)) do.call(manim_config, rest)
  invisible(s)
}

#' Read a manim.cfg file
#'
#' Applies the settings of a `.cfg` file written for Manim, the format of
#' upstream's `manim.cfg`: the `[CLI]` section holds settings such as
#' `quality`, `media_dir`, `background_color` or `format`, and the
#' `[video_encoder]`, `[video_encoder.options]`, `[media]` and `[jupyter]`
#' sections their counterparts. This is upstream's `config.digest_file()`,
#' also available as `config$digest_file()`.
#'
#' As upstream does on import, manimR reads two files when it is loaded, if
#' they exist: the user wide file and the folder wide `manim.cfg` of the
#' working directory, in that order. `config_file_paths()` gives the three
#' locations of upstream: the library wide `default.cfg` (shipped with
#' manimR, whose values are its built in defaults),
#' `~/.config/manim/manim.cfg` (on Windows
#' `~/AppData/Roaming/Manim/manim.cfg`) and `manim.cfg`. [manim_cli()] reads
#' the working directory's file again, or the one given with
#' `-c`/`--config_file`. [make_config_parser()] merges the three files.
#'
#' @param filename Path to the `.cfg` file.
#' @return `digest_config_file()` returns the settings applied, invisibly;
#'   `config_file_paths()` a named character vector.
#' @export
#' @examples
#' cfg_file <- tempfile(fileext = ".cfg")
#' writeLines(c("[CLI]", "frame_rate = 24", "background_color = WHITE"), cfg_file)
#' old <- manim_config()
#' digest_config_file(cfg_file)
#' config$frame_rate
#' do.call(manim_config, old[c("frame_rate", "background_color")])
digest_config_file <- function(filename) {
  if (!file.exists(filename) || dir.exists(filename)) {
    stop("Error: --config_file could not find a valid config file: ", filename, call. = FALSE)
  }
  digest_cfg(read_cfg_file(filename))
}

#' @rdname digest_config_file
#' @export
config_file_paths <- function() {
  user_wide <- if (.Platform$OS.type == "windows") {
    file.path(path.expand("~"), "AppData", "Roaming", "Manim", "manim.cfg")
  } else {
    file.path(path.expand("~"), ".config", "manim", "manim.cfg")
  }
  c(library_wide = system.file("default.cfg", package = "manimR", mustWork = TRUE), user_wide = user_wide,
    folder_wide = "manim.cfg")
}

# Applies the user wide and folder wide config files that exist, as
# upstream's make_config_parser() at import. The library wide file holds the
# defaults manimR is built with. A broken file gives a warning rather than
# stopping the package from loading.
digest_startup_config_files <- function() {
  for (path in config_file_paths()[c("user_wide", "folder_wide")]) {
    if (file.exists(path) && !dir.exists(path)) {
      tryCatch(digest_config_file(path), error = function(e) {
        warning("Could not read config file ", path, ": ", conditionMessage(e), call. = FALSE)
      })
    }
  }
  invisible(NULL)
}
