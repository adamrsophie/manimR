# Number lines

`NumberLine()` draws a line with tick marks and optional number labels.
`UnitInterval()` is a number line from 0 to 1 with ticks every 0.1.

## Usage

``` r
NumberLine(
  x_range = NULL,
  length = NULL,
  unit_size = 1,
  include_ticks = TRUE,
  tick_size = 0.1,
  numbers_with_elongated_ticks = NULL,
  longer_tick_multiple = 2,
  exclude_origin_tick = FALSE,
  rotation = 0,
  stroke_width = 2,
  include_tip = FALSE,
  tip_width = DEFAULT_ARROW_TIP_LENGTH,
  tip_height = DEFAULT_ARROW_TIP_LENGTH,
  tip_shape = NULL,
  include_numbers = FALSE,
  font_size = 36,
  label_direction = DOWN,
  label_constructor = MathTex,
  scaling = LinearBase(),
  line_to_number_buff = MED_SMALL_BUFF,
  decimal_number_config = NULL,
  numbers_to_exclude = NULL,
  numbers_to_include = NULL,
  ...
)

UnitInterval(
  unit_size = 10,
  numbers_with_elongated_ticks = NULL,
  decimal_number_config = NULL,
  ...
)
```

## Arguments

- x_range:

  `c(x_min, x_max, x_step)`; the step defaults to 1.

- length:

  Length of the line. Overrides `unit_size` when given.

- unit_size:

  Distance between consecutive integers.

- include_ticks:

  Whether to draw ticks.

- tick_size:

  Half length of each tick.

- numbers_with_elongated_ticks:

  Values whose ticks are longer.

- longer_tick_multiple:

  How much longer elongated ticks are.

- exclude_origin_tick:

  Whether to omit the tick at 0.

- rotation:

  Rotation angle in radians.

- stroke_width:

  Line width.

- include_tip:

  Whether to add an arrow tip.

- tip_width, tip_height:

  Tip size.

- tip_shape:

  Tip class generator, for example `StealthTipClass`.

- include_numbers:

  Whether to add number labels.

- font_size:

  Font size of the labels.

- label_direction:

  Direction of the labels from the line.

- label_constructor:

  Function building labels, such as
  [`MathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md).

- scaling:

  A scale from
  [`LinearBase()`](https://adamrsophie.github.io/manimR/reference/graph_scale.md)
  or
  [`LogBase()`](https://adamrsophie.github.io/manimR/reference/graph_scale.md).

- line_to_number_buff:

  Gap between line and labels.

- decimal_number_config:

  List of arguments for
  [`DecimalNumber()`](https://adamrsophie.github.io/manimR/reference/DecimalNumberClass.md).

- numbers_to_exclude:

  Values that get no number label.

- numbers_to_include:

  Values that get a number label.

- ...:

  Passed to
  [`Line()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  (for example `color`).

## Value

A `NumberLine` mobject.

## Details

Useful methods: `number_to_point(x)` (alias `n2p`), `point_to_number(p)`
(alias `p2n`), `get_tick_range()`, `add_numbers()`, `add_labels()`,
`get_number_mobject()`, `get_unit_size()`, `rotate_about_number()`.
`n2p()` of a vector returns an n x 3 matrix; `p2n()` of an n x 3 matrix
returns a vector.

## Examples

``` r
l <- NumberLine(x_range = c(-5, 5, 1), length = 10)
l$n2p(2)
#> [1] 2 0 0
if (FALSE) { # \dontrun{
# The numbers are typeset with LaTeX.
NumberLine(x_range = c(-5, 5, 1), length = 10, include_numbers = TRUE)
} # }
```
