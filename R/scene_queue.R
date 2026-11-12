# The interaction queue of upstream's Scene (manim/scene/scene.py,
# manim/data_structures.py, manim/utils/exceptions.py). The queue holds
# MethodWithArgs, SceneInteractContinue and SceneInteractRerun records;
# the interactive window (a Shiny gadget here) reads it while it runs.

#' Records of the interaction queue
#'
#' Upstream's interactive scene reads a queue (`scene$queue`) while it
#' runs; manimR's interactive window ([interactive_scene]) does the same.
#'
#' * `MethodWithArgs(method, args, kwargs)` is a method to call later with
#'   positional `args` and named `kwargs`; the animation builder
#'   (`mob$animate`) records its method calls this way.
#' * `SceneInteractContinue(sender)` ends the interaction and the scene
#'   continues.
#' * `SceneInteractRerun(sender, ...)` reruns the scene; a
#'   `from_animation_number` among `...` sets where the rerun starts.
#' * `RerunSceneHandler$new(queue)` is the file watcher's handler: its
#'   `on_modified()` queues a rerun from `"file"`. The interactive window
#'   calls it when the scene's input file changes.
#' * `EndSceneEarlyException()`, `RerunSceneException()` and
#'   `MultiAnimationOverrideException()` build the conditions of upstream's
#'   exceptions (classes `manim_end_scene`, `manim_rerun_scene` and
#'   `manim_multi_override`), which [render()] and
#'   `MobjectClass$add_animation_override()` signal.
#'
#' @param method A function.
#' @param args,kwargs Lists of positional and named arguments.
#' @param sender Who asked: `"gui"`, `"keyboard"`, `"play"` or `"file"`.
#' @param ... Named arguments of the rerun.
#' @param message Condition message.
#' @return A record of the class of its name; a condition for the
#'   exceptions; `RerunSceneHandler` is an R6 class generator.
#' @export
#' @examples
#' m <- MethodWithArgs(function(x, y = 1) x + y, list(2), list(y = 3))
#' do.call(m$method, c(m$args, m$kwargs))
#' SceneInteractRerun("keyboard", from_animation_number = 2)$kwargs
#' q <- SceneQueue$new()
#' RerunSceneHandler$new(q)$on_modified()
#' class(q$get_nowait())
#' tryCatch(stop(RerunSceneException()), manim_rerun_scene = function(e) "rerun")
MethodWithArgs <- function(method, args = list(), kwargs = list()) {
  structure(list(method = method, args = as.list(args), kwargs = as.list(kwargs)), class = "MethodWithArgs")
}

#' @rdname MethodWithArgs
#' @export
SceneInteractContinue <- function(sender) {
  structure(list(sender = sender), class = "SceneInteractContinue")
}

#' @rdname MethodWithArgs
#' @export
SceneInteractRerun <- function(sender, ...) {
  structure(list(sender = sender, kwargs = list(...)), class = "SceneInteractRerun")
}

#' @export
print.SceneInteractContinue <- function(x, ...) {
  cat("SceneInteractContinue(sender=", x$sender, ")\n", sep = "")
  invisible(x)
}

#' @export
print.SceneInteractRerun <- function(x, ...) {
  kw <- if (length(x$kwargs)) paste0(", ", paste(names(x$kwargs), x$kwargs, sep = "=", collapse = ", ")) else ""
  cat("SceneInteractRerun(sender=", x$sender, kw, ")\n", sep = "")
  invisible(x)
}

#' @rdname MethodWithArgs
#' @format NULL
#' @usage NULL
#' @export
SceneQueue <- R6::R6Class("SceneQueue",
  public = list(
    items = NULL,
    initialize = function() self$items <- list(),
    put = function(item) {
      self$items[[length(self$items) + 1]] <- item
      invisible(self)
    },
    get = function() self$get_nowait(),
    get_nowait = function() {
      if (!length(self$items)) stop("The queue is empty.", call. = FALSE)
      item <- self$items[[1]]
      self$items <- self$items[-1]
      item
    },
    empty = function() !length(self$items),
    qsize = function() length(self$items)
  )
)

#' @rdname MethodWithArgs
#' @format NULL
#' @usage NULL
#' @export
RerunSceneHandler <- R6::R6Class("RerunSceneHandler",
  public = list(
    queue = NULL,
    initialize = function(queue) self$queue <- queue,
    on_modified = function(event = NULL) {
      self$queue$put(SceneInteractRerun("file"))
      invisible(self)
    }
  )
)

manim_condition <- function(classes, message) {
  structure(class = c(classes, "error", "condition"), list(message = message, call = NULL))
}

#' @rdname MethodWithArgs
#' @export
EndSceneEarlyException <- function(message = "end") {
  manim_condition(c("EndSceneEarlyException", "manim_end_scene"), message)
}

#' @rdname MethodWithArgs
#' @export
RerunSceneException <- function(message = "rerun") {
  manim_condition(c("RerunSceneException", "manim_rerun_scene"), message)
}

#' @rdname MethodWithArgs
#' @export
MultiAnimationOverrideException <- function(message = "") {
  manim_condition(c("MultiAnimationOverrideException", "manim_multi_override"), message)
}

# Each scene gets its own queue on first use.
Scene$set("private", ".queue", NULL)
Scene$set("active", "queue", function(value) {
  if (!missing(value)) {
    private$.queue <- value
    return(invisible(value))
  }
  if (is.null(private$.queue)) private$.queue <- SceneQueue$new()
  private$.queue
})

# Runs the queued records, as the loop of upstream's Scene.interact():
# a rerun signals RerunSceneException after the window closes, a continue
# ends the interaction and a MethodWithArgs is called.
Scene$set("public", "process_queue", function() {
  while (!self$queue$empty()) {
    action <- self$queue$get_nowait()
    if (inherits(action, "SceneInteractRerun")) {
      if (!is.null(action$kwargs$from_animation_number)) {
        manim_config(from_animation_number = action$kwargs$from_animation_number)
      }
      self$rerun_requested <- TRUE
      self$quit_interaction <- TRUE
      return(invisible(self))
    } else if (inherits(action, "SceneInteractContinue")) {
      while (!self$queue$empty()) self$queue$get()
      self$quit_interaction <- TRUE
      return(invisible(self))
    } else if (inherits(action, "MethodWithArgs")) {
      do.call(action$method, c(action$args, action$kwargs))
    }
  }
  invisible(self)
})
Scene$set("public", "rerun_requested", FALSE)
