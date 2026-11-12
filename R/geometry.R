# Geometry: arcs, circles, lines, arrows, tips, polygons and shape matchers.
# Ported from manim/mobject/geometry/{arc,line,polygram,tips,shape_matchers}.py.

#' Geometry mobjects
#'
#' Constructors for basic shapes. Each `Foo()` function creates an object of
#' the R6 class `FooClass`, whose generator is exported for subclassing.
#' Arguments mirror Manim; unlisted arguments in `...` are passed on to
#' [VMobject()] (for example `color`, `fill_opacity`, `stroke_width`).
#'
#' @param ... Arguments passed to the class initializer.
#' @param num_components Number of anchor points used to approximate an arc.
#' @param arc_center Center of the arc.
#' @param start,end Start and end points of a line or arc.
#' @param point Location of the dot's center.
#' @param color,fill_color,fill_opacity,stroke_opacity Color, fill color,
#'   fill opacity and stroke opacity of the shape.
#' @param height Height of the shape.
#' @param path_arc Angle of the arc a line bends along; 0 gives a straight
#'   line.
#' @param dash_length,dashed_ratio Length of each dash, and the fraction of
#'   the line covered by dashes rather than gaps.
#' @param max_tip_length_to_length_ratio,max_stroke_width_to_length_ratio
#'   Upper bounds on the tip length and the stroke width relative to the
#'   arrow length, so short arrows stay well proportioned.
#' @param quadrant Pair of `1` or `-1` choosing, for each line, whether the
#'   angle is measured toward its end (`1`) or its start (`-1`).
#' @param other_angle Draw the reflex angle, going clockwise, instead.
#' @param dot,dot_radius,dot_distance,dot_color Whether to mark the angle
#'   with a dot, the dot's radius, its distance from the vertex as a fraction
#'   of the radius, and its color.
#' @param elbow Draw a right angle elbow instead of an arc.
#' @param num_vertices Number of vertices of the regular polygram.
#' @param grid_xstep,grid_ystep Spacing of optional grid lines drawn inside
#'   the rectangle; `NULL` draws none.
#' @param mark_paths_closed,close_new_points Treat the outline as a closed
#'   path.
#' @param side_length Side length of the square.
#' @param corner_radius Radius of the rounded corners.
#' @param tolerance Tolerance for nearly collinear points; accepted for
#'   compatibility with Manim.
#' @return A mobject.
#' @name geometry
#' @examples
#' Circle(radius = 2, color = BLUE)
#' Square(side_length = 1)$shift(LEFT)
#' Arrow(LEFT, RIGHT)
#' Polygon(c(-1, 0, 0), c(1, 0, 0), c(0, 1, 0))
NULL

# TipableVMobject ------------------------------------------------------------

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
TipableVMobjectClass <- R6::R6Class("TipableVMobject", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    tip_length = DEFAULT_ARROW_TIP_LENGTH,
    normal_vector = NULL,
    tip_style = NULL,
    tip = NULL,
    start_tip = NULL,
    init_positioning_axis = NULL,
    initialize = function(tip_length = DEFAULT_ARROW_TIP_LENGTH, normal_vector = OUT, tip_style = NULL, ...) {
      self$tip_length <- tip_length
      self$normal_vector <- normal_vector
      self$tip_style <- tip_style %||% list()
      super$initialize(...)
    },
    add_tip = function(tip = NULL, tip_shape = NULL, tip_length = NULL, tip_width = NULL, at_start = FALSE) {
      if (is.null(tip)) tip <- self$create_tip(tip_shape, tip_length, tip_width, at_start)
      else self$position_tip(tip, at_start)
      self$reset_endpoints_based_on_tip(tip, at_start)
      self$assign_tip_attr(tip, at_start)
      self$add(tip)
      invisible(self)
    },
    create_tip = function(tip_shape = NULL, tip_length = NULL, tip_width = NULL, at_start = FALSE) {
      tip <- self$get_unpositioned_tip(tip_shape, tip_length, tip_width)
      self$position_tip(tip, at_start)
      tip
    },
    get_unpositioned_tip = function(tip_shape = NULL, tip_length = NULL, tip_width = NULL) {
      style <- list()
      if (is.null(tip_shape)) tip_shape <- ArrowTriangleFilledTipClass
      if (identical(tip_shape, ArrowTriangleFilledTipClass)) {
        style$width <- tip_width %||% self$get_default_tip_length()
      }
      if (is.null(tip_length)) tip_length <- self$get_default_tip_length()
      col <- self$get_color()
      style$fill_color <- col
      style$stroke_color <- col
      for (nm in names(self$tip_style)) style[[nm]] <- self$tip_style[[nm]]
      style$length <- tip_length
      do.call(tip_shape$new, style)
    },
    position_tip = function(tip, at_start = FALSE) {
      if (at_start) {
        anchor <- self$get_start()
        handle <- self$get_first_handle()
      } else {
        handle <- self$get_last_handle()
        anchor <- self$get_end()
      }
      angles <- cartesian_to_spherical(handle - anchor)
      tip$rotate(angles[2] - PI - tip$tip_angle)
      if (is.null(self$init_positioning_axis)) {
        axis <- c(sin(angles[2]), -cos(angles[2]), 0)
        tip$rotate(-angles[3] + PI / 2, axis = axis)
        self$init_positioning_axis <- axis
      }
      tip$shift(anchor - tip$tip_point)
      tip
    },
    reset_endpoints_based_on_tip = function(tip, at_start) {
      if (self$get_length() == 0) return(invisible(self))
      if (at_start) self$put_start_and_end_on(tip$base, self$get_end())
      else self$put_start_and_end_on(self$get_start(), tip$base)
      invisible(self)
    },
    assign_tip_attr = function(tip, at_start) {
      if (at_start) self$start_tip <- tip else self$tip <- tip
      invisible(self)
    },
    has_tip = function() !is.null(self$tip) && self$tip$mob_id %in% self$submobject_ids(),
    has_start_tip = function() !is.null(self$start_tip) && self$start_tip$mob_id %in% self$submobject_ids(),
    pop_tips = function() {
      se <- self$get_start_and_end()
      result <- VGroup()
      if (self$has_tip()) {
        result$add(self$tip)
        self$remove(self$tip)
      }
      if (self$has_start_tip()) {
        result$add(self$start_tip)
        self$remove(self$start_tip)
      }
      if (length(result$submobjects)) self$put_start_and_end_on(se[[1]], se[[2]])
      result
    },
    get_tips = function() {
      result <- VGroup()
      if (!is.null(self$tip)) result$add(self$tip)
      if (!is.null(self$start_tip)) result$add(self$start_tip)
      result
    },
    get_tip = function() {
      tips <- self$get_tips()
      if (length(tips$submobjects) == 0) stop("tip not found", call. = FALSE)
      tips$submobjects[[1]]
    },
    get_default_tip_length = function() self$tip_length,
    get_first_handle = function() self$points[2, ],
    get_last_handle = function() self$points[nrow(self$points) - 1, ],
    get_end = function() if (self$has_tip()) self$tip$get_start() else super$get_end(),
    get_start = function() if (self$has_start_tip()) self$start_tip$get_start() else super$get_start(),
    get_length = function() {
      se <- self$get_start_and_end()
      get_norm(se[[1]] - se[[2]])
    }
  )
)

# Arcs and circles -----------------------------------------------------------

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
ArcClass <- R6::R6Class("Arc", inherit = TipableVMobjectClass, lock_objects = FALSE,
  public = list(
    radius = 1,
    num_components = 9,
    arc_center = NULL,
    start_angle = 0,
    angle = TAU / 4,
    failed_to_get_center = FALSE,
    initialize = function(radius = 1, start_angle = 0, angle = TAU / 4, num_components = 9,
                          arc_center = ORIGIN, ...) {
      self$radius <- radius %||% 1
      self$num_components <- num_components
      self$arc_center <- as_point(arc_center)
      self$start_angle <- start_angle
      self$angle <- angle
      super$initialize(...)
    },
    generate_points = function() {
      self$set_pre_positioned_points()
      self$scale(self$radius, about_point = ORIGIN)
      self$shift(self$arc_center)
      invisible(self)
    },
    init_points = function() self$generate_points(),
    set_pre_positioned_points = function() {
      a <- seq(self$start_angle, self$start_angle + self$angle, length.out = self$num_components)
      anchors <- cbind(cos(a), sin(a), 0)
      d_theta <- self$angle / (self$num_components - 1)
      tangents <- cbind(-anchors[, 2], anchors[, 1], 0)
      factor <- 4 / 3 * tan(d_theta / 4)
      n <- nrow(anchors)
      h1 <- anchors[-n, , drop = FALSE] + factor * tangents[-n, , drop = FALSE]
      h2 <- anchors[-1, , drop = FALSE] - factor * tangents[-1, , drop = FALSE]
      self$set_anchors_and_handles(anchors[-n, , drop = FALSE], h1, h2, anchors[-1, , drop = FALSE])
    },
    get_arc_center = function(warning = TRUE) {
      a1 <- self$points[1, ]; h1 <- self$points[2, ]; h2 <- self$points[3, ]; a2 <- self$points[4, ]
      if (all(a1 == a2)) return(a1)
      n1 <- rotate_vector(h1 - a1, TAU / 4)
      n2 <- rotate_vector(h2 - a2, TAU / 4)
      tryCatch(line_intersection(rbind(a1, a1 + n1), rbind(a2, a2 + n2)), error = function(e) {
        if (warning) warning("Can't find Arc center, using ORIGIN instead", call. = FALSE)
        self$failed_to_get_center <- TRUE
        ORIGIN
      })
    },
    move_arc_center_to = function(point) self$shift(as_point(point) - self$get_arc_center()),
    stop_angle = function() angle_of_vector(self$points[nrow(self$points), ] - self$get_arc_center()) %% TAU
  )
)

#' @rdname geometry
#' @export
Arc <- constructor(ArcClass)
#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
ArcBetweenPointsClass <- R6::R6Class("ArcBetweenPoints", inherit = ArcClass, lock_objects = FALSE,
  public = list(
    initialize = function(start, end, angle = TAU / 4, radius = NULL, ...) {
      start <- as_point(start)
      end <- as_point(end)
      if (!is.null(radius)) {
        sgn <- if (radius < 0) -2 else 2
        r <- abs(radius)
        halfdist <- get_norm(start - end) / 2
        if (r < halfdist) stop("ArcBetweenPoints called with a radius that is smaller than half the distance between the points.", call. = FALSE)
        arc_height <- r - sqrt(r^2 - halfdist^2)
        angle <- acos((r - arc_height) / r) * sgn
        radius <- r
      }
      super$initialize(radius = radius, angle = angle, ...)
      if (angle == 0) self$set_points_as_corners(rbind(LEFT, RIGHT))
      self$put_start_and_end_on(start, end)
      if (is.null(radius)) {
        center <- self$get_arc_center(warning = FALSE)
        self$radius <- if (!self$failed_to_get_center) get_norm(start - center) else Inf
      }
    }
  )
)

#' @rdname geometry
#' @export
ArcBetweenPoints <- constructor(ArcBetweenPointsClass)
#' @rdname geometry
#' @export
CurvedArrow <- function(start_point, end_point, tip_shape = NULL, ...) {
  a <- ArcBetweenPointsClass$new(start_point, end_point, ...)
  class(a) <- c("CurvedArrow", class(a))
  a$add_tip(tip_shape = tip_shape)
  a
}

#' @rdname geometry
#' @param start_point,end_point Endpoints.
#' @param tip_shape,tip_shape_start,tip_shape_end Tip classes such as `ArrowTriangleTipClass`.
#' @export
CurvedDoubleArrow <- function(start_point, end_point, tip_shape_start = NULL, tip_shape_end = NULL, ...) {
  a <- CurvedArrow(start_point, end_point, tip_shape = tip_shape_end, ...)
  a$add_tip(at_start = TRUE, tip_shape = tip_shape_start)
  a
}

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
CircleClass <- R6::R6Class("Circle", inherit = ArcClass, lock_objects = FALSE,
  public = list(
    initialize = function(radius = NULL, color = "#FC6255", ...) {
      super$initialize(radius = radius, start_angle = 0, angle = TAU, color = color, ...)
    },
    surround = function(mobject, dim_to_match = 1, stretch = FALSE, buffer_factor = 1.2) {
      self$replace(mobject, dim_to_match, stretch)
      self$width <- sqrt(mobject$width^2 + mobject$height^2)
      self$scale(buffer_factor)
    },
    point_at_angle = function(angle) {
      p <- angle / TAU
      self$point_from_proportion(p - floor(p))
    }
  )
)

#' @rdname geometry
#' @export
Circle <- constructor(CircleClass)
#' @rdname geometry
#' @param p1,p2,p3 Points on the circle.
#' @export
circle_from_three_points <- function(p1, p2, p3, ...) {
  pb <- function(a, b) {
    m <- midpoint(a, b)
    d <- cross(a - b, OUT)
    rbind(m + d, m - d)
  }
  p1 <- as_point(p1); p2 <- as_point(p2); p3 <- as_point(p3)
  center <- line_intersection(pb(p1, p2), pb(p2, p3))
  Circle(radius = get_norm(p1 - center), ...)$shift(center)
}

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
DotClass <- R6::R6Class("Dot", inherit = CircleClass, lock_objects = FALSE,
  public = list(
    initialize = function(point = ORIGIN, radius = DEFAULT_DOT_RADIUS, stroke_width = 0,
                          fill_opacity = 1, color = "#FFFFFF", ...) {
      super$initialize(arc_center = point, radius = radius, stroke_width = stroke_width,
                       fill_opacity = fill_opacity, color = color, ...)
    }
  )
)

#' @rdname geometry
#' @export
Dot <- constructor(DotClass)
#' @rdname geometry
#' @export
AnnotationDot <- function(radius = DEFAULT_DOT_RADIUS * 1.3, stroke_width = 5, stroke_color = "#FFFFFF",
                          fill_color = BLUE, ...) {
  DotClass$new(radius = radius, stroke_width = stroke_width, stroke_color = stroke_color,
               fill_color = fill_color, ...)
}

#' @rdname geometry
#' @param label A string (rendered with [MathTex()]) or a mobject.
#' @param buff Buffer.
#' @export
LabeledDot <- function(label, radius = NULL, buff = SMALL_BUFF, ...) {
  lab <- if (is.character(label)) MathTex(label, color = "#000000") else label
  if (is.null(radius)) radius <- buff + sqrt(lab$width^2 + lab$height^2) / 2
  d <- DotClass$new(radius = radius, ...)
  lab$move_to(d$get_center())
  d$add(lab)
  d
}

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
EllipseClass <- R6::R6Class("Ellipse", inherit = CircleClass, lock_objects = FALSE,
  public = list(
    initialize = function(width = 2, height = 1, ...) {
      super$initialize(...)
      self$stretch_to_fit_width(width)
      self$stretch_to_fit_height(height)
    }
  )
)

#' @rdname geometry
#' @export
Ellipse <- constructor(EllipseClass)
#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
AnnularSectorClass <- R6::R6Class("AnnularSector", inherit = ArcClass, lock_objects = FALSE,
  public = list(
    inner_radius = 1,
    outer_radius = 2,
    initialize = function(inner_radius = 1, outer_radius = 2, angle = TAU / 4, start_angle = 0,
                          fill_opacity = 1, stroke_width = 0, color = "#FFFFFF", ...) {
      self$inner_radius <- inner_radius
      self$outer_radius <- outer_radius
      super$initialize(start_angle = start_angle, angle = angle, fill_opacity = fill_opacity,
                       stroke_width = stroke_width, color = color, ...)
    },
    generate_points = function() {
      inner <- Arc(start_angle = self$start_angle, angle = self$angle, radius = self$inner_radius, arc_center = self$arc_center)
      outer <- Arc(start_angle = self$start_angle, angle = self$angle, radius = self$outer_radius, arc_center = self$arc_center)
      outer$reverse_points()
      self$append_points(inner$points)
      self$add_line_to(outer$points[1, ])
      self$append_points(outer$points)
      self$add_line_to(inner$points[1, ])
      invisible(self)
    }
  )
)

#' @rdname geometry
#' @export
AnnularSector <- constructor(AnnularSectorClass)
#' @rdname geometry
#' @param radius Radius.
#' @export
Sector <- function(radius = 1, ...) {
  s <- AnnularSectorClass$new(inner_radius = 0, outer_radius = radius, ...)
  class(s) <- c("Sector", class(s))
  s
}

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
AnnulusClass <- R6::R6Class("Annulus", inherit = CircleClass, lock_objects = FALSE,
  public = list(
    inner_radius = 1,
    outer_radius = 2,
    initialize = function(inner_radius = 1, outer_radius = 2, fill_opacity = 1, stroke_width = 0,
                          color = "#FFFFFF", ...) {
      self$inner_radius <- inner_radius
      self$outer_radius <- outer_radius
      super$initialize(fill_opacity = fill_opacity, stroke_width = stroke_width, color = color, ...)
    },
    generate_points = function() {
      self$radius <- self$outer_radius
      outer <- Circle(radius = self$outer_radius)
      inner <- Circle(radius = self$inner_radius)
      inner$reverse_points()
      self$append_points(outer$points)
      self$append_points(inner$points)
      self$shift(self$arc_center)
      invisible(self)
    }
  )
)

#' @rdname geometry
#' @export
Annulus <- constructor(AnnulusClass)
#' @rdname geometry
#' @param start_anchor,start_handle,end_handle,end_anchor Bezier control points.
#' @export
CubicBezier <- function(start_anchor, start_handle, end_handle, end_anchor, ...) {
  v <- VMobject(...)
  class(v) <- c("CubicBezier", class(v))
  v$add_cubic_bezier_curve(start_anchor, start_handle, end_handle, end_anchor)
  v
}

#' @rdname geometry
#' @param angle Angle.
#' @param arc_config List of argument lists, one per arc.
#' @export
ArcPolygon <- function(..., angle = PI / 4, radius = NULL, arc_config = NULL) {
  args <- list(...)
  nm <- names(args) %||% rep("", length(args))
  vertices <- args[nm == ""]
  kwargs <- args[nm != ""]
  n <- length(vertices)
  confs <- if (is.null(arc_config)) {
    rep(list(if (!is.null(radius)) list(radius = radius) else list(angle = angle)), n)
  } else if (!is.null(names(arc_config))) rep(list(arc_config), n) else arc_config
  arcs <- lapply(seq_len(n), function(k) {
    do.call(ArcBetweenPoints, c(list(vertices[[k]], vertices[[k %% n + 1]]), confs[[k]]))
  })
  v <- do.call(VMobject, kwargs)
  class(v) <- c("ArcPolygon", class(v))
  v$add(arcs)
  for (a in arcs) v$append_points(a$points)
  v$arcs <- arcs
  v
}

#' @rdname geometry
#' @export
ArcPolygonFromArcs <- function(...) {
  args <- list(...)
  nm <- names(args) %||% rep("", length(args))
  arcs <- args[nm == ""]
  v <- do.call(VMobject, args[nm != ""])
  class(v) <- c("ArcPolygonFromArcs", class(v))
  v$add(arcs)
  v$arcs <- arcs
  n <- length(arcs)
  for (k in seq_len(n)) {
    a1 <- arcs[[k]]
    a2 <- arcs[[k %% n + 1]]
    v$append_points(a1$points)
    line <- Line(a1$get_end(), a2$get_start())
    ratio <- line$get_length() / a1$get_arc_length()
    if (is.nan(ratio) || is.infinite(ratio)) next
    line$insert_n_curves(as.integer(a1$get_num_curves() * ratio))
    v$append_points(line$points)
  }
  v
}

# Lines ----------------------------------------------------------------------

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
LineClass <- R6::R6Class("Line", inherit = TipableVMobjectClass, lock_objects = FALSE,
  public = list(
    buff = 0,
    path_arc = 0,
    start = NULL,
    end = NULL,
    initialize = function(start = LEFT, end = RIGHT, buff = 0, path_arc = 0, ...) {
      self$buff <- buff
      self$path_arc <- path_arc
      self$set_start_and_end_attrs(start, end)
      super$initialize(...)
    },
    generate_points = function() {
      self$set_points_by_ends(self$start, self$end, self$buff, self$path_arc)
    },
    init_points = function() self$generate_points(),
    set_points_by_ends = function(start, end, buff = 0, path_arc = 0) {
      self$set_start_and_end_attrs(start, end)
      if (path_arc != 0) {
        arc <- ArcBetweenPoints(self$start, self$end, angle = path_arc)
        self$set_points(arc$points)
      } else {
        self$set_points_as_corners(rbind(self$start, self$end))
      }
      self$account_for_buff(buff)
      invisible(self)
    },
    account_for_buff = function(buff) {
      if (buff <= 0) return(invisible(self))
      len <- if (self$path_arc == 0) self$get_length() else self$get_arc_length()
      if (len < 2 * buff) return(invisible(self))
      bp <- buff / len
      self$pointwise_become_partial(self, bp, 1 - bp)
      invisible(self)
    },
    set_start_and_end_attrs = function(start, end) {
      rough_start <- self$pointify(start)
      rough_end <- self$pointify(end)
      vect <- normalize(rough_end - rough_start)
      self$start <- self$pointify(start, vect)
      self$end <- self$pointify(end, -vect)
    },
    pointify = function(mob_or_point, direction = NULL) {
      if (is_mobject(mob_or_point)) {
        if (is.null(direction)) return(mob_or_point$get_center())
        return(mob_or_point$get_boundary_point(direction))
      }
      as_point(mob_or_point)
    },
    set_path_arc = function(new_value) {
      self$path_arc <- new_value
      self$init_points()
    },
    put_start_and_end_on = function(start, end) {
      se <- self$get_start_and_end()
      if (isTRUE(all.equal(get_norm(se[[2]] - se[[1]]), 0))) {
        self$start <- as_point(start)
        self$end <- as_point(end)
        self$generate_points()
      }
      super$put_start_and_end_on(start, end)
    },
    get_vector = function() self$get_end() - self$get_start(),
    get_unit_vector = function() normalize(self$get_vector()),
    get_angle = function() angle_of_vector(self$get_vector()),
    get_projection = function(point) {
      s <- self$get_start()
      u <- normalize(self$get_end() - s)
      s + sum((as_point(point) - s) * u) * u
    },
    get_slope = function() tan(self$get_angle()),
    set_angle = function(angle, about_point = NULL) {
      self$rotate(angle - self$get_angle(), about_point = about_point %||% self$get_start())
    },
    set_length = function(length) self$scale(length / self$get_length())
  )
)

#' @rdname geometry
#' @export
Line <- constructor(LineClass)
#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
DashedLineClass <- R6::R6Class("DashedLine", inherit = LineClass, lock_objects = FALSE,
  public = list(
    dash_length = DEFAULT_DASH_LENGTH,
    dashed_ratio = 0.5,
    initialize = function(..., dash_length = DEFAULT_DASH_LENGTH, dashed_ratio = 0.5) {
      self$dash_length <- dash_length
      self$dashed_ratio <- dashed_ratio
      super$initialize(...)
      dashes <- DashedVMobject(self, num_dashes = self$calculate_num_dashes(), dashed_ratio = dashed_ratio)
      self$clear_points()
      self$add(dashes$submobjects)
    },
    calculate_num_dashes = function() {
      max(2, as.integer(ceiling((self$get_length() / self$dash_length) * self$dashed_ratio)))
    },
    get_start = function() {
      if (length(self$submobjects)) self$submobjects[[1]]$get_start() else super$get_start()
    },
    get_end = function() {
      n <- length(self$submobjects)
      if (n) self$submobjects[[n]]$get_end() else super$get_end()
    },
    get_first_handle = function() self$submobjects[[1]]$points[2, ],
    get_last_handle = function() {
      sm <- self$submobjects[[length(self$submobjects)]]
      sm$points[3, ]
    }
  )
)

#' @rdname geometry
#' @export
DashedLine <- constructor(DashedLineClass)
#' @rdname geometry
#' @param vmob A VMobject.
#' @param alpha Proportion along `vmob`.
#' @param length Length.
#' @param d_alpha Step used to estimate the tangent.
#' @export
TangentLine <- function(vmob, alpha, length = 1, d_alpha = 1e-6, ...) {
  a1 <- min(max(alpha - d_alpha, 0), 1)
  a2 <- min(max(alpha + d_alpha, 0), 1)
  l <- LineClass$new(vmob$point_from_proportion(a1), vmob$point_from_proportion(a2), ...)
  class(l) <- c("TangentLine", class(l))
  l$scale(length / l$get_length())
  l
}

#' @rdname geometry
#' @param width Width.
#' @export
Elbow <- function(width = 0.2, angle = 0, ...) {
  v <- VMobject(...)
  class(v) <- c("Elbow", class(v))
  v$angle <- angle
  v$set_points_as_corners(rbind(UP, UP + RIGHT, RIGHT))
  v$scale_to_fit_width(width, about_point = ORIGIN)
  v$rotate(angle, about_point = ORIGIN)
  v
}

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
ArrowClass <- R6::R6Class("Arrow", inherit = LineClass, lock_objects = FALSE,
  public = list(
    max_tip_length_to_length_ratio = 0.25,
    max_stroke_width_to_length_ratio = 5,
    initial_stroke_width = 6,
    initialize = function(..., stroke_width = 6, buff = MED_SMALL_BUFF, max_tip_length_to_length_ratio = 0.25,
                          max_stroke_width_to_length_ratio = 5, tip_shape = NULL) {
      self$max_tip_length_to_length_ratio <- max_tip_length_to_length_ratio
      self$max_stroke_width_to_length_ratio <- max_stroke_width_to_length_ratio
      super$initialize(..., buff = buff, stroke_width = stroke_width)
      self$initial_stroke_width <- self$stroke_width
      self$add_tip(tip_shape = tip_shape)
      self$set_stroke_width_from_length()
    },
    scale = function(scale_factor, scale_tips = FALSE, ...) {
      if (self$get_length() == 0) return(invisible(self))
      if (scale_tips) {
        super$scale(scale_factor, ...)
        self$set_stroke_width_from_length()
        return(invisible(self))
      }
      ht <- self$has_tip()
      hst <- self$has_start_tip()
      if (ht || hst) old <- self$pop_tips()
      super$scale(scale_factor, ...)
      self$set_stroke_width_from_length()
      if (ht) self$add_tip(tip = old$submobjects[[1]])
      if (hst) self$add_tip(tip = old$submobjects[[length(old$submobjects)]], at_start = TRUE)
      invisible(self)
    },
    get_normal_vector = function() {
      p <- self$tip$get_start_anchors()
      normalize(cross(p[3, ] - p[2, ], p[2, ] - p[1, ]))
    },
    reset_normal_vector = function() {
      self$normal_vector <- self$get_normal_vector()
      invisible(self)
    },
    get_default_tip_length = function() min(self$tip_length, self$max_tip_length_to_length_ratio * self$get_length()),
    set_stroke_width_from_length = function() {
      self$set_stroke(width = min(self$initial_stroke_width, self$max_stroke_width_to_length_ratio * self$get_length()),
                      family = FALSE)
    }
  )
)

#' @rdname geometry
#' @export
Arrow <- constructor(ArrowClass)
#' @rdname geometry
#' @param direction Direction of the vector.
#' @export
Vector <- constructor(VectorClass)
#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
VectorClass <- R6::R6Class("Vector", inherit = ArrowClass, lock_objects = FALSE,
  public = list(
    initialize = function(direction = RIGHT, buff = 0, ...) {
      super$initialize(ORIGIN, as_point(direction), buff = buff, ...)
    },
    coordinate_label = function(integer_labels = TRUE, n_dim = 2, color = NULL, ...) {
      vect <- self$get_end()
      if (integer_labels) vect <- round(vect)
      vect <- vect[seq_len(n_dim)]
      label <- Matrix(matrix(vect, ncol = 1), ...)
      label$scale(LARGE_BUFF - 0.2)
      shift_dir <- self$get_end()
      if (shift_dir[1] >= 0) {
        shift_dir <- shift_dir - (label$get_left() + DEFAULT_MOBJECT_TO_MOBJECT_BUFFER * LEFT)
      } else {
        shift_dir <- shift_dir - (label$get_right() + DEFAULT_MOBJECT_TO_MOBJECT_BUFFER * RIGHT)
      }
      label$shift(shift_dir)
      if (!is.null(color)) label$set_color(color)
      label
    }
  )
)

#' @rdname geometry
#' @export
DoubleArrow <- function(..., tip_shape_start = NULL, tip_shape_end = NULL) {
  a <- ArrowClass$new(..., tip_shape = tip_shape_end)
  class(a) <- c("DoubleArrow", class(a))
  a$add_tip(at_start = TRUE, tip_shape = tip_shape_start)
  a
}

#' @rdname geometry
#' @param line1,line2 Lines.
#' @export
Angle <- constructor(AngleClass)
#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
AngleClass <- R6::R6Class("Angle", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    lines = NULL,
    quadrant = c(1, 1),
    dot_distance = 0.55,
    elbow = FALSE,
    angle_value = 0,
    initialize = function(line1, line2, radius = NULL, quadrant = c(1, 1), other_angle = FALSE, dot = FALSE,
                          dot_radius = NULL, dot_distance = 0.55, dot_color = "#FFFFFF", elbow = FALSE, ...) {
      super$initialize(...)
      self$lines <- list(line1, line2)
      self$quadrant <- quadrant
      self$dot_distance <- dot_distance
      self$elbow <- elbow
      inter <- tryCatch(line_intersection(rbind(line1$get_start(), line1$get_end()),
                                          rbind(line2$get_start(), line2$get_end())),
                        error = function(e) NULL)
      if (is.null(inter)) {
        self$angle_value <- 0
        return(invisible(self))
      }
      if (is.null(radius)) {
        d1 <- get_norm((if (quadrant[1] == 1) line1$get_end() else line1$get_start()) - inter)
        d2 <- get_norm((if (quadrant[2] == 1) line2$get_end() else line2$get_start()) - inter)
        radius <- if (min(d1, d2) < 0.6) 2 / 3 * min(d1, d2) else 0.4
      } else {
        self$radius <- radius
      }
      a1 <- inter + quadrant[1] * radius * line1$get_unit_vector()
      a2 <- inter + quadrant[2] * radius * line2$get_unit_vector()
      if (elbow) {
        mid <- inter + quadrant[1] * radius * line1$get_unit_vector() + quadrant[2] * radius * line2$get_unit_vector()
        am <- VMobject(...)
        am$set_points_as_corners(rbind(a1, mid, a2))
        self$angle_value <- PI / 2
      } else {
        ang1 <- angle_of_vector(a1 - inter)
        ang2 <- angle_of_vector(a2 - inter)
        fin <- if (!other_angle) {
          if (ang2 > ang1) ang2 - ang1 else 2 * pi - (ang1 - ang2)
        } else {
          if (ang2 < ang1) -ang1 + ang2 else -2 * pi + (ang2 - ang1)
        }
        self$angle_value <- fin
        am <- Arc(radius = radius, angle = fin, start_angle = ang1, arc_center = inter, ...)
        if (dot) {
          dot_radius <- dot_radius %||% (radius / 10)
          rd <- Dot(ORIGIN, radius = dot_radius, color = dot_color)
          dc <- am$get_center() - inter
          rd$move_to(inter + dc / get_norm(dc) * radius * dot_distance)
          self$add(rd)
        }
      }
      self$set_points(am$points)
    },
    get_lines = function() VGroup(self$lines),
    get_value = function(degrees = FALSE) if (degrees) self$angle_value / DEGREES else self$angle_value
  )
)

#' @rdname geometry
#' @param A,B,C Points; the angle is at `B`.
#' @export
angle_from_three_points <- function(A, B, C, ...) Angle(Line(B, A), Line(B, C), ...)

#' @rdname geometry
#' @export
RightAngle <- function(line1, line2, length = NULL, ...) {
  Angle(line1, line2, radius = length, elbow = TRUE, ...)
}

# Tips -----------------------------------------------------------------------

tip_active <- list(
  base = function(value) self$point_from_proportion(0.5),
  tip_point = function(value) self$points[1, ],
  vector = function(value) self$points[1, ] - self$point_from_proportion(0.5),
  tip_angle = function(value) angle_of_vector(self$points[1, ] - self$point_from_proportion(0.5)),
  length = function(value) get_norm(self$points[1, ] - self$point_from_proportion(0.5))
)

# Polygons -------------------------------------------------------------------

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
PolygramClass <- R6::R6Class("Polygram", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    initialize = function(..., color = BLUE) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      groups <- args[nm == ""]
      do.call(super$initialize, c(list(color = color), args[nm != ""]))
      for (g in groups) {
        v <- as_points(g)
        self$start_new_path(v[1, ])
        self$add_points_as_corners(rbind(v[-1, , drop = FALSE], v[1, ]))
      }
    },
    get_vertices = function() self$get_start_anchors(),
    get_vertex_groups = function() {
      s <- self$get_start_anchors()
      e <- self$get_end_anchors()
      groups <- list()
      group <- NULL
      for (i in seq_len(nrow(e))) {
        group <- rbind(group, s[i, ])
        if (self$consider_points_equals(e[i, ], group[1, ])) {
          groups[[length(groups) + 1]] <- group
          group <- NULL
        }
      }
      groups
    },
    round_corners = function(radius = 0.5, evenly_distribute_anchors = FALSE, components_per_rounded_corner = 2) {
      if (all(radius == 0)) return(invisible(self))
      new_points <- list()
      for (vg in self$get_vertex_groups()) {
        n <- nrow(vg)
        rl <- rep_len(radius, n)
        arcs <- vector("list", n)
        for (k in seq_len(n)) {
          v1 <- vg[k, ]
          v2 <- vg[k %% n + 1, ]
          v3 <- vg[(k + 1) %% n + 1, ]
          vect1 <- v2 - v1
          vect2 <- v3 - v2
          u1 <- normalize(vect1)
          u2 <- normalize(vect2)
          ang <- angle_between_vectors(vect1, vect2) * sign(rl[k])
          cut <- rl[k] * tan(ang / 2)
          mx <- min(get_norm(vect1), get_norm(vect2)) / 2
          cut <- min(max(cut, -mx), mx)
          sgn <- sign(cross(vect1, vect2)[3])
          arcs[[k]] <- ArcBetweenPoints(v2 - u1 * cut, v2 + u2 * cut, angle = sgn * ang,
                                        num_components = components_per_rounded_corner)
        }
        if (evenly_distribute_anchors) {
          nz <- Filter(function(a) nrow(a$points) > 4, arcs)
          avg <- if (length(nz)) {
            sum(vapply(nz, function(a) a$get_arc_length(), 0)) / (sum(vapply(nz, function(a) nrow(a$points), 0)) / 4)
          } else 1
        }
        arcs <- c(arcs[n], arcs[-n])
        for (k in seq_len(n)) {
          a1 <- arcs[[k]]
          a2 <- arcs[[k %% n + 1]]
          new_points[[length(new_points) + 1]] <- a1$points
          line <- Line(a1$get_end(), a2$get_start())
          if (evenly_distribute_anchors) line$insert_n_curves(ceiling(line$get_length() / avg))
          new_points[[length(new_points) + 1]] <- line$points
        }
      }
      self$set_points(do.call(rbind, new_points))
    }
  )
)

#' @rdname geometry
#' @export
Polygram <- constructor(PolygramClass)
#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
PolygonClass <- R6::R6Class("Polygon", inherit = PolygramClass, lock_objects = FALSE,
  public = list(
    initialize = function(...) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      verts <- args[nm == ""]
      verts <- if (length(verts) == 1 && (is.matrix(verts[[1]]) || is.list(verts[[1]]))) list(as_points(verts[[1]]))
        else list(as_points(verts))
      do.call(super$initialize, c(verts, args[nm != ""]))
    }
  )
)

#' @rdname geometry
#' @export
Polygon <- constructor(PolygonClass)
regular_polygram_groups <- function(num_vertices, density, radius, start_angle) {
  gcd <- function(a, b) if (b == 0) a else gcd(b, a %% b)
  num_gons <- gcd(num_vertices, density)
  nv <- num_vertices %/% num_gons
  dens <- density %/% num_gons
  gen <- function(sa) {
    rv <- regular_vertices(nv, radius = radius, start_angle = sa)
    idx <- integer()
    i <- 0
    repeat {
      idx <- c(idx, i + 1)
      i <- (i + dens) %% nv
      if (i == 0) break
    }
    list(vertices = rv$vertices[idx, , drop = FALSE], start_angle = rv$start_angle)
  }
  first <- gen(start_angle)
  groups <- list(first$vertices)
  if (num_gons > 1) {
    for (i in 1:(num_gons - 1)) {
      groups[[i + 1]] <- gen(first$start_angle + (i / num_gons) * TAU / nv)$vertices
    }
  }
  list(groups = groups, start_angle = first$start_angle)
}

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
RegularPolygramClass <- R6::R6Class("RegularPolygram", inherit = PolygramClass, lock_objects = FALSE,
  public = list(
    start_angle = NULL,
    initialize = function(num_vertices, density = 2, radius = 1, start_angle = NULL, ...) {
      rp <- regular_polygram_groups(num_vertices, density, radius, start_angle)
      self$start_angle <- rp$start_angle
      do.call(super$initialize, c(rp$groups, list(...)))
    }
  )
)

#' @rdname geometry
#' @export
RegularPolygram <- constructor(RegularPolygramClass)
#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
RegularPolygonClass <- R6::R6Class("RegularPolygon", inherit = RegularPolygramClass, lock_objects = FALSE,
  public = list(
    initialize = function(n = 6, ...) super$initialize(n, density = 1, ...)
  )
)

#' @rdname geometry
#' @export
RegularPolygon <- constructor(RegularPolygonClass)
#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
TriangleClass <- R6::R6Class("Triangle", inherit = RegularPolygonClass, lock_objects = FALSE,
  public = list(
    initialize = function(...) super$initialize(n = 3, ...)
  )
)

#' @rdname geometry
#' @export
Triangle <- constructor(TriangleClass)
#' @rdname geometry
#' @param n Number of points.
#' @param outer_radius,inner_radius Radii.
#' @param density Density of the star.
#' @param start_angle Starting angle.
#' @export
Star <- function(n = 5, outer_radius = 1, inner_radius = NULL, density = 2, start_angle = TAU / 4, ...) {
  inner_angle <- TAU / (2 * n)
  if (is.null(inner_radius)) {
    if (density <= 0 || density >= n / 2) stop("Incompatible density ", density, " for number of points ", n, call. = FALSE)
    outer_angle <- TAU * density / n
    inverse_x <- 1 - tan(inner_angle) * ((cos(outer_angle) - 1) / sin(outer_angle))
    inner_radius <- outer_radius / (cos(inner_angle) * inverse_x)
  }
  ov <- regular_vertices(n, radius = outer_radius, start_angle = start_angle)
  iv <- regular_vertices(n, radius = inner_radius, start_angle = ov$start_angle + inner_angle)
  verts <- matrix(0, 2 * n, 3)
  verts[seq(1, 2 * n, 2), ] <- ov$vertices
  verts[seq(2, 2 * n, 2), ] <- iv$vertices
  s <- PolygonClass$new(verts, ...)
  class(s) <- c("Star", class(s))
  s$start_angle <- ov$start_angle
  s
}

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
RectangleClass <- R6::R6Class("Rectangle", inherit = PolygonClass, lock_objects = FALSE,
  public = list(
    grid_lines = NULL,
    initialize = function(color = "#FFFFFF", height = 2, width = 4, grid_xstep = NULL, grid_ystep = NULL,
                          mark_paths_closed = TRUE, close_new_points = TRUE, ...) {
      super$initialize(UR, UL, DL, DR, color = color, ...)
      self$stretch_to_fit_width(width)
      self$stretch_to_fit_height(height)
      v <- self$get_vertices()
      self$grid_lines <- VGroup()
      if (!is.null(grid_xstep)) {
        grid_xstep <- abs(grid_xstep)
        count <- as.integer(width / grid_xstep)
        if (count > 1) {
          self$grid_lines$add(VGroup(lapply(1:(count - 1), function(i) {
            Line(v[2, ] + i * grid_xstep * RIGHT, v[2, ] + i * grid_xstep * RIGHT + height * DOWN, color = color)
          })))
        }
      }
      if (!is.null(grid_ystep)) {
        grid_ystep <- abs(grid_ystep)
        count <- as.integer(height / grid_ystep)
        if (count > 1) {
          self$grid_lines$add(VGroup(lapply(1:(count - 1), function(i) {
            Line(v[2, ] + i * grid_ystep * DOWN, v[2, ] + i * grid_ystep * DOWN + width * RIGHT, color = color)
          })))
        }
      }
      if (length(self$grid_lines$submobjects)) self$add(self$grid_lines)
    }
  )
)

#' @rdname geometry
#' @export
Rectangle <- constructor(RectangleClass)
#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
SquareClass <- R6::R6Class("Square", inherit = RectangleClass, lock_objects = FALSE,
  public = list(
    initialize = function(side_length = 2, ...) super$initialize(height = side_length, width = side_length, ...)
  ),
  active = list(
    side_length = function(value) {
      v <- self$get_vertices()
      cur <- get_norm(v[1, ] - v[2, ])
      if (missing(value)) return(cur)
      self$scale(value / cur)
    }
  )
)

#' @rdname geometry
#' @export
Square <- constructor(SquareClass)
#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
RoundedRectangleClass <- R6::R6Class("RoundedRectangle", inherit = RectangleClass, lock_objects = FALSE,
  public = list(
    corner_radius = 0.5,
    initialize = function(corner_radius = 0.5, ...) {
      super$initialize(...)
      self$corner_radius <- corner_radius
      self$round_corners(corner_radius)
    }
  )
)

#' @rdname geometry
#' @export
RoundedRectangle <- constructor(RoundedRectangleClass)
#' @rdname geometry
#' @param main_shape Shape to cut holes into.
#' @export
Cutout <- function(main_shape, ...) {
  args <- list(...)
  nm <- names(args) %||% rep("", length(args))
  v <- do.call(VMobject, args[nm != ""])
  class(v) <- c("Cutout", class(v))
  v$append_points(main_shape$points)
  sub_dir <- if (main_shape$get_direction() == "CW") "CCW" else "CW"
  for (m in args[nm == ""]) v$append_points(m$force_direction(sub_dir)$points)
  v
}

#' @rdname geometry
#' @export
ConvexHull <- function(..., tolerance = 1e-5) {
  args <- list(...)
  nm <- names(args) %||% rep("", length(args))
  pos <- args[nm == ""]
  pts <- if (length(pos) == 1 && is.matrix(pos[[1]])) as_points(pos[[1]]) else as_points(pos)
  h <- grDevices::chull(pts[, 1], pts[, 2])
  verts <- pts[rev(h), , drop = FALSE]
  verts[, 3] <- 0
  p <- do.call(PolygramClass$new, c(list(verts), args[nm != ""]))
  class(p) <- c("ConvexHull", class(p))
  p
}

# Tip classes (after polygons, since they inherit them) ----------------------

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
ArrowTriangleTipClass <- R6::R6Class("ArrowTriangleTip", inherit = TriangleClass, lock_objects = FALSE,
  public = list(
    initialize = function(fill_opacity = 0, stroke_width = 3, length = DEFAULT_ARROW_TIP_LENGTH,
                          width = DEFAULT_ARROW_TIP_LENGTH, start_angle = PI, ...) {
      super$initialize(fill_opacity = fill_opacity, stroke_width = stroke_width, start_angle = start_angle, ...)
      self$width <- width
      self$stretch_to_fit_width(length)
      self$stretch_to_fit_height(width)
    }
  ),
  active = tip_active
)

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
ArrowTriangleFilledTipClass <- R6::R6Class("ArrowTriangleFilledTip", inherit = ArrowTriangleTipClass, lock_objects = FALSE,
  public = list(
    initialize = function(fill_opacity = 1, stroke_width = 0, ...) {
      super$initialize(fill_opacity = fill_opacity, stroke_width = stroke_width, ...)
    }
  )
)

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
ArrowCircleTipClass <- R6::R6Class("ArrowCircleTip", inherit = CircleClass, lock_objects = FALSE,
  public = list(
    initialize = function(fill_opacity = 0, stroke_width = 3, length = DEFAULT_ARROW_TIP_LENGTH,
                          start_angle = PI, ...) {
      super$initialize(fill_opacity = fill_opacity, stroke_width = stroke_width, ...)
      self$start_angle <- start_angle
      self$width <- length
      self$stretch_to_fit_height(length)
    }
  ),
  active = tip_active
)

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
ArrowCircleFilledTipClass <- R6::R6Class("ArrowCircleFilledTip", inherit = ArrowCircleTipClass, lock_objects = FALSE,
  public = list(
    initialize = function(fill_opacity = 1, stroke_width = 0, ...) {
      super$initialize(fill_opacity = fill_opacity, stroke_width = stroke_width, ...)
    }
  )
)

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
ArrowSquareTipClass <- R6::R6Class("ArrowSquareTip", inherit = SquareClass, lock_objects = FALSE,
  public = list(
    initialize = function(fill_opacity = 0, stroke_width = 3, length = DEFAULT_ARROW_TIP_LENGTH,
                          start_angle = PI, ...) {
      super$initialize(fill_opacity = fill_opacity, stroke_width = stroke_width, side_length = length, ...)
      self$start_angle <- start_angle
      self$width <- length
      self$stretch_to_fit_height(length)
    }
  ),
  active = tip_active
)

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
ArrowSquareFilledTipClass <- R6::R6Class("ArrowSquareFilledTip", inherit = ArrowSquareTipClass, lock_objects = FALSE,
  public = list(
    initialize = function(fill_opacity = 1, stroke_width = 0, ...) {
      super$initialize(fill_opacity = fill_opacity, stroke_width = stroke_width, ...)
    }
  )
)

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
StealthTipClass <- R6::R6Class("StealthTip", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    start_angle = PI,
    initialize = function(fill_opacity = 1, stroke_width = 3, length = DEFAULT_ARROW_TIP_LENGTH / 2,
                          start_angle = PI, ...) {
      self$start_angle <- start_angle
      super$initialize(fill_opacity = fill_opacity, stroke_width = stroke_width, ...)
      self$set_points_as_corners(rbind(c(2, 0, 0), c(-1.2, 1.6, 0), c(0, 0, 0), c(-1.2, -1.6, 0), c(2, 0, 0)))
      self$scale(length / self$length)
    }
  ),
  active = utils::modifyList(tip_active, list(
    length = function(value) get_norm(self$points[1, ] - self$point_from_proportion(0.5)) * 1.6
  ))
)

# Shape matchers -------------------------------------------------------------

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
SurroundingRectangleClass <- R6::R6Class("SurroundingRectangle", inherit = RoundedRectangleClass, lock_objects = FALSE,
  public = list(
    buff = SMALL_BUFF,
    initialize = function(..., color = PURE_YELLOW, buff = SMALL_BUFF, corner_radius = 0) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      mobs <- args[nm == ""]
      bx <- buff[1]
      by <- buff[length(buff)]
      group <- do.call(Group, mobs)
      do.call(super$initialize, c(list(color = color, width = group$width + 2 * bx, height = group$height + 2 * by,
                                       corner_radius = corner_radius), args[nm != ""]))
      self$buff <- buff
      self$move_to(group)
    }
  )
)

#' @rdname geometry
#' @export
SurroundingRectangle <- constructor(SurroundingRectangleClass)
#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
BackgroundRectangleClass <- R6::R6Class("BackgroundRectangle", inherit = SurroundingRectangleClass, lock_objects = FALSE,
  public = list(
    original_fill_opacity = 0.75,
    initialize = function(..., color = NULL, stroke_width = 0, stroke_opacity = 0, fill_opacity = 0.75, buff = 0) {
      super$initialize(..., color = color %||% cfg("background_color"), stroke_width = stroke_width,
                       stroke_opacity = stroke_opacity, fill_opacity = fill_opacity, buff = buff)
      self$original_fill_opacity <- self$fill_opacity
    },
    pointwise_become_partial = function(mobject, a, b) {
      self$set_fill(opacity = b * self$original_fill_opacity)
    },
    set_style = function(fill_opacity = NULL, ...) {
      super$set_style(stroke_color = "#000000", stroke_width = 0, fill_color = "#000000", fill_opacity = fill_opacity)
    }
  )
)

#' @rdname geometry
#' @export
BackgroundRectangle <- constructor(BackgroundRectangleClass)
#' @rdname geometry
#' @param mobject A mobject.
#' @param stroke_color,stroke_width Stroke style.
#' @param scale_factor Scale factor.
#' @export
Cross <- function(mobject = NULL, stroke_color = "#FC6255", stroke_width = 6, scale_factor = 1, ...) {
  g <- VGroup(Line(UP + LEFT, DOWN + RIGHT), Line(UP + RIGHT, DOWN + LEFT), ...)
  class(g) <- c("Cross", class(g))
  if (!is.null(mobject)) g$replace(mobject, stretch = TRUE)
  g$scale(scale_factor)
  g$set_stroke(color = stroke_color, width = stroke_width)
  g
}

#' @rdname geometry
#' @export
Underline <- function(mobject, buff = SMALL_BUFF, ...) {
  l <- LineClass$new(LEFT, RIGHT, buff = buff, ...)
  class(l) <- c("Underline", class(l))
  l$match_width(mobject)
  l$next_to(mobject, DOWN, buff = buff)
  l
}

#' @rdname geometry
#' @param corner Which corner between the lines, as `c(1, 1)` and so on.
#' @export
TangentialArc <- function(line1, line2, radius, corner = c(1, 1), ...) {
  inter <- line_intersection(rbind(line1$get_start(), line1$get_end()), rbind(line2$get_start(), line2$get_end()))
  u1 <- corner[1] * line1$get_unit_vector()
  u2 <- corner[2] * line2$get_unit_vector()
  corner_angle <- angle_between_vectors(u1, u2)
  d <- radius / tan(corner_angle / 2)
  t1 <- inter + d * u1
  t2 <- inter + d * u2
  cross_z <- u1[1] * u2[2] - u1[2] * u2[1]
  ends <- if (cross_z < 0) list(t1, t2) else list(t2, t1)
  a <- ArcBetweenPointsClass$new(ends[[1]], ends[[2]], radius = radius, ...)
  class(a) <- c("TangentialArc", class(a))
  a$line1 <- line1
  a$line2 <- line2
  a
}

#' @rdname geometry
#' @format NULL
#' @usage NULL
#' @export
ArrowTipClass <- R6::R6Class("ArrowTip", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    initialize = function(...) {
      if (identical(class(self)[1], "ArrowTip")) stop("ArrowTip has to be implemented in inheriting subclasses.", call. = FALSE)
      super$initialize(...)
    }
  ),
  active = tip_active
)
