# BulletedList and Title

`BulletedList()` typesets items with bullets; `Title()` places
underlined LaTeX text at the top of the frame. Both use
[`Tex()`](https://adamrsophie.github.io/manimR/reference/tex.md).

## Usage

``` r
BulletedList(
  ...,
  buff = MED_LARGE_BUFF,
  dot_scale_factor = 2,
  tex_environment = NULL,
  dot_buff = SMALL_BUFF
)

Title(
  ...,
  include_underline = TRUE,
  match_underline_width_to_text = FALSE,
  underline_buff = MED_SMALL_BUFF
)
```

## Arguments

- ...:

  Strings, then named arguments for
  [`Tex()`](https://adamrsophie.github.io/manimR/reference/tex.md).

- buff:

  Gap between items.

- dot_scale_factor:

  Bullet size.

- tex_environment:

  LaTeX environment.

- dot_buff:

  Gap between bullet and item.

- include_underline:

  Draw an underline.

- match_underline_width_to_text:

  Underline only under the text.

- underline_buff:

  Gap below the title.

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.
