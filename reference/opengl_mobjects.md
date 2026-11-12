# OpenGL mobject classes

Upstream's OpenGL renderer has its own mobject classes, such as
`OpenGLCircle` or `OpenGLVGroup`. manimR draws every mobject with grid,
so each of them is a subclass of its Cairo counterpart: `OpenGLCircle()`
is a
[`Circle()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
and `inherits(x, "OpenGLCircle")` is `TRUE`. Code written for the OpenGL
renderer runs unchanged. The classes also have the methods of upstream's
OpenGL mobjects, such as `fix_in_frame()`, `set_gloss()`,
`get_shader_data()`, `get_triangulation()` and
`get_shader_wrapper_list()`: they compute the data upstream's renderer
sends to the GPU (see
[`ShaderWrapper()`](https://adamrsophie.github.io/manimR/reference/ShaderWrapper.md)),
from manimR's cubic curves, which they split into upstream's quadratic
ones. manimR draws with grid and has no OpenGL window or camera.

## Arguments

- uv_surface:

  A
  [`Surface()`](https://adamrsophie.github.io/manimR/reference/three_dimensions.md).

- resolution:

  Number of mesh lines along `u` and `v`.

- stroke_width:

  Width of the mesh lines.

- normal_nudge:

  Distance the mesh is moved along the surface normal.

- depth_test, flat_stroke, shader_folder:

  Settings of upstream's shaders, kept but not used.

- image_file:

  Image file (looked up with
  [`get_full_raster_image_path()`](https://adamrsophie.github.io/manimR/reference/path_helpers.md))
  or array for the texture.

- dark_image_file:

  Image for the dark side, stored in `dark_image`.

- image_mode:

  Mode the image is converted to, as in
  [`ImageMobject()`](https://adamrsophie.github.io/manimR/reference/image_mobject.md).

- ...:

  Further arguments for
  [`VGroup()`](https://adamrsophie.github.io/manimR/reference/VGroupClass.md)
  or
  [`Surface()`](https://adamrsophie.github.io/manimR/reference/three_dimensions.md).

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.

## Details

Where upstream's OpenGL class differs from its Cairo counterpart, manimR
follows the OpenGL class:

- `OpenGLArrowTip()` is an `OpenGLTriangle` pointing right.

- `OpenGLArrow()`, `OpenGLVector()` and `OpenGLDoubleArrow()` are filled
  shapes (a stem `thickness` wide and a head, grey by default) and
  subclasses of `OpenGLLine`, not of
  [`Arrow()`](https://adamrsophie.github.io/manimR/reference/geometry.md).

- `OpenGLLine()`, `OpenGLDashedLine()` and `OpenGLTangentLine()` apply
  `buff` twice, as upstream:
  `OpenGLLine(2 * LEFT, 2 * RIGHT, buff = 0.5)` runs from -1 to 1.

- `OpenGLArc(start_angle, angle, radius, n_components, arc_center)`,
  `OpenGLCircle(color)`, `OpenGLSector(outer_radius, inner_radius)`,
  `OpenGLRectangle(color, width, height)`,
  `OpenGLRegularPolygon(n, start_angle)`,
  `OpenGLCubicBezier(a0, h0, h1, a1)` and
  `OpenGLPoint(location, artificial_width, artificial_height)` take
  upstream's arguments in upstream's order.

- Arcs, circles, dots, ellipses, sectors and annuli are made of
  `n_components` quadratic pieces (8 by default), as upstream, stored as
  cubic curves.

- `add_tip(at_start, ...)` of OpenGL lines and arcs adds an
  `OpenGLArrowTip()` made from the `tip_config` of the line and the
  arguments given (white unless they say otherwise).
  `OpenGLCurvedArrow()` and `OpenGLCurvedDoubleArrow()` are
  `OpenGLArcBetweenPoints` with such tips, not
  [`CurvedArrow()`](https://adamrsophie.github.io/manimR/reference/geometry.md)s.

- `OpenGLDashedVMobject(vmobject, num_dashes, dashed_ratio, color)`
  spaces its dashes by the curve's parameter rather than by arc length.

- `OpenGLSurface(uv_func, u_range, v_range, resolution, axes, color, colorscale, colorscale_axis, opacity, gloss, shadow, ...)`
  takes upstream's arguments: `resolution` counts grid points, one more
  than the faces along `u` and `v`, and the surface is one `color`
  (grey) without outlines, and `colorscale` with `axes` colors it by
  value along `colorscale_axis` (0 for x, as upstream). The default
  `resolution` is 33 points (32 faces, as
  [`Surface()`](https://adamrsophie.github.io/manimR/reference/three_dimensions.md))
  rather than upstream's 101: manimR draws each face with grid, not on a
  GPU.

- `OpenGLImageMobject(filename_or_array, width, height, ...)` is 4 units
  high unless `width` or `height` is given.

- `OpenGLMobject(color, opacity, dim, gloss, shadow, ...)` and
  `OpenGLVMobject(fill_color, fill_opacity, stroke_color, stroke_opacity, stroke_width, draw_stroke_behind_fill, ...)`
  take upstream's arguments in upstream's order; `n_points_per_curve` is
  taken but not used, since manimR's curves are cubic.

Three classes have no Cairo counterpart:

- `OpenGLSurfaceGroup(...)` is a surface without faces of its own that
  holds the surfaces it is given.

- `OpenGLSurfaceMesh(uv_surface)` is a
  [`VGroup()`](https://adamrsophie.github.io/manimR/reference/VGroupClass.md)
  of curves along the grid lines of a surface (`resolution` lines in
  each direction, 21 by default), lifted `normal_nudge` along the
  surface normal so they show on top of it.

- `OpenGLTexturedSurface(uv_surface, image_file)` is a copy of a surface
  whose faces take the color of the image at their center: `u` runs
  along the image from left to right and `v` from bottom to top, as
  upstream's texture coordinates. Upstream's shader shows
  `dark_image_file` on the side facing away from the light; manimR keeps
  it in `dark_image` but draws the light image on both sides.

## Examples

``` r
c1 <- OpenGLCircle(radius = 2)
inherits(c1, "Circle")
#> [1] TRUE
s <- OpenGLSurface(function(u, v) c(u, v, u * v), u_range = c(-1, 1), v_range = c(-1, 1),
                   resolution = 9)
mesh <- OpenGLSurfaceMesh(s, resolution = c(5, 5))
length(mesh$submobjects)
#> [1] 10
img <- matrix(c("red", "blue", "green", "white"), 2, 2)
tex <- OpenGLTexturedSurface(s, img)
```
