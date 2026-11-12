# Fading animations

`FadeIn()` and `FadeOut()` fade mobjects in or out, optionally moving
them by `shift`, toward `target_position`, or scaling by `scale`.

## Usage

``` r
FadeIn(...)

FadeOut(...)
```

## Arguments

- ...:

  Mobjects, then named arguments: `shift`, a vector to move along while
  fading; `target_position`, a point or mobject to fade toward or from;
  `scale`, the scale factor of the faded state; and any argument of
  [`Transform()`](https://adamrsophie.github.io/manimR/reference/transform.md).

## Value

An animation: an R6 object of the class named by the function called, to
pass to a scene's `play()`. The objects whose names end in `Class` are
the R6 class generators that these functions call.
