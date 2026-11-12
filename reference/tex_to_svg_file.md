# Compile LaTeX to SVG

Writes the expression into the template, compiles it and converts the
result with `dvisvgm`, caching files in the `tex_dir` setting
(`media/Tex`). The .aux, .dvi and .log files are deleted afterwards
unless `manim_config(no_latex_cleanup = TRUE)`.

## Usage

``` r
tex_to_svg_file(expression, environment = NULL, tex_template = NULL)
```

## Arguments

- expression:

  LaTeX code.

- environment:

  Optional environment such as `"align*"`.

- tex_template:

  A
  [`TexTemplate()`](https://adamrsophie.github.io/manimR/reference/TexTemplateClass.md).

## Value

Path to the SVG file.
