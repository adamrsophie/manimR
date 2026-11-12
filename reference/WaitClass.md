# Wait

An animation that does nothing for `run_time` seconds.

## Usage

``` r
Wait(
  run_time = 1,
  stop_condition = NULL,
  frozen_frame = NULL,
  rate_func = linear,
  ...
)
```

## Arguments

- run_time:

  Duration.

- stop_condition:

  Function returning `TRUE` to stop early.

- frozen_frame:

  Whether the frame is static.

- rate_func:

  Rate function.

- ...:

  Passed to
  [`Animation()`](https://adamrsophie.github.io/manimR/reference/AnimationClass.md).
