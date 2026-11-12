# Random colors from a seed

Upstream's `RandomColorGenerator`: `$next()` (or `$next_color()`, since
[`next`](https://rdrr.io/r/base/Control.html) is reserved in R and needs
backticks: `` gen$`next`() ``) returns a random color from
`sample_colors` (by default every manim color). With a `seed`, the
generator has its own random stream, which does not touch R's global one
and repeats for the same seed; the sequence differs from Python's.

## Usage

``` r
RandomColorGenerator(seed = NULL, sample_colors = NULL)
```

## Arguments

- seed:

  `NULL`, or an integer seed.

- sample_colors:

  Colors to choose from.

## Value

A `RandomColorGenerator`, an R6 object. `RandomColorGeneratorClass` is
its R6 class generator.

## Examples

``` r
gen <- RandomColorGenerator(42)
gen$next_color()
#> ManimColor('#E07A5F')
```
