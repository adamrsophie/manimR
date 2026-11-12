# Projection, view and transformation matrices

The 4 x 4 homogeneous matrices of `manim.utils.opengl`.

## Usage

``` r
matrix_to_shader_input(matrix)

orthographic_projection_matrix(
  width = NULL,
  height = NULL,
  near = 1,
  far = OPENGL_DEPTH + 1,
  format_ = TRUE
)

perspective_projection_matrix(
  width = NULL,
  height = NULL,
  near = 2,
  far = 50,
  format_ = TRUE
)

translation_matrix(x = 0, y = 0, z = 0)

x_rotation_matrix(x = 0)

y_rotation_matrix(y = 0)

z_rotation_matrix(z = 0)

opengl_rotation_matrix(x = 0, y = 0, z = 0)

rotate_in_place_matrix(initial_position, x = 0, y = 0, z = 0)

scale_matrix(scale_factor = 1)

view_matrix(translation = NULL, x_rotation = 0, y_rotation = 0, z_rotation = 0)
```

## Arguments

- matrix:

  A numeric matrix.

- width, height:

  Size of the projected region.

- near, far:

  Distances of the clipping planes.

- format\_:

  `FALSE` returns the matrix instead of its flattened form.

- x, y, z:

  Translation distances or rotation angles in radians.

- initial_position:

  A point.

- scale_factor:

  Scale factor.

- translation:

  Camera position; by default `c(0, 0, 11)`.

- x_rotation, y_rotation, z_rotation:

  Camera rotation angles.

## Value

A 4 x 4 matrix, or a numeric vector of its 16 entries.

## Details

- `translation_matrix(x, y, z)`, `scale_matrix(scale_factor)`,
  `x_rotation_matrix(x)`, `y_rotation_matrix(y)` and
  `z_rotation_matrix(z)` are the elementary transformations.

- `opengl_rotation_matrix(x, y, z)` is the product of the rotations
  about the x, y and z axes (upstream calls it `rotation_matrix` inside
  `manim.utils.opengl`; here that name is the rotation about an axis,
  [`rotation_matrix()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)).

- `rotate_in_place_matrix(initial_position, x, y, z)` moves
  `initial_position` to the origin, rotates, and moves back.

- `orthographic_projection_matrix()` and
  `perspective_projection_matrix()` project the frame; `width` and
  `height` default to the frame size (a sixth of it for the perspective
  matrix).

- `view_matrix()` is the inverse of the camera's model matrix.

- `matrix_to_shader_input(matrix)` flattens a matrix column by column,
  the layout shaders take. The projection matrices return this form
  unless `format_ = FALSE`, and `view_matrix()` always does.

## Examples

``` r
translation_matrix(1, 2, 3)
#>      [,1] [,2] [,3] [,4]
#> [1,]    1    0    0    1
#> [2,]    0    1    0    2
#> [3,]    0    0    1    3
#> [4,]    0    0    0    1
orthographic_projection_matrix(format_ = FALSE)
#>          [,1] [,2] [,3] [,4]
#> [1,] 0.140625 0.00  0.0  0.0
#> [2,] 0.000000 0.25  0.0  0.0
#> [3,] 0.000000 0.00 -0.1 -1.1
#> [4,] 0.000000 0.00  0.0  1.0
```
