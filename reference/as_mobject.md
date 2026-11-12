# Turn R plots into mobjects

`as_mobject()` draws a plot into an SVG file with R's Cairo
[`svg()`](https://rdrr.io/r/grDevices/cairo.html) device and imports it
with
[`SVGMobject()`](https://adamrsophie.github.io/manimR/reference/SVGMobjectClass.md),
so a ggplot2 chart, a grid grob or base graphics can be animated like
any vector mobject: each line, point, rectangle and glyph becomes a
submobject.

## Usage

``` r
as_mobject(x, width = 7, height = 5, bg = "transparent", height_units = 6, ...)
```

## Arguments

- x:

  The plot.

- width, height:

  Size of the drawing in inches.

- bg:

  Background of the drawing; `"transparent"` (the default) leaves only
  the plot's own elements.

- height_units:

  Height of the mobject in scene units, or `NULL` to keep the SVG size.

- ...:

  Passed to
  [`SVGMobject()`](https://adamrsophie.github.io/manimR/reference/SVGMobjectClass.md).

## Value

An
[`SVGMobject()`](https://adamrsophie.github.io/manimR/reference/SVGMobjectClass.md).

## Details

- a `ggplot` object (ggplot2), a `grob` or `gTable`, or a recorded plot
  is drawn as it is;

- a function is called to draw base graphics, for example
  `as_mobject(function() hist(rnorm(100)))`.

The plot is drawn on a white or transparent background (`bg`), at
`width` x `height` inches; the mobject is then scaled to `height_units`
scene units.

## Examples

``` r
if (FALSE) { # \dontrun{
if (requireNamespace("ggplot2", quietly = TRUE)) {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  chart <- as_mobject(p)
  render(function(self) self$play(Create(chart)), quality = "l")
}
} # }
```
