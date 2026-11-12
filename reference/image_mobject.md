# Image mobjects

`ImageMobject()` displays a raster image from a PNG file or a numeric
array with values from 0 to 255 (a matrix for grayscale, or an
`h x w x 3` or `h x w x 4` array). Its corner points are, in order,
upper left, upper right, lower left and lower right, so it moves, scales
and rotates like any mobject. `get_raster()` returns an array in
`[0, 1]` suitable for
[`grid::grid.raster()`](https://rdrr.io/r/grid/grid.raster.html).

`ImageMobjectFromCamera()` shows what a
[MovingCameraClass](https://adamrsophie.github.io/manimR/reference/MovingCameraClass.md)
camera sees; it is drawn by
[MultiCameraClass](https://adamrsophie.github.io/manimR/reference/MultiCameraClass.md)
(see
[ZoomedScene](https://adamrsophie.github.io/manimR/reference/ZoomedScene.md)).

## Usage

``` r
ImageMobject(
  filename_or_array,
  scale_to_resolution = QUALITIES$high_quality$pixel_height,
  invert = FALSE,
  image_mode = "RGBA",
  ...
)

ImageMobjectFromCamera(camera, default_display_frame_config = NULL, ...)

AbstractImageMobject(
  scale_to_resolution,
  pixel_array_dtype = "uint8",
  resampling_algorithm = "bicubic",
  ...
)
```

## Arguments

- filename_or_array:

  Path to a PNG file (a single string), a numeric array, a raster from
  [`grDevices::as.raster()`](https://rdrr.io/r/grDevices/as.raster.html),
  a `nativeRaster`, or a character matrix of colors.

- scale_to_resolution:

  Pixel height shown pixel for pixel, so the image height is
  `nrow / scale_to_resolution * frame_height`.

- invert:

  Invert the image colors.

- image_mode:

  Mode a PNG file is converted to after reading, as PIL does: `"RGBA"`,
  `"RGB"` (drops the alpha channel) or `"L"` (luminance). Arrays and
  rasters are used as given. Images are then stored as RGBA, 0 to 255.

- ...:

  Further arguments for
  [MobjectClass](https://adamrsophie.github.io/manimR/reference/MobjectClass.md).

- camera:

  A
  [MovingCameraClass](https://adamrsophie.github.io/manimR/reference/MovingCameraClass.md)
  camera.

- default_display_frame_config:

  List of style arguments for the frame added by `add_display_frame()`.

- pixel_array_dtype:

  Type of the stored pixel values; only `"uint8"` (0 to 255) is used.

- resampling_algorithm:

  How the image is sampled when drawn: a name in
  [RESAMPLING_ALGORITHMS](https://adamrsophie.github.io/manimR/reference/RESAMPLING_ALGORITHMS.md),
  `"bicubic"` by default.

## Examples

``` r
img <- ImageMobject(matrix(c(0, 100, 30, 200, 255, 0, 5, 33), 2, byrow = TRUE))
img$height <- 7
img$set_resampling_algorithm("nearest")
```
