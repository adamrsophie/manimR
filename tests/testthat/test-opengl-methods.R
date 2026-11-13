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
  half <- OpenGLSurface(function(u, v) c(u, v, u * v), u_range = c(-1, 1), v_range = c(-1, 1), resolution = 3, opacity = 0.5)
  th <- OpenGLTexturedSurface(half, img)
  expect_equal(th$get_shader_data()$opacity[, 1], unlist(oracle$textured_opacity))
  expect_equal(unique(vapply(th$list_of_faces, function(f) f$get_fill_opacity(), 0)), 0.5)
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

test_that("OpenGLImageMobject upscales image arrays with Pillow's filters, as upstream", {
  src <- array(0, c(2, 3, 4))
  px <- list(c(255, 0, 0, 255), c(0, 255, 0, 128), c(0, 0, 255, 255), c(255, 255, 0, 255), c(0, 255, 255, 64), c(40, 80, 120, 255))
  for (k in seq_along(px)) src[(k - 1) %/% 3 + 1, (k - 1) %% 3 + 1, ] <- px[[k]]
  for (alg in c("nearest", "bilinear", "bicubic", "lanczos", "box", "hamming")) {
    im <- OpenGLImageMobject(src, resampling_algorithm = alg)$get_image_from_file(src, "RGBA")
    expect_equal(dim(im), oracle$image_upscaled[[alg]]$dim, info = alg)
    expect_equal(im[c(1, 301, 400), c(seq(1, 600, 7), 600), , drop = FALSE], oracle$image_upscaled[[alg]]$rows, info = alg)
  }
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

test_that("OpenGLCamera turns, moves and zooms as upstream's camera", {
  o <- oracle$camera
  cam <- OpenGLCamera()
  cam$set_euler_angles(theta = PI / 4, phi = PI / 3)
  expect_equal(cam$inverse_rotation_matrix, o$rotation)
  expect_equal(cam$get_position(), o$position)
  expect_equal(cam$unformatted_view_matrix, o$view)
  turned <- OpenGLCamera(euler_angles = c(0.2, 0.4, 0.1))
  turned$rotate(0.3, RIGHT)
  expect_equal(turned$euler_angles, o$turned)
  moved <- OpenGLCamera(frame_shape = c(4, 3), center_point = c(1, 2, 0))
  moved$set_zoom(2)
  moved$increment_phi(3)
  expect_equal(moved$points, o$moved_points)
  expect_equal(moved$get_shape(), o$moved_shape)
  expect_equal(moved$euler_angles[2], o$moved_phi)
  expect_equal(moved$get_focal_distance(), o$focal)
  moved$frame_center <- c(3, 0, 0)
  expect_equal(moved$get_center(), c(3, 0, 0))
  expect_warning(moved$set_focal_distance(3), "can not be adjusted")
  start <- OpenGLCamera()
  end <- OpenGLCamera(euler_angles = c(1, 0.5, 0.2))
  end$shift(c(1, 2, 0))
  end$scale(0.5)
  mid <- OpenGLCamera()
  mid$interpolate(start, end, 0.25)
  expect_equal(mid$points, oracle$camera_interpolate$points)
  expect_equal(mid$euler_angles, oracle$camera_interpolate$angles)
  expect_equal(mid$inverse_rotation_matrix, oracle$camera_interpolate$rotation)
  end$to_default_state()
  expect_equal(end$points, oracle$camera_default$points)
  expect_equal(end$euler_angles, oracle$camera_default$angles)
  expect_s3_class(start$copy(), "OpenGLCamera")
})

test_that("Object3D trees give upstream's hierarchical matrices and copies", {
  o <- oracle$object3d
  a <- Object3D()
  b <- Object3D()
  c3 <- Object3D()
  a$add(b)
  b$add(c3)
  a$model_matrix <- rbind(c(0, -1, 0, 1), c(1, 0, 0, 0), c(0, 0, 1, 0), c(0, 0, 0, 1))
  b$set_position(c(0, 2, 0))
  c3$normal_matrix <- diag(c(2, 3, 4, 1))
  expect_equal(c3$hierarchical_model_matrix(), o$model)
  expect_equal(c3$hierarchical_normal_matrix(), o$normal)
  copied <- a$copy()
  expect_length(copied$get_family(), o$n_family)
  expect_false(identical(copied$children[[1]], b))
  expect_identical(copied$children[[1]]$parent, copied)
  expect_error(Object3D()$add(b), "already added")
  ticks <- 0
  a$add_updater(function(obj, dt) ticks <<- ticks + dt, call_updater = FALSE)
  expect_true(a$has_time_based_updater())
  a$update(0.5)
  expect_equal(ticks, 0.5)
})

test_that("triangulate_mobject() gives upstream's fill triangles", {
  tri <- oracle$triangulation
  quadratic_of <- function(...) {
    m <- OpenGLVMobject()
    m$set_points(do.call(rbind, lapply(list(...), function(x) x$points)))
    m
  }
  got <- list(square = triangulate_mobject(quadratic_of(Square())),
              circle = triangulate_mobject(quadratic_of(Circle())),
              two_squares = triangulate_mobject(quadratic_of(Square(), Square(0.5))))
  for (k in names(got)) {
    expect_equal(get("in_vert", envir = got[[k]]), tri[[k]]$in_vert, tolerance = 1e-6, info = k)
    expect_equal(get("texture_mode", envir = got[[k]])[, 1], tri[[k]]$texture_mode, info = k)
  }
  f <- filter_attributes(got$square, c("in_vert", "texture_coords"))
  expect_equal(c(names(f), length(f)), c(oracle$filtered$names, oracle$filtered$n))
})

test_that("build_matrix_lists() groups a family by its model matrices", {
  g <- OpenGLVGroup(OpenGLSquare(), OpenGLCircle())
  g$submobjects[[2]]$model_matrix <- diag(c(2, 1, 1, 1))
  lists <- build_matrix_lists(g)
  expected <- oracle$matrix_lists
  expect_equal(lapply(strsplit(names(lists), ","), as.numeric), lapply(seq_len(nrow(expected)), function(i) expected$matrix[[i]]))
  expect_equal(unname(lengths(lists)), expected$n)
})

test_that("Shader and FullScreenQuad read upstream's GLSL and keep declared uniforms", {
  s <- Shader(name = "vectorized_mobject_fill")
  expect_named(s$shader_program, c("fragment_shader", "vertex_shader"), ignore.order = TRUE)
  expect_identical(Shader(name = "vectorized_mobject_fill")$shader_program, s$shader_program)
  s$set_uniform("u_projection_matrix", 1)
  s$set_uniform("not_a_uniform", 1)
  expect_named(s$uniforms, "u_projection_matrix")
  q <- FullScreenQuad(fragment_shader_name = "design")
  expect_equal(dim(get("in_vert", envir = q$attributes)), c(6, 4))
  expect_named(q$shader$uniforms, c("u_model_view_matrix", "u_projection_matrix"))
  expect_error(Mesh(s, q$attributes)$render(), "needs an OpenGL context")
  expect_true(dir.exists(SHADER_FOLDER))
})

# A context that keeps the buffers and the shader it is given, as the
# oracle's mock context does.
recording_renderer <- function() {
  rec <- new.env()
  rec$buffers <- list()
  r <- OpenGLRenderer()
  r$context <- list(
    buffer = function(data) {
      rec$buffers[[length(rec$buffers) + 1]] <- data
      data
    },
    simple_vertex_array = function(program, buffer, ...) {
      rec$program <- program
      list(render = function() invisible(NULL), release = function() invisible(NULL))
    }
  )
  r$frame_buffer_object <- list(viewport = c(0, 0, 1280, 720), use = function() invisible(NULL))
  list(renderer = r, rec = rec)
}

test_that("OpenGLRenderer computes upstream's perspective uniforms and pixel coordinates", {
  r <- recording_renderer()$renderer
  r$camera$set_euler_angles(0.3, 0.6, 0.1)
  r$refresh_perspective_uniforms(r$camera)
  want <- oracle$perspective_uniforms
  for (k in names(want)) {
    expect_equal(as.numeric(r$perspective_uniforms[[k]]), as.numeric(want[[k]]), tolerance = 1e-9, info = k)
  }
  r$camera$set_euler_angles(0, 0, 0)
  got <- rbind(r$pixel_coords_to_space_coords(100, 200),
               r$pixel_coords_to_space_coords(30, -20, relative = TRUE),
               r$pixel_coords_to_space_coords(100, 200, top_left = TRUE))
  expect_equal(unname(got), unname(oracle$pixel_to_space), tolerance = 1e-9)
  r$background_color <- "#336699"
  expect_equal(r$background_color, oracle$background_color, tolerance = 1e-9)
})

test_that("render_* functions build upstream's fill and stroke buffers", {
  rr <- recording_renderer()
  r <- rr$renderer
  rec <- rr$rec
  circle <- OpenGLVMobject()
  circle$set_points(Circle(radius = 1.5)$points)
  circle$set_fill(RED, 0.5)
  circle$set_stroke(RED, 6)
  sq <- OpenGLVMobject()
  sq$set_points(Square(side_length = 1)$points)
  sq$set_fill(BLUE, 1)
  circle$add(sq)
  render_opengl_vectorized_mobject_fill(r, circle)
  want <- oracle$fill_buffers
  expect_length(rec$buffers, nrow(want))
  b <- rec$buffers[[1]]
  expect_equal(length(b), want$n[1])
  expect_equal(get("in_vert", envir = b)[1:6, ], want$in_vert[[1]], tolerance = 1e-6)
  expect_equal(get("in_color", envir = b)[c(1, length(b)), ], want$in_color[[1]], tolerance = 1e-6)
  expect_equal(get("texture_coords", envir = b)[1:6, ], want$texture_coords[[1]], tolerance = 1e-9)
  expect_equal(get("texture_mode", envir = b)[, 1], want$texture_mode[[1]])
  for (k in names(oracle$fill_uniforms)) {
    expect_equal(as.numeric(rec$program$uniforms[[k]]), oracle$fill_uniforms[[k]], tolerance = 1e-9, info = k)
  }
  rec$buffers <- list()
  render_opengl_vectorized_mobject_stroke(r, circle)
  want <- oracle$stroke_buffers
  expect_length(rec$buffers, nrow(want))
  b <- rec$buffers[[1]]
  n <- length(b)
  expect_equal(n, want$n[1])
  curve <- get("current_curve", envir = b)[c(1, 2, 4), ]
  want_curve <- want$current_curve[[1]]
  for (i in 1:3) expect_equal(curve[i, ], as.numeric(t(want_curve[i, , ])), tolerance = 1e-6)
  expect_equal(get("tile_coordinate", envir = b)[c(1, 2, 3, n / 2 + 1, n / 2 + 2), ], want$tile_coordinate[[1]])
  expect_equal(get("in_color", envir = b)[1, ], want$in_color[[1]], tolerance = 1e-6)
  expect_equal(get("in_width", envir = b)[c(1, n), 1], want$in_width[[1]])
  for (k in names(oracle$stroke_uniforms)) {
    expect_equal(as.numeric(rec$program$uniforms[[k]]), oracle$stroke_uniforms[[k]], tolerance = 1e-9, info = k)
  }
})

test_that("Window places itself as upstream's find_initial_position()", {
  r <- recording_renderer()$renderer
  monitor <- list(x = 10, y = 20, width = 1920, height = 1080)
  for (pos in names(oracle$window_positions)) {
    tempconfig(list(window_position = pos), {
      w <- Window(r, window_size = c(640, 360), monitor = monitor, open = FALSE)
      expect_equal(w$position, as.numeric(oracle$window_positions[[pos]]), info = pos)
    })
  }
  w <- Window(r, window_size = "default", monitor = monitor, open = FALSE)
  expect_equal(w$size, c(960L, 540L))
  expect_equal(Window(r, window_size = "800,450", monitor = monitor, open = FALSE)$size, c(800L, 450L))
  expect_error(Window(r, window_size = "800", monitor = monitor, open = FALSE), "window_size must be")
})

test_that("OpenGLRenderer draws a scene into its software framebuffer", {
  tempconfig(list(pixel_width = 160, pixel_height = 90), {
    r <- OpenGLRenderer()
    devices <- grDevices::dev.list()
    s <- Scene$new(renderer = r)
    # The framebuffer's device opens when it is first drawn to.
    expect_identical(grDevices::dev.list(), devices)
    on.exit(r$close_device(), add = TRUE)
    # A red disk of radius 2 (22.5 pixels) with a blue stroke on its circle,
    # which runs through the middles of columns 58 and 103.
    c <- OpenGLCircle(radius = 2)
    c$set_fill(RED, 1)
    c$set_stroke(BLUE, 16)
    s$add(c)
    px <- function(a, row, col) as.numeric(a[row, col, ])
    red <- c(color_to_rgb(RED) * 255, 255)
    blue <- c(color_to_rgb(BLUE) * 255, 255)
    check <- function(a) {
      expect_equal(dim(a), c(90, 160, 4))
      expect_lte(max(abs(px(a, 45, 80) - red)), 2)
      expect_lte(max(abs(px(a, 45, 103) - blue)), 2)
      expect_lte(max(abs(px(a, 45, 58) - blue)), 2)
      expect_equal(px(a, 3, 3), c(0, 0, 0, 255))
    }
    r$update_frame(s)
    check(r$get_raw_frame_buffer_object_data())
    # Upstream's projection shaders: u_projection_matrix puts the circle at
    # 0.1534 * 2 in device coordinates (24.5 pixels), and the stroke is
    # 0.004 * 16 units on either side of it.
    tempconfig(list(use_projection_fill_shaders = TRUE, use_projection_stroke_shaders = TRUE), r$update_frame(s))
    b <- r$get_raw_frame_buffer_object_data()
    expect_lte(max(abs(px(b, 45, 80) - red)), 2)
    expect_lte(max(abs(px(b, 45, 104) - red)), 2)
    expect_equal(px(b, 45, 107), c(0, 0, 0, 255))
    expect_gt(b[45, 105, 3], 2 * b[45, 105, 1] - 60)
    expect_gt(b[45, 105, 3], 150)
    expect_s3_class(r$get_frame(), "nativeRaster")
    expect_equal(dim(r$get_image()), c(90, 160))
  })
})

test_that("enable_wireframe draws the projection shaders' triangles as lines", {
  count <- function(wire) tempconfig(list(pixel_width = 160, pixel_height = 90, enable_wireframe = wire,
                                          use_projection_fill_shaders = TRUE, use_projection_stroke_shaders = TRUE), {
    r <- OpenGLRenderer()
    on.exit(r$close_device(), add = TRUE)
    s <- Scene$new(renderer = r)
    c <- OpenGLCircle(radius = 2)
    c$set_fill(RED, 1)
    s$add(c)
    expect_identical(r$context$wireframe, wire)
    r$update_frame(s)
    a <- r$get_raw_frame_buffer_object_data()
    sum(a[, , 1] > 150)
  })
  solid <- count(FALSE)
  lines <- count(TRUE)
  expect_gt(lines, 0)
  expect_lt(lines, solid / 3)
})

test_that("window_monitor picks a monitor as upstream does", {
  mons <- list(list(x = 0, y = 0, width = 1920, height = 1080), list(x = 1920, y = 0, width = 2560, height = 1440))
  expect_identical(manimR:::opengl_monitor(mons, 1), mons[[2]])
  expect_identical(manimR:::opengl_monitor(mons, 5), mons[[2]])
  expect_identical(manimR:::opengl_monitor(mons[[1]], 3), mons[[1]])
  expect_equal(manimR:::opengl_monitor(NULL, 0)$width, 1920)
})

test_that("an OpenGLCamera hashes the same in every run", {
  expect_identical(digest::digest(manimR:::snapshot_camera(OpenGLCamera())),
                   digest::digest(manimR:::snapshot_camera(OpenGLCamera())))
})

test_that("OpenGLSurface runs the surface shader with the depth test", {
  tempconfig(list(pixel_width = 160, pixel_height = 90), {
    r <- OpenGLRenderer()
    s <- Scene$new(renderer = r)
    on.exit(r$close_device(), add = TRUE)
    plane <- function(z, color) {
      p <- OpenGLSurface(function(u, v) c(u, v, z), u_range = c(-1, 1), v_range = c(-1, 1), resolution = c(4, 4))
      p$set_color(color)
      p$gloss <- 0
      p$shadow <- 0
      p
    }
    center <- function() {
      r$update_frame(s)
      a <- r$get_raw_frame_buffer_object_data()
      as.numeric(a[45, 80, 1:3])
    }
    red <- color_to_rgb(RED) * 255
    green <- color_to_rgb(GREEN) * 255
    near <- plane(1, RED)
    far <- plane(0, GREEN)
    # The nearer plane covers the center whichever is drawn last.
    s$add(near, far)
    expect_lte(max(abs(center() - red)), 1)
    s$clear()
    s$add(far, near)
    expect_lte(max(abs(center() - red)), 1)
    # Without the depth test the last one drawn covers it.
    near$deactivate_depth_test()
    far$deactivate_depth_test()
    s$clear()
    s$add(near, far)
    expect_lte(max(abs(center() - green)), 1)
    # Lighting per pixel: each pixel of a glossy plane is add_light() at
    # the point under that pixel.
    s$clear()
    shiny <- plane(0, BLUE)
    shiny$gloss <- 0.8
    shiny$shadow <- 0.5
    s$add(shiny)
    r$update_frame(s)
    a <- r$get_raw_frame_buffer_object_data()
    light <- r$perspective_uniforms$light_source_position
    at <- function(row, col) {
      xy <- c((col - 0.5) / 160 * 2 - 1, (row - 0.5) / 90 * 2 - 1) * c(8 * 16 / 9, 8) / 2
      opengl_add_light(c(color_to_rgb(BLUE), 1), c(xy, 0), c(0, 0, 1), light, 0.8, 0.5)[1:3] * 255
    }
    for (rc in list(c(40, 72), c(50, 88), c(45, 80))) {
      expect_lte(max(abs(as.numeric(a[rc[1], rc[2], 1:3]) - at(rc[1], rc[2]))), 1)
    }
    expect_gt(max(abs(as.numeric(a[40, 72, 1:3]) - as.numeric(a[50, 88, 1:3]))), 2)
  })
})

test_that("OpenGLTexturedSurface samples its image as the textured_surface shader does", {
  tempconfig(list(pixel_width = 160, pixel_height = 90), {
    r <- OpenGLRenderer()
    s <- Scene$new(renderer = r)
    on.exit(r$close_device(), add = TRUE)
    plane <- OpenGLSurface(function(u, v) c(u, v, 0), u_range = c(-2, 2), v_range = c(-2, 2), resolution = c(3, 3))
    plane$gloss <- 0
    plane$shadow <- 0
    img <- array(0, c(2, 2, 4))
    img[, , 4] <- 255
    img[1, 1, 1] <- 255
    img[1, 2, 2] <- 255
    img[2, 1, 3] <- 255
    img[2, 2, 1:3] <- 255
    # Upstream sets a textured surface's gloss and shadow itself.
    tex <- OpenGLTexturedSurface(plane, img, gloss = 0, shadow = 0)
    s$add(tex)
    r$update_frame(s)
    a <- r$get_raw_frame_buffer_object_data()
    # Rows from the bottom: the image stands upright on the plane, each
    # texel covering a quarter of it (nearest texel, no smoothing).
    px <- function(row, col) as.numeric(a[row, col, 1:3])
    expect_equal(px(60, 60), c(255, 0, 0))
    expect_equal(px(60, 100), c(0, 255, 0))
    expect_equal(px(30, 60), c(0, 0, 255))
    expect_equal(px(30, 100), c(255, 255, 255))
    expect_equal(px(46, 81), c(0, 255, 0))
    expect_equal(px(45, 80), c(0, 0, 255))
  })
})

test_that("OpenGL point clouds run the true_dot shader", {
  tempconfig(list(pixel_width = 160, pixel_height = 90), {
    r <- OpenGLRenderer()
    s <- Scene$new(renderer = r)
    on.exit(r$close_device(), add = TRUE)
    # A dot of radius 0.4 (4.5 pixels) at the origin, between columns 80
    # and 81.
    dot <- OpenGLPMobject(stroke_width = 40, color = RED)
    dot$add_points(rbind(c(0, 0, 0)), color = RED)
    s$add(dot)
    r$update_frame(s)
    a <- r$get_raw_frame_buffer_object_data()
    red <- color_to_rgb(RED) * 255
    expect_lte(max(abs(as.numeric(a[45, 80, 1:3]) - red)), 1)
    expect_lte(max(abs(as.numeric(a[45, 83, 1:3]) - red)), 1)
    expect_equal(as.numeric(a[45, 87, 1:3]), c(0, 0, 0))
    # The edge fades over anti_alias_width (1.5 pixels): the center of
    # column 85 is on the circle, at about half the alpha.
    edge <- a[45, 85, 1]
    expect_gt(edge, 0)
    expect_lt(edge, red[1])
    # With the depth test a dot behind an opaque surface is hidden.
    wall <- OpenGLSurface(function(u, v) c(u, v, 1), u_range = c(-1, 1), v_range = c(-1, 1), resolution = c(3, 3))
    wall$set_color(GREEN)
    wall$gloss <- 0
    wall$shadow <- 0
    dot$apply_depth_test()
    s$clear()
    s$add(wall, dot)
    r$update_frame(s)
    a <- r$get_raw_frame_buffer_object_data()
    expect_lte(max(abs(as.numeric(a[45, 80, 1:3]) - color_to_rgb(GREEN) * 255)), 1)
  })
})

test_that("an OpenGLSurface draws the colors its animations give it", {
  tempconfig(list(pixel_width = 160, pixel_height = 90), {
    r <- OpenGLRenderer()
    s <- Scene$new(renderer = r)
    on.exit(r$close_device(), add = TRUE)
    p <- OpenGLSurface(function(u, v) c(u, v, 0), u_range = c(-1, 1), v_range = c(-1, 1), resolution = c(3, 3))
    p$set_color(WHITE)
    p$gloss <- 0
    p$shadow <- 0
    s$add(p)
    anim <- FadeIn(p)
    anim$begin()
    anim$interpolate(0.5)
    r$update_frame(s)
    a <- r$get_raw_frame_buffer_object_data()
    expect_equal(as.numeric(a[45, 80, 1]), 127.5, tolerance = 1.5)
    # A colorscale with axes colors each vertex by its z coordinate.
    ax <- ThreeDAxes()
    cs <- OpenGLSurface(function(u, v) c(u, v, u), u_range = c(-1, 1), v_range = c(-1, 1), resolution = c(5, 5),
                        axes = ax, colorscale = c(RED, BLUE))
    col <- get("color", envir = cs$get_shader_data())
    z <- ax$z_range
    expected <- function(point) {
      color_to_rgba(interpolate_color(RED, BLUE, (ax$point_to_coords(point)[3] - z[1]) / (z[2] - z[1])))
    }
    expect_equal(col[1, ], expected(c(-1, -1, -1)), tolerance = 1e-9)
    expect_equal(col[nrow(col), ], expected(c(1, 1, 1)), tolerance = 1e-9)
    expect_false(isTRUE(all.equal(col[1, ], col[nrow(col), ])))
  })
})

test_that("the software shaders draw the frames of upstream's OpenGL renderer", {
  # Frames from data-raw/opengl_oracle.py (upstream on a GPU, 160 x 90).
  oracle <- function(name) {
    a <- png::readPNG(testthat::test_path("fixtures", paste0("opengl_", name, ".png"))) * 255
    round(a)
  }
  frame <- function(mobjects) {
    tempconfig(list(pixel_width = 160, pixel_height = 90), {
      r <- OpenGLRenderer()
      s <- Scene$new(renderer = r)
      on.exit(r$close_device(), add = TRUE)
      for (m in mobjects) s$add(m)
      r$update_frame(s)
      r$get_raw_frame_buffer_object_data()
    })
  }
  surf <- function(f, ur, vr, res, color = GREY, gloss = 0.3, shadow = 0.4) {
    OpenGLSurface(f, u_range = ur, v_range = vr, resolution = res, color = color, gloss = gloss, shadow = shadow)
  }
  far <- surf(function(u, v) c(u, v, 0), c(-1, 1), c(-1, 1), c(4, 4), GREEN, 0, 0)
  near <- surf(function(u, v) c(u, v, 1), c(-1, 1), c(-1, 1), c(4, 4), RED, 0, 0)
  expect_lte(max(abs(frame(list(far, near)) - oracle("planes"))), 1)
  tilted <- surf(function(u, v) c(u, v, 0.5 * u), c(-2, 2), c(-1.5, 1.5), c(5, 5), BLUE, 0.8, 0.5)
  expect_lte(max(abs(frame(list(tilted)) - oracle("tilted"))), 1)
  plane <- surf(function(u, v) c(u, v, 0), c(-2, 2), c(-2, 2), c(101, 101), GREY, 0, 0)
  textured <- OpenGLTexturedSurface(plane, testthat::test_path("fixtures", "opengl_texture.png"))
  expect_lte(max(abs(frame(list(textured)) - oracle("textured"))), 1)
  dot <- OpenGLPMobject(stroke_width = 40, color = RED)
  dot$add_points(rbind(c(0, 0, 0)), color = RED)
  cloud <- DotCloud(radius = 1.5, density = 3, color = BLUE)$make_3d()$shift(RIGHT * 3)
  expect_lte(max(abs(frame(list(dot, cloud)) - oracle("dots"))), 1)
  # VMobjects run the quadratic_bezier_fill and quadratic_bezier_stroke
  # shaders.
  circle <- Circle(radius = 1.5, color = WHITE, fill_color = RED, fill_opacity = 1, stroke_width = 4)$shift(LEFT * 2)
  square <- Square(side_length = 2, color = YELLOW, fill_color = BLUE, fill_opacity = 0.5, stroke_width = 8)$shift(RIGHT * 2)
  expect_lte(max(abs(frame(list(circle, square)) - oracle("vfill"))), 2)
  zig <- OpenGLVMobject(stroke_color = GREEN, stroke_width = 10)
  zig$set_points_as_corners(rbind(c(-4, -1, 0), c(-2, 1.5, 0), c(0, -1, 0), c(2, 1.5, 0), c(4, -1, 0)))
  arc <- OpenGLVMobject(stroke_color = WHITE, stroke_width = 6)
  arc$set_points(rbind(c(-3, -2.5, 0), c(-1, -0.5, 0), c(1, -0.5, 0), c(3, -2.5, 0)))
  expect_lte(max(abs(frame(list(zig, arc)) - oracle("vstroke"))), 3)
  # Turned out of the frame's plane (perspective, flat_stroke) and with
  # round, miter and bevel joints.
  tilted_square <- Square(side_length = 2, color = YELLOW, fill_color = BLUE, fill_opacity = 0.8, stroke_width = 12)
  tilted_square$rotate(PI / 3, axis = RIGHT)$rotate(PI / 6, axis = UP)$shift(LEFT * 3.5)
  zigs <- lapply(1:3, function(k) {
    z <- OpenGLVMobject(stroke_color = list(RED, GREEN, WHITE)[[k]], stroke_width = 16)
    z$set_points_as_corners(rbind(c(0, 1, 0), c(1, -1, 0), c(2, 1, 0), c(3, -1, 0)))
    z$joint_type <- c("round", "miter", "bevel")[k]
    z$shift(c(-0.5, 5 - 2.5 * k, 0))
  })
  expect_lte(max(abs(frame(c(list(tilted_square), zigs)) - oracle("vtilt"))), 3)
  # A curve of zero length is left out of the stroke, as upstream's
  # geometry shader emits nothing for it.
  dup <- OpenGLVMobject(stroke_color = GREEN, stroke_width = 10)
  dup$set_points_as_corners(rbind(c(-4, -1, 0), c(-2, 1.5, 0), c(-2, 1.5, 0), c(0, -1, 0), c(2, 1.5, 0), c(4, -1, 0)))
  expect_lte(max(abs(frame(list(dup)) - oracle("vdup"))), 3)
  # A turned camera, and a checkerboard sphere whose faces upstream draws in
  # order without a depth test.
  turned <- tempconfig(list(pixel_width = 160, pixel_height = 90), {
    r <- OpenGLRenderer()
    s <- Scene$new(renderer = r)
    on.exit(r$close_device(), add = TRUE)
    s$add(Sphere(radius = 1.5, resolution = c(8, 6))$shift(LEFT * 2),
          Circle(radius = 1, color = WHITE, fill_color = RED, fill_opacity = 0.7, stroke_width = 6)$shift(RIGHT * 2))
    r$camera$set_euler_angles(theta = -30 * DEGREES, phi = 60 * DEGREES)
    r$update_frame(s)
    r$get_raw_frame_buffer_object_data()
  })
  expect_lte(max(abs(turned - oracle("vcamera"))), 4)
  # A fill with a hole: the inner circle runs the other way.
  cubic_circle <- function(radius) {
    a <- seq(0, TAU, length.out = 9)
    h <- 4 / 3 * tan(PI / 16)
    do.call(rbind, lapply(1:8, function(k) {
      p0 <- c(cos(a[k]), sin(a[k]), 0)
      p3 <- c(cos(a[k + 1]), sin(a[k + 1]), 0)
      radius * rbind(p0, p0 + h * c(-sin(a[k]), cos(a[k]), 0), p3 - h * c(-sin(a[k + 1]), cos(a[k + 1]), 0), p3)
    }))
  }
  ring <- OpenGLVMobject(fill_color = GREEN, fill_opacity = 1, stroke_color = WHITE, stroke_width = 4)
  inner <- cubic_circle(1)
  ring$set_points(unname(rbind(cubic_circle(2), inner[nrow(inner):1, ])))
  expect_lte(max(abs(frame(list(ring)) - oracle("vhole"))), 3)
  # OpenGLImageMobject is upstream's textured surface: the upscaled image
  # sampled at nearest texels, with the opacity of set_opacity().
  img <- array(0, c(2, 3, 4))
  texels <- list(c(255, 0, 0, 255), c(0, 255, 0, 255), c(0, 0, 255, 255), c(255, 255, 0, 255), c(0, 255, 255, 255),
                 c(255, 255, 255, 128))
  for (k in 1:6) img[(k - 1) %/% 3 + 1, (k - 1) %% 3 + 1, ] <- texels[[k]]
  image_a <- OpenGLImageMobject(img)$shift(LEFT * 3)
  image_b <- OpenGLImageMobject(img, height = 2)$rotate(PI / 5)$shift(c(3, 1, 0))
  image_b$set_opacity(0.5)
  expect_lte(max(abs(frame(list(image_a, image_b)) - oracle("vimage"))), 4)
  # Upstream's renderer compiles shaders from their files, so the code
  # set_color_by_code() puts into the wrappers' programs is not drawn.
  coded <- OpenGLVMobject(fill_color = RED, fill_opacity = 1, stroke_color = WHITE, stroke_width = 8)
  coded$set_points(Square(side_length = 4)$shift(LEFT * 3)$points)
  coded$set_color_by_code("color.rgb = vec3(point.x > -3.0 ? 1.0 : 0.0, 0.5 + 0.2 * point.y, 1.0);")
  coded_plane <- surf(function(u, v) c(u, v, 0), c(1, 5), c(-2, 2), c(4, 4), GREEN, 0, 0)
  coded_plane$set_color_by_code("color.rgb = vec3(1.0, 0.0, 1.0);")
  expect_lte(max(abs(frame(list(coded, coded_plane)) - oracle("vcode"))), 2)
  # Meshes with upstream's own mesh shaders, drawn after the mobjects.
  meshes <- tempconfig(list(pixel_width = 160, pixel_height = 90), {
    r <- OpenGLRenderer()
    s <- Scene$new(renderer = r)
    on.exit(r$close_device(), add = TRUE)
    colored <- shader_data(c(in_vert = 4, in_color = 4), 3)
    assign("in_vert", rbind(c(-6, -3, 0, 1), c(-1, -3, 0, 1), c(-3.5, 3, 0, 1)), envir = colored)
    assign("in_color", rbind(c(1, 0, 0, 1), c(0, 1, 0, 1), c(0, 0, 1, 0.5)), envir = colored)
    plain <- shader_data(c(in_vert = 3), 4)
    assign("in_vert", rbind(c(1, -2, 0), c(5, -2, 0), c(5, 2, 0), c(1, 2, 0)), envir = plain)
    flat <- Shader(r$context, name = "default")
    flat$set_uniform("u_color", c(1, 0.8, 0, 0.75))
    colored_mesh <- Mesh(Shader(r$context, name = "vertex_colors"), colored)
    s$add(colored_mesh, Mesh(flat, plain, indices = c(0, 1, 2, 0, 2, 3)))
    expect_length(s$meshes, 2)
    expect_length(s$mobjects, 0)
    r$update_frame(s)
    out <- r$get_raw_frame_buffer_object_data()
    s$remove(colored_mesh)
    expect_length(s$meshes, 1)
    out
  })
  expect_lte(max(abs(meshes - oracle("vmesh"))), 2)
  # A mesh with its own GLSL code: its shaders run in the interpreter, with
  # perspective-correct varyings, a user function, a loop and discard.
  glsl_vs <- "#version 330
in vec3 in_vert;
in vec2 in_uv;
uniform mat4 u_model_matrix;
uniform mat4 u_view_matrix;
uniform mat4 u_projection_matrix;
out vec2 v_uv;
out float v_height;
void main() {
    vec4 world = u_model_matrix * vec4(in_vert, 1.0);
    v_uv = in_uv;
    v_height = world.z;
    gl_Position = u_projection_matrix * u_view_matrix * world;
}"
  glsl_fs <- "#version 330
in vec2 v_uv;
in float v_height;
uniform vec3 u_tint;
out vec4 frag_color;
float bands(float x) {
    float s = 0.0;
    for (int i = 1; i <= 3; i++) {
        s += sin(x * float(i) * 6.2831853) / float(i);
    }
    return s;
}
void main() {
    vec2 cell = floor(v_uv * 4.0);
    if (mod(cell.x + cell.y, 2.0) > 0.5 && v_uv.y > 0.5) discard;
    float b = 0.5 + 0.25 * bands(v_uv.x);
    frag_color = vec4(mix(u_tint, vec3(v_uv, b), 0.6), 0.9);
}"
  custom <- tempconfig(list(pixel_width = 160, pixel_height = 90), {
    r <- OpenGLRenderer()
    s <- Scene$new(renderer = r)
    on.exit(r$close_device(), add = TRUE)
    r$camera$set_euler_angles(theta = -20 * DEGREES, phi = 40 * DEGREES)
    quad <- shader_data(c(in_vert = 3, in_uv = 2), 4)
    assign("in_vert", rbind(c(-4, -3, -2), c(4, -3, -2), c(4, 3, 2), c(-4, 3, 2)), envir = quad)
    assign("in_uv", rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 1)), envir = quad)
    sh <- Shader(r$context, source = list(vertex_shader = glsl_vs, fragment_shader = glsl_fs))
    sh$set_uniform("u_tint", c(1, 0.3, 0.1))
    s$add(Mesh(sh, quad, indices = c(0, 1, 2, 0, 2, 3)))
    r$update_frame(s)
    r$get_raw_frame_buffer_object_data()
  })
  expect_lte(max(abs(custom - oracle("vglsl"))), 2)
  # A geometry shader: triangles in, a triangle strip out, with EmitVertex()
  # under a mask.
  glsl_gs <- "#version 330
layout(triangles) in;
layout(triangle_strip, max_vertices = 6) out;
in vec2 v_uv[];
in float v_height[];
out vec3 g_color;
void main() {
    vec4 c = (gl_in[0].gl_Position + gl_in[1].gl_Position + gl_in[2].gl_Position) / 3.0;
    for (int i = 0; i < 3; i++) {
        gl_Position = mix(c, gl_in[i].gl_Position, 0.8);
        g_color = vec3(v_uv[i], 0.5 + 0.2 * v_height[i]);
        EmitVertex();
    }
    EndPrimitive();
    if (gl_PrimitiveIDIn == 0) {
        for (int i = 0; i < 3; i++) {
            gl_Position = mix(c, gl_in[i].gl_Position, 0.3);
            gl_Position.z -= 0.1 * gl_Position.w;
            g_color = vec3(1.0, 1.0, float(i) / 2.0);
            EmitVertex();
        }
        EndPrimitive();
    }
}
"
  glsl_gfs <- "#version 330
in vec3 g_color;
out vec4 frag_color;
void main() {
    frag_color = vec4(g_color, 1.0);
}
"
  geom <- tempconfig(list(pixel_width = 160, pixel_height = 90), {
    r <- OpenGLRenderer()
    s <- Scene$new(renderer = r)
    on.exit(r$close_device(), add = TRUE)
    r$camera$set_euler_angles(theta = -20 * DEGREES, phi = 40 * DEGREES)
    quad <- shader_data(c(in_vert = 3, in_uv = 2), 4)
    assign("in_vert", rbind(c(-4, -3, -2), c(4, -3, -2), c(4, 3, 2), c(-4, 3, 2)), envir = quad)
    assign("in_uv", rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 1)), envir = quad)
    sh <- Shader(r$context, source = list(vertex_shader = glsl_vs, geometry_shader = glsl_gs, fragment_shader = glsl_gfs))
    s$add(Mesh(sh, quad, indices = c(0, 1, 2, 0, 2, 3)))
    r$update_frame(s)
    r$get_raw_frame_buffer_object_data()
  })
  expect_lte(max(abs(geom - oracle("vgeom"))), 2)
  # A FullScreenQuad runs its fragment shader over the frame.
  quad <- tempconfig(list(pixel_width = 160, pixel_height = 90), {
    r <- OpenGLRenderer()
    s <- Scene$new(renderer = r)
    on.exit(r$close_device(), add = TRUE)
    s$add(FullScreenQuad(r$context, fragment_shader_source = "
        #version 330
        out vec4 frag_color;
        void main() {
            vec2 p = gl_FragCoord.xy / vec2(160.0, 90.0);
            frag_color = vec4(p.x, p.y, 0.5 + 0.5 * sin(20.0 * length(p - 0.5)), 1.0);
        }
        "))
    r$update_frame(s)
    r$get_raw_frame_buffer_object_data()
  })
  expect_lte(max(abs(quad - oracle("vquad"))), 2)
  # Structs: constructors, fields, nested writes, inout, returns, arrays.
  structs <- tempconfig(list(pixel_width = 160, pixel_height = 90), {
    r <- OpenGLRenderer()
    s <- Scene$new(renderer = r)
    on.exit(r$close_device(), add = TRUE)
    s$add(FullScreenQuad(r$context, fragment_shader_source = "
        #version 330
        out vec4 frag_color;
        struct Ring { vec2 center; float radius; vec3 color; };
        Ring grow(Ring r, float f) { r.radius *= f; return r; }
        void tint(inout Ring r) { r.color.g = 1.0 - r.color.g; }
        void main() {
            vec2 p = gl_FragCoord.xy / vec2(160.0, 90.0);
            Ring rings[3];
            rings[0] = Ring(vec2(0.25, 0.5), 0.12, vec3(1.0, 0.2, 0.1));
            rings[1] = grow(Ring(vec2(0.55, 0.45), 0.1, vec3(0.1, 0.3, 1.0)), 1.6);
            rings[2] = rings[0];
            rings[2].center.x = 0.8;
            tint(rings[2]);
            vec3 c = vec3(0.05);
            for (int i = 0; i < 3; i++) {
                float d = length((p - rings[i].center) * vec2(1.78, 1.0));
                if (d < rings[i].radius) c = mix(c, rings[i].color, 0.7);
            }
            frag_color = vec4(c, 1.0);
        }
        "))
    r$update_frame(s)
    r$get_raw_frame_buffer_object_data()
  })
  expect_lte(max(abs(structs - oracle("vstruct"))), 2)
  # Shapes made under the OpenGL renderer have upstream's OpenGL geometry
  # (a circle of 9 quadratic arcs), drawn without conversion.
  native <- tempconfig(list(renderer = "opengl", pixel_width = 160, pixel_height = 90), {
    r <- OpenGLRenderer()
    s <- Scene$new(renderer = r)
    on.exit(r$close_device(), add = TRUE)
    c1 <- Circle(radius = 1.5, color = WHITE, fill_color = RED, fill_opacity = 0.7, stroke_width = 6)
    expect_equal(nrow(opengl_quadratic_points(c1)), 27)
    s$add(c1$shift(c(-4, 0, 0)),
          Square(side_length = 2.5, fill_color = GREEN, fill_opacity = 1, stroke_color = YELLOW,
                 stroke_width = 8)$rotate(PI / 7),
          Triangle(fill_color = BLUE, fill_opacity = 0.6, stroke_width = 4)$shift(c(4, 1, 0)),
          Arc(radius = 1.2, start_angle = 0.3, angle = 4, stroke_width = 10, color = "#FF862F")$shift(c(4, -2, 0)))
    r$update_frame(s)
    r$get_raw_frame_buffer_object_data()
  })
  expect_lte(max(abs(native - oracle("vnative"))), 2)
  # A Sphere made under the OpenGL renderer: its faces map the midpoint
  # handles of quadratic edges through the surface function, as upstream.
  ball <- tempconfig(list(renderer = "opengl", pixel_width = 160, pixel_height = 90), {
    expect_length(Sphere()$submobjects, 101 * 51)
    r <- OpenGLRenderer()
    s <- Scene$new(renderer = r)
    on.exit(r$close_device(), add = TRUE)
    s$add(Sphere(radius = 1.5, resolution = c(8, 6))$shift(c(-2, 0, 0)))
    r$camera$set_euler_angles(theta = -30 * DEGREES, phi = 60 * DEGREES)
    r$update_frame(s)
    r$get_raw_frame_buffer_object_data()
  })
  expect_lte(max(abs(ball - oracle("vsphere"))), 4)
  # A rotated parent mesh with a child, a manim_coords mesh and a test
  # shader mesh, over a filled square with the camera turned.
  meshes2 <- tempconfig(list(pixel_width = 160, pixel_height = 90), {
    r <- OpenGLRenderer()
    s <- Scene$new(renderer = r)
    on.exit(r$close_device(), add = TRUE)
    s$add(Square(side_length = 4, fill_color = BLUE, fill_opacity = 1, stroke_width = 0))
    r$camera$set_euler_angles(theta = -30 * DEGREES, phi = 50 * DEGREES)
    tri <- function(p) {
      d <- shader_data(c(in_vert = ncol(p)), 3)
      assign("in_vert", p, envir = d)
      d
    }
    flat <- function(name, color) {
      sh <- Shader(r$context, name = name)
      sh$set_uniform("u_color", color)
      sh
    }
    parent <- Mesh(flat("default", c(1, 0.2, 0.2, 0.8)), tri(rbind(c(0, 0, 0.5), c(3, 0, 0.5), c(0, 2, 0.5))))
    parent$model_matrix <- rbind(c(cos(PI / 6), -sin(PI / 6), 0, 1), c(sin(PI / 6), cos(PI / 6), 0, 0),
                                 c(0, 0, 1, 0), c(0, 0, 0, 1))
    child <- Mesh(flat("default", c(0.2, 1, 0.2, 0.6)), tri(rbind(c(0, 0, -0.5), c(2, 0, -0.5), c(1, 2, -0.5))))
    child$set_position(c(-4, -1, 0))
    parent$add(child)
    coords <- Mesh(flat("manim_coords", c(1, 1, 0, 1)), tri(rbind(c(-1, 1, 0, 1), c(1, 1, 0, 1), c(0, 3, 0, 1))))
    coords$shader$set_uniform("u_model_view_matrix", r$camera$formatted_view_matrix)
    corner <- shader_data(c(in_vert = 2, in_color = 4), 3)
    assign("in_vert", rbind(c(0.6, 0.6), c(0.95, 0.6), c(0.95, 0.95)), envir = corner)
    assign("in_color", rbind(c(1, 0, 1, 1), c(0, 1, 1, 1), c(1, 1, 1, 0.5)), envir = corner)
    s$add(parent, coords, Mesh(Shader(r$context, name = "test"), corner))
    r$update_frame(s)
    out <- r$get_raw_frame_buffer_object_data()
    # A geometry shader without a triangle strip output is not run.
    s$add(Mesh(Shader(r$context, source = list(vertex_shader = "void main() {}", fragment_shader = "void main() {}",
                                               geometry_shader = "void main() {}")),
               tri(rbind(c(0, 0, 0), c(1, 0, 0), c(0, 1, 0)))))
    expect_error(r$update_frame(s), "OpenGL")
    out
  })
  expect_lte(max(abs(meshes2 - oracle("vmesh2"))), 2)
  # A VMobject holding a surface draws the surface with its own shader.
  plane <- surf(function(u, v) c(u, v, 0), c(-1, 1), c(-1, 1), c(4, 4), GREEN, 0, 0)
  expect_equal(frame(list(VGroup(plane$copy()))), frame(list(plane)))
  # Near the sphere's front pole the vertex normals nearly cancel, and the
  # GPU's single precision interpolation sets their direction.
  sphere <- surf(function(u, v) 2 * c(cos(u) * sin(v), sin(u) * sin(v), -cos(v)), c(0, TAU), c(0, PI), c(33, 17), BLUE)
  d <- apply(abs(frame(list(sphere)) - oracle("sphere")), 1:2, max)
  expect_lte(sum(d > 2), 40)
  expect_lte(max(d[-(40:50), ]), 1)
})

test_that("ThreeDScene fixes mobjects in frame through their shader uniforms under OpenGLRenderer", {
  frame <- function(fixed, turn) tempconfig(list(pixel_width = 160, pixel_height = 90), {
    r <- OpenGLRenderer()
    s <- ThreeDScene$new(renderer = r)
    on.exit(r$close_device(), add = TRUE)
    sq <- Square(side_length = 2, fill_color = RED, fill_opacity = 1)
    if (fixed) s$add_fixed_in_frame_mobjects(sq) else s$add(sq)
    if (fixed) expect_equal(sq$submobjects, list())
    if (fixed) expect_equal(sq$is_fixed_in_frame, 1)
    if (turn) s$set_camera_orientation(phi = 70 * DEGREES, theta = -30 * DEGREES)
    r$update_frame(s)
    r$get_raw_frame_buffer_object_data()
  })
  flat <- frame(FALSE, FALSE)
  expect_equal(frame(TRUE, TRUE), flat)
  expect_false(isTRUE(all.equal(frame(FALSE, TRUE), flat)))
})

test_that("plot_surface makes an OpenGLSurface under the OpenGL renderer, as upstream", {
  axes <- ThreeDAxes()
  f <- function(u, v) u * v
  s <- tempconfig(list(renderer = "opengl"),
                  axes$plot_surface(f, u_range = c(-1, 1), v_range = c(-1, 1), resolution = c(4, 4),
                                    colorscale = c(BLUE, RED)))
  expect_s3_class(s, "OpenGLSurface")
  expect_length(s$submobjects, 9)
  expect_false(inherits(axes$plot_surface(f, u_range = c(-1, 1), v_range = c(-1, 1), resolution = 2),
                        "OpenGLSurface"))
})

test_that("plot colors by point under the OpenGL renderer, as upstream", {
  g <- tempconfig(list(renderer = "opengl"),
                  Axes()$plot(function(x) x^2, x_range = c(-2, 2), colorscale = c(BLUE, RED)))
  expect_equal(g$sheen_factor, 0)
  expect_gt(nrow(g$stroke_rgbas), 2)
  expect_equal(nrow(g$fill_rgbas), nrow(g$stroke_rgbas))
})

test_that("StreamLines color each point by the field's norm under the OpenGL renderer", {
  f <- function(p) c(-p[2], p[1], 0)
  s <- tempconfig(list(renderer = "opengl"),
                  StreamLines(f, x_range = c(-2, 2, 1), y_range = c(-2, 2, 1), virtual_time = 1, stroke_width = 2))
  l <- s$stream_lines[[1]]
  expect_equal(l$stroke_width, 0.5)
  expect_equal(nrow(l$stroke_rgbas), nrow(l$points))
  norm <- sqrt(sum(f(l$points[1, ])^2))
  expect_equal(l$stroke_rgbas[1, ], s$get_vectorized_rgba_gradient_function(0, 2, s$colors)(norm, 1)[1, ],
               ignore_attr = TRUE)
})

test_that("Cylinder bases take opacity 1 under the OpenGL renderer, as upstream", {
  c1 <- tempconfig(list(renderer = "opengl"), Cylinder(fill_color = "#FF0000", fill_opacity = 0.5))
  expect_equal(c1$base_top$get_fill_opacity(), 1)
  expect_equal(c1$base_top$get_fill_color(), "#FF0000")
  expect_equal(Cylinder(fill_opacity = 0.5)$base_top$get_fill_opacity(), 0.5)
})

test_that("SVG paths under the OpenGL renderer keep upstream's quadratic curves", {
  # Points from upstream 0.22.1 under renderer = "opengl".
  path <- "M 0 0 L 0 0 Q 2 3 4 0 C 5 2 6 -2 7 0 L 7 0 Z"
  q <- function(...) tempconfig(list(renderer = "opengl"), opengl_quadratic_points(VMobjectFromSVGPath(path, ...)))
  expect_equal(unname(q(should_remove_null_curves = TRUE)[, 1:2]),
               matrix(c(0, 0, 2, 3, 4, 0, 4, 0, 4.75, 1.5, 5.5, 0, 5.5, 0, 6.25, -1.5, 7, 0, 7, 0, 3.5, 0, 0, 0),
                      ncol = 2, byrow = TRUE))
  expect_equal(nrow(q()), 18)
  sharp <- q(should_subdivide_sharp_curves = TRUE, should_remove_null_curves = TRUE)
  expect_equal(nrow(sharp), 45)
  expect_equal(unname(sharp[2:3, 1:2]), rbind(c(0.5, 0.75), c(1, 1.125)))
})

test_that("mobjects made under the OpenGL renderer are bounded and transformed as upstream", {
  # Values from upstream 0.22.1 under renderer = "opengl".
  tempconfig(list(renderer = "opengl"), {
    c1 <- Circle()
    expect_equal(c(c1$width, c1$height), c(2.0642, 2.096), tolerance = 1e-4)
    expect_equal(c1$get_top(), c(-0.0321, 1.048, 0), tolerance = 1e-3)
    g <- VGroup(Circle(), Square())$arrange(RIGHT)
    expect_equal(g$submobjects[[2]]$get_center(), c(1.1571, 0, 0), tolerance = 1e-4)
    a <- VGroup(Circle(), Square())
    b <- VGroup(Square(color = RED), Circle(color = BLUE))$shift(RIGHT)
    t1 <- Transform(a, b)
    t1$begin()
    t1$interpolate(0.5)
    expect_equal(round(a$submobjects[[1]]$get_center(), 3), c(0.484, 0, 0))
    expect_equal(round(unname(opengl_quadratic_points(a$submobjects[[1]])[2, ]), 3), c(1.333, 0.682, 0))
  })
})

test_that("OpenGL-made mobjects keep upstream's quadratic curve counts in transforms", {
  # Values from upstream 0.22.1 under renderer = "opengl".
  tempconfig(list(renderer = "opengl"), {
    a <- VMobjectFromSVGPath("M 0 0 C 1 2 2 3 3 0 C 2 -1 1 -2 0 0 Z")
    expect_equal(a$get_num_curves(), 4)
    t1 <- Transform(a, Circle())
    t1$begin()
    t1$interpolate(0.3)
    q <- opengl_quadratic_points(a)
    expect_equal(nrow(q), 27)
    expect_equal(round(unname(q[c(2, 5, 6), 1:2]), 4), rbind(c(0.3355, 0.4845), c(0.7252, 1.2126), c(0.9058, 1.4412)))
  })
})

test_that("the GLSL interpreter runs functions, loops, matrices and discard", {
  vs <- "#version 330
in vec3 in_vert;
uniform mat4 u_m;
uniform float u_k;
out vec3 v_pos;
float twice(float x) { return 2.0 * x; }
void scale(inout vec3 p, float s) { p *= s; }
void main() {
  vec3 p = in_vert;
  scale(p, u_k);
  float acc = 0.0;
  for (int i = 0; i < 4; i++) { if (i == 2) continue; acc += float(i); }
  v_pos = p + vec3(acc, twice(1.5), 0.0);
  gl_Position = u_m * vec4(p, 1.0);
}"
  m <- diag(4)
  m[1, 4] <- 10
  st <- glsl_run(glsl_program(vs), 2, inputs = list(in_vert = rbind(c(1, 2, 3), c(4, 5, 6))),
                 uniforms = list(u_m = as.vector(m), u_k = 2))
  expect_equal(unname(get("gl_Position", st$globals)), rbind(c(12, 4, 6, 1), c(18, 10, 12, 1)))
  expect_equal(unname(get("v_pos", st$globals)), rbind(c(6, 7, 6), c(12, 13, 12)))
  fs <- "in vec3 v_pos; out vec4 frag_color;
void main() { if (v_pos.x > 5.0) discard; mat2 r = mat2(0.0, 1.0, -1.0, 0.0);
  frag_color = vec4(r * vec2(1.0, 0.0), length(v_pos.xy), 1.0); }"
  st <- glsl_run(glsl_program(fs), 2, inputs = list(v_pos = rbind(c(3, 4, 0), c(9, 0, 0))))
  expect_equal(st$discarded, c(FALSE, TRUE))
  expect_equal(unname(get("frag_color", st$globals)[1, ]), c(0, 1, 5, 1))
  expect_error(glsl_run(glsl_program("uniform sampler2D t; void main() { gl_FragColor = texture(t, vec2(0.0)); }"), 1),
               "not supported")
})
