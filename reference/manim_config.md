# Get or set the manimR configuration

Called with no arguments, returns the current configuration as a list.
Named arguments update it; an unknown name is an error, as upstream's
`config`. The
[config](https://adamrsophie.github.io/manimR/reference/config.md)
object gives the same settings with upstream's `config$name` syntax,
[`with_manim_config()`](https://adamrsophie.github.io/manimR/reference/with_manim_config.md)
and
[`tempconfig()`](https://adamrsophie.github.io/manimR/reference/config.md)
change them for a block of code, and
[`digest_config_file()`](https://adamrsophie.github.io/manimR/reference/digest_config_file.md)
reads them from a `manim.cfg` file.

## Usage

``` r
manim_config(...)
```

## Arguments

- ...:

  Named settings.

## Value

The configuration list (including the derived `frame_width`,
`frame_x_radius`, `frame_y_radius`, `transparent` and
`save_last_frame`), invisibly when setting.

## Details

The settings, with upstream's names and defaults:

- Frame: `quality` (a flag `"l"` 854x480 at 15 fps, `"m"` 1280x720 at
  30, `"h"` 1920x1080 at 60, `"p"` 2560x1440 at 60, `"k"` 3840x2160 at
  60, or a preset name of
  [QUALITIES](https://adamrsophie.github.io/manimR/reference/QUALITIES.md)),
  `pixel_width`, `pixel_height`, `frame_size` (both at once),
  `frame_rate`, `frame_height` (8), `frame_width` (derived from the
  aspect ratio unless set), `frame_x_radius`, `frame_y_radius`,
  `background_color`, `background_opacity`, `transparent` (`TRUE` sets
  `background_opacity` to 0).

- Output: `format`, the artifact a render writes: `"auto"` (the default:
  MP4, or MOV when transparent; a scene without animations is saved as
  its last frame), `"mp4"`, `"mov"`, `"webm"`, `"gif"`, `"png"` (only
  the last frame), `"png-sequence"` (every frame) or `"none"`.
  `save_last_frame = TRUE` is short for `format = "png"`. `dry_run`
  renders without writing files, `save_sections` also writes one video
  per section, `zero_pad` (4) is the number of digits in PNG sequence
  file names, `output_file` names the artifact (relative to its
  directory below), `from_animation_number` and `upto_animation_number`
  (-1: all) select animations.

- Directories, with `{name}` placeholders resolved by
  [`get_dir()`](https://adamrsophie.github.io/manimR/reference/get_dir.md):
  `media_dir` (a folder `media` in the session's temporary directory;
  set it, for example to `"media"`, to keep the output;
  [`manim_cli()`](https://adamrsophie.github.io/manimR/reference/manim_cli.md)
  uses `"media"` in the working directory, as upstream), `video_dir`
  ("{media_dir}/videos/{module_name}/{quality}"), `images_dir`,
  `sections_dir`, `partial_movie_dir`, `tex_dir`, `text_dir`, `log_dir`,
  `assets_dir` (where sounds and images are looked up), `input_file`
  (the script being rendered; its name is the module name) and manimR's
  `module_name` for scenes rendered from R code ("manimR").

- Encoding: `video_codec`, `pixel_format` (both `"auto"`) and
  `video_encoder_options` (a named list of ffmpeg options such as
  `list(crf = "18")`) for the cached video segments;
  `max_inflight_encoders` and `encoder_queue_size` are validated but
  encoding runs in the R process, one segment at a time.

- Caching: `disable_caching`, `disable_caching_warning`,
  `max_files_cached` (100; -1 keeps all), and manimR's `flush_cache`.

- Presentation and logging: `preview` (open the result),
  `preview_command`, `show_in_file_browser`, `verbosity` ("INFO"),
  `progress_bar`, `log_to_file` (write a log per scene to `log_dir`),
  `media_loglevel`.

- LaTeX: `tex_template` (a
  [`TexTemplate()`](https://adamrsophie.github.io/manimR/reference/TexTemplateClass.md)),
  `tex_template_file`, `no_latex_cleanup` (keep .aux, .dvi and .log
  files in `tex_dir`).

- Other: `seed` (random seed of every scene), `renderer` (`"cairo"`, or
  `"opengl"` for
  [OpenGLRenderer()](https://adamrsophie.github.io/manimR/reference/opengl_renderer.md),
  upstream's OpenGL renderer drawn in software; scenes with their own
  camera class, such as
  [`ThreeDScene()`](https://adamrsophie.github.io/manimR/reference/ThreeDScene.md),
  keep the Cairo style renderer), `plugins`, `write_all`, `scene_names`,
  `notify_outdated_version`, and the OpenGL window settings
  `enable_gui`, `live_preview`, `gui_location`, `fullscreen`,
  `window_position`, `window_size`, `window_monitor`,
  `use_projection_fill_shaders`, `use_projection_stroke_shaders`,
  `enable_wireframe`, which have no effect on the Cairo style renderer
  (asking for a live preview is an error, as upstream), and the Jupyter
  settings `media_embed` and `media_width`.

- manimR only: `ffmpeg` and `typst` (paths of those programs) and
  `curve_tolerance`.

## Examples

``` r
old <- manim_config(quality = "l")
manim_config()$pixel_width
#> [1] 854
manim_config(quality = old$quality)
```
