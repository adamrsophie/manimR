# Broadcast

Emits expanding copies of a mobject from a focal point.

## Usage

``` r
Broadcast(
  mobject,
  focal_point = ORIGIN,
  n_mobs = 5,
  initial_opacity = 1,
  final_opacity = 0,
  initial_width = 0,
  remover = TRUE,
  lag_ratio = 0.2,
  run_time = 3,
  ...
)
```

## Arguments

- mobject:

  Mobject to broadcast.

- focal_point:

  Point the copies emanate from.

- n_mobs:

  Number of copies.

- initial_opacity, final_opacity:

  Opacities.

- initial_width:

  Starting width.

- remover:

  Remove the copies when done.

- lag_ratio:

  Lag between copies.

- run_time:

  Duration.

- ...:

  Passed to
  [`LaggedStart()`](https://adamrsophie.github.io/manimR/reference/composition.md).

## Value

A `Broadcast` animation, an R6 object to pass to a scene's `play()`.
