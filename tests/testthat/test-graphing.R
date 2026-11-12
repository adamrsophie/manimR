has_latex <- function() nzchar(Sys.which("latex")) && nzchar(Sys.which("dvisvgm"))

test_that("np_arange follows numpy semantics", {
  expect_equal(np_arange(0, 1, 0.25), c(0, 0.25, 0.5, 0.75))
  expect_equal(np_arange(-1, -4, -1), c(-1, -2, -3))
  expect_length(np_arange(2, 2, 1), 0)
  expect_length(np_arange(3, 1, 1), 0)
})

test_that("scales map values and back", {
  lin <- LinearBase(2)
  expect_equal(lin$func(3), 6)
  expect_equal(lin$inverse_function(6), 3)
  lg <- LogBase()
  expect_equal(lg$func(c(-1, 2)), c(0.1, 100))
  expect_equal(lg$inverse_function(1000), 3)
  expect_error(lg$inverse_function(0), "undefined")
})

test_that("NumberLine ticks and n2p/p2n", {
  l <- NumberLine()
  expect_equal(l$get_tick_range(), -7:7)
  expect_length(l$ticks$submobjects, 15)
  expect_equal(l$n2p(1), c(1, 0, 0))
  expect_equal(l$n2p(c(1, 2, 3)), cbind(1:3, 0, 0))
  expect_equal(l$p2n(c(1, 0, 0)), 1)
  expect_equal(l$p2n(rbind(c(0.5, 0, 0), c(1, 0, 0), c(1.5, 0, 0))), c(0.5, 1, 1.5))

  l2 <- NumberLine(x_range = c(-10, 10, 2), length = 10)
  expect_equal(l2$get_unit_size(), 0.5)
  expect_equal(l2$n2p(10), c(5, 0, 0))
  expect_equal(l2$get_tick_range(), seq(-10, 10, 2))

  l3 <- NumberLine(x_range = c(-3, 3, 1), rotation = PI / 2)
  expect_equal(l3$n2p(2), c(0, 2, 0), tolerance = 1e-12)
  expect_equal(l3$p2n(c(0, -1, 0)), -1)

  l4 <- NumberLine(x_range = c(2, 6, 1), exclude_origin_tick = TRUE)
  expect_equal(l4$get_tick_range(), 2:6)
})

test_that("UnitInterval has elongated ticks at 0 and 1", {
  u <- UnitInterval()
  expect_equal(u$get_tick_range(), seq(0, 1, 0.1), tolerance = 1e-12)
  h <- vapply(u$ticks$submobjects, function(t) t$height, 0)
  expect_equal(h, c(0.4, rep(0.2, 9), 0.4), tolerance = 1e-9)
  expect_equal(u$get_unit_size(), 10)
})

test_that("Log scaled number line places powers evenly", {
  lg <- NumberLine(x_range = c(-2, 4, 1), scaling = LogBase(), length = 6)
  expect_equal(lg$get_tick_range(), 10^(-2:4))
  expect_equal(lg$n2p(100), c(1, 0, 0), tolerance = 1e-12)
  expect_equal(lg$p2n(c(1, 0, 0)), 100, tolerance = 1e-9)
})

test_that("decimal places follow the step", {
  expect_equal(decimal_places_from_step(1), 0)
  expect_equal(decimal_places_from_step(0.1), 1)
  expect_equal(decimal_places_from_step(0.25), 2)
})

test_that("Axes coords_to_point matches upstream doctests", {
  ax <- Axes()
  expect_equal(round(ax$c2p(1, 0, 0), 2), c(0.86, 0, 0))
  expect_equal(round(ax$c2p(c(1, 0, 0)), 2), c(0.86, 0, 0))
  expect_equal(round(ax$c2p(c(1, 0)), 2), c(0.86, 0, 0))
  m <- ax$c2p(rbind(c(0, 1), c(1, 1), c(1, 0)))
  expect_equal(round(m, 2), rbind(c(0, 0.75, 0), c(0.86, 0.75, 0), c(0.86, 0, 0)))
  tr <- ax$c2p(c(0, 1, 1), c(1, 1, 0))
  expect_equal(round(tr, 2), rbind(c(0, 0.86, 0.86), c(0.75, 0.75, 0), c(0, 0, 0)))

  ax2 <- Axes(x_range = c(0, 10, 2))
  expect_equal(round(ax2$p2c(RIGHT), 2), c(5.83, 0))
  expect_equal(round(ax2$p2c(rbind(c(0, 0, 1), c(1, 0, 0))), 2), rbind(c(5, 0), c(5.83, 0)))

  p <- ax$c2p(2.5, -1.5)
  expect_equal(ax$p2c(p), c(2.5, -1.5))
  expect_equal(ax$get_origin(), c(0, 0, 0))
  expect_equal(ax$get_x_unit_size(), 12 / 14)
  expect_equal(ax$get_y_unit_size(), 6 / 8)
  expect_equal(ax$pt2pr(ax$pr2pt(2, PI / 3)), c(2, PI / 3))
})

test_that("Axes with ranges excluding zero stay centered", {
  ax <- Axes(x_range = c(2, 6, 1), y_range = c(1, 5, 1), x_length = 4, y_length = 4)
  expect_equal(ax$c2p(4, 3), c(0, 0, 0), tolerance = 1e-12)
  expect_equal(ax$c2p(2, 1), c(-2, -2, 0), tolerance = 1e-12)
})

test_that("plot samples the function and supports discontinuities", {
  ax <- Axes(x_range = c(-3, 3, 1), y_range = c(-3, 3, 1))
  g <- ax$plot(function(x) x^2 / 3)
  expect_equal(ax$input_to_graph_coords(2, g), c(2, 4 / 3))
  expect_equal(ax$i2gp(1.5, g), ax$c2p(1.5, 0.75))
  expect_equal(g$t_step, 0.1)
  expect_equal(g$get_start(), ax$c2p(-3, 3))
  expect_equal(g$get_end(), ax$c2p(3, 3))
  expect_equal(ax$slope_of_tangent(1.5, g), 1, tolerance = 1e-6)

  d <- ax$plot(function(x) 1 / x, discontinuities = 0, dt = 0.1)
  expect_length(d$get_subpaths(), 2)

  v <- ax$plot(function(x) x, use_vectorized = TRUE)
  s <- ax$plot(function(x) x)
  expect_equal(v$points, s$points)
})

test_that("input_to_graph_point works without an underlying function", {
  ax <- Axes(x_range = c(-3, 3, 1), y_range = c(-3, 3, 1))
  line <- Line(ax$c2p(-2, -2), ax$c2p(2, 2))
  expect_equal(ax$i2gp(1, line), ax$c2p(1, 1), tolerance = 1e-3)
})

test_that("Riemann rectangles: count, widths and total area", {
  ax <- Axes(x_range = c(-3, 3, 1), y_range = c(-1, 9, 1), x_length = 6, y_length = 10)
  g <- ax$plot(function(x) x^2)
  rects <- ax$get_riemann_rectangles(g, x_range = c(0, 2), dx = 0.5)
  expect_length(rects$submobjects, 4)
  widths <- vapply(rects$submobjects, function(r) r$width, 0)
  heights <- vapply(rects$submobjects, function(r) r$height, 0)
  expect_equal(widths, rep(0.5 * 1.001, 4), tolerance = 1e-9)
  expect_equal(heights, c(0, 0.25, 1, 2.25), tolerance = 1e-9)
  expect_equal(sum(widths * heights), 1.001 * 0.5 * sum(c(0, 0.25, 1, 2.25)), tolerance = 1e-9)

  right <- ax$get_riemann_rectangles(g, x_range = c(0, 2), dx = 0.5, input_sample_type = "right")
  h2 <- vapply(right$submobjects, function(r) r$height, 0)
  expect_equal(h2, c(0.25, 1, 2.25, 4), tolerance = 1e-9)
  expect_length(ax$get_riemann_rectangles(g, dx = 0.1)$submobjects, 60)

  neg <- ax$get_riemann_rectangles(ax$plot(function(x) -1), x_range = c(0, 1), dx = 0.5, color = BLUE)
  expect_equal(neg$submobjects[[1]]$get_fill_color(), invert_color(BLUE))
})

test_that("get_area outlines the region under the graph", {
  ax <- Axes(x_range = c(-3, 3, 1), y_range = c(-1, 9, 1), x_length = 6, y_length = 10)
  g <- ax$plot(function(x) x)
  area <- ax$get_area(g, x_range = c(0, 2))
  expect_s3_class(area, "Polygon")
  expect_equal(area$get_fill_opacity(), 0.3)
  v <- area$get_vertices()
  expect_equal(range(v[, 1]), c(ax$c2p(0)[1], ax$c2p(2)[1]))
  expect_equal(max(v[, 2]), ax$c2p(2, 2)[2])
  closed <- rbind(v, v[1, ])
  expect_equal(abs(shoelace(closed[, 1:2])), 2, tolerance = 1e-6)
})

test_that("NumberPlane builds the expected grid lines", {
  np <- NumberPlane()
  expect_length(np$x_lines$submobjects, 7)
  expect_length(np$y_lines$submobjects, 15)
  expect_length(np$faded_lines$submobjects, 0)
  expect_equal(np$background_lines$submobjects[[1]]$get_stroke_color(), BLUE_D)
  np2 <- NumberPlane(x_range = c(-2, 2, 1), y_range = c(-2, 2, 1), faded_line_ratio = 2)
  # As upstream: with ratio 2 the lines at 0 are faded and the edges at +-2 are not drawn.
  expect_length(np2$background_lines$submobjects, 4)
  expect_length(np2$faded_lines$submobjects, 10)
  expect_equal(np2$faded_lines$submobjects[[1]]$get_stroke_width(), 1)
})

test_that("ThreeDAxes put z out of the screen", {
  ax <- ThreeDAxes()
  expect_equal(ax$c2p(0, 0, 1), c(0, 0, 1) * ax$z_axis$get_unit_size(), tolerance = 1e-9)
  expect_equal(ax$p2c(ax$c2p(1, 2, 3)), c(1, 2, 3), tolerance = 1e-9)
  expect_length(ax$axes$submobjects, 3)
  expect_length(ax$x_axis$pieces$submobjects, 20)
})

test_that("PolarPlane and ComplexPlane", {
  pp <- PolarPlane()
  expect_length(pp$background_lines$submobjects, 25)
  expect_equal(pp$pr2pt(2, PI / 2), c(0, 2, 0), tolerance = 1e-12)
  expect_equal(limit_denominator(0.1), c(1, 10))
  expect_equal(limit_denominator(2 / 3), c(2, 3))
  cp <- ComplexPlane()
  expect_equal(cp$n2p(2 + 1i), c(2, 1, 0))
  expect_equal(cp$p2n(c(-1, 3, 0)), complex(real = -1, imaginary = 3))
})

test_that("ImplicitFunction traces a circle", {
  im <- ImplicitFunction(function(x, y) x^2 + y^2 - 4)
  r <- sqrt(rowSums(im$get_anchors()[, 1:2]^2))
  expect_true(all(abs(r - 2) < 0.01))
  expect_length(im$get_subpaths(), 1)
  ax <- Axes(x_range = c(-3, 3, 1), y_range = c(-3, 3, 1), x_length = 6, y_length = 3)
  curve <- ax$plot_implicit_curve(function(x, y) x^2 + y^2 - 4)
  co <- ax$p2c(curve$get_anchors())
  expect_true(all(abs(sqrt(rowSums(co^2)) - 2) < 0.02))
})

test_that("parametric and polar plots map through the axes", {
  ax <- Axes(x_range = c(-3, 3, 1), y_range = c(-3, 3, 1))
  pc <- ax$plot_parametric_curve(function(t) c(cos(t), sin(t)), t_range = c(0, TAU))
  expect_equal(pc$get_start(), ax$c2p(1, 0))
  pg <- ax$plot_polar_graph(function(th) 2, theta_range = c(0, PI))
  expect_equal(pg$get_end(), ax$c2p(-2, 0), tolerance = 1e-9)
  der <- ax$plot_derivative_graph(ax$plot(function(x) x^2))
  expect_equal(der$underlying_function(1), 2, tolerance = 1e-6)
  anti <- ax$plot_antiderivative_graph(ax$plot(function(x) 2 * x))
  expect_equal(anti$underlying_function(2), 4, tolerance = 1e-6)
})

test_that("vectorized functions return coordinate rows like upstream", {
  # Three samples make the 3 x 3 output ambiguous; upstream reads rows as x, y, z.
  # Reference anchors from manim 0.20.1 (use_smoothing = False).
  ax <- Axes(x_range = c(-3, 3, 1), y_range = c(-3, 3, 1))
  anchors <- function(m) unique(round(m$get_anchors(), 6))
  g <- ax$plot(function(x) x^2 / 3, x_range = c(0, 1, 0.5), use_vectorized = TRUE, use_smoothing = FALSE)
  expect_equal(anchors(g), rbind(c(0, 0, 0), c(1, 0.083333, 0), c(2, 0.333333, 0)))
  pc <- ax$plot_parametric_curve(function(t) rbind(cos(t), sin(t), 0 * t), t_range = c(0, 1, 0.5),
                                 use_vectorized = TRUE, use_smoothing = FALSE)
  expect_equal(anchors(pc), rbind(c(2, 0, 0), c(1.755165, 0.479426, 0), c(1.080605, 0.841471, 0)))
  pf <- ParametricFunction(function(t) rbind(t, 2 * t, t^2), t_range = c(0, 1, 0.5), use_vectorized = TRUE,
                           use_smoothing = FALSE)
  expect_equal(anchors(pf), rbind(c(0, 0, 0), c(0.5, 1, 0.25), c(1, 2, 1)))
  # list(x, y), c(x, y, z) and unambiguous point rows give the same curve.
  same <- function(f, ...) ParametricFunction(f, t_range = c(0, 1, 0.5), use_vectorized = TRUE, ...)$points
  expect_equal(same(function(t) c(t, 2 * t, t^2)), same(function(t) rbind(t, 2 * t, t^2)))
  expect_equal(same(function(t) list(t, 2 * t)), same(function(t) rbind(t, 2 * t)))
  rows <- ParametricFunction(function(t) cbind(t, 2 * t, t^2), t_range = c(0, 1, 0.25), use_vectorized = TRUE)
  loop <- ParametricFunction(function(t) c(t, 2 * t, t^2), t_range = c(0, 1, 0.25))
  expect_equal(rows$points, loop$points)
  expect_error(same(function(t) 1:5), "coordinate rows")
})

test_that("lines to points start on the axes", {
  ax <- Axes(x_range = c(-3, 3, 1), y_range = c(-3, 3, 1))
  p <- ax$c2p(2, 1)
  v <- ax$get_vertical_line(p, line_func = Line)
  expect_equal(v$get_start(), ax$c2p(2, 0))
  h <- ax$get_horizontal_line(p, line_func = Line)
  expect_equal(h$get_start(), ax$c2p(0, 1))
  lg <- ax$plot_line_graph(c(0, 1, 2), c(1, 2, 0))
  expect_equal(lg$get("line_graph")$get_end(), ax$c2p(2, 0))
  expect_length(lg$get("vertex_dots")$submobjects, 3)
})

test_that("SampleSpace divisions and BarChart bars", {
  s <- SampleSpace()$divide_vertically(c(0.25, 0.25))
  widths <- vapply(s$vertical_parts$submobjects, function(p) p$width, 0)
  expect_equal(widths, c(0.75, 0.75, 1.5), tolerance = 1e-9)
  expect_equal(s$complete_p_list(0.3), c(0.3, 0.7))

  chart <- BarChart(c(1, 3, 2), y_range = c(0, 4, 1), y_length = 4, x_length = 3,
                    y_axis_config = list(include_numbers = FALSE))
  h <- vapply(chart$bars$submobjects, function(b) b$height, 0)
  expect_equal(h, c(1, 3, 2), tolerance = 1e-9)
  expect_equal(chart$bars$submobjects[[2]]$get_bottom()[2], chart$c2p(0, 0)[2], tolerance = 1e-9)
  chart$change_bar_values(c(2, 1, 4))
  h2 <- vapply(chart$bars$submobjects, function(b) b$height, 0)
  expect_equal(h2, c(2, 1, 4), tolerance = 1e-9)
  expect_equal(chart$values, c(2, 1, 4))
})

test_that("labels and numbers render with LaTeX", {
  skip_if_not(has_latex())
  skip_on_cran()
  l <- NumberLine(x_range = c(-2, 2, 1), include_numbers = TRUE)
  expect_length(l$numbers$submobjects, 5)
  expect_equal(l$numbers$submobjects[[3]]$get_value(), 0)
  ax <- Axes(x_range = c(-3, 3, 1), y_range = c(-2, 2, 1))$add_coordinates()
  expect_length(ax$coordinate_labels$submobjects, 2)
  expect_length(ax$x_axis$numbers$submobjects, 5)
  labs <- ax$get_axis_labels()
  expect_length(labs$submobjects, 2)
  g <- ax$plot(sin)
  gl <- ax$get_graph_label(g, "\\sin x", x_val = 1, dot = TRUE)
  expect_false(is.null(gl$dot))
  lg <- NumberLine(x_range = c(0, 2, 1), scaling = LogBase(), include_numbers = TRUE)
  expect_length(lg$labels$submobjects, 3)
  chart <- BarChart(c(1, 3, 2), bar_names = c("a", "b", "c"))
  expect_length(chart$x_axis$labels$submobjects, 3)
  expect_equal(chart$y_axis$decimal_number_config$num_decimal_places, 2)
  expect_length(chart$get_bar_labels()$submobjects, 3)
  cp <- ComplexPlane(x_range = c(-2, 2, 1), y_range = c(-2, 2, 1))$add_coordinates()
  expect_length(cp$coordinate_labels$submobjects, 8)
})

# Reference values dumped from Python manim 0.20.1 (see the report for the script).
graph_oracle <- list(
  nl_ticks = matrix(c(-2.165064, -1.25, 0, -1.443376, -0.833333, 0, -0.721688, -0.416667, 0, 0, 0, 0, 0.721688, 0.416667, 0, 1.443376, 0.833333, 0), ncol = 3, byrow = TRUE),
  nl_n2p = c(1.082532, 0.625, 0),
  log_ticks = matrix(c(-3, 0, 0, -2, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, 0, 2, 0, 0, 3, 0, 0), ncol = 3, byrow = TRUE),
  ax_c2p = c(-0.4375, 1.5625, 0),
  ax_c2p_many = matrix(c(-1.75, -1.25, 0, -0.875, 0, 0, 3.5, 2.5, 0), ncol = 3, byrow = TRUE),
  ax_p2c = c(3.142857, 1.8),
  ax_x_ticks = matrix(c(-3.5, -1.25, 0, -2.625, -1.25, 0, -0.875, -1.25, 0, 0, -1.25, 0, 0.875, -1.25, 0, 1.75, -1.25, 0, 2.625, -1.25, 0), ncol = 3, byrow = TRUE),
  ax_y_ticks = matrix(c(-1.75, -2.5, 0, -1.75, -1.875, 0, -1.75, -0.625, 0, -1.75, 0, 0, -1.75, 0.625, 0, -1.75, 1.25, 0, -1.75, 1.875, 0), ncol = 3, byrow = TRUE),
  ax_tip = matrix(c(3.5, -1.25, 0, 3.15, -1.075, 0, 3.15, -1.425, 0), ncol = 3, byrow = TRUE),
  plot_points = matrix(c(-2.625, -0.9375, 0, -2.479167, -1.026643, 0, -2.333333, -1.115785, 0, -2.1875, -1.171875, 0, -2.1875, -1.171875, 0, -2.041667, -1.227965, 0, -1.895833, -1.251002, 0, -1.75, -1.25, 0, -1.75, -1.25, 0, -1.604167, -1.248998, 0, -1.458333, -1.223958, 0, -1.3125, -1.171875, 0, -1.3125, -1.171875, 0, -1.166667, -1.119792, 0, -1.020833, -1.040665, 0, -0.875, -0.9375, 0, -0.875, -0.9375, 0, -0.729167, -0.834335, 0, -0.583333, -0.707131, 0, -0.4375, -0.546875, 0, -0.4375, -0.546875, 0, -0.291667, -0.386619, 0, -0.145833, -0.193309, 0, 0, 0, 0), ncol = 3, byrow = TRUE),
  plot_disc_anchors = matrix(c(-1.75, -0.625, 0, -1.3125, -0.666667, 0, -0.875, -0.833333, 0, -0.4375, -1.428571, 0, 0.0875, 6.097561, 0, 0.525, 0.905797, 0, 0.9625, 0.445633, 0, 1.4, 0.279018, 0), ncol = 3, byrow = TRUE),
  riemann = list(matrix(c(-2.187062, -0.9375, 0, -2.625, -0.9375, 0, -2.625, -1.25, 0, -2.187062, -1.25, 0), ncol = 3, byrow = TRUE),
    matrix(c(-1.749562, -1.171875, 0, -2.1875, -1.171875, 0, -2.1875, -1.25, 0, -1.749562, -1.25, 0), ncol = 3, byrow = TRUE),
    matrix(c(-1.312062, -1.25, 0, -1.75, -1.25, 0, -1.75, -1.25, 0, -1.312062, -1.25, 0), ncol = 3, byrow = TRUE),
    matrix(c(-0.874563, -1.171875, 0, -1.3125, -1.171875, 0, -1.3125, -1.25, 0, -0.874563, -1.25, 0), ncol = 3, byrow = TRUE),
    matrix(c(-0.437063, -0.9375, 0, -0.875, -0.9375, 0, -0.875, -1.25, 0, -0.437063, -1.25, 0), ncol = 3, byrow = TRUE),
    matrix(c(0.000438, -0.546875, 0, -0.4375, -0.546875, 0, -0.4375, -1.25, 0, 0.000438, -1.25, 0), ncol = 3, byrow = TRUE)),
  riemann_center = list(matrix(c(-1.312062, -1.25, 0, -1.75, -1.25, 0, -1.75, -2.1875, 0, -1.312062, -2.1875, 0), ncol = 3, byrow = TRUE),
    matrix(c(-0.874563, -1.25, 0, -1.3125, -1.25, 0, -1.3125, -1.5625, 0, -0.874563, -1.5625, 0), ncol = 3, byrow = TRUE),
    matrix(c(-0.437063, -0.9375, 0, -0.875, -0.9375, 0, -0.875, -1.25, 0, -0.437063, -1.25, 0), ncol = 3, byrow = TRUE),
    matrix(c(0.000438, -0.3125, 0, -0.4375, -0.3125, 0, -0.4375, -1.25, 0, 0.000438, -1.25, 0), ncol = 3, byrow = TRUE)),
  area_anchors = matrix(c(-1.75, -1.25, 0, -1.604167, -1.248998, 0, -1.458333, -1.223958, 0, -1.3125, -1.171875, 0, -1.166667, -1.119792, 0, -1.020833, -1.040665, 0, -0.875, -0.9375, 0, -0.729167, -0.834335, 0, -0.583333, -0.707131, 0, -0.4375, -0.546875, 0, -0.4375, -1.25, 0), ncol = 3, byrow = TRUE),
  np_bg = matrix(c(-3, 0.75, 0, 3, 0.75, 0, -3, -0.75, 0, 3, -0.75, 0, 1, -1.5, 0, 1, 1.5, 0, 2, -1.5, 0, 2, 1.5, 0, -1, -1.5, 0, -1, 1.5, 0, -2, -1.5, 0, -2, 1.5, 0), ncol = 3, byrow = TRUE),
  np_faded = matrix(c(-3, 0, 0, 3, 0, 0, -3, 0.375, 0, 3, 0.375, 0, -3, 1.125, 0, 3, 1.125, 0, -3, -0.375, 0, 3, -0.375, 0, -3, -1.125, 0, 3, -1.125, 0, 0, -1.5, 0, 0, 1.5, 0, 0.5, -1.5, 0, 0.5, 1.5, 0, 1.5, -1.5, 0, 1.5, 1.5, 0, 2.5, -1.5, 0, 2.5, 1.5, 0, -0.5, -1.5, 0, -0.5, 1.5, 0, -1.5, -1.5, 0, -1.5, 1.5, 0, -2.5, -1.5, 0, -2.5, 1.5, 0), ncol = 3, byrow = TRUE),
  t3_c2p = c(0.875, 2.1, 2.4375),
  t3_z_points = matrix(c(0, 0, -3.25, 0, 0, 3.25), ncol = 3, byrow = TRUE),
  polar_c2p = c(0.75, 1.299038, 0),
  polar_radian_labels = c("0", "\\tfrac{\\pi}{10}", "\\tfrac{\\pi}{5}", "\\tfrac{3\\pi}{10}", "\\tfrac{2\\pi}{5}", "\\tfrac{\\pi}{2}", "\\tfrac{3\\pi}{5}", "\\tfrac{7\\pi}{10}", "\\tfrac{4\\pi}{5}", "\\tfrac{9\\pi}{10}", "\\pi", "\\tfrac{11\\pi}{10}", "\\tfrac{6\\pi}{5}", "\\tfrac{13\\pi}{10}", "\\tfrac{7\\pi}{5}", "\\tfrac{3\\pi}{2}", "\\tfrac{8\\pi}{5}", "\\tfrac{17\\pi}{10}", "\\tfrac{9\\pi}{5}", "\\tfrac{19\\pi}{10}"),
  bars = list(matrix(c(-0.7, 0, 0, -1.3, 0, 0, -1.3, -0.666667, 0, -0.7, -0.666667, 0), ncol = 3, byrow = TRUE),
    matrix(c(0.3, 1.333333, 0, -0.3, 1.333333, 0, -0.3, -0.666667, 0, 0.3, -0.666667, 0), ncol = 3, byrow = TRUE),
    matrix(c(1.3, -0.666667, 0, 0.7, -0.666667, 0, 0.7, -2, 0, 1.3, -2, 0), ncol = 3, byrow = TRUE)),
  bars_changed = list(matrix(c(-0.7, 0.666667, 0, -1.3, 0.666667, 0, -1.3, -0.666667, 0, -0.7, -0.666667, 0), ncol = 3, byrow = TRUE),
    matrix(c(0.3, -0.666667, 0, -0.3, -0.666667, 0, -0.3, -1.333333, 0, 0.3, -1.333333, 0), ncol = 3, byrow = TRUE),
    matrix(c(1.3, 0, 0, 0.7, 0, 0, 0.7, -0.666667, 0, 1.3, -0.666667, 0), ncol = 3, byrow = TRUE)),
  ss_parts = list(matrix(c(1.5, 1.5, 0, -1.5, 1.5, 0, -1.5, 0.6, 0, 1.5, 0.6, 0), ncol = 3, byrow = TRUE),
    matrix(c(1.5, 0.6, 0, -1.5, 0.6, 0, -1.5, -0.9, 0, 1.5, -0.9, 0), ncol = 3, byrow = TRUE),
    matrix(c(1.5, -0.9, 0, -1.5, -0.9, 0, -1.5, -1.5, 0, 1.5, -1.5, 0), ncol = 3, byrow = TRUE)),
  secant = list(matrix(c(-0.875, -0.9375, 0, -0.4375, -0.9375, 0), ncol = 3, byrow = TRUE),
    matrix(c(-0.4375, -0.9375, 0, -0.4375, -0.546875, 0), ncol = 3, byrow = TRUE),
    matrix(c(-4.385938, -4.072266, 0, 3.073438, 2.587891, 0), ncol = 3, byrow = TRUE)),
  line_graph = matrix(c(-1.75, 0, 0, -0.875, 1.25, 0), ncol = 3, byrow = TRUE),
  polar_graph = matrix(c(-0.4375, -1.25, 0, -0.481846, -0.938201, 0, -0.526191, -0.626403, 0, -0.645174, -0.387758, 0, -0.645174, -0.387758, 0, -0.764157, -0.149114, 0, -0.957777, 0.016377, 0, -1.149518, 0.085994, 0, -1.149518, 0.085994, 0, -1.341258, 0.155611, 0, -1.531118, 0.129355, 0, -1.685916, 0.040969, 0, -1.685916, 0.040969, 0, -1.840714, -0.047418, 0, -1.96045, -0.197935, 0, -2.038363, -0.349879, 0, -2.038363, -0.349879, 0, -2.116276, -0.501823, 0, -2.152365, -0.655193, 0, -2.1702, -0.801574, 0, -2.1702, -0.801574, 0, -2.188034, -0.947954, 0, -2.187615, -1.087345, 0, -2.187456, -1.160917, 0, -2.187456, -1.160917, 0, -2.187297, -1.23449, 0, -2.187399, -1.242245, 0, -2.1875, -1.25, 0), ncol = 3, byrow = TRUE),
  vline = matrix(c(0, -1.25, 0, 0, 0, 0), ncol = 3, byrow = TRUE)
)

anchors_of <- function(m) m$points[seq(1, nrow(m$points), 4), , drop = FALSE]
ends_of <- function(m) rbind(m$get_start(), m$get_end())
tick_centers <- function(g) do.call(rbind, lapply(g$submobjects, function(t) t$get_center()))
expect_close <- function(x, y, tol = 2e-6) {
  expect_equal(dim(x), dim(y))
  expect_lt(max(abs(unname(x) - unname(y))), tol)
}

test_that("number lines match upstream geometry", {
  o <- graph_oracle
  l <- NumberLine(x_range = c(-3, 3, 1), length = 5, rotation = PI / 6, include_tip = TRUE)
  expect_close(tick_centers(l$ticks), o$nl_ticks)
  expect_close(l$n2p(1.5), o$nl_n2p)
  lg <- NumberLine(x_range = c(-2, 4, 1), scaling = LogBase(), length = 6)
  expect_close(tick_centers(lg$ticks), o$log_ticks)
})

test_that("axes, plots and calculus helpers match upstream geometry", {
  o <- graph_oracle
  ax <- Axes(x_range = c(-2, 6, 1), y_range = c(-1, 3, 0.5), x_length = 7, y_length = 5)
  expect_close(ax$c2p(1.5, 2.25), o$ax_c2p)
  expect_close(ax$c2p(rbind(c(0, 0), c(1, 1), c(6, 3))), o$ax_c2p_many)
  expect_close(ax$p2c(c(1, 1, 0)), o$ax_p2c)
  expect_close(tick_centers(ax$x_axis$ticks), o$ax_x_ticks)
  expect_close(tick_centers(ax$y_axis$ticks), o$ax_y_ticks)
  expect_close(anchors_of(ax$x_axis$tip), o$ax_tip)

  g <- ax$plot(function(x) x^2 / 4, x_range = c(-1, 2, 0.5))
  expect_close(g$points, o$plot_points)
  g2 <- ax$plot(function(x) (x^2 - 2) / (x^2 - 4), discontinuities = 2, dt = 0.1, x_range = c(0, 4, 0.5))
  expect_close(anchors_of(g2), o$plot_disc_anchors)

  rects <- ax$get_riemann_rectangles(g, x_range = c(-1, 2), dx = 0.5)
  expect_length(rects$submobjects, length(o$riemann))
  for (i in seq_along(o$riemann)) expect_close(anchors_of(rects$submobjects[[i]]), o$riemann[[i]])
  rects2 <- ax$get_riemann_rectangles(ax$plot(function(x) x - 1), x_range = c(0, 2), dx = 0.5,
                                      input_sample_type = "center")
  for (i in seq_along(o$riemann_center)) expect_close(anchors_of(rects2$submobjects[[i]]), o$riemann_center[[i]])

  # Duplicate vertices at the ends depend on floating point noise, so compare unique anchors.
  area <- ax$get_area(g, x_range = c(0, 1.5))
  expect_close(unique(round(anchors_of(area), 6)), o$area_anchors)

  sg <- ax$get_secant_slope_group(1, g, dx = 0.5)
  for (i in seq_along(o$secant)) expect_close(ends_of(sg$submobjects[[i]]), o$secant[[i]])
  expect_close(anchors_of(ax$plot_line_graph(c(0, 1, 2), c(1, 2, 0))$get("line_graph")), o$line_graph)
  expect_close(ax$plot_polar_graph(function(th) 1 + 0.5 * cos(th), theta_range = c(0, PI, 0.5))$points, o$polar_graph)
  expect_close(ends_of(ax$get_vertical_line(ax$c2p(2, 1), line_func = Line)), o$vline)
})

test_that("planes, 3D axes and charts match upstream geometry", {
  o <- graph_oracle
  np <- NumberPlane(x_range = c(-3, 3, 1), y_range = c(-2, 2, 1), x_length = 6, y_length = 3, faded_line_ratio = 2)
  se <- function(grp) do.call(rbind, lapply(grp$submobjects, ends_of))
  expect_close(se(np$background_lines), o$np_bg)
  expect_close(se(np$faded_lines), o$np_faded)
  t3 <- ThreeDAxes()
  expect_close(t3$c2p(1, 2, 3), o$t3_c2p)
  expect_close(ends_of(t3$z_axis), o$t3_z_points)
  pp <- PolarPlane(size = 6)
  expect_close(pp$pr2pt(2, PI / 3), o$polar_c2p)
  labels <- vapply(np_arange(0, 1, 1 / 20), pp$get_radian_label_string, "")
  expect_equal(labels, o$polar_radian_labels)

  bc <- BarChart(c(1, 3, -2), y_range = c(-2, 4, 1), y_length = 4, x_length = 3,
                 y_axis_config = list(include_numbers = FALSE))
  for (i in 1:3) expect_close(anchors_of(bc$bars$submobjects[[i]]), o$bars[[i]])
  bc$change_bar_values(c(2, -1, 1))
  for (i in 1:3) expect_close(anchors_of(bc$bars$submobjects[[i]]), o$bars_changed[[i]])
  ss <- SampleSpace()$divide_horizontally(c(0.3, 0.5))
  for (i in seq_along(o$ss_parts)) expect_close(anchors_of(ss$horizontal_parts$submobjects[[i]]), o$ss_parts[[i]])
})

# Label centers, widths and heights (x, y, z, width, height) from Python manim 0.20.1.
label_oracle <- list(
  nl_numbers = matrix(c(-2.114134, -0.374408, 0, 0.413335, 0.248817, -1.114134, -0.374408, 0, 0.387557, 0.248817, 0, -0.378518, 0, 0.157285, 0.257036, 1, -0.374408, 0, 0.123288, 0.248817, 2, -0.374408, 0, 0.149066, 0.248817), ncol = 5, byrow = TRUE),
  ax_y_numbers = matrix(c(-0.456667, -3, 0, 0.413335, 0.248817, -0.443778, -1.5, 0, 0.387557, 0.248817, -0.311644, 1.5, 0, 0.123288, 0.248817), ncol = 5, byrow = TRUE),
  axis_labels = matrix(c(6.224035, 0.387827, 0, 0.24807, 0.225654, 0.389819, 3.211146, 0, 0.229639, 0.322291), ncol = 5, byrow = TRUE),
  graph_label = matrix(c(2.720347, 1.262206, 0, 0.940694, 0.33873), ncol = 5, byrow = TRUE),
  bar_x_labels = matrix(c(-1, -1.307161, 0, 0.112329, 0.114321, 0, -0.662204, 0, 0.26116, 0.175592, 1, -1.307161, 0, 0.094894, 0.114321), ncol = 5, byrow = TRUE),
  bar_labels = matrix(c(-1, 2.335679, 0, 0.103362, 0.171357, 0, -2.332939, 0, 0.184641, 0.165878, 1, 1.332939, 0, 0.099377, 0.165878), ncol = 5, byrow = TRUE),
  polar_a = matrix(c(3.3, 0, 0, 0.104857, 0.171357, 3.138487, 1.019756, 0, 0.198562, 0.262583, 2.669756, 1.939691, 0, 0.122727, 0.262583, 1.939691, 2.669756, 0, 0.222008, 0.303206, 1.019756, 3.138487, 0, 0.222008, 0.303206, 0, 3.3, 0, 0.122727, 0.259096), ncol = 5, byrow = TRUE),
  complex = matrix(c(-1.762222, -0.182939, 0, 0.275557, 0.165878, -0.770814, -0.182939, 0, 0.258371, 0.165878, 1.141096, -0.182939, 0, 0.082192, 0.165878, 2.149689, -0.182939, 0, 0.099377, 0.165878, 0.282655, -2.183686, 0, 0.36531, 0.167372, 0.274062, -1.183686, 0, 0.348125, 0.167372, 0.185973, 0.816314, 0, 0.171945, 0.167372, 0.194565, 1.816314, 0, 0.189131, 0.167372), ncol = 5, byrow = TRUE),
  log_labels = matrix(c(-1, -0.378518, 0, 0.473918, 0.257036, 0, -0.378518, 0, 0.447766, 0.257036, 1, -0.378518, 0, 0.468164, 0.257036), ncol = 5, byrow = TRUE)
)

test_that("labels match upstream placement", {
  skip_if_not(has_latex())
  skip_on_cran()
  o <- label_oracle
  cw <- function(m) c(m$get_center(), m$width, m$height)
  cws <- function(g) do.call(rbind, lapply(g$submobjects, cw))
  close <- function(x, y) expect_lt(max(abs(unname(x) - unname(y))), 1e-4)
  close(cws(NumberLine(x_range = c(-2, 2, 1), include_numbers = TRUE)$numbers), o$nl_numbers)
  ax <- Axes(x_range = c(-3, 3, 1), y_range = c(-2, 2, 1))$add_coordinates()
  close(cws(ax$y_axis$numbers), o$ax_y_numbers)
  close(cws(ax$get_axis_labels()), o$axis_labels)
  close(cw(ax$get_graph_label(ax$plot(sin), "\\sin x", x_val = 1)), o$graph_label)
  bc <- BarChart(c(3, -1, 2), bar_names = c("a", "bb", "c"))
  close(cws(bc$x_axis$labels), o$bar_x_labels)
  close(cws(bc$get_bar_labels()), o$bar_labels)
  pp <- PolarPlane(size = 6)$add_coordinates()
  close(cws(pp$coordinate_labels[2])[1:6, ], o$polar_a)
  cp <- ComplexPlane(x_range = c(-2, 2, 1), y_range = c(-2, 2, 1))$add_coordinates()
  close(cws(cp$coordinate_labels), o$complex)
  close(cws(NumberLine(x_range = c(0, 2, 1), scaling = LogBase(), include_numbers = TRUE)$labels), o$log_labels)
})
