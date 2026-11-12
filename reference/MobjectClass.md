# Mobject

Base class for mathematical objects. Most users construct subclasses
such as
[`Circle()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
or
[`VGroup()`](https://adamrsophie.github.io/manimR/reference/VGroupClass.md).
All transformation methods modify the object in place and return it
invisibly, so calls chain: `Square()$shift(LEFT)$scale(2)`.

## Usage

``` r
Mobject(color = "#FFFFFF", name = NULL, z_index = 0, ...)
```

## Arguments

- color:

  Color of the mobject.

- name:

  Name; the class name by default.

- z_index:

  Drawing order: higher values are drawn on top.

- ...:

  Fields of the class to set, such as those
  [`set_default()`](https://adamrsophie.github.io/manimR/reference/set_default.md)
  gives; any other name is an error.

## Details

Fields: `points` (n x 3 matrix), `submobjects` (list), `z_index`,
`updaters`, `name`. Active bindings `width`, `height`, `depth` get or
set the size. The active binding `animate` records method calls as an
animation, as in `scene$play(sq$animate$shift(RIGHT)$scale(2))`.
