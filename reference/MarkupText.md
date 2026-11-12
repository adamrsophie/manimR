# MarkupText

Text with inline Pango style markup. Supported tags: `<b>`, `<i>`,
`<tt>`, `<big>`, `<small>`, `<sup>`, `<sub>`, and `<span>` with
`foreground`/`color`, `font`/`font_family`, `weight`, `style`,
`fgalpha`.

## Usage

``` r
MarkupText(
  text,
  fill_opacity = 1,
  stroke_width = 0,
  color = NULL,
  font_size = DEFAULT_FONT_SIZE,
  line_spacing = -1,
  font = "",
  slant = "NORMAL",
  weight = "NORMAL",
  justify = FALSE,
  gradient = NULL,
  tab_width = 4,
  height = NULL,
  width = NULL,
  should_center = TRUE,
  disable_ligatures = FALSE,
  warn_missing_font = TRUE,
  ...
)
```

## Arguments

- text:

  Markup string.

- fill_opacity, stroke_width, color, font_size, line_spacing, font,
  slant, weight, justify, gradient, tab_width, height, width,
  should_center, disable_ligatures, warn_missing_font:

  As for
  [`Text()`](https://adamrsophie.github.io/manimR/reference/TextClass.md),
  in upstream's order for `MarkupText`.

- ...:

  Passed to
  [`Text()`](https://adamrsophie.github.io/manimR/reference/TextClass.md).

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.

## Examples

``` r
MarkupText("<b>bold</b> and <span foreground='red'>red</span>")
#> <MarkupText> 0 points, 10 submobjects
```
