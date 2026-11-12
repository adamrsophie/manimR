# Upstream module objects

Upstream code often reaches rate functions and colors through their
modules, as in `rate_functions.ease_in_sine` or `color.BLUE_C`. These
lists give the same access: `rate_functions$ease_in_sine`,
`rate_functions$smooth` (which is
[`smooth_rate()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)),
`color$BLUE_C`, `color$X11$BEIGE` or `color$interpolate_color`.
Everything in them is also exported directly.

## Usage

``` r
rate_functions

color
```

## Format

Named lists of functions and values.

## Details

Upstream's third module, `unit`, is not provided as an object, since
`unit` would mask [`grid::unit()`](https://rdrr.io/r/grid/unit.html);
use [Pixels](https://adamrsophie.github.io/manimR/reference/units.md),
[`Percent()`](https://adamrsophie.github.io/manimR/reference/units.md),
[Degrees](https://adamrsophie.github.io/manimR/reference/units.md) and
[Munits](https://adamrsophie.github.io/manimR/reference/units.md)
directly.

## Examples

``` r
rate_functions$smooth(0.5)
#> [1] 0.5
color$BLUE_C
#> [1] "#58C4DD"
```
