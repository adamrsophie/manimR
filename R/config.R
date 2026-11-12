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

default_config <- function() {
  list(
    quality = "h",
    pixel_width = 1920,
    pixel_height = 1080,
    frame_rate = 60,
    frame_height = 8,
    background_color = "#000000",
    background_opacity = 1,
    media_dir = "media",
    format = "mp4",
    transparent = FALSE,
    save_last_frame = FALSE,
    write_to_movie = TRUE,
    save_sections = FALSE,
    preview = FALSE,
    disable_caching = FALSE,
    verbosity = "INFO",
    output_file = NULL,
    tex_template = NULL,
    from_animation_number = 0,
    upto_animation_number = Inf,
    progress_bar = TRUE,
    ffmpeg = "ffmpeg",
    typst = "typst",
    curve_tolerance = 0.25,
    assets_dir = "./",
    renderer = "cairo",
    flush_cache = FALSE,
    max_files_cached = 100
  )
}

#' Get or set the manimR configuration
#'
#' Called with no arguments, returns the current configuration as a list.
#' Named arguments update it. `quality` accepts manim's quality flags:
#' `"l"` (854x480, 15 fps), `"m"` (1280x720, 30 fps), `"h"` (1920x1080, 60 fps),
#' `"p"` (2560x1440, 60 fps) and `"k"` (3840x2160, 60 fps), or the preset
#' names of [QUALITIES] such as `"low_quality"` and `"example_quality"`.
#' `renderer` accepts `"cairo"`; `"opengl"` is accepted for compatibility and
#' renders with the same Cairo style renderer, the only one ported. The
#' [config] object gives the same settings with upstream's `config$name`
#' syntax.
#'
#' @param ... Named settings, e.g. `quality = "l"`, `background_color = WHITE`,
#'   `format = "gif"`, `media_dir = "media"`, `pixel_width`, `pixel_height`,
#'   `frame_rate`, `frame_height`, `transparent`, `tex_template`. The returned
#'   list also reports the derived `frame_width`, `frame_x_radius` and
#'   `frame_y_radius`.
#' @return The configuration list, invisibly when setting.
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
    return(cfg)
  }
  old <- cfg
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
#' @export
with_manim_config <- function(settings, code) {
  old <- do.call(manim_config, settings)
  on.exit(.manim$config <- old, add = TRUE)
  force(code)
}

cfg <- function(name) .manim$config[[name]]

frame_height <- function() cfg("frame_height")
# An explicitly set frame_width (config$frame_width <- w) wins, as upstream.
frame_width <- function() cfg("frame_width") %||% (cfg("frame_height") * cfg("pixel_width") / cfg("pixel_height"))
frame_x_radius <- function() frame_width() / 2
frame_y_radius <- function() frame_height() / 2

quality_dir_name <- function() {
  paste0(cfg("pixel_height"), "p", cfg("frame_rate"))
}
