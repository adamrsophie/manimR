# Interactive scenes

Upstream's interactive mode lets you look around a scene and change it
while it runs, in its OpenGL window. In manimR,
`scene$interactive_embed()` (or `scene$embed()`, or `scene$interact()`)
opens the scene in a Shiny window (the RStudio Viewer, or a browser),
live:

## Value

The scene, invisibly, when the window closes.

## Details

- time based updaters keep running;

- dragging orbits a 3D camera (left button) or pans (right button, or
  Shift and move); the mouse wheel zooms;

- `r` restores the starting view, `q` closes the window, and other keys
  run the functions given to `scene$set_key_function(char, func)`;

- the code box runs R code with `self` set to the scene, as upstream's
  embedded IPython shell does, and redraws.

The same key and mouse handlers (`on_key_press()`, `on_mouse_drag()`,
`on_mouse_scroll()`, `on_mouse_motion()`, `on_mouse_press()`) can also
be called directly. `check_interactive_embed_is_valid()` tells whether a
window can be opened (an interactive session with shiny and miniUI
installed, and no video being written).

## Arguments

- `scene`: a scene object.

- `fps`: redraws per second.

## Examples

``` r
if (FALSE) { # interactive()
sc <- ThreeDScene$new()
sc$add(Cube())
sc$set_key_function("c", function() sc$add(Sphere(radius = 0.5)))
sc$interactive_embed()
}
```
