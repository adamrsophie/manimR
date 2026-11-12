# SVGMobject

Import an SVG file as vectorized mobjects. Paths, rectangles, circles,
ellipses, lines, polylines, polygons, groups, `<use>` references,
transforms, CSS and fill/stroke styles are supported; text elements are
skipped with a warning, as upstream does (convert them to paths first).
Styles are read as upstream's parser reads them: a shape with no stroke
keeps the stroke color of its class with a width of 0, a `fill-opacity`
or `stroke-opacity` replaces the alpha of its color, and the `opacity`
property is not read.

The import follows upstream's steps, each a method: `get_file_path()`
finds the file (also in the `assets_dir` setting, with `.svg` added);
`modify_xml_tree(doc)` wraps the content in groups carrying the
`svg_default` style and the root element's style;
`get_mobjects_from(doc)` walks the elements and turns each shape (a list
of its `node`, resolved `style` and `transform` matrix) into a mobject
with `get_mob_from_shape_element(shape)`, which calls
`path_to_mobject()`, `line_to_mobject()`, `rect_to_mobject()`,
`ellipse_to_mobject()`, `polygon_to_mobject()`, `polyline_to_mobject()`
or `text_to_mobject()`, then `apply_style_to_mobject()` and
`handle_transform()`; `generate_mobject()` runs these, and
`init_svg_mobject()` caches the result under `hash_seed()`.
`move_into_position()` centers and sizes it.

## Usage

``` r
SVGMobject(
  file_name = NULL,
  should_center = TRUE,
  height = 2,
  width = NULL,
  color = NULL,
  opacity = NULL,
  fill_color = NULL,
  fill_opacity = NULL,
  stroke_color = NULL,
  stroke_opacity = NULL,
  stroke_width = NULL,
  svg_default = NULL,
  path_string_config = NULL,
  use_svg_cache = TRUE,
  ...
)

VMobjectFromSVGPath(
  path_string,
  long_lines = FALSE,
  should_subdivide_sharp_curves = FALSE,
  should_remove_null_curves = FALSE,
  ...
)
```

## Arguments

- file_name:

  Path to an `.svg` file.

- should_center:

  Center the result at the origin.

- height, width:

  Target size; `height = 2` by default like Manim.

- color, opacity, fill_color, fill_opacity, stroke_color,
  stroke_opacity, stroke_width:

  Style overrides applied after import.

- svg_default:

  Default style for elements that do not set their own: a list with
  `color`, `opacity`, `fill_color`, `fill_opacity`, `stroke_width`,
  `stroke_color` and `stroke_opacity`.

- path_string_config:

  Arguments for `VMobjectFromSVGPath()`.

- use_svg_cache:

  Reuse earlier imports of the same file.

- ...:

  Passed to
  [`VMobject()`](https://adamrsophie.github.io/manimR/reference/VMobjectClass.md).

- path_string:

  SVG path data, as in the `d` attribute of a `<path>`.

- long_lines, should_subdivide_sharp_curves, should_remove_null_curves:

  Upstream's options for the OpenGL renderer's triangulation; kept for
  compatibility.

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.

## Examples

``` r
file <- tempfile(fileext = ".svg")
writeLines(c(
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">',
  '<circle cx="5" cy="5" r="4" fill="#58C4DD"/>',
  '<path d="M 2 5 L 8 5" stroke="#FFFFFF"/>',
  '</svg>'), file)
SVGMobject(file)
#> <SVGMobject> 0 points, 2 submobjects
```
