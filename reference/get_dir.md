# Resolve a directory setting

Directory settings may refer to each other and to values known only when
a scene renders, with `{name}` placeholders: the default `video_dir` is
`"{media_dir}/videos/{module_name}/{quality}"`. `get_dir()` fills them
in, as upstream's `config.get_dir()`; `quality` is always known (for
example `"480p15"`), other names come from `...`.

## Usage

``` r
get_dir(key, ...)
```

## Arguments

- key:

  One of `"assets_dir"`, `"media_dir"`, `"video_dir"`, `"sections_dir"`,
  `"images_dir"`, `"text_dir"`, `"tex_dir"`, `"log_dir"`,
  `"partial_movie_dir"`, `"input_file"` or `"output_file"`.

- ...:

  Values for placeholders, such as `module_name = "scenes"` or
  `scene_name = "Intro"`.

## Value

The path, or `NULL` when the setting is empty.

## Examples

``` r
get_dir("tex_dir")
#> [1] "/tmp/RtmprKW6CR/media/Tex"
get_dir("video_dir", module_name = "scenes")
#> [1] "/tmp/RtmprKW6CR/media/videos/scenes/1080p60"
```
