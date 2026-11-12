# Vector and space utilities ported from manim/utils/space_ops.py.

#' Space operations
#'
#' Vector helpers used throughout manimR. Points and vectors are length 3
#' numeric vectors; point sets are n x 3 matrices.
#'
#' @param v,v1,v2,vector Numeric vectors. In `find_intersection()`, `v1` is
#'   the direction of the second line.
#' @param angle Angle in radians.
#' @param axis Rotation axis.
#' @return See Details for functions whose result is not a plain vector.
#' @name space_ops
NULL

#' @rdname space_ops
#' @export
get_norm <- function(v) sqrt(sum(v * v))

#' @rdname space_ops
#' @param fall_back Value returned for a zero vector.
#' @export
normalize <- function(v, fall_back = NULL) {
  n <- get_norm(v)
  if (n > 0) return(v / n)
  if (is.null(fall_back)) v * 0 else fall_back
}

#' @rdname space_ops
#' @export
cross <- function(v1, v2) {
  c(v1[2] * v2[3] - v1[3] * v2[2], v1[3] * v2[1] - v1[1] * v2[3], v1[1] * v2[2] - v1[2] * v2[1])
}

#' @rdname space_ops
#' @export
rotation_matrix <- function(angle, axis = OUT) {
  axis <- normalize(axis)
  if (all(axis == 0)) return(diag(3))
  x <- axis[1]; y <- axis[2]; z <- axis[3]
  c0 <- cos(angle); s <- sin(angle); C <- 1 - c0
  matrix(c(
    x * x * C + c0, x * y * C - z * s, x * z * C + y * s,
    y * x * C + z * s, y * y * C + c0, y * z * C - x * s,
    z * x * C - y * s, z * y * C + x * s, z * z * C + c0
  ), 3, 3, byrow = TRUE)
}

#' @rdname space_ops
#' @export
rotation_about_z <- function(angle) {
  c0 <- cos(angle); s <- sin(angle)
  matrix(c(c0, -s, 0, s, c0, 0, 0, 0, 1), 3, 3, byrow = TRUE)
}

#' @rdname space_ops
#' @export
rotate_vector <- function(vector, angle, axis = OUT) {
  if (length(vector) > 3) stop("Vector must have the correct dimensions.", call. = FALSE)
  # A 2D vector lies in the xy plane, as upstream pads it with z = 0.
  if (length(vector) == 2) vector <- c(vector, 0)
  drop(rotation_matrix(angle, axis) %*% vector)
}

#' @rdname space_ops
#' @export
angle_of_vector <- function(vector) atan2(vector[2], vector[1])

#' @rdname space_ops
#' @export
angle_between_vectors <- function(v1, v2) {
  a <- normalize(v1); b <- normalize(v2)
  2 * atan2(get_norm(a - b), get_norm(a + b))
}

#' @rdname space_ops
#' @details `z_to_vector()` returns a 3 x 3 rotation matrix taking the z
#'   axis to the direction of `vector`.
#' @export
z_to_vector <- function(vector) {
  axis_z <- normalize(vector)
  axis_y <- normalize(cross(axis_z, RIGHT))
  axis_x <- cross(axis_y, axis_z)
  if (get_norm(axis_y) == 0) {
    axis_x <- normalize(cross(UP, axis_z))
    axis_y <- -cross(axis_x, axis_z)
  }
  cbind(axis_x, axis_y, axis_z, deparse.level = 0)
}

#' @rdname space_ops
#' @param n Number of directions (`compass_directions()`) or vertices
#'   (`regular_vertices()`).
#' @param start_vect First direction.
#' @export
compass_directions <- function(n = 4, start_vect = RIGHT) {
  do.call(rbind, lapply(0:(n - 1), function(k) rotate_vector(start_vect, k * TAU / n)))
}

#' @rdname space_ops
#' @param radius Radius of the circle the vertices lie on.
#' @param start_angle Angle of the first vertex; by default 0 for even `n`
#'   and `TAU / 4` for odd `n`.
#' @details `regular_vertices()` returns `list(vertices, start_angle)`, an
#'   n x 3 matrix of regularly spaced vertices on a circle centered at the
#'   origin and the angle actually used for the first one.
#' @export
regular_vertices <- function(n, radius = 1, start_angle = NULL) {
  if (is.null(start_angle)) start_angle <- if (n %% 2 == 0) 0 else TAU / 4
  list(vertices = compass_directions(n, rotate_vector(RIGHT * radius, start_angle)), start_angle = start_angle)
}

#' @rdname space_ops
#' @param z A complex number.
#' @export
complex_to_R3 <- function(z) c(Re(z), Im(z), 0)

#' @rdname space_ops
#' @param point A point.
#' @export
R3_to_complex <- function(point) complex(real = point[1], imaginary = point[2])

#' @rdname space_ops
#' @param p1,p2 Points. In `find_intersection()`, `p1` is a point of the
#'   second line.
#' @export
midpoint <- function(p1, p2) (p1 + p2) / 2

#' @rdname space_ops
#' @param line1,line2 Two lines, each a list or 2 x 3 matrix of two points.
#' @export
line_intersection <- function(line1, line2) {
  as_rows <- function(l) if (is.matrix(l)) l else do.call(rbind, l)
  l1 <- as_rows(line1); l2 <- as_rows(line2)
  h1 <- cross(c(l1[1, 1:2], 1), c(l1[2, 1:2], 1))
  h2 <- cross(c(l2[1, 1:2], 1), c(l2[2, 1:2], 1))
  p <- cross(h1, h2)
  if (p[3] == 0) stop("The lines are parallel, there is no unique intersection point.")
  c(p[1] / p[3], p[2] / p[3], 0)
}

#' @rdname space_ops
#' @param p0s,v0s A point and the direction of the first line of
#'   `find_intersection()`: single vectors, or n x 3 matrices with one line
#'   per row (then `p1s`, `v1s` are matrices too).
#' @param p1s,v1s A point and the direction of the second line.
#' @param threshold Lower bound for the denominator, guarding against
#'   parallel lines.
#' @details `find_intersection()` returns the intersection of the line
#'   through `p0s` with direction `v0s` and the line through `p1s` with
#'   direction `v1s`; in 3D, the point of the first line closest to the second. Given
#'   matrices it works row by row and returns an n x 3 matrix (upstream
#'   returns a list of points).
#' @export
find_intersection <- function(p0s, v0s, p1s, v1s, threshold = 1e-5) {
  one <- function(p0, v0, p1, v1) {
    normal <- cross(v1, cross(v0, v1))
    denom <- max(sum(v0 * normal), threshold)
    p0 + sum((p1 - p0) * normal) / denom * v0
  }
  if (!is.matrix(p0s)) return(one(p0s, v0s, p1s, v1s))
  do.call(rbind, lapply(seq_len(nrow(p0s)), function(i) one(p0s[i, ], v0s[i, ], p1s[i, ], v1s[i, ])))
}

#' @rdname space_ops
#' @param x_y Vertices of a polygon, an n x 2 (or n x 3) matrix.
#' @details `shoelace()` returns the signed area of the polygon computed with
#'   the trapezoid rule as upstream does (positive for a clockwise polygon),
#'   and `shoelace_direction()` returns `"CW"` or `"CCW"` from its sign.
#' @export
shoelace <- function(x_y) {
  x <- x_y[, 1]; y <- x_y[, 2]
  n <- length(x)
  if (n < 2) return(0)
  sum((x[-1] - x[-n]) * (y[-1] + y[-n]) / 2)
}

#' @rdname space_ops
#' @export
shoelace_direction <- function(x_y) if (shoelace(x_y) > 0) "CW" else "CCW"

#' @rdname space_ops
#' @param vec A vector `c(x, y, z)`.
#' @export
cartesian_to_spherical <- function(vec) {
  r <- get_norm(vec)
  if (r == 0) return(c(0, 0, 0))
  c(r, atan2(vec[2], vec[1]), acos(vec[3] / r))
}

#' @rdname space_ops
#' @param spherical `c(r, theta, phi)`.
#' @export
spherical_to_cartesian <- function(spherical) {
  r <- spherical[1]; theta <- spherical[2]; phi <- spherical[3]
  c(r * cos(theta) * sin(phi), r * sin(theta) * sin(phi), r * cos(phi))
}

#' @rdname space_ops
#' @param points Points, an n x 3 matrix (one point per row).
#' @details `get_winding_number()` returns how many times the closed polygon
#'   with vertices `points` winds counterclockwise around the origin.
#' @export
get_winding_number <- function(points) {
  points <- as_points(points)
  n <- nrow(points)
  ang <- atan2(points[, 2], points[, 1])
  d <- ang[c(seq_len(n)[-1], 1)] - ang
  d <- ((d + pi) %% TAU) - pi
  sum(d) / TAU
}

#' @rdname space_ops
#' @param tol Tolerance below which vectors count as aligned.
#' @details `get_unit_normal()` returns a unit vector normal to `v1` and
#'   `v2`. When they are aligned (or one is zero) it returns the unit vector
#'   in the plane of the remaining vector and the z axis that is perpendicular
#'   to that vector, and `DOWN` when that vector is itself along the z axis.
#' @export
get_unit_normal <- function(v1, v2, tol = 1e-6) {
  # Dividing by the largest absolute component is enough to normalize the
  # scale, as upstream does.
  div1 <- max(abs(v1))
  div2 <- max(abs(v2))
  if (div1 == 0) {
    if (div2 == 0) return(DOWN)
    u <- v2 / div2
  } else if (div2 == 0) {
    u <- v1 / div1
  } else {
    u1 <- v1 / div1
    u2 <- v2 / div2
    cp <- cross(u1, u2)
    cp_norm <- sqrt(sum(cp^2))
    if (cp_norm > tol) return(cp / cp_norm)
    u <- u1
  }
  if (abs(u[1]) < tol && abs(u[2]) < tol) return(DOWN)
  cp <- c(-u[1] * u[3], -u[2] * u[3], u[1]^2 + u[2]^2)
  cp / sqrt(sum(cp^2))
}

#' @rdname space_ops
#' @details `center_of_mass()` returns the mean of `points` (a matrix with
#'   one point per row, or a list of points).
#' @export
center_of_mass <- function(points) {
  if (is.list(points) && !is.data.frame(points)) points <- do.call(rbind, points)
  colMeans(as.matrix(points))
}

#' @rdname space_ops
#' @param complex_func A function of a complex number returning a complex
#'   number.
#' @details `complex_func_to_R3_func()` turns a complex function into a
#'   function of a point `c(x, y, z)`, through [R3_to_complex()] and
#'   [complex_to_R3()].
#' @export
complex_func_to_R3_func <- function(complex_func) {
  force(complex_func)
  function(p) complex_to_R3(complex_func(R3_to_complex(p)))
}

#' @rdname space_ops
#' @param a,b Two vectors, or two matrices with one vector per row.
#' @details `cross2d()` returns the determinant `a[1] * b[2] - a[2] * b[1]`
#'   of the first two components, row by row for matrices.
#' @export
cross2d <- function(a, b) {
  if (is.matrix(a)) return(a[, 1] * b[, 2] - a[, 2] * b[, 1])
  a[1] * b[2] - b[1] * a[2]
}

#' @rdname space_ops
#' @param line The two end points of a segment, as a list or a 2 x 3 matrix.
#' @param norm_vector Vector perpendicular to both the segment and its
#'   bisector.
#' @details `perpendicular_bisector()` returns a 2 x 3 matrix with the end
#'   points `m + d` and `m - d` of the perpendicular bisector, where `m` is
#'   the midpoint of the segment and `d` is the cross product of the segment
#'   (first point minus second) with `norm_vector`.
#' @export
perpendicular_bisector <- function(line, norm_vector = OUT) {
  if (is.list(line) && !is.data.frame(line)) line <- do.call(rbind, line)
  line <- as.matrix(line)
  p1 <- line[1, ]
  p2 <- line[2, ]
  direction <- cross(p1 - p2, norm_vector)
  m <- midpoint(p1, p2)
  rbind(m + direction, m - direction)
}

#' @rdname space_ops
#' @param dim Size of the matrix.
#' @param thickness Number of diagonals on each side counted, the main one
#'   included.
#' @details `thick_diagonal()` returns a `dim x dim` integer matrix with 1
#'   where `abs(i - j) < thickness` and 0 elsewhere.
#' @export
thick_diagonal <- function(dim, thickness = 2) {
  i <- seq_len(dim)
  m <- abs(outer(i, i, "-")) < thickness
  storage.mode(m) <- "integer"
  m
}

#' Quaternions
#'
#' Quaternions are numeric vectors `c(w, x, y, z)`.
#'
#' * `quaternion_mult()` returns the Hamilton product of its arguments, taken
#'   left to right; with no arguments it returns `c(1, 0, 0, 0)`.
#' * `quaternion_from_angle_axis()` returns the rotation quaternion
#'   `c(cos(angle / 2), sin(angle / 2) * axis)`.
#' * `angle_axis_from_quaternion()` returns `list(angle, axis)`. As upstream,
#'   an angle above `PI` is replaced by `TAU - angle` and the axis is
#'   negated, which describes the same rotation. For a quaternion with zero
#'   vector part the axis is `c(1, 0, 0)`.
#' * `quaternion_conjugate()` negates the vector part.
#'
#' @param ... Quaternions.
#' @param angle Rotation angle in radians.
#' @param axis Rotation axis.
#' @param axis_normalized Whether `axis` already has unit length.
#' @param quaternion A quaternion.
#' @return A quaternion, or for `angle_axis_from_quaternion()` a list.
#' @export
#' @examples
#' q <- quaternion_from_angle_axis(PI / 2, OUT)
#' quaternion_mult(q, c(0, 1, 0, 0), quaternion_conjugate(q)) # rotates RIGHT to UP
#' angle_axis_from_quaternion(q)
quaternion_mult <- function(...) {
  quats <- list(...)
  if (!length(quats)) return(c(1, 0, 0, 0))
  result <- quats[[1]]
  for (q in quats[-1]) {
    w1 <- result[1]; x1 <- result[2]; y1 <- result[3]; z1 <- result[4]
    w2 <- q[1]; x2 <- q[2]; y2 <- q[3]; z2 <- q[4]
    result <- c(
      w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2,
      w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
      w1 * y2 + y1 * w2 + z1 * x2 - x1 * z2,
      w1 * z2 + z1 * w2 + x1 * y2 - y1 * x2
    )
  }
  result
}

#' @rdname quaternion_mult
#' @export
quaternion_from_angle_axis <- function(angle, axis, axis_normalized = FALSE) {
  if (!axis_normalized) axis <- normalize(axis)
  c(cos(angle / 2), sin(angle / 2) * axis)
}

#' @rdname quaternion_mult
#' @export
angle_axis_from_quaternion <- function(quaternion) {
  axis <- normalize(quaternion[2:4], fall_back = c(1, 0, 0))
  angle <- 2 * acos(quaternion[1])
  # A rotation by angle about axis is a rotation by TAU - angle about -axis
  # (current upstream flips the axis too; manim 0.20.1 did not).
  if (angle > TAU / 2) {
    angle <- TAU - angle
    axis <- -axis
  }
  list(angle = angle, axis = axis)
}

#' @rdname quaternion_mult
#' @export
quaternion_conjugate <- function(quaternion) c(quaternion[1], -quaternion[-1])

# Coerce a point-like value to a length 3 numeric vector.
as_point <- function(p) {
  p <- as.numeric(p)
  if (length(p) == 2) p <- c(p, 0)
  if (length(p) != 3) stop("A point must have 2 or 3 coordinates.", call. = FALSE)
  p
}

# Coerce a list of points or matrix to an n x 3 matrix.
as_points <- function(x) {
  if (is.matrix(x)) {
    if (ncol(x) == 2) x <- cbind(x, 0)
    storage.mode(x) <- "double"
    return(unname(x))
  }
  if (is.list(x)) {
    if (length(x) == 0) return(matrix(0, 0, 3))
    return(do.call(rbind, lapply(x, as_point)))
  }
  matrix(as_point(x), 1)
}
