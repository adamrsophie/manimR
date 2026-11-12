# VDict

A VGroup whose submobjects are addressed by key, as upstream's `VDict`:
`d$add(list(s = Square()))` adds pairs, `d$remove("s")` removes one,
`d[["s"]]` or `d$get("s")` reads one and `d[["s"]] <- Circle()` replaces
it. With `show_keys = TRUE` each value gets its key as a
[`Tex()`](https://adamrsophie.github.io/manimR/reference/tex.md) label
on its left (this needs LaTeX).

## Usage

``` r
VDict(mapping_or_iterable = list(), show_keys = FALSE, ...)
```

## Arguments

- mapping_or_iterable:

  A named list of VMobjects, or a list of `list(key, mobject)` pairs.

- show_keys:

  Whether to show the keys next to the values.

- ...:

  Passed to
  [`VGroup()`](https://adamrsophie.github.io/manimR/reference/VGroupClass.md).
