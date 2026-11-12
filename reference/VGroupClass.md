# VGroup

Group vectorized mobjects so they move and style together.

## Usage

``` r
VGroup(...)
```

## Arguments

- ...:

  VMobjects, or lists of them. Named style arguments are passed to
  [`VMobject()`](https://adamrsophie.github.io/manimR/reference/VMobjectClass.md).

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.

## Examples

``` r
g <- VGroup(Circle(), Square())$arrange(RIGHT)
```
