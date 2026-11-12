# MultiCamera

A
[MovingCameraClass](https://adamrsophie.github.io/manimR/reference/MovingCameraClass.md)
that also draws the views of other cameras into
[`ImageMobjectFromCamera()`](https://adamrsophie.github.io/manimR/reference/image_mobject.md)
mobjects. Each view is drawn as vector graphics clipped to the display
rectangle, so it stays sharp.

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
