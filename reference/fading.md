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
