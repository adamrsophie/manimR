# manimR 0.1.0

* First release: a native R port of Manim Community 0.22 (the Cairo style
  renderer), covering every public name and class method of
  `from manim import *` (checked by `tests/testthat/test-api-coverage.R`).
* Renders to MP4, MOV (with transparency), WebM, GIF and PNG sequences with
  ffmpeg, with sections, sound, subtitles and Manim's partial movie cache.
* `Tex()` and `MathTex()` through LaTeX and dvisvgm, `Typst()` and
  `MathTypst()` through the typst compiler, and `Text()` through system fonts.
* RStudio addins, a `manim` knitr engine, a command line entry point
  (`manim_cli()`) and an interactive Shiny window for scenes.
