# The CPU side of upstream's OpenGL renderer

Upstream's OpenGL renderer keeps a camera mobject, a tree of 3D objects
and meshes, and compiled shader programs, and draws them with moderngl.
manimR draws with grid and has no OpenGL context, so these ports compute
what upstream computes on the CPU and stop where upstream would draw:

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

  An OpenGL context; manimR has none and keeps what is given.

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

## Value

`OpenGLCamera()`, `Object3D()`, `Mesh()`, `Shader()` and
`FullScreenQuad()` return R6 objects; `filter_attributes()` and
`triangulate_mobject()` shader data; `build_matrix_lists()` a list of
mobject lists named by the 16 values of their matrix, row by row; the
decorators a function.

## Details

- `OpenGLCamera()` is upstream's camera mobject: a frame of five points
  (center, left, right, bottom, top), a model matrix that places it at
  `(0, 0, 11)`, Euler angles (`theta`, `phi`, `gamma`) and the
  projection and view matrices.

- `Object3D(...)` is a node of a tree of objects with a model matrix, a
  normal matrix and updaters; `Mesh()` adds vertex attributes, indices
  and a shader, and `FullScreenQuad()` is a mesh covering the frame.
  `Mesh$render()` needs an OpenGL context and stops.

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

The drawing functions of `vectorized_mobject_rendering`
(`render_opengl_vectorized_mobject_fill()` and the rest),
`OpenGLRenderer` and `Window` need an OpenGL context and are not ported.

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
```
