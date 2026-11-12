# Example scenes ported from Manim Community's example_scenes/basic.py.
#
# Render one from R:
#   manimR::render_file(system.file("examples", "basic.R", package = "manimR"),
#                       "SquareToCircle", quality = "l", preview = TRUE)
# or open this file in RStudio, put the cursor inside a scene and use the
# "Render scene at cursor" addin.

library(manimR)

OpeningManim <- R6::R6Class("OpeningManim", inherit = Scene, public = list(construct = function() {
  title <- Tex("This is some \\LaTeX")
  basel <- MathTex("\\sum_{n=1}^\\infty \\frac{1}{n^2} = \\frac{\\pi^2}{6}")
  VGroup(title, basel)$arrange(DOWN)
  self$play(Write(title), FadeIn(basel, shift = DOWN))
  self$wait()

  transform_title <- Tex("That was a transform")
  transform_title$to_corner(UP + LEFT)
  self$play(Transform(title, transform_title),
            LaggedStart(lapply(basel$submobjects, function(obj) FadeOut(obj, shift = DOWN))))
  self$wait()

  grid <- NumberPlane()
  grid_title <- Tex("This is a grid", font_size = 72)
  grid_title$move_to(transform_title)
  self$add(grid, grid_title)
  self$play(FadeOut(title), FadeIn(grid_title, shift = UP), Create(grid, run_time = 3, lag_ratio = 0.1))
  self$wait()

  grid_transform_title <- Tex("That was a non-linear function \\\\ applied to the grid")
  grid_transform_title$move_to(grid_title, UL)
  grid$prepare_for_nonlinear_transform()
  self$play(grid$animate$apply_function(function(p) p + c(sin(p[2]), sin(p[1]), 0)), run_time = 3)
  self$wait()
  self$play(Transform(grid_title, grid_transform_title))
  self$wait()
}))

SquareToCircle <- R6::R6Class("SquareToCircle", inherit = Scene, public = list(construct = function() {
  circle <- Circle()
  square <- Square()
  square$flip(RIGHT)
  square$rotate(-3 * TAU / 8)
  circle$set_fill(PINK, opacity = 0.5)
  self$play(Create(square))
  self$play(Transform(square, circle))
  self$play(FadeOut(square))
}))

WarpSquare <- R6::R6Class("WarpSquare", inherit = Scene, public = list(construct = function() {
  square <- Square()
  self$play(ApplyPointwiseFunction(function(point) complex_to_R3(exp(R3_to_complex(point))), square))
  self$wait()
}))

WriteStuff <- R6::R6Class("WriteStuff", inherit = Scene, public = list(construct = function() {
  example_text <- Tex("This is a some text", tex_to_color_map = list(text = YELLOW))
  example_tex <- MathTex("\\sum_{k=1}^\\infty {1 \\over k^2} = {\\pi^2 \\over 6}")
  group <- VGroup(example_text, example_tex)
  group$arrange(DOWN)
  group$width <- manim_config()$frame_width - 2 * LARGE_BUFF
  self$play(Write(example_text))
  self$play(Write(example_tex))
  self$wait()
}))

UpdatersExample <- R6::R6Class("UpdatersExample", inherit = Scene, public = list(construct = function() {
  decimal <- DecimalNumber(0, show_ellipsis = TRUE, num_decimal_places = 3, include_sign = TRUE)
  square <- Square()$to_edge(UP)
  decimal$add_updater(function(d) d$next_to(square, RIGHT))
  decimal$add_updater(function(d) d$set_value(square$get_center()[2]))
  self$add(square, decimal)
  self$play(square$animate$to_edge(DOWN), rate_func = there_and_back, run_time = 5)
  self$wait()
}))

SpiralInExample <- R6::R6Class("SpiralInExample", inherit = Scene, public = list(construct = function() {
  logo_green <- "#81b29a"
  logo_blue <- "#454866"
  logo_red <- "#e07a5f"
  font_color <- "#ece6e2"
  pi_tex <- MathTex("\\pi")$scale(7)$set_color(font_color)
  pi_tex$shift(2.25 * LEFT + 1.5 * UP)
  circle <- Circle(color = logo_green, fill_opacity = 0.7, stroke_width = 0)$shift(LEFT)
  square <- Square(color = logo_blue, fill_opacity = 0.8, stroke_width = 0)$shift(UP)
  triangle <- Triangle(color = logo_red, fill_opacity = 0.9, stroke_width = 0)$shift(RIGHT)
  pentagon <- Polygon(lapply(0:4, function(i) c(cos(2 * pi / 5 * i), sin(2 * pi / 5 * i), 0)),
                      color = PURPLE_B, fill_opacity = 1, stroke_width = 0)$shift(UP + 2 * RIGHT)
  shapes <- VGroup(triangle, square, circle, pentagon, pi_tex)
  self$play(SpiralIn(shapes, fade_in_fraction = 0.9))
  self$wait()
  self$play(FadeOut(shapes))
}))

LineJoints <- R6::R6Class("LineJoints", inherit = Scene, public = list(construct = function() {
  t1 <- Triangle(stroke_width = 20)
  t2 <- Triangle(stroke_width = 20, joint_type = "round")
  t3 <- Triangle(stroke_width = 20, joint_type = "bevel")
  grp <- VGroup(t1, t2, t3)$arrange(RIGHT)
  grp$width <- manim_config()$frame_width - 1
  self$add(grp)
}))
