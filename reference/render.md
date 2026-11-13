# Render a scene

Renders a scene to a video or image file, like `manim render` does.

## Usage

``` r
render(
  scene,
  quality = NULL,
  format = NULL,
  output_file = NULL,
  save_last_frame = NULL,
  preview = NULL,
  transparent = NULL,
  module_name = NULL,
  scene_name = NULL,
  ...
)
```

## Arguments

- scene:

  A [Scene](https://adamrsophie.github.io/manimR/reference/Scene.md)
  subclass (R6 generator), a scene instance, or a function of one
  argument `self` used as `construct()`. A scene instance keeps the
  camera it was created with, so quality and other camera settings only
  apply when `scene` is a class or a function.

- quality:

  One of `"l"`, `"m"`, `"h"`, `"p"`, `"k"` or a preset name of
  [QUALITIES](https://adamrsophie.github.io/manimR/reference/QUALITIES.md).
  Defaults to the current
  [`manim_config()`](https://adamrsophie.github.io/manimR/reference/manim_config.md)
  quality.

- format:

  The artifact to write: `"auto"` (the default: MP4, or MOV when
  transparent; a scene without animations is saved as its last frame),
  `"mp4"`, `"mov"`, `"webm"`, `"gif"`, `"png"` (only the last frame),
  `"png-sequence"` (every frame) or `"none"`.

- output_file:

  Name of the artifact. A relative name is placed in the video directory
  (or the images directory for PNG output), as upstream's `-o`; an
  absolute path is used as it is. Defaults to the scene name in
  `<media_dir>/videos/<module>/<quality>/` (videos) or
  `<media_dir>/images/<module>/` (images). The media folder is in the
  session's temporary directory unless `media_dir` is set, for example
  `manim_config(media_dir = "media")` to keep the output in the working
  directory.

- save_last_frame:

  `TRUE` is short for `format = "png"`.

- preview:

  Open the result when done (the RStudio Viewer when available).
  Defaults to the `preview` setting.

- transparent:

  Render with a transparent background.

- module_name:

  Folder name under `<media_dir>/videos/` and `<media_dir>/images/`;
  [`render_file()`](https://adamrsophie.github.io/manimR/reference/render_file.md)
  uses the script name. Defaults to `"manimR"`.

- scene_name:

  Name used for output files; defaults to the scene class name.

- ...:

  Further
  [`manim_config()`](https://adamrsophie.github.io/manimR/reference/manim_config.md)
  settings for this render, such as `background_color`, `frame_rate`,
  `save_sections` or `dry_run`.

## Value

The path of the artifact, invisibly, with class `manim_output`; `NULL`
when nothing is written (`format = "none"` or `dry_run`).

## Examples

``` r
# The last frame as a PNG file in the session's temporary directory.
render(function(self) self$play(Create(Circle())), quality = "l", format = "png",
       media_dir = tempdir())
#> INFO File ready at '/tmp/Rtmp11IoSN/images/manimR/Scene_manimR_v0.1.0.png'
#> INFO Rendered Scene
#> Played 1 animations
if (FALSE) { # \dontrun{
# A video in the media folder (by default in the session's temporary
# directory); this needs ffmpeg.
render(function(self) self$play(Create(Circle())), quality = "l")
} # }
```
