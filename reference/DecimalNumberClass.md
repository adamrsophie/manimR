# DecimalNumber, Integer and Variable

A number typeset digit by digit (with LaTeX by default) that can be
updated with `set_value()`, for example in an updater or with
[`ChangeDecimalToValue()`](https://adamrsophie.github.io/manimR/reference/number_animations.md).
`Variable()` shows `label = value` driven by a
[`ValueTracker()`](https://adamrsophie.github.io/manimR/reference/ValueTrackerClass.md)
stored in `$tracker`.

## Usage

``` r
DecimalNumber(
  number = 0,
  num_decimal_places = 2,
  mob_class = MathTex,
  include_sign = FALSE,
  group_with_commas = TRUE,
  digit_buff_per_font_unit = 0.001,
  show_ellipsis = FALSE,
  unit = NULL,
  unit_buff_per_font_unit = 0,
  include_background_rectangle = FALSE,
  edge_to_fix = LEFT,
  font_size = DEFAULT_FONT_SIZE,
  stroke_width = 0,
  fill_opacity = 1,
  ...
)

Integer(number = 0, num_decimal_places = 0, ...)

Variable(var, label, var_type = "decimal", num_decimal_places = 2, ...)
```

## Arguments

- number:

  The number (real or complex).

- num_decimal_places:

  Digits after the decimal point.

- mob_class:

  Constructor for each character,
  [`MathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md)
  by default.

- include_sign:

  Always show the sign.

- group_with_commas:

  Insert thousands separators.

- digit_buff_per_font_unit:

  Gap between characters per font size unit.

- show_ellipsis:

  Append an ellipsis.

- unit:

  Optional unit string; aligned to the top when it starts with `^`.

- unit_buff_per_font_unit:

  Gap before the unit.

- include_background_rectangle:

  Add a background rectangle.

- edge_to_fix:

  Edge kept fixed when the value changes.

- font_size:

  Font size.

- stroke_width, fill_opacity:

  Style.

- ...:

  Passed to
  [`VMobject()`](https://adamrsophie.github.io/manimR/reference/VMobjectClass.md).

- var:

  Initial value of the variable.

- label:

  Label string (typeset with
  [`MathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md))
  or a mobject.

- var_type:

  `"decimal"` or `"integer"` (or the constructors `DecimalNumber` /
  `Integer`).

## Examples

``` r
if (FALSE) { # \dontrun{
d <- DecimalNumber(3.14159, num_decimal_places = 3)
d$set_value(2.71828)
} # }
```
