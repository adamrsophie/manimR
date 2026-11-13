# ZoomedScene

A
[MovingCameraScene](https://adamrsophie.github.io/manimR/reference/MovingCameraScene.md)
with a second camera whose view is shown in a display in a corner of the
screen. Call `activate_zooming()` to show the zoomed camera frame and
its display, then move `self$zoomed_camera$frame`. The display is drawn
as vector graphics clipped to the display rectangle rather than as a
pixel copy of the zoomed camera.

## Value

An R6 class generator. A scene class inherits from it, and `$new()`
creates a scene.

## Details

Initializer arguments (override `initialize()` in a subclass to change
them): `zoomed_display_height`, `zoomed_display_width`,
`zoomed_display_center` (overrides the corner), `zoomed_display_corner`,
`zoomed_display_corner_buff`, `zoomed_camera_config` (list of
[MovingCameraClass](https://adamrsophie.github.io/manimR/reference/MovingCameraClass.md)
arguments), `zoomed_camera_image_mobject_config`,
`zoomed_camera_frame_starting_position`, `zoom_factor` (zoomed frame
size over display size, 0.15), `image_frame_stroke_width` and
`zoom_activated`.

## Examples

``` r
UseZoomedScene <- R6::R6Class("UseZoomedScene", inherit = ZoomedScene, public = list(
  construct = function() {
    dot <- Dot()$set_color(GREEN)
    self$add(dot)
    self$wait(1)
    self$activate_zooming(animate = FALSE)
    self$wait(1)
    self$play(dot$animate$shift(LEFT))
  }))
# The last frame as a PNG file in the session's temporary directory.
render(UseZoomedScene, quality = "l", format = "png", media_dir = tempdir())
#> INFO File ready at '/tmp/RtmpJIK9nH/images/manimR/UseZoomedScene_manimR_v0.1.0.png'
#> INFO Rendered UseZoomedScene
#> Played 3 animations
if (FALSE) { # \dontrun{
# A video in the media folder (by default in the session's temporary
# directory); this needs ffmpeg.
render(UseZoomedScene, quality = "l")
} # }
```
