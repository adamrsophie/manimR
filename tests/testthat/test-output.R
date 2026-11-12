test_that("output formats follow upstream's render session", {
  expect_identical(parse_output_format(NULL), "auto")
  expect_identical(parse_output_format("PNG_Sequence"), "png-sequence")
  expect_error(parse_output_format("avi"), "Invalid output format")
  tempconfig(list(format = "auto"), {
    s <- resolve_render_session()
    expect_identical(s$output$format, "mp4")
    expect_true(s$output$fallback_to_still)
  })
  tempconfig(list(format = "auto", transparent = TRUE), expect_identical(resolve_render_session()$output$format, "mov"))
  tempconfig(list(dry_run = TRUE), expect_identical(resolve_render_session()$output$format, "none"))
  tempconfig(list(format = "mp4", transparent = TRUE), expect_error(resolve_render_session(), "alpha channel"))
  tempconfig(list(format = "png", save_sections = TRUE), expect_error(resolve_render_session(), "Section output"))
  tempconfig(list(live_preview = TRUE), expect_error(resolve_render_session(), "live preview"))
  live <- RendererCapabilities(live_preview = TRUE)
  tempconfig(list(live_preview = TRUE, dry_run = TRUE), expect_error(resolve_render_session(live), "dry_run"))
  tempconfig(list(live_preview = TRUE, format = "png"), expect_error(resolve_render_session(live), "PNG"))
  tempconfig(list(live_preview = TRUE), expect_identical(resolve_render_session(live)$output$format, "none"))
  expect_false(CairoRenderer()$capabilities$live_preview)
  expect_false(CairoRendererClass$capabilities$live_preview)
  tempconfig(list(format = "gif"), {
    out <- resolve_render_session()$output
    expect_identical(out$segment_extension, ".mp4")
    expect_identical(out$artifact_extension, ".gif")
  })
})

test_that("save_last_frame and transparent are derived settings", {
  tempconfig(list(), {
    manim_config(save_last_frame = TRUE)
    expect_identical(cfg("format"), "png")
    expect_true(cfg("save_last_frame"))
    manim_config(save_last_frame = FALSE)
    expect_identical(cfg("format"), "auto")
    manim_config(transparent = TRUE)
    expect_equal(cfg("background_opacity"), 0)
    expect_true(config$transparent)
  })
  expect_error(manim_config(not_a_setting = 1), "Unknown setting")
  expect_error(manim_config(write_to_movie = FALSE), "format")
  expect_error(manim_config(verbosity = "LOUD"), "verbosity")
  expect_error(manim_config(zero_pad = 12), "zero_pad")
})

test_that("the video encoder and its fingerprint match upstream", {
  out <- output_spec("mp4")
  enc <- resolve_video_encoder(out, 854, 480, 15)
  expect_identical(enc$codec, "libx264")
  expect_identical(enc$pixel_format, "yuv420p")
  expect_identical(enc$options, c(crf = "23"))
  # The canonical JSON upstream hashes, written out by hand.
  json <- paste0('{"codec":"libx264","container_format":"mp4","frame_rate":{"denominator":1,"numerator":15},',
                 '"height":480,"options":[{"name":"crf","value":"23"}],"pixel_format":"yuv420p",',
                 '"schema":"manim-video-segment-v1","width":854}')
  expect_identical(video_encoder_fingerprint(enc), digest::digest(json, algo = "sha256", serialize = FALSE))
  expect_identical(to_frame_rate(29.97), c(30000, 1001))
  expect_identical(to_frame_rate(12.5), c(25, 2))
  expect_identical(resolve_video_encoder(output_spec("mov", transparent = TRUE), 10, 10, 30)$codec, "qtrle")
  expect_error(resolve_video_encoder(out, 10, 10, 30, options = list(pix_fmt = "rgb24")), "conflict")
  expect_error(resolve_video_encoder(output_spec("webm", transparent = TRUE), 10, 10, 30, pixel_format = "yuv420p"),
               "alpha")
  expect_null(resolve_video_encoder(output_spec("png"), 10, 10, 30))
})

test_that("directory settings resolve their placeholders", {
  tempconfig(list(media_dir = "out"), {
    expect_identical(get_dir("tex_dir"), "out/Tex")
    expect_error(get_dir("video_dir"), "module_name")
    expect_identical(get_dir("video_dir", module_name = "m"), paste0("out/videos/m/", quality_dir_name()))
    expect_identical(get_dir("partial_movie_dir", module_name = "m", scene_name = "S"),
                     paste0("out/videos/m/", quality_dir_name(), "/partial_movie_files/S"))
  })
  expect_error(get_dir("frame_rate"), "must pass one of")
  expect_identical(absolute_lexical("a/../b/./c", "/root"), "/root/b/c")
})

test_that("output plans name every artifact as upstream", {
  layout <- list(images_dir = "/m/images/mod", video_dir = "/m/videos/mod/480p15",
                 partial_movie_dir = "/m/videos/mod/480p15/partial_movie_files/S", sections_dir = NULL,
                 log_dir = NULL, zero_pad = 4L)
  ver <- utils::packageVersion("manimR")
  p <- resolve_output_plan(layout, output_spec("mp4", fallback_to_still = TRUE), "S")
  expect_identical(p$primary_artifact, "/m/videos/mod/480p15/S.mp4")
  expect_identical(p$fallback_image, paste0("/m/images/mod/S_manimR_v", ver, ".png"))
  expect_identical(p$subcaption_file, "/m/videos/mod/480p15/S.srt")
  expect_identical(plan_segment_path(p, "abc"), "/m/videos/mod/480p15/partial_movie_files/S/abc.mp4")
  p <- resolve_output_plan(layout, output_spec("png"), "S", "poster")
  expect_identical(p$primary_artifact, "/m/images/mod/poster.png")
  p <- resolve_output_plan(layout, output_spec("png-sequence"), "S")
  expect_identical(plan_image_frame_path(p, 7), "/m/images/mod/S/0007.png")
  p <- resolve_output_plan(layout, output_spec("gif"), "S")
  expect_identical(p$primary_artifact, paste0("/m/videos/mod/480p15/S_manimR_v", ver, ".gif"))
  expect_null(resolve_output_plan(layout, output_spec("none"), "S")$primary_artifact)
})

test_that("renders write the artifact of each format", {
  skip_if_not(nzchar(Sys.which("ffmpeg")))
  skip_on_cran()
  dir <- withr_tempdir()
  sc <- function(self) self$play(Create(Square()), run_time = 0.2)
  png_out <- render(sc, quality = "l", format = "png", media_dir = dir)
  expect_match(png_out, "images/manimR/Scene_manimR_v.*\\.png$")
  seq_out <- render(sc, quality = "l", format = "png-sequence", media_dir = dir, zero_pad = 3)
  expect_true(dir.exists(seq_out))
  expect_identical(list.files(seq_out)[1], "000.png")
  expect_null(render(sc, quality = "l", dry_run = TRUE, media_dir = dir))
  still <- render(function(self) self$add(Circle()), quality = "l", media_dir = dir)
  expect_match(still, "\\.png$")
  expect_error(render(function(self) self$add(Circle()), quality = "l", format = "mp4", media_dir = dir),
               "no play calls")
  named <- render(sc, quality = "l", media_dir = dir, output_file = "named")
  expect_identical(basename(named), "named.mp4")
  expect_true(file.exists(file.path(dirname(named), "partial_movie_files", "Scene", "partial_movie_file_list.txt")))
  logged <- render(sc, quality = "l", media_dir = dir, log_to_file = TRUE, verbosity = "INFO")
  log_file <- file.path(dir, "logs", "manimR_Scene.log")
  expect_true(file.exists(log_file))
  expect_match(readLines(log_file)[1], '^\\{"levelname": ')
})

test_that("custom file writer classes are used", {
  Custom <- R6::R6Class("CustomWriter", inherit = SceneFileWriterClass, lock_objects = FALSE,
                        public = list(initialize = function(settings) {
                          self$custom <- TRUE
                          super$initialize(settings)
                        }))
  sc <- Scene$new(renderer = CairoRenderer(file_writer_class = Custom), skip_animations = TRUE)
  expect_true(isTRUE(sc$renderer$file_writer$custom))
})

test_that("manim.cfg files and the command line set upstream's options", {
  f <- tempfile(fileext = ".cfg")
  writeLines(c("[CLI]", "frame_rate = 24", "zero_pad = 2", "save_sections = True",
               "[video_encoder.options]", "crf = 30"), f)
  tempconfig(list(), {
    digest_config_file(f)
    expect_equal(cfg("frame_rate"), 24)
    expect_equal(cfg("zero_pad"), 2)
    expect_true(cfg("save_sections"))
    expect_identical(cfg("video_encoder_options"), list(crf = "30"))
  })
  expect_error(digest_config_file(tempfile()), "valid config file")
  # A section may set one key; upstream's default.cfg keys and %% escapes read.
  writeLines(c("[CLI]", "tex_template = ", "[video_encoder]", "codec = libx264",
               "[jupyter]", "media_width = 50%%"), f)
  tempconfig(list(), {
    digest_config_file(f)
    expect_identical(cfg("video_codec"), "libx264")
    expect_identical(cfg("media_width"), "50%")
  })
  d <- withr_tempdir()
  old_wd <- setwd(d)
  on.exit(setwd(old_wd), add = TRUE)
  expect_output(path <- manim_cli(c("cfg", "export", "--directory", "out")), "Exported final Config")
  expect_identical(normalizePath(dirname(path)), normalizePath(file.path(d, "out")))
  setwd(old_wd)
  script <- tempfile(fileext = ".R")
  writeLines(c("A <- manim_scene(function(self) self$add(Circle()), name = 'A')",
               "B <- manim_scene(function(self) self$add(Square()), name = 'B')"), script)
  expect_error(manim_cli(c(script, "-a", "-o", "x")), "exactly one scene")
  expect_error(manim_cli(c(script, "--no_such_flag")), "Unknown option")
  expect_identical(prompt_scene_choice(c("A", "B"), input = "2"), "B")
  expect_identical(prompt_scene_choice(c("A", "B"), input = "*"), c("A", "B"))
  expect_error(prompt_scene_choice(c("A", "B"), input = "5"), "Invalid scene numbers")
  dir <- withr_tempdir()
  out <- manim_cli(c(script, "A", "-s", "-ql", "--media_dir", dir, "-v", "warning"))
  expect_match(out, "A_manimR_v.*\\.png$")
})

test_that("play hashes include private settings and global values", {
  sc <- Scene$new(skip_animations = TRUE)
  h <- function(anims) get_hash_from_play_call(sc, sc$camera, anims, list())
  expect_false(identical(h(list(Transform(Square(), Circle(), path_arc = 0))),
                         h(list(Transform(Square(), Circle(), path_arc = PI)))))
  speed <- 1
  m1 <- Square()$add_updater(function(m, dt) m$shift(speed * dt * RIGHT))
  a <- get_hash_from_play_call(sc, sc$camera, list(), list(m1))
  speed <- 2
  b <- get_hash_from_play_call(sc, sc$camera, list(), list(m1))
  expect_false(identical(a, b))
  expect_match(a, "^[0-9a-f]{64}$")
  # Cycles end in placeholders.
  g1 <- Group(Square())
  g2 <- Group(g1)
  g1$add(g2)
  expect_match(get_hash_from_play_call(sc, sc$camera, list(), list(g1)), "^[0-9a-f]{64}$")
})

test_that("upstream fixes: vectors, curves, colors, families", {
  expect_equal(rotate_vector(c(1, 0), PI / 2), c(0, 1, 0))
  expect_error(rotate_vector(1:4, 1), "dimensions")
  expect_equal(Line(ORIGIN, RIGHT)$proportion_from_point(c(0.123, 0, 0)), 0.123, tolerance = 1e-9)
  expect_error(Line(ORIGIN, RIGHT)$proportion_from_point(c(0.5, 1, 0)), "does not lie")
  col <- rgba_to_color(c(1, 0, 0, 0.25))
  expect_equal(ManimColor(col)$to_rgba(), c(1, 0, 0, 0.25))
  expect_equal(color_to_rgb(rgb_to_color(c(0.1, 0.2, 0.3))), c(0.1, 0.2, 0.3))
  expect_equal(ManimColor(interpolate_color(rgba_to_color(c(0, 0, 0, 0)), WHITE, 0.5))$to_rgba(), c(0.5, 0.5, 0.5, 0.5))
  a <- Group()
  b <- Group(a)
  a$add(b)
  fam <- a$get_family()
  expect_length(fam, 2)
})

test_that("VDict adds, removes and replaces by key", {
  d <- VDict()
  d$add(list(a = Square()))
  expect_true(inherits(d[["a"]], "Square"))
  d$add(list(list("b", Circle())))
  expect_true(d$has_key("b"))
  d$remove("a")
  expect_false(d$has_key("a"))
  expect_length(d$submobjects, 1)
  expect_error(d$remove("zz"), "not present")
  d[["b"]] <- Triangle()
  expect_true(inherits(d$get("b"), "Triangle"))
  expect_length(d$submobjects, 1)
  expect_error(VDict(list(a = Mobject())), "VMobject")
  skip_if_not(latex_works())
  skip_on_cran()
  k <- VDict(list(s = Square()), show_keys = TRUE)
  expect_true(any(vapply(k[["s"]]$submobjects, function(m) inherits(m, "Tex"), NA)))
})

test_that("Text keeps whitespace as characters with disable_ligatures", {
  t <- Text("a b", disable_ligatures = TRUE)
  expect_length(t, 3)
  expect_equal(t[2]$width, 0)
  expect_length(t$chars, 3)
  expect_length(Text("a b"), 2)
  t2 <- Text("xy", text2color = list(x = RED))
  expect_identical(manim_color(t2[1]$get_fill_color()), manim_color(RED))
})

test_that("spring layouts honor dim, center and fixed vertices", {
  g <- Graph(1:4, list(c(1, 2), c(2, 3)), layout = "spring", layout_config = list(dim = 3, seed = 1))
  z <- vapply(g$vertices, function(v) v$get_center()[3], 0)
  expect_true(any(abs(z) > 1e-6))
  pos <- graph_layout_spring(g, center = c(1, 1), seed = 1)
  expect_equal(Reduce(`+`, pos)[1:2] / 4, c(1, 1), tolerance = 1e-8)
  fixed <- graph_layout_spring(g, pos = list(`1` = c(0, 0)), fixed = "1", seed = 2)
  expect_equal(fixed[["1"]], c(0, 0, 0))
})

test_that("constructor functions have their own class generators", {
  expect_true(inherits(MathTableClass, "R6ClassGenerator"))
  expect_identical(MathTableClass$get_inherit()$classname, "Table")
  expect_s3_class(ReplacementTransform(Square(), Circle()), "Transform")
  expect_s3_class(Star(), "Star")
  on.exit(set_default(Star), add = TRUE)
  set_default(Star, n = 7)
  expect_equal(nrow(Star()$get_vertices()), 14)
  expect_equal(nrow(Star(n = 5)$get_vertices()), 10)
  expect_equal(nrow(RegularPolygon()$get_vertices()), 6)
  Sub <- R6::R6Class("Sub", inherit = StarClass)
  expect_s3_class(Sub$new(), "Star")
  skip_if_not(latex_works())
  skip_on_cran()
  expect_s3_class(MathTable(list(c("1", "2"))), "MathTable")
})

test_that("OpenGL point clouds take an opacity", {
  p <- OpenGLPMobject()
  p$add_points(matrix(0, 2, 3), color = RED, opacity = 0.25)
  expect_equal(p$rgbas[nrow(p$rgbas), 4], 0.25)
  p$add_points(matrix(0, 1, 3), color = BLUE)
  expect_equal(p$rgbas[nrow(p$rgbas), 4], 0.25)
})

test_that("mirrored and sheared images are drawn through their corners", {
  img <- ImageMobject(rbind(c("red", "red"), c("blue", "blue")))
  img$height <- 2
  render_at <- function(m) {
    cam <- CameraClass$new(pixel_width = 64, pixel_height = 36)
    cap <- ragg::agg_capture(width = 64, height = 36, units = "px", res = 96)
    on.exit(grDevices::dev.off(), add = TRUE)
    grid::grid.newpage()
    cam$draw_frame(list(m))
    cap(native = FALSE)
  }
  up <- render_at(img)
  down <- render_at(img$copy()$flip(RIGHT))
  expect_false(identical(up, down))
  sheared <- img$copy()$apply_matrix(rbind(c(1, 0.5, 0), c(0, 1, 0), c(0, 0, 1)))
  expect_silent(render_at(sheared))
})

test_that("camera backgrounds set from pixels or functions are drawn", {
  cam <- CameraClass$new(pixel_width = 16, pixel_height = 9)
  cam$set_background_from_func(function(p) c(1, 0, 0, 1))
  cap <- ragg::agg_capture(width = 16, height = 9, units = "px", res = 96)
  on.exit(grDevices::dev.off(), add = TRUE)
  grid::grid.newpage()
  cam$draw_frame(list())
  px <- cap(native = FALSE)
  expect_equal(as.numeric(grDevices::col2rgb(px[5, 8])), c(255, 0, 0))
})

test_that("render output prints into knitr documents and Shiny apps", {
  skip_if_not_installed("knitr")
  png <- tempfile(fileext = ".png")
  png::writePNG(array(1, c(2, 2, 3)), png)
  out <- structure(png, class = "manim_output")
  res <- knit_print.manim_output(out, options = list(label = "x", fig.path = paste0(tempdir(), "/kp-")))
  expect_s3_class(res, "knit_asis")
  skip_if_not_installed("shiny")
  expect_s3_class(manimOutput("a"), "shiny.tag")
  expect_true(is.function(renderManim(png)))
})

test_that("plots, single frames and igraph graphs become manimR objects", {
  skip_if_not(isTRUE(capabilities("cairo")))
  m <- as_mobject(function() plot(1:3), height_units = 4)
  expect_true(is_mobject(m))
  expect_equal(m$height, 4, tolerance = 1e-6)
  sc <- function(self) {
    s <- Square()
    self$play(s$animate$shift(RIGHT * 2), run_time = 2)
    self$play(s$animate$shift(UP), run_time = 1)
  }
  f <- scene_frame(sc, t = 1, quality = "l")
  expect_s3_class(f, "manim_frame_image")
  expect_identical(dim(f), c(480L, 854L))
  expect_false(identical(f, scene_frame(sc, t = Inf, quality = "l")))
  skip_if_not_installed("igraph")
  g <- igraph::make_ring(4)
  G <- GraphClass$from_igraph(g, layout = "circular")
  expect_length(G$vertices, 4)
  expect_length(G$edges, 4)
  D <- DiGraphClass$from_igraph(igraph::make_graph(c("a", "b", "b", "c"), directed = TRUE))
  expect_s3_class(D, "DiGraph")
})

test_that("upstream style constructors, size methods, indexing and group arithmetic", {
  expect_s3_class(Mobject(), "Mobject")
  expect_s3_class(Camera(pixel_width = 32, pixel_height = 18), "Camera")
  a <- Arrow(LEFT, RIGHT, tip_shape = ArrowSquareTip)
  expect_true(any(vapply(a$submobjects, function(m) inherits(m, "ArrowSquareTip"), NA)))
  s <- Square()
  expect_equal(s$get_width(), 2)
  s$set_height(4)
  expect_equal(s$height, 4)
  c1 <- Circle()
  expect_length(c1, 1)
  expect_identical(c1[1], c1)
  g <- VGroup(Square(), Circle())
  g2 <- g + Triangle()
  expect_s3_class(g2, "VGroup")
  expect_length(g2, 3)
  expect_length(g2 - g2[3], 2)
  g[2] <- Dot()
  expect_s3_class(g[2], "Dot")
  expect_error(Circle(raduis = 2), "unexpected argument")
  expect_equal(Square()$shift(c(3, 1, 0))$apply_matrix(diag(c(2, 1)), about_edge = LEFT)$get_center(),
               c(4, 1, 0))
  sc <- Scene$new()
  expect_error(sc$replace(Circle(), Square()), "Could not find")
  expect_identical(manim_color("0xFF0000"), "#FF0000")
})

test_that("frame width stays upstream's 14.22 at every quality", {
  tempconfig(list(quality = "l"), {
    expect_equal(config$frame_width, 8 * 16 / 9)
    cam <- CameraClass$new()
    expect_equal(cam$frame_height, cam$frame_width * 480 / 854)
  })
})

test_that("MarkupText wraps at upstream's layout width and justifies", {
  long <- paste(rep("word", 40), collapse = " ")
  j <- MarkupText(long, justify = TRUE)
  expect_equal(j$width, 2400 / 48 * 48 / 72, tolerance = 0.02)
  expect_gt(j$height, MarkupText("word")$height * 1.5)
})

test_that("scripts are sourced without running their render calls", {
  f <- tempfile(fileext = ".R")
  writeLines(c("A <- manim_scene(function(self) self$add(Circle()), name = 'A')",
               "render(A, output_file = 'should_not_exist')"), f)
  expect_named(find_scenes(f), "A")
  expect_false(file.exists("should_not_exist.png"))
})

test_that("hidden SVG elements are not imported", {
  f <- tempfile(fileext = ".svg")
  writeLines(c('<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">',
               '<rect x="0" y="0" width="10" height="10"/>',
               '<rect x="20" y="0" width="10" height="10" display="none"/>',
               '<g style="display:none"><circle cx="50" cy="50" r="5"/></g>',
               '<rect x="40" y="0" width="10" height="10" visibility="hidden"/>',
               '</svg>'), f)
  expect_length(SVGMobject(f)$submobjects, 1)
})

test_that("config files are found where upstream looks for them", {
  paths <- config_file_paths()
  expect_named(paths, c("library_wide", "user_wide", "folder_wide"))
  expect_equal(paths[["folder_wide"]], "manim.cfg")
  d <- withr_tempdir()
  writeLines(c("[CLI]", "frame_rate = 24"), file.path(d, "manim.cfg"))
  old <- setwd(d)
  on.exit(setwd(old), add = TRUE)
  with_manim_config(list(), {
    manimR:::digest_startup_config_files()
    expect_equal(config$frame_rate, 24)
  })
})

test_that("config has upstream's digest_file, get_dir and update methods", {
  f <- tempfile(fileext = ".cfg")
  writeLines(c("[CLI]", "frame_rate = 12"), f)
  with_manim_config(list(), {
    config$digest_file(f)
    expect_equal(config$frame_rate, 12)
    config$update(list(frame_rate = 20))
    expect_equal(config$frame_rate, 20)
    expect_match(config$get_dir("video_dir", module_name = "m"), "videos")
  })
})
