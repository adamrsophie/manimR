# Display vectorized mobjects colored by a background image

Upstream's pixel based helper for mobjects whose colors come from an
image (`vmobject$color_using_background_image()`). The camera draws such
mobjects itself by masking the image with their shape; this class gives
the same result as an array, as upstream returns it.

## Usage

``` r
BackgroundColoredVMobjectDisplayer(camera)
```

## Arguments

- camera:

  The camera that draws the mobjects.

## Value

A `BackgroundColoredVMobjectDisplayer`, an R6 object.
`BackgroundColoredVMobjectDisplayerClass` is its R6 class generator.

## Details

- `$display(...)` draws the given mobjects in black and white and
  multiplies their coverage with their background image, one batch per
  run of consecutive mobjects sharing an image, keeping the brightest
  value of the batches. It returns an RGBA array of values 0 to 255
  (`pixel_height x pixel_width x 4`), or `NULL` without mobjects.

- `$get_background_array(image)` reads an image (a file name looked up
  with
  [`get_full_raster_image_path()`](https://adamrsophie.github.io/manimR/reference/path_helpers.md),
  or an array of values 0 to 1), resizes it to the camera's pixel size
  and caches it by name.

- `$resize_background_array(background_array, new_width, new_height, mode)`
  resamples an image array with bilinear interpolation (upstream uses
  Pillow's default bicubic filter) and converts it to `"RGBA"` or
  `"RGB"`; `$resize_background_array_to_match()` resizes to the shape of
  another array.
