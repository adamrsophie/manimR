# Updater animations

`UpdateFromFunc()` calls `update_function(mobject)` every frame;
`UpdateFromAlphaFunc()` calls `update_function(mobject, alpha)`.

## Usage

``` r
UpdateFromFunc(mobject, update_function, suspend_mobject_updating = FALSE, ...)

UpdateFromAlphaFunc(
  mobject,
  update_function,
  suspend_mobject_updating = FALSE,
  ...
)

MaintainPositionRelativeTo(mobject, tracked_mobject, ...)
```

## Arguments

- mobject:

  The mobject.

- update_function:

  The function to call.

- suspend_mobject_updating:

  Pause other updaters while running.

- ...:

  Passed to
  [`Animation()`](https://adamrsophie.github.io/manimR/reference/AnimationClass.md).

- tracked_mobject:

  Mobject to follow.

## Value

An animation: an R6 object of the class named by the function called, to
pass to a scene's `play()`. The objects whose names end in `Class` are
the R6 class generators that these functions call.
