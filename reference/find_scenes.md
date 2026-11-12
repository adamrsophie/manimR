# Find scenes defined in a file or environment

Sourcing a script runs its code, but calls of
[`render()`](https://adamrsophie.github.io/manimR/reference/render.md),
[`render_file()`](https://adamrsophie.github.io/manimR/reference/render_file.md),
[`manim_cli()`](https://adamrsophie.github.io/manimR/reference/manim_cli.md),
[`preview_output()`](https://adamrsophie.github.io/manimR/reference/preview_output.md)
and
[`manim_gadget()`](https://adamrsophie.github.io/manimR/reference/rstudio_addins.md)
in it do nothing, so a script that ends with `render(MyScene)` is not
rendered twice by
[`render_file()`](https://adamrsophie.github.io/manimR/reference/render_file.md),
[`manim_cli()`](https://adamrsophie.github.io/manimR/reference/manim_cli.md)
or the RStudio addins.

## Usage

``` r
find_scenes(file = NULL, envir = NULL)
```

## Arguments

- file:

  Path to an R script defining scenes.

- envir:

  Environment to search instead of a file.

## Value

A named list of scene class generators, in definition order.
