# Triangulate a polygon with holes

Port of manim's `earclip_triangulation()`. The rings (the outer boundary
and its holes) are first joined into one ring by bridges between nearby
vertices, then that ring is cut into triangles by ear clipping (mapbox's
earcut algorithm).

## Usage

``` r
earclip_triangulation(verts, ring_ends)
```

## Arguments

- verts:

  Vertices, an n x 2 or n x 3 matrix (one vertex per row). Only x and y
  are used for the triangulation.

- ring_ends:

  Cumulative vertex counts of the rings, for example `c(4, 8)` for a
  square with a square hole after it.

## Value

An integer vector of row indices of `verts`, three per triangle;
`matrix(result, ncol = 3, byrow = TRUE)` gives one triangle per row.

## Details

Indices are 1 based here: the result indexes rows of `verts` (upstream
returns 0 based indices). `ring_ends` holds, for each ring, the number
of vertices up to and including that ring, which is both upstream's
exclusive 0 based end and the 1 based row of the ring's last vertex.

The ring lookup accepts a bridge to the last vertex of a hole. manim
0.20.1 raises "Could not find a ring to attach" there; newer upstream
versions fix it the same way. Otherwise the result matches upstream
index for index.

## Examples

``` r
outer <- rbind(c(0, 0, 0), c(6, 0, 0), c(6, 4, 0), c(0, 4, 0))
hole <- rbind(c(1, 1, 0), c(1, 3, 0), c(2, 3, 0), c(2, 1, 0))
tri <- earclip_triangulation(rbind(outer, hole), c(4, 8))
matrix(tri, ncol = 3, byrow = TRUE)
#>      [,1] [,2] [,3]
#> [1,]    4    1    5
#> [2,]    8    5    1
#> [3,]    4    5    6
#> [4,]    8    1    2
#> [5,]    3    4    6
#> [6,]    7    8    2
#> [7,]    3    6    7
#> [8,]    7    2    3
```
