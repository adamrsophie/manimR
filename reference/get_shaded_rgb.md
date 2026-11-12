# Shade a color by its orientation to a light

Adds light (or shadow) to `rgb` for a surface at `point` facing
`unit_normal_vect`, depending on whether it faces `light_source`. The
result is not clipped.

## Usage

``` r
get_shaded_rgb(rgb, point, unit_normal_vect, light_source)
```

## Arguments

- rgb:

  Numeric RGB in `[0, 1]`.

- point, unit_normal_vect, light_source:

  Length 3 vectors.

## Value

Numeric RGB.
