# Boolean operations on VMobjects

`Union()` merges two or more shapes, `Intersection()` keeps the region
they all share, `Difference()` removes `clip` from `subject` and
`Exclusion()` keeps the region covered by exactly one of the two. As
upstream's skia-pathops result, the outline is made of pieces of the
input curves, cut where they cross.

## Usage

``` r
Union(...)

Intersection(...)

Difference(subject, clip, ...)

Exclusion(subject, clip, ...)
```

## Arguments

- ...:

  For `Union()` and `Intersection()`: two or more VMobjects, then named
  style arguments passed to
  [`VMobject()`](https://adamrsophie.github.io/manimR/reference/VMobjectClass.md).
  For `Difference()` and `Exclusion()`: named style arguments.

- subject, clip:

  The VMobjects to subtract or exclude.

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.

## Examples

``` r
sq <- Square(color = RED, fill_opacity = 1)$move_to(c(-2, 0, 0))
cr <- Circle(color = BLUE, fill_opacity = 1)$move_to(c(-1.3, 0.7, 0))
un <- Union(sq, cr, color = GREEN, fill_opacity = 1)$move_to(c(1.5, 0.3, 0))
```
