# Composing animations

`AnimationGroup()` plays animations together, offset by `lag_ratio`
times each run time. `Succession()` plays them one after another.
`LaggedStart()` uses a small default lag. `LaggedStartMap()` applies an
animation constructor to every submobject.

## Usage

``` r
AnimationGroup(
  ...,
  group = NULL,
  run_time = NULL,
  rate_func = linear,
  lag_ratio = 0
)

Succession(..., lag_ratio = 1)

LaggedStart(..., lag_ratio = DEFAULT_LAGGED_START_LAG_RATIO)

LaggedStartMap(
  animation_class,
  mobject,
  arg_creator = NULL,
  run_time = 2,
  lag_ratio = DEFAULT_LAGGED_START_LAG_RATIO,
  ...
)
```

## Arguments

- ...:

  Animations (or lists of them), then named arguments.

- group:

  Mobject group used as the animation's mobject.

- run_time:

  Total run time; defaults to the length of the schedule.

- rate_func:

  Rate function applied to the whole group.

- lag_ratio:

  Offset between consecutive animations, as a fraction of their run
  time.

- animation_class:

  An animation constructor such as `FadeIn`.

- mobject:

  Mobject whose submobjects are animated.

- arg_creator:

  Function mapping a submobject to a list of arguments.
