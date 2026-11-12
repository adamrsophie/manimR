# Upstream's config objects (manim/_config): `config`, `frame`, `tempconfig`,
# `logger`, `console`, `error_console` and `cli_ctx_settings`, as R objects
# over the same settings that manim_config() reads and writes.

# Settings derived from others, as upstream's config properties.
config_derived <- function(name) {
  switch(name,
    frame_width = frame_width(),
    frame_x_radius = frame_x_radius(),
    frame_y_radius = frame_y_radius(),
    aspect_ratio = cfg("pixel_width") / cfg("pixel_height"),
    top = frame_y_radius() * UP,
    bottom = frame_y_radius() * DOWN,
    left_side = frame_x_radius() * LEFT,
    right_side = frame_x_radius() * RIGHT,
    NULL
  )
}

CONFIG_DERIVED <- c("frame_width", "frame_x_radius", "frame_y_radius", "aspect_ratio", "top", "bottom",
                    "left_side", "right_side")

#' The global configuration object
#'
#' `config` gives upstream's `config.name` access to the settings of
#' [manim_config()]: `config$frame_height`, `config$pixel_width <- 1280`,
#' `config[["background_color"]]`. Derived values (`frame_width`,
#' `frame_x_radius`, `frame_y_radius`, `aspect_ratio`, `top`, `bottom`,
#' `left_side`, `right_side`) are computed on read; `frame_width` can also
#' be set, as upstream allows, and then stays fixed until set again.
#' `config$quality <- "low_quality"` applies a preset from [QUALITIES].
#' Three of upstream's methods are there too: `config$digest_file(path)`
#' reads a `manim.cfg` file ([digest_config_file()]), `config$get_dir(key,
#' ...)` resolves a directory setting ([get_dir()]) and
#' `config$update(list(...))` changes several settings.
#'
#' `manim_frame` is upstream's read only `frame` object: the frame sizes and
#' edges plus the direction constants (`manim_frame$top`, `manim_frame$UP`).
#' It is not called `frame` because that would mask `graphics::frame()`.
#'
#' `tempconfig()` runs code with some settings changed and restores them
#' afterwards, like upstream's `with tempconfig({...}):` block. As upstream,
#' names that are not settings are ignored.
#'
#' @param x A config object.
#' @param name,i A setting name.
#' @param value New value.
#' @param temp A named list of settings.
#' @param code Code to run with those settings.
#' @param ... Ignored.
#' @return `tempconfig()` returns the value of `code`.
#' @name config
#' @examples
#' config$frame_height
#' tempconfig(list(frame_height = 100), config$frame_height)
#' manim_frame$right_side
NULL

#' @rdname config
#' @format NULL
#' @export
config <- structure(list(), class = "manim_config_object")

#' @rdname config
#' @export
`$.manim_config_object` <- function(x, name) {
  # Methods of upstream's ManimConfig.
  method <- switch(name, digest_file = digest_config_file, get_dir = get_dir,
                   update = function(obj) do.call(manim_config, as.list(obj)), NULL)
  if (!is.null(method)) return(method)
  if (name %in% CONFIG_DERIVED && !(name == "frame_width" && !is.null(cfg("frame_width")))) {
    return(config_derived(name))
  }
  cfg(name)
}

#' @rdname config
#' @export
`[[.manim_config_object` <- function(x, i, ...) `$.manim_config_object`(x, i)

#' @rdname config
#' @export
`$<-.manim_config_object` <- function(x, name, value) {
  if (name %in% setdiff(CONFIG_DERIVED, "frame_width")) {
    stop("config$", name, " is derived from other settings and cannot be set", call. = FALSE)
  }
  do.call(manim_config, stats::setNames(list(value), name))
  x
}

#' @rdname config
#' @export
`[[<-.manim_config_object` <- function(x, i, value) `$<-.manim_config_object`(x, i, value)

#' @rdname config
#' @export
names.manim_config_object <- function(x) union(config_names(), CONFIG_DERIVED)

# Settings that manimR stores but upstream's ManimConfig does not keep in its
# option dictionary (R only settings, or upstream properties).
CONFIG_NOT_UPSTREAM_OPTS <- c("curve_tolerance", "ffmpeg", "flush_cache", "frame_size", "module_name",
                              "save_last_frame", "transparent", "typst")

# ManimConfig.__len__ counts the options it stores.
#' @export
length.manim_config_object <- function(x) length(setdiff(config_names(), CONFIG_NOT_UPSTREAM_OPTS))

#' @rdname config
#' @export
print.manim_config_object <- function(x, ...) {
  cat("<manimR config>\n")
  utils::str(manim_config(), give.attr = FALSE, no.list = TRUE)
  invisible(x)
}

#' @rdname config
#' @format NULL
#' @export
manim_frame <- structure(list(), class = "manim_frame_object")

FRAME_OPTS <- c("pixel_width", "pixel_height", "aspect_ratio", "frame_height", "frame_width", "frame_y_radius",
                "frame_x_radius", "top", "bottom", "left_side", "right_side")

FRAME_CONSTANTS <- c("UP", "DOWN", "RIGHT", "LEFT", "IN", "OUT", "ORIGIN", "X_AXIS", "Y_AXIS", "Z_AXIS",
                     "UL", "UR", "DL", "DR")

#' @rdname config
#' @export
`$.manim_frame_object` <- function(x, name) {
  if (name %in% FRAME_OPTS) return(`$.manim_config_object`(config, name))
  if (name %in% FRAME_CONSTANTS) return(get(name, envir = asNamespace("manimR")))
  stop("manim_frame has no entry '", name, "'", call. = FALSE)
}

#' @rdname config
#' @export
`[[.manim_frame_object` <- function(x, i, ...) `$.manim_frame_object`(x, i)

#' @rdname config
#' @export
`$<-.manim_frame_object` <- function(x, name, value) {
  stop("manim_frame is read only; change settings through config or manim_config()", call. = FALSE)
}

#' @rdname config
#' @export
`[[<-.manim_frame_object` <- function(x, i, value) `$<-.manim_frame_object`(x, i, value)

#' @rdname config
#' @export
names.manim_frame_object <- function(x) c(FRAME_OPTS, FRAME_CONSTANTS)

# ManimFrame.__len__ counts the frame options, not the constants.
#' @export
length.manim_frame_object <- function(x) length(FRAME_OPTS)

#' @rdname config
#' @export
print.manim_frame_object <- function(x, ...) {
  cat("<manimR frame> ", config$frame_width, " x ", config$frame_height, " units, ",
      cfg("pixel_width"), " x ", cfg("pixel_height"), " pixels\n", sep = "")
  invisible(x)
}

#' @rdname config
#' @export
tempconfig <- function(temp, code) {
  temp <- as.list(temp)
  temp <- temp[names(temp) %in% config_names()]
  old <- .manim$config
  on.exit(.manim$config <- old, add = TRUE)
  if (length(temp)) do.call(manim_config, temp)
  force(code)
}

LOG_LEVELS <- c(DEBUG = 10, INFO = 20, WARNING = 30, ERROR = 40, CRITICAL = 50)

#' Logging and console output
#'
#' `logger` mirrors upstream's `manim.logger`: `logger$info("...")`,
#' `logger$debug()`, `logger$warning()`, `logger$error()` and
#' `logger$critical()` print a message when its level is at least the
#' `verbosity` setting of [manim_config()] (`"DEBUG"`, `"INFO"`, `"WARNING"`,
#' `"ERROR"` or `"CRITICAL"`; default `"INFO"`). Messages go through
#' [message()], so [suppressMessages()] silences them. `logger$setLevel()`
#' changes `verbosity`. Format arguments work as in [sprintf()].
#'
#' `console$print()` writes to standard output and `error_console$print()`
#' to standard error, like upstream's rich consoles.
#'
#' `cli_ctx_settings` holds upstream's command line help settings (the
#' `[CLI_CTX]` section of its configuration file).
#'
#' @return `logger`, `console` and `error_console` are lists of functions that
#'   print messages; `cli_ctx_settings` is a named list of settings.
#' @format Lists of functions; `cli_ctx_settings` is a named list.
#' @name logger
#' @examples
#' logger$info("Rendering %d scenes", 2L)
#' console$print("Done")
NULL

make_log_fn <- function(level) {
  force(level)
  function(msg, ...) {
    current <- LOG_LEVELS[[toupper(cfg("verbosity") %||% "INFO")]]
    if (LOG_LEVELS[[level]] >= current) {
      text <- if (length(list(...))) sprintf(msg, ...) else paste(msg, collapse = " ")
      message(level, " ", text)
      # With log_to_file, scenes also log to <log_dir>/<module>_<scene>.log
      # as JSON lines, like upstream's JSONFormatter.
      if (!is.null(.manim$log_file)) {
        cat(sprintf('{"levelname": %s, "module": "manimR", "message": %s}\n', json_string(level), json_string(text)),
            file = .manim$log_file, append = TRUE)
      }
    }
    invisible(NULL)
  }
}

#' @rdname logger
#' @export
logger <- list(
  debug = make_log_fn("DEBUG"),
  info = make_log_fn("INFO"),
  warning = make_log_fn("WARNING"),
  error = make_log_fn("ERROR"),
  critical = make_log_fn("CRITICAL"),
  setLevel = function(level) {
    level <- toupper(level)
    if (!level %in% names(LOG_LEVELS)) stop("Unknown log level '", level, "'", call. = FALSE)
    manim_config(verbosity = level)
    invisible(NULL)
  },
  getEffectiveLevel = function() LOG_LEVELS[[toupper(cfg("verbosity") %||% "INFO")]]
)

#' @rdname logger
#' @export
console <- list(print = function(...) {
  cat(..., "\n", sep = " ")
  invisible(NULL)
})

#' @rdname logger
#' @export
error_console <- list(print = function(...) {
  cat(..., "\n", sep = " ", file = stderr())
  invisible(NULL)
})

#' @rdname logger
#' @export
cli_ctx_settings <- list(
  align_option_groups = TRUE,
  align_sections = TRUE,
  show_constraints = TRUE,
  formatter_settings = list(indent_increment = 2L, width = 80L, col1_max_width = 30L, col2_min_width = 35L,
                            col_spacing = 2L, row_sep = NULL),
  theme = NULL
)
