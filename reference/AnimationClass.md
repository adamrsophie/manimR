# Animation

Base class for animations. An animation changes its `mobject` over
`run_time` seconds, mapping time through `rate_func`. `lag_ratio`
staggers submobjects: 0 animates them together, 1 one after another.

## Usage

``` r
Animation(
  mobject = NULL,
  lag_ratio = DEFAULT_ANIMATION_LAG_RATIO,
  run_time = DEFAULT_ANIMATION_RUN_TIME,
  rate_func = smooth_rate,
  reverse_rate_function = FALSE,
  name = NULL,
  remover = FALSE,
  suspend_mobject_updating = TRUE,
  introducer = FALSE,
  on_finish = NULL,
  ...
)
```

## Arguments

- mobject:

  The mobject to animate.

- lag_ratio:

  Stagger between submobjects.

- run_time:

  Duration in seconds.

- rate_func:

  A [rate
  function](https://adamrsophie.github.io/manimR/reference/rate_funcs.md).

- reverse_rate_function:

  Run the rate function backwards.

- name:

  Name used in progress messages.

- remover:

  Remove the mobject from the scene when done.

- suspend_mobject_updating:

  Pause the mobject's updaters while running.

- introducer:

  Add the mobject to the scene when the animation starts.

- on_finish:

  Optional function called with the scene when the animation is cleaned
  up from it.

- ...:

  Ignored.
