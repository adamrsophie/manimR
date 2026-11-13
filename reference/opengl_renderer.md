# Upstream's OpenGL renderer

Upstream's OpenGL renderer keeps a camera mobject, a tree of 3D objects
and meshes, and compiled shader programs, and draws them with moderngl.
manimR computes what upstream computes on the CPU and draws the result
in software, with a context whose framebuffers are off screen graphics
devices:

## Usage

``` r
OpenGLCamera(
  frame_shape = NULL,
  center_point = NULL,
  euler_angles = NULL,
  focal_distance = 2,
  light_source_position = NULL,
  orthographic = FALSE,
  minimum_polar_angle = -PI/2,
  maximum_polar_angle = PI/2,
  model_matrix = NULL,
  ...
)

Object3D(...)

Mesh(
  shader = NULL,
  attributes = NULL,
  geometry = NULL,
  material = NULL,
  indices = NULL,
  use_depth_test = TRUE,
  primitive = 4L
)

Shader(context = NULL, name = NULL, source = NULL)

FullScreenQuad(
  context = NULL,
  fragment_shader_source = NULL,
  fragment_shader_name = NULL
)

filter_attributes(unfiltered_attributes, attributes)

build_matrix_lists(mob)

triangulate_mobject(mob)

affects_shader_info_id(func)

triggers_refreshed_triangulation(func)

OpenGLSoftwareContext(...)

render_opengl_vectorized_mobject_fill(renderer, mobject)

render_mobject_fills_with_matrix(renderer, model_matrix, mobjects)

render_opengl_vectorized_mobject_stroke(renderer, mobject)

render_mobject_strokes_with_matrix(renderer, model_matrix, mobjects)

OpenGLRenderer(
  file_writer_class = SceneFileWriterClass,
  skip_animations = FALSE
)

Window(
  renderer,
  window_size = cfg("window_size"),
  monitor = NULL,
  open = TRUE,
  ...
)
```

## Arguments

- frame_shape:

  Width and height of the frame; the config's frame size by default.

- center_point:

  Center of the frame.

- euler_angles:

  `theta`, `phi` and `gamma`, in radians.

- focal_distance:

  Focal distance, in frame heights.

- light_source_position:

  Position of the light.

- orthographic:

  Whether the projection is orthographic.

- minimum_polar_angle, maximum_polar_angle:

  Limits of `phi`.

- model_matrix:

  Initial model matrix.

- ...:

  For `OpenGLCamera()`, further arguments for
  [`OpenGLMobject()`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md);
  for `Object3D()`, child objects.

- shader, material:

  A `Shader`.

- attributes:

  For `Mesh()`, shader data (see
  [`ShaderWrapper()`](https://adamrsophie.github.io/manimR/reference/ShaderWrapper.md));
  for `filter_attributes()`, the names of the attributes to keep.

- geometry:

  A mesh whose attributes and indices are used.

- indices:

  Vertex indices, 0 based.

- use_depth_test:

  Whether the mesh is drawn with a depth test.

- primitive:

  moderngl primitive number (4 for triangles).

- context:

  A context, as `OpenGLSoftwareContext()`, kept with the shader.

- name:

  Name of a shader folder under `SHADER_FOLDER`.

- source:

  List of GLSL code.

- fragment_shader_source, fragment_shader_name:

  Code of the fragment shader, or the name of a `.frag` file under
  `SHADER_FOLDER`.

- unfiltered_attributes:

  Shader data.

- mob:

  An OpenGL mobject.

- func:

  A method, a function of `self` and further arguments.

- renderer:

  An `OpenGLRenderer`.

- mobject:

  An OpenGL VMobject.

- mobjects:

  A list of OpenGL VMobjects.

- file_writer_class:

  Class of the scene's file writer.

- skip_animations:

  Whether animations are skipped.

- window_size:

  `"default"`, `"width,height"` or two integers.

- monitor:

  List of `x`, `y`, `width` and `height` of the monitor.

- open:

  Whether to open the window's graphics device.

## Value

`OpenGLCamera()`, `Object3D()`, `Mesh()`, `Shader()`,
`FullScreenQuad()`, `OpenGLRenderer()`, `OpenGLSoftwareContext()` and
`Window()` return R6 objects; the `render_*` functions return `NULL`
invisibly; `filter_attributes()` and `triangulate_mobject()` shader
data; `build_matrix_lists()` a list of mobject lists named by the 16
values of their matrix, row by row; the decorators a function.

## Details

- `OpenGLCamera()` is upstream's camera mobject: a frame of five points
  (center, left, right, bottom, top), a model matrix that places it at
  `(0, 0, 11)`, Euler angles (`theta`, `phi`, `gamma`) and the
  projection and view matrices.

- `Object3D(...)` is a node of a tree of objects with a model matrix, a
  normal matrix and updaters; `Mesh()` adds vertex attributes, indices
  and a shader, and `FullScreenQuad()` is a mesh covering the frame. A
  scene takes meshes with `add()`, and `OpenGLRenderer` draws them after
  the mobjects: a mesh whose shader is one of upstream's mesh shaders
  (the `default`, `manim_coords`, `vertex_colors` and `test` folders) is
  rasterized by their rules; `Mesh$render()` of other GLSL code needs an
  OpenGL context and stops, as does a `FullScreenQuad` (whose vertex
  shader upstream's GLSL compiler rejects).

- `Shader(context, name, source)` reads the GLSL code of a shader folder
  under `SHADER_FOLDER` (or takes `source`, a list of `vertex_shader`,
  `fragment_shader` and `geometry_shader` code) and keeps it in
  `shader_program_cache` by name; `set_uniform()` stores a value for a
  uniform the code declares and ignores others, as upstream.

- `filter_attributes()` keeps the named attributes of shader data.

- `build_matrix_lists()` groups a mobject's family by hierarchical model
  matrix, and `triangulate_mobject()` gives the fill triangles of a
  VMobject with upstream's texture coordinates and modes.

- `affects_shader_info_id(func)` and
  `triggers_refreshed_triangulation(func)` are upstream's decorators as
  functions: they wrap a method `func(self, ...)`.

- `OpenGLRenderer()` renders scenes as upstream's renderer: it clears
  its framebuffer to the background color, sets the perspective uniforms
  from the camera (`refresh_perspective_uniforms()`) and draws each
  mobject. The shader wrappers run upstream's GLSL rules in software, in
  the order of upstream's `get_shader_wrapper_list()`: a VMobject's
  family runs the quadratic_bezier_fill and quadratic_bezier_stroke
  shaders (anti aliased fills, and strokes with upstream's joints and
  ends), an `OpenGLSurface` the surface shader, an
  `OpenGLTexturedSurface` or `OpenGLImageMobject` the textured_surface
  shader (nearest texel), and an OpenGL point cloud the true_dot shader.
  Points are placed as the shaders place them (rotated by
  `camera_rotation`, scaled by `focal_distance / (focal_distance - z)`,
  fixed in frame mobjects in the default frame); triangles are
  rasterized at pixel centers, lit per pixel by upstream's
  `add_light()`, and with `depth_test` (on by default for surfaces)
  tested against and written to the framebuffer's depth buffer. A plain
  `ImageMobject`, on which upstream's OpenGL renderer raises, is drawn
  by a grid camera. `config$renderer = "opengl"` makes scenes use it.
  `get_frame()` gives a `nativeRaster`;
  `get_raw_frame_buffer_object_data()` the pixels bottom row first, as
  OpenGL reads them.

- `render_opengl_vectorized_mobject_fill()`,
  `render_opengl_vectorized_mobject_stroke()` and their `_with_matrix`
  helpers build upstream's vertex buffers and uniforms and draw them as
  upstream's projection shaders do (with
  `config$use_projection_fill_shaders` and
  `config$use_projection_stroke_shaders`): the fill keeps the part of
  each triangle on the side of its curve given by its texture mode, and
  the stroke the points within `0.004 * width` of its curve.

- `OpenGLSoftwareContext()` stands for moderngl's context:
  `framebuffer()`, `buffer()` and `simple_vertex_array()`, whose
  [`render()`](https://adamrsophie.github.io/manimR/reference/render.md)
  draws the `vectorized_mobject_fill` and `vectorized_mobject_stroke`
  shaders. GLSL code written for a `Mesh` is not run.

- `Window(renderer)` is the window of a live preview: an R graphics
  device (an interactive session is needed) that shows the renderer's
  frame on `swap_buffers()`; `handle_event()` waits for a mouse or key
  event in it and passes it to the scene's handlers, on devices that
  report events (X11 and Windows). Its size follows `config$window_size`
  and its position `config$window_position` on the monitor, which is
  `getOption("manimR.monitor")` (a list of `x`, `y`, `width` and
  `height`) or 1920 by 1080 pixels at the origin.

## Examples

``` r
cam <- OpenGLCamera()
cam$set_euler_angles(theta = PI / 4, phi = PI / 3)
round(cam$inverse_rotation_matrix, 3)
#>        [,1]   [,2]  [,3]
#> [1,]  0.707  0.707 0.000
#> [2,] -0.354  0.354 0.866
#> [3,]  0.612 -0.612 0.500
cam$get_position()
#> [1]  0  0 11
tri <- triangulate_mobject(OpenGLSquare())
length(tri)
#> [1] 42
s <- Shader(name = "surface")
names(s$shader_program)
#> [1] "fragment_shader" "vertex_shader"  
# \donttest{
r <- OpenGLRenderer()
scene <- Scene$new(renderer = r)
scene$add(OpenGLCircle()$set_fill(RED, 1))
r$update_frame(scene)
dim(r$get_raw_frame_buffer_object_data())
#> [1] 1080 1920    4
r$close_device()
# }
```
