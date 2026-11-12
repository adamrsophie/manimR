# Is a spline closed?

Returns `TRUE` when the first and last rows of `points` are close, using
the tolerance `1e-8 + 1e-5 * abs(start)` per coordinate, as upstream.
Smooth handles (see
[`get_smooth_cubic_bezier_handle_points()`](https://adamrsophie.github.io/manimR/reference/get_smooth_cubic_bezier_handle_points.md))
depend on this test.

## Usage

``` r
is_closed(points)
```

## Arguments

- points:

  Points of a spline, an n x 3 matrix.

## Value

`TRUE` or `FALSE`.

## Examples

``` r
is_closed(rbind(c(0, 0, 0), c(1, 2, 3), c(0, 0, 0)))
#> [1] TRUE
is_closed(rbind(c(-1, 0, 0), c(1, 2, 3), c(-1, 0, 0)))
#> [1] TRUE
```
