# Boolean operations on VMobjects

`Union()` merges two or more shapes, `Intersection()` keeps the region
they all share, `Difference()` removes `clip` from `subject` and
`Exclusion()` keeps the region covered by exactly one of the two. The
inputs are flattened to polygons (curves are sampled finely) and clipped
with the 'polyclip' package, so the result is made of straight segments.
Install 'polyclip' to use these classes.

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

## Examples

``` r
if (FALSE) { # \dontrun{
sq <- Square(color = RED, fill_opacity = 1)$move_to(c(-2, 0, 0))
cr <- Circle(color = BLUE, fill_opacity = 1)$move_to(c(-1.3, 0.7, 0))
un <- Union(sq, cr, color = GREEN, fill_opacity = 1)$move_to(c(1.5, 0.3, 0))
} # }
```
