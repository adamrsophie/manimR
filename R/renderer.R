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
#' @param file_writer_class The file writer class generator a renderer
#'   creates for each scene.
#' @param camera_class The camera class generator.
#' @param skip_animations Skip rendering animations.
#' @param ... Arguments passed to the camera.
#' @param settings The settings a scene resolves for its file writer: the
#'   output plan, the video encoder and the cache settings.
#' @return `CairoRenderer()` returns a renderer and `SceneFileWriter()` a file
#'   writer, both R6 objects that a scene creates for itself. The objects whose
#'   names end in `Class` are the R6 class generators that these functions call.
#' @name CairoRenderer
#' @format NULL
#' @usage NULL
NULL

RendererClass <- R6::R6Class("Renderer", lock_objects = FALSE,
  public = list(
    file_writer_class = NULL,
    camera = NULL,
    file_writer = NULL,
    capture = NULL,
    device = NULL,
    static_image = NULL,
    time = 0,
    num_plays = 0,
    skip_animations = FALSE,
    original_skipping_status = FALSE,
    animations_hashes = NULL,
    last_frame = NULL,
    # When set (by scene_frame()), the time of the one frame to draw.
    target_time = NULL,
    initialize = function(file_writer_class = SceneFileWriterClass, camera_class = CameraClass,
                          skip_animations = FALSE, ...) {
      self$file_writer_class <- file_writer_class
      self$camera <- camera_class$new(...)
      self$skip_animations <- skip_animations
      self$original_skipping_status <- skip_animations
      self$animations_hashes <- list()
    },
    # Creates the file writer from the settings the scene resolved.
    init_scene = function(scene, session_spec = scene$session_spec,
                          file_writer_settings = scene$file_writer_settings) {
      self$file_writer <- self$file_writer_class$new(file_writer_settings)
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
    update_frame = function(scene, mobjects = NULL, include_submobjects = TRUE, ignore_skipping = TRUE, ...) {
      if (isTRUE(self$skip_animations) && !isTRUE(ignore_skipping)) return(invisible(self))
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
      # Only the last frame is needed for still output.
      if (isTRUE(self$file_writer$output_spec$is_still)) self$skip_animations <- TRUE
      from <- cfg("from_animation_number") %||% 0
      if (from > 0 && n < from) self$skip_animations <- TRUE
      upto <- cfg("upto_animation_number") %||% -1
      if (upto >= 0 && n > upto) {
        self$skip_animations <- TRUE
        stop(EndSceneEarlyException())
      }
    },
    # As upstream's CairoRenderer.play(): a play whose hash names an existing
    # partial movie file is not rendered again (it only updates the scene).
    play = function(scene, ...) {
      self$skip_animations <- self$original_skipping_status
      self$update_skipping_status()
      scene$compile_animation_data(...)
      if (!is.null(self$target_time)) return(self$play_to_target(scene))
      fw <- self$file_writer
      hash <- NULL
      if (self$skip_animations) {
        self$time <- self$time + scene$duration
      } else if (isTRUE(cfg("disable_caching"))) {
        logger$info("Caching disabled.")
        hash <- sprintf("uncached_%05d", self$num_plays)
      } else {
        hash <- get_hash_from_play_call(scene, self$camera, scene$animations, scene$mobjects, backend = "cairo",
                                        encoder_fingerprint = video_encoder_fingerprint(scene$session_spec$video_encoder))
        if (fw$is_already_cached(hash)) {
          logger$info("Animation %d : Using cached data (hash : %s)", self$num_plays, hash)
          self$skip_animations <- TRUE
          self$time <- self$time + scene$duration
        }
      }
      fw$add_partial_movie_file(hash)
      self$animations_hashes[[length(self$animations_hashes) + 1]] <- hash
      fw$begin_animation(!self$skip_animations, animation_index = self$num_plays)
      scene$begin_animations()
      self$save_static_frame_data(scene, scene$static_mobjects)
      if (scene$is_current_animation_frozen_frame()) {
        self$update_frame(scene, mobjects = scene$moving_mobjects)
        self$freeze_current_frame(scene$duration)
      } else {
        scene$play_internal()
      }
      fw$end_animation(!self$skip_animations)
      self$num_plays <- self$num_plays + 1
      invisible(self)
    },
    # scene_frame(): plays that end before the target time step through
    # their frame times without drawing, so updaters that use dt reach the
    # state a render gives; the play running at that time steps to its last
    # frame time at or before it, which is drawn and returned through a
    # manim_frame_found condition.
    play_to_target = function(scene) {
      start <- self$time
      scene$begin_animations()
      if (start + scene$duration < self$target_time || !is.finite(self$target_time)) {
        scene$play_internal(skip_rendering = TRUE)
        self$time <- start + scene$duration
        self$num_plays <- self$num_plays + 1
        return(invisible(self))
      }
      target <- max(self$target_time - start, 0)
      if (self$skip_animations) {
        scene$update_to_time(target)
      } else {
        fps <- scene$camera$frame_rate
        n <- ceiling(scene$duration * fps - 1e-9)
        times <- if (n > 0) (seq_len(n) - 1) / fps else 0
        times <- times[times <= target + 1e-9]
        for (tt in if (length(times)) times else 0) {
          scene$update_to_time(tt)
          if (!is.null(scene$stop_condition) && isTRUE(scene$stop_condition())) break
        }
      }
      self$static_image <- NULL
      self$update_frame(scene)
      frame <- self$get_frame()
      self$close_device()
      stop(structure(class = c("manim_frame_found", "condition"), list(message = "frame", call = NULL, frame = frame)))
    },
    render = function(scene, time, moving_mobjects = NULL) {
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
    # Finishes the output as upstream's scene_finished(): the movie or image
    # sequence, and the last frame for still output (or for automatic video
    # output of a scene without animations). Returns the artifact path.
    scene_finished = function(scene) {
      on.exit(self$close_device(), add = TRUE)
      fw <- self$file_writer
      output <- fw$output_spec
      if (self$num_plays > 0 && (output$is_video || output$is_image_sequence)) {
        fw$finish()
      } else if (self$num_plays == 0) {
        self$static_image <- NULL
        self$update_frame(scene)
      }
      if (output$is_still || (self$num_plays == 0 && output$fallback_to_still)) {
        if (self$num_plays > 0) {
          self$static_image <- NULL
          self$update_frame(scene)
        }
        fw$save_image(self$get_frame())
      }
      fw$final_file_path
    }
  )
)

#' @rdname CairoRenderer
#' @export
CairoRendererClass <- R6::R6Class("CairoRenderer", inherit = RendererClass, lock_objects = FALSE,
  public = list(capabilities = RendererCapabilities(live_preview = FALSE))
)

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
