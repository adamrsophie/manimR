# Units

Unit helpers from `manim.utils.unit`: `Pixels` converts pixels to scene
units at the current resolution, `Percent(X_AXIS)` converts a percentage
of the frame width (or height for `Y_AXIS`), `Degrees` converts degrees
to radians and `Munits` is one scene unit. Multiply a number by a unit:
`50 * Pixels`, `25 * Percent(X_AXIS)`.

## Usage

``` r
Pixels

Percent(axis)

Degrees

Munits
```

## Arguments

- axis:

  `X_AXIS` or `Y_AXIS`.

## Value

`Pixels`, `Degrees` and `Munits` are units to multiply a number by, and
`Percent()` returns such a unit for an axis; the product is a length in
scene units or an angle in radians.

## Examples

``` r
100 * Pixels
#> [1] 0.7407407
10 * Percent(X_AXIS)
#> [1] 1.422222
```
