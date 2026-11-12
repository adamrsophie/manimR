# Transform animations

`Transform(a, b)` morphs `a` into the shape and style of `b`, keeping
`a` in the scene. `ReplacementTransform()` swaps `a` for `b` in the
scene when done. See Manim's documentation for the remaining variants.

## Usage

``` r
Transform(
  mobject,
  target_mobject = NULL,
  path_func = NULL,
  path_arc = 0,
  path_arc_axis = OUT,
  path_arc_centers = NULL,
  replace_mobject_with_target_in_scene = FALSE,
  ...
)

ReplacementTransform(mobject, target_mobject, ...)

TransformFromCopy(mobject, target_mobject, ...)

ClockwiseTransform(mobject, target_mobject, path_arc = -pi, ...)

CounterclockwiseTransform(mobject, target_mobject, path_arc = pi, ...)

MoveToTarget(mobject, ...)

ApplyMethod(method, ..., method_mobject = NULL)

ApplyPointwiseFunction(
  fn,
  mobject,
  run_time = DEFAULT_POINTWISE_FUNCTION_RUN_TIME,
  ...
)

ApplyPointwiseFunctionToCenter(fn, mobject, ...)

FadeToColor(mobject, color, ...)

ScaleInPlace(mobject, scale_factor, ...)

ShrinkToCenter(mobject, ...)

Restore(mobject, ...)

ApplyFunction(fn, mobject, ...)

ApplyMatrix(matrix, mobject, about_point = ORIGIN, ...)

ApplyComplexFunction(fn, mobject, ...)

CyclicReplace(..., path_arc = 90 * DEGREES)

Swap(...)

FadeTransform(mobject, target_mobject, stretch = TRUE, dim_to_match = 2, ...)

FadeTransformPieces(
  mobject,
  target_mobject,
  stretch = TRUE,
  dim_to_match = 2,
  ...
)

TransformAnimations(
  start_anim,
  end_anim,
  rate_func = squish_rate_func(smooth_rate),
  run_time = NULL,
  ...
)
```

## Arguments

- mobject:

  The mobject to transform.

- target_mobject:

  The target.

- path_func:

  A [path
  function](https://adamrsophie.github.io/manimR/reference/paths.md).

- path_arc:

  Angle of the arc points travel along.

- path_arc_axis:

  Axis of that arc.

- path_arc_centers:

  Centers of the arcs.

- replace_mobject_with_target_in_scene:

  Replace `mobject` by the target at the end.

- ...:

  Passed to
  [`Animation()`](https://adamrsophie.github.io/manimR/reference/AnimationClass.md).

- method:

  A mobject method such as `mob$shift`, followed by its arguments.

- method_mobject:

  Mobject to call `method` on when `method` is given as a method name
  rather than a bound method.

- fn:

  A function of a point.

- run_time:

  Duration in seconds; for `TransformAnimations()` the default is the
  longer of the two animations.

- color:

  A color.

- scale_factor:

  Scale factor.

- matrix:

  A 2 x 2 or 3 x 3 matrix.

- about_point:

  Fixed point of the transformation.

- stretch:

  Stretch the ghosts to match.

- dim_to_match:

  Dimension (1 = x, 2 = y) to match when not stretching.

- start_anim, end_anim:

  Animations to blend between.

- rate_func:

  Rate function.
