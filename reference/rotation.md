# Rotation animations

`Rotate()` turns a mobject by `angle` along an arc path. `Rotating()`
spins it continuously with a linear rate by default.

## Usage

``` r
Rotating(
  mobject,
  angle = TAU,
  axis = OUT,
  about_point = NULL,
  about_edge = NULL,
  run_time = 5,
  rate_func = linear,
  ...
)

Rotate(
  mobject,
  angle = PI,
  axis = OUT,
  about_point = NULL,
  about_edge = NULL,
  path_arc = NULL,
  path_arc_axis = NULL,
  ...
)
```

## Arguments

- mobject:

  The mobject.

- angle:

  Angle in radians.

- axis:

  Rotation axis.

- about_point, about_edge:

  Center of rotation.

- run_time:

  Duration.

- rate_func:

  Rate function.

- ...:

  Passed to
  [`Animation()`](https://adamrsophie.github.io/manimR/reference/AnimationClass.md)
  or
  [`Transform()`](https://adamrsophie.github.io/manimR/reference/transform.md).

- path_arc, path_arc_axis:

  Arc angle and axis of the path the points follow in `Rotate()`;
  default to `angle` and `axis`.
