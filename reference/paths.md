# Path functions

Path functions control the trajectory points follow during a
`Transform`.

## Usage

``` r
straight_path()

path_along_arc(arc_angle, axis = OUT)

path_along_circles(arc_angle, circles_centers, axis = OUT)

clockwise_path()

counterclockwise_path()

spiral_path(angle, axis = OUT)
```

## Arguments

- arc_angle, angle:

  Angle swept along the path.

- axis:

  Rotation axis.

- circles_centers:

  Centers of the circles points travel along.

## Value

A function `f(start_points, end_points, alpha)`.
