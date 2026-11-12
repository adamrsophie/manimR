# Add

Adds mobjects to the scene instantly, useful inside
[`Succession()`](https://adamrsophie.github.io/manimR/reference/composition.md).

## Usage

``` r
Add(..., run_time = 0, use_override = TRUE)
```

## Arguments

- ...:

  Mobjects, then named arguments passed to
  [`Animation()`](https://adamrsophie.github.io/manimR/reference/AnimationClass.md).

- run_time:

  Duration in seconds; zero adds the mobjects instantly.

- use_override:

  `FALSE` ignores an override of `Add` set with
  [`override_animation()`](https://adamrsophie.github.io/manimR/reference/override_animation.md)
  on the first mobject's class.

## Value

An `Add` animation, an R6 object to pass to a scene's `play()`.
