# OpenGL point clouds

Point cloud mobjects of upstream's OpenGL renderer, drawn as round dots
of radius `stroke_width / 100` frame units (`point_radius`).

## Usage

``` r
OpenGLPMobject(stroke_width = 2, color = PURE_YELLOW, ...)

OpenGLPGroup(...)

OpenGLPMPoint(location = ORIGIN, stroke_width = 4, ...)

DotCloud(color = PURE_YELLOW, stroke_width = 2, radius = 2, density = 10, ...)

TrueDot(center = ORIGIN, stroke_width = 2, ...)
```

## Arguments

- stroke_width:

  Dot diameter in hundredths of a frame unit.

- color:

  Color of the points.

- ...:

  Further arguments passed to
  [`PMobject()`](https://adamrsophie.github.io/manimR/reference/point_cloud.md),
  or point clouds for `OpenGLPGroup()`.

- location, center:

  Position of the point.

- radius:

  Radius of the disk a `DotCloud` fills.

- density:

  Rings and dots per frame unit.

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.

## Details

- `OpenGLPMobject()` is an empty cloud; add points with `$add_points()`.
  As upstream, its color array starts with one row holding the mobject's
  color, and `$add_points()` appends one row per point.

- `OpenGLPGroup()` groups OpenGL point clouds.

- `OpenGLPMPoint()` is a single point at `location`.

- `DotCloud()` fills a disk of the given `radius` with concentric rings
  of dots spaced `1 / density` apart. `$make_3d()` sets the gloss and
  shadow that upstream's shader lights the dots with and turns on the
  depth test; the OpenGL renderer uses them, the Cairo renderer does
  not.

- `TrueDot()` is a `DotCloud`. Note that upstream overwrites its
  `center` and radius in `DotCloud`'s initializer, so a `TrueDot` is the
  default cloud of radius 2 at the origin; manimR keeps that behavior.

## Examples

``` r
cloud <- DotCloud(radius = 1, density = 8)
nrow(cloud$points)
#> [1] 216
```
