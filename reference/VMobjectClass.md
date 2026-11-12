# VMobject

Vectorized mobject: a path of cubic Bezier curves with fill and stroke
styling. Points come in groups of four per curve (anchor, handle,
handle, anchor).

## Usage

``` r
VMobject(
  fill_color = NULL,
  fill_opacity = 0,
  stroke_color = NULL,
  stroke_opacity = 1,
  stroke_width = DEFAULT_STROKE_WIDTH,
  background_stroke_color = "#000000",
  background_stroke_opacity = 1,
  background_stroke_width = 0,
  sheen_factor = 0,
  joint_type = "auto",
  sheen_direction = UL,
  close_new_points = FALSE,
  pre_function_handle_to_anchor_scale_factor = 0.01,
  make_smooth_after_applying_functions = FALSE,
  background_image = NULL,
  shade_in_3d = FALSE,
  tolerance_for_point_equality = 1e-06,
  n_points_per_cubic_curve = 4,
  cap_style = "auto",
  color = "#FFFFFF",
  ...
)
```

## Arguments

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

- close_new_points:

  Close the path when new points are added.

- pre_function_handle_to_anchor_scale_factor:

  How far the handles are pulled toward their anchors before
  `apply_function()`.

- make_smooth_after_applying_functions:

  Smooth the curve after `apply_function()`.

- background_image:

  An image whose colors fill the mobject (see
  `$color_using_background_image()`).

- shade_in_3d:

  Shade the mobject by its orientation in a 3D scene.

- tolerance_for_point_equality:

  Distance below which two points count as the same.

- n_points_per_cubic_curve:

  Points per Bezier curve, 4.

- cap_style:

  Shape of the stroke ends: `"auto"`, `"round"`, `"butt"` or `"square"`.

- color:

  Color used for fill and stroke when they are not given.

- ...:

  Passed to
  [MobjectClass](https://adamrsophie.github.io/manimR/reference/MobjectClass.md),
  for example `z_index` or `name`.

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.
