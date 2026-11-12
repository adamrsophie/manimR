# Updater helpers

- `always_redraw(func)` returns `func()` and rebuilds it every frame.

- `always(mob$method, ...)` calls the method with fixed arguments every
  frame.

- `f_always(mob$method, ...)` calls it with arguments produced by the
  given functions.

- `always_shift()` and `always_rotate()` move a mobject at a constant
  rate.

- `turn_animation_into_updater()` and `cycle_animation()` run an
  animation as an updater.

## Usage

``` r
always_redraw(func)

always(method, ...)

f_always(method, ...)

always_shift(mobject, direction = RIGHT, rate = 0.1)

always_rotate(mobject, rate = 20 * DEGREES, ...)

turn_animation_into_updater(animation, cycle = FALSE, delay = 0)

cycle_animation(animation, ...)
```

## Arguments

- func:

  Function with no arguments returning a mobject.

- method:

  A mobject method such as `dot$move_to`.

- ...:

  Arguments (or argument generators for `f_always()`).

- mobject:

  A mobject.

- direction:

  Direction of motion.

- rate:

  Speed in units (or radians) per second.

- animation:

  An animation.

- cycle:

  Restart the animation when it ends.

- delay:

  Seconds to wait before starting.

## Value

The mobject.
