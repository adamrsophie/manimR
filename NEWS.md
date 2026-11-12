# manimR 0.1.0

* First release: a native R port of Manim Community 0.22 (the Cairo style
  renderer), covering every public name and class method of
  `from manim import *` (checked by `tests/testthat/test-api-coverage.R`).
  Every upstream class has an R6 generator `FooClass`, including the ones
  upstream defines only to preset arguments.
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
  `OpenGLVGroup()`, `OpenGLSurface()` and the rest) are subclasses of their
  Cairo counterparts, so code written for that renderer runs unchanged;
  `OpenGLSurfaceMesh()` and `OpenGLTexturedSurface()` are ported to grid.
* Images are drawn through the homography of their corners with Pillow's
  nearest, bilinear and bicubic filters, and an image seen edge on is
  skipped as upstream.
