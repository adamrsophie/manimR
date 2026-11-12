# Brace

A curly brace spanning a mobject on the side given by `direction`.
`BraceLabel()` adds a label at its tip, `BraceText()` uses
[`Text()`](https://adamrsophie.github.io/manimR/reference/TextClass.md)
for the label, `BraceBetweenPoints()` spans two points and `ArcBrace()`
follows an arc.

## Usage

``` r
Brace(
  mobject,
  direction = DOWN,
  buff = 0.2,
  sharpness = 2,
  stroke_width = 0,
  fill_opacity = 1,
  background_stroke_width = 0,
  background_stroke_color = "#000000",
  ...
)

BraceLabel(
  obj,
  text,
  brace_direction = DOWN,
  label_constructor = MathTex,
  font_size = DEFAULT_FONT_SIZE,
  buff = 0.2,
  brace_config = NULL,
  ...
)

BraceText(obj, text, label_constructor = Text, ...)

BraceBetweenPoints(point_1, point_2, direction = ORIGIN, ...)

ArcBrace(arc = NULL, direction = RIGHT, ...)
```

## Arguments

- mobject, obj:

  The mobject to brace.

- direction:

  Side of the mobject.

- buff:

  Gap between mobject and brace.

- sharpness:

  Sharpness of the brace tip.

- stroke_width, fill_opacity, background_stroke_width,
  background_stroke_color:

  Style.

- ...:

  Passed to
  [`VMobject()`](https://adamrsophie.github.io/manimR/reference/VMobjectClass.md)
  (for `BraceLabel()`, to the label constructor).

- text:

  Label text (a string or a vector of strings).

- brace_direction:

  Side of the mobject.

- label_constructor:

  Label constructor,
  [`MathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md)
  by default.

- font_size:

  Label font size.

- brace_config:

  List of extra `Brace()` arguments.

- point_1, point_2:

  End points.

- arc:

  An
  [`Arc()`](https://adamrsophie.github.io/manimR/reference/geometry.md).

## Examples

``` r
if (FALSE) { # \dontrun{
sq <- Square()
b <- Brace(sq, DOWN)
} # }
```
