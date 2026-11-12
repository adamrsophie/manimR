# VMobject

Vectorized mobject: a path of cubic Bezier curves with fill and stroke
styling. Points come in groups of four per curve (anchor, handle,
handle, anchor).

## Usage

``` r
VMobject(
  color = "#FFFFFF",
  fill_color = NULL,
  fill_opacity = 0,
  stroke_color = NULL,
  stroke_opacity = 1,
  stroke_width = DEFAULT_STROKE_WIDTH,
  background_stroke_color = "#000000",
  background_stroke_opacity = 1,
  background_stroke_width = 0,
  sheen_factor = 0,
  sheen_direction = UL,
  joint_type = "auto",
  cap_style = "auto",
  close_new_points = FALSE,
  make_smooth_after_applying_functions = FALSE,
  shade_in_3d = FALSE,
  ...
)
```

## Arguments

- color:

  Color used for fill and stroke when they are not given.

- fill_color, fill_opacity:

  Fill color and opacity.

- stroke_color, stroke_opacity, stroke_width:

  Stroke color, opacity and width.

- background_stroke_color, background_stroke_opacity,
  background_stroke_width:

  Style of a stroke drawn behind the fill.

- sheen_factor, sheen_direction:

  Strength and direction of a lighter gradient across the fill.

- joint_type:

  How stroke segments are joined: `"auto"`, `"round"`, `"bevel"` or
  `"miter"`.

- cap_style:

  Shape of the stroke ends: `"auto"`, `"round"`, `"butt"` or `"square"`.

- close_new_points:

  Close the path when new points are added.

- make_smooth_after_applying_functions:

  Smooth the curve after `apply_function()`.

- shade_in_3d:

  Shade the mobject by its orientation in a 3D scene.

- ...:

  Passed to
  [MobjectClass](https://adamrsophie.github.io/manimR/reference/MobjectClass.md),
  for example `z_index` or `name`.
