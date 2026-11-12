# Vector fields

`VectorField()` holds a function mapping a position to a vector and
provides methods to move other mobjects along the field.
`ArrowVectorField()` draws the field as a grid of arrows and
`StreamLines()` as traces of agents moving through it. Unless `color` is
given, colors come from `color_scheme` (by default the vector's length)
mapped onto the gradient `colors`.

Methods: `nudge(mob, dt, substeps, pointwise)`,
`nudge_submobjects(dt, substeps, pointwise)`,
`get_nudge_updater(speed, pointwise)`,
`start_submobject_movement(speed, pointwise)`,
`stop_submobject_movement()`, `fit_to_coordinate_system(cs)`,
`shift_func(func, shift_vector)`, `scale_func(func, scalar)`,
`get_colored_background_image(sampling_rate)` (an RGB array) and
`get_vectorized_rgba_gradient_function(start, end, colors)`.
`StreamLines` adds `create()`, `start_animation()` and
`end_animation()`.

## Usage

``` r
DEFAULT_SCALAR_FIELD_COLORS

VectorField(
  func,
  color = NULL,
  color_scheme = NULL,
  min_color_scheme_value = 0,
  max_color_scheme_value = 2,
  colors = DEFAULT_SCALAR_FIELD_COLORS,
  ...
)

vector_field_shift_func(func, shift_vector)

vector_field_scale_func(func, scalar)

ArrowVectorField(
  func,
  color = NULL,
  color_scheme = NULL,
  min_color_scheme_value = 0,
  max_color_scheme_value = 2,
  colors = DEFAULT_SCALAR_FIELD_COLORS,
  x_range = NULL,
  y_range = NULL,
  z_range = NULL,
  three_dimensions = FALSE,
  length_func = NULL,
  opacity = 1,
  vector_config = NULL,
  ...
)

StreamLines(
  func,
  color = NULL,
  color_scheme = NULL,
  min_color_scheme_value = 0,
  max_color_scheme_value = 2,
  colors = DEFAULT_SCALAR_FIELD_COLORS,
  x_range = NULL,
  y_range = NULL,
  z_range = NULL,
  three_dimensions = FALSE,
  noise_factor = NULL,
  n_repeats = 1,
  dt = 0.05,
  virtual_time = 3,
  max_anchors_per_line = 100,
  padding = 3,
  stroke_width = 1,
  opacity = 1,
  ...
)
```

## Arguments

- func:

  Function of a position `c(x, y, z)` returning a vector.

- color:

  Single color for the whole field; disables position based coloring.

- color_scheme:

  Function mapping a vector to a number; defaults to its length.

- min_color_scheme_value, max_color_scheme_value:

  Values mapped to the first and last of `colors`.

- colors:

  Colors of the gradient.

- ...:

  Passed to
  [`VGroup()`](https://adamrsophie.github.io/manimR/reference/VGroupClass.md).

- shift_vector:

  Shift applied to the field.

- scalar:

  Scale applied to the positions.

- x_range, y_range, z_range:

  `c(min, max, step)` (step defaults to 0.5).

- three_dimensions:

  Build a 3D grid (automatic when `z_range` is given).

- length_func:

  Maps a vector's length to its displayed length.

- opacity:

  Opacity of the arrows or stream lines.

- vector_config:

  Named list passed to
  [`Vector()`](https://adamrsophie.github.io/manimR/reference/geometry.md).

- noise_factor:

  Random offset of the stream line starting points; defaults to half of
  the y step.

- n_repeats:

  Number of agents per starting point.

- dt:

  Integration step of the stream lines.

- virtual_time:

  Simulated time; longer gives longer stream lines.

- max_anchors_per_line:

  Maximum anchors per stream line.

- padding:

  Distance agents may leave the spawning area.

- stroke_width:

  Stroke width of the stream lines.

## Details

As upstream, stream lines in the plane are colored through a background
image of the field's colors (`get_colored_background_image()`, so a
line's color changes along it with the field), and 3D stream lines get a
stroke gradient from the colors at their anchors.

## Examples

``` r
if (FALSE) { # \dontrun{
func <- function(pos) ((pos[1] * UR + pos[2] * LEFT) - pos) / 3
ArrowVectorField(func)
StreamLines(func)
} # }
```
