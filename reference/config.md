# The global configuration object

`config` gives upstream's `config.name` access to the settings of
[`manim_config()`](https://adamrsophie.github.io/manimR/reference/manim_config.md):
`config$frame_height`, `config$pixel_width <- 1280`,
`config[["background_color"]]`. Derived values (`frame_width`,
`frame_x_radius`, `frame_y_radius`, `aspect_ratio`, `top`, `bottom`,
`left_side`, `right_side`) are computed on read; `frame_width` can also
be set, as upstream allows, and then stays fixed until set again.
`config$quality <- "low_quality"` applies a preset from
[QUALITIES](https://adamrsophie.github.io/manimR/reference/QUALITIES.md).
Three of upstream's methods are there too: `config$digest_file(path)`
reads a `manim.cfg` file
([`digest_config_file()`](https://adamrsophie.github.io/manimR/reference/digest_config_file.md)),
`config$get_dir(key, ...)` resolves a directory setting
([`get_dir()`](https://adamrsophie.github.io/manimR/reference/get_dir.md))
and `config$update(list(...))` changes several settings.

## Usage

``` r
config

# S3 method for class 'manim_config_object'
x$name

# S3 method for class 'manim_config_object'
x[[i, ...]]

# S3 method for class 'manim_config_object'
x$name <- value

# S3 method for class 'manim_config_object'
x[[i]] <- value

# S3 method for class 'manim_config_object'
names(x)

# S3 method for class 'manim_config_object'
print(x, ...)

manim_frame

# S3 method for class 'manim_frame_object'
x$name

# S3 method for class 'manim_frame_object'
x[[i, ...]]

# S3 method for class 'manim_frame_object'
x$name <- value

# S3 method for class 'manim_frame_object'
x[[i]] <- value

# S3 method for class 'manim_frame_object'
names(x)

# S3 method for class 'manim_frame_object'
print(x, ...)

tempconfig(temp, code)
```

## Arguments

- x:

  A config object.

- name, i:

  A setting name.

- ...:

  Ignored.

- value:

  New value.

- temp:

  A named list of settings.

- code:

  Code to run with those settings.

## Value

`tempconfig()` returns the value of `code`.

## Details

`manim_frame` is upstream's read only `frame` object: the frame sizes
and edges plus the direction constants (`manim_frame$top`,
`manim_frame$UP`). It is not called `frame` because that would mask
[`graphics::frame()`](https://rdrr.io/r/graphics/frame.html).

`tempconfig()` runs code with some settings changed and restores them
afterwards, like upstream's `with tempconfig({...}):` block. As
upstream, names that are not settings are ignored.

## Examples

``` r
config$frame_height
#> [1] 8
tempconfig(list(frame_height = 100), config$frame_height)
#> [1] 100
manim_frame$right_side
#> [1] 7.111111 0.000000 0.000000
```
