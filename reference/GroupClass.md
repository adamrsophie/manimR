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
