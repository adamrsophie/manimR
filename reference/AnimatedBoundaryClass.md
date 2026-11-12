# AnimatedBoundary and TracedPath

`AnimatedBoundary()` draws a boundary around a VMobject that cycles
through colors while the scene runs. `TracedPath()` leaves a trail
behind a moving point, optionally fading after `dissipating_time`
seconds.

## Usage

``` r
AnimatedBoundary(
  vmobject,
  colors = c(BLUE_D, BLUE_B, BLUE_E, GREY_BROWN),
  max_stroke_width = 3,
  cycle_rate = 0.5,
  back_and_forth = TRUE,
  draw_rate_func = smooth_rate,
  fade_rate_func = smooth_rate,
  ...
)

TracedPath(
  traced_point_func,
  stroke_width = 2,
  stroke_color = "#FFFFFF",
  dissipating_time = NULL,
  ...
)
```

## Arguments

- vmobject:

  The VMobject to outline.

- colors:

  Colors to cycle through.

- max_stroke_width:

  Maximum stroke width.

- cycle_rate:

  Cycles per second.

- back_and_forth:

  Draw back and forth.

- draw_rate_func, fade_rate_func:

  Rate functions for drawing and fading.

- ...:

  Passed to
  [`VGroup()`](https://adamrsophie.github.io/manimR/reference/VGroupClass.md)
  or
  [`VMobject()`](https://adamrsophie.github.io/manimR/reference/VMobjectClass.md).

- traced_point_func:

  Function with no arguments returning the point to trace.

- stroke_width, stroke_color:

  Style of the trace.

- dissipating_time:

  Seconds after which the trace fades, or `NULL`.

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.
