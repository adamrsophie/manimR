# CurvesAsSubmobjects

Split a VMobject into one submobject per Bezier curve.

## Usage

``` r
CurvesAsSubmobjects(vmobject, ...)
```

## Arguments

- vmobject:

  The VMobject to split.

- ...:

  Passed to
  [`VGroup()`](https://adamrsophie.github.io/manimR/reference/VGroupClass.md).

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.

## Details

`$point_from_proportion(alpha)` measures `alpha` along the total arc
length of the curves, as upstream.
