test_that("set_default changes and restores class defaults", {
  set_default(Circle, color = BLUE)
  on.exit(set_default(Circle), add = TRUE)
  expect_equal(Circle()$get_color(), BLUE)
  set_default(Create, run_time = 3)
  on.exit(set_default(Create), add = TRUE)
  expect_equal(Create(Square())$run_time, 3)
  expect_equal(Create(Square(), run_time = 1)$run_time, 1)
  set_default(Circle)
  set_default(Create)
  expect_equal(Circle()$get_color(), RED)
  expect_equal(Create(Square())$run_time, 1)
})

test_that("units convert like manim.utils.unit", {
  old <- manim_config(quality = "h")
  on.exit(manim_config(quality = old$quality))
  expect_equal(1920 * Pixels, 8 * 16 / 9)
  expect_equal(50 * Percent(X_AXIS), 8 * 16 / 9 / 2)
  expect_equal(25 * Percent(Y_AXIS), 2)
  expect_equal(180 * Degrees, pi)
})

test_that("TracedPath and AnimatedBoundary update every frame", {
  d <- Dot()
  tp <- TracedPath(function() d$get_center())
  tp$update(0.1)
  d$shift(RIGHT)
  tp$update(0.1)
  expect_equal(tp$get_end(), RIGHT)
  ab <- AnimatedBoundary(Square())
  ab$update(1.5)
  expect_equal(ab$boundary_copies[[1]]$get_stroke_width(), 3)
})

test_that("ScreenRectangle keeps the frame aspect ratio", {
  r <- ScreenRectangle(height = 2)
  expect_equal(r$aspect_ratio, 16 / 9)
  expect_equal(FullScreenRectangle()$height, 8)
})

test_that("find_scenes and render_file locate scene classes", {
  f <- tempfile(fileext = ".R")
  writeLines(c(
    "Second <- manimR::manim_scene(function(self) self$add(manimR::Circle()), name = 'Second')",
    "First <- R6::R6Class('First', inherit = manimR::Scene, public = list(construct = function() self$add(manimR::Square())))",
    "not_a_scene <- 1"
  ), f)
  sc <- find_scenes(f)
  expect_equal(names(sc), c("Second", "First"))
  dir <- withr_tempdir()
  out <- render_file(f, "First", quality = "l", media_dir = dir)
  expect_match(out, "First\\.png$")
})

test_that("TangentialArc matches upstream endpoints", {
  a <- TangentialArc(Line(LEFT * 2, ORIGIN), Line(ORIGIN, UP * 2), radius = 0.5)
  expect_equal(a$get_start(), c(0, 0.5, 0), tolerance = 1e-9)
  expect_equal(a$get_end(), c(0.5, 0, 0), tolerance = 1e-9)
})

test_that("MappingCamera maps points before drawing", {
  cam <- MappingCameraClass$new(mapping_func = function(p) p * 2)
  expect_equal(unname(cam$project_points(matrix(c(1, 2, 0), 1))), matrix(c(2, 4), 1))
})

test_that("knitr engine renders a scene to an image", {
  skip_if_not_installed("knitr")
  skip_if_not_installed("rmarkdown")
  dir <- withr_tempdir()
  rmd <- file.path(dir, "doc.Rmd")
  writeLines(c(
    "---", "output: md_document", "---", "",
    "```{manim, scene = 'Still', save_last_frame = TRUE}",
    "Still <- R6::R6Class('Still', inherit = Scene, public = list(construct = function() self$add(Circle())))",
    "```"
  ), rmd)
  library(manimR)
  out <- rmarkdown::render(rmd, quiet = TRUE, envir = new.env())
  md <- readLines(out)
  expect_true(any(grepl("Still\\.png", md)))
})

test_that("multi-line text and paragraphs match upstream layout", {
  skip_if(!grepl("Helvetica", systemfonts::match_fonts("Helvetica")$path), "Helvetica not installed")
  # Reference values from Python manim 0.20.1 (Pango) with font = "Helvetica".
  t <- Text("Hag\nHag", font = "Helvetica")
  expect_equal(c(t$height, t$width), c(1.2756, 1.1232), tolerance = 0.005)
  expect_equal(Text("Hag\nHag", font = "Helvetica", line_spacing = 1)$height, 1.6256, tolerance = 0.005)
  p <- Paragraph("aaa", "ggg", "AAA", font = "Helvetica")
  expect_equal(vapply(p$submobjects, function(l) l$get_center()[2], 0), c(0.6441, -0.0748, -0.5895), tolerance = 0.005)
  t <- Text("Hello World", font = "Helvetica", t2c = list(World = RED), t2w = list(Hello = "BOLD"))
  expect_equal(length(t), 10)
  expect_equal(t[6]$get_fill_color(), "#FC6255")
})

test_that("CLI resolution, range, fps and still output path flags work", {
  skip_if_not(nzchar(Sys.which("ffmpeg")))
  dir <- withr_tempdir()
  f <- file.path(dir, "s.R")
  writeLines("Still <- manimR::manim_scene(function(self) { self$add(manimR::Square()); self$play(manimR::FadeIn(manimR::Circle()), run_time = 0.2) }, name = 'Still')", f)
  poster <- file.path(dir, "poster.png")
  out <- manim_cli(c(f, "Still", "-s", "-r", "64,36", "--fps", "5", "-n", "0,3", "-o", poster))
  expect_true(file.exists(poster))
  expect_equal(dim(png::readPNG(poster))[1:2], c(36, 64))
  expect_error(manim_cli(c(f, "-r", "64")), "Resolution")
  expect_error(manim_cli(c(f, "-n", "a")), "range")
})

test_that("transparent output with an .mp4 name becomes .mov", {
  skip_if_not(nzchar(Sys.which("ffmpeg")))
  dir <- withr_tempdir()
  out <- suppressMessages(render(function(self) self$play(FadeIn(Square()), run_time = 0.2), quality = "l",
                                 transparent = TRUE, output_file = file.path(dir, "clip.mp4")))
  expect_match(unclass(out), "clip\\.mov$")
  expect_true(file.exists(out))
})

test_that("a short sound does not cut the movie", {
  skip_if_not(nzchar(Sys.which("ffmpeg")) && nzchar(Sys.which("ffprobe")))
  dir <- withr_tempdir()
  wav <- file.path(dir, "click.wav")
  system2(Sys.which("ffmpeg"), c("-y", "-loglevel", "error", "-f", "lavfi", "-i", shQuote("sine=frequency=440:duration=0.1"), shQuote(wav)))
  out <- render(function(self) { self$add_sound(wav); self$wait(1) }, quality = "l", media_dir = dir)
  d <- as.numeric(system2(Sys.which("ffprobe"), c("-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", shQuote(out)), stdout = TRUE))
  expect_gt(d, 0.9)
})

test_that("mobjects animated inside groups count as moving", {
  sc <- Scene$new()
  q <- Square()
  sc$add(Circle(), q)
  moving <- sc$get_moving_mobjects(list(AnimationGroup(FadeIn(q))))
  expect_true(q$mob_id %in% vapply(moving, function(m) m$mob_id, ""))
})

test_that("override_animation replaces an animation for a class", {
  Pulse <- R6::R6Class("Pulse", inherit = CircleClass, lock_objects = FALSE)
  override_animation(Pulse, "FadeIn", function(...) GrowFromCenter(self, ...))
  p <- Pulse$new()
  expect_s3_class(FadeIn(p, run_time = 2), "GrowFromPoint")
  expect_equal(FadeIn(p, run_time = 2)$run_time, 2)
  expect_s3_class(FadeIn(p, use_override = FALSE), "FadeIn")
  expect_s3_class(FadeIn(Circle()), "FadeIn")
  override_animate(Pulse, "shift", function(..., anim_args = NULL) Indicate(self))
  expect_s3_class(prepare_animation(Pulse$new()$animate$shift(UP)), "Indicate")
  expect_error(assert_is_mobject_method(function() 1), "method of a mobject")
  expect_silent(assert_is_mobject_method(p$shift))
})

test_that("camera background images and non PNG images load", {
  skip_if_not(nzchar(Sys.which("ffmpeg")))
  dir <- withr_tempdir()
  jpg <- file.path(dir, "red.jpg")
  system2(Sys.which("ffmpeg"), c("-y", "-loglevel", "error", "-f", "lavfi", "-i", shQuote("color=c=red:s=40x30"), "-frames:v", "1", shQuote(jpg)))
  im <- ImageMobject(jpg)
  expect_equal(dim(im$pixel_array)[1:2], c(30, 40))
  expect_gt(mean(im$pixel_array[, , 1]), 200)
  cam <- CameraClass$new(background_image = jpg, pixel_width = 20, pixel_height = 10, use_z_index = FALSE)
  expect_equal(dim(cam$background_image)[1:2], c(10, 20))
  expect_false(cam$use_z_index)
})

test_that("a conditional wait stops at its condition while skipping", {
  sc <- Scene$new(skip_animations = TRUE)
  vt <- ValueTracker(0)
  vt$add_updater(function(m, dt) m$increment_value(dt))
  sc$add(vt)
  sc$wait_until(function() vt$get_value() >= 1, max_time = 10)
  expect_lt(vt$get_value(), 1.2)
})
