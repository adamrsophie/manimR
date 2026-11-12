# ChangeSpeed

Modifies the speed of an animation. `speedinfo` maps nodes (proportions
of the animation's `run_time`) to speed factors; between two nodes the
speed changes smoothly. The run time of the wrapped animation is
stretched accordingly. An
[`AnimationGroup()`](https://adamrsophie.github.io/manimR/reference/composition.md)
with any `lag_ratio` counts as one animation.

Updaters added with
[`change_speed_add_updater()`](https://adamrsophie.github.io/manimR/reference/change_speed_add_updater.md)
follow the modified speed while a `ChangeSpeed` with
`affects_speed_updaters = TRUE` plays.

## Usage

``` r
ChangeSpeed(
  anim,
  speedinfo,
  rate_func = NULL,
  affects_speed_updaters = TRUE,
  ...
)
```

## Arguments

- anim:

  The animation (or `mob$animate` builder) to modify.

- speedinfo:

  Named numeric vector or list: names are the nodes in `[0, 1]`, values
  the speed factors, for example
  `c("0.3" = 1, "0.4" = 0.1, "0.6" = 0.1, "1" = 1)`. A missing node 0
  gets speed 1 and a missing node 1 gets the speed of the last node.

- rate_func:

  Overrides the rate function of `anim`; it is applied before changing
  the speed.

- affects_speed_updaters:

  Whether updaters added with
  [`change_speed_add_updater()`](https://adamrsophie.github.io/manimR/reference/change_speed_add_updater.md)
  follow the speed change. Only one such animation can play at a time.

- ...:

  Passed to
  [`Animation()`](https://adamrsophie.github.io/manimR/reference/AnimationClass.md).

## Value

An animation: an R6 object of the class named by the function called, to
pass to a scene's `play()`. The objects whose names end in `Class` are
the R6 class generators that these functions call.

## Examples

``` r
SpeedModifierExample <- manim_scene(function(self) {
  a <- Dot()$shift(LEFT * 4)
  b <- Dot()$shift(RIGHT * 4)
  self$add(a, b)
  self$play(ChangeSpeed(
    AnimationGroup(a$animate(run_time = 1)$shift(RIGHT * 8),
                   b$animate(run_time = 1)$shift(LEFT * 8)),
    speedinfo = c("0.3" = 1, "0.4" = 0.1, "0.6" = 0.1, "1" = 1),
    rate_func = linear))
})
```
