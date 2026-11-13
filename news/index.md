# Changelog

## manimR 0.1.0

- First release: a native R port of Manim Community 0.22 (the Cairo
  style renderer), covering every public name and class method of
  `from manim import *` (checked by
  `tests/testthat/test-api-coverage.R`). Every upstream class has an R6
  generator `FooClass`, including the ones upstream defines only to
  preset arguments.
- Rendered output and the LaTeX cache go to a `media` folder in the R
  session’s temporary directory unless `media_dir` is set, so nothing is
  written to the working directory by default;
  [`manim_cli()`](https://adamrsophie.github.io/manimR/reference/manim_cli.md)
  writes to a `media` folder in `tools::R_user_dir("manimR", "cache")`
  unless `--media_dir` is given (`--media_dir media` writes `./media` as
  Manim’s command line does).
- Output follows Manim 0.22’s render sessions: `format` is `"auto"`,
  `"mp4"`, `"mov"`, `"webm"`, `"gif"`, `"png"` (last frame),
  `"png-sequence"` or `"none"`, with `dry_run`, directory templates
  ([`get_dir()`](https://adamrsophie.github.io/manimR/reference/get_dir.md)),
  `manim.cfg` files
  ([`digest_config_file()`](https://adamrsophie.github.io/manimR/reference/digest_config_file.md)),
  encoder settings and per scene log files. Partial movie files are
  cached by a hash of each play, and sections, sound and subtitles are
  written as upstream.
- [`Tex()`](https://adamrsophie.github.io/manimR/reference/tex.md) and
  [`MathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md)
  through LaTeX and dvisvgm,
  [`Typst()`](https://adamrsophie.github.io/manimR/reference/typst.md)
  and
  [`MathTypst()`](https://adamrsophie.github.io/manimR/reference/typst.md)
  through the typst compiler,
  [`Text()`](https://adamrsophie.github.io/manimR/reference/TextClass.md)
  and
  [`MarkupText()`](https://adamrsophie.github.io/manimR/reference/MarkupText.md)
  through system fonts, and
  [`Code()`](https://adamrsophie.github.io/manimR/reference/CodeClass.md)
  highlighted with Pygments when Python has it.
- The command line
  ([`manim_cli()`](https://adamrsophie.github.io/manimR/reference/manim_cli.md))
  takes `manim render`’s options and the `checkhealth`, `cfg`, `init`,
  `plugins` and `cache clear` subcommands.
- RStudio addins (including rendering as a background job), a `manim`
  knitr engine for R Markdown and Quarto, printing of
  [`render()`](https://adamrsophie.github.io/manimR/reference/render.md)
  results in documents, Shiny output functions
  ([`manimOutput()`](https://adamrsophie.github.io/manimR/reference/manimOutput.md),
  [`renderManim()`](https://adamrsophie.github.io/manimR/reference/manimOutput.md))
  and an interactive Shiny window for scenes.
- [`as_mobject()`](https://adamrsophie.github.io/manimR/reference/as_mobject.md)
  turns ggplot2, grid and base graphics into mobjects,
  [`scene_frame()`](https://adamrsophie.github.io/manimR/reference/scene_frame.md)
  renders one frame of a scene,
  [`expect_snapshot_frame()`](https://adamrsophie.github.io/manimR/reference/scene_frame.md)
  tests frames with testthat, and `GraphClass$from_igraph()` imports
  igraph graphs.
- The mobject classes of upstream’s OpenGL renderer
  ([`OpenGLCircle()`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md),
  [`OpenGLVGroup()`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md),
  [`OpenGLSurface()`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  and the rest) build on their Cairo counterparts, so code written for
  that renderer runs unchanged;
  [`OpenGLSurfaceMesh()`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  and
  [`OpenGLTexturedSurface()`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  are ported to grid. They also have the methods and argument names of
  upstream’s OpenGL classes, including the CPU side of its GPU pipeline:
  shader data, triangulation, uniforms and
  [`ShaderWrapper()`](https://adamrsophie.github.io/manimR/reference/ShaderWrapper.md),
  with upstream’s GLSL files. The CPU side of upstream’s OpenGL renderer
  is ported too: the camera
  ([`OpenGLCamera()`](https://adamrsophie.github.io/manimR/reference/opengl_renderer.md)),
  trees of 3D objects and meshes
  ([`Object3D()`](https://adamrsophie.github.io/manimR/reference/opengl_renderer.md),
  [`Mesh()`](https://adamrsophie.github.io/manimR/reference/opengl_renderer.md)),
  [`Shader()`](https://adamrsophie.github.io/manimR/reference/opengl_renderer.md),
  [`triangulate_mobject()`](https://adamrsophie.github.io/manimR/reference/opengl_renderer.md)
  and
  [`build_matrix_lists()`](https://adamrsophie.github.io/manimR/reference/opengl_renderer.md);
  drawing a mesh needs an OpenGL context and stops with a message.
  [`OpenGLRenderer()`](https://adamrsophie.github.io/manimR/reference/opengl_renderer.md)
  renders scenes (also with `manim_config(renderer = "opengl")`) through
  a software context
  ([`OpenGLSoftwareContext()`](https://adamrsophie.github.io/manimR/reference/opengl_renderer.md))
  whose framebuffers are ragg devices, the
  [`render_opengl_vectorized_mobject_fill()`](https://adamrsophie.github.io/manimR/reference/opengl_renderer.md)
  and `_stroke()` functions draw upstream’s projection shaders by their
  GLSL rules, and
  [`Window()`](https://adamrsophie.github.io/manimR/reference/opengl_renderer.md)
  shows a live preview in an R graphics device. Where an OpenGL class
  differs from its Cairo counterpart, it follows upstream’s OpenGL
  class:
  [`OpenGLArrow()`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  is a filled shape,
  [`OpenGLLine()`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  applies `buff` twice, arcs are made of quadratic pieces, `add_tip()`
  adds an
  [`OpenGLArrowTip()`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md),
  [`OpenGLSurface()`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  counts `resolution` in grid points, and
  [`OpenGLArc()`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md),
  [`OpenGLCircle()`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md),
  [`OpenGLRectangle()`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md),
  [`OpenGLImageMobject()`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  and others take upstream’s arguments in upstream’s order, and
  [`OpenGLImageMobject()`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  upscales an image array with Pillow’s resampling filters as upstream
  does.
- Images are drawn through the homography of their corners with Pillow’s
  nearest, bilinear and bicubic filters, and an image seen edge on is
  skipped as upstream.
- Helpers of `manim.utils` outside `from manim import *` are exported
  too: the matrices of `manim.utils.opengl`
  ([`orthographic_projection_matrix()`](https://adamrsophie.github.io/manimR/reference/opengl_matrices.md),
  [`view_matrix()`](https://adamrsophie.github.io/manimR/reference/opengl_matrices.md)
  and the rest),
  [`rotation_matrix_transpose()`](https://adamrsophie.github.io/manimR/reference/space_ops.md),
  [`rotation_matrix_from_quaternion()`](https://adamrsophie.github.io/manimR/reference/space_ops.md),
  [`normalize_along_axis()`](https://adamrsophie.github.io/manimR/reference/space_ops.md),
  [`resize_array()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md),
  [`resize_preserving_order()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md),
  [`resize_with_interpolation()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md),
  [`batch_by_property()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md),
  [`uniq_chain()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md),
  [`get_smooth_closed_cubic_bezier_handle_points()`](https://adamrsophie.github.io/manimR/reference/get_smooth_cubic_bezier_handle_points.md),
  [`get_smooth_open_cubic_bezier_handle_points()`](https://adamrsophie.github.io/manimR/reference/get_smooth_cubic_bezier_handle_points.md),
  [`get_quadratic_approximation_of_cubic()`](https://adamrsophie.github.io/manimR/reference/get_quadratic_approximation_of_cubic.md),
  [`remove_invisible_chars()`](https://adamrsophie.github.io/manimR/reference/remove_invisible_chars.md)
  and
  [`convert_audio()`](https://adamrsophie.github.io/manimR/reference/path_helpers.md).
- [`ImplicitFunction()`](https://adamrsophie.github.io/manimR/reference/function_graphs.md)
  traces its curve with a port of the adaptive quadtree of the
  isosurfaces package, and
  [`ConvexHull()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  and
  [`ConvexHull3D()`](https://adamrsophie.github.io/manimR/reference/polyhedra.md)
  use a port of upstream’s QuickHull, so both give upstream’s curve
  points and hull faces.
- Submobjects are validated and inserted as upstream: a `VMobject` takes
  only `VMobject`s, `add()`, `add_to_back()` and `insert()` move a
  mobject that is already a submobject, and `insert()` takes negative
  positions.
- A numeric vector of 3 or 4 values is one color wherever a color is
  taken (`Square(color = c(0.5, 0.5, 0.5))`), and a single number is a
  hex number (`0xFC6255`); several colors are a character vector or a
  list.
- `frame_width`, `frame_height` and `frame_center` of a camera are
  properties: on a `MovingCamera` they read and move its frame.
- [`SVGMobject()`](https://adamrsophie.github.io/manimR/reference/SVGMobjectClass.md)
  reads styles and paths as upstream’s SVG parser does: a shape with no
  stroke keeps the stroke color of its class, an opacity property
  replaces the alpha of its color and has 8 bits, the `opacity` property
  is not read, and an arc becomes one quadratic piece for every tenth of
  a turn.
  [`MarkupText()`](https://adamrsophie.github.io/manimR/reference/MarkupText.md)
  rejects unknown tags, and
  [`polylabel()`](https://adamrsophie.github.io/manimR/reference/polylabel.md)
  also returns the size `h` of the cell of its pole.
