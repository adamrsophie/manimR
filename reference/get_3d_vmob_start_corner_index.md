# Corners and normals of 3D VMobjects

Helpers that the 3D camera uses to shade a
[`VMobject()`](https://adamrsophie.github.io/manimR/reference/VMobjectClass.md)
face.

## Usage

``` r
get_3d_vmob_start_corner_index(vmob)

get_3d_vmob_end_corner_index(vmob)

get_3d_vmob_start_corner(vmob)

get_3d_vmob_end_corner(vmob)

get_3d_vmob_gradient_start_and_end_points(vmob)

get_3d_vmob_unit_normal(vmob, point_index)

get_3d_vmob_start_corner_unit_normal(vmob)

get_3d_vmob_end_corner_unit_normal(vmob)
```

## Arguments

- vmob:

  A VMobject.

- point_index:

  A 0 based row index into `vmob$points`.

## Value

An integer index, a point, a list of two points, or a unit vector.

## Details

- `get_3d_vmob_start_corner_index()` and
  `get_3d_vmob_end_corner_index()` return the row of `vmob$points`
  holding the start and end corner. **These indices are 0 based**, as
  upstream: the corner is `vmob$points[index + 1, ]`.

- `get_3d_vmob_start_corner()` and `get_3d_vmob_end_corner()` return
  those points (`ORIGIN` for an empty mobject), and
  `get_3d_vmob_gradient_start_and_end_points()` returns both as a list.

- `get_3d_vmob_unit_normal()` returns the unit normal at the 0 based
  point index `point_index`, from the anchors three rows before and
  after it (wrapping around). It returns `UP` for mobjects with two
  anchors or fewer. `get_3d_vmob_start_corner_unit_normal()` and
  `get_3d_vmob_end_corner_unit_normal()` evaluate it at the corners.

## Examples

``` r
sq <- Square()$rotate(PI / 3, axis = RIGHT)
get_3d_vmob_end_corner_index(sq) # 0 based
#> [1] 6
get_3d_vmob_end_corner(sq)
#> [1] -1.0000000 -0.1666667 -0.2886751
get_3d_vmob_start_corner_unit_normal(sq)
#> [1]  0.0000000 -0.8660254  0.5000000
```
