# Paragraph

Several lines of text, each a
[`Text()`](https://adamrsophie.github.io/manimR/reference/TextClass.md)
in a VGroup.

## Usage

``` r
Paragraph(..., line_spacing = -1, alignment = NULL)
```

## Arguments

- ...:

  Strings, one per line, then named arguments for
  [`Text()`](https://adamrsophie.github.io/manimR/reference/TextClass.md).

- line_spacing:

  Line spacing multiplier.

- alignment:

  `"left"`, `"center"` or `"right"`.

## Examples

``` r
Paragraph("first line", "second line", alignment = "center")
#> <Paragraph> 0 points, 2 submobjects
```
