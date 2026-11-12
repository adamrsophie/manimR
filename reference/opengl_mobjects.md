# OpenGL mobject classes

Upstream's OpenGL renderer has its own mobject classes, such as
`OpenGLCircle` or `OpenGLVGroup`. manimR draws every mobject with grid,
so each of them is a subclass of its Cairo counterpart that takes the
same arguments: `OpenGLCircle()` is a
[`Circle()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
and `inherits(x, "OpenGLCircle")` is `TRUE`. Code written for the OpenGL
renderer runs unchanged; the GPU pipeline itself (shaders, the OpenGL
camera and window) is not part of manimR.

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

## Details

Two classes have no Cairo counterpart:

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

`get_mobject_class()`, `get_vectorized_mobject_class()` and
`get_point_mobject_class()` return the base classes for the active
renderer, as upstream's `manim.mobject.utils`; with manimR's renderer
they are
[MobjectClass](https://adamrsophie.github.io/manimR/reference/MobjectClass.md),
[VMobjectClass](https://adamrsophie.github.io/manimR/reference/VMobjectClass.md)
and
[PMobjectClass](https://adamrsophie.github.io/manimR/reference/point_cloud.md).

## Examples

``` r
c1 <- OpenGLCircle(radius = 2)
inherits(c1, "Circle")
#> [1] TRUE
s <- OpenGLSurface(function(u, v) c(u, v, u * v), u_range = c(-1, 1), v_range = c(-1, 1),
                   resolution = 8)
mesh <- OpenGLSurfaceMesh(s, resolution = c(5, 5))
length(mesh$submobjects)
#> [1] 10
img <- matrix(c("red", "blue", "green", "white"), 2, 2)
tex <- OpenGLTexturedSurface(s, img)
```
