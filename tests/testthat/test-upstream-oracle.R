# Compare manimR geometry with reference output dumped from Python manim by
# data-raw/upstream_oracle.py.

oracle_file <- test_path("fixtures", "upstream_oracle.json")

read_oracle <- function() {
  skip_if_not_installed("jsonlite")
  jsonlite::fromJSON(oracle_file, simplifyVector = FALSE)
}

as_mat <- function(x) {
  if (length(x) == 0) return(matrix(0, 0, 3))
  do.call(rbind, lapply(x, unlist))
}

expect_points <- function(mob_points, ref, tol = 1e-6) {
  ref <- as_mat(ref)
  expect_equal(dim(mob_points), dim(ref))
  expect_equal(unname(mob_points), unname(ref), tolerance = tol)
}

expect_family <- function(mob, ref, tol = 1e-6) {
  fam <- mob$family_members_with_points()
  expect_equal(length(fam), length(ref))
  for (i in seq_along(ref)) expect_points(fam[[i]]$points, ref[[i]], tol)
}

test_that("basic shapes match upstream points", {
  o <- read_oracle()
  expect_points(Circle()$points, o$circle)
  expect_points(Circle(radius = 2)$shift(LEFT)$points, o$circle_r2)
  expect_points(Square()$points, o$square)
  expect_points(Arc(radius = 1.5, start_angle = 0.3, angle = 2)$points, o$arc)
  expect_points(ArcBetweenPoints(LEFT, RIGHT + UP, angle = PI / 3)$points, o$arc_between)
  expect_points(Ellipse(width = 3, height = 1)$points, o$ellipse)
  expect_points(Star()$points, o$star)
  expect_points(RegularPolygon(6)$points, o$hexagon)
  expect_points(RoundedRectangle(corner_radius = 0.3, width = 3, height = 2)$points, o$rounded_rect)
  expect_points(Line(LEFT * 2, RIGHT * 2 + UP, buff = 0.3)$points, o$line_buff)
  expect_family(Arrow(LEFT, RIGHT + UP), o$arrow)
  expect_points(Annulus()$points, o$annulus)
  expect_points(AnnularSector()$points, o$annular_sector)
  expect_family(DashedLine(LEFT * 2, RIGHT * 2), o$dashed_line)
})

test_that("smooth curves match upstream handles", {
  o <- read_oracle()
  v <- VMobject()$set_points_smoothly(rbind(LEFT * 2, UP, RIGHT, DOWN * 0.5 + RIGHT * 2))
  expect_points(v$points, o$smooth_open)
  # A closed curve that starts at a negative x.
  v <- VMobject()$set_points_smoothly(rbind(LEFT, UP, RIGHT, DOWN, LEFT))
  expect_points(v$points, o$smooth_closed)
})

test_that("alignment and transforms match upstream", {
  o <- read_oracle()
  a <- Square()$rotate(PI / 4)
  b <- Circle()
  a$align_data(b)
  expect_points(a$points, o$align_square_circle$a)
  expect_points(b$points, o$align_square_circle$b)

  g1 <- VGroup(Square(), Circle()$shift(RIGHT * 2))
  g2 <- VGroup(Star(), Square()$shift(UP), Dot(LEFT * 2))
  g1$align_data(g2)
  expect_family(g1, o$align_groups$a)
  expect_family(g2, o$align_groups$b)

  t <- Transform(Square()$rotate(PI / 4), Circle())
  t$begin()
  t$interpolate(0.37)
  expect_points(t$mobject$points, o$transform_037)

  t <- Transform(Square(), Circle()$shift(RIGHT), path_arc = PI / 2)
  t$begin()
  t$interpolate(0.5)
  expect_points(t$mobject$points, o$transform_arc_05)

  p <- Circle()
  p$pointwise_become_partial(Circle(), 0.2, 0.7)
  expect_points(p$points, o$partial_02_07)
  p <- Square()
  p$pointwise_become_partial(Square(), 0, 0.33)
  expect_points(p$points, o$partial_square)

  expect_points(bezier_remap(Square()$points, 7), o$bezier_remap)
  expect_points(partial_bezier_points(Circle()$points[1:4, ], 0.25, 0.8), o$partial_bezier)
})

test_that("positioning matches upstream", {
  o <- read_oracle()
  expect_equal(Square()$next_to(Circle(), RIGHT, buff = 0.5)$get_center(), unlist(o$next_to), tolerance = 1e-9)
  expect_equal(Square(side_length = 1)$to_corner(UP + LEFT)$get_center(), unlist(o$to_corner), tolerance = 1e-9)
  g <- VGroup(lapply(1:7, function(i) Square(side_length = 0.5)))$arrange_in_grid()
  centers <- do.call(rbind, lapply(g$submobjects, function(m) m$get_center()))
  expect_equal(unname(centers), unname(as_mat(o$arrange_in_grid)), tolerance = 1e-9)
})

test_that("LaTeX output matches upstream", {
  skip_if(!nzchar(Sys.which("latex")) || !nzchar(Sys.which("dvisvgm")), "LaTeX not available")
  skip_on_cran()
  o <- read_oracle()
  old <- manim_config(media_dir = file.path(tempdir(), "manimR-test-media"))
  on.exit(.manim$config <- old)
  m <- MathTex("e^{i\\pi} + 1 = 0")
  expect_equal(c(m$width, m$height), unlist(o$mathtex_size), tolerance = 1e-3)
  m <- MathTex("a^2", "+", "b^2")
  expect_equal(length(m$submobjects), o$mathtex_parts[[1]])
  expect_equal(vapply(m$submobjects, function(p) length(p$submobjects), 1L), unlist(o$mathtex_parts[[2]]))
  expect_points(Brace(Square(), DOWN)$points, o$brace, tol = 1e-4)
})

test_that("rate functions match upstream", {
  o <- read_oracle()
  ts <- c(0, 0.1, 0.25, 0.5, 0.73, 0.9, 1)
  for (nm in names(o$rate_functions)) {
    r_name <- if (nm == "smooth") "smooth_rate" else nm
    f <- get(r_name, envir = asNamespace("manimR"))
    expect_equal(vapply(ts, f, numeric(1)), unlist(o$rate_functions[[nm]]), tolerance = 1e-9, label = nm)
  }
})

anim_state <- function(anim, alpha) {
  anim$begin()
  anim$interpolate(alpha)
  anim$mobject
}

test_that("animations match upstream at intermediate alphas", {
  o <- read_oracle()
  expect_family(anim_state(Create(VGroup(Square(), Circle()$shift(RIGHT))), 0.4), o$create_04)
  expect_family(anim_state(DrawBorderThenFill(Square()$set_fill(BLUE, 1)), 0.3), o$dbtf_03)
  expect_family(anim_state(DrawBorderThenFill(Square()$set_fill(BLUE, 1)), 0.7), o$dbtf_07)
  expect_family(anim_state(FadeIn(Square(), shift = UP, scale = 0.5), 0.5), o$fadein_shift_05)
  expect_family(anim_state(FadeOut(Circle(), target_position = RIGHT * 2), 0.5), o$fadeout_05)
  expect_family(anim_state(GrowFromCenter(Star()), 0.3), o$grow_center_03)
  expect_family(anim_state(GrowArrow(Arrow(LEFT, RIGHT)), 0.5), o$grow_arrow_05)
  expect_family(anim_state(Rotate(Square(), PI / 3), 0.5), o$rotate_05)
  expect_family(anim_state(Indicate(Square()), 0.5), o$indicate_05)
  expect_family(anim_state(ShowPassingFlash(Circle(), time_width = 0.3), 0.4), o$flash_04)
  expect_family(anim_state(SpinInFromNothing(Square()), 0.5), o$spin_05)
  expect_family(anim_state(Wiggle(Square()), 0.3), o$wiggle_03)
  expect_family(anim_state(ApplyWave(Line(LEFT * 2, RIGHT * 2)), 0.4), o$wave_04)
  g <- VGroup(lapply(0:3, function(i) Square(side_length = 0.5)$shift(RIGHT * i)))
  expect_family(anim_state(LaggedStart(lapply(g$submobjects, FadeIn), lag_ratio = 0.5), 0.5), o$lagged_05)
  ag <- AnimationGroup(FadeIn(Square()), Create(Circle(), run_time = 2), lag_ratio = 0.5)
  expect_equal(c(ag$run_time, ag$anim_starts, ag$anim_ends), unlist(o$group_timing))
})

test_that("Write on MathTex matches upstream", {
  skip_if(!nzchar(Sys.which("latex")) || !nzchar(Sys.which("dvisvgm")), "LaTeX not available")
  skip_on_cran()
  o <- read_oracle()
  old <- manim_config(media_dir = file.path(tempdir(), "manimR-test-media"))
  on.exit(.manim$config <- old)
  m <- anim_state(Write(MathTex("abc")), 0.5)
  expect_family(m, o$write_text_05, tol = 1e-4)
  st <- t(vapply(m$family_members_with_points(), function(sm) c(sm$get_stroke_width(), sm$get_fill_opacity()), numeric(2)))
  expect_equal(unname(st), unname(as_mat(o$write_text_05_style))[, 1:2], tolerance = 1e-6)
})
