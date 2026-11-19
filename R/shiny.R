# Shiny output and render functions for scenes.

#' Show scenes in Shiny apps
#'
#' `manimOutput()` and `renderManim()` are a Shiny output pair, like
#' `plotOutput()` and `renderPlot()`: the expression of `renderManim()`
#' returns a [Scene] class, a construct function (as [render()] takes) or the
#' path of a rendered file, and the output shows the video (or image). The
#' expression is reactive, so a scene built from inputs renders again when
#' they change. Unless `media_dir` is given, each output of each session
#' renders into its own temporary media directory, so concurrent renders of
#' scenes with the same name never write to the same files; renders of one
#' output reuse its partial movie cache. Each output of each session is
#' shown its own copy of the file, served from a folder; both folders are
#' removed when the session ends.
#'
#' @param outputId Output name.
#' @param width CSS width of the player.
#' @param expr An expression returning a scene or a file path.
#' @param env,quoted The environment of `expr`, and whether it is quoted.
#' @param ... [render()] arguments for the scene, such as `quality = "l"`
#'   (the default) or `format = "gif"`.
#' @param async Whether to render in a background R process, so the app
#'   keeps serving other sessions meanwhile (the session that asked waits
#'   for the result, as for any Shiny output). Needs the promises
#'   and future packages and a parallel future plan, such as
#'   `future::plan(future::multisession)`; the scene and the objects it
#'   refers to are copied to that process.
#' @return `manimOutput()` returns UI; `renderManim()` a render function.
#' @export
#' @examplesIf interactive() && requireNamespace("shiny", quietly = TRUE)
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
manimOutput <- function(outputId, width = "100%") {
  if (!requireNamespace("shiny", quietly = TRUE)) stop("manimOutput() needs the shiny package.", call. = FALSE)
  shiny::div(style = paste0("width:", width), shiny::uiOutput(outputId))
}

#' @rdname manimOutput
#' @export
renderManim <- function(expr, env = parent.frame(), quoted = FALSE, ..., async = FALSE) {
  if (!requireNamespace("shiny", quietly = TRUE)) stop("renderManim() needs the shiny package.", call. = FALSE)
  if (async && !(requireNamespace("promises", quietly = TRUE) && requireNamespace("future", quietly = TRUE))) {
    stop("renderManim(async = TRUE) needs the promises and future packages.", call. = FALSE)
  }
  func <- shiny::exprToFunction(expr, env, quoted)
  args <- list(...)
  if (is.null(args$quality)) args$quality <- "l"
  own_media <- is.null(args$media_dir)
  args$preview <- FALSE
  # Each output of each session shows its own copy of the rendered file, in
  # a folder only that session's pages are given, so outputs and sessions
  # never show each other's renders.
  output_id <- substr(digest::digest(list(Sys.time(), stats::runif(1)), algo = "xxhash64"), 1, 10)
  shown <- new.env(parent = emptyenv())
  show <- function(path, session) {
    if (is.null(path) || !file.exists(path) || dir.exists(path)) return(NULL)
    pub <- shiny_session_dir(session)
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
  }
  shiny::renderUI({
    x <- func()
    session <- shiny::getDefaultReactiveDomain()
    if (is.character(x)) return(show(unclass(x), session))
    if (own_media) args$media_dir <- file.path(shiny_session_dir(session)$media, output_id)
    if (!async) return(show(unclass(do.call(render, c(list(x), args))), session))
    job <- promises::future_promise(unclass(do.call(manimR::render, c(list(x), args))),
                                    globals = list(x = x, args = args), packages = "manimR", seed = TRUE)
    promises::then(job, function(path) show(path, session))
  })
}

# The folder that holds the files shown to one Shiny session, served under a
# resource path named after a hash of the session's token, and removed with
# it when the session ends.
shiny_session_dir <- function(session) {
  token <- if (is.null(session)) "no-session" else session$token
  prefix <- paste0("manimR-", substr(digest::digest(token, algo = "sha256"), 1, 16))
  dir <- file.path(tempdir(), "manimR-shiny-out", prefix)
  # Renders of the session's outputs; not served.
  media <- file.path(tempdir(), "manimR-shiny", prefix)
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    shiny::addResourcePath(prefix, dir)
    if (!is.null(session)) {
      session$onSessionEnded(function() {
        try(shiny::removeResourcePath(prefix), silent = TRUE)
        unlink(c(dir, media), recursive = TRUE)
      })
    }
  }
  list(dir = dir, prefix = prefix, media = media)
}
