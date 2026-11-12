# Typst and MathTypst

Text and formulas typeset by the [Typst](https://typst.app) compiler and
imported as vectorized mobjects. `Typst()` takes general Typst markup;
`MathTypst()` wraps its input in display math (`$ ... $`). The `typst`
command line compiler must be installed (see
[`typst_to_svg_file()`](https://adamrsophie.github.io/manimR/reference/typst_to_svg_file.md)).

## Usage

``` r
Typst(
  typst_code,
  font_size = DEFAULT_FONT_SIZE,
  typst_preamble = "",
  color = NULL,
  stroke_width = NULL,
  font_paths = NULL,
  track_baselines = FALSE,
  should_center = TRUE,
  height = NULL,
  width = NULL,
  ...
)

MathTypst(math_expression, typst_preamble = "", font_paths = NULL, ...)
```

## Arguments

- typst_code:

  Typst markup placed verbatim into the document body.

- font_size:

  Font size (48 by default), applied by scaling after import.

- typst_preamble:

  Extra Typst code inserted before the body.

- color:

  Color for the parts Typst draws in black (white by default).

- stroke_width:

  Stroke width override; `NULL` keeps Typst's strokes.

- font_paths:

  Optional extra font directories for the compiler.

- track_baselines:

  Keep per element baseline frames.

- should_center:

  Center the result at the origin.

- height, width:

  Optional target size; `height` overrides `font_size`.

- ...:

  Passed to
  [`SVGMobject()`](https://adamrsophie.github.io/manimR/reference/SVGMobjectClass.md)
  (style overrides such as `opacity`).

- math_expression:

  Typst math without the `$` delimiters; may contain `{{ ... }}` groups.

## Details

Typst renders in black; black parts take `color` while explicitly
colored parts keep their color. Stroked parts drawn by Typst (fraction
bars, underlines) keep a stroke width proportional to their size when
`stroke_width` is `NULL`.

Parts can be selected with `$select(key)`, which returns a
[`VGroup()`](https://adamrsophie.github.io/manimR/reference/VGroupClass.md)
of the submobjects (not copies). Labels come from ordinary Typst labels
(`#box[body] <label>`) or, in `MathTypst()`, from the `{{ ... }}`
shorthand: `{{ content : label }}` names a group and `{{ content }}` is
numbered automatically, so `$select(1)` is the first unnamed group
(internally labeled `_grp-0`). Groups may be nested. Unlike upstream
Manim, numeric keys are 1 based.

With `track_baselines = TRUE`, `$baseline_frames` lists the current
`(orig, right, up)` points of each imported element's reference frame
and `$get_baseline_frame(submobject)` returns one of them; both follow
later affine transformations. As in upstream Manim, the reference frame
is the SVG page frame (origin at the top left corner, one Typst point
per unit).

## Examples

``` r
if (FALSE) { # \dontrun{
Typst("*Hello* from _Typst!_", font_size = 72)
eq <- MathTypst("{{ a^2 + b^2 : lhs }} = {{ c^2 }}")
eq$select("lhs")$set_color(BLUE)
eq$select(1)$set_color(YELLOW)
} # }
```
