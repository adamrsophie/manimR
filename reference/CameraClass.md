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
  background_image = NULL,
  frame_center = ORIGIN,
  image_mode = "RGBA",
  n_channels = 4,
  pixel_array_dtype = "uint8",
  cairo_line_width_multiple = 0.01,
  use_z_index = TRUE,
  background = NULL,
  pixel_height = cfg("pixel_height"),
  pixel_width = cfg("pixel_width"),
  frame_height = cfg("frame_height"),
  frame_width = cfg("frame_width"),
  frame_rate = cfg("frame_rate"),
  background_color = cfg("background_color"),
  background_opacity = cfg("background_opacity"),
  ...
)
```

## Arguments

- background_image:

  Path of an image (found with
  [`get_full_raster_image_path()`](https://adamrsophie.github.io/manimR/reference/path_helpers.md))
  drawn as the background.

- frame_center:

  Point at the center of the frame.

- image_mode, n_channels, pixel_array_dtype:

  Layout of the pixel array (see `$get_pixel_array()`): `"RGBA"`, 4
  channels and `"uint8"` values, as upstream. `pixel_array_dtype` sets
  the largest channel value (`rgb_max_val`).

- cairo_line_width_multiple:

  Scale of stroke widths, as upstream's.

- use_z_index:

  Draw mobjects in order of their `z_index`.

- background:

  Accepted as upstream, where the background built from
  `background_image` or `background_color` replaces it.

- pixel_width, pixel_height:

  Size of the frame in pixels.

- frame_width, frame_height:

  Size of the frame in scene units; as upstream, the camera keeps the
  frame width and derives its height from the pixel aspect ratio.

- frame_rate:

  Frames per second.

- background_color, background_opacity:

  Color and opacity of the background.

- ...:

  Ignored.

## Value

A `Camera`, an R6 object. `CameraClass` is its R6 class generator.
