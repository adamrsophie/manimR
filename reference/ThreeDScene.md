# ThreeDScene

A [Scene](https://adamrsophie.github.io/manimR/reference/Scene.md) with
a
[ThreeDCameraClass](https://adamrsophie.github.io/manimR/reference/ThreeDCameraClass.md).
Set the view with
`set_camera_orientation(phi, theta, gamma, zoom, focal_distance, frame_center)`,
animate it with `move_camera()`, and spin it with
`begin_ambient_camera_rotation(rate, about)`. Mobjects passed to
`add_fixed_in_frame_mobjects()` ignore the camera (titles, labels);
those passed to `add_fixed_orientation_mobjects()` keep facing the
viewer while their center follows the 3D projection.

`SpecialThreeDScene` adds default sphere and camera settings.

Initializer arguments: `ambient_camera_rotation` (kept for
compatibility), `default_angled_camera_orientation_kwargs` (angles for
`set_to_default_angled_camera_orientation()`); the rest go to
[Scene](https://adamrsophie.github.io/manimR/reference/Scene.md) and on
to the camera, for example `should_apply_shading = FALSE`.
`SpecialThreeDScene` also takes `camera_config`, `three_d_axes_config`,
`sphere_config`, `default_angled_camera_position` and
`low_quality_config` (used when rendering at low quality).

## Value

R6 class generators. A scene class inherits from one of them, and
`$new()` creates a scene.

## Examples

``` r
Spin <- R6::R6Class("Spin", inherit = ThreeDScene, public = list(
  construct = function() {
    self$set_camera_orientation(phi = 75 * DEGREES, theta = 30 * DEGREES)
    self$add(Sphere(radius = 1.5)$shift(LEFT * 2), Cube()$shift(RIGHT * 2))
    self$begin_ambient_camera_rotation(rate = 0.5)
    self$wait(2)
  }))
if (FALSE) { # \dontrun{
# A video in the folder media of the working directory; this needs ffmpeg.
render(Spin, quality = "l")
} # }
```
