# User facing render entry points.

#' Render a scene
#'
#' Renders a scene to a video or image file, like `manim render` does.
#'
#' @param scene A [Scene] subclass (R6 generator), a scene instance, or a
#'   function of one argument `self` used as `construct()`. A scene instance
#'   keeps the camera it was created with, so quality and other camera
#'   settings only apply when `scene` is a class or a function.
#' @param quality One of `"l"`, `"m"`, `"h"`, `"p"`, `"k"` or a preset name
#'   of [QUALITIES]. Defaults to the current [manim_config()] quality.
#' @param format The artifact to write: `"auto"` (the default: MP4, or MOV
#'   when transparent; a scene without animations is saved as its last
#'   frame), `"mp4"`, `"mov"`, `"webm"`, `"gif"`, `"png"` (only the last
#'   frame), `"png-sequence"` (every frame) or `"none"`.
#' @param output_file Name of the artifact. A relative name is placed in the
#'   video directory (or the images directory for PNG output), as upstream's
#'   `-o`; an absolute path is used as it is. Defaults to the scene name in
#'   `media/videos/<module>/<quality>/` (videos) or `media/images/<module>/`
#'   (images).
#' @param save_last_frame `TRUE` is short for `format = "png"`.
#' @param preview Open the result when done (the RStudio Viewer when
#'   available). Defaults to the `preview` setting.
#' @param transparent Render with a transparent background.
#' @param module_name Folder name under `media/videos/` and `media/images/`;
#'   [render_file()] uses the script name. Defaults to `"manimR"`.
#' @param scene_name Name used for output files; defaults to the scene class name.
#' @param ... Further [manim_config()] settings for this render, such as
#'   `background_color`, `frame_rate`, `save_sections` or `dry_run`.
#' @return The path of the artifact, invisibly, with class `manim_output`;
#'   `NULL` when nothing is written (`format = "none"` or `dry_run`).
#' @export
#' @examples
#' # The last frame as a PNG file in the session's temporary directory.
#' render(function(self) self$play(Create(Circle())), quality = "l", format = "png",
#'        media_dir = tempdir())
#' \dontrun{
#' # A video in the folder media of the working directory; this needs ffmpeg.
#' render(function(self) self$play(Create(Circle())), quality = "l")
#' }
render <- function(scene, quality = NULL, format = NULL, output_file = NULL, save_last_frame = NULL,
                   preview = NULL, transparent = NULL, module_name = NULL, scene_name = NULL, ...) {
  settings <- list(...)
  if (!is.null(quality)) settings$quality <- quality
  if (!is.null(format)) settings$format <- format
  if (!is.null(save_last_frame)) settings$save_last_frame <- save_last_frame
  if (!is.null(transparent)) settings$transparent <- transparent
  if (!is.null(output_file)) settings$output_file <- output_file
  if (!is.null(module_name)) settings$module_name <- module_name
  if (!is.null(preview)) settings$preview <- preview
  is_instance <- inherits(scene, "Scene")
  if (is_instance) {
    # As upstream, a scene reads the camera settings when it is created, so
    # they cannot change an existing instance.
    fixed <- intersect(names(settings), c("quality", "pixel_width", "pixel_height", "frame_size", "frame_rate",
                                          "frame_height", "frame_width", "background_color", "background_opacity",
                                          "transparent"))
    if (length(fixed)) {
      warning("render() was given a scene object, which keeps the camera it was created with, so ",
              paste(fixed, collapse = ", "), " had no effect on the camera. Pass the Scene class instead, ",
              "or set manim_config() before creating the scene.", call. = FALSE)
    }
  }
  out <- with_manim_config(settings, {
    repeat {
      obj <- instantiate_scene(scene)
      if (!is.null(scene_name)) obj$scene_name_override <- scene_name
      # The output settings of this call apply to a scene created earlier too.
      if (is_instance || !is.null(scene_name)) obj$init_output()
      res <- obj$get_manager()$render()
      # An interactive rerun renders a new scene of the same class, as
      # upstream's command line does.
      if (!isTRUE(res) || is_instance) break
    }
    if (isTRUE(res)) NULL else res
  })
  if (is.null(out)) return(invisible(NULL))
  invisible(structure(normalizePath(out, mustWork = FALSE), class = "manim_output"))
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

#' Show rendered output in R Markdown and Quarto
#'
#' In a knitr document, the value of [render()] printed at the end of an `r`
#' chunk is embedded: a video player for MP4, WebM and MOV files in HTML
#' output, an image for GIF and PNG files (and a note with the path in other
#' output formats). The file is copied next to the chunk's figures, under a
#' name made of the chunk label and a hash of its contents.
#'
#' @param x A `manim_output`, the value of [render()].
#' @param options knitr chunk options; `out.width` sets the width.
#' @param ... Ignored.
#' @return A `knit_asis` string.
#' @keywords internal
#' @exportS3Method knitr::knit_print
knit_print.manim_output <- function(x, options = list(), ...) {
  path <- unclass(x)
  fig_dir <- dirname(knitr::fig_path("", options))
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
  # The copy is named after the chunk and the file's contents, so outputs of
  # other chunks (or other renders in this one) with the same file name do
  # not replace it.
  file <- path
  if (!dir.exists(path)) {
    tag <- substr(digest::digest(file = path, algo = "xxhash64"), 1, 10)
    file <- file.path(fig_dir, paste0(options$label %||% "manim", "-", tag, "-", basename(path)))
    if (!identical(normalizePath(path), normalizePath(file, mustWork = FALSE))) file.copy(path, file, overwrite = TRUE)
  }
  ext <- tolower(tools::file_ext(path))
  width <- css_width(options$out.width)
  out <- if (dir.exists(path)) {
    paste0("PNG sequence: `", path, "`")
  } else if (ext %in% c("mp4", "webm", "mov")) {
    if (knitr::is_html_output()) {
      sprintf('<video src="%s" controls autoplay muted loop playsinline style="width:%s"></video>',
              utils::URLencode(video_src(file, fig_dir)), width)
    } else {
      paste0("Video: `", path, "`")
    }
  } else {
    knitr::knit_hooks$get("plot")(file, options)
  }
  knitr::asis_output(out)
}

#' Preview a rendered file
#'
#' Shows a video, GIF or PNG in the RStudio Viewer pane when available,
#' otherwise opens it with the system viewer.
#'
#' @param path Path to a rendered file.
#' @return `path`, invisibly.
#' @export
preview_output <- function(path) {
  path <- unclass(path)
  if (!file.exists(path)) stop("File not found: ", path, call. = FALSE)
  # A PNG sequence is a folder: show it in the file browser.
  if (dir.exists(path)) return(invisible(open_file(path, in_browser = TRUE)))
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
#' @return `x`, invisibly.
#' @export
plot.Mobject <- function(x, background_color = cfg("background_color"), ...) {
  cam <- CameraClass$new(background_color = background_color)
  aspect <- cam$pixel_height / cam$pixel_width
  grid::grid.newpage()
  # The largest frame of the camera's aspect ratio that fits the device.
  dev_w <- grid::convertWidth(grid::unit(1, "npc"), "inches", valueOnly = TRUE)
  dev_h <- grid::convertHeight(grid::unit(1, "npc"), "inches", valueOnly = TRUE)
  w <- min(dev_w, dev_h / aspect)
  grid::pushViewport(grid::viewport(width = grid::unit(w, "inches"), height = grid::unit(w * aspect, "inches")))
  dev_w <- w * 96
  cam$pixel_width <- dev_w
  cam$pixel_height <- dev_w * aspect
  # Point sizes follow the camera's resolution relative to the configured
  # one; the device is the resolution here.
  with_manim_config(list(pixel_width = dev_w, pixel_height = dev_w * aspect), cam$draw_frame(list(x)))
  grid::popViewport()
  invisible(x)
}
