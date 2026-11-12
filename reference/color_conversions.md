# More color conversions

Ports of the remaining helpers in `manim.utils.color.core`: integer
RGB(A) values, hex conversion and HSV conversion. Surface shading is
[`get_shaded_rgb()`](https://adamrsophie.github.io/manimR/reference/get_shaded_rgb.md).

## Usage

``` r
color_to_int_rgb(color)

color_to_int_rgba(color, alpha = 1)

rgb_to_hex(rgb)

hex_to_rgb(hex)

color_to_hsv(color)

color_from_hsv(h, s, v)
```

## Arguments

- color:

  A color.

- alpha:

  Opacity.

- rgb:

  A numeric vector in `[0, 1]`.

- hex:

  A hex string.

- h, s, v:

  Hue, saturation and value in `[0, 1]`.

## Examples

``` r
color_to_int_rgb(BLUE)
#> [1]  88 196 221
color_from_hsv(0.5, 1, 1)
#> ManimColor('#00FFFF')
```
