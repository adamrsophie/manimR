# Scene sections

A scene is split into sections with its `next_section()` method. Each
section records the partial movie files of the plays it contains
(`partial_movie_files`, with `NULL` for skipped plays, as upstream) and,
when `manim_config(save_sections = TRUE)`, the file name of its own
video (`video`, relative to the sections directory), which is joined
from those partial movie files.

## Usage

``` r
Section(type_, video, name, skip_animations)
```

## Arguments

- type\_:

  Section type, see
  [DefaultSectionType](https://adamrsophie.github.io/manimR/reference/DefaultSectionType.md).

- video:

  File name of the section's video, or `NULL` when the section is not
  saved.

- name:

  Section name.

- skip_animations:

  Skip rendering the animations of this section.

## Details

`$is_empty()` tells whether the section has no plays, `$get_dict()`
returns the entry written to the sections index (name, type, video and
the video's metadata from
[`get_video_metadata()`](https://adamrsophie.github.io/manimR/reference/command_helpers.md),
unless `metadata` is given).

## Examples

``` r
s <- Section(DefaultSectionType$NORMAL, NULL, "intro", FALSE)
s$is_empty()
#> [1] TRUE
```
