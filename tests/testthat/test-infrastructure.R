test_that("config, manim_frame and tempconfig mirror upstream", {
  expect_equal(config$frame_height, cfg("frame_height"))
  # Fixed at load time from 1920 x 1080 pixels, as upstream.
  expect_equal(config$frame_width, 8 * 16 / 9)
  expect_equal(config$aspect_ratio, cfg("pixel_width") / cfg("pixel_height"))
  expect_equal(config$top, config$frame_y_radius * UP)
  expect_equal(tempconfig(list(frame_height = 100, not_a_setting = 1), config$frame_height), 100)
  expect_equal(config$frame_height, 8)
  tempconfig(list(), {
    config$frame_width <- 20
    expect_equal(config$frame_width, 20)
    expect_equal(CameraClass$new()$frame_width, 20)
  })
  expect_equal(cfg("frame_width"), 8 * 16 / 9)
  expect_error(config$top <- 1, "derived")
  expect_equal(manim_frame$right_side, config$frame_x_radius * RIGHT)
  expect_equal(manim_frame$UL, UL)
  expect_error(manim_frame$frame_height <- 3, "read only")
  expect_error(manim_frame$nope, "no entry")
  expect_true("frame_height" %in% names(config))
})

test_that("qualities follow upstream presets", {
  expect_equal(names(QUALITIES), c("fourk_quality", "production_quality", "high_quality", "medium_quality",
                                   "low_quality", "example_quality"))
  expect_equal(DEFAULT_QUALITY, "high_quality")
  tempconfig(list(), {
    manim_config(quality = "example_quality")
    expect_equal(c(cfg("pixel_width"), cfg("frame_rate")), c(854, 30))
    manim_config(quality = "m")
    expect_equal(cfg("pixel_height"), 720)
    expect_error(manim_config(quality = "z"), "Unknown quality")
    manim_config(renderer = RendererType$OPENGL)
    devices <- grDevices::dev.list()
    expect_s3_class(Scene$new()$renderer, "OpenGLRenderer")
    expect_identical(grDevices::dev.list(), devices)
    expect_s3_class(ThreeDScene$new()$renderer, "CairoRenderer")
    expect_error(manim_config(renderer = "vulkan"), "Unknown renderer")
  })
})

test_that("logger follows verbosity", {
  tempconfig(list(verbosity = "WARNING"), {
    expect_silent(logger$info("hidden"))
    expect_message(logger$warning("shown %d", 1L), "WARNING shown 1")
  })
  expect_message(logger$info("visible"), "INFO visible")
  expect_output(console$print("hello"), "hello")
  expect_true(cli_ctx_settings$align_sections)
  expect_match(EPILOG, "Manim Community")
  expect_equal(c(SHIFT_VALUE, CTRL_VALUE, START_X, START_Y), c(65505, 65507, 30, 20))
})

test_that("a scene renders through its Manager", {
  sc <- Scene$new(skip_animations = TRUE)
  m <- Manager(sc)
  expect_identical(sc$manager, m)
  expect_identical(sc$get_manager(), m)
  expect_error(Manager(sc), "already attached")
  sc$add(Square())
  sc$play(FadeIn(Circle()), run_time = 0.2, subcaption = "hi", subcaption_offset = 0.1)
  expect_equal(m$num_plays, 1)
  expect_equal(m$time, sc$renderer$time)
  expect_equal(sc$renderer$file_writer$subcaptions[[1]][c("start", "end")], list(start = 0.1, end = 0.3),
               tolerance = 1e-9)
  expect_s3_class(sc$renderer, "CairoRenderer")
  expect_true(inherits(Scene$new()$renderer, "CairoRenderer"))
})

test_that("Section objects follow upstream", {
  s <- Section(DefaultSectionType$NORMAL, NULL, "intro", FALSE)
  expect_true(s$is_empty())
  s$partial_movie_files[1] <- list(NULL)
  expect_false(s$is_empty())
  expect_length(s$get_clean_partial_movie_files(), 0)
  expect_error(s$get_dict("."), "does not have a video")
  expect_output(print(s), "<Section 'intro' stored in 'None'>")
  v <- Section("default.normal", "S_0000_a.mp4", "a", FALSE)
  d <- v$get_dict(".", metadata = list(width = 10L))
  expect_equal(d, list(name = "a", type = "default.normal", video = "S_0000_a.mp4", width = 10L))
})

test_that("OpenGL point clouds match upstream", {
  skip_if_not_installed("jsonlite")
  o <- jsonlite::fromJSON(test_path("fixtures", "opengl_point_cloud_oracle.json"), simplifyVector = TRUE)
  d <- DotCloud()
  expect_equal(nrow(d$points), o$dotcloud_n)
  expect_equal(unname(d$points[1:5, ]), o$dotcloud_first, tolerance = 1e-6)
  expect_equal(unname(d$points[nrow(d$points) - 2:0, ]), o$dotcloud_last, tolerance = 1e-6)
  expect_equal(d$point_radius, o$dotcloud_point_radius)
  expect_equal(d$rgbas, o$dotcloud_rgbas, tolerance = 1e-9)
  d2 <- DotCloud(radius = 0.5, density = 4)
  expect_equal(unname(d2$points), o$dotcloud2, tolerance = 1e-6)
  t <- TrueDot(center = RIGHT)
  expect_equal(unname(t$points), o$truedot_points, tolerance = 1e-6)
  expect_equal(t$radius, o$truedot_radius)
  p <- OpenGLPMPoint(location = UP)
  expect_equal(unname(p$points), o$pmpoint)
  expect_equal(c(p$stroke_width, p$point_radius), c(o$pmpoint_sw, o$pmpoint_pr))
  q <- OpenGLPMobject()
  q$add_points(rbind(c(0, 0, 0), c(1, 1, 0)), color = RED)
  expect_equal(q$points, o$pm_points)
  expect_equal(q$rgbas, o$pm_rgbas, tolerance = 1e-9)
  g <- OpenGLPGroup(OpenGLPMPoint(), OpenGLPMPoint(location = RIGHT))
  expect_length(g$submobjects, o$group_n)
  expect_error(OpenGLPGroup(Square()), "OpenGLPMobject")
  d$make_3d()
  expect_equal(c(d$gloss, d$shadow), c(0.5, 0.2))
  img <- render_mobject_image(OpenGLPMPoint(stroke_width = 40), pixel_width = 80, pixel_height = 45)
  img <- native_raster_to_array(img)
  expect_true(any(img[, , 1] > 200 & img[, , 3] < 50))
})

test_that("background colored displayer multiplies coverage by the image", {
  cam <- CameraClass$new(pixel_width = 32, pixel_height = 18)
  bg <- array(0, c(18, 32, 3))
  bg[, , 1] <- 1
  sq <- Square(side_length = 4)$set_fill(WHITE, 1)
  sq$color_using_background_image(bg)
  disp <- BackgroundColoredVMobjectDisplayer(cam)
  out <- disp$display(sq)
  expect_equal(dim(out), c(18, 32, 4))
  expect_equal(max(out[, , 1]), 255)
  expect_equal(max(out[, , 2]), 0)
  expect_equal(out[1, 1, 1], 0)
  big <- disp$resize_background_array(array(255, c(4, 4, 4)), 8, 6, "RGB")
  expect_equal(dim(big), c(6, 8, 3))
})

test_that("plugins are listed", {
  expect_type(get_plugins(), "list")
  expect_output(list_plugins(), "Plugins:")
})

test_that("gain_to_background lowers earlier sounds", {
  skip_if_not(nzchar(Sys.which("ffmpeg")) && nzchar(Sys.which("ffprobe")))
  skip_on_cran()
  dir <- withr_tempdir()
  make <- function(name, src) {
    f <- file.path(dir, name)
    system2(Sys.which("ffmpeg"), c("-y", "-loglevel", "error", "-f", "lavfi", "-i", shQuote(src), shQuote(f)))
    f
  }
  bed <- make("bed.wav", "sine=frequency=220:duration=1")
  # A silent sound, so only the lowered bed is measured while it plays.
  ping <- make("ping.wav", "anullsrc=r=44100:cl=mono:d=0.3")
  level <- function(gtb) {
    out <- render(function(self) {
      self$add_sound(bed)
      self$add_sound(ping, time_offset = 0.5, gain_to_background = gtb)
      self$wait(1)
    }, quality = "l", media_dir = file.path(dir, as.character(gtb)))
    # Mean volume between 0.55 s and 0.75 s, while the second sound plays.
    rep <- system2(Sys.which("ffmpeg"), c("-hide_banner", "-ss", "0.55", "-t", "0.2", "-i", shQuote(out),
                                          "-af", "volumedetect", "-f", "null", "-"),
                   stdout = TRUE, stderr = TRUE)
    as.numeric(sub(".*mean_volume: ([-0-9.]+) dB.*", "\\1", grep("mean_volume", rep, value = TRUE)))
  }
  expect_equal(level(-20) - level(0), -20, tolerance = 0.1)
})

test_that("partial movie files are cached by play hash", {
  skip_if_not(nzchar(Sys.which("ffmpeg")))
  skip_on_cran()
  dir <- withr_tempdir()
  make <- function(col) function(self) {
    self$play(Create(Square(color = col)), run_time = 0.2)
    self$wait(0.2)
  }
  out1 <- render(make(BLUE), quality = "l", media_dir = dir, scene_name = "Cached")
  pdir <- file.path(dirname(out1), "partial_movie_files", "Cached")
  first <- list.files(pdir, pattern = "\\.mp4$")
  expect_length(first, 2)
  expect_message(out2 <- render(make(BLUE), quality = "l", media_dir = dir, scene_name = "Cached"),
                 "Using cached data")
  expect_setequal(list.files(pdir, pattern = "\\.mp4$"), first)
  expect_equal(get_video_metadata(out2)$nb_frames, get_video_metadata(out1)$nb_frames)
  render(make(RED), quality = "l", media_dir = dir, scene_name = "Cached")
  expect_length(list.files(pdir, pattern = "\\.mp4$"), 4)
  render(make(RED), quality = "l", media_dir = dir, scene_name = "Cached", disable_caching = TRUE)
  expect_true(all(c("uncached_00000.mp4", "uncached_00001.mp4") %in% list.files(pdir)))
  tempconfig(list(max_files_cached = 2), render(make(GREEN), quality = "l", media_dir = dir, scene_name = "Cached"))
  expect_lte(length(list.files(pdir, pattern = "\\.mp4$")), 2)
  render(make(GREEN), quality = "l", media_dir = dir, scene_name = "Cached", flush_cache = TRUE)
  expect_length(list.files(pdir, pattern = "\\.mp4$"), 2)
  # The cache stays in the media directory when output_file points elsewhere.
  out_dir <- file.path(dir, "elsewhere")
  out3 <- render(make(BLUE), quality = "l", media_dir = dir, scene_name = "Cached",
                 output_file = file.path(out_dir, "movie.mp4"))
  expect_true(file.exists(out3))
  expect_identical(list.files(out_dir), "movie.mp4")
})

test_that("play hashes follow the state that is drawn", {
  sc <- Scene$new(skip_animations = TRUE)
  h <- function(mobs, anims) get_hash_from_play_call(sc, sc$camera, anims, mobs)
  sq <- Square()
  a <- h(list(sq), list(FadeIn(sq)))
  # The same structure (one square, animated and on screen) hashes the same.
  sq2 <- Square()
  expect_identical(a, h(list(sq2), list(FadeIn(sq2))))
  expect_false(identical(a, h(list(Square()$shift(RIGHT)), list(FadeIn(Square())))))
  expect_false(identical(a, h(list(sq), list(FadeIn(sq, run_time = 2)))))
  expect_false(identical(h(list(sq), list(FadeIn(sq, rate_func = squish_rate_func(smooth_rate, 0, 0.5)))),
                         h(list(sq), list(FadeIn(sq, rate_func = squish_rate_func(smooth_rate, 0, 0.6))))))
})

test_that("the camera's pixel array follows upstream", {
  cam <- CameraClass$new(pixel_width = 64, pixel_height = 36)
  cam$capture_mobject(Square(side_length = 4)$set_fill(RED, 1))
  expect_equal(cam$pixel_array[18, 32, ], c(252, 98, 85, 255))
  expect_equal(cam$pixel_array[1, 1, ], c(0, 0, 0, 255))
  expect_equal(cam$points_to_pixel_coords(NULL, rbind(c(0, 0, 0), c(-cam$frame_width / 2, 4, 0))),
               rbind(c(32, 18), c(0, 0)))
  expect_equal(nrow(cam$get_thickening_nudges(4)), 16)
  expect_equal(range(cam$get_thickening_nudges(4)), c(-1, 2))
  expect_s3_class(cam$get_image(), "raster")
  expect_false(cam$is_in_frame(Circle()$shift(RIGHT * 20)))
  expect_true(cam$is_in_frame(Circle()))
  cam$set_background_from_func(function(p) c(1, 0, 0, 1))
  cam$reset()
  expect_equal(cam$pixel_array[5, 5, ], c(255, 0, 0, 255))
  over <- cam$overlay_rgba_array(array(c(0, 0, 0, 255), c(1, 1, 4)), array(c(255, 255, 255, 128), c(1, 1, 4)))
  expect_equal(over[1, 1, ], c(128, 128, 128, 255))
  expect_equal(cam$adjusted_thickness(3), 1 + 2 * (cfg("pixel_height") + cfg("pixel_width")) / 100)
})

test_that("Scene helpers and interaction handlers follow upstream", {
  sc <- ThreeDScene$new(skip_animations = TRUE)
  sc$remember_camera_state()
  th <- sc$camera$get_theta()
  sc$on_mouse_drag(ORIGIN, c(0.1, 0.2, 0), buttons = 1)
  expect_equal(sc$camera$get_theta(), th - 0.1)
  sc$on_mouse_scroll(ORIGIN, c(0, 1, 0))
  expect_false(isTRUE(all.equal(sc$camera$get_zoom(), 1)))
  sc$on_key_press(utf8ToInt("r"))
  expect_equal(sc$camera$get_theta(), th)
  expect_equal(sc$camera$get_zoom(), 1)
  hit <- FALSE
  sc$set_key_function("k", function() hit <<- TRUE)
  sc$on_key_press("k")
  expect_true(hit)
  sc$on_key_press("q")
  expect_true(sc$quit_interaction)
  expect_false(suppressMessages(sc$check_interactive_embed_is_valid()))
  expect_equal(sc$get_attrs("quit_interaction"), list(TRUE))
  sc2 <- Scene$new()
  expect_equal(sc2$get_time_progression(0.2), c(0, 1 / 60, 2 / 60, 3 / 60, 4 / 60, 5 / 60, 6 / 60, 7 / 60, 8 / 60, 9 / 60, 10 / 60, 11 / 60))
  sc2$on_mouse_motion(c(1, 1, 0), c(0.5, 0, 0))
  expect_equal(sc2$mouse_point$get_center(), c(1, 1, 0))
  sc2$pressed_keys <- SHIFT_VALUE
  sc2$on_mouse_motion(c(1, 1, 0), c(0.5, 0, 0))
  expect_equal(sc2$camera$frame_center, c(-0.5, 0, 0))
})

test_that("ported class methods work", {
  c3 <- CircleClass$from_three_points(LEFT, UP, RIGHT)
  expect_equal(c3$radius, 1, tolerance = 1e-9)
  expect_equal(c3$get_center(), ORIGIN, tolerance = 1e-9)
  expect_s3_class(AngleClass$from_three_points(RIGHT, ORIGIN, UP), "Angle")
  l <- Line3D(ORIGIN, RIGHT)
  expect_equal(Line3DClass$parallel_to(l, UP, length = 2)$get_start(), UP + RIGHT, tolerance = 1e-6)
  expect_s3_class(Line3DClass$perpendicular_to(l, UP), "Line3D")
  sq <- Square()
  sq$`repeat`(2)
  expect_equal(nrow(sq$points), 32)
  expect_true(is.function(MobjectClass$set_default))
  expect_true("vim" %in% CodeClass$get_styles_list())
  f <- Flash(ORIGIN, num_lines = 6)
  expect_length(f$create_lines()$submobjects, 6)
  cas <- CurvesAsSubmobjects(Square())
  expect_equal(cas$point_from_proportion(1), Square()$points[16, ])
  expect_error(MoveToTarget(Square()), "target")
  expect_equal(ApplyMatrixClass$new(diag(2), Square())$initialize_matrix(diag(2)), diag(3))
  expect_equal(LinearBase()$`function`(2), 2)
  expect_length(VMobject()$set_points_as_corners(rbind(LEFT, RIGHT, UP))$get_curve_functions(), 2)
  tpl <- tempfile(fileext = ".tex")
  writeLines(c("\\documentclass{article}", "\\begin{document}", "YourTextHere", "\\end{document}"), tpl)
  expect_match(TexTemplateClass$from_file(tpl)$body(), "documentclass\\{article\\}")
})

test_that("the interactive window passes events to the scene", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("miniUI")
  sc <- ThreeDScene$new(camera_class = ThreeDCameraClass, pixel_width = 64, pixel_height = 36)
  sc$add(Cube())
  hit <- 0
  sc$set_key_function("k", function() hit <<- hit + 1)
  app <- manimR:::interactive_app(sc, fps = 2)
  on.exit(sc$renderer$close_device(), add = TRUE)
  th <- sc$camera$get_theta()
  shiny::testServer(app, {
    session$setInputs(key_press = list(key = "k", shift = FALSE))
    session$setInputs(mouse_drag = list(p = list(0.5, 0.5), d = list(0.1, 0), button = 1, shift = FALSE))
    session$setInputs(code = "self$add(Square())", run = 1)
    expect_match(output$out, "Scene|Square|ThreeD")
    img <- output$frame
    expect_match(img$src, "^data:image/png")
  })
  expect_equal(hit, 1)
  expect_lt(sc$camera$get_theta(), th)
  expect_true(any(vapply(sc$mobjects, inherits, NA, what = "Square")))
})

test_that("knitr videos are linked relative to the page", {
  expect_identical(video_src("/site/articles/a_files/figure-html/x.mp4", "/site/articles/a_files/figure-html"),
                   "a_files/figure-html/x.mp4")
  expect_identical(video_src("a_files/figure-html/x.mp4", "a_files/figure-html"), "a_files/figure-html/x.mp4")
  expect_identical(video_src("/abs/figures/x.mp4", "/abs/figures"), "/abs/figures/x.mp4")
})

test_that("scene_frame() steps updaters through earlier frames", {
  S <- function(self) {
    v <- ValueTracker(1)
    v$add_updater(function(m, dt) m$increment_value(m$get_value() * dt))
    self$add(v)
    assign("tracker", v, envir = parent.env(environment()))
    self$wait(1)
  }
  tracker <- NULL
  environment(S) <- environment()
  scene_frame(S, t = 0.5, frame_rate = 10)
  expect_equal(tracker$get_value(), 1.1^5)
})

test_that("scene_frame() closes its device when drawing fails", {
  before <- grDevices::dev.list()
  S <- function(self) {
    self$wait(0.1)
    im <- ImageMobject(matrix(c("red", "blue", "green", "white"), 2, 2), scale_to_resolution = FALSE)
    im$pixel_array <- "not an image"
    self$add(im)
  }
  expect_error(scene_frame(S, t = Inf))
  expect_identical(grDevices::dev.list(), before)
})

test_that("no_latex_cleanup keeps LaTeX intermediates", {
  skip_if_not(latex_works())
  skip_on_cran()
  td <- withr_tempdir()
  with_manim_config(list(tex_dir = td, no_latex_cleanup = TRUE), tex_to_svg_file("x^2+41", environment = "align*"))
  expect_true(any(grepl("\\.log$", list.files(td))))
})

test_that("knit_print copies outputs under chunk-specific names", {
  skip_if_not_installed("knitr")
  d <- withr_tempdir()
  f1 <- file.path(d, "a", "Scene.png")
  f2 <- file.path(d, "b", "Scene.png")
  dir.create(dirname(f1))
  dir.create(dirname(f2))
  png::writePNG(array(c(1, 0, 0), c(1, 1, 3)), f1)
  png::writePNG(array(c(0, 0, 1), c(1, 1, 3)), f2)
  out <- character()
  for (x in list(list("red", f1), list("blue", f2))) {
    opts <- list(label = x[[1]], fig.path = paste0(d, "/fig/"), out.width = "100%")
    res <- knit_print.manim_output(structure(x[[2]], class = "manim_output"), options = opts)
    out <- c(out, as.character(res))
  }
  expect_length(unique(out), 2)
  expect_length(list.files(file.path(d, "fig")), 2)
})

test_that("Shiny outputs of different sessions use separate files", {
  skip_if_not_installed("shiny")
  skip_on_cran()
  srcs <- character()
  for (col in c(RED, BLUE)) {
    server <- function(input, output, session) {
      output$scene <- renderManim(function(self) self$add(Square(fill_color = col, fill_opacity = 1)),
                                  format = "png", pixel_width = 64, pixel_height = 36)
    }
    shiny::testServer(server, {
      html <- as.character(output$scene$html)
      srcs <<- c(srcs, regmatches(html, regexpr('src="[^"]+"', html)))
    })
  }
  expect_length(unique(srcs), 2)
  expect_false(identical(dirname(srcs[1]), dirname(srcs[2])))
})

test_that("the knitr engine embeds a file that exists next to the document", {
  skip_if_not_installed("knitr")
  d <- withr_tempdir()
  rmd <- file.path(d, "doc.Rmd")
  writeLines(c(
    "```{manim, sq, format = 'png', quality = 'l'}",
    "Sq <- R6::R6Class('Sq', inherit = Scene, public = list(construct = function() self$add(Square())))",
    "```"
  ), rmd)
  old <- setwd(d)
  on.exit(setwd(old), add = TRUE)
  md <- knitr::knit(rmd, output = file.path(d, "doc.md"), quiet = TRUE, envir = new.env())
  ref <- regmatches(readLines(md), regexpr("\\(([^)]+\\.png)\\)", readLines(md)))
  expect_length(ref, 1)
  expect_true(file.exists(file.path(d, gsub("^\\(|\\)$", "", ref))))
})

test_that("video widths always carry a CSS unit", {
  expect_equal(manimR:::css_width(NULL), "100%")
  expect_equal(manimR:::css_width(672), "672px")
  expect_equal(manimR:::css_width("80%"), "80%")
})
