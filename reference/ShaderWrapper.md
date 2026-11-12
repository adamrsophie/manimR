# Shader wrappers

The CPU side of upstream's OpenGL draw calls: a `ShaderWrapper` holds
the vertex data, vertex indices, uniforms and GLSL source of one draw
call. manimR draws with grid and has no OpenGL renderer, so nothing
sends these to a GPU; they describe what upstream's renderer would draw,
and the GLSL files of upstream ship in the package (`get_shader_dir()`).

## Usage

``` r
get_shader_dir()

find_file(file_name, directories)

get_shader_code_from_file(filename)

get_colormap_code(rgb_list)

ShaderWrapper(
  vert_data = NULL,
  vert_indices = NULL,
  shader_folder = NULL,
  uniforms = NULL,
  texture_paths = NULL,
  depth_test = FALSE,
  render_primitive = 5L
)
```

## Arguments

- file_name:

  A file name or path.

- directories:

  Folders searched in turn.

- filename:

  A GLSL file, relative to `get_shader_dir()`.

- rgb_list:

  A matrix (or list) of RGB rows.

- vert_data:

  Shader data, as returned by an OpenGL mobject's `get_shader_data()`.

- vert_indices:

  Vertex indices (0 based, as upstream), or `NULL`.

- shader_folder:

  Folder of the GLSL files under `get_shader_dir()`.

- uniforms:

  Named list of uniforms.

- texture_paths:

  Named list of textures.

- depth_test:

  Whether the draw call tests depth.

- render_primitive:

  moderngl primitive number, which upstream stores as a string: 0
  points, 1 lines, 2 line loop, 3 line strip, 4 triangles, 5 triangle
  strip (the default) or 6 triangle fan.

## Value

`ShaderWrapper()` returns an R6 object. `get_shader_dir()` and
`find_file()` return paths, `get_shader_code_from_file()` the GLSL code
or `NULL`, and `get_colormap_code()` a string.

## Details

`get_shader_code_from_file()` reads a GLSL file and inlines its
`#include ../include/...` lines; `find_file()` looks a file up in a list
of folders; `get_colormap_code()` writes a GLSL array of colors.

## Examples

``` r
w <- ShaderWrapper(OpenGLMobject()$get_shader_data(), shader_folder = "surface")
nchar(w$program_code$vertex_shader)
#> [1] 3154
```
