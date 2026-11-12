# Change default arguments of a mobject or animation class

`set_default(Text, font_size = 60)` makes every later
[`Text()`](https://adamrsophie.github.io/manimR/reference/TextClass.md)
use `font_size = 60` unless given explicitly. Calling
`set_default(Text)` with no further arguments restores the original
defaults. Works for arguments accepted by the class, including those
passed on to parent classes.

## Usage

``` r
set_default(cls, ...)
```

## Arguments

- cls:

  A constructor such as `Text` or an R6 generator such as `TextClass`.

- ...:

  New defaults as named arguments.

## Value

The generator, invisibly.

## Examples

``` r
set_default(Circle, color = BLUE)
Circle()$get_color()
#> [1] "#58C4DD"
set_default(Circle)
```
