# Base classes for the active renderer

`get_mobject_class()`, `get_vectorized_mobject_class()` and
`get_point_mobject_class()` return the base classes for the active
renderer, as upstream's `manim.mobject.utils`; with manimR's renderer
they are
[MobjectClass](https://adamrsophie.github.io/manimR/reference/MobjectClass.md),
[VMobjectClass](https://adamrsophie.github.io/manimR/reference/VMobjectClass.md)
and
[PMobjectClass](https://adamrsophie.github.io/manimR/reference/point_cloud.md).

## Usage

``` r
get_mobject_class()

get_vectorized_mobject_class()

get_point_mobject_class()
```

## Value

An R6 class generator.

## Examples

``` r
get_mobject_class()$classname
#> [1] "Mobject"
get_vectorized_mobject_class()$classname
#> [1] "VMobject"
get_point_mobject_class()$classname
#> [1] "PMobject"
```
