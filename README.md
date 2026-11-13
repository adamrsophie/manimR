# manimR <a href="https://adamrsophie.github.io/manimR/"><img src="man/figures/logo.png" align="right" height="139" alt="manimR website" /></a>

manimR is a native R port of [Manim Community](https://www.manim.community/), the
animation engine for explanatory math videos. Scenes, mobjects, animations,
LaTeX, text, graphing, 3D and camera tools follow the Python API closely, so
Manim examples translate almost line by line. Rendering is done in R with
[grid](https://stat.ethz.ch/R-manual/R-devel/library/grid/html/00Index.html)
on an offscreen [ragg](https://ragg.r-lib.org/) device, and frames are
streamed to `ffmpeg`.

The website, <https://adamrsophie.github.io/manimR/>, has the full
reference and a set of articles that show every feature with rendered
videos:

* [Getting started](https://adamrsophie.github.io/manimR/articles/manimR.html)
  and [Coming from Python manim](https://adamrsophie.github.io/manimR/articles/coming-from-python.html)
* [Mobjects and geometry](https://adamrsophie.github.io/manimR/articles/mobjects.html),
  [Animations](https://adamrsophie.github.io/manimR/articles/animations.html),
  [Updaters and value trackers](https://adamrsophie.github.io/manimR/articles/updaters.html)
* [Text, math and tables](https://adamrsophie.github.io/manimR/articles/text-and-math.html),
  [Graphs, plots and coordinate systems](https://adamrsophie.github.io/manimR/articles/graphing.html),
  [Cameras and 3D scenes](https://adamrsophie.github.io/manimR/articles/cameras-and-3d.html),
  [Colors, images, SVG and point clouds](https://adamrsophie.github.io/manimR/articles/colors-images.html)
* [Rendering, configuration and output](https://adamrsophie.github.io/manimR/articles/rendering.html),
  [RStudio, knitr, Quarto and Shiny](https://adamrsophie.github.io/manimR/articles/rstudio-knitr-shiny.html),
  [Math and utility functions](https://adamrsophie.github.io/manimR/articles/utilities.html)

The introduction is also installed with the package: `vignette("manimR")`.

## Installation

```r
# install.packages("remotes")
remotes::install_github("adamrsophie/manimR")
```

System requirements:

* `ffmpeg` for video output (MP4, GIF, WebM, MOV).
* A LaTeX distribution with `dvisvgm` for `Tex()` and `MathTex()`
  (for example `tinytex::install_tinytex()` plus `tinytex::tlmgr_install("dvisvgm")`).
* Optionally the [typst](https://typst.app) command line compiler for `Typst()`
  and `MathTypst()`; point to it with `manim_config(typst = "/path/to/typst")`.

Run `manim_check()` to see what was found.

## A first scene

```r
library(manimR)

SquareToCircle <- R6::R6Class("SquareToCircle", inherit = Scene,
  public = list(construct = function() {
    circle <- Circle()$set_fill(PINK, opacity = 0.5)
    square <- Square()$rotate(PI / 4)
    self$play(Create(square))
    self$play(Transform(square, circle))
    self$play(FadeOut(square))
  })
)

render(SquareToCircle, quality = "l", preview = TRUE)
```

The functional form is shorter for quick experiments:

```r
render(function(self) {
  eq <- MathTex("e^{i\\pi}", "+", "1", "=", "0")
  self$play(Write(eq))
  self$play(Indicate(eq[3]))
}, quality = "l")
```

## Translating Manim code

| Python manim | manimR |
| --- | --- |
| `Circle(radius=2, color=RED)` | `Circle(radius = 2, color = RED)` |
| `sq.shift(LEFT).scale(2)` | `sq$shift(LEFT)$scale(2)` |
| `self.play(sq.animate.rotate(PI))` | `self$play(sq$animate$rotate(PI))` |
| `group[0]` | `group[1]` (indices start at 1) |
| `len(group)` | `length(group)` |
| `VGroup(*mobs)` | `VGroup(mobs)` or `VGroup(a, b, c)` |
| `t2c={"x": RED}` | `t2c = list(x = RED)` |
| `rate_func=smooth` | `rate_func = smooth_rate` or `rate_functions$smooth` (avoids masking `stats::smooth()`) |
| `rate_functions.ease_in_sine` | `rate_functions$ease_in_sine` (or `ease_in_sine`) |
| `from manim.utils.color import X11` | `X11_COLORS` or `color$X11` (avoids masking `grDevices::X11()`) |
| `config.frame_height`, `frame.top` | `config$frame_height`, `manim_frame$top` (avoids masking `graphics::frame()`) |
| `with tempconfig({...}):` | `tempconfig(list(...), { ... })` |
| `ManimColor("#FF0000").darker()` | `ManimColor("#FF0000")$darker()` |
| `clip(a, 0, 1)` | `clip_value(a, 0, 1)` (avoids masking `graphics::clip()`) |
| `class S(Scene): def construct(self):` | `S <- R6::R6Class("S", inherit = Scene, public = list(construct = function() ...))` |
| `manim -pql file.py S` | `render_file("file.R", "S", quality = "l", preview = TRUE)` |

Every constructor `Foo()` has an exported R6 generator `FooClass` for
subclassing, for example `R6::R6Class("MyShape", inherit = VMobjectClass, ...)`,
including the classes upstream defines only to preset arguments
(`MathTableClass`, `ReplacementTransformClass`, and so on).
Constructors show the full argument list of their class, so RStudio's
completion lists the same arguments as Manim's documentation. Class wide
defaults work like Manim's `set_default()`: `set_default(Text, font_size = 60)`.

Every public name of `from manim import *` has an R counterpart; the only
renames are the ones above, made so no export masks a base R function
(upstream's `choose()` is `base::choose()`, and its `unit` module's members
`Pixels`, `Percent()`, `Degrees` and `Munits` are exported directly).
`tests/testthat/test-api-coverage.R` checks this against the upstream
source, for every exported name and every public method of every exported
class. Colors are hex strings; `ManimColor()` wraps one when you need
upstream's color methods. As upstream, a misspelled argument
(`Circle(raduis = 2)`) or setting (`manim_config(qualty = "l")`) is an error.

Two exports share names with other packages: `Matrix()` and `MatrixClass`
(also in the Matrix package) and `Cross()` (also in purrr as `cross()`, a
different case). Attach manimR last, or write `manimR::Matrix()`.

## Rendering options

`render()` and `manim_config()` take Manim 0.22's settings: `quality`
(`"l"`, `"m"`, `"h"`, `"p"`, `"k"`), `transparent`, `background_color`,
`frame_rate`, `media_dir` and the rest (see `?manim_config`). `format`
chooses the artifact: `"auto"` (MP4, or MOV when transparent; a scene with
no animations is saved as its last frame), `"mp4"`, `"mov"`, `"webm"`,
`"gif"`, `"png"` (only the last frame; `save_last_frame = TRUE` means the
same), `"png-sequence"` (every frame) or `"none"`; `dry_run = TRUE` renders
without writing files. Output goes to
`media/videos/<module>/<quality>/<Scene>.mp4` and
`media/images/<module>/` like Manim; the media folder is in the R
session's temporary directory unless you set `media_dir` (for example
`manim_config(media_dir = "media")`), while `manim_cli()` uses the R
user cache folder (`--media_dir media` gives Manim's `./media`). The directory settings
(`video_dir`, `images_dir`, `partial_movie_dir`, `tex_dir`, ...) take the
same `{media_dir}`, `{module_name}`, `{quality}` and `{scene_name}`
placeholders (`get_dir()` resolves them). A `manim.cfg` file is read with
`digest_config_file()`, and the command line reads one in the working
directory.

Scenes can be split with `self$next_section("name")`; with
`save_sections = TRUE` each section is also written to its own video under
`sections/` with a JSON index, and `next_section(skip_animations = TRUE)`
skips a section while you work on later ones. `self$add_sound()` and
`self$play(..., subcaption = "...")` add audio and an `.srt` subtitle file.

As in Manim, each play is written to its own partial movie file, named by a
hash of the renderer, the encoder settings, the camera, the animations and
the scene's mobjects (including the values updaters use), and the files
are joined into the movie. Rendering again reuses the files of unchanged
plays; `disable_caching = TRUE` (`--disable_caching`) renders everything,
`flush_cache = TRUE` (`--flush_cache`) empties the cache first, and
`max_files_cached` (default 100) limits its size. `video_codec`,
`pixel_format` and `video_encoder_options` choose how the segments are
encoded.

`scene_frame(MyScene, t = 2.5)` renders the single frame at 2.5 seconds
without writing a video, and `plot()` shows it.

From a terminal:

```sh
Rscript -e 'manimR::manim_cli()' scenes.R SquareToCircle -ql -p
```

The command line takes all of `manim render`'s options (`-ql`, `-p`, `-s`,
`-t`, `-a`, `-o FILE`, `-n N,M`, `-r W,H`, `--fps`, `--format`,
`--save_sections`, `--dry_run`, `--media_dir`, `-c manim.cfg`,
`--encoder-option crf=18`, ...) and the subcommands `checkhealth`,
`cfg show|write|export`, `init project|scene`, `plugins -l` and
`cache clear`; see `?manim_cli`.

## RStudio

The package installs RStudio addins (Addins menu):

* **Render scene at cursor**: renders the scene defined at or above the cursor
  and plays it in the Viewer pane.
* **Render all scenes in file**.
* **Preview last frame**: renders only the final frame, which is much faster.
* **Insert scene template**.
* **Render scene in background**: renders as an RStudio background job and
  shows the result when it is done.
* **Render with options**: a dialog to choose scene, quality, format and
  transparency.

Set `options(manimR.addin_quality = "m")` to change the quality the quick
addins use. `plot(mobject)` draws any mobject in the Plots pane.

## Shiny

`manimOutput()` and `renderManim()` show a scene in a Shiny app and render
it again when the inputs it uses change:

```r
output$scene <- renderManim({
  n <- input$sides
  function(self) self$play(Create(RegularPolygon(n = n)))
})
```

## Other R graphics and data

`as_mobject()` turns a ggplot2 chart, a grid grob or base graphics into a
vector mobject that can be animated, and `GraphClass$from_igraph()` builds a
`Graph()` from an igraph graph.

## R Markdown and Quarto

A `manim` knitr engine renders scenes inside documents:

````markdown
```{manim, scene = "SquareToCircle", quality = "l"}
SquareToCircle <- R6::R6Class("SquareToCircle", inherit = Scene,
  public = list(construct = function() self$play(Create(Circle()))))
```
````

HTML output embeds the video, PDF output the last frame and other formats
(GitHub Markdown, Word) a GIF. The same engine works in Quarto documents
that use the knitr engine. In an `r` chunk, the value of `render()` is
embedded the same way when it is printed.

## Differences from Python manim

* Scenes render with the Cairo style renderer (`CairoRenderer`), which
  draws with grid on a ragg device instead of pycairo, so the camera's
  Cairo context helpers have no counterpart. With `manim_config(renderer =
  "opengl")`, scenes render with `OpenGLRenderer`, a port of upstream's
  OpenGL renderer that draws in software instead of on the GPU. Its shader
  wrappers run upstream's GLSL rules: VMobjects the quadratic Bezier fill
  and stroke shaders, `OpenGLSurface` and `OpenGLTexturedSurface` the
  surface shaders, and the projection shaders when configured, rasterized
  at pixel centers, lit per pixel and depth tested. `OpenGLImageMobject`
  runs the textured surface shader, a plain `ImageMobject` is drawn by a
  grid camera, and a live preview `Window` is an R graphics
  device. Meshes are drawn too: upstream's own mesh shaders by their
  rules, and other GLSL code of a `Mesh` or `FullScreenQuad` in a GLSL
  interpreter (structs, geometry shaders and 2D textures included). The OpenGL point clouds
  (`DotCloud`, `TrueDot`, `OpenGLPMobject`) run upstream's true_dot
  shader, and the other OpenGL mobject classes
  (`OpenGLCircle`, `OpenGLSurface`, ...) are subclasses of their Cairo
  counterparts.
* Interactive mode (`scene$interactive_embed()`, `embed()`, `interact()`)
  opens a Shiny window instead of upstream's OpenGL window: it shows the
  live scene, takes the same key and mouse events (orbit, pan, zoom, `r`,
  `q`, `set_key_function()`) and has a code box in place of the IPython
  shell.
* Plugins are R packages whose `DESCRIPTION` sets
  `Config/manimR/plugin: true` (see `get_plugins()`), not Python entry
  points.
* `Text()` uses system fonts through `textshaping` and `systemfonts` instead of
  Pango, so glyph shapes and metrics follow the installed fonts.
  `MarkupText()` wraps and justifies lines at upstream's Pango layout width.
* Boolean operations (`Union()`, `Intersection()`, `Difference()`,
  `Exclusion()`) cut the input curves where they cross, as skia-pathops
  does, in double precision rather than skia's single precision. A contour
  that holds no input start point can start at a different point, and an
  exclusion can split its outline into different (equally filled) contours.
* `Code()` highlights with Pygments, as upstream, when Python with the
  pygments module is installed; without it, a built in tokenizer highlights
  R and Python.
* Video segments are encoded in the R process, one at a time;
  `max_inflight_encoders` and `encoder_queue_size` are accepted but have no
  effect.
* Copy mobjects with `$copy()`; R6's `$clone()` keeps the original's id.
* `ImplicitFunction()` traces contours with `grDevices::contourLines()`
  instead of an adaptive quadtree.
* Graph layouts, including `"planar"`, are native ports of the networkx
  algorithms, so igraph is not required. Where networkx picks an arbitrary
  element of a set, the first vertex is used, so a planar drawing can differ
  from networkx while staying free of crossings.
* In 3D scenes the camera's `frame_center` is subtracted once (upstream
  subtracts it twice). Shaded strokes color each drawn segment from the
  shading gradient instead of filling a gradient, which looks the same at
  the thin strokes surfaces use.
* Images in formats other than PNG (JPEG, GIF, WebP and so on) are read
  through ffmpeg.
* Index valued helpers keep upstream's 0 based numbers where they are
  arithmetic rather than positions in an R list: `integer_interpolate()`
  and the `get_3d_vmob_*()` corner indices. Labels and positions that index
  R objects (`index_labels()`, `earclip_triangulation()`) start at 1.
* `subdivide_bezier()` splits curves of degree 4 or more at i/n, as its
  upstream documentation states; upstream's code for those degrees splits
  elsewhere. Manim itself only uses cubic curves.
* `override_animation()` and `override_animate()` replace the decorators of
  the same names: `override_animation(MyClass, "FadeIn", function(...) ...)`.
* `ZoomedScene` redraws the zoomed region as vector graphics instead of
  copying pixels.
* Arguments named `function` in Python are called `func` (a reserved word in
  R), and indices such as axis numbers start at 1.

## Fidelity tests

The test suite compares points, positions, colors, timings and LaTeX output
against reference data produced by Python manim (`data-raw/*.py` regenerate
the fixtures in `tests/testthat/fixtures/`). Geometry, alignment, transforms,
partial curves, rate functions, graphing, 3D shapes, camera projections,
graph layouts, matrices and tables match upstream to within numerical
precision.

## Acknowledgments

manimR is a port of [Manim Community](https://github.com/ManimCommunity/manim),
created by the Manim Community developers on top of Grant Sanderson's original
manim for 3Blue1Brown. Its design, algorithms and examples follow their work,
which is gratefully acknowledged. Manim Community is released under the MIT
license. The graph layouts are translated from [NetworkX](https://networkx.org)
(BSD 3 clause license) and the polygon triangulation from
[earcut.hpp](https://github.com/mapbox/earcut.hpp) (ISC license).

## License

GPL (>= 3). The copyright notices of the ported projects are in
[`inst/COPYRIGHTS`](inst/COPYRIGHTS).
