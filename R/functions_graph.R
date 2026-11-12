# Mobjects representing function graphs.
# Ported from manim/mobject/graphing/functions.py.

#' Function graphs
#'
#' `ParametricFunction()` traces a curve `t -> c(x(t), y(t), z(t))`.
#' `FunctionGraph()` plots `y = f(x)` in scene coordinates across the frame.
#' `ImplicitFunction()` draws the zero set of `f(x, y)`.
#'
#' The point function of a graph is stored in the field `func` (upstream
#' calls it `function`, a reserved word in R); `get_function()` returns it.
#'
#' @param func For `ParametricFunction()`, a function of `t` returning 2 or
#'   3 coordinates. For `ImplicitFunction()`, a function of `x` and `y`.
#' @param t_range `c(t_min, t_max, t_step)`; the step defaults to 0.01.
#' @param scaling Scale applied to the sampled `t` values; see [LinearBase()].
#' @param dt Gap left on each side of a discontinuity.
#' @param discontinuities Values of `t` where the curve is broken.
#' @param use_smoothing Whether to smooth the sampled polyline.
#' @param use_vectorized Whether `func` accepts a vector of `t` values. Like
#'   upstream, it must then return coordinate rows: a 2 x n or 3 x n matrix
#'   such as `rbind(cos(t), sin(t), 0)`, or `list(x, y)` or `list(x, y, z)`.
#'   A matrix with one point per row is accepted only when its shape cannot
#'   be read as coordinate rows.
#' @param x_range,y_range Ranges of the variables.
#' @param color Color.
#' @param min_depth,max_quads Resolution of the implicit curve sampling grid.
#' @param ... Passed to [VMobject()].
#' @return A mobject.
#' @name function_graphs
#' @examples
#' \dontrun{
#' ParametricFunction(function(t) c(sin(2 * t), sin(3 * t), 0), t_range = c(0, TAU))
#' FunctionGraph(cos, color = RED)
#' ImplicitFunction(function(x, y) x^2 + y^2 - 4)
#' }
NULL

#' @rdname function_graphs
#' @format NULL
#' @usage NULL
#' @export
ParametricFunctionClass <- R6::R6Class("ParametricFunction", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    func = NULL,
    underlying_function = NULL,
    scaling = NULL,
    dt = 1e-8,
    discontinuities = NULL,
    use_smoothing = TRUE,
    use_vectorized = FALSE,
    t_min = 0,
    t_max = 1,
    t_step = 0.01,
    initialize = function(func, t_range = c(0, 1), scaling = LinearBase(), dt = 1e-8, discontinuities = NULL,
                          use_smoothing = TRUE, use_vectorized = FALSE, ...) {
      self$func <- func
      if (length(t_range) == 2) t_range <- c(t_range, 0.01)
      self$scaling <- scaling
      self$dt <- dt
      self$discontinuities <- discontinuities
      self$use_smoothing <- use_smoothing
      self$use_vectorized <- use_vectorized
      self$t_min <- t_range[1]
      self$t_max <- t_range[2]
      self$t_step <- t_range[3]
      super$initialize(...)
    },
    get_function = function() self$func,
    get_point_from_function = function(t) self$func(t),
    generate_points = function() {
      if (!is.null(self$discontinuities)) {
        d <- self$discontinuities[self$discontinuities >= self$t_min & self$discontinuities <= self$t_max]
        boundary_times <- sort(c(self$t_min, self$t_max, d - self$dt, d + self$dt))
      } else {
        boundary_times <- c(self$t_min, self$t_max)
      }
      for (k in seq(1, length(boundary_times) - 1, by = 2)) {
        t1 <- boundary_times[k]
        t2 <- boundary_times[k + 1]
        ts <- c(self$scaling$func(np_arange(t1, t2, self$t_step)), self$scaling$func(t2))
        points <- if (self$use_vectorized) vectorized_points(self$func(ts), length(ts))
          else t(vapply(ts, function(t) as_point(self$func(t)), numeric(3)))
        self$start_new_path(points[1, ])
        self$add_points_as_corners(points[-1, , drop = FALSE])
      }
      if (self$use_smoothing) self$make_smooth()
      invisible(self)
    },
    init_points = function() self$generate_points()
  )
)

# Turn the output of a vectorized point function of n values into an n x 3
# matrix. As upstream (`x, y, z = function(t)`), the output holds coordinate
# rows: a list(x, y[, z]) (a z that is not a vector of n values counts as 0),
# a 2 or 3 row matrix with n columns, or those rows concatenated with c().
# An n x 2 or n x 3 matrix of points is accepted only when it cannot be read
# as coordinate rows, so a square matrix (n = 2 or 3) is coordinate rows.
vectorized_points <- function(res, n) {
  if (is.list(res) && !is.matrix(res)) {
    z <- if (length(res) >= 3 && length(res[[3]]) == n) res[[3]] else rep(0, n)
    return(cbind(rep_len(res[[1]], n), rep_len(res[[2]], n), z))
  }
  if (is.null(dim(res)) && length(res) %in% (c(2, 3) * n)) res <- matrix(res, ncol = n, byrow = TRUE)
  if (length(dim(res)) == 2) {
    if (nrow(res) %in% 2:3 && ncol(res) == n) return(as_points(t(res)))
    if (ncol(res) %in% 2:3 && nrow(res) == n) return(as_points(res))
  }
  stop("A vectorized function must return 2 or 3 coordinate rows of ", n, " values each.", call. = FALSE)
}

#' @rdname function_graphs
#' @export
ParametricFunction <- constructor(ParametricFunctionClass)
#' @rdname function_graphs
#' @format NULL
#' @usage NULL
#' @export
FunctionGraphClass <- R6::R6Class("FunctionGraph", inherit = ParametricFunctionClass, lock_objects = FALSE,
  public = list(
    x_range = NULL,
    graph_function = NULL,
    initialize = function(func, x_range = NULL, color = PURE_YELLOW, ...) {
      x_range <- x_range %||% c(-frame_x_radius(), frame_x_radius())
      self$x_range <- x_range
      self$graph_function <- func
      super$initialize(function(t) c(t, func(t), 0), t_range = x_range, color = color, ...)
    },
    get_function = function() self$graph_function,
    get_point_from_function = function(x) self$func(x)
  )
)

#' @rdname function_graphs
#' @export
FunctionGraph <- constructor(FunctionGraphClass)
#' @rdname function_graphs
#' @format NULL
#' @usage NULL
#' @export
ImplicitFunctionClass <- R6::R6Class("ImplicitFunction", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    func = NULL,
    min_depth = 5,
    max_quads = 1500,
    use_smoothing = TRUE,
    x_range = NULL,
    y_range = NULL,
    initialize = function(func, x_range = NULL, y_range = NULL, min_depth = 5, max_quads = 1500,
                          use_smoothing = TRUE, ...) {
      self$func <- func
      self$min_depth <- min_depth
      self$max_quads <- max_quads
      self$use_smoothing <- use_smoothing
      self$x_range <- x_range %||% c(-frame_width() / 2, frame_width() / 2)
      self$y_range <- y_range %||% c(-frame_height() / 2, frame_height() / 2)
      super$initialize(...)
    },
    generate_points = function() {
      # ponytail: uniform grid plus grDevices::contourLines instead of the
      # adaptive quadtree of the isosurfaces package; raise max_quads for detail.
      n <- max(2^self$min_depth, ceiling(4 * sqrt(self$max_quads))) + 1
      xs <- seq(self$x_range[1], self$x_range[2], length.out = n)
      ys <- seq(self$y_range[1], self$y_range[2], length.out = n)
      gx <- rep(xs, times = n)
      gy <- rep(ys, each = n)
      vals <- tryCatch(as.numeric(self$func(gx, gy)), error = function(e) NULL)
      if (length(vals) != length(gx)) vals <- mapply(function(x, y) as.numeric(self$func(x, y)), gx, gy)
      z <- matrix(vals, n, n)
      z[!is.finite(z)] <- NA
      # Contour points are unevenly spaced, which makes the smoothing overshoot,
      # so resample them evenly at about the grid spacing.
      h <- min(diff(xs[1:2]), diff(ys[1:2]))
      for (curve in grDevices::contourLines(xs, ys, z, levels = 0)) {
        pts <- resample_polyline(cbind(curve$x, curve$y, 0), h)
        if (nrow(pts) < 2) next
        self$start_new_path(pts[1, ])
        self$add_points_as_corners(pts[-1, , drop = FALSE])
      }
      if (self$use_smoothing) self$make_smooth()
      invisible(self)
    },
    init_points = function() self$generate_points()
  )
)

#' @rdname function_graphs
#' @export
ImplicitFunction <- constructor(ImplicitFunctionClass)
# Resample a polyline at even arc length steps of about h, keeping both ends.
resample_polyline <- function(pts, h) {
  seg <- sqrt(rowSums(diff(pts)^2))
  cum <- c(0, cumsum(seg))
  total <- cum[length(cum)]
  keep <- c(TRUE, seg > 0)
  if (total == 0 || sum(keep) < 2) return(pts[1, , drop = FALSE])
  s <- seq(0, total, length.out = max(2, ceiling(total / h) + 1))
  cbind(stats::approx(cum[keep], pts[keep, 1], s)$y, stats::approx(cum[keep], pts[keep, 2], s)$y, 0)
}
