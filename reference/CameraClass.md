# Camera

Converts mobjects into frames. `CameraClass` handles the standard 2D
view;
[MovingCameraClass](https://adamrsophie.github.io/manimR/reference/MovingCameraClass.md)
adds a movable frame and
[ThreeDCameraClass](https://adamrsophie.github.io/manimR/reference/ThreeDCameraClass.md)
a 3D projection.

## Usage

``` r
Camera(
  pixel_width = cfg("pixel_width"),
  pixel_height = cfg("pixel_height"),
  frame_height = cfg("frame_height"),
  frame_width = cfg("frame_width"),
  frame_center = ORIGIN,
  frame_rate = cfg("frame_rate"),
  background_color = cfg("background_color"),
  background_opacity = cfg("background_opacity"),
  use_z_index = TRUE,
  background_image = NULL,
  cairo_line_width_multiple = 0.01,
  ...
)
```

## Arguments

- pixel_width, pixel_height:

  Size of the frame in pixels.

- frame_width, frame_height:

  Size of the frame in scene units; as upstream, the camera keeps the
  frame width and derives its height from the pixel aspect ratio.

- frame_center:

  Point at the center of the frame.

- frame_rate:

  Frames per second.

- background_color, background_opacity:

  Color and opacity of the background.

- use_z_index:

  Draw mobjects in order of their `z_index`.

- background_image:

  Path of an image (found with
  [`get_full_raster_image_path()`](https://adamrsophie.github.io/manimR/reference/path_helpers.md))
  drawn as the background.

- cairo_line_width_multiple:

  Scale of stroke widths, as upstream's.

- ...:

  Ignored.
