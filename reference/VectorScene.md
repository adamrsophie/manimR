# VectorScene and LinearTransformationScene

Scenes for linear algebra. `VectorScene` adds helpers to draw planes,
vectors, labels and coordinates. `LinearTransformationScene` sets up a
background plane, a transformable foreground plane and basis vectors,
then animates matrices with `apply_matrix()`,
`apply_transposed_matrix()`, `apply_inverse()` and
`apply_nonlinear_transformation()`.

    Shear <- R6::R6Class("Shear", inherit = LinearTransformationScene,
      public = list(construct = function() {
        self$add_unit_square()
        self$apply_matrix(matrix(c(1, 0, 1, 1), 2))
        self$wait()
      }))

## Usage

``` r
X_COLOR

Y_COLOR

Z_COLOR
```

## Value

`VectorScene` and `LinearTransformationScene` are R6 class generators: a
scene class inherits from one of them, and `$new()` creates a scene.
`X_COLOR`, `Y_COLOR` and `Z_COLOR` are colors.

## Details

`VectorScene$new()` and `LinearTransformationScene$new()` take
`basis_vector_stroke_width`, the stroke width of the basis vectors.
`LinearTransformationScene$new()` also takes `include_background_plane`
and `include_foreground_plane`, which planes to draw;
`background_plane_kwargs` and `foreground_plane_kwargs`, lists of
[`NumberPlane()`](https://adamrsophie.github.io/manimR/reference/coordinate_systems.md)
arguments; `show_coordinates`, to label the background plane;
`show_basis_vectors`, to draw i hat and j hat; `i_hat_color` and
`j_hat_color`, the colors of the basis vectors; and
`leave_ghost_vectors`, to keep faded copies of vectors after each
transformation. Other arguments are passed to
[Scene](https://adamrsophie.github.io/manimR/reference/Scene.md).

`X_COLOR`, `Y_COLOR` and `Z_COLOR` are the default colors of the x, y
and z basis vectors.
