# Three dimensional mobjects. Ported from manim/mobject/three_d/three_dimensions.py
# and manim/mobject/three_d/three_d_utils.py.

# 3D utilities ---------------------------------------------------------------
# Corner indices are computed 0 based as upstream and shifted when indexing.

#' Corners and normals of 3D VMobjects
#'
#' Helpers that the 3D camera uses to shade a [VMobject()] face.
#'
#' * `get_3d_vmob_start_corner_index()` and `get_3d_vmob_end_corner_index()`
#'   return the row of `vmob$points` holding the start and end corner. **These
#'   indices are 0 based**, as upstream: the corner is
#'   `vmob$points[index + 1, ]`.
#' * `get_3d_vmob_start_corner()` and `get_3d_vmob_end_corner()` return those
#'   points (`ORIGIN` for an empty mobject), and
#'   `get_3d_vmob_gradient_start_and_end_points()` returns both as a list.
#' * `get_3d_vmob_unit_normal()` returns the unit normal at the 0 based point
#'   index `point_index`, from the anchors three rows before and after it
#'   (wrapping around). It returns `UP` for mobjects with two anchors or
#'   fewer. `get_3d_vmob_start_corner_unit_normal()` and
#'   `get_3d_vmob_end_corner_unit_normal()` evaluate it at the corners.
#'
#' @param vmob A VMobject.
#' @param point_index A 0 based row index into `vmob$points`.
#' @return An integer index, a point, a list of two points, or a unit vector.
#' @export
#' @examples
#' sq <- Square()$rotate(PI / 3, axis = RIGHT)
#' get_3d_vmob_end_corner_index(sq) # 0 based
#' get_3d_vmob_end_corner(sq)
#' get_3d_vmob_start_corner_unit_normal(sq)
get_3d_vmob_start_corner_index <- function(vmob) 0L

#' @rdname get_3d_vmob_start_corner_index
#' @export
get_3d_vmob_end_corner_index <- function(vmob) ((nrow(vmob$points) - 1) %/% 6) * 3

#' @rdname get_3d_vmob_start_corner_index
#' @export
get_3d_vmob_start_corner <- function(vmob) {
  if (vmob$get_num_points() == 0) return(ORIGIN)
  vmob$points[get_3d_vmob_start_corner_index(vmob) + 1, ]
}

#' @rdname get_3d_vmob_start_corner_index
#' @export
get_3d_vmob_end_corner <- function(vmob) {
  if (vmob$get_num_points() == 0) return(ORIGIN)
  vmob$points[get_3d_vmob_end_corner_index(vmob) + 1, ]
}

#' @rdname get_3d_vmob_start_corner_index
#' @export
get_3d_vmob_gradient_start_and_end_points <- function(vmob) {
  list(get_3d_vmob_start_corner(vmob), get_3d_vmob_end_corner(vmob))
}

#' @rdname get_3d_vmob_start_corner_index
#' @export
get_3d_vmob_unit_normal <- function(vmob, point_index) {
  n_points <- vmob$get_num_points()
  # Upstream tests len(get_anchors()) <= 2, which holds exactly when there
  # are fewer than 8 points; counting rows avoids building the anchors.
  if (n_points < 8) return(UP)
  i <- point_index
  im3 <- if (i > 2) i - 3 else n_points - 4
  ip3 <- if (i < n_points - 3) i + 3 else 3
  p <- vmob$points
  unit_normal <- get_unit_normal(p[ip3 + 1, ] - p[i + 1, ], p[im3 + 1, ] - p[i + 1, ])
  if (get_norm(unit_normal) == 0) return(UP)
  unit_normal
}

#' @rdname get_3d_vmob_start_corner_index
#' @export
get_3d_vmob_start_corner_unit_normal <- function(vmob) {
  get_3d_vmob_unit_normal(vmob, get_3d_vmob_start_corner_index(vmob))
}

#' @rdname get_3d_vmob_start_corner_index
#' @export
get_3d_vmob_end_corner_unit_normal <- function(vmob) {
  get_3d_vmob_unit_normal(vmob, get_3d_vmob_end_corner_index(vmob))
}

#' Shade a color by its orientation to a light
#'
#' Adds light (or shadow) to `rgb` for a surface at `point` facing
#' `unit_normal_vect`, depending on whether it faces `light_source`. The
#' result is not clipped.
#' @param rgb Numeric RGB in `[0, 1]`.
#' @param point,unit_normal_vect,light_source Length 3 vectors.
#' @return Numeric RGB.
#' @export
get_shaded_rgb <- function(rgb, point, unit_normal_vect, light_source) {
  to_sun <- normalize(light_source - point)
  light <- 0.5 * sum(unit_normal_vect * to_sun)^3
  if (light < 0) light <- light * 0.5
  rgb + light
}

# Mobjects --------------------------------------------------------------------

#' @title Three dimensional mobjects
#' @description
#' * `ThreeDVMobject()`: a [VMobject()] with `shade_in_3d = TRUE`.
#' * `Surface(func, u_range, v_range, resolution)`: a parametric surface
#'   `func(u, v)` (returning a length 3 point) made of checkerboard faces.
#'   `set_fill_by_checkerboard(...)` recolors the faces and
#'   `set_fill_by_value(axes, colorscale, axis)` colors them by a coordinate
#'   (`axis` 1, 2 or 3 for x, y, z).
#' * `Sphere()`, `Dot3D()`, `Cone()`, `Cylinder()`, `Line3D()`, `Arrow3D()`
#'   and `Torus()` are surfaces; `Cube()` and `Prism()` are groups of square faces.
#' @param shade_in_3d Shade the faces according to their orientation to the
#'   light source.
#' @param func Function of `(u, v)` returning a point.
#' @param u_range,v_range Ranges `c(min, max)` of the `u` and `v` parameters.
#' @param resolution Number of faces along `u` and `v`: one value or
#'   `c(u, v)`; `NULL` uses the class default (for `Sphere()`, `c(24, 12)`,
#'   or `c(101, 51)` under `manim_config(renderer = "opengl")`; for
#'   `Torus()`, `c(24, 24)`, or `c(101, 101)` under it, as upstream).
#' @param surface_piece_config List of extra arguments for each face.
#' @param fill_color,fill_opacity Fill color and opacity of the faces.
#' @param checkerboard_colors Colors alternated across the faces; `FALSE`
#'   keeps `fill_color`.
#' @param stroke_color,stroke_width Color and width of the face outlines.
#' @param should_make_jagged Change the anchor mode of the curves from smooth
#'   to jagged.
#' @param pre_function_handle_to_anchor_scale_factor Kept for compatibility
#'   with Manim.
#' @param center,radius Center and radius of a sphere, dot or cylinder.
#' @param point Center of the dot; for `Line3D_parallel_to()` and
#'   `Line3D_perpendicular_to()`, the point the new line passes through.
#' @param color Color of the mobject.
#' @param side_length Side length of the cube.
#' @param dimensions Side lengths of the prism along x, y and z.
#' @param base_radius Radius of the base of a cone or arrow tip.
#' @param height Height of a cone or cylinder, or length of the arrow tip.
#' @param direction Direction the cone or cylinder points along.
#' @param show_base Draw the base disc of the cone.
#' @param u_min Radius at the apex of the cone.
#' @param show_ends Draw the end caps of the cylinder.
#' @param start,end Start and end points of the line or arrow; they may be
#'   mobjects.
#' @param thickness Thickness of the line or arrow shaft.
#' @param major_radius,minor_radius Distance from the center of the torus to
#'   the center of its tube, and the radius of the tube.
#' @param ... Other named arguments, passed to [VMobject()].
#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @name three_dimensions
#' @examples
#' s <- Sphere(radius = 1.5, resolution = c(12, 6))
#' cube <- Cube(side_length = 2, fill_color = RED)
#' surf <- Surface(function(u, v) c(u, v, sin(u) * cos(v)),
#'                 u_range = c(-2, 2), v_range = c(-2, 2), resolution = 8)
NULL

#' @rdname three_dimensions
#' @format NULL
#' @usage NULL
#' @export
ThreeDVMobjectClass <- R6::R6Class("ThreeDVMobject", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    u_index = NULL, v_index = NULL, u1 = NULL, u2 = NULL, v1 = NULL, v2 = NULL,
    initialize = function(shade_in_3d = TRUE, ...) super$initialize(shade_in_3d = shade_in_3d, ...),
    get_gradient_start_and_end_points = function() {
      if (isTRUE(self$shade_in_3d)) get_3d_vmob_gradient_start_and_end_points(self)
      else super$get_gradient_start_and_end_points()
    }
  )
)

#' @rdname three_dimensions
#' @export
ThreeDVMobject <- constructor(ThreeDVMobjectClass)
#' @rdname three_dimensions
#' @format NULL
#' @usage NULL
#' @export
SurfaceClass <- R6::R6Class("Surface", inherit = VGroupClass, lock_objects = FALSE,
  public = list(
    u_range = NULL,
    v_range = NULL,
    resolution = 32,
    surface_piece_config = NULL,
    checkerboard_colors = NULL,
    should_make_jagged = FALSE,
    list_of_faces = NULL,
    uv_func = NULL,
    initialize = function(func = NULL, u_range = c(0, 1), v_range = c(0, 1), resolution = 32,
                          surface_piece_config = list(), fill_color = BLUE_D, fill_opacity = 1,
                          checkerboard_colors = c(BLUE_D, BLUE_E), stroke_color = LIGHT_GREY, stroke_width = 0.5,
                          should_make_jagged = FALSE, pre_function_handle_to_anchor_scale_factor = 0.00001, ...) {
      self$u_range <- u_range
      self$v_range <- v_range
      super$initialize(fill_color = fill_color, fill_opacity = fill_opacity, stroke_color = stroke_color,
                       stroke_width = stroke_width, ...)
      self$resolution <- resolution
      self$surface_piece_config <- surface_piece_config
      self$checkerboard_colors <- if (isFALSE(checkerboard_colors)) FALSE
                                  else vapply(unlist(checkerboard_colors), manim_color, "")
      self$should_make_jagged <- should_make_jagged
      self$pre_function_handle_to_anchor_scale_factor <- pre_function_handle_to_anchor_scale_factor
      self$list_of_faces <- list()
      self$uv_func <- func
      self$setup_in_uv_space(fill_color, fill_opacity, stroke_color, stroke_width)
      self$apply_function(function(p) self$func(p[1], p[2]))
      if (self$should_make_jagged) self$make_jagged()
    },
    func = function(u, v) self$uv_func(u, v),
    get_u_values_and_v_values = function() {
      res <- rep_len(self$resolution, 2)
      list(seq(self$u_range[1], self$u_range[2], length.out = res[1] + 1),
           seq(self$v_range[1], self$v_range[2], length.out = res[2] + 1))
    },
    setup_in_uv_space = function(fill_color, fill_opacity, stroke_color, stroke_width) {
      uv <- self$get_u_values_and_v_values()
      u_values <- uv[[1]]
      v_values <- uv[[2]]
      faces <- list()
      for (i in seq_len(length(u_values) - 1)) {
        for (j in seq_len(length(v_values) - 1)) {
          u1 <- u_values[i]; u2 <- u_values[i + 1]
          v1 <- v_values[j]; v2 <- v_values[j + 1]
          face <- ThreeDVMobject()
          face$set_points_as_corners(rbind(c(u1, v1, 0), c(u2, v1, 0), c(u2, v2, 0), c(u1, v2, 0), c(u1, v1, 0)))
          # Indices stay 0 based as upstream; only their parity matters.
          face$u_index <- i - 1
          face$v_index <- j - 1
          face$u1 <- u1; face$u2 <- u2; face$v1 <- v1; face$v2 <- v2
          faces[[length(faces) + 1]] <- face
        }
      }
      group <- VGroup(faces)
      group$set_fill(color = fill_color, opacity = fill_opacity)
      group$set_stroke(color = stroke_color, width = stroke_width, opacity = self$stroke_opacity)
      self$list_of_faces <- faces
      self$add(faces)
      if (!isFALSE(self$checkerboard_colors)) do.call(self$set_fill_by_checkerboard, as.list(self$checkerboard_colors))
      invisible(self)
    },
    set_fill_by_checkerboard = function(..., opacity = NULL) {
      colors <- unlist(list(...))
      n <- length(colors)
      for (face in self$list_of_faces) {
        face$set_fill(colors[(face$u_index + face$v_index) %% n + 1], opacity = opacity)
      }
      invisible(self)
    },
    set_fill_by_value = function(axes, colorscale = NULL, axis = 3, ...) {
      extra <- list(...)
      if (!is.null(extra$colors) && is.null(colorscale)) {
        colorscale <- extra$colors
        extra$colors <- NULL
        if (length(extra)) stop("Unsupported keyword argument(s): ", paste(names(extra), collapse = ", "), call. = FALSE)
      }
      if (is.null(colorscale)) {
        warning("The value passed to the colorscale keyword argument was NULL, ",
                "the surface fill color has not been changed", call. = FALSE)
        return(invisible(self))
      }
      if (is.list(colorscale) && length(colorscale[[1]]) == 2) {
        new_colors <- vapply(colorscale, function(cp) manim_color(cp[[1]]), "")
        pivots <- vapply(colorscale, function(cp) as.numeric(cp[[2]]), numeric(1))
      } else {
        new_colors <- vapply(unlist(colorscale), manim_color, "")
        current_range <- list(axes$x_range, axes$y_range, axes$z_range)[[axis]]
        pivot_frequency <- (current_range[2] - current_range[1]) / (length(new_colors) - 1)
        pivots <- current_range[1] + (seq_along(new_colors) - 1) * pivot_frequency
      }
      for (mob in self$family_members_with_points()) {
        axis_value <- axes$point_to_coords(mob$get_midpoint())[axis]
        if (axis_value <= pivots[1]) {
          mob$set_color(new_colors[1])
        } else if (axis_value >= pivots[length(pivots)]) {
          mob$set_color(new_colors[length(new_colors)])
        } else {
          i <- which(pivots > axis_value)[1]
          color_index <- min((axis_value - pivots[i - 1]) / (pivots[i] - pivots[i - 1]), 1)
          mob$set_color(interpolate_color(new_colors[i - 1], new_colors[i], color_index), family = FALSE)
        }
      }
      invisible(self)
    }
  )
)

#' @rdname three_dimensions
#' @export
Surface <- constructor(SurfaceClass)
#' @rdname three_dimensions
#' @format NULL
#' @usage NULL
#' @export
SphereClass <- R6::R6Class("Sphere", inherit = SurfaceClass, lock_objects = FALSE,
  public = list(
    radius = 1,
    initialize = function(center = ORIGIN, radius = 1, resolution = NULL, u_range = c(0, TAU), v_range = c(0, PI), ...) {
      self$radius <- radius
      super$initialize(func = NULL, resolution = resolution %||% if (identical(cfg("renderer"), RendererType$OPENGL)) c(101, 51) else c(24, 12), u_range = u_range, v_range = v_range, ...)
      self$shift(center)
    },
    func = function(u, v) self$radius * c(cos(u) * sin(v), sin(u) * sin(v), -cos(v))
  )
)

#' @rdname three_dimensions
#' @export
Sphere <- constructor(SphereClass)
#' @rdname three_dimensions
#' @format NULL
#' @usage NULL
#' @export
Dot3DClass <- R6::R6Class("Dot3D", inherit = SphereClass, lock_objects = FALSE,
  public = list(
    initialize = function(point = ORIGIN, radius = DEFAULT_DOT_RADIUS, color = WHITE, resolution = c(8, 8), ...) {
      super$initialize(center = point, radius = radius, resolution = resolution, ...)
      self$set_color(color)
    }
  )
)

#' @rdname three_dimensions
#' @export
Dot3D <- constructor(Dot3DClass)
#' @rdname three_dimensions
#' @format NULL
#' @usage NULL
#' @export
CubeClass <- R6::R6Class("Cube", inherit = VGroupClass, lock_objects = FALSE,
  public = list(
    side_length = 2,
    initialize = function(side_length = 2, fill_opacity = 0.75, fill_color = BLUE, stroke_width = 0, ...) {
      self$side_length <- side_length
      super$initialize(fill_color = fill_color, fill_opacity = fill_opacity, stroke_width = stroke_width, ...)
    },
    generate_points = function() {
      for (vect in list(IN, OUT, LEFT, RIGHT, UP, DOWN)) {
        face <- Square(side_length = self$side_length, shade_in_3d = TRUE, joint_type = "bevel")
        face$flip()
        face$shift(self$side_length * OUT / 2)
        face$apply_matrix(z_to_vector(vect))
        self$add(face)
      }
      invisible(self)
    }
  )
)

#' @rdname three_dimensions
#' @export
Cube <- constructor(CubeClass)
#' @rdname three_dimensions
#' @format NULL
#' @usage NULL
#' @export
PrismClass <- R6::R6Class("Prism", inherit = CubeClass, lock_objects = FALSE,
  public = list(
    dimensions = NULL,
    initialize = function(dimensions = c(3, 2, 1), ...) {
      self$dimensions <- dimensions
      super$initialize(...)
    },
    generate_points = function() {
      super$generate_points()
      for (dim in seq_along(self$dimensions)) self$rescale_to_fit(self$dimensions[dim], dim, stretch = TRUE)
      invisible(self)
    }
  )
)

#' @rdname three_dimensions
#' @export
Prism <- constructor(PrismClass)
# Rotation that points the z axis of a cone or cylinder along `direction`,
# undoing the previous one. Shared by Cone and Cylinder as upstream duplicates it.
rotate_to_direction <- function(self) {
  d <- as_point(self$direction)
  x <- d[1]; y <- d[2]; z <- d[3]
  r <- sqrt(x^2 + y^2 + z^2)
  theta <- if (r > 0) acos(z / r) else 0
  if (x == 0) {
    if (y == 0) {
      phi <- 0
    } else {
      phi <- atan(Inf)
      if (y < 0) phi <- phi + PI
    }
  } else {
    phi <- atan(y / x)
  }
  if (x < 0) phi <- phi + PI
  self$rotate(-self$current_phi, Z_AXIS, about_point = ORIGIN)
  self$rotate(-self$current_theta, Y_AXIS, about_point = ORIGIN)
  self$rotate(theta, Y_AXIS, about_point = ORIGIN)
  self$rotate(phi, Z_AXIS, about_point = ORIGIN)
  self$current_theta <- theta
  self$current_phi <- phi
  invisible(self)
}

#' @rdname three_dimensions
#' @format NULL
#' @usage NULL
#' @export
ConeClass <- R6::R6Class("Cone", inherit = SurfaceClass, lock_objects = FALSE,
  public = list(
    direction = NULL,
    theta = NULL,
    new_height = NULL,
    current_theta = 0,
    current_phi = 0,
    base_circle = NULL,
    start_point = NULL,
    end_point = NULL,
    initialize = function(base_radius = 1, height = 1, direction = Z_AXIS, show_base = FALSE, v_range = c(0, TAU),
                          u_min = 0, checkerboard_colors = FALSE, ...) {
      self$direction <- as_point(direction)
      self$theta <- PI - atan(base_radius / height)
      super$initialize(func = NULL, v_range = v_range, u_range = c(u_min, sqrt(base_radius^2 + height^2)),
                       checkerboard_colors = checkerboard_colors, ...)
      self$new_height <- height
      self$current_theta <- 0
      self$current_phi <- 0
      self$base_circle <- Circle(radius = base_radius, color = self$get_fill_color(),
                                 fill_opacity = self$fill_opacity, stroke_width = 0)
      self$base_circle$shift(height * IN)
      self$set_start_and_end_attributes(direction)
      if (show_base) self$add(self$base_circle)
      rotate_to_direction(self)
    },
    func = function(u, v) {
      r <- u
      phi <- v
      c(r * sin(self$theta) * cos(phi), r * sin(self$theta) * sin(phi), r * cos(self$theta))
    },
    get_start = function() self$start_point$get_center(),
    get_end = function() self$end_point$get_center(),
    set_direction = function(direction) {
      self$direction <- as_point(direction)
      rotate_to_direction(self)
    },
    get_direction = function() self$direction,
    set_start_and_end_attributes = function(direction) {
      direction <- as_point(direction)
      # Upstream multiplies by the norm here (not divides); kept as is.
      normalized_direction <- direction * get_norm(direction)
      start <- self$base_circle$get_center()
      end <- start + normalized_direction * self$new_height
      self$start_point <- VectorizedPoint(start)
      self$end_point <- VectorizedPoint(end)
      self$add(self$start_point, self$end_point)
      invisible(self)
    }
  )
)

#' @rdname three_dimensions
#' @export
Cone <- constructor(ConeClass)
#' @rdname three_dimensions
#' @format NULL
#' @usage NULL
#' @export
CylinderClass <- R6::R6Class("Cylinder", inherit = SurfaceClass, lock_objects = FALSE,
  public = list(
    cylinder_height = 2,
    radius = 1,
    direction = NULL,
    current_theta = 0,
    current_phi = 0,
    base_top = NULL,
    base_bottom = NULL,
    initialize = function(radius = 1, height = 2, direction = Z_AXIS, v_range = c(0, TAU), show_ends = TRUE,
                          resolution = c(24, 24), ...) {
      self$cylinder_height <- height
      self$radius <- radius
      super$initialize(func = NULL, resolution = resolution, u_range = c(-height / 2, height / 2),
                       v_range = v_range, ...)
      if (show_ends) self$add_bases()
      self$current_phi <- 0
      self$current_theta <- 0
      self$set_direction(direction)
    },
    func = function(u, v) c(self$radius * cos(v), self$radius * sin(v), u),
    add_bases = function() {
      color <- self$get_fill_color()
      opacity <- self$fill_opacity
      self$base_top <- Circle(radius = self$radius, color = color, fill_opacity = opacity, shade_in_3d = TRUE,
                              stroke_width = 0)
      self$base_top$shift(self$u_range[2] * IN)
      self$base_bottom <- Circle(radius = self$radius, color = color, fill_opacity = opacity, shade_in_3d = TRUE,
                                 stroke_width = 0)
      self$base_bottom$shift(self$u_range[1] * IN)
      self$add(self$base_top, self$base_bottom)
      invisible(self)
    },
    set_direction = function(direction) {
      self$direction <- as_point(direction)
      rotate_to_direction(self)
    },
    get_direction = function() self$direction
  )
)

#' @rdname three_dimensions
#' @export
Cylinder <- constructor(CylinderClass)
#' @rdname three_dimensions
#' @format NULL
#' @usage NULL
#' @export
Line3DClass <- R6::R6Class("Line3D", inherit = CylinderClass, lock_objects = FALSE,
  public = list(
    thickness = 0.02,
    vect = NULL,
    length = NULL,
    start = NULL,
    end = NULL,
    initialize = function(start = LEFT, end = RIGHT, thickness = 0.02, color = NULL, resolution = 24, ...) {
      self$thickness <- thickness
      self$resolution <- if (length(resolution) == 1) c(2, resolution) else resolution
      self$set_start_and_end_attrs(start, end, ...)
      if (!is.null(color)) self$set_color(color)
    },
    # Builds the cylinder between the two points; like upstream this runs
    # the Cylinder initializer again, so calling it rebuilds the line.
    set_start_and_end_attrs = function(start, end, ...) {
      rough_start <- self$pointify(start)
      rough_end <- self$pointify(end)
      self$vect <- rough_end - rough_start
      self$length <- get_norm(self$vect)
      self$direction <- normalize(self$vect)
      self$start <- self$pointify(start, self$direction)
      self$end <- self$pointify(end, -self$direction)
      super$initialize(height = get_norm(self$vect), radius = self$thickness, direction = self$direction,
                       resolution = self$resolution, ...)
      self$shift((self$start + self$end) / 2)
      invisible(self)
    },
    pointify = function(mob_or_point, direction = NULL) {
      if (is_mobject(mob_or_point)) {
        if (is.null(direction)) return(mob_or_point$get_center())
        return(mob_or_point$get_boundary_point(direction))
      }
      as_point(mob_or_point)
    },
    get_start = function() self$start,
    get_end = function() self$end
  )
)

#' @rdname three_dimensions
#' @export
Line3D <- constructor(Line3DClass)
#' @rdname three_dimensions
#' @param line A `Line3D()`.
#' @param length Length of the new line.
#' @param cls Constructor for the new line.
#' @details `Line3D_parallel_to()` and `Line3D_perpendicular_to()` port the
#'   upstream class methods `Line3D.parallel_to()` and
#'   `Line3D.perpendicular_to()`: a line of `length` through `point`.
#' @export
Line3D_parallel_to <- function(line, point = ORIGIN, length = 5, cls = Line3D, ...) {
  point <- as_point(point)
  vect <- normalize(line$vect)
  cls(point + vect * length / 2, point - vect * length / 2, ...)
}

#' @rdname three_dimensions
#' @export
Line3D_perpendicular_to <- function(line, point = ORIGIN, length = 5, cls = Line3D, ...) {
  point <- as_point(point)
  norm <- cross(line$vect, point - line$start)
  if (all(norm == 0)) stop("Could not find the perpendicular.", call. = FALSE)
  ends <- perpendicular_bisector(list(line$start, line$end), norm)
  vect <- normalize(ends[2, ] - ends[1, ])
  cls(point + vect * length / 2, point - vect * length / 2, ...)
}

#' @rdname three_dimensions
#' @format NULL
#' @usage NULL
#' @export
Arrow3DClass <- R6::R6Class("Arrow3D", inherit = Line3DClass, lock_objects = FALSE,
  public = list(
    cone = NULL,
    end_point = NULL,
    initialize = function(start = LEFT, end = RIGHT, thickness = 0.02, height = 0.3, base_radius = 0.08,
                          color = WHITE, resolution = 24, ...) {
      super$initialize(start = start, end = end, thickness = thickness, color = color, resolution = resolution, ...)
      self$length <- get_norm(self$vect)
      self$set_start_and_end_attrs(self$start, self$end - height * self$direction, ...)
      self$cone <- Cone(direction = self$direction, base_radius = base_radius, height = height, ...)
      end <- if (is_mobject(end)) end$get_center() else as_point(end)
      self$cone$shift(end)
      self$end_point <- VectorizedPoint(end)
      self$add(self$end_point, self$cone)
      self$set_color(color)
    },
    get_end = function() self$end_point$get_center()
  )
)

#' @rdname three_dimensions
#' @export
Arrow3D <- constructor(Arrow3DClass)
#' @rdname three_dimensions
#' @format NULL
#' @usage NULL
#' @export
TorusClass <- R6::R6Class("Torus", inherit = SurfaceClass, lock_objects = FALSE,
  public = list(
    R = 3,
    r = 1,
    initialize = function(major_radius = 3, minor_radius = 1, u_range = c(0, TAU), v_range = c(0, TAU),
                          resolution = NULL, ...) {
      self$R <- major_radius
      self$r <- minor_radius
      super$initialize(func = NULL, u_range = u_range, v_range = v_range, resolution = resolution %||% if (identical(cfg("renderer"), RendererType$OPENGL)) c(101, 101) else c(24, 24), ...)
    },
    func = function(u, v) (self$R - self$r * cos(v)) * c(cos(u), sin(u), 0) - self$r * sin(v) * OUT
  )
)

#' @rdname three_dimensions
#' @export
Torus <- constructor(TorusClass)