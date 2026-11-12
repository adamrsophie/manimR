# Number animations

`ChangingDecimal()` sets a
[`DecimalNumber()`](https://adamrsophie.github.io/manimR/reference/DecimalNumberClass.md)
to `number_update_func(alpha)`; `ChangeDecimalToValue()` counts it to a
target.

## Usage

``` r
ChangingDecimal(
  decimal_mob,
  number_update_func,
  suspend_mobject_updating = FALSE,
  ...
)

ChangeDecimalToValue(decimal_mob, target_number, ...)
```

## Arguments

- decimal_mob:

  A
  [`DecimalNumber()`](https://adamrsophie.github.io/manimR/reference/DecimalNumberClass.md).

- number_update_func:

  Function of alpha.

- suspend_mobject_updating:

  Pause other updaters.

- ...:

  Passed to
  [`Animation()`](https://adamrsophie.github.io/manimR/reference/AnimationClass.md).

- target_number:

  Final number.

## Value

An animation: an R6 object of the class named by the function called, to
pass to a scene's `play()`. The objects whose names end in `Class` are
the R6 class generators that these functions call.
