# Rendering scenes defined in script files, the R counterpart of
# `manim render file.py SceneName`.

is_scene_generator <- function(x) {
  if (!inherits(x, "R6ClassGenerator")) return(FALSE)
  g <- x
  for (i in 1:50) {
    if (identical(g, Scene)) return(TRUE)
    g <- tryCatch(g$get_inherit(), error = function(e) NULL)
    if (is.null(g)) return(FALSE)
  }
  FALSE
}

#' Find scenes defined in a file or environment
#'
#' @param file Path to an R script defining scenes.
#' @param envir Environment to search instead of a file.
#' @return A named list of scene class generators, in definition order.
#' @export
find_scenes <- function(file = NULL, envir = NULL) {
  if (!is.null(file)) {
    envir <- new.env(parent = globalenv())
    sys.source(file, envir = envir, keep.source = FALSE)
  }
  nms <- ls(envir)
  scenes <- Filter(function(n) is_scene_generator(get(n, envir = envir)), nms)
  if (!is.null(file)) {
    src <- readLines(file, warn = FALSE)
    pos <- vapply(scenes, function(n) {
      hit <- grep(paste0("^\\s*`?", n, "`?\\s*(<-|=)"), src)
      if (length(hit)) hit[1] else .Machine$integer.max
    }, integer(1))
    scenes <- scenes[order(pos)]
  }
  stats::setNames(lapply(scenes, get, envir = envir), scenes)
}

#' Render scenes from a script
#'
#' Sources `file` and renders the named scenes (all scenes when `scenes` is
#' `NULL`). Output goes to `media/videos/<file name>/<quality>/`.
#'
#' @param file Path to an R script defining [Scene] subclasses.
#' @param scenes Scene class names; `NULL` renders all.
#' @param ... Passed to [render()], for example `quality = "l"`.
#' @param found Named list of scene generators, as returned by
#'   [find_scenes()]; by default the scenes defined in `file`.
#' @return Output paths, invisibly.
#' @export
#' @examples
#' \dontrun{
#' render_file("scenes.R", "SquareToCircle", quality = "l", preview = TRUE)
#' }
render_file <- function(file, scenes = NULL, ..., found = NULL) {
  found <- found %||% find_scenes(file)
  if (!length(found)) stop("No Scene subclasses found in ", file, call. = FALSE)
  if (is.null(scenes)) scenes <- names(found)
  missing <- setdiff(scenes, names(found))
  if (length(missing)) stop("Scene(s) not found in ", file, ": ", paste(missing, collapse = ", "), call. = FALSE)
  module <- tools::file_path_sans_ext(basename(file))
  outs <- lapply(scenes, function(s) {
    message("Rendering ", s, " ...")
    render(found[[s]], module_name = module, scene_name = s, ...)
  })
  invisible(unlist(outs))
}

#' Command line entry point
#'
#' Mirrors `manim render` for use with `Rscript`:
#' `Rscript -e 'manimR::manim_cli()' scenes.R SceneName -ql -p`.
#' Flags: `-ql`, `-qm`, `-qh`, `-qp`, `-qk` (quality), `-s` (save last frame
#' only), `-t` (transparent), `--format gif`, `-o file`, `-p` (preview),
#' `--save_sections` (also write one video per section), `-n N` or `-n N,M`
#' (render animations N through M, counted from 0 as upstream does),
#' `-r W,H` (resolution in pixels), `--fps FPS`, `--disable_caching` (render
#' every animation again) and `--flush_cache` (delete cached partial movie
#' files first).
#'
#' @param args Character vector of arguments; defaults to the trailing
#'   command line arguments.
#' @export
manim_cli <- function(args = commandArgs(trailingOnly = TRUE)) {
  usage <- paste("Usage: Rscript -e 'manimR::manim_cli()' FILE [SCENE ...] [-ql|-qm|-qh|-qp|-qk]",
                 "[-q QUALITY] [-a] [-s] [-t] [-p] [-n N[,M]] [-r W,H] [--fps FPS] [--save_sections]",
                 "[--disable_caching] [--flush_cache]",
                 "[--format FMT] [-o OUT]\n")
  if (!length(args)) {
    cat(usage)
    return(invisible(NULL))
  }
  # Expand clustered short flags such as -pql into -p -ql, like manim's CLI.
  expanded <- character()
  for (a in args) {
    if (grepl("^-[a-z]{2,}$", a) && !grepl("^-q[lmhpk]$", a)) {
      chars <- strsplit(substring(a, 2), "")[[1]]
      k <- 1
      while (k <= length(chars)) {
        if (chars[k] == "q" && k < length(chars)) {
          expanded <- c(expanded, paste0("-q", chars[k + 1]))
          k <- k + 2
        } else {
          expanded <- c(expanded, paste0("-", chars[k]))
          k <- k + 1
        }
      }
    } else {
      expanded <- c(expanded, a)
    }
  }
  opts <- list()
  positional <- character()
  all_scenes <- FALSE
  i <- 1
  while (i <= length(expanded)) {
    a <- expanded[i]
    if (grepl("^-q[lmhpk]$", a)) {
      opts$quality <- substr(a, 3, 3)
    } else if (a %in% c("-q", "--quality")) {
      i <- i + 1
      # A flag or a preset name such as low_quality; manim_config() checks it.
      opts$quality <- expanded[i]
    } else if (a %in% c("-s", "--save_last_frame")) {
      opts$save_last_frame <- TRUE
      opts$write_to_movie <- FALSE
    } else if (a %in% c("-n", "--from_animation_number")) {
      i <- i + 1
      v <- suppressWarnings(as.integer(strsplit(expanded[i] %||% "", "[;,-]")[[1]]))
      if (!length(v) || length(v) > 2 || anyNA(v)) stop("Couldn't determine a range for -n option.", call. = FALSE)
      opts$from_animation_number <- v[1]
      if (length(v) == 2) opts$upto_animation_number <- v[2]
    } else if (a %in% c("-r", "--resolution")) {
      i <- i + 1
      v <- suppressWarnings(as.integer(strsplit(expanded[i] %||% "", "[;,-]")[[1]]))
      if (length(v) != 2 || anyNA(v)) stop("Resolution option is invalid; use W,H.", call. = FALSE)
      opts$pixel_width <- v[1]
      opts$pixel_height <- v[2]
    } else if (a %in% c("--fps", "--frame_rate")) {
      i <- i + 1
      opts$frame_rate <- suppressWarnings(as.numeric(expanded[i] %||% NA))
      if (is.na(opts$frame_rate) || opts$frame_rate <= 0) stop("--fps needs a positive number.", call. = FALSE)
    } else if (a == "--disable_caching") {
      opts$disable_caching <- TRUE
    } else if (a == "--flush_cache") {
      opts$flush_cache <- TRUE
    } else if (a == "--save_sections") {
      opts$save_sections <- TRUE
    } else if (a %in% c("-t", "--transparent")) {
      opts$transparent <- TRUE
    } else if (a %in% c("-p", "--preview")) {
      opts$preview <- TRUE
    } else if (a %in% c("-a", "--write_all")) {
      all_scenes <- TRUE
    } else if (a == "--format") {
      i <- i + 1
      opts$format <- expanded[i]
    } else if (a %in% c("-o", "--output_file")) {
      i <- i + 1
      opts$output_file <- expanded[i]
    } else if (startsWith(a, "-")) {
      stop("Unknown option '", a, "'. ", usage, call. = FALSE)
    } else {
      positional <- c(positional, a)
    }
    i <- i + 1
  }
  if (!length(positional)) stop("No file given. ", usage, call. = FALSE)
  file <- positional[1]
  scenes <- if (length(positional) > 1 && !all_scenes) positional[-1] else NULL
  out <- do.call(render_file, c(list(file, scenes), opts))
  for (o in out) cat("File ready at", o, "\n")
  invisible(out)
}
