# Space operations

Vector helpers used throughout manimR. Points and vectors are length 3
numeric vectors; point sets are n x 3 matrices.

## Usage

``` r
get_norm(v)

normalize(vect, fall_back = NULL)

cross(v1, v2)

rotation_matrix(angle, axis = OUT, homogeneous = FALSE)

rotation_matrix_transpose(angle, axis)

rotation_matrix_transpose_from_quaternion(quat)

rotation_matrix_from_quaternion(quat)

norm_squared(v)

normalize_along_axis(array, axis)

rotation_about_z(angle)

rotate_vector(vector, angle, axis = OUT)

angle_of_vector(vector)

angle_between_vectors(v1, v2)

z_to_vector(vector)

compass_directions(n = 4, start_vect = RIGHT)

regular_vertices(n, radius = 1, start_angle = NULL)

complex_to_R3(complex_num)

R3_to_complex(point)

midpoint(point1, point2)

line_intersection(line1, line2)

find_intersection(p0s, v0s, p1s, v1s, threshold = 1e-05)

shoelace(x_y)

shoelace_direction(x_y)

cartesian_to_spherical(vec)

spherical_to_cartesian(spherical)

get_winding_number(points)

get_unit_normal(v1, v2, tol = 1e-06)

center_of_mass(points)

complex_func_to_R3_func(complex_func)

cross2d(a, b)

perpendicular_bisector(line, norm_vector = OUT)

thick_diagonal(dim, thickness = 2)
```

## Arguments

- v, v1, v2, vector, vect:

  Numeric vectors. In `find_intersection()`, `v1` is the direction of
  the second line.

- fall_back:

  Value returned for a zero vector.

- angle:

  Angle in radians.

- axis:

  Rotation axis. In `normalize_along_axis()`, the dimension to take
  norms along (1 or 2).

- homogeneous:

  `TRUE` returns a 4 x 4 homogeneous matrix.

- quat:

  A quaternion `c(w, x, y, z)`.

- array:

  A numeric matrix.

- n:

  Number of directions (`compass_directions()`) or vertices
  (`regular_vertices()`).

- start_vect:

  First direction.

- radius:

  Radius of the circle the vertices lie on.

- start_angle:

  Angle of the first vertex; by default 0 for even `n` and `TAU / 4` for
  odd `n`.

- complex_num:

  A complex number.

- point:

  A point.

- point1, point2:

  Points.

- line1, line2:

  Two lines, each a list or 2 x 3 matrix of two points.

- p0s, v0s:

  A point and the direction of the first line of `find_intersection()`:
  single vectors, or n x 3 matrices with one line per row (then `p1s`,
  `v1s` are matrices too).

- p1s, v1s:

  A point and the direction of the second line.

- threshold:

  Lower bound for the denominator, guarding against parallel lines.

- x_y:

  Vertices of a polygon, an n x 2 (or n x 3) matrix.

- vec:

  A vector `c(x, y, z)`.

- spherical:

  `c(r, theta, phi)`.

- points:

  Points, an n x 3 matrix (one point per row).

- tol:

  Tolerance below which vectors count as aligned.

- complex_func:

  A function of a complex number returning a complex number.

- a, b:

  Two vectors, or two matrices with one vector per row.

- line:

  The two end points of a segment, as a list or a 2 x 3 matrix.

- norm_vector:

  Vector perpendicular to both the segment and its bisector.

- dim:

  Size of the matrix.

- thickness:

  Number of diagonals on each side counted, the main one included.

## Value

See Details for functions whose result is not a plain vector.

## Details

`rotation_matrix_transpose()` is the transpose of `rotation_matrix()`.
`rotation_matrix_transpose_from_quaternion()` returns a list of the
three rows of that transpose for the rotation a quaternion describes,
and `rotation_matrix_from_quaternion()` the rotation matrix itself.

`norm_squared()` is the squared length of a vector.
`normalize_along_axis()` divides a matrix by the norms taken along
`axis` (1 sums over rows, 2 over columns, so `axis = 2` gives every row
length 1); zero norms are left alone.

`z_to_vector()` returns a 3 x 3 rotation matrix taking the z axis to the
direction of `vector`.

`regular_vertices()` returns `list(vertices, start_angle)`, an n x 3
matrix of regularly spaced vertices on a circle centered at the origin
and the angle actually used for the first one.

`find_intersection()` returns the intersection of the line through `p0s`
with direction `v0s` and the line through `p1s` with direction `v1s`; in
3D, the point of the first line closest to the second. Given matrices it
works row by row and returns an n x 3 matrix (upstream returns a list of
points).

`shoelace()` returns the signed area of the polygon computed with the
trapezoid rule as upstream does (positive for a clockwise polygon), and
`shoelace_direction()` returns `"CW"` or `"CCW"` from its sign.

`get_winding_number()` returns how many times the closed polygon with
vertices `points` winds counterclockwise around the origin.

`get_unit_normal()` returns a unit vector normal to `v1` and `v2`. When
they are aligned (or one is zero) it returns the unit vector in the
plane of the remaining vector and the z axis that is perpendicular to
that vector, and `DOWN` when that vector is itself along the z axis.

`center_of_mass()` returns the mean of `points` (a matrix with one point
per row, or a list of points).

`complex_func_to_R3_func()` turns a complex function into a function of
a point `c(x, y, z)`, through `R3_to_complex()` and `complex_to_R3()`.

`cross2d()` returns the determinant `a[1] * b[2] - a[2] * b[1]` of the
first two components, row by row for matrices.

`perpendicular_bisector()` returns a 2 x 3 matrix with the end points
`m + d` and `m - d` of the perpendicular bisector, where `m` is the
midpoint of the segment and `d` is the cross product of the segment
(first point minus second) with `norm_vector`.

`thick_diagonal()` returns a `dim x dim` integer matrix with 1 where
`abs(i - j) < thickness` and 0 elsewhere.
