# RStudio addins

Addins available from the RStudio Addins menu:

- `addin_render_scene()`: render the scene under the cursor and play it
  in the Viewer.

- `addin_render_all()`: render every scene in the active file.

- `addin_last_frame()`: render only the final frame of the scene under
  the cursor (fast preview).

- `addin_insert_template()`: insert a scene template at the cursor.

- `addin_render_background()`: render the scene under the cursor as an
  RStudio background job, so the console stays free; the job pane shows
  its log and can stop it, and the result opens in the Viewer when it is
  done.

- `manim_gadget()`: a dialog to pick the scene, quality and format.

## Usage

``` r
addin_render_scene()

addin_render_background()

addin_render_all()

addin_last_frame()

addin_insert_template()

manim_gadget()
```

## Value

The addins are called for their side effects and return nothing useful.

## Details

The quality used by the quick addins is
`getOption("manimR.addin_quality", "l")`. Any addin can be bound to a
keyboard shortcut with Tools, Modify Keyboard Shortcuts.
