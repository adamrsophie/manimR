# Updaters that follow ChangeSpeed

Adds an updater to `mobject` that follows the speed and rate function of
any
[`ChangeSpeed()`](https://adamrsophie.github.io/manimR/reference/ChangeSpeedClass.md)
animation playing with `affects_speed_updaters = TRUE`. Updaters added
with the usual `mob$add_updater()` ignore speed changes. This is the R
form of upstream's `ChangeSpeed.add_updater()`.

## Usage

``` r
change_speed_add_updater(
  mobject,
  update_function,
  index = NULL,
  call_updater = FALSE
)
```

## Arguments

- mobject:

  The mobject to which the updater is attached.

- update_function:

  The updater, `function(m)` or `function(m, dt)`.

- index:

  Position in the mobject's updater list.

- call_updater:

  Call the updater once when attaching it.

## Value

The mobject, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
SpeedModifierUpdaterExample <- manim_scene(function(self) {
  a <- Dot()$shift(LEFT * 4)
  self$add(a)
  change_speed_add_updater(a, function(x, dt) x$shift(RIGHT * 4 * dt))
  self$play(ChangeSpeed(Wait(2), speedinfo = c("0.4" = 1, "0.5" = 0.2, "0.8" = 0.2, "1" = 1),
                        affects_speed_updaters = TRUE))
})
} # }
```
