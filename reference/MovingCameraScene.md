# MovingCameraScene

A [Scene](https://adamrsophie.github.io/manimR/reference/Scene.md) whose
camera is a
[MovingCameraClass](https://adamrsophie.github.io/manimR/reference/MovingCameraClass.md).
Animate `self$camera$frame` to pan and zoom.

## Examples

``` r
if (FALSE) { # \dontrun{
Zoom <- R6::R6Class("Zoom", inherit = MovingCameraScene, public = list(
  construct = function() {
    dot <- Dot(2 * RIGHT)
    self$add(Square(), dot)
    self$camera$frame$save_state()
    self$play(self$camera$frame$animate$scale(0.5)$move_to(dot))
    self$play(Restore(self$camera$frame))
  }))
render(Zoom, quality = "l")
} # }
```
