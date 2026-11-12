# Labels

`Label()` is a label surrounded by a background box and a frame.
`LabeledLine()` and `LabeledArrow()` put such a label at
`label_position` (a proportion of the length) along a line or arrow.
`LabeledPolygram()` puts it at the pole of inaccessibility of a
polygram, the interior point farthest from its edges, stored in `$pole`
with the distance in `$radius`.

## Usage

``` r
Label(label, label_config = NULL, box_config = NULL, frame_config = NULL, ...)

LabeledLine(
  label,
  label_position = 0.5,
  label_config = NULL,
  box_config = NULL,
  frame_config = NULL,
  ...
)

LabeledArrow(
  label,
  label_position = 0.5,
  label_config = NULL,
  box_config = NULL,
  frame_config = NULL,
  ...
)

LabeledPolygram(
  ...,
  label,
  precision = 0.01,
  label_config = NULL,
  box_config = NULL,
  frame_config = NULL
)
```

## Arguments

- label:

  A string (rendered with
  [`MathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md))
  or a mobject such as
  [`Text()`](https://adamrsophie.github.io/manimR/reference/TextClass.md).

- label_config:

  Named list of arguments for
  [`MathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md)
  when `label` is a string.

- box_config:

  Named list of arguments for the
  [`BackgroundRectangle()`](https://adamrsophie.github.io/manimR/reference/geometry.md).

- frame_config:

  Named list of arguments for the
  [`SurroundingRectangle()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  frame.

- ...:

  For `Label()`: passed to
  [`VGroup()`](https://adamrsophie.github.io/manimR/reference/VGroupClass.md).
  For `LabeledLine()` and `LabeledArrow()`: passed to
  [`Line()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  or
  [`Arrow()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  (`start`, `end`, ...). For `LabeledPolygram()`: vertex groups (one
  matrix or list of points per ring), then named arguments for
  [`Polygram()`](https://adamrsophie.github.io/manimR/reference/geometry.md).

- label_position:

  Position of the label along the line, in `[0, 1]`.

- precision:

  Precision of the pole of inaccessibility search.

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.

## Examples

``` r
Label(Text("Label Text"), box_config = list(color = BLUE, fill_opacity = 0.75))$scale(3)
if (FALSE) { # \dontrun{
# A label given as a string is typeset with LaTeX.
LabeledLine("0.5", label_position = 0.8, label_config = list(font_size = 20),
            start = LEFT + DOWN, end = RIGHT + UP)
} # }
```
