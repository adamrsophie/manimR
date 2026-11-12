# Pole of inaccessibility

Finds the point inside a polygon (with optional holes) that is farthest
from its edges, by the iterative grid search of the polylabel algorithm.

## Usage

``` r
polylabel(rings, precision = 0.01)
```

## Arguments

- rings:

  List of closed rings, each a matrix of points (n x 2 or n x 3). Extra
  rings are holes.

- precision:

  Precision of the result.

## Value

A list with `c` (the 2D pole), `d` (its distance to the edges) and `h`
(half the size of the cell it was found in).

## Examples

``` r
polylabel(list(rbind(c(0, 0), c(4, 0), c(4, 2), c(0, 2), c(0, 0))))
#> $c
#> [1] 2 1
#> 
#> $d
#> [1] 1
#> 
#> $h
#> [1] 0
#> 
```
