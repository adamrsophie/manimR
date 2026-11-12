# Render one frame of a scene

`scene_frame()` renders the frame shown at time `t` (in seconds) of a
scene, without writing a video: plays that end before `t` step through
their frames without drawing them (so updaters reach the state a render
gives), and the play running at `t` is drawn at its last frame at or
before `t`, the frame a video shows then. It is a quick way to look at
any point of a scene while writing it;
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) shows the
frame. `t = Inf` gives the last frame.

## Usage

``` r
scene_frame(scene, t = Inf, quality = "l", ...)

expect_snapshot_frame(scene, t = Inf, name = "frame", quality = "l", ...)
```

## Arguments

- scene:

  A [Scene](https://adamrsophie.github.io/manimR/reference/Scene.md)
  class, a construct function or a scene object, as
  [`render()`](https://adamrsophie.github.io/manimR/reference/render.md)
  takes.

- t:

  Time in seconds.

- quality:

  Quality flag or preset name.

- ...:

  Further
  [`manim_config()`](https://adamrsophie.github.io/manimR/reference/manim_config.md)
  settings.

- name:

  Snapshot name for `expect_snapshot_frame()`.

## Value

`scene_frame()` returns a `manim_frame_image`, a native raster.

## Details

`expect_snapshot_frame()` is a testthat expectation for packages that
make scenes: it saves the frame as a PNG snapshot (see
[`testthat::expect_snapshot_file()`](https://testthat.r-lib.org/reference/expect_snapshot_file.html))
and fails when it changes.

## Examples

``` r
if (FALSE) { # \dontrun{
f <- scene_frame(function(self) self$play(Create(Circle()), run_time = 2), t = 1)
plot(f)
} # }
```
