# Point cloud mobjects. Ported from manim/mobject/types/point_cloud_mobject.py.

# Repeat rows (or elements) of an array so it has `n` rows, like manim's
# stretch_array_to_length.
#' @rdname list_helpers
#' @export
stretch_array_to_length <- function(nparray, length) {
  n <- length
  cur <- if (is.matrix(nparray)) nrow(nparray) else base::length(nparray)
  if (cur > n) stop("Trying to stretch array to a length shorter than its own", call. = FALSE)
  idx <- ((0:(n - 1)) * cur) %/% n + 1
  if (is.matrix(nparray)) nparray[idx, , drop = FALSE] else nparray[idx]
}

#' @title Point cloud mobjects
#' @description `PMobject` is a mobject made of points drawn as small squares,
#'   each with its own color (the `rgbas` matrix, one row per point).
#'   `Mobject1D` and `Mobject2D` add a sampling `density`. `PGroup()` groups
#'   point clouds, `PointCloudDot()` is a disc filled with points and
#'   `Point()` is a single point.
#' @param stroke_width Drawn size of each point.
#' @param density Number of sample points per unit length (1D) or per unit
#'   area (2D).
#' @param center,radius Center and radius of the disc of points.
#' @param color Color of the points.
#' @param location Position of the point.
#' @param ... Further named arguments passed to [MobjectClass], or for
#'   `PGroup()` the point cloud mobjects to group.
#' @name point_cloud
#' @examples
#' cloud <- PointCloudDot(radius = 1, density = 20, color = BLUE)
#' cloud$thin_out(2)
#' g <- PGroup(PointCloudDot(), Point(RIGHT))
NULL

#' @rdname point_cloud
#' @format NULL
#' @usage NULL
#' @export
PMobjectClass <- R6::R6Class("PMobject", inherit = MobjectClass, lock_objects = FALSE,
  public = list(
    rgbas = NULL,
    stroke_width = DEFAULT_STROKE_WIDTH,
    initialize = function(stroke_width = DEFAULT_STROKE_WIDTH, ...) {
      self$stroke_width <- stroke_width
      super$initialize(...)
    },
    reset_points = function() {
      self$rgbas <- matrix(0, 0, 4)
      self$points <- matrix(0, 0, 3)
      invisible(self)
    },
    get_array_attrs = function() c("points", "rgbas"),
    get_mobject_type_class = function() PMobjectClass,
    apply_over_attr_arrays = function(func) {
      for (attr in self$get_array_attrs()) self[[attr]] <- func(self[[attr]])
      invisible(self)
    },
    add_points = function(points, rgbas = NULL, color = NULL, alpha = 1) {
      points <- as_points(points)
      n <- nrow(points)
      if (is.null(rgbas)) {
        col <- if (is.null(color)) self$color else manim_color(color)
        rgbas <- matrix(color_to_rgba(col, alpha), n, 4, byrow = TRUE)
      } else {
        rgbas <- as.matrix(rgbas)
        if (nrow(rgbas) != n) stop("points and rgbas must have same length", call. = FALSE)
      }
      self$points <- rbind(self$points, points)
      self$rgbas <- rbind(self$rgbas, rgbas)
      invisible(self)
    },
    set_color = function(color = PURE_YELLOW, family = TRUE) {
      rgba <- color_to_rgba(color)
      mobs <- if (family) self$family_members_with_points() else list(self)
      for (m in mobs) {
        if (!is.null(m$rgbas) && nrow(m$rgbas)) m$rgbas <- matrix(rgba, nrow(m$rgbas), 4, byrow = TRUE)
      }
      self$color <- manim_color(color)
      invisible(self)
    },
    get_stroke_width = function() self$stroke_width,
    set_stroke_width = function(width, family = TRUE) {
      mobs <- if (family) self$family_members_with_points() else list(self)
      for (m in mobs) m$stroke_width <- width
      invisible(self)
    },
    set_color_by_gradient = function(...) {
      cols <- color_gradient(unlist(list(...)), nrow(self$points))
      self$rgbas <- matrix(unlist(lapply(cols, color_to_rgba)), ncol = 4, byrow = TRUE)
      invisible(self)
    },
    set_colors_by_radial_gradient = function(center = NULL, radius = 1, inner_color = WHITE, outer_color = BLACK) {
      start_rgba <- color_to_rgba(inner_color)
      end_rgba <- color_to_rgba(outer_color)
      if (is.null(center)) center <- self$get_center()
      center <- as_point(center)
      # Upstream measures self$points for every family member; using each
      # member's own points is the same for a single cloud and correct for groups.
      for (m in self$family_members_with_points()) {
        d <- sweep(m$points, 2, center)
        alphas <- sqrt(rowSums(d^2)) / radius
        m$rgbas <- t(vapply(alphas, function(a) interpolate(start_rgba, end_rgba, a), numeric(4)))
      }
      invisible(self)
    },
    match_colors = function(mobject) {
      self$align_data(mobject)
      self$rgbas <- mobject$rgbas
      invisible(self)
    },
    filter_out = function(condition) {
      for (m in self$family_members_with_points()) {
        keep <- !vapply(seq_len(nrow(m$points)), function(i) isTRUE(condition(m$points[i, ])), logical(1))
        m$points <- m$points[keep, , drop = FALSE]
        m$rgbas <- m$rgbas[keep, , drop = FALSE]
      }
      invisible(self)
    },
    thin_out = function(factor = 5) {
      for (m in self$family_members_with_points()) {
        n <- m$get_num_points()
        idx <- seq(1, n, by = factor)
        m$apply_over_attr_arrays(function(arr) arr[idx, , drop = FALSE])
      }
      invisible(self)
    },
    sort_points = function(fn = function(p) p[1]) {
      for (m in self$family_members_with_points()) {
        idx <- order(apply(m$points, 1, fn))
        m$apply_over_attr_arrays(function(arr) arr[idx, , drop = FALSE])
      }
      invisible(self)
    },
    fade_to = function(color, alpha, family = TRUE) {
      target <- color_to_rgba(color)
      if (nrow(self$rgbas)) self$rgbas <- self$rgbas + alpha * (rep(target, each = nrow(self$rgbas)) - self$rgbas)
      for (m in self$submobjects) m$fade_to(color, alpha, family)
      invisible(self)
    },
    get_all_rgbas = function() self$get_merged_array("rgbas"),
    ingest_submobjects = function() {
      for (attr in self$get_array_attrs()) {
        arr <- self$get_merged_array(attr)
        self[[attr]] <- if (is.null(arr)) matrix(0, 0, if (attr == "rgbas") 4 else 3) else arr
      }
      self$submobjects <- list()
      invisible(self)
    },
    get_color = function() {
      if (is.null(self$rgbas) || nrow(self$rgbas) == 0) return(self$color)
      rgba_to_color(self$rgbas[1, ])
    },
    point_from_proportion = function(alpha) {
      index <- alpha * (self$get_num_points() - 1)
      self$points[floor(index) + 1, ]
    },
    align_points_with_larger = function(larger_mobject) {
      if (!inherits(larger_mobject, "PMobject")) stop("Expected a PMobject.", call. = FALSE)
      n <- larger_mobject$get_num_points()
      self$apply_over_attr_arrays(function(a) stretch_array_to_length(a, n))
    },
    get_point_mobject = function(center = NULL) Point(center %||% self$get_center()),
    interpolate_color = function(mobject1, mobject2, alpha) {
      self$rgbas <- interpolate(mobject1$rgbas, mobject2$rgbas, alpha)
      self$set_stroke_width(interpolate(mobject1$get_stroke_width(), mobject2$get_stroke_width(), alpha))
      invisible(self)
    },
    pointwise_become_partial = function(mobject, a, b) {
      n <- mobject$get_num_points()
      lower <- as.integer(a * n)
      upper <- as.integer(b * n)
      idx <- if (upper > lower) (lower + 1):upper else integer()
      for (attr in self$get_array_attrs()) self[[attr]] <- mobject[[attr]][idx, , drop = FALSE]
      invisible(self)
    }
  )
)

#' @rdname point_cloud
#' @export
PMobject <- constructor(PMobjectClass)
#' @rdname point_cloud
#' @format NULL
#' @usage NULL
#' @export
Mobject1DClass <- R6::R6Class("Mobject1D", inherit = PMobjectClass, lock_objects = FALSE,
  public = list(
    density = DEFAULT_POINT_DENSITY_1D,
    epsilon = 0.1,
    initialize = function(density = DEFAULT_POINT_DENSITY_1D, ...) {
      self$density <- density
      self$epsilon <- 1 / density
      super$initialize(...)
    },
    add_line = function(start, end, color = NULL) {
      start <- as_point(start)
      end <- as_point(end)
      len <- get_norm(end - start)
      points <- if (len == 0) matrix(start, 1) else {
        eps <- self$epsilon / len
        ts <- (0:(ceiling(1 / eps) - 1)) * eps
        t(vapply(ts, function(t) interpolate(start, end, t), numeric(3)))
      }
      self$add_points(points, color = color)
    }
  )
)

#' @rdname point_cloud
#' @export
Mobject1D <- constructor(Mobject1DClass)
#' @rdname point_cloud
#' @format NULL
#' @usage NULL
#' @export
Mobject2DClass <- R6::R6Class("Mobject2D", inherit = PMobjectClass, lock_objects = FALSE,
  public = list(
    density = DEFAULT_POINT_DENSITY_2D,
    epsilon = 0.04,
    initialize = function(density = DEFAULT_POINT_DENSITY_2D, ...) {
      self$density <- density
      self$epsilon <- 1 / density
      super$initialize(...)
    }
  )
)

#' @rdname point_cloud
#' @export
Mobject2D <- constructor(Mobject2DClass)
#' @rdname point_cloud
#' @format NULL
#' @usage NULL
#' @export
PGroupClass <- R6::R6Class("PGroup", inherit = PMobjectClass, lock_objects = FALSE,
  public = list(
    initialize = function(...) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      pmobs <- flatten_mobjects(args[nm == ""])
      if (!all(vapply(pmobs, inherits, logical(1), what = "PMobject"))) {
        stop("All submobjects must be of type PMobject", call. = FALSE)
      }
      do.call(super$initialize, args[nm != ""])
      self$add(pmobs)
    },
    fade_to = function(color, alpha, family = TRUE) {
      if (family) for (m in self$submobjects) m$fade_to(color, alpha, family)
      invisible(self)
    }
  )
)

#' @rdname point_cloud
#' @export
PGroup <- constructor(PGroupClass)
#' @rdname point_cloud
#' @format NULL
#' @usage NULL
#' @export
PointCloudDotClass <- R6::R6Class("PointCloudDot", inherit = Mobject1DClass, lock_objects = FALSE,
  public = list(
    radius = 2,
    initialize = function(center = ORIGIN, radius = 2, stroke_width = 2, density = DEFAULT_POINT_DENSITY_1D,
                          color = PURE_YELLOW, ...) {
      self$radius <- radius
      self$epsilon <- 1 / density
      super$initialize(stroke_width = stroke_width, density = density, color = color, ...)
      self$shift(center)
    },
    generate_points = function() {
      eps <- self$epsilon
      # np.arange(eps, radius, eps)
      n_r <- max(0, ceiling((self$radius - eps) / eps))
      rs <- eps + (seq_len(n_r) - 1) * eps
      pts <- lapply(rs, function(r) {
        num <- as.integer(2 * pi * (r + eps) / eps)
        theta <- if (num == 1) 0 else seq(0, 2 * pi, length.out = num)
        cbind(r * cos(theta), r * sin(theta), 0)
      })
      pts <- do.call(rbind, pts)
      if (!is.null(pts)) self$add_points(pts)
      invisible(self)
    }
  )
)

#' @rdname point_cloud
#' @export
PointCloudDot <- constructor(PointCloudDotClass)
#' @rdname point_cloud
#' @format NULL
#' @usage NULL
#' @export
PointClass <- R6::R6Class("Point", inherit = PMobjectClass, lock_objects = FALSE,
  public = list(
    location = NULL,
    initialize = function(location = ORIGIN, color = BLACK, ...) {
      self$location <- as_point(location)
      super$initialize(color = color, ...)
    },
    generate_points = function() {
      self$add_points(matrix(self$location, 1))
    }
  )
)

#' @rdname point_cloud
#' @export
Point <- constructor(PointClass)