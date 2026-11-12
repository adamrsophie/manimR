# Growing animations

Grow mobjects from a point, their center, an edge, or (for arrows) their
start.

## Usage

``` r
GrowFromPoint(mobject, point, point_color = NULL, ...)

GrowFromCenter(mobject, ...)

GrowFromEdge(mobject, edge, ...)

GrowArrow(arrow, point_color = NULL, ...)

SpinInFromNothing(mobject, angle = PI/2, point_color = NULL, ...)
```

## Arguments

- mobject, arrow:

  The mobject to grow.

- point:

  Point to grow from.

- point_color:

  Initial color.

- ...:

  Passed to
  [`Transform()`](https://adamrsophie.github.io/manimR/reference/transform.md).

- edge:

  Edge direction to grow from.

- angle:

  Spin angle for `SpinInFromNothing()`.
