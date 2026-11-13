test_that("ImageMobject from an array has upstream size and corners", {
  arr <- matrix(c(0, 100, 30, 200, 255, 0, 5, 33), 2, byrow = TRUE)
  img <- ImageMobject(arr)
  expect_equal(dim(img$pixel_array), c(2, 4, 4))
  expect_equal(img$pixel_array[, , 1], arr)
  expect_true(all(img$pixel_array[, , 4] == 255))
  expect_equal(img$height, 2 / 1080 * cfg("frame_height"))
  expect_equal(img$width, 2 * img$height)
  expect_equal(img$get_center(), ORIGIN)
  # UL, UR, DL, DR
  expect_true(img$points[1, 1] < img$points[2, 1] && img$points[1, 2] > img$points[3, 2])
  img$height <- 7
  expect_equal(c(img$width, img$height), c(14, 7))
  r <- img$get_raster()
  expect_equal(dim(r), c(2, 4, 4))
  expect_true(all(r >= 0 & r <= 1))
  expect_silent(grid::rasterGrob(r))
})

test_that("ImageMobject reads PNG files and inverts", {
  f <- tempfile(fileext = ".png")
  rgb <- array(0, c(3, 5, 3))
  rgb[, , 1] <- 1
  png::writePNG(rgb, f)
  img <- ImageMobject(f, scale_to_resolution = 3)
  expect_equal(img$height, cfg("frame_height"))
  expect_equal(img$pixel_array[1, 1, ], c(255, 0, 0, 255))
  inv <- ImageMobject(sub("\\.png$", "", f), invert = TRUE)
  expect_equal(inv$pixel_array[1, 1, 1:3], c(0, 255, 255))
  expect_error(ImageMobject(tempfile()), "not found")
})

test_that("ImageMobject takes rasters and converts files to image_mode like PIL", {
  a <- array(0, c(2, 2, 4))
  a[1, 1, ] <- c(255, 0, 0, 128)
  a[1, 2, ] <- c(0, 255, 0, 255)
  a[2, 1, ] <- c(0, 0, 255, 0)
  a[2, 2, ] <- c(10, 20, 30, 40)
  f <- tempfile(fileext = ".png")
  png::writePNG(a / 255, f)
  expect_equal(ImageMobject(f)$pixel_array, a)
  # References from manim 0.20.1 (PIL Image.convert).
  rgb <- ImageMobject(f, image_mode = "RGB")$pixel_array
  expect_equal(rgb[, , 1:3], a[, , 1:3])
  expect_equal(rgb[, , 4], matrix(255, 2, 2))
  l <- ImageMobject(f, image_mode = "L")$pixel_array
  for (k in 1:3) expect_equal(l[, , k], rbind(c(76, 150), c(29, 18)))
  expect_equal(l[, , 4], matrix(255, 2, 2))
  expect_error(ImageMobject(f, image_mode = "CMYK"), "image_mode")
  # Rasters are not file names.
  expect_equal(ImageMobject(png::readPNG(f, native = TRUE))$pixel_array, a)
  expect_equal(ImageMobject(grDevices::as.raster(png::readPNG(f)))$pixel_array, a)
  expect_equal(ImageMobject(as.matrix(grDevices::as.raster(png::readPNG(f))))$pixel_array, a)
  wide <- array(1, c(2, 3, 4))
  wide[1, 3, 2:3] <- 0
  png::writePNG(wide, f)
  expect_equal(ImageMobject(png::readPNG(f, native = TRUE))$pixel_array, wide * 255)
  expect_error(ImageMobject(c(f, f)), "single string")
})

test_that("ImageMobject opacity, color, resampling and interpolation", {
  img <- ImageMobject(matrix(200, 2, 2))
  img$set_opacity(0.5)
  expect_true(all(img$pixel_array[, , 4] == 127))
  img$fade(0.75)
  expect_true(all(img$pixel_array[, , 4] == 63))
  img$set_color(RED)
  expect_equal(img$pixel_array[1, 1, 1:3], round(color_to_rgb(RED) * 255))
  expect_equal(img$resampling_algorithm, "bicubic")
  expect_equal(img$set_resampling_algorithm("none")$resampling_algorithm, "nearest")
  expect_equal(img$set_resampling_algorithm("linear")$resampling_algorithm, "bilinear")
  expect_error(img$set_resampling_algorithm("fancy"), "resampling_algorithm")
  a <- ImageMobject(matrix(0, 2, 2))
  b <- ImageMobject(matrix(100, 2, 2))$shift(RIGHT)
  mid <- a$copy()
  mid$interpolate(a, b, 0.5)
  expect_true(all(mid$pixel_array[, , 1] == 50))
  expect_equal(mid$get_center(), RIGHT / 2)
  expect_error(mid$interpolate_color(a, ImageMobject(matrix(0, 3, 2)), 0.5), "incompatible")
})

test_that("point cloud dots match upstream point counts", {
  dot <- PointCloudDot(radius = 1, density = 20)
  expect_equal(nrow(dot$points), 1303)
  expect_equal(dim(dot$rgbas), c(1303, 4))
  expect_equal(dot$get_color(), manim_color(PURE_YELLOW))
  expect_equal(dot$stroke_width, 2)
  moved <- PointCloudDot(center = c(1, 2, 0), radius = 1, density = 10)
  expect_equal(colMeans(moved$points)[1:2], c(1, 2), tolerance = 0.05)
  m <- Mobject1D()
  m$add_line(LEFT, RIGHT, color = RED)
  expect_equal(nrow(m$points), 20)
  expect_equal(m$get_color(), manim_color(RED))
  m$thin_out(4)
  expect_equal(nrow(m$points), 5)
  expect_equal(nrow(m$rgbas), 5)
})

test_that("PMobject color, sorting, filtering and alignment", {
  p <- PMobject()
  p$add_points(rbind(c(2, 0, 0), c(0, 0, 0), c(1, 0, 0)), color = BLUE)
  expect_error(p$add_points(rbind(c(0, 0, 0)), rgbas = matrix(1, 2, 4)), "same length")
  p$sort_points()
  expect_equal(p$points[, 1], c(0, 1, 2))
  p$set_color_by_gradient(RED, GREEN)
  expect_equal(manim_color(rgb_to_color(p$rgbas[1, 1:3])), manim_color(RED))
  expect_equal(manim_color(rgb_to_color(p$rgbas[3, 1:3])), manim_color(GREEN))
  p$filter_out(function(pt) pt[1] > 1.5)
  expect_equal(nrow(p$points), 2)
  expect_equal(p$point_from_proportion(1), c(1, 0, 0))
  big <- PMobject()
  big$add_points(matrix(seq_len(12), 4, 3))
  p$align_points_with_larger(big)
  expect_equal(nrow(p$points), 4)
  expect_equal(nrow(p$rgbas), 4)
  part <- PMobject()
  part$pointwise_become_partial(big, 0.25, 0.75)
  expect_equal(part$points, big$points[2:3, ])
  p$fade_to(BLACK, 1)
  expect_equal(p$rgbas[, 1:3], matrix(0, 4, 3))
})

test_that("PGroup, Point and display fields", {
  pt <- Point(c(1, 2, 3))
  expect_s3_class(pt, "Point")
  expect_s3_class(pt, "PMobject")
  expect_equal(pt$points, matrix(c(1, 2, 3), 1))
  expect_equal(pt$get_color(), BLACK)
  g <- PGroup(PointCloudDot(radius = 0.5), pt)
  expect_length(g$submobjects, 2)
  expect_error(PGroup(Circle()), "PMobject")
  g$set_stroke_width(5)
  expect_equal(pt$stroke_width, 5)
  g$set_color(RED)
  expect_equal(pt$get_color(), manim_color(RED))
  merged <- g$copy()$ingest_submobjects()
  expect_equal(nrow(merged$rgbas), nrow(merged$points))
  expect_length(merged$submobjects, 0)
})

test_that("images and point clouds match upstream points", {
  skip_if_not_installed("jsonlite")
  o <- jsonlite::fromJSON(test_path("fixtures", "upstream_oracle_3d.json"), simplifyVector = FALSE)
  mat <- function(x) do.call(rbind, lapply(x, unlist))
  img <- ImageMobject(matrix(c(0, 100, 30, 200, 255, 0, 5, 33), 2, byrow = TRUE))
  expect_equal(img$points, mat(o$image_points), tolerance = 1e-8)
  img$height <- 7
  expect_equal(img$points, mat(o$image_points_h7), tolerance = 1e-8)
  d <- PointCloudDot(radius = 1, density = 20)
  expect_equal(nrow(d$points), o$pointcloud_dot$n)
  expect_equal(d$points[1:5, ], mat(o$pointcloud_dot$head), tolerance = 1e-8)
  expect_equal(unname(tail(d$points, 3)), mat(o$pointcloud_dot$tail), tolerance = 1e-8)
  m <- Mobject1D()
  m$add_line(c(-1, 0, 0), c(1, 0.5, 0))
  expect_equal(m$points, mat(o$mobject1d_line), tolerance = 1e-8)
})

test_that("edge-on and collapsed images are skipped instead of failing", {
  im <- ImageMobject(matrix(c("red", "blue", "green", "white"), 2, 2), scale_to_resolution = FALSE)
  im$rotate(pi / 2, axis = RIGHT + UP)
  expect_s3_class(im$get_image(pixel_width = 160, pixel_height = 90), "nativeRaster")
  im2 <- ImageMobject(matrix(c("red", "blue", "green", "white"), 2, 2), scale_to_resolution = FALSE)
  im2$apply_matrix(matrix(c(1, 1, 0, 0, 0, 0, 0, 0, 1), 3, byrow = TRUE))
  expect_s3_class(im2$get_image(pixel_width = 160, pixel_height = 90), "nativeRaster")
})

test_that("shearing a one-row image keeps both columns", {
  im <- ImageMobject(matrix(c("red", "blue"), 1, 2), scale_to_resolution = FALSE)
  im$set_resampling_algorithm("nearest")
  im$scale(3)
  im$apply_matrix(matrix(c(1, 0.5, 0, 0, 1, 0, 0, 0, 1), 3, byrow = TRUE))
  a <- manimR:::native_raster_to_array(im$get_image(pixel_width = 160, pixel_height = 90))
  px <- matrix(a, ncol = 4)
  red <- sum(px[, 1] == 255 & px[, 2] == 0 & px[, 3] == 0)
  blue <- sum(px[, 1] == 0 & px[, 2] == 0 & px[, 3] == 255)
  expect_gt(red, 100)
  expect_gt(blue, 100)
})

test_that("bilinear and bicubic resampling differ, as in Pillow", {
  draw <- function(alg) {
    a <- array(255, c(3, 3, 4))
    a[, , 1:3] <- rep(c(0, 255, 0, 255, 0, 255, 0, 255, 0), 3)
    m <- ImageMobject(a, scale_to_resolution = FALSE)
    m$set_resampling_algorithm(alg)
    m$get_image(pixel_width = 160, pixel_height = 90)
  }
  expect_false(identical(draw("bilinear"), draw("bicubic")))
  w <- manimR:::cubic_weights(c(0, 0.25, 0.5))
  expect_equal(rowSums(w), c(1, 1, 1))
  expect_equal(w[1, ], c(0, 1, 0, 0))
})

test_that("an image far larger than the frame is sampled at the frame pixels it covers", {
  check <- function(im) {
    a <- manimR:::native_raster_to_array(im$get_image(pixel_width = 160, pixel_height = 90))
    expect_equal(a[45, 5, 1:3], c(255, 0, 0))
    expect_equal(a[45, 156, 1:3], c(0, 0, 255))
    expect_true(all(a[, , 4] == 255))
  }
  big <- ImageMobject(matrix(rep(c("red", "blue"), each = 200), 1, 400), scale_to_resolution = FALSE)
  big$stretch_to_fit_width(400)$stretch_to_fit_height(400)
  check(big)
  sheared <- big$copy()
  sheared$apply_matrix(matrix(c(1, 0.01, 0, 0, 1, 0, 0, 0, 1), 3, byrow = TRUE))
  check(sheared)
})

test_that("images are drawn as upstream's Cairo camera draws them", {
  # Frames from data-raw/image_frame_oracle.py, side by side.
  ref <- round(png::readPNG(test_path("fixtures", "image_frames.png")) * 255)
  idx <- as.matrix(expand.grid(i = 0:5, j = 0:8, k = 0:3))
  src <- array((idx[, 1] * 37 + idx[, 2] * 91 + idx[, 3] * 53) %% 256, c(6, 9, 4))
  src[1:3, , 4] <- 255
  cases <- list(
    function(m) m,
    function(m) m$scale(3.3),
    function(m) m$scale(2.2)$rotate(0.6),
    function(m) m$scale(2)$apply_matrix(matrix(c(1, 0.4, 0, 0.1, 1, 0, 0, 0, 1), 3, byrow = TRUE)),
    function(m) m$scale(1.7)$shift(2.3 * RIGHT + 0.7 * UP),
    function(m) m$scale(30),
    function(m) m$scale(2.5)$set_resampling_algorithm("nearest"),
    function(m) m$scale(2.5)$rotate(0.3)$set_resampling_algorithm("linear"),
    function(m) m$scale(2.5)$set_opacity(0.4),
    function(m) m$scale(0.3)
  )
  for (i in seq_along(cases)) {
    m <- ImageMobject(src)
    cases[[i]](m)
    got <- manimR:::native_raster_to_array(m$get_image(pixel_width = 160, pixel_height = 90))[, , 1:3]
    expect_lte(max(abs(got - ref[, (i - 1) * 160 + 1:160, ])), 1)
  }
})

test_that("pillow_transform() samples as Pillow's perspective transform", {
  # Values from Pillow 10.1: a 2 x 3 RGBA image, half transparent in its
  # second row, scaled to 5 x 4 with each filter.
  src <- array(c(10, 200, 30, 250, 120, 0, 40, 90, 170, 255, 255, 255, 255, 255, 255, 128, 64, 0,
                 0, 0, 0, 0, 0, 0)[1:24], c(2, 3, 4))
  src[, , 4] <- c(255, 128, 255, 64, 255, 0)
  co <- c(3 / 5, 0, 0, 0, 2 / 4, 0, 0, 0)
  out <- function(m) manimR:::pillow_transform(src, co, c(0, 5, 0, 4), m)
  expect_equal(out("nearest")[, , 1], matrix(c(10, 10, 200, 200, 10, 10, 200, 200, 30, 30, 250, 250,
                                               120, 120, 0, 0, 120, 120, 0, 0), 4))
  expect_equal(out("bilinear")[, , 1], matrix(c(10, 36, 123, 199, 18, 40, 123, 212, 30, 46, 124, 251,
                                                84, 89, 121, 255, 120, 120, 121, 0), 4))
  expect_equal(out("bilinear")[, , 4], matrix(c(255, 223, 159, 128, 255, 216, 140, 102, 255, 207, 111, 64,
                                                255, 197, 82, 25, 255, 191, 63, 0), 4))
  expect_equal(out("bicubic")[, , 1], matrix(c(0, 35, 123, 252, 0, 33, 123, 255, 25, 46, 124, 255,
                                               94, 89, 120, 12, 151, 129, 116, 0), 4))
  expect_equal(out("bicubic")[, , 3], matrix(c(255, 255, 255, 255, 255, 255, 240, 196, 255, 245, 199, 0,
                                               159, 137, 120, 0, 45, 37, 26, 0), 4))
})
