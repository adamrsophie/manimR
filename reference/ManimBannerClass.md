# ManimBanner

The banner of manim's logo: a circle, a square and a triangle next to
the letter M. `banner$create()` draws it and `banner$expand()` slides
the shapes aside to uncover the rest of the name. As upstream, the
expanded letters (`banner$anim`) only become submobjects during
`expand()`.

## Usage

``` r
ManimBanner(dark_theme = TRUE)
```

## Arguments

- dark_theme:

  Light letters for dark backgrounds (default) or dark letters for light
  ones.

## Value

A mobject: an R6 object of the class named by the function called. The
objects whose names end in `Class` are the R6 class generators that
these functions call.

## Examples

``` r
DarkThemeBanner <- manim_scene(function(self) {
  banner <- ManimBanner()
  self$play(banner$create())
  self$play(banner$expand())
  self$wait()
  self$play(Unwrite(banner))
})
```
