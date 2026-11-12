# ThreeDCamera

A camera looking at the scene from spherical angles `phi` (polar, off
the z axis) and `theta` (azimuth), rotated by `gamma` about its line of
sight, with a perspective projection of strength `focal_distance` and a
`zoom` factor. Mobjects with `shade_in_3d = TRUE` are sorted by depth
and shaded by their normal against `light_source`. The angles live in
[`ValueTracker()`](https://adamrsophie.github.io/manimR/reference/ValueTrackerClass.md)s
(`phi_tracker`, `theta_tracker`, `gamma_tracker`,
`focal_distance_tracker`, `zoom_tracker`) so they can be animated.

`get_frame_center()` is the 3D point shown at the center of the screen.
Upstream manim subtracts the frame center twice (once in the projection
and once in the 2D view); here it is subtracted once, so a point at the
frame center lands at the screen center and fixed in frame mobjects
really stay fixed.

## Usage

``` r
ThreeDCamera(
  focal_distance = 20,
  shading_factor = 0.2,
  default_distance = 5,
  light_source_start_point = 9 * DOWN + 7 * LEFT + 10 * OUT,
  should_apply_shading = TRUE,
  exponential_projection = FALSE,
  phi = 0,
  theta = -90 * DEGREES,
  gamma = 0,
  zoom = 1,
  frame_center = ORIGIN,
  ...
)
```

## Arguments

- focal_distance:

  Distance from the camera to the frame center; smaller values give a
  stronger perspective.

- shading_factor, default_distance:

  Kept for compatibility with Manim.

- light_source_start_point:

  Initial position of the light source.

- should_apply_shading:

  Shade mobjects that have `shade_in_3d = TRUE`.

- exponential_projection:

  Scale points in front of the frame by an exponential rather than the
  usual perspective factor.

- phi, theta, gamma:

  Polar angle, azimuth and roll of the camera, in radians.

- zoom:

  Zoom factor.

- frame_center:

  3D point shown at the center of the screen.

- ...:

  Passed to
  [CameraClass](https://adamrsophie.github.io/manimR/reference/CameraClass.md).

## Details

Shaded strokes are drawn in the mean of their two shaded colors rather
than as a gradient, which grid can only do through a costly mask.
