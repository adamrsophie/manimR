# Group of mobjects

`Group()` groups any mobjects;
[`VGroup()`](https://adamrsophie.github.io/manimR/reference/VGroupClass.md)
groups vectorized mobjects.

## Usage

``` r
Group(..., color = "#FFFFFF", name = NULL, z_index = 0)
```

## Arguments

- ...:

  Mobjects (or lists of mobjects) to group.

- color:

  Color of the group.

- name:

  Name of the group; defaults to the class name.

- z_index:

  Drawing order; higher values are drawn on top.

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.
