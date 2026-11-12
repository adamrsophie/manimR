# Point clouds of the OpenGL renderer, ported from
# manim/mobject/opengl/opengl_point_cloud_mobject.py and dot_cloud.py.
# Upstream draws them with the "true_dot" shader as round dots of radius
# stroke_width / 100; manimR draws the same dots with grid (see
# CameraClass$display_point_cloud()).

# Rounds to single precision, as upstream stores these points as float32.
as_float32 <- function(x) {
  d <- dim(x)
  y <- readBin(writeBin(as.vector(x), raw(), size = 4), "double", length(x), size = 4)
  if (!is.null(d)) dim(y) <- d
  y
}

#' OpenGL point clouds
#'
#' Point cloud mobjects of upstream's OpenGL renderer, drawn as round dots of
#' radius `stroke_width / 100` frame units (`point_radius`).
#'
#' * `OpenGLPMobject()` is an empty cloud; add points with `$add_points()`.
#'   As upstream, its color array starts with one row holding the mobject's
#'   color, and `$add_points()` appends one row per point.
#' * `OpenGLPGroup()` groups OpenGL point clouds.
#' * `OpenGLPMPoint()` is a single point at `location`.
#' * `DotCloud()` fills a disk of the given `radius` with concentric rings of
#'   dots spaced `1 / density` apart. `$make_3d()` stores the gloss and
#'   shadow that upstream's shader uses; they do not change manimR's
#'   drawing.
#' * `TrueDot()` is a `DotCloud`. Note that upstream overwrites its `center`
#'   and radius in `DotCloud`'s initializer, so a `TrueDot` is the default
#'   cloud of radius 2 at the origin; manimR keeps that behavior.
#'
#' @param stroke_width Dot diameter in hundredths of a frame unit.
#' @param color Color of the points.
#' @param location,center Position of the point.
#' @param radius Radius of the disk a `DotCloud` fills.
#' @param density Rings and dots per frame unit.
#' @param ... Further arguments passed to [PMobject()], or point clouds for
#'   `OpenGLPGroup()`.
#' @name opengl_point_cloud
#' @examples
#' cloud <- DotCloud(radius = 1, density = 8)
#' nrow(cloud$points)
NULL

#' @rdname opengl_point_cloud
#' @format NULL
#' @usage NULL
#' @export
OpenGLPMobjectClass <- R6::R6Class("OpenGLPMobject", inherit = PMobjectClass, lock_objects = FALSE,
  public = list(
    point_radius = 0.02,
    gloss = 0,
    shadow = 0,
    depth_test = FALSE,
    initialize = function(stroke_width = 2, color = PURE_YELLOW, ...) {
      super$initialize(stroke_width = stroke_width, color = color, ...)
      self$point_radius <- self$stroke_width * 0.01
    },
    init_colors = function(propagate_colors = TRUE) {
      self$rgbas <- matrix(color_to_rgba(self$color), 1, 4)
      invisible(self)
    },
    # Adds points with the colors `rgbas`, or one `color` (yellow when
    # neither is given) at `opacity`, which defaults to the opacity of the
    # last color row, as upstream.
    add_points = function(points, rgbas = NULL, color = NULL, opacity = NULL) {
      points <- as_points(points)
      n <- nrow(points)
      if (is.null(rgbas) && is.null(color)) color <- PURE_YELLOW
      if (!is.null(color)) {
        if (is.null(opacity)) opacity <- if (nrow(self$rgbas)) self$rgbas[nrow(self$rgbas), 4] else 1
        new_rgbas <- matrix(color_to_rgba(color, opacity), n, 4, byrow = TRUE)
      } else {
        new_rgbas <- as.matrix(rgbas)
        if (nrow(new_rgbas) != n) stop("points and rgbas must have same length", call. = FALSE)
      }
      self$points <- rbind(self$points, points)
      self$rgbas <- rbind(self$rgbas, new_rgbas)
      invisible(self)
    },
    set_gloss = function(gloss) {
      self$gloss <- gloss
      invisible(self)
    },
    set_shadow = function(shadow) {
      self$shadow <- shadow
      invisible(self)
    },
    apply_depth_test = function() {
      self$depth_test <- TRUE
      invisible(self)
    },
    get_mobject_type_class = function() OpenGLPMobjectClass,
    # The per point data upstream sends to its true_dot shader: positions and
    # RGBA colors, one row per point (colors stretched to the points).
    get_shader_data = function() {
      n <- nrow(self$points)
      list(point = self$points, color = stretch_rows(self$rgbas, n))
    }
  )
)

#' @rdname opengl_point_cloud
#' @export
OpenGLPMobject <- constructor(OpenGLPMobjectClass)

#' @rdname opengl_point_cloud
#' @format NULL
#' @usage NULL
#' @export
OpenGLPGroupClass <- R6::R6Class("OpenGLPGroup", inherit = OpenGLPMobjectClass, lock_objects = FALSE,
  public = list(
    initialize = function(...) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      pmobs <- flatten_mobjects(args[nm == ""])
      if (!all(vapply(pmobs, inherits, logical(1), what = "OpenGLPMobject"))) {
        stop("All submobjects must be of type OpenGLPMobject", call. = FALSE)
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

#' @rdname opengl_point_cloud
#' @export
OpenGLPGroup <- constructor(OpenGLPGroupClass)

#' @rdname opengl_point_cloud
#' @format NULL
#' @usage NULL
#' @export
OpenGLPMPointClass <- R6::R6Class("OpenGLPMPoint", inherit = OpenGLPMobjectClass, lock_objects = FALSE,
  public = list(
    location = NULL,
    initialize = function(location = ORIGIN, stroke_width = 4, ...) {
      self$location <- as_point(location)
      super$initialize(stroke_width = stroke_width, ...)
    },
    generate_points = function() {
      self$points <- as_float32(matrix(self$location, 1, 3))
      invisible(self)
    }
  )
)

#' @rdname opengl_point_cloud
#' @export
OpenGLPMPoint <- constructor(OpenGLPMPointClass)

#' @rdname opengl_point_cloud
#' @format NULL
#' @usage NULL
#' @export
DotCloudClass <- R6::R6Class("DotCloud", inherit = OpenGLPMobjectClass, lock_objects = FALSE,
  public = list(
    radius = 2,
    epsilon = 0.1,
    initialize = function(color = PURE_YELLOW, stroke_width = 2, radius = 2, density = 10, ...) {
      self$radius <- radius
      self$epsilon <- 1 / density
      super$initialize(stroke_width = stroke_width, color = color, ...)
    },
    # Rings at radii epsilon, 2 epsilon, ... below radius (numpy.arange),
    # each with int(2 pi (r + epsilon) / epsilon) dots spread over the full
    # circle, both ends included (numpy.linspace).
    generate_points = function() {
      eps <- self$epsilon
      n <- max(ceiling((self$radius - eps) / eps), 0)
      rs <- eps + (seq_len(n) - 1) * eps
      pts <- lapply(rs, function(r) {
        k <- as.integer(trunc(2 * pi * (r + eps) / eps))
        theta <- if (k == 1) 0 else seq(0, 2 * pi, length.out = k)
        cbind(r * cos(theta), r * sin(theta), 0)
      })
      self$points <- as_float32(do.call(rbind, c(list(matrix(0, 0, 3)), pts)))
      invisible(self)
    },
    make_3d = function(gloss = 0.5, shadow = 0.2) {
      self$set_gloss(gloss)
      self$set_shadow(shadow)
      self$apply_depth_test()
      invisible(self)
    }
  )
)

#' @rdname opengl_point_cloud
#' @export
DotCloud <- constructor(DotCloudClass)

#' @rdname opengl_point_cloud
#' @format NULL
#' @usage NULL
#' @export
TrueDotClass <- R6::R6Class("TrueDot", inherit = DotCloudClass, lock_objects = FALSE,
  public = list(
    initialize = function(center = ORIGIN, stroke_width = 2, ...) {
      self$radius <- stroke_width
      super$initialize(stroke_width = stroke_width, ...)
    }
  )
)

#' @rdname opengl_point_cloud
#' @export
TrueDot <- constructor(TrueDotClass)
