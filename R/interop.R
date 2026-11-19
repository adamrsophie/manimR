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
#' Clipping is kept: shapes outside a clipped viewport (a ggplot panel, say)
#' are dropped and shapes that cross it are cut. Raster images, such as a
#' `rasterGrob()` or `geom_raster()`, become [ImageMobject()]s; the result is
#' then a [Group()] of the vector parts and the images in drawing order. SVG
#' features the import cannot reproduce (masks, other filters) are named in
#' a warning; `raster = TRUE` then gives a faithful picture of the plot as a
#' single image.
#'
#' @param x The plot.
#' @param width,height Size of the drawing in inches.
#' @param bg Background of the drawing; `"transparent"` (the default) leaves
#'   only the plot's own elements.
#' @param height_units Height of the mobject in scene units, or `NULL` to
#'   keep the SVG size.
#' @param raster Draw the plot as one image ([ImageMobject()]) instead of
#'   importing its shapes.
#' @param res Resolution of the image in pixels per inch when `raster = TRUE`.
#' @param ... Passed to [SVGMobject()].
#' @return An [SVGMobject()]; a [Group()] when the plot has raster images;
#'   an [ImageMobject()] when `raster = TRUE`.
#' @export
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE) && local({f <- tempfile(fileext = ".svg"); d <- grDevices::dev.cur(); suppressWarnings(try(grDevices::svg(f), silent = TRUE)); if (grDevices::dev.cur() != d) grDevices::dev.off(); file.exists(f)})
#' # R's svg() device needs the Cairo library (on macOS, XQuartz).
#' \donttest{
#' p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
#' chart <- as_mobject(p)
#' }
#' \dontrun{
#' # A video in the media folder (by default in the session's temporary
#' # directory); this needs ffmpeg.
#' render(function(self) self$play(Create(chart)), quality = "l")
#' }
as_mobject <- function(x, width = 7, height = 5, bg = "transparent", height_units = 6, raster = FALSE, res = 150,
                       ...) {
  UseMethod("as_mobject")
}

#' @export
as_mobject.default <- function(x, width = 7, height = 5, bg = "transparent", height_units = 6, raster = FALSE,
                               res = 150, ...) {
  if (is_mobject(x)) return(x)
  draw <- if (is.function(x)) x
    else if (inherits(x, c("grob", "gTree", "gtable"))) function() grid::grid.draw(x)
    else if (inherits(x, "recordedplot")) function() grDevices::replayPlot(x)
    else if (inherits(x, "ggplot")) function() print(x)
    else stop("as_mobject() takes a ggplot, a grid grob, a recorded plot or a drawing function.", call. = FALSE)
  if (isTRUE(raster)) return(plot_to_image_mobject(draw, width, height, bg, height_units, res))
  if (!isTRUE(capabilities("cairo"))) stop("as_mobject() needs R's Cairo svg() device.", call. = FALSE)
  file <- tempfile(fileext = ".svg")
  on.exit(unlink(file), add = TRUE)
  grDevices::svg(file, width = width, height = height, bg = bg)
  ok <- FALSE
  tryCatch({
    draw()
    ok <- TRUE
  }, finally = grDevices::dev.off())
  # R's svg() only warns when it cannot load the Cairo library.
  if (!file.exists(file)) {
    stop("R's svg() device wrote no file: it needs the Cairo library (on macOS, XQuartz).", call. = FALSE)
  }
  mob <- SVGMobject(file, height = height_units, clip_paths = TRUE, keep_images = TRUE, use_svg_cache = FALSE, ...)
  if (length(mob$unsupported)) {
    logger$warning(paste0("as_mobject() could not reproduce these SVG features: ", paste(mob$unsupported, collapse = ", "),
                          ". Use raster = TRUE for an exact picture of the plot."))
  }
  swap_image_placeholders(mob)
}

# The plot drawn by `draw` as one ImageMobject `height_units` high.
plot_to_image_mobject <- function(draw, width, height, bg, height_units, res) {
  prev <- grDevices::dev.cur()
  capture <- ragg::agg_capture(width = width, height = height, units = "in", res = res, background = bg)
  dev <- grDevices::dev.cur()
  on.exit({
    if (dev %in% grDevices::dev.list()) grDevices::dev.off(dev)
    if (prev > 1 && prev %in% grDevices::dev.list()) grDevices::dev.set(prev)
  }, add = TRUE)
  draw()
  img <- ImageMobject(capture(native = TRUE))
  if (!is.null(height_units)) img$height <- height_units
  img
}

# An SVGMobject whose image placeholders become ImageMobjects: a Group of
# the vector runs and the images in drawing order, or the SVGMobject itself
# when it has no images.
swap_image_placeholders <- function(mob) {
  subs <- mob$submobjects
  is_image <- vapply(subs, function(m) !is.null(m$svg_image), NA)
  if (!any(is_image)) return(mob)
  parts <- list()
  run <- list()
  flush <- function() {
    if (length(run)) parts[[length(parts) + 1L]] <<- do.call(VGroup, run)
    run <<- list()
  }
  for (i in seq_along(subs)) {
    if (!is_image[i]) {
      run[[length(run) + 1L]] <- subs[[i]]
      next
    }
    flush()
    corners <- subs[[i]]$get_start_anchors()
    img <- ImageMobject(subs[[i]]$svg_image)
    img$set_resampling_algorithm(if (isTRUE(subs[[i]]$svg_image_interpolate)) "bilinear" else "nearest")
    img$points <- rbind(corners[1, ], corners[2, ], corners[4, ], corners[3, ])
    parts[[length(parts) + 1L]] <- img
  }
  flush()
  do.call(Group, parts)
}

#' Render one frame of a scene
#'
#' `scene_frame()` renders the frame shown at time `t` (in seconds) of a
#' scene, without writing a video: plays that end before `t` step through
#' their frames without drawing them (so updaters reach the state a render
#' gives), and the play running at `t` is drawn at its last frame at or
#' before `t`, the frame a video shows then. It is a quick way to
#' look at any point of a scene while writing it; `plot()` shows the frame.
#' `t = Inf` gives the last frame. The frame at time `t` is frame
#' `floor(t * frame_rate)` of the movie, as in the timeline of
#' [render_report()].
#'
#' `scene_frames()` returns the frames at several times from one run of the
#' scene, so a scene with random parts shows one consistent run.
#'
#' With `file` (`files` for `scene_frames()`), the frame is also written to
#' a file: a PNG of the frame, or a PDF or SVG in which the 2D camera draws
#' the scene again as vectors, for figures that scale. `storyboard()` draws
#' the frames at several times side by side, each with a label, into one
#' PDF, SVG or PNG file, again from one run. Vector output and storyboards
#' need the Cairo renderer; image mobjects stay images in them.
#'
#' `expect_snapshot_frame()` is a testthat expectation for packages that
#' make scenes: it saves the frame as a PNG snapshot (see
#' [testthat::expect_snapshot_file()]) and fails when it changes.
#'
#' @param scene A [Scene] class, a construct function or a scene object, as
#'   [render()] takes.
#' @param t Time in seconds; for `scene_frames()` and `storyboard()`, one or
#'   more times, which may be named.
#' @param file,files File (one per time for `files`) to write the frame to,
#'   ending in `.png`, `.pdf` or `.svg`.
#' @param ncol Number of columns of the storyboard.
#' @param labels Labels under the frames of the storyboard; by default the
#'   names of `t`, or the times.
#' @param quality Quality flag or preset name.
#' @param ... Further [manim_config()] settings.
#' @param name Snapshot name for `expect_snapshot_frame()`.
#' @return `scene_frame()` returns a `manim_frame_image`, a native raster;
#'   `scene_frames()` a list of them, named as `t`; `storyboard()` `file`,
#'   invisibly.
#' @export
#' @examples
#' f <- scene_frame(function(self) self$play(Create(Circle()), run_time = 2), t = 1)
#' plot(f)
#' fs <- scene_frames(function(self) self$play(Create(Circle()), run_time = 2), t = c(start = 0.5, end = 2))
#' pdf_file <- tempfile(fileext = ".pdf")
#' storyboard(function(self) self$play(Create(Circle()), run_time = 2), t = c(0.5, 1, 2), pdf_file)
scene_frame <- function(scene, t = Inf, quality = "l", ..., file = NULL) {
  if (length(t) != 1) stop("`t` must be one time; use scene_frames() for several.", call. = FALSE)
  frame <- scene_frames(scene, t, quality = quality, ..., files = file)[[1]]
  if (is.null(file)) frame else invisible(frame)
}

#' @rdname scene_frame
#' @export
scene_frames <- function(scene, t, quality = "l", ..., files = NULL) {
  if (!is.numeric(t) || !length(t) || anyNA(t)) stop("`t` must be one or more times.", call. = FALSE)
  if (!is.null(files) && length(files) != length(t)) stop("`files` needs one file per time.", call. = FALSE)
  frames <- scene_at_times(scene, t, list(quality = quality, ...), function(renderer, scene, i) {
    frame <- renderer$get_frame()
    if (!is.null(files)) write_scene_file(renderer, scene, frame, files[i])
    frame
  })
  frames <- lapply(frames, function(f) structure(f, class = c("manim_frame_image", class(f))))
  names(frames) <- names(t)
  frames
}

#' @rdname scene_frame
#' @export
storyboard <- function(scene, t, file, ncol = min(length(t), 3), labels = names(t), quality = "l", ...) {
  if (!is.numeric(t) || !length(t) || anyNA(t)) stop("`t` must be one or more times.", call. = FALSE)
  ext <- tolower(tools::file_ext(file))
  if (!ext %in% c("pdf", "svg", "png")) stop("`file` must end in .pdf, .svg or .png.", call. = FALSE)
  labels <- labels %||% sprintf("t = %s s", format(t))
  nrow <- ceiling(length(t) / ncol)
  dev <- NULL
  label_h <- 0.4
  scene_at_times(scene, t, list(quality = quality, ...), function(renderer, scene, i) {
    cam <- vector_camera(renderer)
    w <- cam$pixel_width / 96
    h <- cam$pixel_height / 96
    prev <- grDevices::dev.cur()
    on.exit(if (prev > 1) grDevices::dev.set(prev), add = TRUE)
    if (is.null(dev)) {
      open_graphics_file(file, ncol * w, nrow * (h + label_h))
      dev <<- grDevices::dev.cur()
      grid::grid.newpage(recording = FALSE)
      grid::pushViewport(grid::viewport(layout = grid::grid.layout(nrow * 2, ncol,
        heights = grid::unit(rep(c(h, label_h), nrow), "inches")), name = "storyboard"))
      grid::upViewport()
    }
    grDevices::dev.set(dev)
    k <- i - 1
    grid::seekViewport("storyboard")
    grid::pushViewport(grid::viewport(layout.pos.row = 2 * (k %/% ncol) + 1, layout.pos.col = k %% ncol + 1))
    cam$draw_frame(list_update(scene$mobjects, scene$foreground_mobjects))
    grid::upViewport()
    grid::pushViewport(grid::viewport(layout.pos.row = 2 * (k %/% ncol) + 2, layout.pos.col = k %% ncol + 1))
    grid::grid.text(labels[order(t)][i], gp = grid::gpar(fontsize = 14))
    grid::upViewport()
    NULL
  }, finally = function() if (!is.null(dev)) grDevices::dev.off(dev))
  invisible(file)
}

# Runs a scene once and calls capture(renderer, scene, i) at each time of
# `t` in increasing order; returns the captures in the order of `t`.
scene_at_times <- function(scene, t, settings, capture, finally = NULL) {
  if (!is.null(finally)) on.exit(finally(), add = TRUE)
  settings <- c(list(format = "none", progress_bar = FALSE), settings)
  with_manim_config(settings, {
    obj <- instantiate_scene(scene)
    ord <- order(t)
    renderer <- obj$renderer
    renderer$target_time <- t[ord]
    renderer$target_frames <- list()
    renderer$on_target <- function(scene, i) capture(renderer, scene, i)
    on.exit({
      renderer$target_time <- NULL
      renderer$on_target <- NULL
    }, add = TRUE)
    if (inherits(scene, "Scene")) obj$init_output()
    found <- function(cnd) cnd$frames
    res <- tryCatch({
      obj$get_manager()$render()
      NULL
    }, manim_frame_found = found)
    if (is.null(res)) {
      # Times at or after the end show the last frame.
      res <- tryCatch({
        while (length(renderer$target_time)) renderer$capture_target(obj)
        renderer$target_frames
      }, manim_frame_found = found, finally = renderer$close_device())
    }
    res[order(ord)]
  })
}

# The 2D camera of a renderer, which can draw on any graphics device.
vector_camera <- function(renderer) {
  cam <- renderer$camera
  if (inherits(renderer, "OpenGLRenderer") || !is.function(cam$draw_frame)) {
    stop("Vector output (PDF, SVG) and storyboards need the Cairo renderer.", call. = FALSE)
  }
  cam
}

open_graphics_file <- function(file, width, height) {
  switch(tolower(tools::file_ext(file)),
    pdf = grDevices::pdf(file, width = width, height = height),
    svg = {
      if (!isTRUE(capabilities("cairo"))) stop("SVG output needs R built with cairo.", call. = FALSE)
      grDevices::svg(file, width = width, height = height)
    },
    png = ragg::agg_png(file, width = width, height = height, units = "in", res = 96),
    stop("`file` must end in .pdf, .svg or .png.", call. = FALSE))
}

# Writes the scene as it is now: a PNG of the frame, or PDF and SVG drawn
# again as vectors by the camera.
write_scene_file <- function(renderer, scene, frame, file) {
  ext <- tolower(tools::file_ext(file))
  if (ext == "png") {
    png::writePNG(frame_to_png_array(frame), file)
    return(invisible(file))
  }
  if (!ext %in% c("pdf", "svg")) stop("`files` must end in .png, .pdf or .svg.", call. = FALSE)
  cam <- vector_camera(renderer)
  prev <- grDevices::dev.cur()
  open_graphics_file(file, cam$pixel_width / 96, cam$pixel_height / 96)
  dev <- grDevices::dev.cur()
  on.exit({
    grDevices::dev.off(dev)
    if (prev > 1) grDevices::dev.set(prev)
  }, add = TRUE)
  grid::grid.newpage(recording = FALSE)
  cam$draw_frame(list_update(scene$mobjects, scene$foreground_mobjects))
  invisible(file)
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
