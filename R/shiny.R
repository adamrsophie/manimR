# Shiny output and render functions for scenes.

#' Show scenes in Shiny apps
#'
#' `manimOutput()` and `renderManim()` are a Shiny output pair, like
#' `plotOutput()` and `renderPlot()`: the expression of `renderManim()`
#' returns a [Scene] class, a construct function (as [render()] takes) or the
#' path of a rendered file, and the output shows the video (or image). The
#' expression is reactive, so a scene built from inputs renders again when
#' they change. Renders go to a temporary media directory and reuse its
#' partial movie cache; each output of each session is shown its own copy
#' of the file, served from a folder that is removed when the session ends.
#'
#' @param outputId Output name.
#' @param width CSS width of the player.
#' @param expr An expression returning a scene or a file path.
#' @param env,quoted The environment of `expr`, and whether it is quoted.
#' @param ... [render()] arguments for the scene, such as `quality = "l"`
#'   (the default) or `format = "gif"`.
#' @return `manimOutput()` returns UI; `renderManim()` a render function.
#' @export
#' @examples
#' \dontrun{
#' ui <- shiny::fluidPage(
#'   shiny::sliderInput("n", "Sides", 3, 10, 5),
#'   manimOutput("scene")
#' )
#' server <- function(input, output) {
#'   output$scene <- renderManim({
#'     n <- input$n
#'     function(self) self$play(Create(RegularPolygon(n = n)))
#'   })
#' }
#' shiny::shinyApp(ui, server)
#' }
manimOutput <- function(outputId, width = "100%") {
  if (!requireNamespace("shiny", quietly = TRUE)) stop("manimOutput() needs the shiny package.", call. = FALSE)
  shiny::div(style = paste0("width:", width), shiny::uiOutput(outputId))
}

#' @rdname manimOutput
#' @export
renderManim <- function(expr, env = parent.frame(), quoted = FALSE, ...) {
  if (!requireNamespace("shiny", quietly = TRUE)) stop("renderManim() needs the shiny package.", call. = FALSE)
  func <- shiny::exprToFunction(expr, env, quoted)
  args <- list(...)
  if (is.null(args$quality)) args$quality <- "l"
  if (is.null(args$media_dir)) args$media_dir <- file.path(tempdir(), "manimR-shiny")
  args$preview <- FALSE
  # Each output of each session shows its own copy of the rendered file, in
  # a folder only that session's pages are given, so outputs and sessions
  # never show each other's renders.
  output_id <- substr(digest::digest(list(Sys.time(), stats::runif(1)), algo = "xxhash64"), 1, 10)
  shown <- new.env(parent = emptyenv())
  shiny::renderUI({
    x <- func()
    path <- if (is.character(x)) unclass(x) else unclass(do.call(render, c(list(x), args)))
    if (is.null(path) || !file.exists(path) || dir.exists(path)) return(NULL)
    pub <- shiny_session_dir(shiny::getDefaultReactiveDomain())
    tag <- substr(digest::digest(file = path, algo = "xxhash64"), 1, 12)
    name <- paste0(output_id, "-", tag, ".", tolower(tools::file_ext(path)))
    dest <- file.path(pub$dir, name)
    if (!file.exists(dest)) file.copy(path, dest)
    old <- shown[[pub$prefix]]
    if (!is.null(old) && !identical(old, dest)) unlink(old)
    shown[[pub$prefix]] <- dest
    src <- paste0(pub$prefix, "/", utils::URLencode(name))
    if (tolower(tools::file_ext(path)) %in% c("mp4", "webm", "mov")) {
      shiny::tags$video(src = src, controls = NA, autoplay = NA, muted = NA, loop = NA, playsinline = NA,
                        style = "width:100%")
    } else {
      shiny::tags$img(src = src, style = "width:100%", alt = "manimR scene")
    }
  })
}

# The folder that holds the files shown to one Shiny session, served under a
# resource path named after a hash of the session's token, and removed with
# it when the session ends.
shiny_session_dir <- function(session) {
  token <- if (is.null(session)) "no-session" else session$token
  prefix <- paste0("manimR-", substr(digest::digest(token, algo = "sha256"), 1, 16))
  dir <- file.path(tempdir(), "manimR-shiny-out", prefix)
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    shiny::addResourcePath(prefix, dir)
    if (!is.null(session)) {
      session$onSessionEnded(function() {
        try(shiny::removeResourcePath(prefix), silent = TRUE)
        unlink(dir, recursive = TRUE)
      })
    }
  }
  list(dir = dir, prefix = prefix)
}
