# Show rendered output in R Markdown and Quarto

In a knitr document, the value of
[`render()`](https://adamrsophie.github.io/manimR/reference/render.md)
printed at the end of an `r` chunk is embedded: a video player for MP4,
WebM and MOV files in HTML output, an image for GIF and PNG files (and a
note with the path in other output formats). The file is copied next to
the chunk's figures, under a name made of the chunk label and a hash of
its contents.

## Usage

``` r
# S3 method for class 'manim_output'
knit_print(x, options = list(), ...)
```

## Arguments

- x:

  A `manim_output`, the value of
  [`render()`](https://adamrsophie.github.io/manimR/reference/render.md).

- options:

  knitr chunk options; `out.width` sets the width.

- ...:

  Ignored.

## Value

A `knit_asis` string.
