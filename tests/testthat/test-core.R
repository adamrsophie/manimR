test_that("copy is deep and keeps internal references consistent", {
  a <- Arrow(LEFT, RIGHT)
  b <- a$copy()
  expect_false(identical(a$mob_id, b$mob_id))
  expect_true(b$tip$mob_id %in% b$submobject_ids())
  expect_false(b$tip$mob_id %in% a$submobject_ids())
  b$shift(UP)
  expect_equal(a$get_center()[2], 0)
  expect_equal(b$get_center()[2], 1)
})

test_that("indexing, length and grouping follow 1 based R conventions", {
  g <- VGroup(Circle(), Square(), Dot())
  expect_equal(length(g), 3)
  expect_s3_class(g[2], "Square")
  expect_equal(length(g[-1]), 2)
  expect_s3_class(Circle() + Square(), "Group")
})

test_that("updaters run with and without dt", {
  d <- Dot()
  d$add_updater(function(m, dt) m$shift(RIGHT * dt))
  d$update(0.5)
  expect_equal(d$get_center()[1], 0.5)
  t <- ValueTracker(2)
  d2 <- Dot()
  d2$add_updater(function(m) m$move_to(c(t$get_value(), 0, 0)))
  t$set_value(3)
  d2$update(0)
  expect_equal(d2$get_center()[1], 3)
})

test_that("ValueTracker arithmetic and animate builder work", {
  t <- ValueTracker(2)
  expect_equal((t + 3)$get_value(), 5)
  expect_equal((-t)$get_value(), -2)
  anim <- prepare_animation(t$animate$set_value(10))
  anim$begin()
  anim$interpolate(0.5)
  expect_equal(t$get_value(), 6)
  anim$finish()
  expect_equal(t$get_value(), 10)
})

test_that("scenes produce the same number of frames as upstream", {
  skip_if(!nzchar(Sys.which("ffmpeg")), "ffmpeg not available")
  dir <- withr_tempdir()
  out <- render(function(self) {
    self$play(Create(Circle()))
    self$wait(0.5)
  }, quality = "l", media_dir = dir)
  expect_true(file.exists(out))
  n <- system2("ffprobe", c("-v", "error", "-count_frames", "-select_streams", "v:0", "-show_entries",
                            "stream=nb_read_frames", "-of", "csv=p=0", shQuote(out)), stdout = TRUE)
  expect_equal(as.integer(n), 15 + 7)
})

test_that("scenes without animations save a PNG", {
  dir <- withr_tempdir()
  out <- render(function(self) self$add(Square()), quality = "l", media_dir = dir)
  expect_match(out, "\\.png$")
  expect_true(file.exists(out))
})

test_that("SVG import handles paths, shapes, groups and use elements", {
  f <- tempfile(fileext = ".svg")
  writeLines(c(
    "<svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' viewBox='0 0 100 100'>",
    "<defs><path id='p' d='M0 0 L10 0 L10 10 Z'/></defs>",
    "<g id='grp' fill='red'><rect x='10' y='10' width='20' height='10'/><circle cx='50' cy='50' r='5'/></g>",
    "<use xlink:href='#p' x='70' y='70'/>",
    "<path d='M 0 90 a 5 5 0 1 0 10 0' stroke='blue' fill='none'/>",
    "</svg>"), f)
  s <- SVGMobject(f)
  expect_equal(length(s$submobjects), 4)
  expect_equal(length(s$id_to_vgroup_dict$grp$submobjects), 2)
  expect_equal(s$submobjects[[1]]$get_fill_color(), "#FF0000")
  expect_equal(s$height, 2)
})

test_that("Text maps characters to glyphs and colors substrings", {
  t <- Text("ab cd", t2c = list(cd = RED))
  expect_equal(length(t$submobjects), 4)
  expect_equal(t$submobjects[[3]]$get_fill_color(), "#FC6255")
  expect_equal(t$submobjects[[1]]$get_fill_color(), "#FFFFFF")
  expect_equal(t$font_size, 48)
  t$font_size <- 24
  expect_equal(t$font_size, 24)
})

test_that("colors parse manim names and R colors", {
  expect_equal(manim_color("red"), "#FC6255")
  expect_equal(manim_color("#ff0000"), "#FF0000")
  expect_equal(manim_color(interpolate_color(BLACK, WHITE, 0.5)), "#7F7F7F")
  expect_length(color_gradient(c(RED, BLUE), 5), 5)
  expect_equal(XKCD$AVOCADO, "#90B134")
})

test_that("config quality presets match manim", {
  old <- manim_config(quality = "m")
  on.exit(manim_config(quality = old$quality))
  cfg <- manim_config()
  expect_equal(c(cfg$pixel_width, cfg$pixel_height, cfg$frame_rate), c(1280, 720, 30))
  expect_equal(cfg$frame_width, 8 * 16 / 9)
})

test_that("character keys index VDict and Graph entries", {
  vd <- VDict(list(sq = Square(), ci = Circle()))
  expect_true(inherits(vd["sq"], "Square"))
  expect_true(inherits(vd[["ci"]], "Circle"))
  expect_error(vd["nope"], "No entry")
  expect_true(is.matrix(vd[["points"]]))
  expect_error(Square()["a"], "VDict or a Graph")
})

test_that("ConvexHull accepts a single point matrix", {
  pts <- rbind(c(0, 0, 0), c(2, 0, 0), c(1, 1, 0), c(1, 3, 0))
  expect_equal(ConvexHull(pts)$get_num_points(), ConvexHull(pts[1, ], pts[2, ], pts[3, ], pts[4, ])$get_num_points())
})

test_that("fast_clone matches R6 clone", {
  for (o in list(Circle(), Axes(), Transform(Square(), Circle()))) {
    a <- o$clone(deep = FALSE)
    b <- fast_clone(o)
    expect_setequal(names(a), names(b))
    expect_identical(class(a), class(b))
    for (nm in setdiff(names(a), c(".__enclos_env__", names(a$.__enclos_env__$.__active__)))) {
      va <- .subset2(a, nm)
      vb <- .subset2(b, nm)
      if (is.function(va)) {
        expect_identical(bindingIsLocked(nm, a), bindingIsLocked(nm, b))
        expect_identical(get0("self", environment(vb), inherits = FALSE) %||% b, b)
      } else {
        expect_identical(va, vb)
      }
    }
  }
  c1 <- Circle()
  c2 <- c1$copy()
  c2$shift(RIGHT)
  expect_equal(c1$get_center(), ORIGIN)
  expect_equal(c2$get_center(), RIGHT)
  t1 <- Transform(Square(), Circle(), path_arc = pi / 2)
  t2 <- t1$copy()
  t2$path_arc <- 0
  expect_equal(t1$path_arc, pi / 2)
})

test_that("sections split the movie and can skip animations", {
  skip_if_not(nzchar(Sys.which("ffmpeg")))
  dir <- withr_tempdir()
  sc <- manim_scene(function(self) {
    self$next_section("intro")
    self$play(FadeIn(Square()), run_time = 0.4)
    self$next_section("skipped", skip_animations = TRUE)
    self$play(FadeIn(Circle()), run_time = 0.4)
    self$next_section("Last part!")
    self$wait(0.2)
  }, name = "Sections")
  out <- render(sc, quality = "l", media_dir = dir, save_sections = TRUE)
  sdir <- file.path(dirname(out), "sections")
  idx <- readLines(file.path(sdir, "Sections.json"))
  expect_true(file.exists(file.path(sdir, "Sections_0000_intro.mp4")))
  expect_true(file.exists(file.path(sdir, "Sections_0002_Last-part.mp4")))
  expect_false(any(grepl("skipped", idx)))
  expect_true(any(grepl('"nb_frames": "6"', idx, fixed = TRUE)))
})

test_that("copies stay correct when a class is redefined", {
  Blob <- R6::R6Class("Blob", inherit = CircleClass, lock_objects = FALSE)
  expect_equal(Blob$new()$copy()$get_center(), ORIGIN)
  Blob <- R6::R6Class("Blob", inherit = CircleClass, lock_objects = FALSE,
                      public = list(get_center = function() super$get_center() + 1))
  expect_equal(Blob$new()$copy()$get_center(), c(1, 1, 1))
  Blob2 <- R6::R6Class("Blob2", inherit = CircleClass, lock_objects = FALSE, public = list(tag = function() "m"))
  Blob2$new()$copy()
  Blob2 <- R6::R6Class("Blob2", inherit = CircleClass, lock_objects = FALSE, public = list(tag = NULL))
  b <- Blob2$new()
  b$tag <- Square()
  cp <- b$copy()
  expect_false(identical(cp$tag$mob_id, b$tag$mob_id))
})

test_that("VDict keys never shadow methods or fields", {
  vd <- VDict(list(scale = Circle(), fill_rgbas = Square()))
  expect_true(is.function(vd[["scale"]]))
  expect_true(inherits(vd["scale"], "Circle"))
  expect_silent(prepare_animation(vd$animate$scale(2)))
  vd$set_fill(RED, 1)
  expect_length(vd[c("scale", "fill_rgbas")]$submobjects, 2)
  vd["tri"] <- Triangle()
  expect_true("tri" %in% names(vd$submob_dict))
  expect_true(inherits(vd[["tri"]], "Triangle"))
  sq <- Square()
  expect_error(sq["a"] <- Circle(), "VDict")
})

test_that("plain animation constructors honor overrides", {
  P <- R6::R6Class("P", inherit = SquareClass, lock_objects = FALSE)
  override_animation(P, "Create", function(...) FadeIn(self, ...))
  override_animation(P, "Write", function(...) FadeIn(self, ...))
  override_animation(P, "GrowFromCenter", function(...) FadeIn(self, ...))
  p <- P$new()
  expect_s3_class(Create(p, run_time = 3), "FadeIn")
  expect_equal(Create(p, run_time = 3)$run_time, 3)
  expect_s3_class(Write(p), "FadeIn")
  expect_s3_class(GrowFromCenter(p), "FadeIn")
  expect_s3_class(Create(p, use_override = FALSE), "Create")
})

test_that("gray plus alpha background images are expanded", {
  f <- tempfile(fileext = ".png")
  png::writePNG(array(c(rep(0.5, 12), rep(1, 12)), c(3, 4, 2)), f)
  cam <- CameraClass$new(background_image = f, pixel_width = 4, pixel_height = 3)
  expect_equal(dim(cam$background_image), c(3, 4, 4))
})

test_that("final review fixes hold", {
  vd <- VDict(list(target = Circle()))
  expect_null(vd[["target"]])
  expect_true(inherits(vd["target"], "Circle"))
  G <- R6::R6Class("G", inherit = SquareClass, lock_objects = FALSE)
  G$new()$copy()
  G$set("public", "ping", function() self)
  cp <- G$new()$copy()
  expect_true(bindingIsLocked("ping", cp))
  expect_identical(cp$ping(), cp)
  cam <- CameraClass$new(pixel_width = 40, pixel_height = 20)
  dev <- ragg::agg_capture(width = 40, height = 20, units = "px", res = 96, background = "transparent")
  on.exit(grDevices::dev.off(), add = TRUE)
  grid::grid.newpage(recording = FALSE)
  p <- PMobject(stroke_width = 0)
  p$add_points(matrix(0, 1, 3), color = WHITE)
  withr_cfg <- manim_config(background_opacity = 0)
  on.exit(manim_config(background_opacity = withr_cfg$background_opacity), add = TRUE)
  cam$background_opacity <- 0
  cam$draw_frame(list(p))
  img <- dev(native = FALSE)
  expect_true(all(img == "transparent" | substr(img, 8, 9) == "00"))
})

test_that("copies give private mobject references their own copies", {
  PrivateMob <- R6::R6Class("PrivateMob", inherit = MobjectClass, lock_objects = FALSE,
    public = list(
      initialize = function() {
        super$initialize()
        private$dot <- Dot()
        self$add(private$dot)
      },
      get_dot = function() private$dot
    ),
    private = list(dot = NULL)
  )
  a <- PrivateMob$new()
  b <- a$copy()
  b$get_dot()$shift(RIGHT)
  expect_false(identical(a$get_dot(), b$get_dot()))
  expect_equal(a$get_dot()$get_center(), c(0, 0, 0))
  expect_equal(b$submobjects[[1]]$get_center(), c(1, 0, 0))
})

test_that("Add and TransformMatchingTex use animation overrides", {
  C <- R6::R6Class("OverrideProbe", inherit = CircleClass, lock_objects = FALSE)
  override_animation(C, "Add", function(...) Wait(run_time = 7))
  override_animation(C, "TransformMatchingTex", function(...) Wait(run_time = 7))
  expect_s3_class(Add(C$new()), "Wait")
  expect_s3_class(TransformMatchingTex(C$new(), Circle()), "Wait")
  expect_s3_class(Add(C$new(), use_override = FALSE), "Add")
})
