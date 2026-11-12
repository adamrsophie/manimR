# Records of the interaction queue

Upstream's interactive scene reads a queue (`scene$queue`) while it
runs; manimR's interactive window
([interactive_scene](https://adamrsophie.github.io/manimR/reference/interactive_scene.md))
does the same.

## Usage

``` r
MethodWithArgs(method, args = list(), kwargs = list())

SceneInteractContinue(sender)

SceneInteractRerun(sender, ...)

EndSceneEarlyException(message = "end")

RerunSceneException(message = "rerun")

MultiAnimationOverrideException(message = "")
```

## Arguments

- method:

  A function.

- args, kwargs:

  Lists of positional and named arguments.

- sender:

  Who asked: `"gui"`, `"keyboard"`, `"play"` or `"file"`.

- ...:

  Named arguments of the rerun.

- message:

  Condition message.

## Value

A record of the class of its name; a condition for the exceptions;
`RerunSceneHandler` is an R6 class generator.

## Details

- `MethodWithArgs(method, args, kwargs)` is a method to call later with
  positional `args` and named `kwargs`; the animation builder
  (`mob$animate`) records its method calls this way.

- `SceneInteractContinue(sender)` ends the interaction and the scene
  continues.

- `SceneInteractRerun(sender, ...)` reruns the scene; a
  `from_animation_number` among `...` sets where the rerun starts.

- `RerunSceneHandler$new(queue)` is the file watcher's handler: its
  `on_modified()` queues a rerun from `"file"`. The interactive window
  calls it when the scene's input file changes.

- `EndSceneEarlyException()`, `RerunSceneException()` and
  `MultiAnimationOverrideException()` build the conditions of upstream's
  exceptions (classes `manim_end_scene`, `manim_rerun_scene` and
  `manim_multi_override`), which
  [`render()`](https://adamrsophie.github.io/manimR/reference/render.md)
  and `MobjectClass$add_animation_override()` signal.

## Examples

``` r
m <- MethodWithArgs(function(x, y = 1) x + y, list(2), list(y = 3))
do.call(m$method, c(m$args, m$kwargs))
#> [1] 5
SceneInteractRerun("keyboard", from_animation_number = 2)$kwargs
#> $from_animation_number
#> [1] 2
#> 
q <- SceneQueue$new()
RerunSceneHandler$new(q)$on_modified()
class(q$get_nowait())
#> [1] "SceneInteractRerun"
tryCatch(stop(RerunSceneException()), manim_rerun_scene = function(e) "rerun")
#> [1] "rerun"
```
