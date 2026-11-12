# User facing render entry points.

#' Render a scene
#'
#' Renders a scene to a video (or image) file, like `manim render` does.
#'
#' @param scene A [Scene] subclass (R6 generator), a scene instance, or a
#'   function of one argument `self` used as `construct()`. A scene instance
#'   keeps the camera it was created with, so quality and other camera
#'   settings only apply when `scene` is a class or a function.
#' @param quality One of `"l"`, `"m"`, `"h"`, `"p"`, `"k"`. Defaults to the
#'   current [manim_config()] quality.
#' @param format Output format: `"mp4"`, `"gif"`, `"webm"`, `"mov"` or `"png"`
#'   (an image sequence).
#' @param output_file Output path. Defaults to
#'   `media/videos/<module>/<quality>/<Scene>.<format>`.
#' @param save_last_frame Also write the final frame as a PNG.
#' @param preview Open the result when done (the RStudio Viewer when available).
#' @param transparent Render with a transparent background.
#' @param module_name Folder name under `media/`; defaults to the scene
#'   file name when known.
#' @param scene_name Name used for output files; defaults to the scene class name.
#' @param ... Further [manim_config()] settings for this render, such as
#'   `background_color` or `frame_rate`.
#' @return The output path, invisibly, with class `manim_output`.
#' @export
#' @examples
#' \dontrun{
#' render(function(self) self$play(Create(Circle())), quality = "l")
#' }
render <- function(scene, quality = NULL, format = NULL, output_file = NULL, save_last_frame = NULL,
                   preview = FALSE, transparent = NULL, module_name = NULL, scene_name = NULL, ...) {
  settings <- list(...)
  if (!is.null(quality)) settings$quality <- quality
  if (!is.null(format)) settings$format <- format
  if (!is.null(save_last_frame)) settings$save_last_frame <- save_last_frame
  if (!is.null(transparent)) settings$transparent <- transparent
  if (inherits(scene, "Scene")) {
    # As upstream, a scene reads the camera settings when it is created, so
    # they cannot change an existing instance.
    fixed <- intersect(names(settings), c("quality", "pixel_width", "pixel_height", "frame_rate", "frame_height",
                                          "frame_width", "background_color", "background_opacity",
                                          "transparent", "write_to_movie"))
    if (length(fixed)) {
      warning("render() was given a scene object, which keeps the camera it was created with, so ",
              paste(fixed, collapse = ", "), " had no effect on the camera. Pass the Scene class instead, ",
              "or set manim_config() before creating the scene.", call. = FALSE)
    }
  }
  with_manim_config(settings, {
    obj <- instantiate_scene(scene)
    if (!is.null(scene_name)) obj$scene_name_override <- scene_name
    out <- obj$render(module_name = module_name, output_file = output_file)
  })
  out <- structure(normalizePath(out, mustWork = FALSE), class = "manim_output")
  if (isTRUE(preview)) preview_output(out)
  invisible(out)
}

instantiate_scene <- function(scene) {
  if (inherits(scene, "R6ClassGenerator")) return(scene$new())
  if (inherits(scene, "Scene")) return(scene)
  if (is.function(scene)) return(manim_scene(scene)$new())
  stop("`scene` must be a Scene class, a Scene object, or a function.", call. = FALSE)
}

#' @export
print.manim_output <- function(x, ...) {
  cat("<manim output> ", unclass(x), "\n", sep = "")
  invisible(x)
}

#' Preview a rendered file
#'
#' Shows a video, GIF or PNG in the RStudio Viewer pane when available,
#' otherwise opens it with the system viewer.
#'
#' @param path Path to a rendered file.
#' @export
preview_output <- function(path) {
  path <- unclass(path)
  if (!file.exists(path)) stop("File not found: ", path, call. = FALSE)
  viewer <- getOption("viewer")
  if (!is.null(viewer)) {
    dir <- file.path(tempdir(), "manimR-preview", basename(tempfile()))
    dir.create(dir, recursive = TRUE)
    file.copy(path, file.path(dir, basename(path)))
    html <- file.path(dir, "index.html")
    writeLines(preview_html(basename(path)), html)
    viewer(html)
  } else {
    utils::browseURL(path)
  }
  invisible(path)
}

preview_html <- function(file) {
  ext <- tolower(tools::file_ext(file))
  body <- if (ext %in% c("mp4", "webm", "mov")) {
    sprintf('<video src="%s" controls autoplay loop playsinline></video>', file)
  } else {
    sprintf('<img src="%s" alt="manim output">', file)
  }
  c("<!doctype html>", "<html><head><meta charset='utf-8'><title>manimR preview</title>",
    "<style>html,body{margin:0;height:100%;background:#111;display:flex;align-items:center;justify-content:center}",
    "video,img{max-width:100%;max-height:100vh}</style></head><body>", body, "</body></html>")
}

# Render a group of mobjects to a nativeRaster with the 2D camera.
render_mobject_image <- function(mobject, pixel_width = cfg("pixel_width"), pixel_height = cfg("pixel_height"),
                                 background_color = cfg("background_color")) {
  cam <- CameraClass$new(pixel_width = pixel_width, pixel_height = pixel_height, background_color = background_color)
  prev <- grDevices::dev.cur()
  cap <- ragg::agg_capture(width = pixel_width, height = pixel_height, units = "px", res = 96, background = "transparent")
  dev <- grDevices::dev.cur()
  on.exit({
    grDevices::dev.off(dev)
    if (prev > 1) grDevices::dev.set(prev)
  }, add = TRUE)
  grid::grid.newpage(recording = FALSE)
  cam$draw_frame(list(mobject))
  cap(native = TRUE)
}

write_mobject_png <- function(mobject, file, ...) {
  png::writePNG(render_mobject_image(mobject, ...), file)
}

#' Plot a mobject
#'
#' Draws a mobject on the current graphics device, framed like a scene, so it
#' shows in the RStudio Plots pane.
#'
#' @param x A mobject.
#' @param background_color Background color.
#' @param ... Ignored.
#' @export
plot.Mobject <- function(x, background_color = cfg("background_color"), ...) {
  cam <- CameraClass$new(background_color = background_color)
  aspect <- cam$pixel_height / cam$pixel_width
  grid::grid.newpage()
  grid::pushViewport(grid::viewport(width = grid::unit(1, "snpc"), height = grid::unit(aspect, "snpc")))
  dev_w <- grid::convertWidth(grid::unit(1, "npc"), "inches", valueOnly = TRUE) * 96
  cam$pixel_width <- dev_w
  cam$pixel_height <- dev_w * aspect
  cam$draw_frame(list(x))
  grid::popViewport()
  invisible(x)
}
