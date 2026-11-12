# Read a manim.cfg file

Applies the settings of a `.cfg` file written for Manim, the format of
upstream's `manim.cfg`: the `[CLI]` section holds settings such as
`quality`, `media_dir`, `background_color` or `format`, and the
`[video_encoder]`, `[video_encoder.options]`, `[media]` and `[jupyter]`
sections their counterparts. This is upstream's `config.digest_file()`,
also available as `config$digest_file()`.

## Usage

``` r
digest_config_file(filename)

config_file_paths()
```

## Arguments

- filename:

  Path to the `.cfg` file.

## Value

`digest_config_file()` returns the settings applied, invisibly;
`config_file_paths()` a named character vector.

## Details

As upstream does on import, manimR reads two files when it is loaded, if
they exist: the user wide file and the folder wide `manim.cfg` of the
working directory, in that order. `config_file_paths()` gives the three
locations of upstream: the library wide `default.cfg` (shipped with
manimR, whose values are its built in defaults),
`~/.config/manim/manim.cfg` (on Windows
`~/AppData/Roaming/Manim/manim.cfg`) and `manim.cfg`.
[`manim_cli()`](https://adamrsophie.github.io/manimR/reference/manim_cli.md)
reads the working directory's file again, or the one given with
`-c`/`--config_file`.
[`make_config_parser()`](https://adamrsophie.github.io/manimR/reference/make_config_parser.md)
merges the three files.

## Examples

``` r
cfg_file <- tempfile(fileext = ".cfg")
writeLines(c("[CLI]", "frame_rate = 24", "background_color = WHITE"), cfg_file)
old <- manim_config()
digest_config_file(cfg_file)
config$frame_rate
#> [1] 24
do.call(manim_config, old[c("frame_rate", "background_color")])
```
