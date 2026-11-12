# DashedVMobject

A dashed copy of a VMobject.

## Usage

``` r
DashedVMobject(
  vmobject,
  num_dashes = 15,
  dashed_ratio = 0.5,
  dash_offset = 0,
  color = "#FFFFFF",
  equal_lengths = TRUE,
  ...
)
```

## Arguments

- vmobject:

  The VMobject to dash.

- num_dashes:

  Number of dashes.

- dashed_ratio:

  Fraction of the path covered by dashes.

- dash_offset:

  Shift of the dash pattern along the path.

- color:

  Color.

- equal_lengths:

  Whether dashes have equal arc lengths.

- ...:

  Passed to
  [`VMobject()`](https://adamrsophie.github.io/manimR/reference/VMobjectClass.md).
