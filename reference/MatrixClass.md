# Matrix

Displays a matrix: entries made with `element_to_mobject` (by default
[`MathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md))
laid out in a grid between brackets. `DecimalMatrix()`,
`IntegerMatrix()` and `MobjectMatrix()` use
[`DecimalNumber()`](https://adamrsophie.github.io/manimR/reference/DecimalNumberClass.md),
[`Integer()`](https://adamrsophie.github.io/manimR/reference/DecimalNumberClass.md)
and the given mobjects as entries.

Methods: `get_rows()`, `get_columns()`, `get_entries()`,
`get_brackets()`, `get_mob_matrix()`, `set_row_colors(...)`,
`set_column_colors(...)` and `add_background_to_entries()`.

## Usage

``` r
Matrix(
  matrix,
  v_buff = 0.8,
  h_buff = 1.3,
  bracket_h_buff = MED_SMALL_BUFF,
  bracket_v_buff = MED_SMALL_BUFF,
  add_background_rectangles_to_entries = FALSE,
  include_background_rectangle = FALSE,
  element_to_mobject = MathTex,
  element_to_mobject_config = list(),
  element_alignment_corner = DR,
  left_bracket = "[",
  right_bracket = "]",
  stretch_brackets = TRUE,
  bracket_config = list(),
  ...
)

DecimalMatrix(
  matrix,
  element_to_mobject = DecimalNumber,
  element_to_mobject_config = list(num_decimal_places = 1),
  ...
)

IntegerMatrix(matrix, element_to_mobject = Integer, ...)

MobjectMatrix(matrix, element_to_mobject = function(m) m, ...)
```

## Arguments

- matrix:

  An R matrix, a data frame, a list of rows (vectors or lists), or a
  vector (one column).

- v_buff, h_buff:

  Vertical and horizontal distance between entries.

- bracket_h_buff:

  Distance of the brackets from the entries.

- bracket_v_buff:

  How far the brackets extend above and below the entries.

- add_background_rectangles_to_entries:

  Add a background rectangle to each entry.

- include_background_rectangle:

  Add a background rectangle to the matrix.

- element_to_mobject:

  Constructor applied to each entry.

- element_to_mobject_config:

  Named list of extra arguments for it.

- element_alignment_corner:

  Corner of each entry aligned to the grid.

- left_bracket, right_bracket:

  LaTeX bracket delimiters, such as `"("` or `"["`.

- stretch_brackets:

  Stretch the brackets to the height of the entries.

- bracket_config:

  Named list of arguments for the bracket
  [`MathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md).

- ...:

  Passed to
  [`VMobject()`](https://adamrsophie.github.io/manimR/reference/VMobjectClass.md).

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.

## Examples

``` r
if (FALSE) { # \dontrun{
# Needs LaTeX and dvisvgm.
Matrix(list(list(2, "\\pi"), list(-1, 1)))
IntegerMatrix(rbind(c(3.7, 2), c(42.2, 12)), left_bracket = "(", right_bracket = ")")
} # }
```
