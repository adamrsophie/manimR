# TexTemplate

A LaTeX document template used by
[`Tex()`](https://adamrsophie.github.io/manimR/reference/tex.md) and
[`MathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md).
Change the default with `manim_config(tex_template = TexTemplate(...))`.

## Usage

``` r
TexTemplate(
  tex_compiler = "latex",
  description = "",
  output_format = ".dvi",
  documentclass = "\\documentclass[preview]{standalone}",
  preamble = DEFAULT_TEX_PREAMBLE,
  placeholder_text = "YourTextHere",
  post_doc_commands = ""
)
```

## Arguments

- tex_compiler:

  Compiler, `"latex"` by default (or `"xelatex"`, `"lualatex"`).

- description:

  A description.

- output_format:

  `".dvi"` (latex), `".xdv"` (xelatex) or `".pdf"`.

- documentclass:

  The `\documentclass` line.

- preamble:

  Preamble between the document class and `\begin{document}`.

- placeholder_text:

  Text replaced by the expression.

- post_doc_commands:

  Commands right after `\begin{document}`.

## Value

A `TexTemplate`, an R6 object. `TexTemplateClass` is its R6 class
generator.

## Examples

``` r
tpl <- TexTemplate()
tpl$add_to_preamble("\\usepackage{mathrsfs}")
```
