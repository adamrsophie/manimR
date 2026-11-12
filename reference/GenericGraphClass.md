# Graphs

`Graph()` displays an undirected graph and `DiGraph()` a directed one:
vertices (by default
[`Dot()`](https://adamrsophie.github.io/manimR/reference/geometry.md)s)
joined by edges (by default
[`Line()`](https://adamrsophie.github.io/manimR/reference/geometry.md)s).
An updater keeps the edges attached to the vertices, so moving a vertex
drags its edges along.

Vertices are identified by their names (numbers are converted to
strings). Look up a vertex with `g$get(1)` or `g$vertices[["1"]]` and an
edge with `g$get(c(1, 2))`. Methods: `add_vertices()`,
`remove_vertices()`, `add_edges()`, `remove_edges()` and
`change_layout()`; `g$animate$change_layout("circular")` animates the
new layout. `g$animate$add_vertices()` and `g$animate$add_edges()`
return
[`Create()`](https://adamrsophie.github.io/manimR/reference/creation.md)
animations of the new mobjects, and `g$animate$remove_vertices()` and
`g$animate$remove_edges()` return
[`Uncreate()`](https://adamrsophie.github.io/manimR/reference/creation.md)
animations of the removed ones; choose another animation with
`g$animate(animation = FadeIn)`.

## Usage

``` r
Graph(
  vertices,
  edges,
  labels = FALSE,
  label_fill_color = BLACK,
  layout = "spring",
  layout_scale = 2,
  layout_config = NULL,
  vertex_type = Dot,
  vertex_config = NULL,
  vertex_mobjects = NULL,
  edge_type = Line,
  partitions = NULL,
  root_vertex = NULL,
  edge_config = NULL
)

DiGraph(
  vertices,
  edges,
  labels = FALSE,
  label_fill_color = BLACK,
  layout = "spring",
  layout_scale = 2,
  layout_config = NULL,
  vertex_type = Dot,
  vertex_config = NULL,
  vertex_mobjects = NULL,
  edge_type = Line,
  partitions = NULL,
  root_vertex = NULL,
  edge_config = NULL
)
```

## Arguments

- vertices:

  Vector or list of vertex names.

- edges:

  List of vertex pairs, such as `list(c(1, 2), c(2, 3))`, or a two
  column matrix.

- labels:

  `TRUE` labels vertices with their names via
  [`MathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md);
  a named list maps vertex names to label mobjects.

- label_fill_color:

  Color of the labels made for `labels = TRUE`.

- layout:

  A layout name (`"spring"`, `"circular"`, `"kamada_kawai"`, `"planar"`,
  `"random"`, `"shell"`, `"spectral"`, `"spiral"`, `"tree"`,
  `"partite"`), a named list of positions, or a function
  `function(graph, scale, ...)` returning such a list. The layouts
  follow networkx; `"planar"` draws a planar graph without crossings (an
  error for other graphs) and can place vertices differently from
  networkx, which picks some vertices in hash order.

- layout_scale:

  Half width of the generated layouts.

- layout_config:

  Named list of extra arguments for the layout, for example
  `list(nlist = ...)` for `"shell"`,
  `list(root_vertex = 1, vertex_spacing = c(1, 1))` for `"tree"`,
  `list(dist = ...)` for `"kamada_kawai"`, or `list(seed = 1)` for
  `"spring"` and `"random"`.

- vertex_type:

  Constructor (or R6 generator) for vertices.

- vertex_config:

  Named list of arguments for `vertex_type`; entries named by a vertex
  are used for that vertex only.

- vertex_mobjects:

  Named list of mobjects used as vertices.

- edge_type:

  Constructor (or R6 generator) for edges.

- partitions:

  Partitions for the `"partite"` layout.

- root_vertex:

  Root for the `"tree"` layout.

- edge_config:

  Named list of arguments for `edge_type`; entries named `"u-v"` apply
  to the edge from `u` to `v`. Inside a vertex name, escape each `-` and
  each backslash with a backslash when the plain form would name several
  edges. For `DiGraph()`, a `tip_config` entry (globally or per edge)
  styles the tips.

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.

## Examples

``` r
g <- Graph(1:4, list(c(1, 2), c(2, 3), c(3, 4), c(1, 3), c(1, 4)), layout = "circular")
g$get(1)$move_to(c(1, 1, 0))
```
