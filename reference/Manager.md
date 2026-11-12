# Render manager

A `Manager` coordinates the render of one scene, as upstream's
`manim.manager.Manager` does: `$render()` runs the scene's `setup()`,
`construct()` and `tear_down()`, then finishes the output; `$play()`,
`$next_section()`, `$add_subcaption()` and `$add_sound()` carry out the
scene methods of the same names. The `renderer`, `camera`,
`file_writer`, `time`, `num_plays` and `skip_animations` fields forward
to the scene's renderer.

## Usage

``` r
Manager(scene)
```

## Arguments

- scene:

  The scene to manage.

## Details

A scene creates its manager when it is first rendered or played; one can
also be attached explicitly with `Manager(scene)`, and a scene accepts
only one.

## Examples

``` r
sc <- Scene$new()
m <- Manager(sc)
identical(sc$manager, m)
#> [1] TRUE
```
