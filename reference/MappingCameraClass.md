# MappingCamera, OldMultiCamera and SplitScreenCamera

`MappingCameraClass` draws every point through `mapping_func` (curves
are subdivided first so the image bends smoothly). `OldMultiCameraClass`
composites several cameras at pixel offsets, and
`SplitScreenCameraClass` puts two cameras side by side. Use them through
a scene's `default_camera_class()` or `Scene$new(camera_class = ...)`.

## Usage

``` r
MappingCamera(
  mapping_func = function(p) p,
  min_num_curves = 50,
  allow_object_intrusion = FALSE,
  ...
)

OldMultiCamera(..., cameras_with_start_positions = NULL)

SplitScreenCamera(left_camera, right_camera, ...)
```

## Arguments

- mapping_func:

  Function of a point returning a point.

- min_num_curves:

  Minimum number of curves per VMobject before mapping.

- allow_object_intrusion:

  Map the scene's mobjects in place instead of copies.

- ...:

  Passed to
  [CameraClass](https://adamrsophie.github.io/manimR/reference/CameraClass.md).

- cameras_with_start_positions:

  Lists of `list(camera, c(start_y, start_x))` in pixels.

- left_camera, right_camera:

  Cameras for each half.

## Value

A camera: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.
