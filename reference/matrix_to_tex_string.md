# Matrix helpers

`matrix_to_tex_string()` writes a matrix as a LaTeX `array` in square
brackets and `matrix_to_mobject()` renders it with
[`MathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md). A
vector becomes a column.

## Usage

``` r
matrix_to_tex_string(matrix)

matrix_to_mobject(matrix)
```

## Arguments

- matrix:

  A matrix or vector.

## Value

`matrix_to_tex_string()` returns a LaTeX string, and
`matrix_to_mobject()` a `MathTex` mobject of it.

## Examples

``` r
matrix_to_tex_string(matrix(1:4, 2))
#> [1] "\\left[ \\begin{array}{cc}1 & 3 \\\\ 2 & 4\\end{array} \\right]"
```
