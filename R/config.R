# Global render configuration, mirroring manim's config object.

#' Render qualities
#'
#' Upstream's quality presets. `quality` in [manim_config()] and [render()]
#' accepts a preset name such as `"low_quality"` or its flag (`"l"`).
#' `"example_quality"` has no flag.
#'
#' @format `QUALITIES` is a named list of presets, each a list with `flag`,
#'   `pixel_height`, `pixel_width` and `frame_rate`. `DEFAULT_QUALITY` is the
#'   name of the default preset.
#' @export
QUALITIES <- list(
  fourk_quality = list(flag = "k", pixel_height = 2160, pixel_width = 3840, frame_rate = 60),
  production_quality = list(flag = "p", pixel_height = 1440, pixel_width = 2560, frame_rate = 60),
  high_quality = list(flag = "h", pixel_height = 1080, pixel_width = 1920, frame_rate = 60),
  medium_quality = list(flag = "m", pixel_height = 720, pixel_width = 1280, frame_rate = 30),
  low_quality = list(flag = "l", pixel_height = 480, pixel_width = 854, frame_rate = 15),
  example_quality = list(flag = NA_character_, pixel_height = 480, pixel_width = 854, frame_rate = 30)
)

#' @return `QUALITIES` is a named list of render settings, one entry for each
#'   quality. `DEFAULT_QUALITY` is the name of the default quality.
#' @rdname QUALITIES
#' @export
DEFAULT_QUALITY <- "high_quality"

# The preset for a quality name or flag, or NULL.
quality_spec <- function(q) {
  if (!is.character(q) || length(q) != 1) return(NULL)
  if (q %in% names(QUALITIES)) return(QUALITIES[[q]])
  flags <- vapply(QUALITIES, function(x) x$flag, "")
  hit <- which(!is.na(flags) & flags == q)
  if (length(hit)) QUALITIES[[hit[1]]]
}

# The default media folder, in the session's temporary directory, so that
# rendering writes nothing to the working directory unless asked to. Upstream
# writes ./media; manim_cli() keeps that, as upstream's command line does.
default_media_dir <- function() file.path(tempdir(), "media")

default_config <- function() {
  list(
    quality = "h",
    pixel_width = 1920,
    pixel_height = 1080,
    frame_rate = 60,
    frame_height = 8,
    background_color = "#000000",
    background_opacity = 1,
    format = "auto",
    save_sections = FALSE,
    zero_pad = 4,
    preview = FALSE,
    live_preview = FALSE,
    show_in_file_browser = FALSE,
    preview_command = NULL,
    dry_run = FALSE,
    write_all = FALSE,
    scene_names = character(),
    input_file = NULL,
    output_file = NULL,
    media_dir = default_media_dir(),
    log_dir = "{media_dir}/logs",
    log_to_file = FALSE,
    assets_dir = "./",
    video_dir = "{media_dir}/videos/{module_name}/{quality}",
    sections_dir = "{video_dir}/sections",
    images_dir = "{media_dir}/images/{module_name}",
    tex_dir = "{media_dir}/Tex",
    text_dir = "{media_dir}/texts",
    partial_movie_dir = "{video_dir}/partial_movie_files/{scene_name}",
    disable_caching = FALSE,
    disable_caching_warning = FALSE,
    max_files_cached = 100,
    flush_cache = FALSE,
    video_codec = "auto",
    pixel_format = "auto",
    video_encoder_options = list(),
    max_inflight_encoders = 1,
    encoder_queue_size = 8,
    verbosity = "INFO",
    progress_bar = TRUE,
    media_loglevel = "ERROR",
    media_embed = NULL,
    media_width = "60%",
    notify_outdated_version = TRUE,
    from_animation_number = 0,
    upto_animation_number = -1,
    renderer = "cairo",
    enable_gui = FALSE,
    gui_location = c(0, 0),
    fullscreen = FALSE,
    window_position = "UR",
    window_size = "default",
    window_monitor = 0,
    use_projection_fill_shaders = FALSE,
    use_projection_stroke_shaders = FALSE,
    enable_wireframe = FALSE,
    no_latex_cleanup = FALSE,
    tex_template = NULL,
    tex_template_file = NULL,
    plugins = character(),
    seed = NULL,
    # Computed once from the default 1920 x 1080 pixels, as upstream: quality
    # and pixel sizes do not change it, cameras adapt their frame height.
    frame_width = 8 * 1920 / 1080,
    # manimR settings with no upstream counterpart: external programs, the
    # module name of scenes rendered from R code, and curve flattening.
    ffmpeg = "ffmpeg",
    typst = "typst",
    module_name = NULL,
    curve_tolerance = 0.25
  )
}

# Settings computed from others, which manim_config() translates when set.
CONFIG_TRANSLATED <- c("transparent", "save_last_frame", "frame_size", "frame_x_radius", "frame_y_radius")

config_names <- function() c(names(default_config()), CONFIG_TRANSLATED)

check_choice <- function(name, value, choices) {
  if (!is.character(value) || length(value) != 1 || !value %in% choices) {
    stop(name, " must be one of ", paste(choices, collapse = ", "), call. = FALSE)
  }
}

#' Get or set the manimR configuration
#'
#' Called with no arguments, returns the current configuration as a list.
#' Named arguments update it; an unknown name is an error, as upstream's
#' `config`. The [config] object gives the same settings with upstream's
#' `config$name` syntax, [with_manim_config()] and [tempconfig()] change
#' them for a block of code, and [digest_config_file()] reads them from a
#' `manim.cfg` file.
#'
#' The settings, with upstream's names and defaults:
#'
#' * Frame: `quality` (a flag `"l"` 854x480 at 15 fps, `"m"` 1280x720 at 30,
#'   `"h"` 1920x1080 at 60, `"p"` 2560x1440 at 60, `"k"` 3840x2160 at 60, or a
#'   preset name of [QUALITIES]), `pixel_width`, `pixel_height`,
#'   `frame_size` (both at once), `frame_rate`, `frame_height` (8),
#'   `frame_width` (derived from the aspect ratio unless set),
#'   `frame_x_radius`, `frame_y_radius`, `background_color`,
#'   `background_opacity`, `transparent` (`TRUE` sets `background_opacity`
#'   to 0).
#' * Output: `format`, the artifact a render writes: `"auto"` (the default:
#'   MP4, or MOV when transparent; a scene without animations is saved as
#'   its last frame), `"mp4"`, `"mov"`, `"webm"`, `"gif"`, `"png"` (only the
#'   last frame), `"png-sequence"` (every frame) or `"none"`.
#'   `save_last_frame = TRUE` is short for `format = "png"`. `dry_run` renders
#'   without writing files, `save_sections` also writes one video per section,
#'   `zero_pad` (4) is the number of digits in PNG sequence file names,
#'   `output_file` names the artifact (relative to its directory below),
#'   `from_animation_number` and `upto_animation_number` (-1: all) select
#'   animations.
#' * Directories, with `{name}` placeholders resolved by [get_dir()]:
#'   `media_dir` (a folder `media` in the session's temporary directory; set
#'   it, for example to `"media"`, to keep the output; [manim_cli()] uses
#'   `"media"` in the working directory, as upstream), `video_dir`
#'   ("\{media_dir\}/videos/\{module_name\}/\{quality\}"), `images_dir`, `sections_dir`,
#'   `partial_movie_dir`, `tex_dir`, `text_dir`, `log_dir`, `assets_dir`
#'   (where sounds and images are looked up), `input_file` (the script
#'   being rendered; its name is the module name) and manimR's
#'   `module_name` for scenes rendered from R code ("manimR").
#' * Encoding: `video_codec`, `pixel_format` (both `"auto"`) and
#'   `video_encoder_options` (a named list of ffmpeg options such as
#'   `list(crf = "18")`) for the cached video segments;
#'   `max_inflight_encoders` and `encoder_queue_size` are validated but
#'   encoding runs in the R process, one segment at a time.
#' * Caching: `disable_caching`, `disable_caching_warning`,
#'   `max_files_cached` (100; -1 keeps all), and manimR's `flush_cache`.
#' * Presentation and logging: `preview` (open the result), `preview_command`,
#'   `show_in_file_browser`, `verbosity` ("INFO"), `progress_bar`,
#'   `log_to_file` (write a log per scene to `log_dir`), `media_loglevel`.
#' * LaTeX: `tex_template` (a [TexTemplate()]), `tex_template_file`,
#'   `no_latex_cleanup` (keep .aux, .dvi and .log files in `tex_dir`).
#' * Other: `seed` (random seed of every scene), `renderer` (`"cairo"`;
#'   `"opengl"` is accepted and renders with the Cairo style renderer, the
#'   only one ported), `plugins`, `write_all`, `scene_names`,
#'   `notify_outdated_version`, and the OpenGL window settings
#'   `enable_gui`, `live_preview`, `gui_location`, `fullscreen`,
#'   `window_position`, `window_size`, `window_monitor`,
#'   `use_projection_fill_shaders`, `use_projection_stroke_shaders`,
#'   `enable_wireframe`, which have no effect on the Cairo style renderer
#'   (asking for a live preview is an error, as upstream), and the Jupyter
#'   settings `media_embed` and `media_width`.
#' * manimR only: `ffmpeg` and `typst` (paths of those programs) and
#'   `curve_tolerance`.
#'
#' @param ... Named settings.
#' @return The configuration list (including the derived `frame_width`,
#'   `frame_x_radius`, `frame_y_radius`, `transparent` and
#'   `save_last_frame`), invisibly when setting.
#' @export
#' @examples
#' old <- manim_config(quality = "l")
#' manim_config()$pixel_width
#' manim_config(quality = old$quality)
manim_config <- function(...) {
  args <- list(...)
  cfg <- .manim$config
  if (length(args) == 0) {
    cfg$frame_width <- frame_width()
    cfg$frame_x_radius <- frame_x_radius()
    cfg$frame_y_radius <- frame_y_radius()
    cfg$transparent <- cfg("transparent")
    cfg$save_last_frame <- cfg("save_last_frame")
    return(cfg)
  }
  old <- cfg
  if (is.null(names(args)) || any(!nzchar(names(args)))) stop("manim_config() settings must be named", call. = FALSE)
  if ("write_to_movie" %in% names(args)) {
    stop("write_to_movie is not a setting any more (manim 0.22): use format = \"png\" for the last frame only, ",
         "or format = \"none\" for no output.", call. = FALSE)
  }
  unknown <- setdiff(names(args), config_names())
  if (length(unknown)) {
    stop("Unknown setting", if (length(unknown) > 1) "s", ": ", paste(unknown, collapse = ", "),
         ". See ?manim_config for the settings.", call. = FALSE)
  }
  # Settings derived from others (upstream's config properties).
  if (!is.null(args$transparent)) {
    if (!is.logical(args$transparent) || length(args$transparent) != 1 || is.na(args$transparent)) {
      stop("transparent must be TRUE or FALSE", call. = FALSE)
    }
    args$background_opacity <- as.numeric(!args$transparent)
  }
  if (!is.null(args$save_last_frame)) {
    if (!is.logical(args$save_last_frame) || length(args$save_last_frame) != 1 || is.na(args$save_last_frame)) {
      stop("save_last_frame must be boolean", call. = FALSE)
    }
    if (args$save_last_frame) {
      args$format <- "png"
    } else if (is.null(args$format) && identical(parse_output_format(cfg$format), "png")) {
      args$format <- "auto"
    }
  }
  if (!is.null(args$frame_x_radius)) args$frame_width <- 2 * args$frame_x_radius
  if (!is.null(args$frame_y_radius)) args$frame_height <- 2 * args$frame_y_radius
  if (!is.null(args$frame_size)) {
    args$pixel_width <- args$frame_size[1]
    args$pixel_height <- args$frame_size[2]
  }
  args[intersect(names(args), CONFIG_TRANSLATED)] <- NULL
  if ("format" %in% names(args)) {
    args["format"] <- list(parse_output_format(args$format))
    if (identical(args$format, "webm")) {
      message("WARNING Output format set as webm, this can be slower than other formats")
    }
  }
  if (!is.null(args$verbosity)) check_choice("verbosity", args$verbosity, names(LOG_LEVELS))
  if (!is.null(args$media_loglevel)) check_choice("media_loglevel", args$media_loglevel, names(LOG_LEVELS))
  if (!is.null(args$zero_pad) && !(is.numeric(args$zero_pad) && args$zero_pad >= 0 && args$zero_pad <= 9)) {
    stop("zero_pad must be between 0 and 9", call. = FALSE)
  }
  for (k in c("max_inflight_encoders", "encoder_queue_size")) {
    if (!is.null(args[[k]]) && !(is.numeric(args[[k]]) && args[[k]] > 0)) stop(k, " must be positive", call. = FALSE)
  }
  if (!is.null(args$max_files_cached) && !(is.numeric(args$max_files_cached) && args$max_files_cached >= -1)) {
    stop("max_files_cached must be non-negative or -1", call. = FALSE)
  }
  if (!is.null(args$tex_template_file) && nzchar(args$tex_template_file) &&
      file.access(args$tex_template_file, 4) != 0) {
    message("WARNING Custom TeX template ", args$tex_template_file, " not found or not readable.")
    args["tex_template_file"] <- list(NULL)
  }
  if (!is.null(args$renderer)) {
    if (!args$renderer %in% unlist(RendererType)) stop("Unknown renderer '", args$renderer, "'", call. = FALSE)
    if (args$renderer == RendererType$OPENGL) {
      message("Only the Cairo style renderer is ported to R; scenes render with it.")
    }
  }
  if (!is.null(args$quality)) {
    q <- quality_spec(args$quality)
    if (is.null(q)) {
      stop("Unknown quality '", args$quality, "'. Use a flag (l, m, h, p, k) or a name from QUALITIES.", call. = FALSE)
    }
    cfg$quality <- args$quality
    cfg$pixel_width <- q$pixel_width
    cfg$pixel_height <- q$pixel_height
    cfg$frame_rate <- q$frame_rate
    args$quality <- NULL
  }
  for (nm in names(args)) cfg[nm] <- list(args[[nm]])
  .manim$config <- cfg
  invisible(old)
}

#' Run code with a temporary configuration
#'
#' @param settings A named list passed to [manim_config()].
#' @param code Code to evaluate.
#' @return The value of `code`.
#' @export
with_manim_config <- function(settings, code) {
  old <- do.call(manim_config, settings)
  on.exit(.manim$config <- old, add = TRUE)
  force(code)
}

# One setting; `transparent` and `save_last_frame` are derived from
# background_opacity and format, as upstream's config properties.
cfg <- function(name) {
  switch(name,
    transparent = (.manim$config$background_opacity %||% 1) < 1,
    save_last_frame = identical(parse_output_format(.manim$config$format), "png"),
    .manim$config[[name]]
  )
}

frame_height <- function() cfg("frame_height")
# An explicitly set frame_width (config$frame_width <- w) wins, as upstream.
frame_width <- function() cfg("frame_width") %||% (cfg("frame_height") * cfg("pixel_width") / cfg("pixel_height"))
frame_x_radius <- function() frame_width() / 2
frame_y_radius <- function() frame_height() / 2

quality_dir_name <- function() {
  paste0(cfg("pixel_height"), "p", cfg("frame_rate"))
}
