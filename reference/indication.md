# Indication animations

Animations that draw attention to a mobject or point.

## Usage

``` r
FocusOn(focus_point, opacity = 0.2, color = GREY, run_time = 2, ...)

Indicate(
  mobject,
  scale_factor = 1.2,
  color = PURE_YELLOW,
  rate_func = there_and_back,
  ...
)

ShowPassingFlash(mobject, time_width = 0.1, ...)

Flash(
  point,
  line_length = 0.2,
  num_lines = 12,
  flash_radius = 0.1,
  line_stroke_width = 3,
  color = PURE_YELLOW,
  time_width = 1,
  run_time = 1,
  ...
)

ShowPassingFlashWithThinningStrokeWidth(
  vmobject,
  n_segments = 10,
  time_width = 0.1,
  remover = TRUE,
  ...
)

ApplyWave(
  mobject,
  direction = UP,
  amplitude = 0.2,
  wave_func = smooth_rate,
  time_width = 1,
  ripples = 1,
  run_time = 2,
  ...
)

Wiggle(
  mobject,
  scale_value = 1.1,
  rotation_angle = 0.01 * TAU,
  n_wiggles = 6,
  scale_about_point = NULL,
  rotate_about_point = NULL,
  run_time = 2,
  ...
)

Circumscribe(
  mobject,
  shape = c("rectangle", "circle"),
  fade_in = FALSE,
  fade_out = FALSE,
  time_width = 0.3,
  buff = SMALL_BUFF,
  color = PURE_YELLOW,
  run_time = 1,
  stroke_width = DEFAULT_STROKE_WIDTH,
  ...
)

Blink(
  mobject,
  time_on = 0.5,
  time_off = 0.5,
  blinks = 1,
  hide_at_end = FALSE,
  ...
)
```

## Arguments

- focus_point, point:

  Point or mobject to focus or flash on.

- opacity:

  Opacity of the focusing spotlight.

- color:

  Color.

- run_time:

  Duration.

- ...:

  Passed on to the underlying animation.

- mobject, vmobject:

  The mobject to indicate.

- scale_factor:

  Scale at the peak.

- rate_func:

  Rate function.

- time_width:

  Width of the traveling flash, as a fraction of the path.

- line_length, num_lines, flash_radius, line_stroke_width:

  Flash geometry.

- n_segments:

  Number of strokes for the thinning flash.

- remover:

  Remove when done.

- direction, amplitude, wave_func, ripples:

  Wave settings.

- scale_value, rotation_angle, n_wiggles, scale_about_point,
  rotate_about_point:

  Wiggle settings.

- shape:

  `"rectangle"` or `"circle"` for `Circumscribe()`.

- fade_in, fade_out:

  Fade the frame in or out.

- buff:

  Buffer around the mobject.

- stroke_width:

  Stroke width.

- time_on, time_off, blinks, hide_at_end:

  Blink settings.

## Value

An animation: an R6 object of the class named by the function called, to
pass to a scene's `play()`. The objects whose names end in `Class` are
the R6 class generators that these functions call.
