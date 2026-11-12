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

## Details

`$point_from_proportion(alpha)` measures `alpha` along the total arc
length of the curves, as upstream.
