# Polyhedra

`Polyhedron(vertex_coords, faces_list)` builds a polyhedron from vertex
coordinates (a matrix or list of points) and faces given as vectors of 1
based vertex indices, like the OFF file format. The faces are in
`$faces` (a
[`VGroup()`](https://adamrsophie.github.io/manimR/reference/VGroupClass.md)
of
[`Polygon()`](https://adamrsophie.github.io/manimR/reference/geometry.md)s)
and the vertices and edges in `$graph`, a
[`Graph()`](https://adamrsophie.github.io/manimR/reference/GenericGraphClass.md):
`graph[i]` (or `graph$vertices[[i]]`) is vertex `i`, a
[`Dot3D()`](https://adamrsophie.github.io/manimR/reference/three_dimensions.md).
Moving a vertex moves the faces with it (through an updater).

`Tetrahedron()`, `Octahedron()`, `Icosahedron()` and `Dodecahedron()`
are the platonic solids; `ConvexHull3D()` is the convex hull of points.

## Usage

``` r
Polyhedron(
  vertex_coords,
  faces_list,
  faces_config = list(),
  graph_config = list()
)

Tetrahedron(edge_length = 1, ...)

Octahedron(edge_length = 1, ...)

Icosahedron(edge_length = 1, ...)

Dodecahedron(edge_length = 1, ...)

ConvexHull3D(..., tolerance = 1e-05)
```

## Arguments

- vertex_coords:

  Vertex coordinates.

- faces_list:

  List of integer vectors of vertex indices (1 based).

- faces_config:

  List of
  [`Polygon()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  arguments for the faces; the default is
  `fill_opacity = 0.5, shade_in_3d = TRUE`.

- graph_config:

  List with `vertex_type` (default
  [`Dot3D()`](https://adamrsophie.github.io/manimR/reference/three_dimensions.md)),
  `vertex_config`, `edge_type` (default
  [`Line()`](https://adamrsophie.github.io/manimR/reference/geometry.md))
  and `edge_config` (default invisible edges).

- edge_length:

  Edge length of the platonic solid.

- ...:

  For `ConvexHull3D()`, the points (then named arguments for
  `Polyhedron()`); otherwise passed to `Polyhedron()`.

- tolerance:

  Coplanarity tolerance of the hull.

## Examples

``` r
pyramid <- Polyhedron(
  rbind(c(1, 1, 0), c(1, -1, 0), c(-1, -1, 0), c(-1, 1, 0), c(0, 0, 2)),
  list(c(1, 2, 5), c(2, 3, 5), c(3, 4, 5), c(4, 1, 5), c(1, 2, 3, 4))
)
# \donttest{
oct <- Octahedron(edge_length = 3)
oct$graph[1]$set_color(RED)
oct$faces[3]$set_color(YELLOW)
# }
```
