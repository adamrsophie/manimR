# Movement animations

Movement animations

## Usage

``` r
Homotopy(homotopy, mobject, run_time = 3, apply_function_kwargs = NULL, ...)

SmoothedVectorizedHomotopy(
  homotopy,
  mobject,
  run_time = 3,
  apply_function_kwargs = NULL,
  ...
)

ComplexHomotopy(complex_homotopy, mobject, ...)

PhaseFlow(
  fn,
  mobject,
  virtual_time = 1,
  suspend_mobject_updating = FALSE,
  rate_func = linear,
  ...
)

MoveAlongPath(mobject, path, suspend_mobject_updating = FALSE, ...)
```

## Arguments

- homotopy:

  A function `(x, y, z, t)` returning a point.

- mobject:

  The mobject to move.

- run_time:

  Duration.

- apply_function_kwargs:

  Extra arguments to `apply_function()`.

- ...:

  Passed to
  [`Animation()`](https://adamrsophie.github.io/manimR/reference/AnimationClass.md).

- complex_homotopy:

  A function `(z, t)` of a complex number.

- fn:

  A vector field function of a point (for `PhaseFlow()`).

- virtual_time:

  Virtual time span of the flow.

- suspend_mobject_updating:

  Pause updaters while running.

- rate_func:

  Rate function.

- path:

  A VMobject path to move along.
