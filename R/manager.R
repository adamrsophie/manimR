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
    render = function(preview = FALSE) {
      presentation <- self$session_spec$presentation
      open_after <- isTRUE(preview) || isTRUE(presentation$open_after_render)
      if (open_after && !self$output_spec$enabled) stop("Previewing after render requires a media artifact.", call. = FALSE)
      ok <- FALSE
      on.exit({
        if (!ok) {
          self$file_writer$abort_encode_jobs()
          self$renderer$close_device()
        }
        .manim$log_file <- NULL
      }, add = TRUE)
      self$setup()
      # Reaching the configured animation boundary (-n) ends the scene
      # normally, as upstream's EndSceneEarlyException does.
      tryCatch(self$construct(), manim_end_scene = function(e) NULL)
      self$tear_down()
      self$post_construct()
      ok <- TRUE
      if (open_after || isTRUE(presentation$show_in_file_browser)) {
        open_media_file(self$file_writer, preview = open_after,
                        show_in_file_browser = isTRUE(presentation$show_in_file_browser))
      }
      invisible(self$file_writer$final_file_path)
    },
    setup = function() self$scene$setup(),
    construct = function() self$scene$construct(),
    tear_down = function() self$scene$tear_down(),
    # Finishes the output after construct() and tear_down(). A scene without
    # animations cannot make an explicitly requested video; automatic video
    # output saves its last frame instead.
    post_construct = function() {
      output <- self$output_spec
      empty_video <- self$num_plays == 0 && output$is_video
      if (empty_video && !output$fallback_to_still) {
        stop(self$scene$scene_name(), " has no play calls, so the explicitly requested ", toupper(output$format),
             " output cannot be produced. Use format = \"png\" to save its last frame.", call. = FALSE)
      }
      self$renderer$scene_finished(self$scene)
      if (empty_video && output$fallback_to_still && !is.null(self$file_writer$final_file_path)) {
        logger$warning("%s has no play calls. Automatic video output has been saved as a PNG instead.",
                       self$scene$scene_name())
      }
      if (self$num_plays > 0 || output$enabled) {
        logger$info("Rendered %s\nPlayed %d animations", self$scene$scene_name(), self$num_plays)
      }
      invisible(self$file_writer$final_file_path)
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
      self$file_writer$next_section(name, section_type, skip_animations)
      invisible(self)
    },
    add_subcaption = function(content, duration = 1, offset = 0) {
      start <- self$time + offset
      fw <- self$file_writer
      fw$subcaptions <- c(fw$subcaptions, list(list(content = content, start = start, end = start + duration)))
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
    output_spec = function() self$session_spec$output,
    session_spec = function() self$scene$session_spec,
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
