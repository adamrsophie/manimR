# RStudio addins and knitr integration.

addin_quality <- function() getOption("manimR.addin_quality", "l")

require_rstudio <- function() {
  if (!requireNamespace("rstudioapi", quietly = TRUE) || !rstudioapi::isAvailable()) {
    stop("This addin needs RStudio and the rstudioapi package.", call. = FALSE)
  }
}

# Save the active document (or its unsaved text) to a file we can source.
active_document_file <- function() {
  ctx <- rstudioapi::getSourceEditorContext()
  if (is.null(ctx)) stop("No active source document.", call. = FALSE)
  path <- ctx$path
  if (!nzchar(path)) {
    path <- file.path(tempdir(), "manimR_untitled.R")
    writeLines(ctx$contents, path)
  } else if (isTRUE(rstudioapi::hasFun("documentSave"))) {
    try(rstudioapi::documentSave(ctx$id), silent = TRUE)
  }
  list(path = path, ctx = ctx)
}

# Name of the scene whose definition contains or precedes the cursor.
scene_at_cursor <- function(ctx, scene_names) {
  lines <- ctx$contents
  row <- ctx$selection[[1]]$range$start[["row"]]
  starts <- vapply(scene_names, function(n) {
    hit <- grep(paste0("^\\s*`?", n, "`?\\s*(<-|=)"), lines)
    if (length(hit)) hit[1] else NA_integer_
  }, integer(1))
  starts <- starts[!is.na(starts)]
  if (!length(starts)) return(scene_names[1])
  before <- starts[starts <= row]
  if (length(before)) names(before)[which.max(before)] else names(starts)[which.min(starts)]
}

#' RStudio addins
#'
#' Addins available from the RStudio Addins menu:
#' * `addin_render_scene()`: render the scene under the cursor and play it in the Viewer.
#' * `addin_render_all()`: render every scene in the active file.
#' * `addin_last_frame()`: render only the final frame of the scene under the cursor (fast preview).
#' * `addin_insert_template()`: insert a scene template at the cursor.
#' * `manim_gadget()`: a dialog to pick the scene, quality and format.
#'
#' The quality used by the quick addins is `getOption("manimR.addin_quality", "l")`.
#' @name rstudio_addins
NULL

#' @rdname rstudio_addins
#' @export
addin_render_scene <- function() {
  require_rstudio()
  doc <- active_document_file()
  scenes <- find_scenes(doc$path)
  if (!length(scenes)) stop("No Scene subclasses found in the active document.", call. = FALSE)
  name <- scene_at_cursor(doc$ctx, names(scenes))
  out <- render_file(doc$path, name, quality = addin_quality(), found = scenes)
  preview_output(out[1])
  invisible(out)
}

#' @rdname rstudio_addins
#' @export
addin_render_all <- function() {
  require_rstudio()
  doc <- active_document_file()
  scenes <- find_scenes(doc$path)
  if (!length(scenes)) stop("No Scene subclasses found in the active document.", call. = FALSE)
  out <- render_file(doc$path, quality = addin_quality(), found = scenes)
  if (length(out)) preview_output(out[length(out)])
  invisible(out)
}

#' @rdname rstudio_addins
#' @export
addin_last_frame <- function() {
  require_rstudio()
  doc <- active_document_file()
  scenes <- find_scenes(doc$path)
  if (!length(scenes)) stop("No Scene subclasses found in the active document.", call. = FALSE)
  name <- scene_at_cursor(doc$ctx, names(scenes))
  out <- render_file(doc$path, name, quality = addin_quality(), write_to_movie = FALSE, save_last_frame = TRUE,
                     found = scenes)
  preview_output(out[1])
  invisible(out)
}

scene_template <- function(name = "MyScene") {
  sprintf(paste(
    "%s <- R6::R6Class(\"%s\", inherit = Scene,",
    "  public = list(",
    "    construct = function() {",
    "      circle <- Circle()$set_fill(PINK, opacity = 0.5)",
    "      square <- Square()$rotate(PI / 4)",
    "      self$play(Create(square))",
    "      self$play(Transform(square, circle))",
    "      self$wait()",
    "    }",
    "  )",
    ")",
    "",
    sep = "\n"), name, name)
}

#' @rdname rstudio_addins
#' @export
addin_insert_template <- function() {
  require_rstudio()
  rstudioapi::insertText(text = scene_template())
}

#' @rdname rstudio_addins
#' @export
manim_gadget <- function() {
  require_rstudio()
  for (p in c("shiny", "miniUI")) {
    if (!requireNamespace(p, quietly = TRUE)) stop("The gadget needs the ", p, " package.", call. = FALSE)
  }
  doc <- active_document_file()
  scene_classes <- find_scenes(doc$path)
  scenes <- names(scene_classes)
  if (!length(scenes)) stop("No Scene subclasses found in the active document.", call. = FALSE)
  ui <- miniUI::miniPage(
    miniUI::gadgetTitleBar("Render manimR scene", right = miniUI::miniTitleBarButton("done", "Render", primary = TRUE)),
    miniUI::miniContentPanel(
      shiny::selectInput("scene", "Scene", scenes, selected = scene_at_cursor(doc$ctx, scenes)),
      shiny::selectInput("quality", "Quality",
                         c("Low, 480p15" = "l", "Medium, 720p30" = "m", "High, 1080p60" = "h",
                           "Production, 1440p60" = "p", "4K, 2160p60" = "k"), selected = addin_quality()),
      shiny::selectInput("format", "Format", c("mp4", "gif", "webm", "mov", "png")),
      shiny::checkboxInput("transparent", "Transparent background", FALSE),
      shiny::checkboxInput("last_frame", "Last frame only", FALSE)
    )
  )
  server <- function(input, output, session) {
    shiny::observeEvent(input$done, {
      args <- list(doc$path, input$scene, quality = input$quality, format = input$format,
                   transparent = input$transparent, found = scene_classes)
      if (isTRUE(input$last_frame)) args <- c(args, list(write_to_movie = FALSE, save_last_frame = TRUE))
      out <- do.call(render_file, args)
      shiny::stopApp(out)
    })
    shiny::observeEvent(input$cancel, shiny::stopApp(invisible(NULL)))
  }
  out <- shiny::runGadget(ui, server, viewer = shiny::dialogViewer("manimR", width = 420, height = 420))
  if (length(out)) preview_output(out[1])
  invisible(out)
}

# knitr ---------------------------------------------------------------------

#' knitr engine for manimR scenes
#'
#' Registered automatically when knitr is installed. A chunk with engine
#' `manim` evaluates its R code, renders the scene named by the chunk option
#' `scene` (or the last scene defined in the chunk), and embeds the video.
#' Chunk options `quality`, `format` and `save_last_frame` are passed to
#' [render()]; `out.width` sets the display width.
#'
#' ```` markdown
#' ```{manim, scene = "SquareToCircle", quality = "l"}
#' SquareToCircle <- R6::R6Class("SquareToCircle", inherit = Scene,
#'   public = list(construct = function() self$play(Create(Circle()))))
#' ```
#' ````
#' @param options knitr chunk options.
#' @export
knitr_manim_engine <- function(options) {
  env <- knitr::knit_global()
  code <- paste(options$code, collapse = "\n")
  # Evaluating the chunk's own R code is the purpose of a knitr engine, exactly
  # like an `r` chunk; the code comes from the document author.
  if (isTRUE(options$eval)) eval(parse(text = code), envir = env)
  out_text <- if (isTRUE(options$echo)) knitr::engine_output(options, options$code, "") else ""
  if (!isTRUE(options$eval)) return(out_text)
  scenes <- find_scenes(envir = env)
  if (!is.null(options$scene)) {
    name <- options$scene
    if (!name %in% names(scenes)) stop("Scene '", name, "' is not defined.", call. = FALSE)
  } else {
    # Only scenes assigned in this chunk count, so chunks with ordinary code
    # do not re-render a scene defined earlier.
    defined <- regmatches(code, gregexpr("[A-Za-z.][A-Za-z0-9._]*(?=\\s*(<-|=))", code, perl = TRUE))[[1]]
    defined <- intersect(rev(defined), names(scenes))
    if (!length(defined)) return(out_text)
    name <- defined[1]
  }
  fig_dir <- dirname(knitr::fig_path("", options))
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
  fmt <- options$format %||% (if (knitr::is_latex_output()) "png" else "mp4")
  last <- isTRUE(options$save_last_frame) || fmt == "png"
  ext <- if (last) "png" else fmt
  file <- file.path(fig_dir, paste0(options$label, "-", name, ".", ext))
  args <- list(scenes[[name]], quality = options$quality %||% "l", output_file = file)
  if (last) args <- c(args, list(write_to_movie = FALSE, save_last_frame = TRUE)) else args$format <- fmt
  args$media_dir <- file.path(tempdir(), "manimR-knitr")
  res <- unclass(do.call(render, args))
  if (!identical(normalizePath(res, mustWork = FALSE), normalizePath(file, mustWork = FALSE))) {
    if (!file.copy(res, file, overwrite = TRUE)) stop("Could not copy the rendered file to ", file, call. = FALSE)
  }
  width <- options$out.width %||% "100%"
  embed <- if (ext %in% c("mp4", "webm", "mov") && knitr::is_html_output()) {
    sprintf('<video src="%s" controls autoplay muted loop playsinline style="width:%s"></video>', file, width)
  } else {
    knitr::knit_hooks$get("plot")(file, options)
  }
  paste(c(out_text, embed), collapse = "\n")
}

register_knitr_engine <- function() {
  if (requireNamespace("knitr", quietly = TRUE)) knitr::knit_engines$set(manim = knitr_manim_engine)
}
