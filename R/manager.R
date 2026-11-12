# Render orchestration, ported from manim/manager.py.

#' Render manager
#'
#' A `Manager` coordinates the render of one scene, as upstream's
#' `manim.manager.Manager` does: `$render()` runs the scene's `setup()`,
#' `construct()` and `tear_down()`, then finishes the output; `$play()`,
#' `$next_section()`, `$add_subcaption()` and `$add_sound()` carry out the
#' scene methods of the same names. The `renderer`, `camera`,
#' `file_writer`, `time`, `num_plays` and `skip_animations` fields forward
#' to the scene's renderer.
#'
#' A scene creates its manager when it is first rendered or played; one can
#' also be attached explicitly with `Manager(scene)`, and a scene accepts
#' only one.
#'
#' @param scene The scene to manage.
#' @name Manager
#' @format NULL
#' @usage NULL
#' @examples
#' sc <- Scene$new()
#' m <- Manager(sc)
#' identical(sc$manager, m)
#' @export
ManagerClass <- R6::R6Class("Manager", lock_objects = FALSE,
  public = list(
    scene = NULL,
    initialize = function(scene) {
      if (!is.null(scene$manager)) stop("A manager is already attached to this scene.", call. = FALSE)
      self$scene <- scene
      scene$manager <- self
    },
    render = function(preview = FALSE, module_name = NULL, output_file = NULL) {
      sc <- self$scene
      self$renderer$init_scene(sc, module_name = module_name, output_file = output_file)
      ok <- FALSE
      on.exit(if (!ok) {
        fw <- self$renderer$file_writer
        if (!is.null(fw)) fw$abort_encode_jobs()
        self$renderer$close_device()
      }, add = TRUE)
      self$setup()
      # Reaching the configured animation boundary (-n) ends the scene
      # normally, as upstream's EndSceneEarlyException does.
      tryCatch(self$construct(), manim_end_scene = function(e) NULL)
      self$tear_down()
      out <- self$post_construct()
      ok <- TRUE
      out
    },
    setup = function() self$scene$setup(),
    construct = function() self$scene$construct(),
    tear_down = function() self$scene$tear_down(),
    # Finishes the output; a scene without plays is saved as its last frame,
    # as upstream does for automatic video output.
    post_construct = function() {
      out <- self$renderer$scene_finished(self$scene)
      if (self$num_plays == 0 && isTRUE(cfg("write_to_movie")) && !isTRUE(cfg("save_last_frame")) &&
          !identical(cfg("format"), "png")) {
        logger$warning("%s has no play calls. Its last frame has been saved as a PNG instead.", self$scene$scene_name())
      }
      out
    },
    play = function(..., subcaption = NULL, subcaption_duration = NULL, subcaption_offset = 0) {
      start <- self$time
      self$renderer$play(self$scene, ...)
      run_time <- self$time - start
      if (!is.null(subcaption) && nzchar(subcaption)) {
        # Added after the play, so the start goes back by its run time.
        self$scene$add_subcaption(content = subcaption, duration = subcaption_duration %||% run_time,
                                  offset = -run_time + subcaption_offset)
      }
      invisible(self)
    },
    next_section = function(name = "unnamed", section_type = DefaultSectionType$NORMAL, skip_animations = FALSE) {
      if (is.null(self$file_writer)) stop("next_section() needs a scene being rendered", call. = FALSE)
      self$file_writer$next_section(name, section_type, skip_animations)
      invisible(self)
    },
    add_subcaption = function(content, duration = 1, offset = 0) {
      start <- self$time + offset
      self$scene$subcaptions <- c(self$scene$subcaptions,
                                  list(list(content = content, start = start, end = start + duration)))
      invisible(self)
    },
    # No sound is added while animations are skipped.
    add_sound = function(sound_file, time_offset = 0, gain = NULL, gain_to_background = NULL, ...) {
      if (self$skip_animations) return(invisible(self))
      self$file_writer$add_sound(sound_file, self$time + time_offset, gain, gain_to_background = gain_to_background)
      invisible(self)
    }
  ),
  active = list(
    # What the render writes, and how it is presented (upstream's OutputSpec
    # and RenderSessionSpec), from the current settings.
    output_spec = function() {
      fmt <- self$file_writer$format %||% cfg("format")
      list(format = fmt, is_video = isTRUE(cfg("write_to_movie")) && fmt != "png",
           is_still = !isTRUE(cfg("write_to_movie")), is_image_sequence = identical(fmt, "png"),
           is_gif = identical(fmt, "gif"), save_last_frame = isTRUE(cfg("save_last_frame")),
           save_sections = isTRUE(cfg("save_sections")), transparent = isTRUE(cfg("transparent")))
    },
    session_spec = function() {
      list(preview = isTRUE(cfg("preview")), from_animation_number = cfg("from_animation_number"),
           upto_animation_number = cfg("upto_animation_number"), renderer = cfg("renderer"))
    },
    renderer = function() self$scene$renderer,
    camera = function() self$scene$renderer$camera,
    file_writer = function() self$scene$renderer$file_writer,
    time = function(value) {
      if (missing(value)) return(self$scene$renderer$time)
      self$scene$renderer$time <- value
    },
    num_plays = function(value) {
      if (missing(value)) return(self$scene$renderer$num_plays)
      self$scene$renderer$num_plays <- value
    },
    skip_animations = function(value) {
      if (missing(value)) return(self$scene$renderer$skip_animations)
      self$scene$renderer$skip_animations <- value
    }
  )
)

#' @rdname Manager
#' @export
Manager <- constructor(ManagerClass)
