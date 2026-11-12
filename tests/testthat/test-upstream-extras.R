# Helpers of manim.utils that `from manim import *` does not export, and
# argument names and defaults, checked against values from the upstream
# source (data-raw/extras_oracle.py).

extras_oracle <- function() {
  skip_if_not_installed("jsonlite")
  jsonlite::fromJSON(test_path("fixtures", "extras_oracle.json"), simplifyVector = FALSE)
}

ex_mat <- function(x) {
  if (!length(x)) return(matrix(0, 0, 3))
  if (!is.list(x[[1]])) return(as.numeric(unlist(x)))
  do.call(rbind, lapply(x, function(r) as.numeric(unlist(r))))
}

test_that("rotation matrices and vector helpers match upstream", {
  o <- extras_oracle()$space_ops
  axis <- c(1, 2, 3)
  expect_equal(rotation_matrix(0.7, axis), ex_mat(o$rotation_matrix), tolerance = 1e-9)
  expect_equal(rotation_matrix(0.7, axis, homogeneous = TRUE), ex_mat(o$rotation_matrix_homogeneous), tolerance = 1e-9)
  expect_equal(rotation_matrix_transpose(0.7, axis), ex_mat(o$rotation_matrix_transpose), tolerance = 1e-9)
  expect_equal(rotation_matrix_transpose(0.7, c(0, 0, -2)), ex_mat(o$rotation_matrix_transpose_z), tolerance = 1e-9)
  q <- quaternion_from_angle_axis(0.7, axis)
  expect_equal(q, unlist(o$quat), tolerance = 1e-9)
  expect_equal(rotation_matrix_from_quaternion(q), ex_mat(o$rotation_matrix_from_quaternion), tolerance = 1e-9)
  expect_equal(do.call(rbind, rotation_matrix_transpose_from_quaternion(q)),
               ex_mat(o$rotation_matrix_transpose_from_quaternion), tolerance = 1e-9)
  expect_equal(norm_squared(axis), o$norm_squared)
  expect_equal(normalize_along_axis(rbind(c(3, 4, 0), c(0, 0, 0), c(1, 2, 2)), 2), ex_mat(o$normalize_along_axis), tolerance = 1e-9)
  # Upstream's argument names.
  expect_equal(midpoint(point1 = c(0, 2, 0), point2 = c(4, 0, 2)), unlist(o$midpoint))
  expect_equal(complex_to_R3(complex_num = 2 - 3i), unlist(o$complex_to_R3))
  expect_equal(normalize(vect = c(3, 4, 0)), unlist(o$normalize))
  expect_equal(normalize(vect = c(0, 0, 0), fall_back = c(0, 1, 0)), unlist(o$normalize_zero_fall_back))
})

test_that("array resizing helpers match upstream", {
  o <- extras_oracle()$iterables
  m <- ex_mat(o$m)
  v <- unlist(o$v)
  expect_equal(resize_array(m, 7), ex_mat(o$resize_array_grow))
  expect_equal(resize_array(m, 2), ex_mat(o$resize_array_shrink))
  expect_equal(resize_array(v, 6), unlist(o$resize_array_vector))
  expect_identical(resize_array(m, 4), m)
  expect_equal(resize_preserving_order(m, 7), ex_mat(o$resize_preserving_order_grow))
  expect_equal(resize_preserving_order(m, 3), ex_mat(o$resize_preserving_order_shrink))
  expect_equal(resize_preserving_order(matrix(0, 0, 3), 2), ex_mat(o$resize_preserving_order_empty))
  expect_equal(resize_with_interpolation(m, 6), ex_mat(o$resize_with_interpolation_grow), tolerance = 1e-9)
  expect_equal(resize_with_interpolation(m, 3), ex_mat(o$resize_with_interpolation_shrink), tolerance = 1e-9)
  expect_equal(resize_with_interpolation(v, 7), unlist(o$resize_with_interpolation_vector), tolerance = 1e-9)

  batches <- batch_by_property(c(1, 3, 5, 2, 4, 7, 6), function(x) x %% 2)
  expect_length(batches, length(o$batch_by_property))
  for (i in seq_along(batches)) {
    expect_equal(unlist(batches[[i]][[1]]), unlist(o$batch_by_property[[i]][[1]]))
    expect_equal(batches[[i]][[2]], o$batch_by_property[[i]][[2]])
  }
  expect_equal(uniq_chain(c(1, 2, 3), c(3, 4, 1), 5), unlist(o$uniq_chain))
  expect_identical(uniq_chain(), list())

  # A named list hashes the same in any order; an unnamed one does not.
  expect_identical(hash_obj(list(a = 1, b = list(2, 3))), hash_obj(list(b = list(2, 3), a = 1)))
  expect_false(identical(hash_obj(list(1, 2)), hash_obj(list(2, 1))))

  # VMobject$resize_points takes the resize function, as upstream.
  sq <- Square()
  n <- nrow(sq$points)
  sq$resize_points(n + 4)
  expect_equal(nrow(sq$points), n + 4)
  sq2 <- Square()
  sq2$resize_points(n + 4, resize_func = resize_preserving_order)
  expect_equal(sq2$points, resize_preserving_order(Square()$points, n + 4))
})

test_that("smooth handle helpers and the quadratic approximation match upstream", {
  o <- extras_oracle()$bezier
  for (nm in names(o$closed)) {
    h <- get_smooth_closed_cubic_bezier_handle_points(ex_mat(o$closed_anchors[[nm]]))
    expect_equal(unname(h$h1), ex_mat(o$closed[[nm]][[1]]), tolerance = 1e-9, info = nm)
    expect_equal(unname(h$h2), ex_mat(o$closed[[nm]][[2]]), tolerance = 1e-9, info = nm)
  }
  for (nm in names(o$open)) {
    h <- get_smooth_open_cubic_bezier_handle_points(ex_mat(o$open_anchors[[nm]]))
    expect_equal(unname(h$h1), ex_mat(o$open[[nm]][[1]]), tolerance = 1e-9, info = nm)
    expect_equal(unname(h$h2), ex_mat(o$open[[nm]][[2]]), tolerance = 1e-9, info = nm)
  }
  expect_equal(get_quadratic_approximation_of_cubic(c(0, 0, 0), c(1, 2, 0), c(3, 2, 0), c(4, 0, 0)),
               ex_mat(o$quadratic_single))
  expect_equal(get_quadratic_approximation_of_cubic(
    rbind(c(0, 0, 0), c(4, 0, 0)), rbind(c(1, 2, 0), c(5, -2, 0)),
    rbind(c(3, 2, 0), c(7, -2, 1)), rbind(c(4, 0, 0), c(8, 0, 0))), ex_mat(o$quadratic_many))
  expect_error(get_quadratic_approximation_of_cubic(c(0, 0, 0), rbind(c(1, 2, 0)), c(3, 2, 0), c(4, 0, 0)), "points or matrices")
})

test_that("the OpenGL matrix helpers match upstream", {
  o <- extras_oracle()$opengl
  expect_equal(orthographic_projection_matrix(), unlist(o$orthographic_flat), tolerance = 1e-9)
  expect_equal(orthographic_projection_matrix(width = 10, height = 4, near = 2, far = 30, format_ = FALSE),
               ex_mat(o$orthographic), tolerance = 1e-9)
  expect_equal(perspective_projection_matrix(), unlist(o$perspective_flat), tolerance = 1e-9)
  expect_equal(perspective_projection_matrix(width = 3, height = 2, near = 1, far = 40, format_ = FALSE),
               ex_mat(o$perspective), tolerance = 1e-9)
  expect_equal(translation_matrix(1, 2, 3), ex_mat(o$translation))
  expect_equal(x_rotation_matrix(0.3), ex_mat(o$x_rotation), tolerance = 1e-9)
  expect_equal(y_rotation_matrix(0.4), ex_mat(o$y_rotation), tolerance = 1e-9)
  expect_equal(z_rotation_matrix(0.5), ex_mat(o$z_rotation), tolerance = 1e-9)
  expect_equal(opengl_rotation_matrix(0.3, 0.4, 0.5), ex_mat(o$rotation), tolerance = 1e-9)
  expect_equal(rotate_in_place_matrix(c(1, -2, 0.5), 0.3, 0.4, 0.5), ex_mat(o$rotate_in_place), tolerance = 1e-9)
  expect_equal(scale_matrix(2.5), ex_mat(o$scale))
  expect_equal(view_matrix(), unlist(o$view_default), tolerance = 1e-9)
  expect_equal(view_matrix(translation = c(1, 2, 9), x_rotation = 0.3, y_rotation = 0.4, z_rotation = 0.5),
               unlist(o$view), tolerance = 1e-9)
  expect_equal(matrix_to_shader_input(matrix(0:15, 4, 4, byrow = TRUE)), unlist(o$matrix_to_shader_input))
})

test_that("color_to_rgba sets the opacity to 1 unless told otherwise", {
  o <- extras_oracle()$colors
  expect_equal(color_to_rgba("#FF000080"), unlist(o$color_to_rgba_hex_alpha))
  expect_equal(color_to_rgba("#FF000080", 0.3), unlist(o$color_to_rgba_alpha))
  mixed <- interpolate_color(rgba_to_color(c(0, 0, 0, 0)), WHITE, 0.5)
  expect_equal(color_to_rgba(mixed), unlist(o$color_to_rgba_interpolated))
  expect_equal(color_to_rgba(mixed, alpha = NULL), unlist(o$interpolate_alpha))
  expect_equal(hex_to_rgb(hex_code = "#336699"), unlist(o$hex_to_rgb))
})

test_that("family and parameter helpers behave as upstream", {
  a <- Square(); b <- Circle(); c <- Triangle()
  g <- VGroup(a, b)
  # A group holding a removed mobject is replaced by its remaining members.
  left <- restructure_list_to_exclude_certain_family_members(list(g, c), list(b))
  expect_length(left, 2)
  expect_identical(left[[1]], a)
  expect_identical(left[[2]], c)
  expect_length(restructure_list_to_exclude_certain_family_members(list(g, c), list(g)), 1)
  expect_length(extract_mobject_family_members(mobject_list = list(g, c)), 4)

  expect_equal(flatten_iterable_parameters(list(1, c(2, 3), list(4, 5))), list(1, 2, 3, 4, 5))
  flat <- flatten_iterable_parameters(list(a, list(b, c)))
  expect_length(flat, 3)
  expect_identical(flat[[3]], c)

  expect_match(add_version_before_extension("dir/a.png"), "^dir/a_manimR_v[0-9.]+\\.png$")

  dir <- withr_tempdir()
  writeLines("<svg/>", file.path(dir, "logo.svg"))
  old <- manim_config(assets_dir = dir)
  expect_equal(normalizePath(get_full_vector_image_path("logo")), normalizePath(file.path(dir, "logo.svg")))
  expect_error(get_full_vector_image_path("missing"), "could not find")
  do.call(manim_config, old["assets_dir"])
})

test_that("remove_invisible_chars drops the dots that stand for spaces", {
  txt <- Text("a b c", disable_ligatures = TRUE)
  n_dots <- sum(vapply(txt$submobjects, function(k) inherits(k, "Dot"), NA))
  expect_gt(n_dots, 0)
  vis <- remove_invisible_chars(txt)
  expect_length(vis$submobjects, length(txt$submobjects) - n_dots)
  line <- function(s) do.call(VGroup, Text(s, disable_ligatures = TRUE)$submobjects)
  lines <- VGroup(line("a b"), line("c d e"))
  per_line <- remove_invisible_chars(lines)
  expect_length(per_line$submobjects, 2)
  expect_length(per_line$submobjects[[2]]$submobjects, 3)
})

test_that("constructors take their arguments in upstream's order", {
  # VMobject(fill_color, fill_opacity, stroke_color, ...)
  v <- VMobject(RED, 0.4, BLUE)
  expect_equal(v$get_fill_color(), RED)
  expect_equal(v$get_fill_opacity(), 0.4)
  expect_equal(v$get_stroke_color(), BLUE)
  # The fill_color and stroke_color properties read and set the style.
  expect_equal(v$fill_color, RED)
  v$stroke_color <- GREEN
  expect_equal(v$get_stroke_color(), GREEN)
  expect_equal(v$copy()$stroke_color, GREEN)

  # Camera(background_image, frame_center, image_mode, n_channels, pixel_array_dtype, ...)
  cam <- Camera(NULL, c(1, 0, 0), "RGBA", 4, "uint16")
  expect_equal(cam$frame_center, c(1, 0, 0))
  expect_equal(cam$rgb_max_val, 65535)
  expect_s3_class(Camera(background = NULL), "Camera")
  expect_error(Camera(pixel_array_dtype = "float32"), "integer type")

  # TexTemplate(tex_compiler, description, ...)
  tpl <- TexTemplate("xelatex", "my template")
  expect_equal(tpl$description, "my template")
  expect_equal(tpl$output_format, ".dvi")

  # Scene(renderer, camera_class, ...); the camera scenes take camera_class first.
  expect_s3_class(Scene$new(NULL, MovingCameraClass)$camera, "MovingCamera")
  expect_s3_class(MovingCameraScene$new()$camera, "MovingCamera")
  expect_s3_class(ThreeDScene$new()$camera, "ThreeDCamera")
  expect_s3_class(ThreeDScene$new(ThreeDCameraClass, 0.2)$camera, "ThreeDCamera")

  expect_true(Annulus(mark_paths_closed = TRUE)$mark_paths_closed)
  expect_equal(AddClass$new(Square())$run_time, 0)
  expect_s3_class(Variable(1, "x", var_type = IntegerClass)$value, "Integer")
})

test_that("scenes and renderers take upstream's arguments", {
  sc <- Scene$new()
  sq <- Square()
  sc$add(sq)
  # get_moving_mobjects(*animations)
  expect_length(sc$get_moving_mobjects(FadeIn(sq)), 1)
  expect_length(sc$get_moving_mobjects(list(FadeIn(sq))), 1)
  # update_frame(ignore_skipping = FALSE) does nothing while skipping.
  r <- sc$renderer
  r$skip_animations <- TRUE
  r$close_device()
  r$update_frame(sc, ignore_skipping = FALSE)
  expect_null(r$device)
  r$update_frame(sc)
  expect_false(is.null(r$device))
  r$close_device()
})

test_that("ImplicitFunction traces the curve as upstream", {
  o <- extras_oracle()$implicit
  small <- list(x_range = c(-2, 2), y_range = c(-2, 2), min_depth = 3, max_quads = 100)
  circle <- function(x, y) x^2 + y^2 - 2
  corners <- do.call(ImplicitFunction, c(list(circle, use_smoothing = FALSE), small))
  expect_equal(corners$points, ex_mat(o$circle_points), tolerance = 1e-8)
  smooth <- do.call(ImplicitFunction, c(list(circle), small))
  expect_equal(smooth$points, ex_mat(o$circle_smooth_points), tolerance = 1e-8)

  same <- function(m, ref) {
    expect_equal(nrow(m$points), ref$n)
    expect_equal(colSums(m$points), unlist(ref$sum), tolerance = 1e-7)
    expect_equal(sum(abs(m$points)), ref$abs, tolerance = 1e-9)
    expect_equal(apply(m$points, 2, min), unlist(ref$min), tolerance = 1e-8)
    expect_equal(apply(m$points, 2, max), unlist(ref$max), tolerance = 1e-8)
  }
  same(ImplicitFunction(circle), o$circle)
  # An asymptote (x y = 0) is not a zero, and undefined values are skipped.
  same(ImplicitFunction(function(x, y) if (x * y != 0) 1 / (x * y) - 1 else NaN, x_range = c(-3, 3), y_range = c(-3, 3)),
       o$hyperbola)
  same(ImplicitFunction(function(x, y) (x^2 + y^2 - 1) * ((x - 3)^2 + y^2 - 0.5)), o$two_curves)
  same(ImplicitFunction(function(x, y) (x^2 + y^2)^2 - 4 * (x^2 - y^2), min_depth = 6, max_quads = 3000), o$lemniscate)
  same(ImplicitFunction(function(x, y) y - 0.3 * x - 0.1, use_smoothing = FALSE), o$line_open)
})

test_that("convex hulls have upstream's vertices and triangular faces", {
  o <- extras_oracle()$hulls
  rows <- function(m) m[do.call(order, as.data.frame(m)), , drop = FALSE]
  cloud <- ex_mat(o$cloud)
  hull <- ConvexHull3D(cloud)
  faces <- lapply(hull$faces_list, function(f) rows(hull$vertex_coords[f, , drop = FALSE]))
  key <- function(m) paste(format(round(t(m), 6), nsmall = 6), collapse = " ")
  ref <- vapply(o$cloud_faces, function(f) key(rows(ex_mat(f))), "")
  expect_setequal(vapply(faces, key, ""), ref)
  # Every face is counterclockwise seen from outside.
  center <- colMeans(hull$vertex_coords)
  outward <- vapply(hull$faces_list, function(f) {
    v <- hull$vertex_coords[f, ]
    sum(cross(v[2, ] - v[1, ], v[3, ] - v[1, ]) * (v[1, ] - center)) > 0
  }, NA)
  expect_true(all(outward))

  # A flat face through four points is two triangles, as upstream.
  cube <- as.matrix(expand.grid(c(0, 1), c(0, 1), c(0, 1)))
  cube_hull <- ConvexHull3D(rbind(cube, c(0.5, 0.5, 0.5)))
  expect_length(cube_hull$faces_list, o$cube_n_faces)
  expect_equal(sort(lengths(cube_hull$faces_list)), unlist(o$cube_face_sizes))
  expect_equal(nrow(cube_hull$vertex_coords), o$cube_n_vertices)
  expect_error(ConvexHull3D(c(0, 0, 0), c(1, 0, 0), c(0, 1, 0), c(1, 1, 0)), "do not span")

  flat <- cbind(ex_mat(o$flat), 0)
  hull2 <- ConvexHull(rbind(flat, c(0, 0, 0)))
  expect_equal(unname(rows(hull2$get_vertices())), rows(ex_mat(o$flat_vertices)))
  near <- ConvexHull(c(0, 0, 0), c(2, 0, 0), c(1, -1e-6, 0), c(1, 2, 0))
  expect_equal(unname(rows(near$get_vertices())), rows(ex_mat(o$near_edge_vertices)))
  expect_equal(nrow(ConvexHull(c(0, 0, 0), c(2, 0, 0), c(1, -1e-6, 0), c(1, 2, 0), tolerance = 1e-8)$get_vertices()), 4)
})

test_that("a numeric vector is one color wherever a color is taken", {
  gray <- c(0.5, 0.5, 0.5)
  expect_equal(Square(color = gray)$get_stroke_color(), "#7F7F7F")
  expect_equal(Square()$set_fill(gray, 1)$get_fill_color(), "#7F7F7F")
  expect_equal(Square()$set_color(c(0.2, 0.4, 0.6))$get_stroke_color(), "#336699")
  expect_equal(Square()$set_stroke(c(51, 102, 153))$get_stroke_color(), "#336699")
  # Several colors are a character vector or a list.
  expect_equal(nrow(Square()$set_fill(c(RED, BLUE), 1)$fill_rgbas), 2)
  expect_equal(nrow(Square()$set_fill(list(gray, BLUE, c(1, 0, 0)), 1)$fill_rgbas), 3)
  # A hex number, as upstream's ManimColor(0x00FF00).
  expect_equal(manim_color(0x00FF00), "#00FF00")
  expect_error(manim_color(c(0.5, 0.5)), "3 or 4 numbers")
})

test_that("the animate builder gives its animation with build()", {
  sq <- Square()
  anim <- sq$animate$shift(RIGHT)$build()
  expect_true(inherits(anim, "Animation"))
  expect_identical(anim$mobject, sq)
})

test_that("ReplacementTransform leaves one reference to the target", {
  tempconfig(list(dry_run = TRUE), {
    s <- Scene$new()
    a <- Circle()
    b <- Square()
    s$add(a, b)
    s$play(ReplacementTransform(a, b))
    expect_length(s$mobjects, 1)
    expect_identical(s$mobjects[[1]], b)

    s <- Scene$new()
    a <- Circle()
    b <- Square()
    g <- VGroup(a, b)
    s$add(g)
    s$play(ReplacementTransform(a, b))
    expect_length(g$submobjects, 1)
    expect_identical(g$submobjects[[1]], b)
  })
})

test_that("TeX environments keep their braces and arguments", {
  env <- function(e) unname(unlist(texcode_for_environment(e)))
  expect_equal(env("align*"), c("\\begin{align*}", "\\end{align*}"))
  expect_equal(env("{align*}"), c("\\begin{align*}", "\\end{align*}"))
  expect_equal(env("\\begin{align*}"), c("\\begin{align*}", "\\end{align*}"))
  expect_equal(env("{tabular}[t]{cccl}"), c("\\begin{tabular}[t]{cccl}", "\\end{tabular}"))
  expect_equal(env("\\begin{tabular}[t]{cccl}"), c("\\begin{tabular}[t]{cccl}", "\\end{tabular}"))
  expect_equal(env("tabular}{cccl"), c("\\begin{tabular}{cccl}", "\\end{tabular}"))
})

test_that("TexTemplate adds text as upstream and warns for a fixed body", {
  tpl <- TexTemplate()
  tpl$add_to_document("\\boldmath")
  expect_true(grepl("\\begin{document}\n\\boldmath\nYourTextHere", tpl$body(), fixed = TRUE))
  fixed <- TexTemplate()
  fixed$set_body("dummy")
  expect_warning(fixed$add_to_preamble("extra"), "fixed body")
  expect_warning(fixed$add_to_document("extra"), "fixed body")
  expect_equal(fixed$body(), "dummy")
})

test_that("TeX errors come with hints for missing packages and characters", {
  log <- tempfile()
  writeLines(c("! LaTeX Error: File `frcursive.sty' not found.", "",
               "! Package inputenc Error: Unicode character x (U+00E9)"), log)
  msg <- tex_error_lines(log)
  expect_match(msg, "You do not have package frcursive.sty installed.", fixed = TRUE)
  expect_match(msg, "does not support character U+00E9", fixed = TRUE)
  expect_match(tex_error_lines(tempfile()), "did not produce a log file")
})

test_that("submobjects are validated and inserted as upstream", {
  expect_error(VMobject()$add(VMobject(), Mobject()), "Only values of type VMobject.*index 2.*Group instead")
  expect_error(VMobject()$insert(1, Mobject()), "Only values of type VMobject")
  expect_error(VMobject()$add_to_back(Mobject()), "Only values of type VMobject")
  expect_error(VGroup()$add(Mobject()), "submobjects of VGroup")
  m <- Mobject()
  expect_error(m$add(m), "submobject of itself")
  expect_error(m$add_to_back(m), "submobject of itself")
  expect_length(m$submobjects, 0)

  kids <- function(parent) vapply(parent$submobjects, function(x) x$name, "")
  abc <- function() list(a = Mobject(name = "a"), b = Mobject(name = "b"), c = Mobject(name = "c"))
  k <- abc(); m <- Mobject(); m$add(k$b); m$add_to_back(k$c, k$a, k$c)
  expect_equal(kids(m), c("a", "c", "b"))
  k <- abc(); m <- Mobject(); m$add(k$b); m$add(k$c, k$a, k$c)
  expect_equal(kids(m), c("b", "a", "c"))
  # insert() counts from 1; negative positions count from the end.
  for (case in list(list(1, c("c", "a", "b")), list(2, c("a", "c", "b")), list(3, c("a", "b", "c")),
                    list(9, c("a", "b", "c")), list(-1, c("a", "c", "b")), list(-5, c("c", "a", "b")))) {
    k <- abc(); m <- Mobject(); m$add(k$a, k$b); m$insert(case[[1]], k$c)
    expect_equal(kids(m), case[[2]])
  }
  # A submobject that is inserted again moves.
  k <- abc(); m <- Mobject(); m$add(k$a, k$b, k$c); m$insert(1, k$c)
  expect_equal(kids(m), c("c", "a", "b"))
  m$add(k$c)
  expect_equal(kids(m), c("a", "b", "c"))
})

test_that("angle_of_vector takes one vector per column", {
  expect_equal(angle_of_vector(matrix(c(1, 0, 0, 1, -1, 0), nrow = 2)), c(0, pi / 2, pi))
  expect_equal(angle_of_vector(c(0, 1, 0)), pi / 2)
  expect_error(angle_of_vector(matrix(c(1, 0, -1), nrow = 1)), "correct dimensions")
})

test_that("colors given as numbers follow upstream", {
  expect_equal(color_to_rgb(0xFF0000), c(1, 0, 0))
  expect_equal(color_to_rgb(16711680L), c(1, 0, 0))
  expect_equal(color_to_rgb(0), c(0, 0, 0))
  expect_equal(color_to_rgb(rgb_to_color(c(255L, 128L, 0L))), c(1, 128 / 255, 0))
  expect_equal(color_to_rgb(rgb_to_color(c(0.2, 0.4, 0.6))), c(0.2, 0.4, 0.6))
  expect_equal(ManimColor(rgba_to_color(c(255L, 0L, 0L, 51L)))$to_rgba(), c(1, 0, 0, 0.2))
  expect_equal(invert_color(ManimColor("#FF0000", alpha = 0.3))$to_rgba(), c(0, 1, 1, 0.3))
})

test_that("point equality handles infinite and missing coordinates", {
  v <- VMobject()
  expect_false(v$consider_points_equals_2d(c(NaN, 0), c(NaN, 0)))
  expect_true(v$consider_points_equals_2d(c(Inf, 0), c(Inf, 0)))
  expect_false(v$consider_points_equals_2d(c(Inf, 0), c(-Inf, 0)))
  expect_false(v$consider_points_equals_2d(c(1, NaN), c(1, 0)))
  expect_true(v$consider_points_equals_2d(c(1, Inf), c(1, Inf)))
  expect_false(v$consider_points_equals_2d(c(1, Inf), c(1, 5)))
  expect_true(v$consider_points_equals_2d(c(1, 2), c(1, 2 + 1e-9)))
  expect_false(v$consider_points_equals(c(NaN, 0, 0), c(NaN, 0, 0)))
  expect_true(v$consider_points_equals(c(Inf, 0, 0), c(Inf, 0, 0)))
})

test_that("line_intersection and Angle need lines in the xy-plane", {
  expect_error(line_intersection(rbind(c(0, 0, 3), c(3, 3, 3)), rbind(c(0, 3, 3), c(3, 0, 3))), "xy-plane")
  expect_error(Angle(Line(c(0, 0, 1), c(1, 0, 1)), Line(c(0, 0, 1), c(0, 1, 1))), "xy-plane")
  # Parallel lines in the plane give an empty angle.
  flat <- Angle(Line(UP, UP + RIGHT), Line(DOWN, DOWN + RIGHT))
  expect_false(flat$has_points())
  expect_equal(flat$get_value(), 0)
})

test_that("camera frame properties follow the frame", {
  cam <- MovingCamera()
  cam$frame$set(width = 22)
  expect_equal(cam$frame_width, 22)
  cam$frame_width <- 10
  cam$frame_center <- c(1, 2, 0)
  expect_equal(cam$frame$width, 10)
  expect_equal(cam$frame$get_center(), c(1, 2, 0))
  expect_equal(cam$frame_height, cam$frame$height)
  plain <- Camera()
  plain$frame_width <- 10
  expect_equal(plain$get_frame_width(), 10)
  cam3 <- ThreeDCamera()
  cam3$frame_center <- c(2, 3, 0)
  expect_equal(cam3$get_frame_center(), c(2, 3, 0))
})

test_that("turn_animation_into_updater keeps the elapsed time on the animation", {
  m <- Circle()
  a <- FadeIn(m, run_time = 2)
  turn_animation_into_updater(a, delay = 1)
  expect_equal(a$total_time, -1)
  m$update(0.5)
  expect_equal(a$total_time, -0.5)
})

test_that("the OpenGL rectangles and the surface group exist", {
  expect_true(inherits(OpenGLRectangle(width = 3), "Rectangle"))
  expect_equal(OpenGLSquare(side_length = 3)$width, 3)
  expect_true(inherits(OpenGLRoundedRectangle(), "RoundedRectangle"))
  g <- OpenGLSurfaceGroup(Surface(function(u, v) c(u, v, 0), resolution = 2),
                          Surface(function(u, v) c(u, v, 1), resolution = 2))
  expect_true(inherits(g, "OpenGLSurface"))
  expect_length(g$submobjects, 2)
})

test_that("SVG import reads styles and paths as upstream", {
  cases <- extras_oracle()$svg
  hex <- function(rgbas) toupper(rgb_hex(rgbas[1, 1:3]))
  for (name in names(cases)) {
    e <- cases[[name]]
    f <- tempfile(fileext = ".svg")
    writeLines(e$svg, f)
    m <- SVGMobject(f, use_svg_cache = FALSE)
    expect_equal(m$width, e$width, tolerance = 1e-6, info = name)
    expect_length(m$submobjects, length(e$members))
    for (i in seq_along(e$members)) {
      x <- m$submobjects[[i]]
      w <- e$members[[i]]
      info <- paste(name, i)
      expect_equal(nrow(x$points), w$n, info = info)
      expect_equal(unname(colSums(x$points)), unlist(w$sum), tolerance = 1e-6, info = info)
      expect_equal(sum(abs(x$points)), w$abs, tolerance = 1e-6, info = info)
      expect_identical(hex(x$fill_rgbas), w$fill, info = info)
      expect_identical(hex(x$stroke_rgbas), w$stroke, info = info)
      expect_equal(x$fill_rgbas[1, 4], w$fill_opacity, tolerance = 1e-7, info = info)
      expect_equal(x$stroke_rgbas[1, 4], w$stroke_opacity, tolerance = 1e-7, info = info)
      expect_equal(x$get_stroke_width(), w$stroke_width, tolerance = 1e-7, info = info)
    }
  }
})

test_that("an SVGMobject takes its own color before its shapes are imported", {
  e <- extras_oracle()$svg_container
  f <- tempfile(fileext = ".svg")
  writeLines('<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10" fill="#FFFF00"/></svg>', f)
  own <- function(m) {
    list(fill = toupper(m$get_fill_color()), stroke = toupper(m$get_stroke_color()), stroke_width = m$get_stroke_width(),
         child_fill = toupper(m$submobjects[[1]]$get_fill_color()))
  }
  expect_equal(own(SVGMobject(f, use_svg_cache = FALSE)), e$plain)
  expect_equal(own(SVGMobject(f, color = RED, use_svg_cache = FALSE)), e$color)
  expect_equal(own(SVGMobject(f, fill_color = BLUE, use_svg_cache = FALSE)), e$fill_color)
})

test_that("markup with an unknown or unbalanced tag is an error", {
  expect_error(MarkupText("<invalidtag>foo</invalidtag>"), "Unknown tag 'invalidtag'")
  expect_error(MarkupText("<b>foo"))
  expect_s3_class(MarkupText('<span foreground="red">a</span><gradient from="RED" to="YELLOW">b</gradient>'), "MarkupText")
})

test_that("polylabel returns the size of the cell of its pole", {
  ring <- rbind(c(0, 0), c(4, 0), c(4, 4), c(0, 4), c(0, 0))
  hole <- rbind(c(1, 1), c(1, 3), c(3, 3), c(3, 1), c(1, 1))
  pole <- polylabel(list(ring), precision = 0.01)
  expect_equal(pole$c, c(2, 2), tolerance = 0.05)
  expect_lte(pole$h, 0.01)
  ringed <- polylabel(list(ring, hole), precision = 0.01)
  expect_lte(ringed$h, 0.01)
  expect_gte(ringed$d, 0)
  # The pole lies on a diagonal, as far from the outer corner's sides as from the hole's corner.
  expect_equal(ringed$d, 2 - sqrt(2), tolerance = 0.02)
})

test_that("a missing system-ui font does not warn", {
  expect_true(font_available("System-ui"))
  expect_false(font_available("Manim!Manim!Manim!"))
})

test_that("mob[[i]] <- value with a position replaces a group member", {
  g <- VGroup(Square(), Circle())
  d <- Dot()
  g[[1]] <- d
  expect_identical(g$submobjects[[1]], d)
  expect_length(g$submobjects, 2)
  g[["name"]] <- "renamed"
  expect_identical(g$name, "renamed")
})
