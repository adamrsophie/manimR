# Sample spaces and bar charts

`SampleSpace()` is a rectangle that can be divided horizontally or
vertically into parts with areas proportional to probabilities, with
braces and labels. `BarChart()` is an
[`Axes()`](https://adamrsophie.github.io/manimR/reference/coordinate_systems.md)
with one bar per value.

## Usage

``` r
SampleSpace(
  height = 3,
  width = 3,
  fill_color = DARK_GREY,
  fill_opacity = 1,
  stroke_width = 0.5,
  stroke_color = LIGHT_GREY,
  default_label_scale_val = 1,
  ...
)

# S3 method for class 'SampleSpace'
x[i, ...]

BarChart(
  values,
  bar_names = NULL,
  y_range = NULL,
  x_length = NULL,
  y_length = NULL,
  bar_colors = c("#003f5c", "#58508d", "#bc5090", "#ff6361", "#ffa600"),
  bar_width = 0.6,
  bar_fill_opacity = 0.7,
  bar_stroke_width = 3,
  x_axis_config = NULL,
  y_axis_config = NULL,
  tips = FALSE,
  ...
)
```

## Arguments

- height, width:

  Size of the sample space.

- fill_color, fill_opacity, stroke_width, stroke_color:

  Style.

- default_label_scale_val:

  Scale applied to string labels.

- ...:

  Passed to
  [`Rectangle()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  or
  [`Axes()`](https://adamrsophie.github.io/manimR/reference/coordinate_systems.md).

- x:

  A SampleSpace.

- i:

  Index (1 based).

- values:

  Numeric bar heights.

- bar_names:

  Labels under the bars.

- y_range:

  `c(min, max, step)` of the y axis; computed from `values` when `NULL`.

- x_length, y_length:

  Axis lengths.

- bar_colors:

  Colors spread over the bars as a gradient.

- bar_width:

  Width of each bar in x units.

- bar_fill_opacity, bar_stroke_width:

  Bar style.

- x_axis_config, y_axis_config:

  Lists of
  [`NumberLine()`](https://adamrsophie.github.io/manimR/reference/NumberLine.md)
  arguments.

- tips:

  Whether the axes get tips.

## Value

A mobject.

## Details

SampleSpace methods: `add_title()`, `add_label()`, `complete_p_list()`,
`get_horizontal_division()`, `get_vertical_division()`,
`divide_horizontally()`, `divide_vertically()`,
`get_side_braces_and_labels()`, `get_top_braces_and_labels()`,
`get_bottom_braces_and_labels()`, `add_braces_and_labels()`. Indexing
`space[i]` returns the i-th part once the space is divided.

BarChart methods: `get_bar_labels()`, `change_bar_values()`. Bars are in
the field `bars`.

## Examples

``` r
if (FALSE) { # \dontrun{
s <- SampleSpace()$divide_vertically(c(0.3, 0.7))
chart <- BarChart(c(1, 3, 2), bar_names = c("a", "b", "c"))
} # }
```
