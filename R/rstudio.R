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
#' * `addin_render_background()`: render the scene under the cursor as an
#'   RStudio background job, so the console stays free; the job pane shows
#'   its log and can stop it, and the result opens in the Viewer when it is
#'   done.
#' * `manim_gadget()`: a dialog to pick the scene, quality and format.
#'
#' The quality used by the quick addins is `getOption("manimR.addin_quality", "l")`.
#' Any addin can be bound to a keyboard shortcut with Tools, Modify Keyboard
#' Shortcuts.
#' @return The addins are called for their side effects and return nothing
#'   useful.
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
addin_render_background <- function() {
  require_rstudio()
  doc <- active_document_file()
  scenes <- find_scenes(doc$path)
  if (!length(scenes)) stop("No Scene subclasses found in the active document.", call. = FALSE)
  name <- scene_at_cursor(doc$ctx, names(scenes))
  job_dir <- tempfile("manimR-job-")
  dir.create(job_dir)
  result <- file.path(job_dir, "output.rds")
  script <- file.path(job_dir, "render.R")
  # The job is another R process, whose temporary directory is removed when
  # it ends, so it writes to the media folder of this session.
  writeLines(c(
    sprintf("manimR::manim_config(media_dir = %s)", deparse(normalizePath(cfg("media_dir"), mustWork = FALSE))),
    sprintf("out <- manimR::render_file(%s, %s, quality = %s)", deparse(doc$path), deparse(name),
            deparse(addin_quality())),
    sprintf("saveRDS(unclass(out), %s)", deparse(result))
  ), script)
  job <- rstudioapi::jobRunScript(script, name = paste("manimR:", name), workingDir = dirname(doc$path),
                                  importEnv = FALSE)
  # Show the result when the job has written it.
  poll <- function() {
    if (file.exists(result)) {
      out <- readRDS(result)
      if (length(out)) preview_output(out[1])
    } else {
      state <- tryCatch(rstudioapi::jobGetState(job), error = function(e) "running")
      if (state %in% c("idle", "running")) later_call(poll, 1)
    }
  }
  later_call(poll, 1)
  invisible(job)
}

# Runs `f` after `delay` seconds when the later package is available.
later_call <- function(f, delay) {
  if (requireNamespace("later", quietly = TRUE)) later::later(f, delay)
  invisible(NULL)
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
  out <- render_file(doc$path, name, quality = addin_quality(), format = "png", found = scenes)
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
      shiny::selectInput("format", "Format", c("auto", "mp4", "gif", "webm", "mov", "png-sequence")),
      shiny::checkboxInput("transparent", "Transparent background", FALSE),
      shiny::checkboxInput("last_frame", "Last frame only", FALSE)
    )
  )
  server <- function(input, output, session) {
    shiny::observeEvent(input$done, {
      fmt <- if (isTRUE(input$last_frame)) "png" else input$format
      # Transparent output needs a format with an alpha channel.
      if (isTRUE(input$transparent) && fmt == "mp4") fmt <- "mov"
      args <- list(doc$path, input$scene, quality = input$quality, format = fmt,
                   transparent = input$transparent, found = scene_classes)
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
#' Chunk options `quality`, `format` (default `"auto"`, or `"png"` for LaTeX
#' output) and `save_last_frame` are passed to [render()]; `out.width` sets
#' the display width.
#'
#' ```` markdown
#' ```{manim, scene = "SquareToCircle", quality = "l"}
#' SquareToCircle <- R6::R6Class("SquareToCircle", inherit = Scene,
#'   public = list(construct = function() self$play(Create(Circle()))))
#' ```
#' ````
#' @param options knitr chunk options.
#' @return A character string for knitr: the chunk output with the rendered
#'   video or image embedded.
#' @export
knitr_manim_engine <- function(options) {
  env <- knitr::knit_global()
  code <- paste(options$code, collapse = "\n")
  # Evaluating the chunk's own R code is the purpose of a knitr engine, exactly
  # like an `r` chunk; the code comes from the document author.
  if (isTRUE(options$eval)) eval(parse(text = code), envir = env)
  # The source is R code, so it is shown (and highlighted) as R.
  options$lang <- options$lang %||% "r"
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
  # Videos play in HTML; LaTeX gets the last frame and other formats (GitHub
  # Markdown, Word) an animated GIF.
  fmt <- options$format %||% (if (knitr::is_latex_output()) "png" else if (knitr::is_html_output()) "auto" else "gif")
  if (isTRUE(options$save_last_frame)) fmt <- "png"
  # The artifact gets the extension of its format; "auto" writes a video, or
  # the last frame of a scene without animations.
  # normalizePath() leaves a file that does not exist yet relative, so the
  # existing folder is normalized instead.
  stem <- file.path(normalizePath(fig_dir), paste0(options$label, "-", name))
  file <- unclass(render(scenes[[name]], quality = options$quality %||% "l", format = fmt, output_file = stem,
                         media_dir = file.path(tempdir(), "manimR-knitr"), preview = FALSE))
  ext <- tolower(tools::file_ext(file))
  # Link the figure folder's copy relative to the document, like knitr does.
  file <- file.path(fig_dir, basename(file))
  width <- css_width(options$out.width)
  embed <- if (ext %in% c("mp4", "webm", "mov") && knitr::is_html_output()) {
    sprintf('<video src="%s" controls autoplay muted loop playsinline style="width:%s"></video>',
            utils::URLencode(video_src(file, fig_dir)), width)
  } else {
    knitr::knit_hooks$get("plot")(file, options)
  }
  paste(c(out_text, embed), collapse = "\n")
}

# A CSS width from knitr's out.width: a bare number is in pixels, as knitr
# reads it for images.
css_width <- function(w) {
  if (is.null(w) || !length(w)) return("100%")
  w <- as.character(w[1])
  if (grepl("^[0-9.]+$", w)) paste0(w, "px") else w
}

# The path a page uses for a video in fig_dir. rmarkdown keeps figures in
# <document>_files/ next to the HTML file; pkgdown passes that folder as an
# absolute path, which only images get rewritten for.
video_src <- function(file, fig_dir) {
  files_dir <- dirname(fig_dir)
  if (grepl("^(/|[A-Za-z]:)", file) && grepl("_files$", basename(files_dir))) {
    return(substring(file, nchar(dirname(files_dir)) + 2))
  }
  file
}

# Registers the engine when knitr is loaded, without loading knitr for
# every library(manimR).
register_knitr_engine <- function() {
  set_engine <- function(...) knitr::knit_engines$set(manim = knitr_manim_engine)
  if (isNamespaceLoaded("knitr")) set_engine() else setHook(packageEvent("knitr", "onLoad"), set_engine)
}
