# Render qualities

Upstream's quality presets. `quality` in
[`manim_config()`](https://adamrsophie.github.io/manimR/reference/manim_config.md)
and
[`render()`](https://adamrsophie.github.io/manimR/reference/render.md)
accepts a preset name such as `"low_quality"` or its flag (`"l"`).
`"example_quality"` has no flag.

## Usage

``` r
QUALITIES

DEFAULT_QUALITY
```

## Format

`QUALITIES` is a named list of presets, each a list with `flag`,
`pixel_height`, `pixel_width` and `frame_rate`. `DEFAULT_QUALITY` is the
name of the default preset.
