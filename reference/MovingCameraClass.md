# MovingCamera

A camera that follows and matches the size and position of its `frame`,
a rectangle mobject. Move, scale or animate the frame to pan and zoom:
`self$play(self$camera$frame$animate$scale(0.5)$move_to(dot))`.

## Usage

``` r
MovingCamera(
  frame = NULL,
  fixed_dimension = 0,
  default_frame_stroke_color = WHITE,
  default_frame_stroke_width = 0,
  ...
)
```

## Arguments

- frame:

  Mobject defining the visible region; by default a rectangle the size
  of the camera frame.

- fixed_dimension:

  Kept for compatibility with Manim.

- default_frame_stroke_color, default_frame_stroke_width:

  Style of the default frame, which is invisible by default.

- ...:

  Passed to
  [CameraClass](https://adamrsophie.github.io/manimR/reference/CameraClass.md).

## Value

A camera: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.
