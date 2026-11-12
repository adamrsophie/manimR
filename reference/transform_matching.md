# Transform matching parts

These animations map the parts of `mobject` and `target_mobject` to keys
and transform parts with equal keys into each other.
`TransformMatchingShapes()` matches submobjects by shape (their points
after moving to the origin, scaling to height 1 and rounding to three
decimals); `TransformMatchingTex()` matches the parts of
[`MathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md)
objects by their TeX strings.

## Usage

``` r
TransformMatchingShapes(mobject, target_mobject, ..., use_override = TRUE)

TransformMatchingTex(mobject, target_mobject, ..., use_override = TRUE)
```

## Arguments

- mobject:

  The starting mobject.

- target_mobject:

  The target mobject.

- ...:

  Named arguments: `transform_mismatches`, to transform unmatched parts
  into each other with
  [`Transform()`](https://adamrsophie.github.io/manimR/reference/transform.md);
  `fade_transform_mismatches`, to transform them with
  [`FadeTransformPieces()`](https://adamrsophie.github.io/manimR/reference/transform.md);
  `key_map`, an optional named character vector or list mapping keys of
  source parts to keys of target parts that should be transformed into
  each other although they differ (useful with
  `TransformMatchingTex()`); and arguments passed to the part
  animations, for example `path_arc` or `run_time`.

- use_override:

  `FALSE` ignores an animation override set with
  [`override_animation()`](https://adamrsophie.github.io/manimR/reference/override_animation.md)
  on the class of `mobject`.

## Value

An animation: an R6 object of the class named by the function called, to
pass to a scene's `play()`. The objects whose names end in `Class` are
the R6 class generators that these functions call.

## Details

Unless `transform_mismatches` or `fade_transform_mismatches` is `TRUE`,
unmatched parts of the source fade out toward the unmatched target
parts, and unmatched target parts fade in from there.

## Examples

``` r
Anagram <- manim_scene(function(self) {
  src <- Text("the morse code")
  tar <- Text("here come dots")
  self$play(Write(src))
  self$wait(0.5)
  self$play(TransformMatchingShapes(src, tar, path_arc = PI / 2))
  self$wait(0.5)
})
```
