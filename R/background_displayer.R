# Ported from BackgroundColoredVMobjectDisplayer in manim/camera/camera.py.

#' Display vectorized mobjects colored by a background image
#'
#' Upstream's pixel based helper for mobjects whose colors come from an image
#' (`vmobject$color_using_background_image()`). The camera draws such
#' mobjects itself by masking the image with their shape; this class gives
#' the same result as an array, as upstream returns it.
#'
#' * `$display(...)` draws the given mobjects in black and white and
#'   multiplies their coverage with their background image, one batch per
#'   run of consecutive mobjects sharing an image, keeping the brightest
#'   value of the batches. It returns an RGBA array of values 0 to 255
#'   (`pixel_height x pixel_width x 4`), or `NULL` without mobjects.
#' * `$get_background_array(image)` reads an image (a file name looked up
#'   with [get_full_raster_image_path()], or an array of values 0 to 1),
#'   resizes it to the camera's pixel size and caches it by name.
#' * `$resize_background_array(background_array, new_width, new_height,
#'   mode)` resamples an image array with bilinear interpolation (upstream
#'   uses Pillow's default bicubic filter) and converts it to `"RGBA"` or
#'   `"RGB"`; `$resize_background_array_to_match()` resizes to the shape of
#'   another array.
#'
#' @param camera The camera that draws the mobjects.
#' @return A `BackgroundColoredVMobjectDisplayer`, an R6 object.
#'   `BackgroundColoredVMobjectDisplayerClass` is its R6 class generator.
#' @name BackgroundColoredVMobjectDisplayer
#' @format NULL
#' @usage NULL
#' @export
BackgroundColoredVMobjectDisplayerClass <- R6::R6Class("BackgroundColoredVMobjectDisplayer", lock_objects = FALSE,
  public = list(
    camera = NULL,
    file_name_to_pixel_array_map = NULL,
    pixel_array = NULL,
    initialize = function(camera) {
      self$camera <- camera
      self$file_name_to_pixel_array_map <- list()
      self$pixel_array <- array(0, c(camera$pixel_height, camera$pixel_width, 4))
      self$reset_pixel_array()
    },
    reset_pixel_array = function() {
      self$pixel_array[] <- 0
      invisible(self)
    },
    resize_background_array = function(background_array, new_width, new_height, mode = "RGBA") {
      img <- change_to_rgba_array(background_array)
      dev <- ragg::agg_capture(width = new_width, height = new_height, units = "px", res = 96,
                               background = "transparent")
      dev_index <- grDevices::dev.cur()
      on.exit(grDevices::dev.off(dev_index), add = TRUE)
      grid::grid.newpage(recording = FALSE)
      grid::grid.raster(img / 255, width = grid::unit(1, "npc"), height = grid::unit(1, "npc"), interpolate = TRUE)
      out <- native_raster_to_array(dev(native = TRUE))
      if (mode == "RGB") out[, , 1:3, drop = FALSE] else out
    },
    resize_background_array_to_match = function(background_array, pixel_array) {
      d <- dim(pixel_array)
      mode <- if (length(d) == 3 && d[3] == 4) "RGBA" else "RGB"
      self$resize_background_array(background_array, d[2], d[1], mode)
    },
    get_background_array = function(image) {
      key <- if (is.character(image)) image else digest::digest(image)
      hit <- self$file_name_to_pixel_array_map[[key]]
      if (!is.null(hit)) return(hit)
      # File names and arrays of values 0 to 1 (as png::readPNG() returns).
      back <- if (is.character(image)) read_raster_file(get_full_raster_image_path(image)) * 255 else image * 255
      back <- change_to_rgba_array(back)
      if (!identical(dim(back), dim(self$pixel_array))) {
        back <- self$resize_background_array_to_match(back, self$pixel_array)
      }
      self$file_name_to_pixel_array_map[[key]] <- back
      back
    },
    display = function(...) {
      mobs <- flatten_mobjects(list(...))
      if (!length(mobs)) return(NULL)
      keys <- vapply(mobs, function(m) {
        img <- m$get_background_image()
        if (is.character(img)) img else digest::digest(img)
      }, "")
      runs <- rle(keys)
      ends <- cumsum(runs$lengths)
      curr <- NULL
      for (r in seq_along(ends)) {
        batch <- mobs[(ends[r] - runs$lengths[r] + 1):ends[r]]
        background <- self$get_background_array(batch[[1]]$get_background_image())
        self$pixel_array <- self$draw_batch(batch)
        new <- trunc(background * self$pixel_array / 255)
        curr <- if (is.null(curr)) new else pmax(curr, new)
        self$reset_pixel_array()
      }
      curr
    },
    # The batch drawn with its own colors, as an array of values 0 to 255.
    draw_batch = function(batch) {
      cam <- self$camera
      dev <- ragg::agg_capture(width = cam$pixel_width, height = cam$pixel_height, units = "px", res = 96,
                               background = "transparent")
      dev_index <- grDevices::dev.cur()
      on.exit(grDevices::dev.off(dev_index), add = TRUE)
      grid::grid.newpage(recording = FALSE)
      cam$push_view()
      for (m in batch) cam$display_vectorized(m, ignore_background_image = TRUE)
      grid::popViewport()
      native_raster_to_array(dev(native = TRUE))
    }
  )
)

#' @rdname BackgroundColoredVMobjectDisplayer
#' @export
BackgroundColoredVMobjectDisplayer <- constructor(BackgroundColoredVMobjectDisplayerClass)

#' Plugins
#'
#' Upstream finds plugins through Python entry points. A manimR plugin is an
#' installed R package whose `DESCRIPTION` has the field
#' `Config/manimR/plugin: true`. `get_plugins()` returns their namespaces,
#' named by package (loading them), and `list_plugins()` prints their names.
#'
#' @return `get_plugins()` returns a named list of namespaces;
#'   `list_plugins()` returns the names invisibly.
#' @export
#' @examples
#' list_plugins()
get_plugins <- function() {
  pkgs <- plugin_packages()
  stats::setNames(lapply(pkgs, loadNamespace), pkgs)
}

# Names of the installed packages that declare themselves manimR plugins.
plugin_packages <- function() {
  pkgs <- unique(.packages(all.available = TRUE))
  flag <- vapply(pkgs, function(p) {
    as.character(suppressWarnings(utils::packageDescription(p, fields = "Config/manimR/plugin")))[1]
  }, "")
  unname(pkgs[!is.na(flag) & tolower(flag) %in% c("true", "yes")])
}

#' @rdname get_plugins
#' @export
list_plugins <- function() {
  pkgs <- plugin_packages()
  console$print("Plugins:")
  for (p in pkgs) console$print(paste0(" \u2022 ", p))
  invisible(pkgs)
}
