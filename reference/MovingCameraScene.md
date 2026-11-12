# MovingCameraScene

A [Scene](https://adamrsophie.github.io/manimR/reference/Scene.md) whose
camera is a
[MovingCameraClass](https://adamrsophie.github.io/manimR/reference/MovingCameraClass.md).
Animate `self$camera$frame` to pan and zoom.

## Value

An R6 class generator. A scene class inherits from it, and `$new()`
creates a scene.

## Examples

``` r
Zoom <- R6::R6Class("Zoom", inherit = MovingCameraScene, public = list(
  construct = function() {
    dot <- Dot(2 * RIGHT)
    self$add(Square(), dot)
    self$camera$frame$save_state()
    self$play(self$camera$frame$animate$scale(0.5)$move_to(dot))
    self$play(Restore(self$camera$frame))
  }))
# The last frame as a PNG file in the session's temporary directory.
render(Zoom, quality = "l", format = "png", media_dir = tempdir())
#> INFO File ready at '/tmp/RtmpQemhr4/images/manimR/Zoom_manimR_v0.1.0.png'
#> INFO Rendered Zoom
#> Played 2 animations
if (FALSE) { # \dontrun{
# A video in the media folder (by default in the session's temporary
# directory); this needs ffmpeg.
render(Zoom, quality = "l")
} # }
```
