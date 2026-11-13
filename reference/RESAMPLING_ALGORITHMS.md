# Resampling algorithms for images

Names accepted by `ImageMobject$set_resampling_algorithm()`, mapped to
their canonical names. Images are drawn with the filters Pillow's
perspective transform has: `"nearest"` draws the pixels as blocks,
`"bilinear"` interpolates linearly, and `"bicubic"` (the default) uses
Pillow's bicubic filter for enlarged, sheared or perspective images.
Pillow cannot transform with `"lanczos"`, `"box"` or `"hamming"`, so
upstream's camera raises for them; manimR draws them as `"bilinear"`.
[`OpenGLImageMobject()`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
upscales image arrays with all six filters, as Pillow's `resize()` does.

## Usage

``` r
RESAMPLING_ALGORITHMS
```

## Value

A named character vector of resampling algorithm names.
