# Define a scene from a function

Creates a
[Scene](https://adamrsophie.github.io/manimR/reference/Scene.md)
subclass whose `construct()` calls `construct(self)`.

## Usage

``` r
manim_scene(construct, name = "Scene", base = Scene, setup = NULL)
```

## Arguments

- construct:

  A function of one argument, the scene.

- name:

  Class name, used for the output file name.

- base:

  Scene class to inherit from, such as `MovingCameraScene`.

- setup:

  Optional function of the scene called before `construct`.

## Value

An R6 class generator that can be passed to
[`render()`](https://adamrsophie.github.io/manimR/reference/render.md).

## Examples

``` r
MyScene <- manim_scene(function(self) {
  self$play(Create(Circle()))
}, name = "MyScene")
```
