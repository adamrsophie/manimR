# Numerical helpers

Ports of `manim.utils.simple_functions`. `sigmoid()` is the logistic
function `1 / (1 + exp(-x))`. `binary_search()` looks, between
`lower_bound` and `upper_bound`, for the input at which the monotone
function `f` reaches `target`, halving the interval until it is shorter
than `tolerance`; it returns `NULL` when `target` is not between the
values at the bounds. Upstream's
[`clip()`](https://rdrr.io/r/graphics/clip.html) is
[`clip_value()`](https://adamrsophie.github.io/manimR/reference/clip_value.md)
here (an exported [`clip()`](https://rdrr.io/r/graphics/clip.html) would
mask [`graphics::clip()`](https://rdrr.io/r/graphics/clip.html)), and
its [`choose()`](https://rdrr.io/r/base/Special.html) is
[`base::choose()`](https://rdrr.io/r/base/Special.html).

## Usage

``` r
binary_search(f, target, lower_bound, upper_bound, tolerance = 1e-04)

sigmoid(x)
```

## Arguments

- f:

  A monotone function of one number returning a number (upstream calls
  it `function`, a reserved word in R).

- target:

  Value to reach.

- lower_bound, upper_bound:

  Search interval.

- tolerance:

  Width of the interval at which the search stops.

- x:

  Numeric vector.

## Value

`sigmoid()`: numeric vector. `binary_search()`: a number or `NULL`.

## Examples

``` r
sigmoid(0)
#> [1] 0.5
binary_search(function(x) x^2 + 3 * x + 1, 11, 0, 5) # about 2
#> [1] 2.000046
binary_search(function(x) x^2 + 3 * x + 1, 71, 0, 5) # NULL
#> NULL
```
