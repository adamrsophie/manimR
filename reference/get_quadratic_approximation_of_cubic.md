# Quadratic approximation of cubic Bezier curves

Splits each cubic Bezier curve into two quadratic ones that approximate
it. Ported from `manim.utils.bezier`.

## Usage

``` r
get_quadratic_approximation_of_cubic(a0, h0, h1, a1)
```

## Arguments

- a0, h0, h1, a1:

  The start anchors, first handles, second handles and end anchors: four
  points, or four matrices with one curve per row.

## Value

A matrix with six rows per curve: the three control points of each of
its two quadratic curves.

## Examples

``` r
get_quadratic_approximation_of_cubic(c(0, 0, 0), c(1, 2, 0), c(3, 2, 0), c(4, 0, 0))
#>      [,1] [,2] [,3]
#> [1,] 0.00  0.0    0
#> [2,] 0.75  1.5    0
#> [3,] 2.00  1.5    0
#> [4,] 2.00  1.5    0
#> [5,] 3.25  1.5    0
#> [6,] 4.00  0.0    0
```
