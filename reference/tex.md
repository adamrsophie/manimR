# MathTex and Tex

LaTeX rendered to vectorized mobjects. `MathTex()` typesets math (in an
`align*` environment), `Tex()` typesets text mode LaTeX. Each string
argument becomes one submobject, so `MathTex("a^2", "+", "b^2")[3]` is
the `b^2` part. Double braces `{{ ... }}` also split parts.
`tex_to_color_map` colors matching parts.

## Usage

``` r
SingleStringMathTex(
  tex_string,
  stroke_width = 0,
  should_center = TRUE,
  height = NULL,
  organize_left_to_right = FALSE,
  tex_environment = "align*",
  tex_template = NULL,
  font_size = DEFAULT_FONT_SIZE,
  color = NULL,
  ...
)

MathTex(
  ...,
  arg_separator = " ",
  substrings_to_isolate = NULL,
  tex_to_color_map = NULL,
  tex_environment = "align*",
  tex_template = NULL
)

Tex(..., arg_separator = "", tex_environment = "center")
```

## Arguments

- tex_string:

  A single LaTeX string.

- stroke_width:

  Stroke width.

- should_center:

  Center at the origin.

- height:

  Optional height.

- organize_left_to_right:

  Sort glyphs by x.

- tex_environment:

  LaTeX environment.

- tex_template:

  A
  [`TexTemplate()`](https://adamrsophie.github.io/manimR/reference/TexTemplateClass.md).

- font_size:

  Font size (48 by default).

- color:

  Color.

- ...:

  Strings (or values coerced to strings), then named arguments.

- arg_separator:

  Separator between the strings.

- substrings_to_isolate:

  Substrings to make addressable parts.

- tex_to_color_map:

  Named list mapping substrings to colors.

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.

## Examples

``` r
if (FALSE) { # \dontrun{
# Needs LaTeX and dvisvgm.
MathTex("e^{i\\pi} + 1 = 0")
Tex("Hello \\LaTeX", color = BLUE)
} # }
```
