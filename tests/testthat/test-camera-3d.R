test_that("MovingCamera follows its frame", {
  cam <- MovingCameraClass$new()
  expect_equal(cam$get_frame_height(), cfg("frame_height"))
  expect_equal(cam$get_frame_width(), cam$frame_width)
  expect_equal(cam$get_frame_center(), ORIGIN)
  cam$frame$scale(0.5)$move_to(c(1, 2, 0))
  expect_equal(cam$get_frame_height(), cfg("frame_height") / 2)
  expect_equal(cam$get_frame_center(), c(1, 2, 0))
  expect_equal(cam$px_per_unit(), cam$pixel_width / cam$get_frame_width())
})

test_that("MovingCamera auto_zoom fits mobjects", {
  cam <- MovingCameraClass$new()
  sq <- Square(side_length = 2)$shift(3 * RIGHT)
  cam$auto_zoom(list(sq, Dot(3 * RIGHT + UP)), margin = 0, animate = FALSE)
  # The dot (radius 0.08) pokes out of the top of the square.
  expect_equal(cam$get_frame_center()[1:2], c(3, 0.04))
  expect_equal(cam$get_frame_height(), 2.08, tolerance = 1e-6)
  expect_s3_class(cam$auto_zoom(sq), "manim_animation_builder")
  expect_error(cam$auto_zoom(list(cam$frame), animate = FALSE), "bounding box")
})

test_that("MovingCameraScene treats everything as moving when the frame moves", {
  scene <- MovingCameraScene$new()
  a <- Square()
  b <- Circle()
  scene$add(a, b)
  scene$add(scene$camera$frame)
  moving <- scene$get_moving_mobjects(list(Transform(scene$camera$frame, scene$camera$frame$copy())))
  ids <- vapply(moving, function(m) m$mob_id, "")
  expect_true(all(c(a$mob_id, b$mob_id) %in% ids))
})

test_that("a rotated camera display keeps its rotation", {
  sub <- MovingCameraClass$new(background_opacity = 1, background_color = BLACK)
  sub$frame$stretch_to_fit_width(4)
  sub$frame$stretch_to_fit_height(2)
  sub$frame$move_to(c(10, 0, 0))
  imfc <- ImageMobjectFromCamera(sub)
  imfc$stretch_to_fit_width(4)
  imfc$stretch_to_fit_height(2)
  imfc$rotate(PI / 2)$move_to(c(2, 0, 0))
  main <- MultiCameraClass$new(image_mobjects_from_cameras = list(imfc), pixel_width = 320, pixel_height = 180)
  cap <- ragg::agg_capture(width = 320, height = 180, units = "px", res = 96)
  dev <- grDevices::dev.cur()
  on.exit(grDevices::dev.off(dev), add = TRUE)
  grid::grid.newpage(recording = FALSE)
  # The dot is 1 right and 0.5 up of the zoomed frame's center.
  main$draw_frame(list(Dot(c(11, 0.5, 0), radius = 0.2, color = RED), imfc))
  img <- cap(native = FALSE)
  px <- colMeans(which(img == RED, arr.ind = TRUE))
  per_unit <- 320 / main$get_frame_width()
  # Turned a quarter turn about the display center (2, 0), it lands at (1.5, 1).
  expect_equal(c((px[["col"]] - 160.5) / per_unit, (90.5 - px[["row"]]) / per_unit), c(1.5, 1), tolerance = 0.02)
  # The sub camera gets the display's own (unrotated) pixel size.
  expect_equal(c(sub$pixel_width, sub$pixel_height), c(90, 45), tolerance = 1.5 / 45)
})

test_that("ThreeDCamera default view is the identity projection", {
  cam <- ThreeDCameraClass$new()
  expect_equal(cam$get_rotation_matrix(), diag(3), tolerance = 1e-12)
  p <- cam$project_points(rbind(c(1, 2, 0), c(1, 1, 1)))
  expect_equal(p[1, ], c(1, 2))
  expect_equal(p[2, ], c(1, 1) * 20 / 19)
  cam$set_zoom(2)
  expect_equal(cam$project_points(rbind(c(1, 2, 0)))[1, ], c(2, 4))
})

test_that("ThreeDCamera rotation matches phi, theta, gamma", {
  cam <- ThreeDCameraClass$new(phi = 75 * DEGREES, theta = 30 * DEGREES)
  rot <- cam$get_rotation_matrix()
  expected <- rotation_matrix(-75 * DEGREES, RIGHT) %*% rotation_about_z(-120 * DEGREES)
  expect_equal(rot, expected, tolerance = 1e-12)
  expect_equal(drop(rot %*% RIGHT), c(-0.5, -cos(75 * DEGREES) * sqrt(3) / 2, sin(75 * DEGREES) * sqrt(3) / 2),
               tolerance = 1e-9)
})

test_that("frame_center lands at the screen center and fixed mobjects ignore the camera", {
  cam <- ThreeDCameraClass$new(phi = 60 * DEGREES, theta = 10 * DEGREES)
  cam$set_frame_center(c(1, 2, 0.5))
  cam$reset_rotation_matrix()
  # The view is centered on the frame center, so projecting it back must give it.
  expect_equal(cam$project_points(rbind(c(1, 2, 0.5)))[1, ], c(1, 2))
  title <- Square()$shift(3 * UP)
  cam$add_fixed_in_frame_mobjects(title)
  pts <- cam$project_points(title$points, title)
  expect_equal(pts, sweep(title$points[, 1:2], 2, c(1, 2), "+"))
  label <- Dot(c(2, 0, 1))
  cam$add_fixed_orientation_mobjects(label)
  lp <- cam$project_points(label$points, label)
  center <- label$get_center()
  shift <- cam$project_point(center) - center
  expect_equal(lp, sweep(label$points, 2, shift, "+")[, 1:2] + rep(c(1, 2), each = nrow(lp)))
  cam$remove_fixed_in_frame_mobjects(title)
  expect_false(title$mob_id %in% cam$fixed_in_frame_mobjects)
})

test_that("ThreeDCamera sorts shaded mobjects by depth and shades them", {
  cam <- ThreeDCameraClass$new()
  near <- Square(shade_in_3d = TRUE)$shift(OUT)
  far <- Square(shade_in_3d = TRUE)$shift(IN)
  flat <- Circle()
  order <- cam$get_mobjects_to_display(list(near, flat, far))
  expect_identical(vapply(order, function(m) m$mob_id, ""), c(far$mob_id, near$mob_id, flat$mob_id))
  near$set_fill(BLUE, opacity = 1)
  shaded <- cam$get_fill_rgbas(near)
  expect_equal(nrow(shaded), 2)
  expect_false(isTRUE(all.equal(shaded[1, 1:3], color_to_rgb(BLUE))))
  expect_equal(nrow(cam$get_fill_rgbas(flat)), 1)
  cam$should_apply_shading <- FALSE
  expect_equal(cam$get_fill_rgbas(near), near$get_fill_rgbas())
})

test_that("get_shaded_rgb and the 3D corner helpers follow upstream", {
  rgb <- c(0.2, 0.3, 0.4)
  expect_equal(get_shaded_rgb(rgb, ORIGIN, OUT, 10 * OUT), rgb + 0.5)
  expect_equal(get_shaded_rgb(rgb, ORIGIN, IN, 10 * OUT), rgb - 0.25)
  face <- ThreeDVMobject()
  face$set_points_as_corners(rbind(c(0, 0, 0), c(1, 0, 0), c(1, 1, 0), c(0, 1, 0), c(0, 0, 0)))
  expect_equal(get_3d_vmob_end_corner_index(face), 6)
  expect_equal(get_3d_vmob_start_corner_unit_normal(face), OUT)
  expect_equal(get_3d_vmob_end_corner(face), face$points[7, ])
  expect_equal(get_unit_normal(c(0, 0, 0), c(0, 0, 0)), DOWN)
})

test_that("Surface, Sphere and Torus have the right faces and geometry", {
  s <- Sphere(center = c(1, 0, 0), radius = 2, resolution = c(6, 4))
  expect_length(s$submobjects, 24)
  anchors <- do.call(rbind, lapply(s$submobjects, function(f) f$get_anchors()))
  expect_equal(sqrt(rowSums(sweep(anchors, 2, c(1, 0, 0))^2)), rep(2, nrow(anchors)), tolerance = 1e-6)
  expect_true(all(vapply(s$submobjects, function(f) isTRUE(f$shade_in_3d), logical(1))))
  cols <- vapply(s$submobjects, function(f) f$get_fill_color(), "")
  expect_equal(unique(cols), c(BLUE_D, BLUE_E))
  surf <- Surface(function(u, v) c(u, v, u * v), u_range = c(0, 1), v_range = c(0, 2), resolution = c(2, 3),
                  checkerboard_colors = FALSE, fill_color = RED)
  expect_length(surf$submobjects, 6)
  expect_equal(surf$depth, 2, tolerance = 1e-6)
  expect_equal(unique(vapply(surf$submobjects, function(f) f$get_fill_color(), "")), RED)
  tor <- Torus(major_radius = 3, minor_radius = 1, resolution = c(8, 8))
  expect_equal(tor$width, 8, tolerance = 1e-6)
  expect_equal(tor$depth, 2, tolerance = 0.2)
})

test_that("set_fill_by_value colors faces by a coordinate", {
  axes <- list(x_range = c(0, 1), y_range = c(0, 1), z_range = c(-1, 1), point_to_coords = function(p) p)
  surf <- Surface(function(u, v) c(u, v, u), u_range = c(0, 1), v_range = c(0, 1), resolution = c(4, 1))
  surf$set_fill_by_value(axes = axes, colorscale = c(RED, GREEN), axis = 1)
  f1 <- surf$submobjects[[1]]
  expect_equal(f1$get_fill_color(), manim_color(interpolate_color(RED, GREEN, f1$get_midpoint()[1])))
  surf$set_fill_by_value(axes = axes, colorscale = list(list(BLUE, 0.3), list(YELLOW, 0.6)), axis = 1)
  expect_equal(surf$submobjects[[1]]$get_fill_color(), manim_color(BLUE))
  expect_equal(surf$submobjects[[4]]$get_fill_color(), manim_color(YELLOW))
  expect_warning(surf$set_fill_by_value(axes = axes), "colorscale")
})

test_that("Cube, Prism, Cone, Cylinder, Line3D and Arrow3D are built right", {
  cube <- Cube(side_length = 3)
  expect_length(cube$submobjects, 6)
  expect_equal(c(cube$width, cube$height, cube$depth), c(3, 3, 3), tolerance = 1e-9)
  expect_equal(cube$submobjects[[1]]$get_fill_opacity(), 0.75)
  prism <- Prism(dimensions = c(1, 2, 3))
  expect_equal(c(prism$width, prism$height, prism$depth), c(1, 2, 3), tolerance = 1e-9)
  cyl <- Cylinder(radius = 1, height = 2, direction = X_AXIS, resolution = c(4, 8))
  expect_equal(cyl$width, 2, tolerance = 1e-6)
  expect_equal(cyl$get_direction(), X_AXIS)
  cone <- Cone(base_radius = 1, height = 2, direction = Z_AXIS, resolution = 4)
  expect_equal(cone$get_start(), c(0, 0, -2), tolerance = 1e-9)
  expect_equal(cone$get_end(), c(0, 0, 0), tolerance = 1e-9)
  line <- Line3D(start = ORIGIN, end = c(2, 2, 2), resolution = 6)
  expect_equal(line$get_start(), ORIGIN)
  expect_equal(line$get_end(), c(2, 2, 2))
  expect_equal(line$get_center(), c(1, 1, 1), tolerance = 0.02)
  par <- Line3D_parallel_to(line, point = RIGHT, length = 4)
  expect_equal(normalize(par$vect), -normalize(line$vect), tolerance = 1e-9)
  arrow <- Arrow3D(start = ORIGIN, end = c(0, 0, 2), resolution = 6)
  expect_equal(arrow$get_end(), c(0, 0, 2))
  expect_equal(arrow$get_zenith()[3], 2, tolerance = 1e-6)
  expect_true(inherits(arrow$cone, "Cone"))
})

test_that("polyhedra have the right faces, edges and vertices", {
  tet <- Tetrahedron(edge_length = 2)
  expect_length(tet$faces$submobjects, 4)
  expect_length(tet$graph$edges, 6)
  v <- tet$vertex_coords
  expect_equal(get_norm(v[1, ] - v[2, ]), 2)
  oct <- Octahedron()
  expect_length(oct$faces$submobjects, 8)
  expect_length(oct$graph$edges, 12)
  expect_length(Icosahedron()$faces$submobjects, 20)
  dod <- Dodecahedron()
  expect_length(dod$graph$edges, 30)
  expect_identical(oct$graph[1]$mob_id, oct$graph$vertices[[1]]$mob_id)
  oct$graph$vertices[[5]]$shift(OUT)
  oct$update(0)
  expect_equal(max(oct$faces$submobjects[[1]]$points[, 3]), sqrt(2) / 2 + 1, tolerance = 1e-9)
  cube_pts <- as.matrix(expand.grid(c(0, 1), c(0, 1), c(0, 1)))
  hull <- ConvexHull3D(rbind(cube_pts, c(0.5, 0.5, 0.5)))
  expect_equal(nrow(hull$vertex_coords), 8)
  expect_equal(sort(lengths(hull$faces_list)), rep(4, 6))
})

test_that("ThreeDScene camera controls and ambient rotation", {
  scene <- ThreeDScene$new()
  scene$set_camera_orientation(phi = 75 * DEGREES, theta = 30 * DEGREES, zoom = 2, frame_center = c(1, 0, 0))
  cam <- scene$camera
  expect_equal(c(cam$get_phi(), cam$get_theta(), cam$get_zoom()), c(75, 30, 2) * c(DEGREES, DEGREES, 1))
  expect_equal(cam$get_frame_center(), c(1, 0, 0))
  sq <- Square()
  scene$add(sq)
  scene$begin_ambient_camera_rotation(rate = 0.5)
  expect_true(any(vapply(scene$mobjects, function(m) identical(m$mob_id, cam$theta_tracker$mob_id), logical(1))))
  moving <- scene$get_moving_mobjects(list())
  expect_true(sq$mob_id %in% vapply(moving, function(m) m$mob_id, ""))
  scene$update_mobjects(1)
  expect_equal(cam$get_theta(), 30 * DEGREES + 0.5)
  scene$stop_ambient_camera_rotation()
  expect_length(cam$theta_tracker$updaters, 0)
  expect_error(scene$begin_ambient_camera_rotation(about = "zoom"), "Invalid")
  scene$add_fixed_in_frame_mobjects(sq)
  expect_true(sq$mob_id %in% cam$fixed_in_frame_mobjects)
})

# Reference data dumped from Python manim by data-raw/upstream_oracle_3d.py.
read_oracle_3d <- function() {
  skip_if_not_installed("jsonlite")
  jsonlite::fromJSON(test_path("fixtures", "upstream_oracle_3d.json"), simplifyVector = FALSE)
}

oracle_mat <- function(x) if (length(x) == 0) matrix(0, 0, 3) else do.call(rbind, lapply(x, unlist))

expect_oracle_family <- function(mob, ref, tol = 1e-8) {
  fam <- mob$family_members_with_points()
  expect_equal(length(fam), length(ref))
  for (i in seq_along(ref)) expect_equal(unname(fam[[i]]$points), oracle_mat(ref[[i]]), tolerance = tol)
}

test_that("3D mobjects match upstream points", {
  o <- read_oracle_3d()
  expect_oracle_family(Sphere(center = c(1, 0, 0), radius = 1.5, resolution = c(6, 4)), o$sphere)
  expect_oracle_family(Cube(side_length = 3), o$cube)
  expect_oracle_family(Prism(dimensions = c(1, 2, 3)), o$prism)
  expect_oracle_family(Surface(function(u, v) c(u, v, u * v), u_range = c(0, 1), v_range = c(0, 2),
                               resolution = c(2, 3)), o$surface)
  expect_oracle_family(Torus(resolution = c(6, 6)), o$torus)
  expect_oracle_family(Cone(base_radius = 1, height = 2, direction = c(1, 1, 2), resolution = 4), o$cone)
  expect_oracle_family(Cylinder(radius = 1, height = 2, direction = X_AXIS, resolution = c(4, 8)), o$cylinder)
  expect_oracle_family(Line3D(ORIGIN, c(2, 1, 2), resolution = 6), o$line3d)
  expect_oracle_family(Arrow3D(ORIGIN, c(0, 1, 2), resolution = 6), o$arrow3d)
  expect_oracle_family(Dot3D(c(1, 2, 3), radius = 0.1), o$dot3d)
})

test_that("polyhedra match upstream faces and vertices", {
  o <- read_oracle_3d()
  solids <- list(tetrahedron = Tetrahedron, octahedron = Octahedron, icosahedron = Icosahedron,
                 dodecahedron = Dodecahedron)
  for (nm in names(solids)) {
    p <- solids[[nm]](edge_length = 2)
    expect_oracle_family(p$faces, o[[nm]]$faces)
    vc <- do.call(rbind, lapply(p$graph$vertices, function(v) v$get_center()))
    expect_equal(unname(vc), oracle_mat(o[[nm]]$vertices), tolerance = 1e-8)
  }
})

test_that("ThreeDCamera rotation, projection, depth order and shading match upstream", {
  o <- read_oracle_3d()
  probe <- rbind(c(1, 2, 0), c(0, 0, 1), c(-1.5, 0.5, 2), c(3, -1, -2))
  cams <- list(
    default = list(),
    angled = list(phi = 75 * DEGREES, theta = 30 * DEGREES),
    full = list(phi = 60 * DEGREES, theta = -45 * DEGREES, gamma = 0.3, zoom = 2, focal_distance = 10,
                frame_center = c(1, 2, 0.5)),
    exponential = list(phi = 50 * DEGREES, theta = 20 * DEGREES, exponential_projection = TRUE)
  )
  for (nm in names(cams)) {
    cam <- do.call(ThreeDCameraClass$new, cams[[nm]])
    expect_equal(cam$get_rotation_matrix(), oracle_mat(o$camera[[nm]]$rotation), tolerance = 1e-8)
    expect_equal(cam$project_3d_points(probe), oracle_mat(o$camera[[nm]]$projected), tolerance = 1e-8)
  }
  cam <- ThreeDCameraClass$new(phi = 75 * DEGREES, theta = 30 * DEGREES)
  sphere <- Sphere(resolution = c(6, 4))
  faces <- sphere$family_members_with_points()
  ids <- vapply(faces, function(m) m$mob_id, "")
  shown <- vapply(cam$get_mobjects_to_display(list(sphere)), function(m) m$mob_id, "")
  expect_equal(match(shown, ids) - 1, unlist(o$sphere_display_order))
  for (i in 1:6) expect_equal(cam$get_fill_rgbas(faces[[i]]), oracle_mat(o$sphere_fill_rgbas[[i]]), tolerance = 1e-8)
  for (i in seq_along(faces)) {
    normals <- rbind(get_3d_vmob_start_corner_unit_normal(faces[[i]]), get_3d_vmob_end_corner_unit_normal(faces[[i]]))
    expect_equal(normals, oracle_mat(o$sphere_normals[[i]]), tolerance = 1e-8)
  }
  sq <- Square(shade_in_3d = TRUE)$set_fill(BLUE, opacity = 1)$rotate(0.7, axis = RIGHT)$shift(OUT)
  expect_equal(cam$get_fill_rgbas(sq), oracle_mat(o$square_fill_rgbas), tolerance = 1e-8)
})

test_that("mirrored camera displays are drawn mirrored", {
  subcam <- MovingCamera(frame = Rectangle(width = 4, height = 4), pixel_width = 180, pixel_height = 180)
  im <- ImageMobjectFromCamera(subcam)$stretch_to_fit_width(3)$stretch_to_fit_height(3)$move_to(4 * RIGHT)
  cam <- MultiCamera(image_mobjects_from_cameras = list(im), pixel_width = 320, pixel_height = 180)
  colors <- c(RED, BLUE, GREEN, YELLOW)
  pos <- list(LEFT + UP, RIGHT + UP, LEFT + DOWN, RIGHT + DOWN)
  mobs <- c(lapply(1:4, function(i) {
    Square(side_length = 1, fill_color = colors[i], fill_opacity = 1, stroke_width = 0)$move_to(pos[[i]])
  }), list(im))
  draw <- function() {
    cap <- ragg::agg_capture(width = 320, height = 180, background = "black")
    on.exit(grDevices::dev.off())
    cam$draw_frame(mobs)
    a <- manimR:::native_raster_to_array(cap(native = TRUE))
    vapply(list(c(3.25, 0.75), c(4.75, 0.75), c(3.25, -0.75), c(4.75, -0.75)), function(p) {
      row <- floor((4 - p[2]) / 8 * 180) + 1
      col <- floor((p[1] + cam$get_frame_width() / 2) / cam$get_frame_width() * 320) + 1
      paste(a[row, col, 1:3], collapse = ",")
    }, "")
  }
  before <- draw()
  im$flip(UP)
  expect_equal(draw(), before[c(2, 1, 4, 3)])
})

test_that("split screen cameras keep still mobjects under moving ones", {
  cam <- SplitScreenCamera(Camera(), Camera(), pixel_width = 320, pixel_height = 90)
  still <- Circle(radius = 1, fill_color = RED, fill_opacity = 1, stroke_width = 0)$shift(2 * LEFT)
  moving <- Square(side_length = 1, fill_color = BLUE, fill_opacity = 1, stroke_width = 0)$shift(2 * RIGHT)
  grab <- function(f) {
    cap <- ragg::agg_capture(width = 320, height = 90, background = "black")
    on.exit(grDevices::dev.off())
    f()
    cap(native = TRUE)
  }
  static <- grab(function() cam$draw_frame(list(still)))
  frame <- grab(function() cam$draw_frame(list(moving), background_raster = static))
  full <- grab(function() cam$draw_frame(list(still, moving)))
  expect_equal(manimR:::native_raster_to_array(frame), manimR:::native_raster_to_array(full))
})
