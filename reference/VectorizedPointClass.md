# VectorizedPoint

An invisible vectorized point, used as an anchor for animations.

## Usage

``` r
VectorizedPoint(
  location = ORIGIN,
  color = "#000000",
  fill_opacity = 0,
  stroke_width = 0,
  artificial_width = 0.01,
  artificial_height = 0.01,
  ...
)
```

## Arguments

- location:

  The point.

- color, fill_opacity, stroke_width:

  Style; the point is invisible by default.

- artificial_width, artificial_height:

  Width and height reported for the point, which has no extent of its
  own.

- ...:

  Passed to
  [`VMobject()`](https://adamrsophie.github.io/manimR/reference/VMobjectClass.md).

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.
