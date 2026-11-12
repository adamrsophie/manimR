# Upstream's module objects `rate_functions` and `color`
# (`from manim.utils import color, rate_functions`), built after every
# function they hold is defined.

#' Upstream module objects
#'
#' Upstream code often reaches rate functions and colors through their
#' modules, as in `rate_functions.ease_in_sine` or `color.BLUE_C`. These
#' lists give the same access: `rate_functions$ease_in_sine`,
#' `rate_functions$smooth` (which is [smooth_rate()]), `color$BLUE_C`,
#' `color$X11$BEIGE` or `color$interpolate_color`. Everything in them is also
#' exported directly.
#'
#' Upstream's third module, `unit`, is not provided as an object, since
#' `unit` would mask `grid::unit()`; use [Pixels], [Percent()], [Degrees] and
#' [Munits] directly.
#'
#' @format Named lists of functions and values.
#' @name upstream_modules
#' @examples
#' rate_functions$smooth(0.5)
#' color$BLUE_C
NULL

RATE_FUNCTION_NAMES <- c(
  "unit_interval", "zero", "linear", "smooth", "smoothstep", "smootherstep", "smoothererstep", "rush_into",
  "rush_from", "slow_into", "double_smooth", "there_and_back", "there_and_back_with_pause", "running_start",
  "not_quite_there", "wiggle", "squish_rate_func", "lingering", "exponential_decay", "ease_in_sine",
  "ease_out_sine", "ease_in_out_sine", "ease_in_quad", "ease_out_quad", "ease_in_out_quad", "ease_in_cubic",
  "ease_out_cubic", "ease_in_out_cubic", "ease_in_quart", "ease_out_quart", "ease_in_out_quart", "ease_in_quint",
  "ease_out_quint", "ease_in_out_quint", "ease_in_expo", "ease_out_expo", "ease_in_out_expo", "ease_in_circ",
  "ease_out_circ", "ease_in_out_circ", "ease_in_back", "ease_out_back", "ease_in_out_back", "ease_in_elastic",
  "ease_out_elastic", "ease_in_out_elastic", "ease_in_bounce", "ease_out_bounce", "ease_in_out_bounce"
)

#' @rdname upstream_modules
#' @export
rate_functions <- stats::setNames(
  lapply(RATE_FUNCTION_NAMES, function(n) get(if (n == "smooth") "smooth_rate" else n)),
  RATE_FUNCTION_NAMES
)

#' @rdname upstream_modules
#' @export
color <- local({
  ns <- topenv(environment())
  consts <- grep("^[A-Z][A-Z0-9_]*$", ls(ns), value = TRUE)
  consts <- consts[vapply(consts, function(n) {
    v <- get(n, envir = ns)
    is.character(v) && length(v) == 1 && grepl("^#[0-9A-F]{6}$", v)
  }, NA)]
  fns <- c("color_to_rgb", "color_to_rgba", "color_to_int_rgb", "color_to_int_rgba", "rgb_to_color", "rgba_to_color",
           "rgb_to_hex", "hex_to_rgb", "invert_color", "color_gradient", "interpolate_color", "average_color",
           "random_bright_color", "random_color", "get_shaded_rgb", "ManimColor", "HSV", "RGBA",
           "RandomColorGenerator", "ManimColorDType", "AS2700", "BS381", "DVIPSNAMES", "SVGNAMES", "XKCD")
  out <- mget(c(consts, fns), envir = ns)
  out$X11 <- get("X11_COLORS", envir = ns)
  out
})
