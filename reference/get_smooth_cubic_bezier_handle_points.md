# Smooth cubic Bezier handles

Given the anchors of a cubic spline, computes the first and second
handle of every curve so that the spline is smooth (continuous first and
second derivatives). A closed spline (see
[`is_closed()`](https://adamrsophie.github.io/manimR/reference/is_closed.md))
is smoothed across its start point too.

## Usage

``` r
get_smooth_cubic_bezier_handle_points(anchors)
```

## Arguments

- anchors:

  Anchors, an n x 3 matrix.

## Value

`list(h1, h2)`: two `(n - 1) x 3` matrices with the first and second
handles of each curve (upstream returns a tuple).

## Examples

``` r
anchors <- rbind(c(0, 0, 0), c(1, 1, 0), c(2, 0, 0), c(3, 2, 0))
get_smooth_cubic_bezier_handle_points(anchors)
#> $h1
#>           [,1]       [,2] [,3]
#> [1,] 0.3333333 0.57777778    0
#> [2,] 1.3333333 0.84444444    0
#> [3,] 2.3333333 0.04444444    0
#> 
#> $h2
#>           [,1]        [,2] [,3]
#> [1,] 0.6666667  1.15555556    0
#> [2,] 1.6666667 -0.04444444    0
#> [3,] 2.6666667  1.02222222    0
#> 
```
