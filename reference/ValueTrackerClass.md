# Value trackers

A `ValueTracker` stores a number that can be animated, for example with
`tracker$animate$set_value(5)`, and read in updaters with `get_value()`.
`ComplexValueTracker` stores a complex number.

## Usage

``` r
ValueTracker(value = 0, ...)

ComplexValueTracker(value = 0, ...)
```

## Arguments

- value:

  Initial value.

- ...:

  Passed to the Mobject initializer.

## Examples

``` r
t <- ValueTracker(1)
t$increment_value(2)
t$get_value()
#> [1] 3
```
