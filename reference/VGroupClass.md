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

## Examples

``` r
g <- VGroup(Circle(), Square())$arrange(RIGHT)
```
