# Check system requirements

Reports which of the programs manimR uses are available: ffmpeg and
ffprobe (video output and video metadata), LaTeX and dvisvgm
([`Tex()`](https://adamrsophie.github.io/manimR/reference/tex.md),
[`MathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md)),
typst
([`Typst()`](https://adamrsophie.github.io/manimR/reference/typst.md))
and Python with Pygments (highlighting every language in
[`Code()`](https://adamrsophie.github.io/manimR/reference/CodeClass.md)).
This is `manim checkhealth`.

## Usage

``` r
manim_check()
```

## Value

A named logical vector, invisibly.
