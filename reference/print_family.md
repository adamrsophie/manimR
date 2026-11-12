# Debugging helpers

`print_family()` prints a mobject and, indented by one tab per level,
every submobject below it, each with its name and id.

## Usage

``` r
print_family(mobject, n_tabs = 0)

index_labels(
  mobject,
  label_height = 0.15,
  background_stroke_width = 5,
  background_stroke_color = BLACK,
  ...
)
```

## Arguments

- mobject:

  A mobject.

- n_tabs:

  Indentation of the first line, in tabs.

- label_height:

  Height of each label.

- background_stroke_width, background_stroke_color:

  Outline drawn behind each label.

- ...:

  Further arguments passed to
  [`Integer()`](https://adamrsophie.github.io/manimR/reference/DecimalNumberClass.md).

## Value

`print_family()` returns `mobject` invisibly; `index_labels()` returns a
VGroup of labels.

## Details

`index_labels()` returns a
[`VGroup()`](https://adamrsophie.github.io/manimR/reference/VGroupClass.md)
of
[`Integer()`](https://adamrsophie.github.io/manimR/reference/DecimalNumberClass.md)
labels, one placed on each submobject of `mobject`, which helps when
picking parts of a complicated mobject such as a
[`MathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md).
The labels count from 1, as `mobject[i]` does in R (upstream labels
count from 0). Labels go on the submobjects, the parts `mobject[i]`
returns; upstream labels the pieces of
[`split()`](https://rdrr.io/r/base/split.html), which also include
`mobject` itself when it has points of its own. Each label is scaled to
`label_height` and gets a background stroke so it stays legible on top
of the mobject.

## Examples

``` r
print_family(VGroup(Square(), VGroup(Circle(), Dot())))
#>  VGroup 23fe2af63e79b71b00-1948
#>   Square 23fe2af63e79b71b00-1943
#>   VGroup 23fe2af63e79b71b00-1947
#>       Circle 23fe2af63e79b71b00-1945
#>       Dot 23fe2af63e79b71b00-1946
if (FALSE) { # \dontrun{
# Needs LaTeX and dvisvgm.
eq <- MathTex("\\frac{d}{dx}f(x)g(x)=")
labels <- index_labels(eq[1])
} # }
```
