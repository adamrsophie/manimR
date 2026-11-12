# Quaternions

Quaternions are numeric vectors `c(w, x, y, z)`.

## Usage

``` r
quaternion_mult(...)

quaternion_from_angle_axis(angle, axis, axis_normalized = FALSE)

angle_axis_from_quaternion(quaternion)

quaternion_conjugate(quaternion)
```

## Arguments

- ...:

  Quaternions.

- angle:

  Rotation angle in radians.

- axis:

  Rotation axis.

- axis_normalized:

  Whether `axis` already has unit length.

- quaternion:

  A quaternion.

## Value

A quaternion, or for `angle_axis_from_quaternion()` a list.

## Details

- `quaternion_mult()` returns the Hamilton product of its arguments,
  taken left to right; with no arguments it returns `c(1, 0, 0, 0)`.

- `quaternion_from_angle_axis()` returns the rotation quaternion
  `c(cos(angle / 2), sin(angle / 2) * axis)`.

- `angle_axis_from_quaternion()` returns `list(angle, axis)`. As
  upstream, an angle above `PI` is replaced by `TAU - angle` and the
  axis is negated, which describes the same rotation. For a quaternion
  with zero vector part the axis is `c(1, 0, 0)`.

- `quaternion_conjugate()` negates the vector part.

## Examples

``` r
q <- quaternion_from_angle_axis(PI / 2, OUT)
quaternion_mult(q, c(0, 1, 0, 0), quaternion_conjugate(q)) # rotates RIGHT to UP
#> [1] 0.000000e+00 2.220446e-16 1.000000e+00 0.000000e+00
angle_axis_from_quaternion(q)
#> $angle
#> [1] 1.570796
#> 
#> $axis
#> [1] 0 0 1
#> 
```
