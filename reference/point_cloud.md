# Point cloud mobjects

`PMobject` is a mobject made of points drawn as small squares, each with
its own color (the `rgbas` matrix, one row per point). `Mobject1D` and
`Mobject2D` add a sampling `density`. `PGroup()` groups point clouds,
`PointCloudDot()` is a disc filled with points and `Point()` is a single
point.

## Usage

``` r
PMobject(stroke_width = DEFAULT_STROKE_WIDTH, ...)

Mobject1D(density = DEFAULT_POINT_DENSITY_1D, ...)

Mobject2D(density = DEFAULT_POINT_DENSITY_2D, ...)

PGroup(...)

PointCloudDot(
  center = ORIGIN,
  radius = 2,
  stroke_width = 2,
  density = DEFAULT_POINT_DENSITY_1D,
  color = PURE_YELLOW,
  ...
)

Point(location = ORIGIN, color = BLACK, ...)
```

## Arguments

- stroke_width:

  Drawn size of each point.

- ...:

  Further named arguments passed to
  [MobjectClass](https://adamrsophie.github.io/manimR/reference/MobjectClass.md),
  or for `PGroup()` the point cloud mobjects to group.

- density:

  Number of sample points per unit length (1D) or per unit area (2D).

- center, radius:

  Center and radius of the disc of points.

- color:

  Color of the points.

- location:

  Position of the point.

## Examples

``` r
cloud <- PointCloudDot(radius = 1, density = 20, color = BLUE)
cloud$thin_out(2)
g <- PGroup(PointCloudDot(), Point(RIGHT))
```
