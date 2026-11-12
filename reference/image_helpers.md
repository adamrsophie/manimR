# Image array helpers

Ports of `manim.utils.images`, on image arrays of values 0 to 255
(`height x width x channels`, as
[`ImageMobject()`](https://adamrsophie.github.io/manimR/reference/image_mobject.md)
stores them).

## Usage

``` r
change_to_rgba_array(image, dtype = "uint8")

invert_image(image)

drag_pixels(frames)
```

## Arguments

- image:

  An image array.

- dtype:

  Ignored.

- frames:

  A list of image arrays of equal size.

## Value

`change_to_rgba_array()` returns an array of height by width by 4
channels, `invert_image()` the image array with its colors inverted, and
`drag_pixels()` a list of frames.

## Details

- `change_to_rgba_array(image, dtype)` adds channels so the array is
  RGBA: a gray image is repeated into RGB, and a missing alpha channel
  becomes 255. Unlike upstream, a gray plus alpha image is also
  accepted. `dtype` is accepted for compatibility; R keeps numbers as
  doubles.

- `invert_image(image)` returns `255 - image` for every channel, alpha
  included, as upstream.

- `drag_pixels(frames)` returns the frames with every pixel that is 0 so
  far filled from the next frame where it is not, a trail effect.

## Examples

``` r
change_to_rgba_array(matrix(c(1, 2, 3, 4), 2))[1, 1, ]
#> [1]   1   1   1 255
```
