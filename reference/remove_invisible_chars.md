# Remove the invisible characters of a text mobject

With `disable_ligatures = TRUE`,
[`Text()`](https://adamrsophie.github.io/manimR/reference/TextClass.md)
keeps an invisible dot for every space, so that its submobjects match
its characters. This returns the visible ones. Ported from
`manim.mobject.text.text_mobject`.

## Usage

``` r
remove_invisible_chars(mobject)
```

## Arguments

- mobject:

  A
  [`Text()`](https://adamrsophie.github.io/manimR/reference/TextClass.md)
  or
  [`Code()`](https://adamrsophie.github.io/manimR/reference/CodeClass.md)
  style mobject: a group of characters, or a group of lines of
  characters.

## Value

A
[`VGroup()`](https://adamrsophie.github.io/manimR/reference/VGroupClass.md)
of the characters that are not dots; for a group of lines, a
[`VGroup()`](https://adamrsophie.github.io/manimR/reference/VGroupClass.md)
with one
[`VGroup()`](https://adamrsophie.github.io/manimR/reference/VGroupClass.md)
per line.

## Examples

``` r
length(remove_invisible_chars(Text("a b c", disable_ligatures = TRUE))$submobjects)
#> [1] 3
```
