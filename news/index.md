# Changelog

## manimR 0.1.0

- First release: a native R port of Manim Community 0.22 (the Cairo
  style renderer), covering every public name and class method of
  `from manim import *` (checked by
  `tests/testthat/test-api-coverage.R`). Every upstream class has an R6
  generator `FooClass`, including the ones upstream defines only to
  preset arguments.
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
  and the rest) are subclasses of their Cairo counterparts, so code
  written for that renderer runs unchanged;
  [`OpenGLSurfaceMesh()`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  and
  [`OpenGLTexturedSurface()`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  are ported to grid.
- Images are drawn through the homography of their corners with Pillow’s
  nearest, bilinear and bicubic filters, and an image seen edge on is
  skipped as upstream.
