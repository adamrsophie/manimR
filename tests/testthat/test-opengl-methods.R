# Methods of upstream's OpenGL mobject classes. Values read from `oracle`
# are written by upstream manim 0.22.1 through data-raw/opengl_methods_oracle.py.
oracle <- jsonlite::fromJSON(test_path("fixtures", "opengl_methods_oracle.json"), simplifyVector = TRUE)
# Upstream's quadratic pieces of manimR's cubic curves, which are raised from
# them: the handle is recovered from the first cubic handle.
as_quadratic <- function(p) {
  i <- seq(1, nrow(p), by = 4)
  k <- seq_along(i)
  q <- matrix(0, 3 * length(i), 3)
  q[3 * k - 2, ] <- p[i, ]
  q[3 * k - 1, ] <- p[i, ] + 1.5 * (p[i + 1, ] - p[i, ])
  q[3 * k, ] <- p[i + 3, ]
  q
}

test_that("OpenGLArrowTip is a triangle pointing right, as upstream", {
  tip <- OpenGLArrowTip()
  expect_s3_class(tip, "OpenGLTriangle")
  o <- oracle$arrow_tip
  expect_equal(tip$get_base(), o$base, tolerance = 1e-9)
  expect_equal(tip$get_tip_point(), o$tip_point, tolerance = 1e-9)
  expect_equal(tip$get_length(), o$length, tolerance = 1e-9)
  expect_equal(tip$get_angle(), o$angle, tolerance = 1e-9)
  expect_equal(tip$get_fill_opacity(), 1)
  # As upstream, get_length() measures along the width.
  expect_equal(OpenGLArrowTip(width = 1, length = 2)$get_length(), o$length_width_1, tolerance = 1e-9)
})

test_that("OpenGL mobjects keep upstream's state fields and data", {
  m <- OpenGLMobject()
  expect_equal(m$model_matrix, diag(4))
  expect_equal(m$rgbas, matrix(1, 1, 4))
  expect_named(m$data, c("points", "bounding_box", "rgbas"))
  m$set_gloss(0.5)$set_shadow(0.2)
  expect_equal(c(m$get_gloss(), m$get_shadow()), c(0.5, 0.2))
  m$fix_in_frame()
  expect_equal(m$uniforms$is_fixed_in_frame, 1)
  m$unfix_from_frame()
  expect_equal(m$is_fixed_in_frame, 0)
  m$apply_depth_test()
  expect_true(m$depth_test)
  m$deactivate_depth_test()
  expect_false(m$depth_test)
  sq <- OpenGLSquare(side_length = 2)
  expect_equal(sq$get_bounding_box(), rbind(c(-1, -1, 0), c(0, 0, 0), c(1, 1, 0)))
  expect_true(sq$is_point_touching(c(1.1, 0, 0)))
  expect_false(sq$is_point_touching(c(2, 0, 0)))
  expect_equal(sq$get_bounding_box_point(UR), c(1, 1, 0))
  expect_equal(sq$get_continuous_bounding_box_point(RIGHT), c(1, 0, 0))
  expect_equal(sq$hierarchical_model_matrix(), diag(4))
  expect_length(sq$get_grid(2, 3)$submobjects, 6)
  cc <- sq$copy()
  expect_equal(cc$get_bounding_box(), sq$get_bounding_box())
})

test_that("OpenGL VMobject methods follow upstream", {
  c1 <- OpenGLCircle()
  expect_equal(dim(c1$fill_rgba), c(1, 4))
  expect_equal(c1$get_unit_normal(), c(0, 0, 1))
  expect_true(c1$has_stroke())
  expect_false(c1$has_fill())
  c1$set_flat_stroke(FALSE)
  expect_false(c1$get_flat_stroke())
  expect_length(c1$get_bezier_tuples(), nrow(c1$points) / 4)
  sq <- OpenGLSquare()
  n <- nrow(sq$points)
  sq$subdivide_sharp_curves(angle_threshold = 1e-3)
  expect_equal(nrow(sq$points), n)
  a <- OpenGLArc(angle = PI / 2)
  # As upstream, the angle is taken modulo TAU, so float noise below 0 gives TAU.
  start_angle <- a$get_start_angle()
  expect_equal(min(start_angle, TAU - start_angle), 0, tolerance = 1e-9)
  expect_equal(a$get_stop_angle(), PI / 2, tolerance = 1e-9)
  expect_equal(a$create_quadratic_bezier_points(PI / 2, 0, 2), oracle$arc_quadratic_points, tolerance = 1e-9)
  p <- OpenGLPoint(location = c(1, 2, 0))
  expect_equal(p$get_location(), c(1, 2, 0))
  p$set_location(c(3, 3, 0))
  expect_equal(p$get_bounding_box_point(UP), c(3, 3, 0))
  arrow <- OpenGLArrow(LEFT, RIGHT)
  arrow$set_thickness(0.1)
  expect_equal(arrow$thickness, 0.1)
})

test_that("OpenGL VMobjects give upstream's shader data and wrappers", {
  c1 <- OpenGLCircle(fill_opacity = 1)
  stroke <- c1$get_stroke_shader_data()
  expect_named(stroke, c("point", "prev_point", "next_point", "unit_normal", "stroke_width", "color"))
  expect_equal(length(stroke), 3 * 2 * nrow(c1$points) / 4)
  fill <- c1$get_fill_shader_data()
  expect_equal(fill$vert_index[, 1], seq_len(length(fill)) - 1)
  tri <- c1$get_triangulation()
  expect_true(all(tri >= 0 & tri < length(fill)))
  expect_equal(length(tri) %% 3, 0)
  wrappers <- c1$get_shader_wrapper_list()
  expect_equal(vapply(wrappers, function(w) w$shader_folder, ""), c("quadratic_bezier_fill", "quadratic_bezier_stroke"))
  expect_true(all(vapply(wrappers, function(w) w$is_valid(), NA)))
  expect_equal(wrappers[[2]]$uniforms$joint_type, 0)
})

test_that("OpenGLSurface gives upstream's grid, triangles and shader data", {
  # Resolution counts grid points, as upstream.
  s <- OpenGLSurface(function(u, v) c(u, v, u * v), u_range = c(-1, 1), v_range = c(-1, 1), resolution = 3)
  expect_equal(s$get_triangle_indices(), oracle$surface$triangle_indices)
  d <- s$get_shader_data()
  expect_named(d, c("point", "du_point", "dv_point", "color"))
  # Upstream's shader data is float32.
  expect_equal(d$point[1:4, ], oracle$surface$point, tolerance = 1e-6)
  expect_equal(d$du_point[1:4, ], oracle$surface$du_point, tolerance = 1e-6)
  expect_equal(dim(s$get_unit_normals()), c(9, 3))
  s$sort_faces_back_to_front()
  expect_setequal(s$get_triangle_indices(), 0:8)
  img <- matrix(c("red", "blue", "green", "white"), 2, 2)
  ts <- OpenGLTexturedSurface(s, img)
  td <- ts$get_shader_data()
  expect_named(td, c("point", "du_point", "dv_point", "im_coords", "opacity"))
  expect_equal(td$im_coords[1:3, ], oracle$textured_im_coords)
})

test_that("shader wrappers read upstream's GLSL files", {
  expect_equal(c(nchar(get_shader_code_from_file("surface/vert.glsl")),
                 nchar(get_shader_code_from_file("quadratic_bezier_fill/frag.glsl"))), oracle$shader_code_lengths)
  expect_null(get_shader_code_from_file("no_such_folder/vert.glsl"))
  # A file with CRLF line ends, as a checkout on Windows can have, reads the same.
  crlf <- file.path(withr_tempdir(), "vert.glsl")
  lf <- gsub("\r\n", "\n", rawToChar(readBin(file.path(get_shader_dir(), "surface/vert.glsl"), "raw", 1e5)))
  writeBin(charToRaw(gsub("\n", "\r\n", lf)), crlf)
  expect_identical(get_shader_code_from_file(crlf), get_shader_code_from_file("surface/vert.glsl"))
  expect_equal(get_colormap_code(rbind(c(1, 0, 0), c(0, 0.5, 1))), oracle$colormap_code)
  expect_error(find_file("nope.glsl", tempdir()), "not Found")
  w <- ShaderWrapper(OpenGLMobject()$get_shader_data(), shader_folder = "surface")
  expect_true(w$is_valid())
  w2 <- w$copy()
  w2$replace_code("void main", "void main2")
  expect_false(identical(w$get_program_id(), w2$get_program_id()))
  a <- ShaderWrapper(OpenGLDot()$get_shader_data(), vert_indices = 0:1)
  b <- ShaderWrapper(OpenGLDot()$get_shader_data(), vert_indices = 0:1)
  na <- length(a$vert_data)
  a$combine_with(b)
  expect_equal(length(a$vert_data), 2 * na)
  expect_equal(a$vert_indices, c(0:1, 0:1 + na))
})

test_that("OpenGL methods take upstream's OpenGL arguments", {
  sq <- OpenGLSquare(side_length = 2)
  sq$set_width(4)
  expect_equal(c(sq$width, sq$height), c(4, 4))
  sq$set_height(1, stretch = TRUE)
  expect_equal(c(sq$width, sq$height), c(4, 1))
  sq$set_color(RED, opacity = 0.5)
  expect_equal(sq$get_fill_opacity(), 0.5)
  expect_equal(tolower(sq$get_stroke_color()), tolower(RED))
  sq$set_fill(BLUE, 1, recurse = FALSE)
  expect_equal(tolower(sq$get_fill_color()), tolower(BLUE))
  sq$set_stroke(width = 2, background = TRUE)
  expect_true(sq$draw_stroke_behind_fill)
  sq$set_style(fill_rgba = c(1, 0, 0, 0.25), gloss = 0.3)
  expect_equal(sq$fill_rgbas, matrix(c(1, 0, 0, 0.25), 1))
  expect_equal(sq$get_gloss(), 0.3)
  calls <- 0
  sq$add_updater(function(m, dt) calls <<- calls + 1)
  sq$suspend_updating(recurse = FALSE)
  sq$resume_updating(call_updater = FALSE)
  expect_equal(calls, 0)
  sq$update(dt = 0, recurse = TRUE)
  expect_equal(calls, 1)
  sq$clear_updaters(recurse = TRUE)
  expect_length(sq$get_updaters(), 0)
  # Upstream's quadratic anchors and handles become cubic curves.
  v <- OpenGLVMobject()
  v$set_anchors_and_handles(matrix(c(0, 0, 0), 1), matrix(c(1, 1, 0), 1), matrix(c(2, 0, 0), 1))
  expect_equal(v$points, rbind(c(0, 0, 0), c(2, 2, 0) / 3, c(4, 2, 0) / 3, c(2, 0, 0)))
  expect_equal(v$point_from_proportion(0.5), oracle$quadratic_at_half, tolerance = 1e-6)
  held <- OpenGLDot()
  g <- OpenGLVGroup(OpenGLCircle())
  g$label <- held
  s <- g$copy(shallow = TRUE)
  expect_identical(s$label, held)
  expect_false(identical(s$submobjects[[1]], g$submobjects[[1]]))
  d <- g$copy()
  expect_false(identical(d$label, held))
})

test_that("OpenGL classes have upstream's own methods", {
  c1 <- OpenGLCircle()
  c1$surround(OpenGLSquare(side_length = 2), buff = 0.5)
  expect_equal(c(c1$width, c1$height), oracle$circle_surround, tolerance = 1e-6)
  dl <- OpenGLDashedLine(LEFT, RIGHT, dash_length = 0.1, dashed_ratio = 0.5)
  expect_equal(c(dl$calculate_num_dashes(0.5), OpenGLDashedLine(ORIGIN, 0.1 * RIGHT)$calculate_num_dashes(0.5)),
               oracle$num_dashes)
  arrow <- OpenGLArrow(LEFT, RIGHT)
  arrow$set_path_arc(PI / 2)
  expect_equal(arrow$path_arc, PI / 2)
  s <- OpenGLSurface(function(u, v) c(u, v, 0), u_range = c(0, 1), v_range = c(0, 1), resolution = 5)
  part <- s$copy()
  part$pointwise_become_partial(s, 0, 0.5, axis = 0)
  expect_equal(max(vapply(part$list_of_faces, function(f) max(f$points[, 1]), 0)), 0.5)
  img <- matrix(c("red", "blue", "green", "white"), 2, 2)
  ts <- OpenGLTexturedSurface(s, img)
  tp <- ts$copy()
  tp$pointwise_become_partial(ts, 0, 0.5)
  # Upstream's resolution (5, 5): the first six image coordinates.
  expect_equal(tp$im_coords[1:6, ], oracle$textured_partial_im_coords)
  ts$set_opacity(0.4)
  expect_equal(ts$opacity, matrix(0.4))
  p <- OpenGLPMobject()
  p$add_points(rbind(c(0, 0, 0), c(1, 0, 0)))
  q <- OpenGLPMobject()
  q$add_points(rbind(c(0, 0, 0), c(1, 0, 0)), color = RED)
  p$match_colors(q)
  expect_equal(p$rgbas, q$rgbas)
  expect_equal(p$shader_folder, "true_dot")
})

test_that("set_default works on a class that inherits its initializer", {
  OpenGLMobjectClass$set_default(name = "held")
  on.exit(OpenGLMobjectClass$set_default(), add = TRUE)
  expect_equal(OpenGLMobject()$name, "held")
  expect_equal(OpenGLMobject(name = "own")$name, "own")
  OpenGLMobjectClass$set_default()
  expect_false(identical(OpenGLMobject()$name, "held"))
})

test_that("the Cairo background stroke and upstream's stroke behind the fill stay apart", {
  sq <- Square()
  sq$set_stroke(RED, 7, background = TRUE)
  expect_equal(sq$background_stroke_width, 7)
  expect_equal(sq$stroke_width, 4)
  sq$set_background_stroke(width = 2)
  expect_equal(sq$background_stroke_width, 2)
  osq <- OpenGLSquare()
  width <- osq$stroke_width
  expect_false(isTRUE(osq$draw_stroke_behind_fill))
  osq$set_stroke(BLUE, width = 3, background = TRUE)
  expect_equal(osq$stroke_width, 3)
  expect_true(osq$draw_stroke_behind_fill)
  osq$set_opacity(0.5)
  expect_equal(osq$stroke_width, 3)
})

test_that("OpenGL lines apply buff twice and arrows are upstream's filled shapes", {
  o <- oracle$lines
  l <- OpenGLLine(2 * LEFT, 2 * RIGHT, buff = 0.5)
  expect_equal(rbind(l$get_start(), l$get_end()), rbind(o$buff$start, o$buff$end), tolerance = 1e-9)
  expect_equal(as_quadratic(OpenGLLine(LEFT, RIGHT, path_arc = PI / 3)$points), o$arc$points, tolerance = 1e-9)
  dl <- OpenGLDashedLine(2 * LEFT, 2 * RIGHT, buff = 0.5)
  expect_equal(rbind(dl$get_start(), dl$get_end()), rbind(o$dashed_buff$start, o$dashed_buff$end), tolerance = 1e-9)
  scaled <- OpenGLArrow()
  scaled$scale(2)
  thick <- OpenGLArrow()
  thick$set_thickness(0.2)
  arrows <- list(default = OpenGLArrow(), thick_tilted = OpenGLArrow(LEFT, 2 * UP + RIGHT, thickness = 0.1),
                 short = OpenGLArrow(ORIGIN, 0.2 * RIGHT), arc = OpenGLArrow(ORIGIN, RIGHT, path_arc = PI / 2),
                 negative_arc = OpenGLArrow(ORIGIN, RIGHT, path_arc = -PI / 3),
                 space = OpenGLArrow(ORIGIN, c(1, 1, 1)), vector = OpenGLVector(c(1, 2)), scaled = scaled,
                 thick = thick)
  for (k in names(arrows)) {
    expect_equal(as_quadratic(arrows[[k]]$points), oracle$arrows[[k]]$points, tolerance = 1e-9, label = k)
    expect_equal(rbind(arrows[[k]]$get_start(), arrows[[k]]$get_end()),
                 rbind(oracle$arrows[[k]]$start, oracle$arrows[[k]]$end), tolerance = 1e-9, label = k)
  }
  a <- arrows$default
  expect_s3_class(a, "OpenGLLine")
  expect_false(inherits(a, "Arrow"))
  expect_equal(a$get_fill_color(), GREY_A, ignore_attr = TRUE)
  expect_equal(a$get_fill_opacity(), 1)
  d <- OpenGLDoubleArrow(LEFT, RIGHT)
  expect_equal(as_quadratic(d$points), oracle$double_arrow$points, tolerance = 1e-9)
  expect_length(d$submobjects, oracle$double_arrow$n_sub)
  expect_equal(as_quadratic(d$start_tip$points), oracle$double_arrow$start_tip, tolerance = 1e-9)
})

test_that("OpenGL shapes take upstream's arguments and points", {
  shapes <- list(arc = OpenGLArc(0, PI), arc_args = OpenGLArc(PI / 4, PI / 2, 2, 4, RIGHT),
                 circle = OpenGLCircle(BLUE), dot = OpenGLDot(RIGHT), ellipse = OpenGLEllipse(4, 2),
                 arc_between = OpenGLArcBetweenPoints(LEFT, RIGHT), annular_sector = OpenGLAnnularSector(),
                 sector = OpenGLSector(2), sector_inner = OpenGLSector(2, 1), annulus = OpenGLAnnulus(),
                 bezier = OpenGLCubicBezier(LEFT, UP, UP + RIGHT, DOWN), pentagon = OpenGLRegularPolygon(5),
                 hexagon_turned = OpenGLRegularPolygon(6, PI / 6))
  # Upstream stores a cubic Bezier as its two piece quadratic approximation;
  # manimR keeps the cubic itself.
  b <- shapes$bezier$points
  expect_equal(b, rbind(LEFT, UP, UP + RIGHT, DOWN), ignore_attr = TRUE)
  expect_equal(get_quadratic_approximation_of_cubic(b[1, ], b[2, ], b[3, ], b[4, ]), oracle$shapes$bezier,
               tolerance = 1e-9)
  for (k in setdiff(names(shapes), "bezier")) {
    expect_equal(as_quadratic(shapes[[k]]$points), oracle$shapes[[k]], tolerance = 1e-9, label = k)
  }
  expect_equal(toupper(OpenGLCircle(BLUE)$get_color()), oracle$circle_color)
  r <- OpenGLRectangle(WHITE, 4, 2)
  expect_equal(c(r$get_width(), r$get_height()), oracle$rectangle_size)
  p <- OpenGLPoint(RIGHT)
  expect_equal(p$get_location(), oracle$point$location)
  expect_equal(c(p$get_width(), p$get_height()), c(oracle$point$width, oracle$point$height))
})

test_that("OpenGLDashedVMobject splits a curve by its parameter, as upstream", {
  bent <- OpenGLVMobject()$set_points_as_corners(rbind(LEFT, ORIGIN, 3 * RIGHT))
  dashes <- list(open = OpenGLDashedVMobject(bent, 3), closed = OpenGLDashedVMobject(OpenGLSquare(), 4, 0.6))
  for (k in names(dashes)) {
    got <- lapply(dashes[[k]]$submobjects, function(m) as_quadratic(m$points))
    expected <- oracle$dashed[[k]]
    # Dashes of equal size come back from JSON as one array.
    if (is.array(expected)) expected <- lapply(seq_len(dim(expected)[1]), function(i) expected[i, , ])
    expect_equal(got, expected, tolerance = 1e-9, label = k)
  }
  expect_equal(dashes$closed$dashed_ratio, 0.6)
})

test_that("OpenGL tips are upstream's OpenGLArrowTips made from tip_config", {
  tipped <- list(line = OpenGLLine(LEFT, 2 * RIGHT)$add_tip(), arc_start = OpenGLArc(0, PI)$add_tip(at_start = TRUE),
                 config = OpenGLLine(ORIGIN, 2 * UP, tip_config = list(width = 0.5))$add_tip(length = 0.2),
                 curved = OpenGLCurvedArrow(LEFT, RIGHT), curved_double = OpenGLCurvedDoubleArrow(LEFT, RIGHT))
  for (k in names(tipped)) {
    m <- tipped[[k]]
    o <- oracle$tipped[[k]]
    expect_equal(as_quadratic(m$points), o$points, tolerance = 1e-9, label = k)
    tips <- o$tips
    if (is.array(tips)) tips <- lapply(seq_len(dim(tips)[1]), function(i) tips[i, , ])
    got <- lapply(m$submobjects, function(t) as_quadratic(t$points))
    expect_equal(got, tips, tolerance = 1e-9, label = k)
    expect_s3_class(m$submobjects[[1]], "OpenGLArrowTip")
    expect_equal(toupper(m$submobjects[[1]]$get_fill_color()), o$tip_color, label = k)
  }
  expect_false(inherits(tipped$curved, "CurvedArrow"))
})

test_that("OpenGLImageMobject takes upstream's width and height", {
  pixels <- array(0, c(2, 4, 4))
  sizes <- list(list(), list(width = 2), list(height = 3), list(width = 1, height = 5))
  got <- t(vapply(sizes, function(kw) {
    m <- do.call(OpenGLImageMobject, c(list(pixels), kw))
    c(m$get_width(), m$get_height())
  }, numeric(2)))
  # Upstream's surface also stores points nudged 1e-5 along u and v.
  expect_equal(got, oracle$image_sizes, tolerance = 1e-4)
  glossy <- OpenGLImageMobject(pixels, gloss = 0.2, shadow = 0.3)
  expect_equal(c(glossy$gloss, glossy$shadow), oracle$image_gloss)
  expect_s3_class(glossy, "ImageMobject")
})

test_that("OpenGLMobject and OpenGLVMobject take upstream's arguments in order", {
  o <- oracle$base_mobject
  m <- OpenGLMobject(RED, 0.5, 3, 0.2, 0.3, is_fixed_in_frame = TRUE)
  expect_equal(toupper(m$get_color()), o$color)
  expect_equal(c(m$opacity, m$gloss, m$shadow, m$is_fixed_in_frame), c(o$opacity, o$gloss, o$shadow, o$is_fixed_in_frame))
  o <- oracle$base_vmobject
  v <- OpenGLVMobject(BLUE, 0.5, RED, 0.7, 2, TRUE, long_lines = TRUE)
  expect_equal(toupper(c(v$get_fill_color(), v$get_stroke_color())), c(o$fill_color, o$stroke_color))
  expect_equal(c(v$get_fill_opacity(), v$get_stroke_opacity(), v$get_stroke_width()),
               c(o$fill_opacity, o$stroke_opacity, o$stroke_width))
  expect_identical(c(v$draw_stroke_behind_fill, v$long_lines), c(o$draw_stroke_behind_fill, o$long_lines))
})
