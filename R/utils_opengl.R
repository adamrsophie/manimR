# Matrix helpers ported from manim/utils/opengl.py. Upstream's OpenGL
# renderer feeds them to shaders; they are plain 4 x 4 matrix arithmetic and
# work without it.

OPENGL_DEPTH <- 20

#' Projection, view and transformation matrices
#'
#' The 4 x 4 homogeneous matrices of `manim.utils.opengl`.
#'
#' * `translation_matrix(x, y, z)`, `scale_matrix(scale_factor)`,
#'   `x_rotation_matrix(x)`, `y_rotation_matrix(y)` and
#'   `z_rotation_matrix(z)` are the elementary transformations.
#' * `opengl_rotation_matrix(x, y, z)` is the product of the rotations about
#'   the x, y and z axes (upstream calls it `rotation_matrix` inside
#'   `manim.utils.opengl`; here that name is the rotation about an axis,
#'   [rotation_matrix()]).
#' * `rotate_in_place_matrix(initial_position, x, y, z)` moves
#'   `initial_position` to the origin, rotates, and moves back.
#' * `orthographic_projection_matrix()` and `perspective_projection_matrix()`
#'   project the frame; `width` and `height` default to the frame size (a
#'   sixth of it for the perspective matrix).
#' * `view_matrix()` is the inverse of the camera's model matrix.
#' * `matrix_to_shader_input(matrix)` flattens a matrix column by column, the
#'   layout shaders take. The projection matrices return this form unless
#'   `format_ = FALSE`, and `view_matrix()` always does.
#'
#' @param matrix A numeric matrix.
#' @param width,height Size of the projected region.
#' @param near,far Distances of the clipping planes.
#' @param format_ `FALSE` returns the matrix instead of its flattened form.
#' @param x,y,z Translation distances or rotation angles in radians.
#' @param initial_position A point.
#' @param scale_factor Scale factor.
#' @param translation Camera position; by default `c(0, 0, 11)`.
#' @param x_rotation,y_rotation,z_rotation Camera rotation angles.
#' @return A 4 x 4 matrix, or a numeric vector of its 16 entries.
#' @name opengl_matrices
#' @examples
#' translation_matrix(1, 2, 3)
#' orthographic_projection_matrix(format_ = FALSE)
NULL

#' @rdname opengl_matrices
#' @export
matrix_to_shader_input <- function(matrix) as.numeric(matrix)

#' @rdname opengl_matrices
#' @export
orthographic_projection_matrix <- function(width = NULL, height = NULL, near = 1, far = OPENGL_DEPTH + 1,
                                           format_ = TRUE) {
  width <- width %||% cfg("frame_width")
  height <- height %||% cfg("frame_height")
  m <- rbind(
    c(2 / width, 0, 0, 0),
    c(0, 2 / height, 0, 0),
    c(0, 0, -2 / (far - near), -(far + near) / (far - near)),
    c(0, 0, 0, 1)
  )
  if (isTRUE(format_)) matrix_to_shader_input(m) else m
}

#' @rdname opengl_matrices
#' @export
perspective_projection_matrix <- function(width = NULL, height = NULL, near = 2, far = 50, format_ = TRUE) {
  width <- width %||% (cfg("frame_width") / 6)
  height <- height %||% (cfg("frame_height") / 6)
  m <- rbind(
    c(2 * near / width, 0, 0, 0),
    c(0, 2 * near / height, 0, 0),
    c(0, 0, (far + near) / (near - far), 2 * far * near / (near - far)),
    c(0, 0, -1, 0)
  )
  if (isTRUE(format_)) matrix_to_shader_input(m) else m
}

#' @rdname opengl_matrices
#' @export
translation_matrix <- function(x = 0, y = 0, z = 0) {
  rbind(c(1, 0, 0, x), c(0, 1, 0, y), c(0, 0, 1, z), c(0, 0, 0, 1))
}

#' @rdname opengl_matrices
#' @export
x_rotation_matrix <- function(x = 0) {
  rbind(c(1, 0, 0, 0), c(0, cos(x), -sin(x), 0), c(0, sin(x), cos(x), 0), c(0, 0, 0, 1))
}

#' @rdname opengl_matrices
#' @export
y_rotation_matrix <- function(y = 0) {
  rbind(c(cos(y), 0, sin(y), 0), c(0, 1, 0, 0), c(-sin(y), 0, cos(y), 0), c(0, 0, 0, 1))
}

#' @rdname opengl_matrices
#' @export
z_rotation_matrix <- function(z = 0) {
  rbind(c(cos(z), -sin(z), 0, 0), c(sin(z), cos(z), 0, 0), c(0, 0, 1, 0), c(0, 0, 0, 1))
}

#' @rdname opengl_matrices
#' @export
opengl_rotation_matrix <- function(x = 0, y = 0, z = 0) {
  x_rotation_matrix(x) %*% y_rotation_matrix(y) %*% z_rotation_matrix(z)
}

#' @rdname opengl_matrices
#' @export
rotate_in_place_matrix <- function(initial_position, x = 0, y = 0, z = 0) {
  p <- initial_position
  translation_matrix(-p[1], -p[2], -p[3]) %*% opengl_rotation_matrix(x, y, z) %*% translation_matrix(p[1], p[2], p[3])
}

#' @rdname opengl_matrices
#' @export
scale_matrix <- function(scale_factor = 1) diag(c(scale_factor, scale_factor, scale_factor, 1))

#' @rdname opengl_matrices
#' @export
view_matrix <- function(translation = NULL, x_rotation = 0, y_rotation = 0, z_rotation = 0) {
  translation <- translation %||% c(0, 0, OPENGL_DEPTH / 2 + 1)
  model <- translation_matrix(translation[1], translation[2], translation[3]) %*%
    opengl_rotation_matrix(x_rotation, y_rotation, z_rotation) %*% scale_matrix()
  matrix_to_shader_input(solve(model))
}
