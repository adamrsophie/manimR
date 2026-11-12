# Code

A highlighted source code listing: monospaced
[`Text()`](https://adamrsophie.github.io/manimR/reference/TextClass.md)
lines colored by token kind, optional line numbers, and a rounded
background (`"rectangle"`) or a window with three buttons (`"window"`).

Highlighting follows upstream: when Python with the pygments module is
available (found as `python3` or `python`, or set with
`options(manimR.python = "/path/to/python")`), every Pygments lexer and
style works and the colors are exactly upstream's
(`CodeClass$get_styles_list()` lists the styles). Without Pygments, a
small built in tokenizer highlights R and Python comments, strings,
numbers and keywords; other languages are shown in the foreground color.
Its styles `"vim"` (default), `"monokai"`, `"emacs"` and `"default"`
reproduce the colors of the Pygments styles of the same names. A custom
style is a named list like the entries of those styles, with fields
`background`, `line_number`, `text`, `comment`, `keyword`, `namespace`,
`constant`, `operator_word`, `string` and `number`; it always uses the
built in tokenizer.

Fields: `code_lines` (a VGroup of
[`Text()`](https://adamrsophie.github.io/manimR/reference/TextClass.md)
lines), `line_numbers` and `background`.

## Usage

``` r
Code(
  code_file = NULL,
  code_string = NULL,
  language = NULL,
  formatter_style = "vim",
  tab_width = 4,
  add_line_numbers = TRUE,
  line_numbers_from = 1,
  background = c("rectangle", "window"),
  background_config = NULL,
  paragraph_config = NULL
)
```

## Arguments

- code_file:

  Path of a file with the code.

- code_string:

  Alternatively, the code as a string.

- language:

  A Pygments lexer name such as `"r"`, `"python"`, `"c"` or
  `"javascript"` (only `"r"` and `"python"` without Pygments); guessed
  from the file name or the code when `NULL`.

- formatter_style:

  A Pygments style name or a named list of colors.

- tab_width:

  Width of a tab in spaces.

- add_line_numbers:

  Show line numbers.

- line_numbers_from:

  First line number.

- background:

  `"rectangle"` or `"window"`.

- background_config:

  Named list of arguments for the background
  [`SurroundingRectangle()`](https://adamrsophie.github.io/manimR/reference/geometry.md);
  `fill_color` defaults to the style's background.

- paragraph_config:

  Named list of
  [`Text()`](https://adamrsophie.github.io/manimR/reference/TextClass.md)
  arguments for the code and line numbers: `font` (default `"mono"`),
  `font_size` (24), `line_spacing` (0.5, extra space between lines as a
  fraction of the font size, as upstream), `disable_ligatures`, and any
  other
  [`Text()`](https://adamrsophie.github.io/manimR/reference/TextClass.md)
  option such as `weight` or `slant`. `color` is ignored; colors come
  from the style. `alignment`, `width` and `height` are ignored.

## Examples

``` r
if (FALSE) { # \dontrun{
code <- "f <- function(x) {\n  # square it\n  x^2 + 1\n}"
Code(code_string = code, language = "r", background = "window",
     background_config = list(stroke_color = "maroon"))
} # }
```
