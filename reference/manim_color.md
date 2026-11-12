# Parse a color

Accepts manim color names (case insensitive, e.g. `"blue_d"`), hex
strings with or without alpha, and any color R understands.

## Usage

``` r
manim_color(color)

color_to_rgb(color)

color_to_rgba(color, alpha = 1)

rgb_to_color(rgb)

rgba_to_color(rgba)
```

## Arguments

- color:

  A color.

- alpha:

  Opacity of the result, 1 by default as upstream; `NULL` keeps the
  opacity the color carries.

- rgb, rgba:

  Numeric vectors in `[0, 1]`.

## Value

`manim_color()` returns an uppercase hex string. `color_to_rgb()`
returns a numeric vector in `[0, 1]`; `color_to_rgba()` includes alpha.
`rgb_to_color()` and `rgba_to_color()` return a
[`ManimColor()`](https://adamrsophie.github.io/manimR/reference/ManimColor.md),
which keeps the exact channel values (and alpha) and works as a hex
string.

## Examples

``` r
manim_color("red")
#> [1] "#FC6255"
color_to_rgb(BLUE)
#> [1] 0.3450980 0.7686275 0.8666667
```
