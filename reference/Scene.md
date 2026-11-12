# Scene

The canvas on which animations play. Subclass it and define
`construct()`, then pass the class to
[`render()`](https://adamrsophie.github.io/manimR/reference/render.md):

    SquareToCircle <- R6::R6Class("SquareToCircle", inherit = Scene,
      public = list(construct = function() {
        circle <- Circle()$set_fill(PINK, opacity = 0.5)
        square <- Square()$rotate(PI / 4)
        self$play(Create(square))
        self$play(Transform(square, circle))
        self$play(FadeOut(square))
      }))
    render(SquareToCircle, quality = "l")

Or use the functional form
[`manim_scene()`](https://adamrsophie.github.io/manimR/reference/manim_scene.md).

## Value

An R6 class generator. A scene class inherits from it, and `$new()`
creates a scene.
