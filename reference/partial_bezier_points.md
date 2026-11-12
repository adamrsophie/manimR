# Split, trim and remap Bezier curves

Helpers that operate on the control points of Bezier curves, given as an
n x 3 matrix with one control point per row (4 rows for a cubic curve).

## Usage

``` r
partial_bezier_points(points, a, b)

split_bezier(points, t)

subdivide_bezier(points, n_divisions)

bezier_remap(bezier_tuples, new_number_of_curves)
```

## Arguments

- points:

  Control points, an n x 3 matrix (one row per point).

- a, b:

  Start and end of the parameter interval.

- t:

  Parameter at which to split.

- n_divisions:

  Number of pieces.

- bezier_tuples:

  Control points of the curves to remap, a `4k x 3` matrix.

- new_number_of_curves:

  Number of curves in the result.

## Value

A matrix of control points, one row per point.

## Details

- `partial_bezier_points()` returns the control points of the portion of
  the curve with parameter in `[a, b]`, `0 <= a < b <= 1`.

- `split_bezier()` splits the curve at `t` and returns the control
  points of both halves stacked (`2 n` rows). Like upstream, a line (2
  points) gives 4 rows `p0, m, m, p1` and a single point gives 2 rows.

- `subdivide_bezier()` splits the curve into `n_divisions` pieces of
  equal parameter length and returns their control points stacked
  (`n_divisions * n` rows). For curves of degree 4 or more, upstream's
  fallback splits at the wrong parameters (`1/3` and `1/2` for three
  pieces); manimR splits at `i / n_divisions`, as upstream documents.

- `bezier_remap()` takes a path of `k` cubic curves (a `4k x 3` matrix)
  and subdivides its curves so the result has `new_number_of_curves`
  curves, which must be at least `k`. Upstream takes a `(k, 4, 3)`
  array; here the curves are stacked rows as everywhere in manimR.

## Examples

``` r
cubic <- rbind(c(0, 0, 0), c(1, 2, 0), c(3, -1, 0), c(4, 1, 0))
split_bezier(cubic, 0.5)
#>      [,1] [,2] [,3]
#> [1,] 0.00 0.00    0
#> [2,] 0.50 1.00    0
#> [3,] 1.25 0.75    0
#> [4,] 2.00 0.50    0
#> [5,] 2.00 0.50    0
#> [6,] 2.75 0.25    0
#> [7,] 3.50 0.00    0
#> [8,] 4.00 1.00    0
partial_bezier_points(cubic, 0.25, 0.75)
#>         [,1]    [,2] [,3]
#> [1,] 0.90625 0.71875    0
#> [2,] 1.59375 0.78125    0
#> [3,] 2.40625 0.21875    0
#> [4,] 3.09375 0.28125    0
nrow(subdivide_bezier(cubic, 3))
#> [1] 12
nrow(bezier_remap(Square()$points, 7))
#> [1] 28
```
