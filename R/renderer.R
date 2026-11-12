# Renderer: drives the camera on an offscreen ragg device and feeds frames to
# the file writer. Ported from manim/renderer/cairo_renderer.py.

#' Cairo style renderer and scene file writer
#'
#' `CairoRenderer` is the renderer every [Scene] uses, the counterpart of
#' upstream's `CairoRenderer`: it draws frames with the scene's camera on an
#' offscreen device and passes them to a `SceneFileWriter`, which streams
#' them to ffmpeg and handles sections, sounds and the last frame image.
#' Both are created by a scene; construct them yourself only to customize
#' rendering, for example `MyScene$new(renderer = CairoRenderer(...))`.
#'
#' @param camera_class The camera class generator.
#' @param skip_animations Skip rendering animations.
#' @param ... Arguments passed to the camera.
#' @param scene_name,module_name,width,height,fps,output_file Output names
#'   and frame format of a `SceneFileWriter`.
#' @name CairoRenderer
#' @format NULL
#' @usage NULL
NULL

RendererClass <- R6::R6Class("Renderer", lock_objects = FALSE,
  public = list(
    camera = NULL,
    file_writer = NULL,
    capture = NULL,
    device = NULL,
    static_image = NULL,
    time = 0,
    num_plays = 0,
    skip_animations = FALSE,
    original_skipping_status = FALSE,
    last_frame = NULL,
    initialize = function(camera_class = CameraClass, skip_animations = FALSE, ...) {
      self$camera <- camera_class$new(...)
      self$skip_animations <- skip_animations
      self$original_skipping_status <- skip_animations
    },
    init_scene = function(scene, module_name = NULL, output_file = NULL) {
      self$file_writer <- SceneFileWriterClass$new(
        scene_name = scene$scene_name(), module_name = module_name,
        width = self$camera$pixel_width, height = self$camera$pixel_height,
        fps = self$camera$frame_rate, output_file = output_file
      )
      invisible(self)
    },
    open_device = function() {
      if (!is.null(self$device) && self$device %in% grDevices::dev.list()) return(invisible(self))
      prev <- grDevices::dev.cur()
      self$capture <- ragg::agg_capture(width = self$camera$pixel_width, height = self$camera$pixel_height,
                                        units = "px", res = 96, background = "transparent")
      self$device <- grDevices::dev.cur()
      if (prev > 1) grDevices::dev.set(prev)
      invisible(self)
    },
    close_device = function() {
      if (!is.null(self$device) && self$device %in% grDevices::dev.list()) {
        prev <- grDevices::dev.cur()
        grDevices::dev.off(self$device)
        if (prev != self$device && prev %in% grDevices::dev.list()) grDevices::dev.set(prev)
      }
      self$device <- NULL
      invisible(self)
    },
    # Draw mobjects onto the offscreen device.
    update_frame = function(scene, mobjects = NULL, include_submobjects = TRUE) {
      # With a cached static frame, an empty list means nothing moves; drawing
      # everything again would double the alpha of translucent shapes.
      if (length(mobjects) == 0 && is.null(self$static_image)) {
        mobjects <- list_update(scene$mobjects, scene$foreground_mobjects)
      }
      self$open_device()
      prev <- grDevices::dev.cur()
      grDevices::dev.set(self$device)
      on.exit(if (prev > 1 && prev != self$device) grDevices::dev.set(prev), add = TRUE)
      grid::grid.newpage(recording = FALSE)
      self$camera$draw_frame(mobjects, include_submobjects = include_submobjects,
                                   background_raster = self$static_image)
      invisible(self)
    },
    # Opens the current frame in the system image viewer (upstream's
    # show_frame()); returns the PNG file it wrote.
    show_frame = function(scene) {
      self$static_image <- NULL
      self$update_frame(scene)
      path <- tempfile("manimR-frame-", fileext = ".png")
      png::writePNG(native_raster_to_array(self$get_frame()) / 255, path)
      if (interactive()) open_file(path)
      invisible(path)
    },
    get_frame = function() {
      prev <- grDevices::dev.cur()
      grDevices::dev.set(self$device)
      on.exit(if (prev > 1 && prev != self$device) grDevices::dev.set(prev), add = TRUE)
      self$last_frame <- self$capture(native = TRUE)
      self$last_frame
    },
    add_frame = function(frame, num_frames = 1) {
      if (self$skip_animations) return(invisible(self))
      self$time <- self$time + num_frames / self$camera$frame_rate
      self$file_writer$write_frame(frame, num_frames)
      invisible(self)
    },
    update_skipping_status = function() {
      n <- self$num_plays
      if (!is.null(self$file_writer) && isTRUE(self$file_writer$current_section()$skip_animations)) {
        self$skip_animations <- TRUE
      }
      if (n < (cfg("from_animation_number") %||% 0)) self$skip_animations <- TRUE
      if (n > (cfg("upto_animation_number") %||% Inf)) {
        self$skip_animations <- TRUE
        stop(structure(class = c("manim_end_scene", "condition"), list(message = "end", call = NULL)))
      }
    },
    # As upstream's CairoRenderer.play(): a play whose hash names an existing
    # partial movie file is not rendered again (it only updates the scene).
    play = function(scene, ...) {
      self$skip_animations <- self$original_skipping_status
      self$update_skipping_status()
      scene$compile_animation_data(...)
      fw <- self$file_writer
      hash <- NULL
      if (self$skip_animations) {
        self$time <- self$time + scene$duration
      } else if (!is.null(fw)) {
        if (isTRUE(cfg("disable_caching"))) {
          hash <- sprintf("uncached_%05d", self$num_plays)
        } else {
          hash <- get_hash_from_play_call(scene, self$camera, scene$animations, scene$mobjects)
          if (fw$is_already_cached(hash)) {
            logger$info("Animation %d : Using cached data (hash : %s)", self$num_plays, hash)
            self$skip_animations <- TRUE
            self$time <- self$time + scene$duration
          }
        }
      }
      if (!is.null(fw)) {
        fw$add_partial_movie_file(hash)
        fw$begin_animation(!self$skip_animations)
      }
      scene$begin_animations()
      self$save_static_frame_data(scene, scene$static_mobjects)
      if (scene$is_current_animation_frozen_frame()) {
        self$update_frame(scene, mobjects = scene$moving_mobjects)
        self$freeze_current_frame(scene$duration)
      } else {
        scene$play_internal()
      }
      if (!is.null(fw)) fw$end_animation(!self$skip_animations)
      self$num_plays <- self$num_plays + 1
      invisible(self)
    },
    render = function(scene, time, moving_mobjects) {
      if (self$skip_animations) return(invisible(self))
      self$update_frame(scene, moving_mobjects)
      self$add_frame(self$get_frame())
    },
    freeze_current_frame = function(duration) {
      dt <- 1 / self$camera$frame_rate
      if (self$skip_animations) return(invisible(self))
      n <- as.integer(floor(duration / dt + 1e-9))
      self$add_frame(self$get_frame(), num_frames = n)
    },
    save_static_frame_data = function(scene, static_mobjects) {
      self$static_image <- NULL
      if (length(static_mobjects) == 0 || self$skip_animations) return(invisible(NULL))
      self$update_frame(scene, mobjects = static_mobjects, include_submobjects = FALSE)
      self$static_image <- self$get_frame()
      invisible(self$static_image)
    },
    scene_finished = function(scene) {
      on.exit(self$close_device(), add = TRUE)
      out <- NULL
      save_last <- isTRUE(cfg("save_last_frame"))
      if (self$num_plays > 0 && self$file_writer$has_output()) {
        self$file_writer$subcaptions <- scene$subcaptions
        out <- self$file_writer$finish()
      } else {
        save_last <- TRUE
      }
      if (save_last) {
        self$static_image <- NULL
        self$update_frame(scene)
        img <- self$file_writer$save_image(self$get_frame())
        if (is.null(out)) out <- img
      }
      out
    }
  )
)

#' @rdname CairoRenderer
#' @export
CairoRendererClass <- R6::R6Class("CairoRenderer", inherit = RendererClass, lock_objects = FALSE)

#' @rdname CairoRenderer
#' @export
CairoRenderer <- constructor(CairoRendererClass)

srt_time <- function(t) {
  ms <- round(t * 1000)
  sprintf("%02d:%02d:%02d,%03d", ms %/% 3600000, (ms %/% 60000) %% 60, (ms %/% 1000) %% 60, ms %% 1000)
}

write_srt <- function(subcaptions, file) {
  lines <- unlist(lapply(seq_along(subcaptions), function(i) {
    s <- subcaptions[[i]]
    c(i, paste(srt_time(s$start), "-->", srt_time(s$end)), s$content, "")
  }))
  writeLines(lines, file)
  invisible(file)
}

# Append items of b not already in a (by mob_id), like manim's list_update.
