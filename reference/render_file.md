# Render scenes from a script

Sources `file` and renders the named scenes (all scenes when `scenes` is
`NULL`), each with its own copy of the settings, as `manim render` does.
The script's name is the module name of the output directories
(`<media_dir>/videos/<file name>/<quality>/`).

## Usage

``` r
render_file(file, scenes = NULL, ..., found = NULL)
```

## Arguments

- file:

  Path to an R script defining
  [Scene](https://adamrsophie.github.io/manimR/reference/Scene.md)
  subclasses.

- scenes:

  Scene class names; `NULL` renders all.

- ...:

  Passed to
  [`render()`](https://adamrsophie.github.io/manimR/reference/render.md),
  for example `quality = "l"`. An `output_file` can only be given when
  one scene is rendered.

- found:

  Named list of scene generators, as returned by
  [`find_scenes()`](https://adamrsophie.github.io/manimR/reference/find_scenes.md);
  by default the scenes defined in `file`.

## Value

Output paths, invisibly.

## Examples

``` r
file <- tempfile(fileext = ".R")
writeLines(c(
  "library(manimR)",
  "SquareToCircle <- manim_scene(function(self) {",
  "  self$play(Transform(Square(), Circle()))",
  "})"), file)
# The last frame as a PNG file in the session's temporary directory.
render_file(file, "SquareToCircle", quality = "l", format = "png", media_dir = tempdir())
#> Rendering SquareToCircle ...
#> INFO File ready at '/tmp/RtmppAwV5q/images/file25d2eed5a25/SquareToCircle_manimR_v0.1.0.png'
#> INFO Rendered SquareToCircle
#> Played 1 animations
if (FALSE) { # \dontrun{
# A video in the media folder (by default in the session's temporary
# directory); this needs ffmpeg.
render_file(file, "SquareToCircle", quality = "l", preview = TRUE)
} # }
```
