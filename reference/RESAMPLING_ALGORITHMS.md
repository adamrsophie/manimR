# Resampling algorithms for images

Names accepted by `ImageMobject$set_resampling_algorithm()`, mapped to
their canonical names. Images are drawn with the filters Pillow's
perspective transform has: `"nearest"` draws the pixels as blocks,
`"bilinear"` interpolates linearly, and `"bicubic"` (the default) uses
Pillow's bicubic filter for enlarged, sheared or perspective images.
Pillow cannot transform with `"lanczos"`, `"box"` or `"hamming"`; manimR
draws them as `"bilinear"`.

## Usage

``` r
RESAMPLING_ALGORITHMS
```
