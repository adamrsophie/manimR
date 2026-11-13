# manimR 0.1.0

* First release: a native R port of Manim Community 0.22 (the Cairo style
  renderer), covering every public name and class method of
  `from manim import *` (checked by `tests/testthat/test-api-coverage.R`).
  Every upstream class has an R6 generator `FooClass`, including the ones
  upstream defines only to preset arguments.
* Rendered output and the LaTeX cache go to a `media` folder in the R
  session's temporary directory unless `media_dir` is set, so nothing is
  written to the working directory by default; `manim_cli()` writes to a
  `media` folder in `tools::R_user_dir("manimR", "cache")` unless
  `--media_dir` is given (`--media_dir media` writes `./media` as Manim's
  command line does).
* Output follows Manim 0.22's render sessions: `format` is `"auto"`,
  `"mp4"`, `"mov"`, `"webm"`, `"gif"`, `"png"` (last frame),
  `"png-sequence"` or `"none"`, with `dry_run`, directory templates
  (`get_dir()`), `manim.cfg` files (`digest_config_file()`), encoder
  settings and per scene log files. Partial movie files are cached by a hash
  of each play, and sections, sound and subtitles are written as upstream.
* `Tex()` and `MathTex()` through LaTeX and dvisvgm, `Typst()` and
  `MathTypst()` through the typst compiler, `Text()` and `MarkupText()`
  through system fonts, and `Code()` highlighted with Pygments when Python
  has it.
* The command line (`manim_cli()`) takes `manim render`'s options and the
  `checkhealth`, `cfg`, `init`, `plugins` and `cache clear` subcommands.
* RStudio addins (including rendering as a background job), a `manim`
  knitr engine for R Markdown and Quarto, printing of `render()` results in
  documents, Shiny output functions (`manimOutput()`, `renderManim()`) and
  an interactive Shiny window for scenes.
* `as_mobject()` turns ggplot2, grid and base graphics into mobjects,
  `scene_frame()` renders one frame of a scene, `expect_snapshot_frame()`
  tests frames with testthat, and `GraphClass$from_igraph()` imports igraph
  graphs.
* The mobject classes of upstream's OpenGL renderer (`OpenGLCircle()`,
  `OpenGLVGroup()`, `OpenGLSurface()` and the rest) build on their Cairo
  counterparts, so code written for that renderer runs unchanged;
  `OpenGLSurfaceMesh()` and `OpenGLTexturedSurface()` are ported to grid.
  They also have the methods and argument names of upstream's OpenGL
  classes, including the CPU side of its GPU pipeline: shader data,
  triangulation, uniforms and `ShaderWrapper()`, with upstream's GLSL files.
  The CPU side of upstream's OpenGL renderer is ported too: the camera
  (`OpenGLCamera()`), trees of 3D objects and meshes (`Object3D()`,
  `Mesh()`), `Shader()`, `triangulate_mobject()` and
  `build_matrix_lists()`. A scene draws meshes whose shader is one of
  upstream's default, manim_coords, vertex_colors or test folders in
  software, and runs the vertex and fragment shaders of other meshes
  (and `FullScreenQuad()`) in a GLSL interpreter, structs, geometry
  shaders and `sampler2D` textures of the software context included
  (`texture()`, `textureLod()`, `texelFetch()`, `textureSize()`); other
  sampler types and units with no texture read (0, 0, 0, 1), as a GPU's
  default texture, since upstream binds only 2D textures. Textures that
  the renderer makes from images are clamped and sampled at the nearest
  texel, as upstream's. `OpenGLRenderer()` renders scenes (also with
  `manim_config(renderer = "opengl")`) through a software context
  (`OpenGLSoftwareContext()`) whose framebuffers are ragg devices, the
  `render_opengl_vectorized_mobject_fill()` and `_stroke()` functions draw
  upstream's projection shaders by their GLSL rules, and `Window()` shows a
  live preview in an R graphics device. Where the device reports no mouse
  or key events (as on macOS), the window opens in the browser through
  httpuv and reports pyglet's events, wheel and key releases included.
  Surface normals are computed in single precision as on the GPU, so a
  sphere's pole takes the shader's fallback normal where upstream's does.
  Where an OpenGL class differs from its Cairo counterpart, it follows
  upstream's OpenGL class: `OpenGLArrow()` is a filled shape,
  `OpenGLLine()` applies `buff` twice, arcs are made of quadratic pieces,
  `add_tip()` adds an `OpenGLArrowTip()`, `OpenGLSurface()` counts
  `resolution` in grid points, and `OpenGLArc()`, `OpenGLCircle()`,
  `OpenGLRectangle()`, `OpenGLImageMobject()` and others take upstream's
  arguments in upstream's order, and `OpenGLImageMobject()` upscales an
  image array with Pillow's resampling filters as upstream does.
  Shapes built under `manim_config(renderer = "opengl")` follow upstream's
  OpenGL constructions: a line is one straight quadratic, a cubic (from
  an SVG path, `add_cubic_bezier_curve_to()` or `make_smooth()`) is two
  quadratics, `MathTex()` and `Typst()` split sharp curves and drop null
  ones, `ThreeDAxes()` adds no shaded pieces, group bounds use the
  quadratic curves, and an empty group keeps track of its shifts. Under
  that renderer a partial curve keeps its number of curves, and copies
  added to align groups in a transform stay visible when opaque, as in
  upstream's OpenGL mobjects. Mobjects of the classes upstream converts
  to OpenGL classes under that renderer (all but a bare `VMobject()` or
  `Mobject()`, `StreamLine`, images and user classes made directly on
  `VMobjectClass` or `MobjectClass`) also get the methods of upstream's
  OpenGL classes. Their quadratic curves are
  stored raised to cubics, so `$points` and the point getters give 4
  points per curve where upstream gives 3.
* Images are drawn as upstream's Cairo camera draws them: the truncated
  pixel corners give the paste box, and the image goes through Pillow's
  perspective transform (its nearest, bilinear and bicubic filters on
  premultiplied 8 bit colors), so frames match upstream's within 1 of 255.
  An image seen edge on is skipped as upstream.
* Helpers of `manim.utils` outside `from manim import *` are exported too:
  the matrices of `manim.utils.opengl` (`orthographic_projection_matrix()`,
  `view_matrix()` and the rest), `rotation_matrix_transpose()`,
  `rotation_matrix_from_quaternion()`, `normalize_along_axis()`,
  `resize_array()`, `resize_preserving_order()`,
  `resize_with_interpolation()`, `batch_by_property()`, `uniq_chain()`,
  `get_smooth_closed_cubic_bezier_handle_points()`,
  `get_smooth_open_cubic_bezier_handle_points()`,
  `get_quadratic_approximation_of_cubic()`, `remove_invisible_chars()` and
  `convert_audio()`.
* `ImplicitFunction()` traces its curve with a port of the adaptive
  quadtree of the isosurfaces package, and `ConvexHull()` and
  `ConvexHull3D()` use a port of upstream's QuickHull, so both give
  upstream's curve points and hull faces.
* Submobjects are validated and inserted as upstream: a `VMobject` takes
  only `VMobject`s, `add()`, `add_to_back()` and `insert()` move a mobject
  that is already a submobject, and `insert()` takes negative positions.
* A numeric vector of 3 or 4 values is one color wherever a color is taken
  (`Square(color = c(0.5, 0.5, 0.5))`), and a single number is a hex number
  (`0xFC6255`); several colors are a character vector or a list.
* `frame_width`, `frame_height` and `frame_center` of a camera are
  properties: on a `MovingCamera` they read and move its frame.
* `SVGMobject()` reads styles and paths as upstream's SVG parser does: a
  shape with no stroke keeps the stroke color of its class, an opacity
  property replaces the alpha of its color and has 8 bits, the `opacity`
  property is not read, and an arc becomes one quadratic piece for every
  tenth of a turn. `MarkupText()` rejects unknown tags, and `polylabel()`
  also returns the size `h` of the cell of its pole.
