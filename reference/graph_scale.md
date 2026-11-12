# Axis scalings

Scales control how values along a
[`NumberLine()`](https://adamrsophie.github.io/manimR/reference/NumberLine.md)
or the axes of a coordinate system map to positions. `LinearBase()`
multiplies values by a constant; `LogBase()` turns the axis into a
logarithmic one, so that an axis with `x_range = c(-1, 3)` spans `10^-1`
to `10^3`.

## Usage

``` r
LinearBase(scale_factor = 1)

LogBase(base = 10, custom_labels = TRUE)
```

## Arguments

- scale_factor:

  The slope of the linear scaling.

- base:

  The base of the logarithm.

- custom_labels:

  Whether axes using this scale build their own labels (with
  [`Integer()`](https://adamrsophie.github.io/manimR/reference/DecimalNumberClass.md))
  instead of plain decimal numbers.

## Value

A scale object.

## Details

Each scale has the methods `func(value)` (the scaling itself, called
`function` upstream, which is a reserved word in R) and
`inverse_function(value)`. `LogBase` also has
`get_custom_labels(val_range, unit_decimal_places = 0, ...)`, which
returns
[`Integer()`](https://adamrsophie.github.io/manimR/reference/DecimalNumberClass.md)
labels of the form \\10^{k}\\.

## Examples

``` r
LogBase(base = 2)$func(3)
#> [1] 8
LinearBase(2)$inverse_function(4)
#> [1] 2
```
