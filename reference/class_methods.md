# Class methods

Upstream's class and static methods live on the class generators:

## Value

The methods return what upstream's class methods of the same names
return, as the list above describes.

## Details

- `CircleClass$from_three_points(p1, p2, p3, ...)`: the circle through
  three points.

- `AngleClass$from_three_points(A, B, C, ...)`: the angle at `B` between
  the lines to `A` and `C`.

- `Line3DClass$parallel_to(line, point, length, ...)` and
  `Line3DClass$perpendicular_to(line, point, length, ...)`: a 3D line
  through `point` parallel or perpendicular to `line`.

- `ChangeSpeedClass$add_updater(mobject, update_function, index, call_updater)`:
  an updater that follows speed changes (the same as
  [`change_speed_add_updater()`](https://adamrsophie.github.io/manimR/reference/change_speed_add_updater.md)).

- `MobjectClass$set_default(...)` and `AnimationClass$set_default(...)`:
  [`set_default()`](https://adamrsophie.github.io/manimR/reference/set_default.md)
  for those base classes.

- `MobjectClass$add_animation_override(animation_class, override_func, mobject_class = MobjectClass)`:
  registers an override, as
  [`override_animation()`](https://adamrsophie.github.io/manimR/reference/override_animation.md)
  does, and errors if the class already has one.

- `TextClass$font_list()` and `MarkupTextClass$font_list()`: the font
  families installed.

- `TexTemplateClass$from_file(file, ...)`: a template whose whole body
  is read from a `.tex` file.

- `CodeClass$get_styles_list()` and
  `CodeClass$get_pygments_style(name)`: the names and colors of the
  highlighting styles (all of Pygments' when it is available, see
  [`Code()`](https://adamrsophie.github.io/manimR/reference/CodeClass.md)).

- `GraphClass$from_igraph(graph, ...)` and
  `DiGraphClass$from_igraph(graph, ...)`: a
  [`Graph()`](https://adamrsophie.github.io/manimR/reference/GenericGraphClass.md)
  or
  [`DiGraph()`](https://adamrsophie.github.io/manimR/reference/GenericGraphClass.md)
  with the vertices (by name when they have names) and edges of an
  igraph graph, the R counterpart of upstream's `Graph.from_networkx()`;
  `...` goes to the constructor, for example `layout = "spring"`.

## Examples

``` r
CircleClass$from_three_points(LEFT, UP, RIGHT)$radius
#> [1] 1
head(TextClass$font_list())
#> [1] "Bitstream Charter"    "C059"                 "Courier"             
#> [4] "D050000L"             "DejaVu Math TeX Gyre" "DejaVu Sans"         
```
