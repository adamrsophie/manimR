# MarkupText

Text with inline Pango style markup. Supported tags: `<b>`, `<i>`,
`<tt>`, `<big>`, `<small>`, `<sup>`, `<sub>`, and `<span>` with
`foreground`/`color`, `font`/`font_family`, `weight`, `style`,
`fgalpha`.

## Usage

``` r
MarkupText(text, ...)
```

## Arguments

- text:

  Markup string.

- ...:

  Passed to
  [`Text()`](https://adamrsophie.github.io/manimR/reference/TextClass.md).

## Examples

``` r
MarkupText("<b>bold</b> and <span foreground='red'>red</span>")
#> <MarkupText> 0 points, 10 submobjects
```
