# Render scenes from a script

Sources `file` and renders the named scenes (all scenes when `scenes` is
`NULL`), each with its own copy of the settings, as `manim render` does.
The script's name is the module name of the output directories
(`media/videos/<file name>/<quality>/`).

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
if (FALSE) { # \dontrun{
render_file("scenes.R", "SquareToCircle", quality = "l", preview = TRUE)
} # }
```
