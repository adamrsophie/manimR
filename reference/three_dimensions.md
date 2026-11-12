# Three dimensional mobjects

- `ThreeDVMobject()`: a
  [`VMobject()`](https://adamrsophie.github.io/manimR/reference/VMobjectClass.md)
  with `shade_in_3d = TRUE`.

- `Surface(func, u_range, v_range, resolution)`: a parametric surface
  `func(u, v)` (returning a length 3 point) made of checkerboard faces.
  `set_fill_by_checkerboard(...)` recolors the faces and
  `set_fill_by_value(axes, colorscale, axis)` colors them by a
  coordinate (`axis` 1, 2 or 3 for x, y, z).

- `Sphere()`, `Dot3D()`, `Cone()`, `Cylinder()`, `Line3D()`, `Arrow3D()`
  and `Torus()` are surfaces; `Cube()` and `Prism()` are groups of
  square faces.

## Usage

``` r
ThreeDVMobject(shade_in_3d = TRUE, ...)

Surface(
  func = NULL,
  u_range = c(0, 1),
  v_range = c(0, 1),
  resolution = 32,
  surface_piece_config = list(),
  fill_color = BLUE_D,
  fill_opacity = 1,
  checkerboard_colors = c(BLUE_D, BLUE_E),
  stroke_color = LIGHT_GREY,
  stroke_width = 0.5,
  should_make_jagged = FALSE,
  pre_function_handle_to_anchor_scale_factor = 1e-05,
  ...
)

Sphere(
  center = ORIGIN,
  radius = 1,
  resolution = NULL,
  u_range = c(0, TAU),
  v_range = c(0, PI),
  ...
)

Dot3D(
  point = ORIGIN,
  radius = DEFAULT_DOT_RADIUS,
  color = WHITE,
  resolution = c(8, 8),
  ...
)

Cube(
  side_length = 2,
  fill_opacity = 0.75,
  fill_color = BLUE,
  stroke_width = 0,
  ...
)

Prism(dimensions = c(3, 2, 1), ...)

Cone(
  base_radius = 1,
  height = 1,
  direction = Z_AXIS,
  show_base = FALSE,
  v_range = c(0, TAU),
  u_min = 0,
  checkerboard_colors = FALSE,
  ...
)

Cylinder(
  radius = 1,
  height = 2,
  direction = Z_AXIS,
  v_range = c(0, TAU),
  show_ends = TRUE,
  resolution = c(24, 24),
  ...
)

Line3D(
  start = LEFT,
  end = RIGHT,
  thickness = 0.02,
  color = NULL,
  resolution = 24,
  ...
)

Line3D_parallel_to(line, point = ORIGIN, length = 5, cls = Line3D, ...)

Line3D_perpendicular_to(line, point = ORIGIN, length = 5, cls = Line3D, ...)

Arrow3D(
  start = LEFT,
  end = RIGHT,
  thickness = 0.02,
  height = 0.3,
  base_radius = 0.08,
  color = WHITE,
  resolution = 24,
  ...
)

Torus(
  major_radius = 3,
  minor_radius = 1,
  u_range = c(0, TAU),
  v_range = c(0, TAU),
  resolution = NULL,
  ...
)
```

## Arguments

- shade_in_3d:

  Shade the faces according to their orientation to the light source.

- ...:

  Other named arguments, passed to
  [`VMobject()`](https://adamrsophie.github.io/manimR/reference/VMobjectClass.md).

- func:

  Function of `(u, v)` returning a point.

- u_range, v_range:

  Ranges `c(min, max)` of the `u` and `v` parameters.

- resolution:

  Number of faces along `u` and `v`: one value or `c(u, v)`; `NULL` uses
  the class default.

- surface_piece_config:

  List of extra arguments for each face.

- fill_color, fill_opacity:

  Fill color and opacity of the faces.

- checkerboard_colors:

  Colors alternated across the faces; `FALSE` keeps `fill_color`.

- stroke_color, stroke_width:

  Color and width of the face outlines.

- should_make_jagged:

  Change the anchor mode of the curves from smooth to jagged.

- pre_function_handle_to_anchor_scale_factor:

  Kept for compatibility with Manim.

- center, radius:

  Center and radius of a sphere, dot or cylinder.

- point:

  Center of the dot; for `Line3D_parallel_to()` and
  `Line3D_perpendicular_to()`, the point the new line passes through.

- color:

  Color of the mobject.

- side_length:

  Side length of the cube.

- dimensions:

  Side lengths of the prism along x, y and z.

- base_radius:

  Radius of the base of a cone or arrow tip.

- height:

  Height of a cone or cylinder, or length of the arrow tip.

- direction:

  Direction the cone or cylinder points along.

- show_base:

  Draw the base disc of the cone.

- u_min:

  Radius at the apex of the cone.

- show_ends:

  Draw the end caps of the cylinder.

- start, end:

  Start and end points of the line or arrow; they may be mobjects.

- thickness:

  Thickness of the line or arrow shaft.

- line:

  A `Line3D()`.

- length:

  Length of the new line.

- cls:

  Constructor for the new line.

- major_radius, minor_radius:

  Distance from the center of the torus to the center of its tube, and
  the radius of the tube.

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.

## Details

`Line3D_parallel_to()` and `Line3D_perpendicular_to()` port the upstream
class methods `Line3D.parallel_to()` and `Line3D.perpendicular_to()`: a
line of `length` through `point`.

## Examples

``` r
s <- Sphere(radius = 1.5, resolution = c(12, 6))
cube <- Cube(side_length = 2, fill_color = RED)
surf <- Surface(function(u, v) c(u, v, sin(u) * cos(v)),
                u_range = c(-2, 2), v_range = c(-2, 2), resolution = 8)
```
