# Coordinate systems

`Axes()` draws an x and a y
[`NumberLine()`](https://adamrsophie.github.io/manimR/reference/NumberLine.md)
that cross at the origin of the coordinates. `ThreeDAxes()` adds a z
axis. `NumberPlane()` adds a grid of background lines, `PolarPlane()` a
polar grid, and `ComplexPlane()` a plane addressed by complex numbers.

## Usage

``` r
Axes(
  x_range = NULL,
  y_range = NULL,
  x_length = round(frame_width()) - 2,
  y_length = round(frame_height()) - 2,
  axis_config = NULL,
  x_axis_config = NULL,
  y_axis_config = NULL,
  tips = TRUE,
  ...
)

ThreeDAxes(
  x_range = c(-6, 6, 1),
  y_range = c(-5, 5, 1),
  z_range = c(-4, 4, 1),
  x_length = frame_height() + 2.5,
  y_length = frame_height() + 2.5,
  z_length = frame_height() - 1.5,
  z_axis_config = NULL,
  z_normal = DOWN,
  num_axis_pieces = 20,
  light_source = 9 * DOWN + 7 * LEFT + 10 * OUT,
  depth = NULL,
  gloss = 0.5,
  ...
)

NumberPlane(
  x_range = c(-frame_x_radius(), frame_x_radius(), 1),
  y_range = c(-frame_y_radius(), frame_y_radius(), 1),
  x_length = NULL,
  y_length = NULL,
  background_line_style = NULL,
  faded_line_style = NULL,
  faded_line_ratio = 1,
  make_smooth_after_applying_functions = TRUE,
  axis_config = NULL,
  y_axis_config = NULL,
  ...
)

PolarPlane(
  radius_max = frame_y_radius(),
  size = NULL,
  radius_step = 1,
  azimuth_step = NULL,
  azimuth_units = "PI radians",
  azimuth_compact_fraction = TRUE,
  azimuth_offset = 0,
  azimuth_direction = "CCW",
  azimuth_label_buff = SMALL_BUFF,
  azimuth_label_font_size = 24,
  radius_config = NULL,
  background_line_style = NULL,
  faded_line_style = NULL,
  faded_line_ratio = 1,
  make_smooth_after_applying_functions = TRUE,
  ...
)

ComplexPlane(
  x_range = c(-frame_x_radius(), frame_x_radius(), 1),
  y_range = c(-frame_y_radius(), frame_y_radius(), 1),
  x_length = NULL,
  y_length = NULL,
  background_line_style = NULL,
  faded_line_style = NULL,
  faded_line_ratio = 1,
  make_smooth_after_applying_functions = TRUE,
  axis_config = NULL,
  y_axis_config = NULL,
  ...
)

CoordinateSystem(
  x_range = NULL,
  y_range = NULL,
  x_length = NULL,
  y_length = NULL,
  dimension = 2,
  ...
)
```

## Arguments

- x_range, y_range, z_range:

  `c(min, max, step)` of each axis.

- x_length, y_length, z_length:

  Lengths of the axes.

- axis_config, x_axis_config, y_axis_config, z_axis_config:

  Lists of arguments for the
  [`NumberLine()`](https://adamrsophie.github.io/manimR/reference/NumberLine.md)
  of every axis or of one axis.

- tips:

  Whether the axes get arrow tips.

- ...:

  Passed to
  [`VGroup()`](https://adamrsophie.github.io/manimR/reference/VGroupClass.md)
  (style).

- z_normal:

  Direction the z axis is rotated toward before tilting.

- num_axis_pieces:

  Number of pieces each axis is cut into for 3D depth sorting.

- light_source:

  Light direction; every axis piece has a sheen of 0.2 along it.

- depth, gloss:

  Unused; kept for compatibility.

- background_line_style:

  List of style arguments for the grid lines.

- faded_line_style:

  Style of the faded lines; defaults to a halved
  `background_line_style`.

- faded_line_ratio:

  Number of faded lines per grid cell.

- make_smooth_after_applying_functions:

  Accepted for compatibility; upstream's VMobject initializer resets it
  to `FALSE`, so it has no effect.

- radius_max:

  Largest radius drawn.

- size:

  Diameter of the plane; `NULL` means one unit per radius step.

- radius_step:

  Spacing of the circles.

- azimuth_step:

  Number of radial lines (or the angle units per line).

- azimuth_units:

  One of `"PI radians"`, `"TAU radians"`, `"degrees"`, `"gradians"` or
  `NULL`.

- azimuth_compact_fraction:

  Whether to write labels like \\\frac{\pi}{4}\\ instead of
  \\\frac{1}{4}\pi\\.

- azimuth_offset:

  Angle of the first radial line.

- azimuth_direction:

  `"CCW"` or `"CW"`.

- azimuth_label_buff, azimuth_label_font_size:

  Azimuth label layout.

- radius_config:

  List of arguments for the radius
  [`NumberLine()`](https://adamrsophie.github.io/manimR/reference/NumberLine.md).

- dimension:

  Number of axes of a coordinate system, 2 or 3.

## Value

A coordinate system mobject.

## Details

All coordinate systems share these methods (`CoordinateSystemClass`):
`coords_to_point()` (alias `c2p`), `point_to_coords()` (alias `p2c`),
`polar_to_point()` (`pr2pt`), `point_to_polar()` (`pt2pr`),
`get_axis(i)` (1 based), `get_x_axis()`, `get_y_axis()`, `get_z_axis()`,
`get_origin()`, `get_x_axis_label()`, `get_y_axis_label()`,
`get_axis_labels()`, `add_coordinates()`,
[`plot()`](https://rdrr.io/r/graphics/plot.default.html),
`plot_implicit_curve()`, `plot_parametric_curve()`,
`plot_polar_graph()`, `plot_surface()`, `plot_derivative_graph()`,
`plot_antiderivative_graph()`, `input_to_graph_point()` (`i2gp`),
`input_to_graph_coords()` (`i2gc`), `get_graph_label()`,
`get_riemann_rectangles()`, `get_area()`, `angle_of_tangent()`,
`slope_of_tangent()`, `get_secant_slope_group()`, `get_vertical_line()`,
`get_horizontal_line()`, `get_lines_to_point()`,
`get_vertical_lines_to_graph()` and `get_T_label()`. `Axes` adds
`plot_line_graph()`.

Shapes follow upstream: `c2p(x, y)` with numbers, or `c2p(c(x, y))`,
returns one point; `c2p(m)` with an n x k matrix whose rows are
coordinates returns an n x 3 matrix of points; `c2p(xs, ys)` with
vectors returns a 3 x n matrix (rows x, y, z). `p2c()` returns a vector
for one point and an n x d matrix for an n x 3 matrix of points.

Differences from Python: the point function of a graph is `graph$func`
(`function` is reserved in R); axis indices and `colorscale_axis` are 1
based; dictionaries become lists named by the numeric positions, for
example `list("1" = "a", "2" = "b")`.

## Examples

``` r
ax <- Axes(x_range = c(-3, 3), y_range = c(-2, 2))
g <- ax$plot(sin, color = BLUE)
area <- ax$get_area(g, x_range = c(0, 2))
plane <- NumberPlane()
```
