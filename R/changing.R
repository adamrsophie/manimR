# AnimatedBoundary, TracedPath, ScreenRectangle and units.
# Ported from manim/animation/changing.py, manim/mobject/frame.py and
# manim/utils/unit.py.

#' @title AnimatedBoundary and TracedPath
#' @description `AnimatedBoundary()` draws a boundary around a VMobject that
#'   cycles through colors while the scene runs. `TracedPath()` leaves a trail
#'   behind a moving point, optionally fading after `dissipating_time` seconds.
#' @param vmobject The VMobject to outline.
#' @param colors Colors to cycle through.
#' @param max_stroke_width Maximum stroke width.
#' @param cycle_rate Cycles per second.
#' @param back_and_forth Draw back and forth.
#' @param draw_rate_func,fade_rate_func Rate functions for drawing and fading.
#' @param traced_point_func Function with no arguments returning the point to trace.
#' @param stroke_width,stroke_color Style of the trace.
#' @param dissipating_time Seconds after which the trace fades, or `NULL`.
#' @param ... Passed to [VGroup()] or [VMobject()].
#' @export
AnimatedBoundaryClass <- R6::R6Class("AnimatedBoundary", inherit = VGroupClass, lock_objects = FALSE,
  public = list(
    colors = NULL,
    max_stroke_width = 3,
    cycle_rate = 0.5,
    back_and_forth = TRUE,
    draw_rate_func = NULL,
    fade_rate_func = NULL,
    vmobject = NULL,
    boundary_copies = NULL,
    total_time = 0,
    initialize = function(vmobject, colors = c(BLUE_D, BLUE_B, BLUE_E, GREY_BROWN), max_stroke_width = 3,
                          cycle_rate = 0.5, back_and_forth = TRUE, draw_rate_func = smooth_rate,
                          fade_rate_func = smooth_rate, ...) {
      super$initialize(...)
      self$colors <- colors
      self$max_stroke_width <- max_stroke_width
      self$cycle_rate <- cycle_rate
      self$back_and_forth <- back_and_forth
      self$draw_rate_func <- draw_rate_func
      self$fade_rate_func <- fade_rate_func
      self$vmobject <- vmobject
      self$boundary_copies <- lapply(1:2, function(i) vmobject$copy()$set_style(stroke_width = 0, fill_opacity = 0))
      self$add(self$boundary_copies)
      self$total_time <- 0
      self$add_updater(function(m, dt) m$update_boundary_copies(dt))
    },
    update_boundary_copies = function(dt) {
      time <- self$total_time * self$cycle_rate
      growing <- self$boundary_copies[[1]]
      fading <- self$boundary_copies[[2]]
      colors <- self$colors
      n <- length(colors)
      msw <- self$max_stroke_width
      index <- as.integer(time %% n)
      alpha <- time %% 1
      draw_alpha <- self$draw_rate_func(alpha)
      fade_alpha <- self$fade_rate_func(alpha)
      bounds <- if (self$back_and_forth && as.integer(time) %% 2 == 1) c(1 - draw_alpha, 1) else c(0, draw_alpha)
      self$full_family_become_partial(growing, self$vmobject, bounds[1], bounds[2])
      growing$set_stroke(colors[index + 1], width = msw)
      if (time >= 1) {
        self$full_family_become_partial(fading, self$vmobject, 0, 1)
        fading$set_stroke(color = colors[((index - 1) %% n) + 1], width = (1 - fade_alpha) * msw)
      }
      self$total_time <- self$total_time + dt
      invisible(self)
    },
    full_family_become_partial = function(mob1, mob2, a, b) {
      f1 <- mob1$family_members_with_points()
      f2 <- mob2$family_members_with_points()
      for (i in seq_len(min(length(f1), length(f2)))) f1[[i]]$pointwise_become_partial(f2[[i]], a, b)
      invisible(self)
    }
  )
)

#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @rdname AnimatedBoundaryClass
#' @export
AnimatedBoundary <- constructor(AnimatedBoundaryClass)
#' @rdname AnimatedBoundaryClass
#' @format NULL
#' @usage NULL
#' @export
TracedPathClass <- R6::R6Class("TracedPath", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    traced_point_func = NULL,
    dissipating_time = NULL,
    time = NULL,
    initialize = function(traced_point_func, stroke_width = 2, stroke_color = "#FFFFFF", dissipating_time = NULL, ...) {
      super$initialize(stroke_color = stroke_color, stroke_width = stroke_width, ...)
      self$traced_point_func <- traced_point_func
      self$dissipating_time <- dissipating_time
      self$time <- if (!is.null(dissipating_time) && dissipating_time != 0) 1 else NULL
      self$add_updater(function(mob, dt) mob$update_path(mob, dt))
    },
    update_path = function(mob, dt) {
      new_point <- as_point(self$traced_point_func())
      if (!self$has_points()) self$start_new_path(new_point)
      self$add_line_to(new_point)
      if (!is.null(self$dissipating_time) && self$dissipating_time != 0) {
        self$time <- self$time + dt
        if (self$time - 1 > self$dissipating_time) {
          n <- nrow(self$points)
          self$set_points(self$points[-(1:min(4, n)), , drop = FALSE])
        }
      }
      invisible(self)
    }
  )
)

#' @rdname AnimatedBoundaryClass
#' @export
TracedPath <- constructor(TracedPathClass)
#' @title ScreenRectangle and FullScreenRectangle
#' @description Rectangles with the aspect ratio of the screen.
#' @param aspect_ratio Width divided by height.
#' @param height Height.
#' @param ... Passed to [Rectangle()].
#' @export
ScreenRectangleClass <- R6::R6Class("ScreenRectangle", inherit = RectangleClass, lock_objects = FALSE,
  public = list(
    initialize = function(aspect_ratio = 16 / 9, height = 4, ...) {
      super$initialize(width = aspect_ratio * height, height = height, ...)
    }
  ),
  active = list(
    aspect_ratio = function(value) {
      if (missing(value)) return(self$width / self$height)
      self$stretch_to_fit_width(value * self$height)
    }
  )
)

#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @rdname ScreenRectangleClass
#' @export
ScreenRectangle <- constructor(ScreenRectangleClass)
#' @rdname ScreenRectangleClass
#' @export
FullScreenRectangle <- function(...) {
  r <- ScreenRectangleClass$new(...)
  class(r) <- c("FullScreenRectangle", class(r))
  r$height <- frame_height()
  r
}

#' Units
#'
#' Unit helpers from `manim.utils.unit`: `Pixels` converts pixels to scene
#' units at the current resolution, `Percent(X_AXIS)` converts a percentage
#' of the frame width (or height for `Y_AXIS`), `Degrees` converts degrees to
#' radians and `Munits` is one scene unit. Multiply a number by a unit:
#' `50 * Pixels`, `25 * Percent(X_AXIS)`.
#'
#' @param axis `X_AXIS` or `Y_AXIS`.
#' @return `Pixels`, `Degrees` and `Munits` are units to multiply a number by,
#'   and `Percent()` returns such a unit for an axis; the product is a length in
#'   scene units or an angle in radians.
#' @name units
#' @examples
#' 100 * Pixels
#' 10 * Percent(X_AXIS)
NULL

#' @rdname units
#' @format NULL
#' @export
Pixels <- structure(list(kind = "pixels"), class = "manim_unit")

#' @rdname units
#' @export
Percent <- function(axis) {
  axis <- as_point(axis)
  if (all(axis == X_AXIS)) return(structure(list(kind = "percent_x"), class = "manim_unit"))
  if (all(axis == Y_AXIS)) return(structure(list(kind = "percent_y"), class = "manim_unit"))
  if (all(axis == Z_AXIS)) stop("length of Z axis is undefined", call. = FALSE)
  stop("Percent only supports X_AXIS (frame width) and Y_AXIS (frame height).", call. = FALSE)
}

#' @rdname units
#' @format NULL
#' @export
Degrees <- pi / 180

#' @rdname units
#' @format NULL
#' @export
Munits <- 1

unit_factor <- function(u) {
  switch(u$kind,
    pixels = frame_width() / cfg("pixel_width"),
    percent_x = frame_width() / 100,
    percent_y = frame_height() / 100
  )
}

#' @export
Ops.manim_unit <- function(e1, e2) {
  if (.Generic != "*") stop("Units only support multiplication.", call. = FALSE)
  if (inherits(e1, "manim_unit")) e2 * unit_factor(e1) else e1 * unit_factor(e2)
}
