# Creation animations

Animations that draw, write, or reveal mobjects.

## Usage

``` r
Create(mobject, ...)

Uncreate(mobject, reverse_rate_function = TRUE, remover = TRUE, ...)

DrawBorderThenFill(
  vmobject,
  run_time = 2,
  rate_func = double_smooth,
  stroke_width = 2,
  stroke_color = NULL,
  introducer = TRUE,
  ...
)

Write(
  vmobject,
  rate_func = linear,
  reverse = FALSE,
  run_time = NULL,
  lag_ratio = NULL,
  remover = NULL,
  ...
)

Unwrite(
  vmobject,
  rate_func = linear,
  reverse = TRUE,
  run_time = NULL,
  lag_ratio = NULL,
  ...
)

SpiralIn(shapes, scale_factor = 8, fade_in_fraction = 0.3, ...)

ShowIncreasingSubsets(
  group,
  suspend_mobject_updating = FALSE,
  int_func = floor,
  reverse_rate_function = FALSE,
  ...
)

AddTextLetterByLetter(
  text,
  suspend_mobject_updating = FALSE,
  int_func = ceiling,
  rate_func = linear,
  time_per_char = 0.1,
  run_time = NULL,
  reverse_rate_function = FALSE,
  introducer = TRUE,
  ...
)

RemoveTextLetterByLetter(
  text,
  reverse_rate_function = TRUE,
  introducer = FALSE,
  remover = TRUE,
  ...
)

ShowSubmobjectsOneByOne(group, int_func = ceiling, ...)

AddTextWordByWord(text_mobject, run_time = NULL, time_per_char = 0.06, ...)

TypeWithCursor(
  text,
  cursor,
  buff = 0.1,
  keep_cursor_y = TRUE,
  leave_cursor_on = TRUE,
  time_per_char = 0.1,
  reverse_rate_function = FALSE,
  introducer = TRUE,
  ...
)

UntypeWithCursor(
  text,
  cursor = NULL,
  time_per_char = 0.1,
  reverse_rate_function = TRUE,
  introducer = FALSE,
  remover = TRUE,
  ...
)

ShowPartial(mobject, ...)
```

## Arguments

- mobject, vmobject, text, group:

  The mobject to animate.

- ...:

  Passed to
  [`Animation()`](https://adamrsophie.github.io/manimR/reference/AnimationClass.md).

- reverse_rate_function:

  Run backwards.

- remover:

  Remove the mobject when done.

- run_time:

  Duration in seconds; for `Write()` and `Unwrite()` the default depends
  on the number of submobjects.

- rate_func:

  Rate function.

- stroke_width, stroke_color:

  Width and color of the outline drawn before filling; a `NULL` color
  uses each submobject's own color.

- introducer:

  Add the mobject to the scene at the start.

- reverse:

  Write in reverse order.

- lag_ratio:

  Stagger between submobjects; for `Write()` and `Unwrite()` the default
  depends on the number of submobjects.

- shapes:

  A group of shapes.

- scale_factor:

  How far out the shapes start.

- fade_in_fraction:

  Fraction of the run time spent fading in.

- suspend_mobject_updating:

  Pause updaters while running.

- int_func:

  Rounding function for the number of visible submobjects.

- time_per_char:

  Seconds per character.

- text_mobject:

  A text mobject whose submobjects are words.

- cursor:

  A mobject used as the cursor.

- buff:

  Gap between text and cursor.

- keep_cursor_y:

  Keep the cursor's y coordinate.

- leave_cursor_on:

  Keep the cursor visible at the end.
