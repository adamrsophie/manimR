# Path and file helpers

Ports of `manim.utils.file_ops` and the path lookups of
`manim.utils.images` and `manim.utils.sounds`.

## Usage

``` r
add_extension_if_not_present(file_name, extension)

guarantee_existence(path)

guarantee_empty_existence(path)

seek_full_path_from_defaults(file_name, default_dir, extensions)

get_full_raster_image_path(image_file_name)

get_full_sound_file_path(
  sound_file_name,
  assets_dir = cfg("assets_dir") %||% "./"
)

modify_atime(file_path)

open_file(file_path, in_browser = FALSE)

ensure_executable(path_to_exe)
```

## Arguments

- file_name, file_path, path, path_to_exe:

  A path.

- extension:

  A file extension including its dot.

- default_dir:

  Directory to look in.

- extensions:

  Extensions to try, each including its dot.

- image_file_name, sound_file_name:

  A file name.

- assets_dir:

  Directory to look in.

- in_browser:

  Show the file in the file browser instead of opening it.

## Details

- `add_extension_if_not_present(file_name, extension)` appends
  `extension` (such as `".png"`) unless the name already ends with it.

- `guarantee_existence(path)` creates the directory if needed;
  `guarantee_empty_existence(path)` first deletes it. Both return the
  absolute path.

- `seek_full_path_from_defaults(file_name, default_dir, extensions)`
  returns the first existing path among `file_name` and `file_name` plus
  each extension inside `default_dir`, and errors if there is none.
  `get_full_raster_image_path()` and `get_full_sound_file_path()` look
  for images (`.jpg`, `.jpeg`, `.png`, `.gif`, `.ico`) and sounds
  (`.wav`, `.mp3`) in the `assets_dir` setting (default `"./"`).

- `modify_atime(file_path)` sets a file's access time to now, keeping
  its modification time.

- `open_file(file_path, in_browser)` opens a file with the system
  viewer, or shows it in the file browser; the `preview_command` setting
  replaces the viewer.

- `ensure_executable(path_to_exe)` tells whether a program can be run: a
  bare name is looked up on the `PATH`.

## Examples

``` r
add_extension_if_not_present("scene", ".png")
#> [1] "scene.png"
d <- guarantee_existence(file.path(tempdir(), "manimR-example"))
dir.exists(d)
#> [1] TRUE
```
