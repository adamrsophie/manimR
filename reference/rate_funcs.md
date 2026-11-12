# Rate functions

Functions that map animation progress `t` in `[0, 1]` to an eased value.
Pass one as `rate_func` to any animation or to `Scene$play()`. Manim's
`smooth` is called `smooth_rate` so it does not mask
[`stats::smooth()`](https://rdrr.io/r/stats/smooth.html).

## Usage

``` r
linear(t, ...)

smooth_rate(t, ...)

smoothstep(t, ...)

smootherstep(t, ...)

smoothererstep(t, ...)

rush_into(t, ...)

rush_from(t, ...)

slow_into(t, ...)

double_smooth(t, ...)

there_and_back(t, ...)

there_and_back_with_pause(t, ...)

running_start(t, ...)

not_quite_there(func = smooth_rate, proportion = 0.7)

wiggle(t, ...)

squish_rate_func(func, a = 0.4, b = 0.6)

lingering(t, ...)

exponential_decay(t, ...)

ease_in_sine(t, ...)

ease_out_sine(t, ...)

ease_in_out_sine(t, ...)

ease_in_quad(t, ...)

ease_out_quad(t, ...)

ease_in_out_quad(t, ...)

ease_in_cubic(t, ...)

ease_out_cubic(t, ...)

ease_in_out_cubic(t, ...)

ease_in_quart(t, ...)

ease_out_quart(t, ...)

ease_in_out_quart(t, ...)

ease_in_quint(t, ...)

ease_out_quint(t, ...)

ease_in_out_quint(t, ...)

ease_in_expo(t, ...)

ease_out_expo(t, ...)

ease_in_out_expo(t, ...)

ease_in_circ(t, ...)

ease_out_circ(t, ...)

ease_in_out_circ(t, ...)

ease_in_back(t, ...)

ease_out_back(t, ...)

ease_in_out_back(t, ...)

ease_in_elastic(t, ...)

ease_out_elastic(t, ...)

ease_in_out_elastic(t, ...)

ease_out_bounce(t, ...)

ease_in_bounce(t, ...)

ease_in_out_bounce(t, ...)
```

## Arguments

- t:

  Progress between 0 and 1.

- ...:

  Optional shape parameters of some rate functions: `inflection`, the
  steepness of the sigmoid (`smooth_rate()`, `rush_into()`,
  `rush_from()`, `there_and_back()`; default 10); `pause_ratio`, the
  fraction of the time spent paused at the peak
  (`there_and_back_with_pause()`; default 1/3); `pull_factor`, how far
  to pull back before starting (`running_start()`; default -0.5);
  `wiggles`, the number of wiggles (`wiggle()`; default 2); and
  `half_life`, the half life of the decay (`exponential_decay()`;
  default 0.1). Other rate functions take none.

- func:

  A rate function.

- proportion:

  Final proportion reached.

- a, b:

  Interval to squish the rate function into.

## Value

A rate function returns a number: the progress of an animation at the
proportion `t` of its run time. The functions that take a rate function
return a new rate function.

## Examples

``` r
smooth_rate(0.5)
#> [1] 0.5
there_and_back(0.25)
#> [1] 0.5
```
