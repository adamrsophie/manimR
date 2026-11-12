# Coordinate systems: axes, planes and the plotting tools that live on them.
# Ported from manim/mobject/graphing/coordinate_systems.py.

# Recursive dict update, like manim's update_dict_recursively.
update_config <- function(default, passed) {
  if (is.null(passed)) default else utils::modifyList(default, passed)
}

# Value at which an axis meets the other axes, like Axes._origin_shift.
axes_origin_shift <- function(axis_range) {
  if (axis_range[1] > 0) return(axis_range[1])
  if (axis_range[2] < 0) return(axis_range[2])
  0
}

#' @rdname sigmoid
#' @param f A monotone function of one number returning a number (upstream
#'   calls it `function`, a reserved word in R).
#' @param target Value to reach.
#' @param lower_bound,upper_bound Search interval.
#' @param tolerance Width of the interval at which the search stops.
#' @export
binary_search <- function(f, target, lower_bound, upper_bound, tolerance = 1e-4) {
  lh <- lower_bound
  rh <- upper_bound
  mh <- (lh + rh) / 2
  while (abs(rh - lh) > tolerance) {
    mh <- (lh + rh) / 2
    lx <- f(lh)
    mx <- f(mh)
    rx <- f(rh)
    if (lx == target) return(lh)
    if (rx == target) return(rh)
    if (lx <= target && target <= rx) {
      if (mx > target) rh <- mh else lh <- mh
    } else if (lx > target && target > rx) {
      tmp <- lh
      lh <- rh
      rh <- tmp
    } else {
      return(NULL)
    }
  }
  mh
}

# Best rational approximation with denominator <= max_den, as c(num, den).
limit_denominator <- function(x, max_den = 100) {
  for (den in seq_len(max_den)) {
    num <- round(x * den)
    if (abs(num / den - x) < 1e-9) return(c(num, den))
  }
  den <- which.min(abs(round(x * seq_len(max_den)) / seq_len(max_den) - x))
  c(round(x * den), den)
}

# Add points or point matrices, broadcasting a single point over rows.
add_points <- function(a, b) {
  if (is.matrix(a) && !is.matrix(b)) return(a + rep(b, each = nrow(a)))
  if (!is.matrix(a) && is.matrix(b)) return(b + rep(a, each = nrow(b)))
  a + b
}

#' Coordinate systems
#'
#' `Axes()` draws an x and a y [NumberLine()] that cross at the origin of the
#' coordinates. `ThreeDAxes()` adds a z axis. `NumberPlane()` adds a grid of
#' background lines, `PolarPlane()` a polar grid, and `ComplexPlane()` a
#' plane addressed by complex numbers.
#'
#' All coordinate systems share these methods (`CoordinateSystemClass`):
#' `coords_to_point()` (alias `c2p`), `point_to_coords()` (alias `p2c`),
#' `polar_to_point()` (`pr2pt`), `point_to_polar()` (`pt2pr`), `get_axis(i)`
#' (1 based), `get_x_axis()`, `get_y_axis()`, `get_z_axis()`, `get_origin()`,
#' `get_x_axis_label()`, `get_y_axis_label()`, `get_axis_labels()`,
#' `add_coordinates()`, `plot()`, `plot_implicit_curve()`,
#' `plot_parametric_curve()`, `plot_polar_graph()`, `plot_surface()`,
#' `plot_derivative_graph()`, `plot_antiderivative_graph()`,
#' `input_to_graph_point()` (`i2gp`), `input_to_graph_coords()` (`i2gc`),
#' `get_graph_label()`, `get_riemann_rectangles()`, `get_area()`,
#' `angle_of_tangent()`, `slope_of_tangent()`, `get_secant_slope_group()`,
#' `get_vertical_line()`, `get_horizontal_line()`, `get_lines_to_point()`,
#' `get_vertical_lines_to_graph()` and `get_T_label()`. `Axes` adds
#' `plot_line_graph()`.
#'
#' Shapes follow upstream: `c2p(x, y)` with numbers, or `c2p(c(x, y))`,
#' returns one point; `c2p(m)` with an n x k matrix whose rows are
#' coordinates returns an n x 3 matrix of points; `c2p(xs, ys)` with vectors
#' returns a 3 x n matrix (rows x, y, z). `p2c()` returns a vector for one
#' point and an n x d matrix for an n x 3 matrix of points.
#'
#' Differences from Python: the point function of a graph is `graph$func`
#' (`function` is reserved in R); axis indices and `colorscale_axis` are 1
#' based; dictionaries become lists named by the numeric positions, for
#' example `list("1" = "a", "2" = "b")`.
#'
#' @param x_range,y_range,z_range `c(min, max, step)` of each axis.
#' @param x_length,y_length,z_length Lengths of the axes.
#' @param dimension Number of axes of a coordinate system, 2 or 3.
#' @param axis_config,x_axis_config,y_axis_config,z_axis_config Lists of
#'   arguments for the [NumberLine()] of every axis or of one axis.
#' @param tips Whether the axes get arrow tips.
#' @param ... Passed to [VGroup()] (style).
#' @return A coordinate system mobject.
#' @name coordinate_systems
#' @examples
#' \dontrun{
#' ax <- Axes(x_range = c(-3, 3), y_range = c(-2, 2))
#' g <- ax$plot(sin, color = BLUE)
#' area <- ax$get_area(g, x_range = c(0, 2))
#' plane <- NumberPlane()
#' }
NULL

#' @rdname coordinate_systems
#' @format NULL
#' @usage NULL
#' @export
CoordinateSystemClass <- R6::R6Class("CoordinateSystem", inherit = VGroupClass, lock_objects = FALSE,
  public = list(
    dimension = 2,
    x_range = NULL,
    y_range = NULL,
    x_length = NULL,
    y_length = NULL,
    num_sampled_graph_points_per_tick = 10,
    x_axis = NULL,
    y_axis = NULL,
    z_axis = NULL,
    axes = NULL,
    coordinate_labels = NULL,
    axis_labels = NULL,

    initialize = function(x_range = NULL, y_range = NULL, x_length = NULL, y_length = NULL, dimension = 2, ...) {
      self$dimension <- dimension
      if (is.null(x_range)) x_range <- c(round(-frame_x_radius()), round(frame_x_radius()), 1)
      else if (length(x_range) == 2) x_range <- c(x_range, 1)
      if (is.null(y_range)) y_range <- c(round(-frame_y_radius()), round(frame_y_radius()), 1)
      else if (length(y_range) == 2) y_range <- c(y_range, 1)
      self$x_range <- as.numeric(x_range)
      self$y_range <- as.numeric(y_range)
      self$x_length <- x_length
      self$y_length <- y_length
      self$num_sampled_graph_points_per_tick <- 10
      super$initialize(...)
    },

    coords_to_point = function(...) stop("coords_to_point is not implemented for ", class(self)[1], call. = FALSE),
    point_to_coords = function(point) stop("point_to_coords is not implemented for ", class(self)[1], call. = FALSE),
    polar_to_point = function(radius, azimuth) self$coords_to_point(radius * cos(azimuth), radius * sin(azimuth)),
    point_to_polar = function(point) {
      xy <- self$point_to_coords(point)
      c(sqrt(xy[1]^2 + xy[2]^2), atan2(xy[2], xy[1]))
    },
    c2p = function(...) self$coords_to_point(...),
    p2c = function(point) self$point_to_coords(point),
    pr2pt = function(radius, azimuth) self$polar_to_point(radius, azimuth),
    pt2pr = function(point) self$point_to_polar(point),
    get_axes = function() stop("get_axes is not implemented for ", class(self)[1], call. = FALSE),
    get_axis = function(index) self$get_axes()$submobjects[[index]],
    get_origin = function() self$coords_to_point(0, 0),
    get_x_axis = function() self$get_axis(1),
    get_y_axis = function() self$get_axis(2),
    get_z_axis = function() self$get_axis(3),
    get_x_unit_size = function() self$get_x_axis()$get_unit_size(),
    get_y_unit_size = function() self$get_y_axis()$get_unit_size(),
    origin_shift = function(axis_range) axes_origin_shift(axis_range),

    # Labels ---------------------------------------------------------------
    get_x_axis_label = function(label, edge = UR, direction = UR, buff = SMALL_BUFF, ...) {
      self$get_axis_label(label, self$get_x_axis(), edge, direction, buff = buff)
    },
    get_y_axis_label = function(label, edge = UR, direction = UP * 0.5 + RIGHT, buff = SMALL_BUFF, ...) {
      self$get_axis_label(label, self$get_y_axis(), edge, direction, buff = buff)
    },
    get_axis_label = function(label, axis, edge, direction, buff = SMALL_BUFF) {
      label_mobject <- self$x_axis$create_label_tex(label)
      label_mobject$next_to(axis$get_edge_center(edge), direction = direction, buff = buff)
      label_mobject$shift_onto_screen(buff = MED_SMALL_BUFF)
      label_mobject
    },
    get_axis_labels = function(...) stop("get_axis_labels is not implemented for ", class(self)[1], call. = FALSE),
    add_coordinates = function(...) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      axes_numbers <- args[nm == ""]
      kwargs <- args[nm != ""]
      self$coordinate_labels <- VGroup()
      axes <- self$axes$submobjects
      if (!length(axes_numbers)) axes_numbers <- vector("list", self$dimension)
      for (i in seq_len(min(length(axes), length(axes_numbers)))) {
        axis <- axes[[i]]
        values <- axes_numbers[[i]]
        if (!is.null(values) && !is.null(names(values))) {
          do.call(axis$add_labels, c(list(as.list(values)), kwargs))
          labels <- axis$labels
        } else if (is.null(values) && isTRUE(axis$scaling$custom_labels)) {
          tick_range <- axis$get_tick_range()
          axis$add_labels(stats::setNames(axis$scaling$get_custom_labels(tick_range), tick_range))
          labels <- axis$labels
        } else {
          do.call(axis$add_numbers, c(list(values), kwargs))
          labels <- axis$numbers
        }
        self$coordinate_labels$add(labels)
      }
      invisible(self)
    },

    # Lines to points -------------------------------------------------------
    get_line_from_axis_to_point = function(index, point, line_func = DashedLine, line_config = NULL,
                                           color = NULL, stroke_width = 2) {
      line_config <- line_config %||% list()
      line_config$color <- manim_color(color %||% "#FFFFFF")
      line_config$stroke_width <- stroke_width
      axis <- self$get_axis(index)
      do.call(call_constructor, c(list(line_func, axis$get_projection(point), as_point(point)), line_config))
    },
    get_vertical_line = function(point, ...) self$get_line_from_axis_to_point(1, point, ...),
    get_horizontal_line = function(point, ...) self$get_line_from_axis_to_point(2, point, ...),
    get_lines_to_point = function(point, ...) {
      VGroup(self$get_horizontal_line(point, ...), self$get_vertical_line(point, ...))
    },

    # Graphing ---------------------------------------------------------------
    plot = function(func, x_range = NULL, ..., use_vectorized = FALSE, colorscale = NULL, colorscale_axis = 2) {
      t_range <- self$x_range
      if (!is.null(x_range)) t_range[seq_along(x_range)] <- x_range
      if (is.null(x_range) || length(x_range) < 3) t_range[3] <- t_range[3] / self$num_sampled_graph_points_per_tick
      # A vector t gives coordinate rows (3 x n), as ParametricFunction expects.
      graph <- ParametricFunction(
        function(t) self$coords_to_point(t, func(t)),
        t_range = t_range, scaling = self$x_axis$scaling, use_vectorized = use_vectorized, ...
      )
      graph$underlying_function <- func
      if (!is.null(colorscale)) {
        if (is.list(colorscale)) {
          new_colors <- vapply(colorscale, function(p) as.character(p[[1]]), "")
          pivots <- vapply(colorscale, function(p) as.numeric(p[[2]]), 0)
        } else {
          new_colors <- colorscale
          rng <- list(self$x_range, self$y_range)[[colorscale_axis]]
          freq <- (rng[2] - rng[1]) / (length(new_colors) - 1)
          pivots <- np_arange(rng[1], rng[2] + freq, freq)
        }
        # Upstream needs an explicit x_range here; fall back to the plotted range.
        xr <- x_range %||% t_range[1:2]
        resolution <- if (length(xr) == 2) 0.01 else xr[3]
        color_list <- vapply(np_arange(xr[1], xr[2] + resolution, resolution), function(sx) {
          v <- c(sx, func(sx))[colorscale_axis]
          if (v <= pivots[1]) return(manim_color(new_colors[1]))
          if (v >= pivots[length(pivots)]) return(manim_color(new_colors[length(new_colors)]))
          i <- which(pivots > v)[1]
          ci <- min((v - pivots[i - 1]) / (pivots[i] - pivots[i - 1]), 1)
          interpolate_color(new_colors[i - 1], new_colors[i], ci)
        }, "")
        graph$set_stroke(color_list)
        graph$set_sheen_direction(RIGHT)
      }
      graph
    },
    plot_implicit_curve = function(func, min_depth = 5, max_quads = 1500, ...) {
      xs <- self$get_x_axis()$scaling
      ys <- self$get_y_axis()$scaling
      graph <- ImplicitFunction(function(x, y) func(xs$func(x), ys$func(y)),
                                x_range = self$x_range[1:2], y_range = self$y_range[1:2],
                                min_depth = min_depth, max_quads = max_quads, ...)
      graph$stretch(self$get_x_unit_size(), 1, about_point = ORIGIN)
      graph$stretch(self$get_y_unit_size(), 2, about_point = ORIGIN)
      graph$shift(self$get_origin())
      graph
    },
    plot_parametric_curve = function(func, use_vectorized = FALSE, ...) {
      dim <- self$dimension
      graph <- ParametricFunction(function(t) {
        if (!use_vectorized) return(do.call(self$coords_to_point, utils::head(as.list(func(t)), dim)))
        # Upstream passes the first `dim` coordinate rows to coords_to_point,
        # which then returns coordinate rows again.
        pts <- vectorized_points(func(t), length(t))
        do.call(self$coords_to_point, lapply(seq_len(dim), function(j) pts[, j]))
      }, use_vectorized = use_vectorized, ...)
      graph$underlying_function <- func
      graph
    },
    plot_polar_graph = function(r_func, theta_range = NULL, ...) {
      graph <- ParametricFunction(function(th) self$pr2pt(r_func(th), th),
                                  t_range = theta_range %||% c(0, 2 * PI), ...)
      graph$underlying_function <- r_func
      graph
    },
    plot_surface = function(func, u_range = NULL, v_range = NULL, ..., colorscale = NULL, colorscale_axis = 3) {
      args <- c(list(function(u, v) self$c2p(u, v, func(u, v))), list(u_range = u_range, v_range = v_range), list(...))
      surface <- do.call(Surface, args[!vapply(args, is.null, TRUE)])
      if (!is.null(colorscale)) {
        surface$set_fill_by_value(axes = self$copy(), colorscale = colorscale, axis = colorscale_axis)
      }
      surface
    },
    input_to_graph_point = function(x, graph) {
      if (!is.null(graph$underlying_function)) return(graph$func(x))
      alpha <- binary_search(function(a) self$point_to_coords(graph$point_from_proportion(a))[1],
                                   target = x, lower_bound = 0, upper_bound = 1)
      if (is.null(alpha)) {
        stop("x=", x, " not located in the range of the graph ([", self$p2c(graph$get_start())[1], ", ",
             self$p2c(graph$get_end())[1], "])", call. = FALSE)
      }
      graph$point_from_proportion(alpha)
    },
    input_to_graph_coords = function(x, graph) c(x, graph$underlying_function(x)),
    i2gc = function(x, graph) self$input_to_graph_coords(x, graph),
    i2gp = function(x, graph) self$input_to_graph_point(x, graph),
    get_graph_label = function(graph, label = "f(x)", x_val = NULL, direction = RIGHT, buff = MED_SMALL_BUFF,
                               color = NULL, dot = FALSE, dot_config = NULL) {
      dot_config <- dot_config %||% list()
      color <- color %||% graph$get_color()
      label_object <- self$x_axis$create_label_tex(label)$set_color(color)
      if (is.null(x_val)) {
        for (x in seq(self$x_range[2], self$x_range[1], length.out = 100)) {
          point <- self$input_to_graph_point(x, graph)
          if (point[2] < frame_y_radius()) break
        }
      } else {
        point <- self$input_to_graph_point(x_val, graph)
      }
      label_object$next_to(point, direction, buff = buff)
      label_object$shift_onto_screen()
      if (isTRUE(dot)) {
        d <- do.call(Dot, c(list(point = point), dot_config))
        label_object$add(d)
        label_object$dot <- d
      }
      label_object
    },

    # Calculus ---------------------------------------------------------------
    get_riemann_rectangles = function(graph, x_range = NULL, dx = 0.1, input_sample_type = "left",
                                      stroke_width = 1, stroke_color = BLACK, fill_opacity = 1,
                                      color = c(BLUE, GREEN), show_signed_area = TRUE, bounded_graph = NULL,
                                      blend = FALSE, width_scale_factor = 1.001) {
      if (is.null(x_range)) {
        x_range <- if (is.null(bounded_graph)) c(graph$t_min, graph$t_max)
          else c(max(graph$t_min, bounded_graph$t_min), min(graph$t_max, bounded_graph$t_max))
      }
      xs <- np_arange(x_range[1], x_range[2], dx)
      colors <- color_gradient(vapply(unlist(color), manim_color, "", USE.NAMES = FALSE), length(xs))
      rectangles <- VGroup()
      for (k in seq_along(xs)) {
        x <- xs[k]
        col <- colors[k]
        sample_input <- switch(input_sample_type,
          left = x, right = x + dx, center = x + 0.5 * dx,
          stop("Invalid input sample type", call. = FALSE))
        graph_point <- self$input_to_graph_point(sample_input, graph)
        y_point <- if (is.null(bounded_graph)) self$origin_shift(self$y_range) else bounded_graph$underlying_function(x)
        points <- VGroup(VectorizedPoint(self$coords_to_point(x, y_point)),
                         VectorizedPoint(self$coords_to_point(x + width_scale_factor * dx, y_point)),
                         VectorizedPoint(graph_point))
        rect <- Rectangle()$replace(points, stretch = TRUE)
        rectangles$add(rect)
        if (self$p2c(graph_point)[2] < y_point && show_signed_area) col <- invert_color(col)
        if (blend) stroke_color <- col
        rect$set_style(fill_color = col, fill_opacity = fill_opacity, stroke_color = stroke_color,
                       stroke_width = stroke_width)
      }
      rectangles
    },
    get_area = function(graph, x_range = NULL, color = c(BLUE, GREEN), opacity = 0.3, bounded_graph = NULL, ...) {
      if (is.null(x_range)) {
        a <- graph$t_min
        b <- graph$t_max
      } else {
        a <- x_range[1]
        b <- x_range[2]
      }
      if (!is.null(bounded_graph)) {
        if (bounded_graph$t_min > b) stop("Ranges not matching: ", bounded_graph$t_min, " < ", b, call. = FALSE)
        if (bounded_graph$t_max < a) stop("Ranges not matching: ", bounded_graph$t_max, " > ", a, call. = FALSE)
        a <- max(a, bounded_graph$t_min)
        b <- min(b, bounded_graph$t_max)
      }
      inside <- function(g) {
        px <- self$p2c(g$points)
        px <- if (is.matrix(px)) px[, 1] else px[1]
        g$points[a <= px & px <= b, , drop = FALSE]
      }
      if (is.null(bounded_graph)) {
        points <- rbind(self$c2p(a), graph$func(a), inside(graph), graph$func(b), self$c2p(b))
      } else {
        g1 <- rbind(graph$func(a), inside(graph), graph$func(b))
        g2 <- rbind(bounded_graph$func(a), inside(bounded_graph), bounded_graph$func(b))
        points <- rbind(g1, g2[rev(seq_len(nrow(g2))), , drop = FALSE])
      }
      Polygon(unname(points), ...)$set_opacity(opacity)$set_color(color)
    },
    angle_of_tangent = function(x, graph, dx = 1e-8) {
      p0 <- self$input_to_graph_coords(x, graph)
      p1 <- self$input_to_graph_coords(x + dx, graph)
      angle_of_vector(p1 - p0)
    },
    slope_of_tangent = function(x, graph, ...) tan(self$angle_of_tangent(x, graph, ...)),
    plot_derivative_graph = function(graph, color = GREEN, ...) {
      self$plot(function(x) self$slope_of_tangent(x, graph), color = color, ...)
    },
    plot_antiderivative_graph = function(graph, y_intercept = 0, samples = 50, use_vectorized = FALSE, ...) {
      f <- graph$underlying_function
      antideriv1 <- function(x) {
        xv <- seq(0, x, length.out = samples)
        yv <- vapply(xv, function(v) as.numeric(f(v)), 0)
        sum(diff(xv) * (yv[-1] + yv[-samples]) / 2) + y_intercept
      }
      antideriv <- if (use_vectorized) function(x) vapply(x, antideriv1, 0) else antideriv1
      self$plot(antideriv, use_vectorized = use_vectorized, ...)
    },
    get_secant_slope_group = function(x, graph, dx = NULL, dx_line_color = PURE_YELLOW, dy_line_color = NULL,
                                      dx_label = NULL, dy_label = NULL, include_secant_line = TRUE,
                                      secant_line_color = GREEN, secant_line_length = 10) {
      group <- VGroup()
      if (is.null(dx) || dx == 0) dx <- (self$x_range[2] - self$x_range[1]) / 10
      dy_line_color <- dy_line_color %||% graph$get_color()
      p1 <- self$input_to_graph_point(x, graph)
      p2 <- self$input_to_graph_point(x + dx, graph)
      interim_point <- p2[1] * RIGHT + p1[2] * UP
      group$dx_line <- Line(p1, interim_point, color = dx_line_color)
      group$df_line <- Line(interim_point, p2, color = dy_line_color)
      group$add(group$dx_line, group$df_line)
      labels <- VGroup()
      if (!is.null(dx_label)) {
        group$dx_label <- self$x_axis$create_label_tex(dx_label)
        labels$add(group$dx_label)
        group$add(group$dx_label)
      }
      if (!is.null(dy_label)) {
        group$df_label <- self$x_axis$create_label_tex(dy_label)
        labels$add(group$df_label)
        group$add(group$df_label)
      }
      if (length(labels$submobjects) > 0) {
        max_width <- 0.8 * group$dx_line$width
        max_height <- 0.8 * group$df_line$height
        if (labels$width > max_width) labels$width <- max_width
        if (labels$height > max_height) labels$height <- max_height
      }
      if (!is.null(dx_label)) {
        group$dx_label$next_to(group$dx_line, sign(dx) * DOWN, buff = group$dx_label$height / 2)
        group$dx_label$set_color(group$dx_line$get_color())
      }
      if (!is.null(dy_label)) {
        group$df_label$next_to(group$df_line, sign(dx) * RIGHT, buff = group$df_label$height / 2)
        group$df_label$set_color(group$df_line$get_color())
      }
      if (include_secant_line) {
        group$secant_line <- Line(p1, p2, color = secant_line_color)
        group$secant_line$scale(secant_line_length / group$secant_line$get_length())
        group$add(group$secant_line)
      }
      group
    },
    get_vertical_lines_to_graph = function(graph, x_range = NULL, num_lines = 20, ...) {
      x_range <- x_range %||% self$x_range
      VGroup(lapply(seq(x_range[1], x_range[2], length.out = num_lines), function(x) {
        self$get_vertical_line(self$i2gp(x, graph), ...)
      }))
    },
    get_T_label = function(x_val, graph, label = NULL, label_color = NULL, triangle_size = MED_SMALL_BUFF,
                           triangle_color = WHITE, line_func = Line, line_color = PURE_YELLOW) {
      T_label_group <- VGroup()
      triangle <- RegularPolygon(n = 3, start_angle = pi / 2, stroke_width = 0)$set_fill(color = triangle_color, opacity = 1)
      triangle$height <- triangle_size
      triangle$move_to(self$coords_to_point(x_val, 0), UP)
      if (!is.null(label)) {
        t_label <- if (is.null(label_color)) self$x_axis$create_label_tex(label)
          else self$x_axis$create_label_tex(label, color = label_color)
        t_label$next_to(triangle, DOWN)
        T_label_group$add(t_label)
      }
      v_line <- self$get_vertical_line(self$i2gp(x_val, graph), color = line_color, line_func = line_func)
      T_label_group$add(triangle, v_line)
      T_label_group
    }
  )
)

#' @rdname coordinate_systems
#' @format NULL
#' @usage NULL
#' @export
AxesClass <- R6::R6Class("Axes", inherit = CoordinateSystemClass, lock_objects = FALSE,
  public = list(
    axis_config = NULL,
    x_axis_config = NULL,
    y_axis_config = NULL,

    initialize = function(x_range = NULL, y_range = NULL, x_length = round(frame_width()) - 2,
                          y_length = round(frame_height()) - 2, axis_config = NULL, x_axis_config = NULL,
                          y_axis_config = NULL, tips = TRUE, ...) {
      super$initialize(x_range = x_range, y_range = y_range, x_length = x_length, y_length = y_length, ...)
      self$axis_config <- update_config(list(include_tip = tips, numbers_to_exclude = 0), axis_config)
      self$x_axis_config <- update_config(self$axis_config, update_config(list(), x_axis_config))
      self$y_axis_config <- update_config(self$axis_config,
                                          update_config(list(rotation = 90 * DEGREES, label_direction = LEFT), y_axis_config))
      # Excluding the origin tick only makes sense for linear scalings.
      linear <- function(cfg) is.null(cfg$scaling) || inherits(cfg$scaling, "LinearBase")
      self$x_axis_config$exclude_origin_tick <- linear(self$x_axis_config)
      self$y_axis_config$exclude_origin_tick <- linear(self$y_axis_config)
      self$x_axis <- self$create_axis(self$x_range, self$x_axis_config, self$x_length)
      self$y_axis <- self$create_axis(self$y_range, self$y_axis_config, self$y_length)
      self$axes <- VGroup(self$x_axis, self$y_axis)
      self$add(self$axes$submobjects)
      center <- vapply(self$axes$submobjects, function(ax) ax$scaling$func((ax$x_range[2] + ax$x_range[1]) / 2), 0)
      self$shift(-do.call(self$coords_to_point, as.list(center)))
    },
    create_axis = function(range_terms, axis_config, length) {
      axis_config$length <- length
      axis <- do.call(NumberLine, c(list(x_range = range_terms), axis_config))
      axis$shift(-axis$number_to_point(self$origin_shift(c(axis$x_min, axis$x_max))))
      axis
    },
    coords_to_point = function(...) {
      coords <- list(...)
      rows_input <- FALSE
      if (length(coords) == 1) {
        a <- coords[[1]]
        if (is.matrix(a) && nrow(a) > 1) {
          rows_input <- TRUE
          coords <- lapply(seq_len(ncol(a)), function(j) a[, j])
        } else if (is.list(a)) {
          coords <- a
        } else {
          coords <- as.list(as.numeric(a))
        }
      }
      origin <- self$x_axis$number_to_point(self$origin_shift(c(self$x_axis$x_min, self$x_axis$x_max)))
      axes <- self$axes$submobjects
      points <- axes[[1]]$number_to_point(coords[[1]])
      for (i in seq_len(min(length(axes), length(coords)))[-1]) {
        points <- add_points(points, add_points(axes[[i]]$number_to_point(coords[[i]]), -origin))
      }
      if (is.matrix(points) && !rows_input) return(t(points))
      points
    },
    point_to_coords = function(point) {
      res <- lapply(self$get_axes()$submobjects, function(ax) ax$point_to_number(point))
      if (is.matrix(point)) do.call(cbind, res) else unlist(res)
    },
    get_axes = function() self$axes,
    get_axis_labels = function(x_label = "x", y_label = "y") {
      self$axis_labels <- VGroup(self$get_x_axis_label(x_label), self$get_y_axis_label(y_label))
      self$axis_labels
    },
    plot_line_graph = function(x_values, y_values, z_values = NULL, line_color = PURE_YELLOW, add_vertex_dots = TRUE,
                               vertex_dot_radius = DEFAULT_DOT_RADIUS, vertex_dot_style = NULL, ...) {
      z_values <- z_values %||% rep(0, length(x_values))
      if (length(x_values) != length(y_values) || length(x_values) != length(z_values)) {
        stop("x_values, y_values and z_values must have the same length.", call. = FALSE)
      }
      line_graph <- VDict()
      graph <- VGroup(color = line_color, ...)
      vertices <- t(vapply(seq_along(x_values), function(i) {
        as_point(self$coords_to_point(x_values[i], y_values[i], z_values[i]))
      }, numeric(3)))
      graph$set_points_as_corners(vertices)
      line_graph$add_key_value_pair("line_graph", graph)
      if (add_vertex_dots) {
        style <- vertex_dot_style %||% list()
        dots <- VGroup(lapply(seq_len(nrow(vertices)), function(i) {
          do.call(Dot, c(list(point = vertices[i, ], radius = vertex_dot_radius), style))
        }))
        line_graph$add_key_value_pair("vertex_dots", dots)
      }
      line_graph
    }
  )
)

#' @rdname coordinate_systems
#' @export
Axes <- constructor(AxesClass)
#' @rdname coordinate_systems
#' @param z_normal Direction the z axis is rotated toward before tilting.
#' @param num_axis_pieces Number of pieces each axis is cut into for 3D depth sorting.
#' @param light_source Light direction; stored, but the upstream axis sheen is not applied.
#' @param depth,gloss Unused; kept for compatibility.
#' @format NULL
#' @usage NULL
#' @export
ThreeDAxesClass <- R6::R6Class("ThreeDAxes", inherit = AxesClass, lock_objects = FALSE,
  public = list(
    z_range = NULL,
    z_length = NULL,
    z_axis_config = NULL,
    z_normal = NULL,
    num_axis_pieces = 20,
    light_source = NULL,

    initialize = function(x_range = c(-6, 6, 1), y_range = c(-5, 5, 1), z_range = c(-4, 4, 1),
                          x_length = frame_height() + 2.5, y_length = frame_height() + 2.5,
                          z_length = frame_height() - 1.5, z_axis_config = NULL, z_normal = DOWN,
                          num_axis_pieces = 20, light_source = 9 * DOWN + 7 * LEFT + 10 * OUT,
                          depth = NULL, gloss = 0.5, ...) {
      super$initialize(x_range = x_range, x_length = x_length, y_range = y_range, y_length = y_length, ...)
      if (length(z_range) == 2) z_range <- c(z_range, 1)
      self$z_range <- as.numeric(z_range)
      self$z_length <- z_length
      self$z_axis_config <- update_config(self$axis_config, update_config(list(), z_axis_config))
      self$z_normal <- as_point(z_normal)
      self$num_axis_pieces <- num_axis_pieces
      self$light_source <- as_point(light_source)
      self$dimension <- 3
      cfg <- self$z_axis_config
      self$z_axis_config$exclude_origin_tick <- is.null(cfg$scaling) || inherits(cfg$scaling, "LinearBase")
      z_axis <- self$create_axis(self$z_range, self$z_axis_config, self$z_length)
      z_origin <- self$origin_shift(c(z_axis$x_min, z_axis$x_max))
      z_axis$rotate_about_number(z_origin, -PI / 2, UP)
      z_axis$rotate_about_number(z_origin, angle_of_vector(self$z_normal))
      z_axis$shift(-z_axis$number_to_point(z_origin))
      z_axis$shift(self$x_axis$number_to_point(self$origin_shift(c(self$x_axis$x_min, self$x_axis$x_max))))
      self$axes$add(z_axis)
      self$add(z_axis)
      self$z_axis <- z_axis
      self$add_3d_pieces()
      # Limitation: upstream also sets sheen 0.2 on every axis submobject, shaded along
      # light_source. The camera's mask based gradient stroke made one ThreeDAxes frame
      # take minutes, so the sheen is skipped; add it back once gradient strokes are cheap.
    },
    add_3d_pieces = function() {
      for (axis in self$axes$submobjects) {
        # Like Mobject$get_pieces(), but from a bare VMobject: copying the whole
        # NumberLine (ticks, tip, labels) for every piece is very slow in R6.
        template <- VMobject()
        template$match_style(axis, family = FALSE)
        alphas <- seq(0, 1, length.out = self$num_axis_pieces + 1)
        axis$pieces <- VGroup(lapply(seq_len(self$num_axis_pieces), function(i) {
          template$copy()$pointwise_become_partial(axis, alphas[i], alphas[i + 1])
        }))
        axis$add(axis$pieces)
        axis$set_stroke(width = 0, family = FALSE)
        axis$set_shade_in_3d(TRUE)
      }
      invisible(self)
    },
    get_y_axis_label = function(label, edge = UR, direction = UR, buff = SMALL_BUFF, rotation = PI / 2,
                                rotation_axis = OUT, ...) {
      lab <- self$get_axis_label(label, self$get_y_axis(), edge, direction, buff = buff)
      lab$rotate(rotation, axis = rotation_axis)
      lab
    },
    get_z_axis_label = function(label, edge = OUT, direction = RIGHT, buff = SMALL_BUFF, rotation = PI / 2,
                                rotation_axis = RIGHT, ...) {
      lab <- self$get_axis_label(label, self$get_z_axis(), edge, direction, buff = buff)
      lab$rotate(rotation, axis = rotation_axis)
      lab
    },
    get_axis_labels = function(x_label = "x", y_label = "y", z_label = "z") {
      self$axis_labels <- VGroup(self$get_x_axis_label(x_label), self$get_y_axis_label(y_label),
                                 self$get_z_axis_label(z_label))
      self$axis_labels
    }
  )
)

#' @rdname coordinate_systems
#' @export
ThreeDAxes <- constructor(ThreeDAxesClass)
# Shared by NumberPlane and PolarPlane: style and add the grid lines.
init_background_lines <- function(self) {
  if (is.null(self$faded_line_style)) {
    style <- self$background_line_style
    for (k in names(style)) if (is.numeric(style[[k]])) style[[k]] <- style[[k]] * 0.5
    self$faded_line_style <- style
  }
  lines <- self$get_lines()
  self$background_lines <- lines[[1]]
  self$faded_lines <- lines[[2]]
  do.call(self$background_lines$set_style, self$background_line_style)
  do.call(self$faded_lines$set_style, self$faded_line_style)
  self$add_to_back(self$faded_lines, self$background_lines)
  invisible(self)
}

# Insert curves so that a nonlinear function bends straight lines smoothly.
prepare_for_nonlinear <- function(self, num_inserted_curves) {
  for (mob in self$family_members_with_points()) {
    n <- mob$get_num_curves()
    if (num_inserted_curves > n) mob$insert_n_curves(num_inserted_curves - n)
  }
  invisible(self)
}

#' @rdname coordinate_systems
#' @param background_line_style List of style arguments for the grid lines.
#' @param faded_line_style Style of the faded lines; defaults to a halved
#'   `background_line_style`.
#' @param faded_line_ratio Number of faded lines per grid cell.
#' @param make_smooth_after_applying_functions Accepted for compatibility;
#'   upstream's VMobject initializer resets it to `FALSE`, so it has no effect.
#' @format NULL
#' @usage NULL
#' @export
NumberPlaneClass <- R6::R6Class("NumberPlane", inherit = AxesClass, lock_objects = FALSE,
  public = list(
    background_line_style = NULL,
    faded_line_style = NULL,
    faded_line_ratio = 1,
    background_lines = NULL,
    faded_lines = NULL,
    x_lines = NULL,
    y_lines = NULL,

    initialize = function(x_range = c(-frame_x_radius(), frame_x_radius(), 1),
                          y_range = c(-frame_y_radius(), frame_y_radius(), 1), x_length = NULL, y_length = NULL,
                          background_line_style = NULL, faded_line_style = NULL, faded_line_ratio = 1,
                          make_smooth_after_applying_functions = TRUE, axis_config = NULL, y_axis_config = NULL, ...) {
      axis_config <- update_config(list(stroke_width = 2, include_ticks = FALSE, include_tip = FALSE,
                                        line_to_number_buff = SMALL_BUFF, label_direction = DR, font_size = 24),
                                   axis_config)
      y_axis_config <- update_config(list(label_direction = DR), y_axis_config)
      self$background_line_style <- update_config(list(stroke_color = BLUE_D, stroke_width = 2, stroke_opacity = 1),
                                                  background_line_style)
      self$faded_line_style <- faded_line_style
      self$faded_line_ratio <- faded_line_ratio
      super$initialize(x_range = x_range, y_range = y_range, x_length = x_length, y_length = y_length,
                       axis_config = axis_config, y_axis_config = y_axis_config, ...)
      init_background_lines(self)
    },
    get_lines = function() {
      x_axis <- self$get_x_axis()
      y_axis <- self$get_y_axis()
      xl <- self$get_lines_parallel_to_axis(x_axis, y_axis, self$y_axis$x_range[3], self$faded_line_ratio)
      yl <- self$get_lines_parallel_to_axis(y_axis, x_axis, self$x_axis$x_range[3], self$faded_line_ratio)
      self$x_lines <- xl[[1]]
      self$y_lines <- yl[[1]]
      list(VGroup(xl[[1]]$submobjects, yl[[1]]$submobjects), VGroup(xl[[2]]$submobjects, yl[[2]]$submobjects))
    },
    get_lines_parallel_to_axis = function(axis_parallel_to, axis_perpendicular_to, freq, ratio_faded_lines) {
      line <- Line(axis_parallel_to$get_start(), axis_parallel_to$get_end())
      if (ratio_faded_lines == 0) ratio_faded_lines <- 1
      step <- (1 / ratio_faded_lines) * freq
      lines1 <- VGroup()
      lines2 <- VGroup()
      unit_vector <- axis_perpendicular_to$get_unit_vector()
      x_min <- axis_perpendicular_to$x_range[1]
      x_max <- axis_perpendicular_to$x_range[2]
      # Logarithmic axes have no negative values: treat c(-2, 4) like c(0, 6).
      if (axis_perpendicular_to$x_min > 0 && x_min < 0) {
        x_max <- abs(x_min) + abs(x_max)
        x_min <- 0
      }
      ranges <- list(0, np_arange(step, min(x_max - x_min, x_max), step),
                     np_arange(-step, max(x_min - x_max, x_min), -step))
      for (inputs in ranges) {
        for (k in seq_along(inputs)) {
          new_line <- line$copy()
          new_line$shift(unit_vector * inputs[k])
          if (k %% ratio_faded_lines == 0) lines1$add(new_line) else lines2$add(new_line)
        }
      }
      list(lines1, lines2)
    },
    get_vector = function(coords, ...) {
      Arrow(self$coords_to_point(0, 0), do.call(self$coords_to_point, as.list(coords)), buff = 0, ...)
    },
    prepare_for_nonlinear_transform = function(num_inserted_curves = 50) prepare_for_nonlinear(self, num_inserted_curves)
  )
)

#' @rdname coordinate_systems
#' @export
NumberPlane <- constructor(NumberPlaneClass)
#' @rdname coordinate_systems
#' @param radius_max Largest radius drawn.
#' @param size Diameter of the plane; `NULL` means one unit per radius step.
#' @param radius_step Spacing of the circles.
#' @param azimuth_step Number of radial lines (or the angle units per line).
#' @param azimuth_units One of `"PI radians"`, `"TAU radians"`, `"degrees"`,
#'   `"gradians"` or `NULL`.
#' @param azimuth_compact_fraction Whether to write labels like
#'   \eqn{\frac{\pi}{4}} instead of \eqn{\frac{1}{4}\pi}.
#' @param azimuth_offset Angle of the first radial line.
#' @param azimuth_direction `"CCW"` or `"CW"`.
#' @param azimuth_label_buff,azimuth_label_font_size Azimuth label layout.
#' @param radius_config List of arguments for the radius [NumberLine()].
#' @format NULL
#' @usage NULL
#' @export
PolarPlaneClass <- R6::R6Class("PolarPlane", inherit = AxesClass, lock_objects = FALSE,
  public = list(
    azimuth_units = "PI radians",
    azimuth_direction = "CCW",
    azimuth_step = 20,
    azimuth_offset = 0,
    azimuth_label_buff = SMALL_BUFF,
    azimuth_label_font_size = 24,
    azimuth_compact_fraction = TRUE,
    radius_config = NULL,
    background_line_style = NULL,
    faded_line_style = NULL,
    faded_line_ratio = 1,
    background_lines = NULL,
    faded_lines = NULL,

    initialize = function(radius_max = frame_y_radius(), size = NULL, radius_step = 1, azimuth_step = NULL,
                          azimuth_units = "PI radians", azimuth_compact_fraction = TRUE, azimuth_offset = 0,
                          azimuth_direction = "CCW", azimuth_label_buff = SMALL_BUFF, azimuth_label_font_size = 24,
                          radius_config = NULL, background_line_style = NULL, faded_line_style = NULL,
                          faded_line_ratio = 1, make_smooth_after_applying_functions = TRUE, ...) {
      units <- c("PI radians", "TAU radians", "degrees", "gradians")
      if (!is.null(azimuth_units) && !azimuth_units %in% units) {
        stop("Invalid azimuth units. Expected one of: PI radians, TAU radians, degrees, gradians or None.", call. = FALSE)
      }
      if (!azimuth_direction %in% c("CW", "CCW")) stop("Invalid azimuth units. Expected one of: CW, CCW.", call. = FALSE)
      self$azimuth_units <- azimuth_units
      self$azimuth_direction <- azimuth_direction
      # Upstream builds the range as a float array, so labels show one decimal place.
      self$radius_config <- update_config(list(stroke_width = 2, include_ticks = FALSE, include_tip = FALSE,
                                               line_to_number_buff = SMALL_BUFF, label_direction = DL, font_size = 24,
                                               decimal_number_config = list(
                                                 num_decimal_places = max(1L, decimal_places_from_step(radius_step)))),
                                          radius_config)
      self$background_line_style <- update_config(list(stroke_color = BLUE_D, stroke_width = 2, stroke_opacity = 1),
                                                  background_line_style)
      default_steps <- c("PI radians" = 20, "TAU radians" = 20, degrees = 36, gradians = 40)
      self$azimuth_step <- azimuth_step %||% (if (is.null(azimuth_units)) 1 else default_steps[[azimuth_units]])
      self$faded_line_style <- faded_line_style
      self$faded_line_ratio <- faded_line_ratio
      self$azimuth_offset <- azimuth_offset
      self$azimuth_label_buff <- azimuth_label_buff
      self$azimuth_label_font_size <- azimuth_label_font_size
      self$azimuth_compact_fraction <- azimuth_compact_fraction
      super$initialize(x_range = c(-radius_max, radius_max, radius_step),
                       y_range = c(-radius_max, radius_max, radius_step),
                       x_length = size, y_length = size, axis_config = self$radius_config, ...)
      init_background_lines(self)
    },
    get_lines = function() {
      center <- self$get_origin()
      ratio <- self$faded_line_ratio
      if (ratio == 0) ratio <- 1
      rstep <- (1 / ratio) * self$x_axis$x_range[3]
      astep <- (1 / ratio) * (TAU * (1 / self$azimuth_step))
      rlines1 <- VGroup()
      rlines2 <- VGroup()
      alines1 <- VGroup()
      alines2 <- VGroup()
      rinput <- np_arange(0, self$x_axis$x_range[2] + rstep, rstep)
      ainput <- np_arange(0, TAU, astep)
      unit_vector <- self$x_axis$get_unit_vector()[1]
      for (k in seq_along(rinput)) {
        new_circle <- Circle(radius = rinput[k] * unit_vector)
        if ((k - 1) %% ratio == 0) alines1$add(new_circle) else alines2$add(new_circle)
      }
      line <- Line(center, self$get_x_axis()$get_end())
      for (k in seq_along(ainput)) {
        new_line <- line$copy()
        new_line$rotate(ainput[k] + self$azimuth_offset, about_point = center)
        if ((k - 1) %% ratio == 0) rlines1$add(new_line) else rlines2$add(new_line)
      }
      list(VGroup(rlines1$submobjects, alines1$submobjects), VGroup(rlines2$submobjects, alines2$submobjects))
    },
    get_vector = function(coords, ...) {
      Arrow(self$coords_to_point(0, 0), do.call(self$coords_to_point, as.list(coords)), buff = 0, ...)
    },
    prepare_for_nonlinear_transform = function(num_inserted_curves = 50) prepare_for_nonlinear(self, num_inserted_curves),
    get_coordinate_labels = function(r_values = NULL, a_values = NULL, ...) {
      if (is.null(r_values)) {
        tr <- self$get_x_axis()$get_tick_range()
        r_values <- tr[tr >= 0]
      }
      a_values <- a_values %||% np_arange(0, 1, 1 / self$azimuth_step)
      self$get_x_axis()$add_numbers(r_values)
      r_mobs <- self$get_x_axis()$numbers
      d <- if (self$azimuth_direction == "CCW") 1 else -1
      right <- self$get_right()[1]
      a_mobs <- VGroup(lapply(a_values, function(i) {
        point <- c(right * cos(d * (i * TAU) + self$azimuth_offset), right * sin(d * (i * TAU) + self$azimuth_offset), 0)
        fs <- self$azimuth_label_font_size
        tex <- if (is.null(self$azimuth_units)) MathTex(sprintf("%g", i), font_size = fs)
          else switch(self$azimuth_units,
            degrees = MathTex(paste0(sprintf("%g", 360 * i), "^{\\circ}"), font_size = fs),
            gradians = MathTex(paste0(sprintf("%g", 400 * i), "^{g}"), font_size = fs),
            self$get_radian_label(i, font_size = fs))
        tex$next_to(point, direction = point, aligned_edge = point, buff = self$azimuth_label_buff)
      }))
      self$coordinate_labels <- VGroup(r_mobs, a_mobs)
      self$coordinate_labels
    },
    add_coordinates = function(r_values = NULL, a_values = NULL) {
      self$add(self$get_coordinate_labels(r_values, a_values))
      invisible(self)
    },
    get_radian_label = function(number, font_size = 24, ...) {
      MathTex(self$get_radian_label_string(number), font_size = font_size, ...)
    },
    get_radian_label_string = function(number) {
      constant_label <- c("PI radians" = "\\pi", "TAU radians" = "\\tau")[[self$azimuth_units]]
      division <- number * c("PI radians" = 2, "TAU radians" = 1)[[self$azimuth_units]]
      frac <- limit_denominator(division, 100)
      num <- frac[1]
      den <- frac[2]
      if (num == 0) "0"
      else if (num == 1 && den == 1) constant_label
      else if (num == 1) {
        if (self$azimuth_compact_fraction) paste0("\\tfrac{", constant_label, "}{", den, "}")
        else paste0("\\tfrac{1}{", den, "}", constant_label)
      } else if (den == 1) paste0(num, constant_label)
      else if (self$azimuth_compact_fraction) paste0("\\tfrac{", num, constant_label, "}{", den, "}")
      else paste0("\\tfrac{", num, "}{", den, "}", constant_label)
    }
  )
)

#' @rdname coordinate_systems
#' @export
PolarPlane <- constructor(PolarPlaneClass)
#' @rdname coordinate_systems
#' @format NULL
#' @usage NULL
#' @export
ComplexPlaneClass <- R6::R6Class("ComplexPlane", inherit = NumberPlaneClass, lock_objects = FALSE,
  public = list(
    number_to_point = function(number) {
      number <- as.complex(number)
      self$coords_to_point(cbind(Re(number), Im(number)))
    },
    n2p = function(number) self$number_to_point(number),
    point_to_number = function(point) {
      xy <- self$point_to_coords(point)
      if (is.matrix(xy)) complex(real = xy[, 1], imaginary = xy[, 2]) else complex(real = xy[1], imaginary = xy[2])
    },
    p2n = function(point) self$point_to_number(point),
    get_default_coordinate_values = function() {
      x_numbers <- self$get_x_axis()$get_tick_range()
      y_numbers <- self$get_y_axis()$get_tick_range()
      c(as.complex(x_numbers), complex(real = 0, imaginary = y_numbers[y_numbers != 0]))
    },
    get_coordinate_labels = function(..., numbers = NULL) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      numbers <- c(numbers, unlist(args[nm == ""]))
      kwargs <- args[nm != ""]
      if (!length(numbers)) numbers <- self$get_default_coordinate_values()
      self$coordinate_labels <- VGroup()
      for (z in as.complex(numbers)) {
        kw <- kwargs
        if (abs(Im(z)) > abs(Re(z))) {
          axis <- self$get_y_axis()
          value <- Im(z)
          kw$unit <- "i"
        } else {
          axis <- self$get_x_axis()
          value <- Re(z)
        }
        self$coordinate_labels$add(do.call(axis$get_number_mobject, c(list(value), kw)))
      }
      self$coordinate_labels
    },
    add_coordinates = function(...) {
      self$add(self$get_coordinate_labels(...))
      invisible(self)
    }
  )
)

#' @rdname coordinate_systems
#' @export
ComplexPlane <- constructor(ComplexPlaneClass)