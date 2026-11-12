# Interpolation helpers

`interpolate()` returns `(1 - alpha) * start + alpha * end`, as upstream
computes it, and works on numbers, vectors and matrices.

## Usage

``` r
interpolate(start, end, alpha)

inverse_interpolate(start, end, value)

match_interpolate(new_start, new_end, old_start, old_end, old_value)

integer_interpolate(start, end, alpha)

mid(start, end)
```

## Arguments

- start, end:

  Values to interpolate between.

- alpha:

  Interpolation parameter.

- value:

  Value whose interpolation parameter `inverse_interpolate()` returns.

- new_start, new_end, old_start, old_end, old_value:

  Ranges for `match_interpolate()`.

## Details

`integer_interpolate()` returns `list(index, residue)`: the integer part
of `interpolate(start, end, alpha)` (truncated as Python's `int()` does)
and the fractional part of `(end - start) * alpha`. When `alpha >= 1` it
returns `end - 1` and residue 1. The numbers follow upstream exactly, so
`integer_interpolate(0, n, alpha)$index` is a 0 based position: add 1
before using it to index an R vector.

`mid()` returns the midpoint `(start + end) / 2` of two numbers or
points.

## Examples

``` r
integer_interpolate(0, 10, 0.46) # index 4, residue 0.6
#> $index
#> [1] 4
#> 
#> $residue
#> [1] 0.6
#> 
```
