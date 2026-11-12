# Text

Text rendered from system fonts as vectorized glyphs. Each glyph is a
submobject, so `text[1]` is the first visible character and
[`Write()`](https://adamrsophie.github.io/manimR/reference/creation.md)
or
[`AddTextLetterByLetter()`](https://adamrsophie.github.io/manimR/reference/creation.md)
animate letter by letter.

## Usage

``` r
Text(
  text,
  fill_opacity = 1,
  stroke_width = 0,
  color = "#FFFFFF",
  font_size = DEFAULT_FONT_SIZE,
  line_spacing = -1,
  font = "",
  slant = "NORMAL",
  weight = "NORMAL",
  t2c = NULL,
  t2f = NULL,
  t2g = NULL,
  t2s = NULL,
  t2w = NULL,
  gradient = NULL,
  tab_width = 4,
  warn_missing_font = TRUE,
  height = NULL,
  width = NULL,
  should_center = TRUE,
  disable_ligatures = FALSE,
  use_svg_cache = FALSE,
  markup = FALSE,
  justify = FALSE,
  ...
)
```

## Arguments

- text:

  The string. Newlines start new lines.

- fill_opacity, stroke_width:

  Style; text is filled by default.

- color:

  Color.

- font_size:

  Font size; 48 matches Manim's default.

- line_spacing:

  Line height multiplier.

- font:

  Font family, for example `"serif"`, `"mono"` or an installed font
  name.

- slant:

  `"NORMAL"`, `"ITALIC"` or `"OBLIQUE"`.

- weight:

  `"NORMAL"`, `"BOLD"` and so on.

- t2c, t2f, t2s, t2w, t2g:

  Named lists mapping substrings (or slices like `"[1:4]"`, 0 based as
  in Manim) to colors, fonts, slants, weights, or gradients.

- gradient:

  Colors for a gradient across the glyphs.

- tab_width:

  Spaces per tab.

- warn_missing_font:

  Warn when `font` is not installed (or registered with
  [`register_font()`](https://adamrsophie.github.io/manimR/reference/register_font.md)),
  as upstream does.

- height, width:

  Optional target size.

- should_center:

  Center the text at the origin.

- disable_ligatures:

  Keep one submobject per character, with an invisible point for each
  space, as upstream (default `FALSE`).

- use_svg_cache:

  Accepted for upstream's signature; glyphs are read from the fonts
  directly, so there is no SVG to cache.

- markup:

  Parse `text` as Pango style markup, as
  [`MarkupText()`](https://adamrsophie.github.io/manimR/reference/MarkupText.md)
  does.

- justify:

  For
  [`MarkupText()`](https://adamrsophie.github.io/manimR/reference/MarkupText.md):
  stretch the lines that wrap (markup lines wrap at 2400 / `font_size`
  em, upstream's Pango layout width) to that full width.

- ...:

  Passed to
  [`VMobject()`](https://adamrsophie.github.io/manimR/reference/VMobjectClass.md).

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.

## Examples

``` r
Text("Hello manimR", color = BLUE)
#> <Text> 0 points, 11 submobjects
```
