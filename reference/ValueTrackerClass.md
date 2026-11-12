# Value trackers

A `ValueTracker` stores a number that can be animated, for example with
`tracker$animate$set_value(5)`, and read in updaters with `get_value()`.
`ComplexValueTracker` stores a complex number. The arithmetic operators
return a new tracker, and `as.logical(t)` is `TRUE` when the value is
not zero, as upstream's `bool(t)`.

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

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.

## Examples

``` r
t <- ValueTracker(1)
t$increment_value(2)
t$get_value()
#> [1] 3
```
