# Axis scalings for number lines and graphs.
# Ported from manim/mobject/graphing/scale.py.

# numpy.arange semantics: start + k * step for k = 0, 1, ... while short of stop.
np_arange <- function(start, stop, step = 1) {
  n <- ceiling((stop - start) / step)
  if (!is.finite(n) || n <= 0) return(numeric(0))
  start + (seq_len(n) - 1) * step
}

#' Axis scalings
#'
#' Scales control how values along a [NumberLine()] or the axes of a
#' coordinate system map to positions. `LinearBase()` multiplies values by a
#' constant; `LogBase()` turns the axis into a logarithmic one, so that an
#' axis with `x_range = c(-1, 3)` spans `10^-1` to `10^3`.
#'
#' Each scale has the methods `func(value)` (the scaling itself, called
#' `function` upstream, which is a reserved word in R) and
#' `inverse_function(value)`. `LogBase` also has
#' `get_custom_labels(val_range, unit_decimal_places = 0, ...)`, which returns
#' [Integer()] labels of the form \eqn{10^{k}}.
#'
#' @param scale_factor The slope of the linear scaling.
#' @param base The base of the logarithm.
#' @param custom_labels Whether axes using this scale build their own
#'   labels (with [Integer()]) instead of plain decimal numbers.
#' @return A scale object.
#' @name graph_scale
#' @examples
#' LogBase(base = 2)$func(3)
#' LinearBase(2)$inverse_function(4)
NULL

#' @rdname graph_scale
#' @format NULL
#' @usage NULL
#' @export
LinearBaseClass <- R6::R6Class("LinearBase", lock_objects = FALSE,
  public = list(
    scale_factor = 1,
    custom_labels = FALSE,
    initialize = function(scale_factor = 1) {
      self$scale_factor <- scale_factor
    },
    func = function(value) self$scale_factor * value,
    # Upstream's name; `function` is reserved in R, so call it as
    # scale$`function`(x) or use func().
    `function` = function(value) self$func(value),
    inverse_function = function(value) value / self$scale_factor,
    get_custom_labels = function(val_range, ...) stop("LinearBase has no custom labels.", call. = FALSE)
  )
)

#' @rdname graph_scale
#' @export
LinearBase <- constructor(LinearBaseClass)
#' @rdname graph_scale
#' @format NULL
#' @usage NULL
#' @export
LogBaseClass <- R6::R6Class("LogBase", lock_objects = FALSE,
  public = list(
    base = 10,
    custom_labels = TRUE,
    initialize = function(base = 10, custom_labels = TRUE) {
      self$base <- base
      self$custom_labels <- custom_labels
    },
    func = function(value) self$base^value,
    `function` = function(value) self$func(value),
    inverse_function = function(value) {
      if (any(value <= 0)) {
        stop("log(0) is undefined. Make sure the value is in the domain of the function", call. = FALSE)
      }
      log(value) / log(self$base)
    },
    get_custom_labels = function(val_range, unit_decimal_places = 0, ...) {
      lapply(val_range, function(i) {
        expo <- formatC(self$inverse_function(i), format = "f", digits = unit_decimal_places)
        Integer(self$base, unit = paste0("^{", expo, "}"), ...)
      })
    }
  )
)

#' @rdname graph_scale
#' @export
LogBase <- constructor(LogBaseClass)