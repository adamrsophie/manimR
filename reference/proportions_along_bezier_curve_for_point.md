# Does a point lie on a Bezier curve?

`proportions_along_bezier_curve_for_point()` solves, for each
coordinate, the Bezier polynomial minus the point's coordinate and
returns the real roots in `[0, 1]` common to every coordinate: the
parameters at which the curve passes through `point`. Roots are rounded
to the number of decimals given by `round_to` before they are compared,
as upstream does. `point_lies_on_bezier()` is `TRUE` when there is at
least one such root.

## Usage

``` r
proportions_along_bezier_curve_for_point(
  point,
  control_points,
  round_to = 1e-06
)

point_lies_on_bezier(point, control_points, round_to = 1e-06)
```

## Arguments

- point:

  A point, `c(x, y, z)`.

- control_points:

  Control points of the curve, an n x 3 matrix.

- round_to:

  Rounding precision of the roots.

## Value

A numeric vector of parameters (usually of length 0 or 1), or
`TRUE`/`FALSE`.

## Examples

``` r
cubic <- rbind(c(0, 0, 0), c(1, 2, 0), c(3, -1, 0), c(4, 1, 0))
p <- bezier(cubic)(0.25)
proportions_along_bezier_curve_for_point(p, cubic)
#> [1] 0.25
point_lies_on_bezier(c(1, 1, 0), cubic)
#> [1] FALSE
```
