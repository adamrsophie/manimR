# Clip a value to a range

Upstream's `clip(a, min_a, max_a)` from `manim.utils.simple_functions`,
named `clip_value()` here because an exported
[`clip()`](https://rdrr.io/r/graphics/clip.html) would mask
[`graphics::clip()`](https://rdrr.io/r/graphics/clip.html). Upstream's
`choose(n, k)` needs no port:
[`base::choose()`](https://rdrr.io/r/base/Special.html) computes the
same binomial coefficient.

## Usage

``` r
clip_value(a, min_a, max_a)
```

## Arguments

- a:

  A value.

- min_a, max_a:

  The range.

## Value

`min_a` when `a` is below it, `max_a` when above, else `a`.

## Examples

``` r
clip_value(5, 0, 3)
#> [1] 3
```
