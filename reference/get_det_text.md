# Determinant label

Builds "det" with parentheses around `matrix` and, if `determinant` is
given, "= determinant" after it. Add the matrix to the scene separately.

## Usage

``` r
get_det_text(
  matrix,
  determinant = NULL,
  background_rect = FALSE,
  initial_scale_factor = 2
)
```

## Arguments

- matrix:

  A
  [`Matrix()`](https://adamrsophie.github.io/manimR/reference/MatrixClass.md).

- determinant:

  Optional value of the determinant.

- background_rect:

  Add a background rectangle behind "det".

- initial_scale_factor:

  Scale of "det" and the parentheses.

## Value

A
[`VGroup()`](https://adamrsophie.github.io/manimR/reference/VGroupClass.md).

## Examples

``` r
if (FALSE) { # \dontrun{
# Needs LaTeX and dvisvgm.
m <- Matrix(rbind(c(2, 0), c(-1, 1)))
det <- get_det_text(m, determinant = 3, initial_scale_factor = 1)
} # }
```
