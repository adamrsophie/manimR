# MultiCamera

A
[MovingCameraClass](https://adamrsophie.github.io/manimR/reference/MovingCameraClass.md)
that also draws the views of other cameras into
[`ImageMobjectFromCamera()`](https://adamrsophie.github.io/manimR/reference/image_mobject.md)
mobjects. A view in a rectangular display (rotated or mirrored too) is
drawn as vector graphics clipped to the display, so it stays sharp; a
sheared or perspective display gets the sub camera's pixels mapped
through its corners, as upstream draws every display.

## Usage

``` r
MultiCamera(
  image_mobjects_from_cameras = NULL,
  allow_cameras_to_capture_their_own_display = FALSE,
  ...
)
```

## Arguments

- image_mobjects_from_cameras:

  List of
  [`ImageMobjectFromCamera()`](https://adamrsophie.github.io/manimR/reference/image_mobject.md)
  mobjects whose cameras' views are drawn.

- allow_cameras_to_capture_their_own_display:

  Let each camera's view include its own display mobject.

- ...:

  Passed to
  [MovingCameraClass](https://adamrsophie.github.io/manimR/reference/MovingCameraClass.md).

## Value

A camera: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.
