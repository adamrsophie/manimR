# manimR (development version)

## New features

* `render_report()` is also the movie's timeline: each play has its
  section, first frame, number of frames, and start and end in seconds of
  the movie, and `sections` sums them by section. The counts match the
  frames ffmpeg writes, including waits that stop early.
* `scene_frames()` captures the frames at several times from one run of a
  scene, and `storyboard()` draws them side by side with labels into one
  PDF, SVG or PNG file. `scene_frame(file = )` and `scene_frames(files = )`
  also write the frames, as PNG or as vector PDF and SVG drawn by the 2D
  camera.
* `Axes` gains `plot_step()` (a right-continuous step function, such as an
  empirical distribution or a survival curve), `plot_band()` (the region
  between two curves, such as a confidence band, optionally with step
  edges) and `plot_intervals()` (vertical or horizontal intervals with caps
  and estimates, as in a forest plot).
* `keyed_mobjects()` makes one mobject per row of a data frame, keyed by a
  column, and `update_keyed()` animates it to new data: a key in both
  tables keeps its object (with its updaters), which transforms to its new
  row; new keys fade in and departing keys fade out. Missing and repeated
  keys are rejected before anything changes. `keyed_points()` does the same
  for a point cloud with one point per row, which is much faster for large
  data (1,000 rows: 2 s against 80 s).
* `max_inflight_encoders` works: above 1, each video segment's ffmpeg keeps
  encoding in the background while the next play renders, up to that many
  segments at once (on Unix-like systems). A scene of eight plays at high
  quality rendered in 3.6 s with four encoders against 7.3 s with one.
* `render_report()` tells what a render ran: the renderer and where it
  runs, the output format and size, the time and cache decision (with its
  reason) of each play, the mobjects and points in the last frame, the
  ffmpeg and encoder used, and the settings that had no effect.
* `renderManim(async = TRUE)` renders in a background R process through
  promises and future, so a Shiny app keeps serving other sessions while a
  scene renders.

## Bug fixes

* The partial movie cache removes unfinished segment files (`.part`) more
  than an hour old, which renders that were killed left behind.
* A scene object rendered with a different `quality` than it was created
  with encodes its video at the size and frame rate of its own camera. The
  encoder took them from the configuration, so ffmpeg got frames of the
  wrong size.
* `render_report()` reads the size and frame rate from the scene's camera
  and records the seed. With no argument it returns the report of the
  latest render, including renders that return nothing (`format = "none"`,
  `dry_run`) and renders that failed, whose report has `status = "failed"`
  and the error.
* `renderManim()` renders each output of each session into its own media
  directory unless `media_dir` is given, so async renders of scenes with
  the same name in two sessions no longer write to the same files. The
  directories are removed when the session ends. Its help no longer says
  `async = TRUE` keeps the asking session's other outputs responsive; it
  frees other sessions.
* `scene_frame()` at a time after a wait that stopped early through
  `stop_condition` shows what playback shows there. It used the wait's
  declared duration and returned the wait's last frame.
* A sound added right after a play that came from the cache is kept. The
  cache hit left the scene skipping, so `add_sound()` dropped it and a
  second render of the same scene had no audio.
* The OpenGL software renderer's image texture cache is bounded. It kept
  every image's upscaled texture for the whole session.
* `as_mobject()` keeps clipping: shapes outside a clipped viewport, such
  as a ggplot panel, are dropped, and shapes that cross it are cut. Content
  outside the page is clipped too, so a plot keeps its size.
* `as_mobject()` keeps raster images (`rasterGrob()`, `geom_raster()`,
  color bars) as `ImageMobject()`s; a plot with images is returned as a
  `Group()` in drawing order. It also reads the compositing filters that
  Cairo writes around interpolated images, which before turned the whole
  plot into a black rectangle.
* `as_mobject(raster = TRUE)` draws the plot as one image, and
  `as_mobject()` warns about SVG features it cannot reproduce.
* `SVGMobject()` gains `clip_paths` and `keep_images` (both off, as
  upstream) and lists what it could not draw in `$unsupported`.
* A play whose movie file comes from the cache now steps through every frame
  time without drawing, so updaters that depend on `dt` leave the scene as
  a fresh render does. Before, the play took one step of its whole
  duration, and later plays could start from a different state.
* A wait that stops early through `stop_condition` advances the scene clock
  by the frames it ran under both renderers. The OpenGL renderer advanced
  it by the whole maximum duration.
* Play hashes include the scene's own updaters, the bindings of
  environments that an updater reads (so changing `params$speed` changes
  the hash), and the state of other R6 objects such as meshes.
* The glyph cache of `DecimalNumber()` tells apart constructors that have
  the same code but capture different settings.
* The OpenGL renderer clears the frame with the configured
  `background_opacity`, so `transparent = TRUE` gives a transparent
  background as under Cairo. It was always opaque.
* Mesh updaters, such as one on a `FullScreenQuad()`, run during playback,
  and a mesh with a time based updater keeps a wait from being frozen.
  Before, they ran only through an explicit `update_meshes()`.
* `FunctionGraph(use_vectorized = TRUE)` works: the curve function returns
  coordinate rows for a vector of samples.
* Packing pixels into a native raster and back keeps black at alpha 128,
  whose bits are R's `NA_integer_`; it came back as `NA`.
* manimR requires textshaping 0.4.0 or later, the first version with the
  `weight` and `features` arguments it uses.

## Performance

* Graph layouts build each vertex's neighbors once, and shortest paths
  (Kamada and Kawai layout) use a breadth first search from each vertex
  instead of Floyd and Warshall. On a tree of 300 vertices the tree layout
  went from 0.22 s to 0.02 s and the shortest paths from 0.83 s to 0.02 s.
* `get_family()` collects members into one list instead of concatenating
  at each level: 30% faster on a group of 200, which every animation frame
  of a large `Transform` pays several times.
* The OpenGL software renderer crops the frame capture before converting it
  when it blends a mobject, instead of converting the whole frame each
  time: a 1080p frame of three mobjects takes 25% less CPU time.
* `DecimalNumber$set_value()` keeps the glyphs when the displayed text and
  its settings do not change, and only updates the value.

* The OpenGL renderer hands each frame to the movie writer as the
  device's native raster, without unpacking it into an array and packing
  it again. At 1080p a frame takes about 1.4 ms and 8 MB instead of
  hundreds of megabytes of temporary arrays.
* `VMobject$point_from_proportion()` keeps the curve lengths it measured
  with the points they belong to, so `MoveAlongPath()` measures a fixed
  path once. A call on a path of 600 curves went from about 4 ms to 20 µs.

## Documentation

* The README no longer says that `ImplicitFunction()` uses
  `grDevices::contourLines()`; it uses the adaptive quadtree, as upstream.
* The help of `knit_print.manim_output()` explains how it differs from the
  `manim` chunk engine for documents that are not HTML.

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
  Stroke points pass through single precision as they do on the GPU, so
  points a rounding error apart (at a sphere's pole) join as on the GPU,
  and each fragment blends into the 8 bit framebuffer in turn, rounded as
  a GPU rounds. Frames now match the GPU's within 1 of 255 for most of the
  test scenes.
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
