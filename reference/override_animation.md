# Override animations for a mobject class

`override_animation()` makes an animation constructor build something
else for one mobject class, like upstream's `@override_animation`
decorator: after
`override_animation(MyMobClass, "FadeIn", function(...) ...)`,
`FadeIn(my_mob, ...)` calls the function as a method of `my_mob` (so it
can use `self`) with the remaining arguments, and returns its result.
Pass `use_override = FALSE` to the constructor to get the normal
animation. Only the package's constructor functions (such as
[`FadeIn()`](https://adamrsophie.github.io/manimR/reference/fading.md))
check for overrides, not `FadeInClass$new()`.

## Usage

``` r
override_animation(mobject_class, animation, fn)

override_animate(mobject_class, method, fn)
```

## Arguments

- mobject_class:

  A mobject class generator, such as `SquareClass` or your own R6 class.

- animation:

  An animation class name, such as `"FadeIn"`, or its generator
  (`FadeInClass`).

- fn:

  The override function.

- method:

  Name of the mobject method to customize under `$animate`.

## Value

The class generator, invisibly.

## Details

`override_animate()` customizes `mob$animate$method(...)`, like
upstream's `@override_animate`: the function is called as a method of
the mobject with the method's arguments plus `anim_args`, the list of
arguments given to `animate` (such as `run_time`), and returns an
animation.

Both change the class generator in place (with `$set()`), so they apply
to objects created afterwards, including objects of subclasses.

## Examples

``` r
Pulse <- R6::R6Class("Pulse", inherit = CircleClass, lock_objects = FALSE)
override_animation(Pulse, "FadeIn", function(...) GrowFromCenter(self, ...))
class(FadeIn(Pulse$new()))[1]
#> [1] "GrowFromCenter"
```
