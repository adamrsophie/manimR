# Table

Displays a table: entries made with `element_to_mobject` (by default
[`Paragraph()`](https://adamrsophie.github.io/manimR/reference/Paragraph.md))
arranged in a grid, with optional row and column labels and lines
between the cells. `MathTable()`, `MobjectTable()`, `IntegerTable()` and
`DecimalTable()` use
[`MathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md),
the given mobjects,
[`Integer()`](https://adamrsophie.github.io/manimR/reference/DecimalNumberClass.md)
and
[`DecimalNumber()`](https://adamrsophie.github.io/manimR/reference/DecimalNumberClass.md)
as entries.

Positions `pos = c(row, col)` are 1 based with `c(1, 1)` the top left
entry. Methods: `get_rows()`, `get_columns()`, `get_entries(pos)`,
`get_entries_without_labels(pos)`, `get_row_labels()`,
`get_col_labels()`, `get_labels()`, `get_horizontal_lines()`,
`get_vertical_lines()`, `set_row_colors(...)`, `set_column_colors(...)`,
`get_cell(pos, ...)`, `get_highlighted_cell(pos, color, ...)`,
`add_highlighted_cell(pos, color, ...)`, `add_background_to_entries()`
and `create(...)`, an animation drawing the table.

## Usage

``` r
Table(
  table,
  row_labels = NULL,
  col_labels = NULL,
  top_left_entry = NULL,
  v_buff = 0.8,
  h_buff = 1.3,
  include_outer_lines = FALSE,
  include_inner_lines = TRUE,
  add_background_rectangles_to_entries = FALSE,
  entries_background_color = BLACK,
  include_background_rectangle = FALSE,
  background_rectangle_color = BLACK,
  element_to_mobject = Paragraph,
  element_to_mobject_config = list(),
  arrange_in_grid_config = list(),
  line_config = list(),
  ...
)

MathTable(table, element_to_mobject = MathTex, ...)

MobjectTable(table, element_to_mobject = function(m) m, ...)

IntegerTable(table, element_to_mobject = Integer, ...)

DecimalTable(
  table,
  element_to_mobject = DecimalNumber,
  element_to_mobject_config = list(num_decimal_places = 1),
  ...
)
```

## Arguments

- table:

  An R matrix, a data frame, or a list of rows (vectors or lists) of
  equal length.

- row_labels, col_labels:

  Lists of mobjects labeling the rows and columns.

- top_left_entry:

  Mobject in the top left corner (needs both kinds of labels).

- v_buff, h_buff:

  Vertical and horizontal buffer between cells.

- include_outer_lines:

  Draw the outer border.

- include_inner_lines:

  Draw the lines between cells.

- add_background_rectangles_to_entries:

  Add a background rectangle to each entry.

- entries_background_color:

  Color of those rectangles.

- include_background_rectangle:

  Add a background rectangle to the table.

- background_rectangle_color:

  Color of that rectangle.

- element_to_mobject:

  Constructor applied to each entry.

- element_to_mobject_config:

  Named list of extra arguments for it.

- arrange_in_grid_config:

  Named list passed to `arrange_in_grid()`.

- line_config:

  Named list passed to
  [`Line()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  for the table lines.

- ...:

  Passed to
  [`VGroup()`](https://adamrsophie.github.io/manimR/reference/VGroupClass.md).

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.

## Examples

``` r
t <- Table(list(c("This", "is a"), c("simple", "Table in \n Manim.")))
t$add_highlighted_cell(c(2, 2), color = GREEN)
```
