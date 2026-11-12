# Rate function decorators

Upstream's decorators for rate functions. `unit_interval(f)` returns a
rate function that is 0 below `t = 0`, 1 above `t = 1`, and `f(t)`
between; `zero(f)` returns one that is 0 outside `[0, 1]`.

## Usage

``` r
unit_interval(f)

zero(f)
```

## Arguments

- f:

  A rate function.

## Value

A rate function.

## Examples

``` r
clamped <- unit_interval(function(t) t^2)
clamped(1.5)
#> [1] 1
```
