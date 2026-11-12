# Bridges between manimR and other R graphics and data.

#' Turn R plots into mobjects
#'
#' `as_mobject()` draws a plot into an SVG file with R's Cairo `svg()`
#' device and imports it with [SVGMobject()], so a ggplot2 chart, a grid
#' grob or base graphics can be animated like any vector mobject: each line,
#' point, rectangle and glyph becomes a submobject.
#'
#' * a `ggplot` object (ggplot2), a `grob` or `gTable`, or a recorded plot
#'   is drawn as it is;
#' * a function is called to draw base graphics, for example
#'   `as_mobject(function() hist(rnorm(100)))`.
#'
#' The plot is drawn on a white or transparent background (`bg`), at
#' `width` x `height` inches; the mobject is then scaled to `height_units`
#' scene units.
#'
#' @param x The plot.
#' @param width,height Size of the drawing in inches.
#' @param bg Background of the drawing; `"transparent"` (the default) leaves
#'   only the plot's own elements.
#' @param height_units Height of the mobject in scene units, or `NULL` to
#'   keep the SVG size.
#' @param ... Passed to [SVGMobject()].
#' @return An [SVGMobject()].
#' @export
#' @examples
#' \dontrun{
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
#'   chart <- as_mobject(p)
#'   render(function(self) self$play(Create(chart)), quality = "l")
#' }
#' }
as_mobject <- function(x, width = 7, height = 5, bg = "transparent", height_units = 6, ...) {
  UseMethod("as_mobject")
}

#' @export
as_mobject.default <- function(x, width = 7, height = 5, bg = "transparent", height_units = 6, ...) {
  if (is_mobject(x)) return(x)
  draw <- if (is.function(x)) x
    else if (inherits(x, c("grob", "gTree", "gtable"))) function() grid::grid.draw(x)
    else if (inherits(x, "recordedplot")) function() grDevices::replayPlot(x)
    else if (inherits(x, "ggplot")) function() print(x)
    else stop("as_mobject() takes a ggplot, a grid grob, a recorded plot or a drawing function.", call. = FALSE)
  if (!isTRUE(capabilities("cairo"))) stop("as_mobject() needs R's Cairo svg() device.", call. = FALSE)
  file <- tempfile(fileext = ".svg")
  on.exit(unlink(file), add = TRUE)
  grDevices::svg(file, width = width, height = height, bg = bg)
  ok <- FALSE
  tryCatch({
    draw()
    ok <- TRUE
  }, finally = grDevices::dev.off())
  mob <- SVGMobject(file, height = height_units, ...)
  mob
}

#' Render one frame of a scene
#'
#' `scene_frame()` renders the frame shown at time `t` (in seconds) of a
#' scene, without writing a video: plays that end before `t` step through
#' their frames without drawing them (so updaters reach the state a render
#' gives), and the play running at `t` is drawn at its last frame at or
#' before `t`, the frame a video shows then. It is a quick way to
#' look at any point of a scene while writing it; `plot()` shows the frame.
#' `t = Inf` gives the last frame.
#'
#' `expect_snapshot_frame()` is a testthat expectation for packages that
#' make scenes: it saves the frame as a PNG snapshot (see
#' [testthat::expect_snapshot_file()]) and fails when it changes.
#'
#' @param scene A [Scene] class, a construct function or a scene object, as
#'   [render()] takes.
#' @param t Time in seconds.
#' @param quality Quality flag or preset name.
#' @param ... Further [manim_config()] settings.
#' @param name Snapshot name for `expect_snapshot_frame()`.
#' @return `scene_frame()` returns a `manim_frame_image`, a native raster.
#' @export
#' @examples
#' \dontrun{
#' f <- scene_frame(function(self) self$play(Create(Circle()), run_time = 2), t = 1)
#' plot(f)
#' }
scene_frame <- function(scene, t = Inf, quality = "l", ...) {
  settings <- c(list(quality = quality, format = "none", progress_bar = FALSE), list(...))
  with_manim_config(settings, {
    obj <- instantiate_scene(scene)
    obj$renderer$target_time <- t
    if (inherits(scene, "Scene")) obj$init_output()
    res <- tryCatch({
      obj$get_manager()$render()
      NULL
    }, manim_frame_found = function(cnd) cnd$frame)
    if (is.null(res)) {
      # t is at or after the end: the last frame.
      obj$renderer$static_image <- NULL
      res <- tryCatch({
        obj$renderer$update_frame(obj)
        obj$renderer$get_frame()
      }, finally = obj$renderer$close_device())
    }
    structure(res, class = c("manim_frame_image", class(res)))
  })
}

#' @export
plot.manim_frame_image <- function(x, ...) {
  grid::grid.newpage()
  grid::grid.raster(structure(x, class = setdiff(class(x), "manim_frame_image")))
  invisible(x)
}

#' @rdname scene_frame
#' @export
expect_snapshot_frame <- function(scene, t = Inf, name = "frame", quality = "l", ...) {
  if (!requireNamespace("testthat", quietly = TRUE)) stop("expect_snapshot_frame() needs testthat.", call. = FALSE)
  frame <- scene_frame(scene, t = t, quality = quality, ...)
  file <- tempfile(fileext = ".png")
  png::writePNG(structure(frame, class = setdiff(class(frame), "manim_frame_image")), file)
  testthat::expect_snapshot_file(file, paste0(name, ".png"))
}
