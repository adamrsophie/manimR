# ScreenRectangle and FullScreenRectangle

Rectangles with the aspect ratio of the screen.

## Usage

``` r
ScreenRectangle(aspect_ratio = 16/9, height = 4, ...)

FullScreenRectangle(...)
```

## Arguments

- aspect_ratio:

  Width divided by height.

- height:

  Height.

- ...:

  Passed to
  [`Rectangle()`](https://adamrsophie.github.io/manimR/reference/geometry.md).

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.
