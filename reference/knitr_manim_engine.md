# knitr engine for manimR scenes

Registered automatically when knitr is installed. A chunk with engine
`manim` evaluates its R code, renders the scene named by the chunk
option `scene` (or the last scene defined in the chunk), and embeds the
video. Chunk options `quality`, `format` (default `"auto"`, or `"png"`
for LaTeX output) and `save_last_frame` are passed to
[`render()`](https://adamrsophie.github.io/manimR/reference/render.md);
`out.width` sets the display width.

## Usage

``` r
knitr_manim_engine(options)
```

## Arguments

- options:

  knitr chunk options.

## Value

A character string for knitr: the chunk output with the rendered video
or image embedded.

## Details

    ```{manim, scene = "SquareToCircle", quality = "l"}
    SquareToCircle <- R6::R6Class("SquareToCircle", inherit = Scene,
      public = list(construct = function() self$play(Create(Circle()))))
    ```
