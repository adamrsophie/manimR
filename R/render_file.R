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
#' Sourcing a script runs its code, but calls of [render()],
#' [render_file()], [manim_cli()], [preview_output()] and [manim_gadget()]
#' in it do nothing, so a script that ends with `render(MyScene)` is not
#' rendered twice by [render_file()], [manim_cli()] or the RStudio addins.
#'
#' @param file Path to an R script defining scenes.
#' @param envir Environment to search instead of a file.
#' @return A named list of scene class generators, in definition order.
#' @export
find_scenes <- function(file = NULL, envir = NULL) {
  if (!is.null(file)) {
    envir <- new.env(parent = globalenv())
    skip <- function(...) invisible(NULL)
    for (f in c("render", "render_file", "manim_cli", "preview_output", "manim_gadget")) assign(f, skip, envir = envir)
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
#' `NULL`), each with its own copy of the settings, as `manim render` does.
#' The script's name is the module name of the output directories
#' (`media/videos/<file name>/<quality>/`).
#'
#' @param file Path to an R script defining [Scene] subclasses.
#' @param scenes Scene class names; `NULL` renders all.
#' @param ... Passed to [render()], for example `quality = "l"`. An
#'   `output_file` can only be given when one scene is rendered.
#' @param found Named list of scene generators, as returned by
#'   [find_scenes()]; by default the scenes defined in `file`.
#' @return Output paths, invisibly.
#' @export
#' @examples
#' file <- tempfile(fileext = ".R")
#' writeLines(c(
#'   "library(manimR)",
#'   "SquareToCircle <- manim_scene(function(self) {",
#'   "  self$play(Transform(Square(), Circle()))",
#'   "})"), file)
#' # The last frame as a PNG file in the session's temporary directory.
#' render_file(file, "SquareToCircle", quality = "l", format = "png", media_dir = tempdir())
#' \dontrun{
#' # A video in the folder media of the working directory; this needs ffmpeg.
#' render_file(file, "SquareToCircle", quality = "l", preview = TRUE)
#' }
render_file <- function(file, scenes = NULL, ..., found = NULL) {
  found <- found %||% find_scenes(file)
  if (!length(found)) stop("No Scene subclasses found in ", file, call. = FALSE)
  if (is.null(scenes)) scenes <- names(found)
  missing <- setdiff(scenes, names(found))
  if (length(missing)) stop("Scene(s) not found in ", file, ": ", paste(missing, collapse = ", "), call. = FALSE)
  args <- list(...)
  out_name <- args$output_file %||% cfg("output_file")
  if (!is.null(out_name) && nzchar(out_name) && length(scenes) != 1) {
    stop("output_file can only be used when rendering exactly one scene. Remove write_all or select a single ",
         "scene.", call. = FALSE)
  }
  if (is.null(args$module_name)) args$input_file <- normalizePath(file, mustWork = FALSE)
  outs <- lapply(scenes, function(s) {
    message("Rendering ", s, " ...")
    do.call(render, c(list(found[[s]], scene_name = s), args))
  })
  invisible(unlist(outs))
}

# Options of manim_cli(): the flags, the setting each sets, and how the
# value is read ("flag" for switches, "int", "num", "str", or a function).
CLI_OPTIONS <- list(
  list(c("-c", "--config_file"), "config_file", "str"),
  list("--disable_caching", "disable_caching", "flag"),
  list("--flush_cache", "flush_cache", "flag"),
  list("--tex_template", "tex_template_file", "str"),
  list(c("-v", "--verbosity"), "verbosity", function(v) toupper(v)),
  list("--notify_outdated_version", "notify_outdated_version", "flag"),
  list("--silent", "notify_outdated_version", function() FALSE),
  list("--enable_gui", "enable_gui", "flag"),
  list("--gui_location", "gui_location", function(v) as.integer(strsplit(v, "[;,-]")[[1]])),
  list("--fullscreen", "fullscreen", "flag"),
  list("--enable_wireframe", "enable_wireframe", "flag"),
  list("--dry_run", "dry_run", "flag"),
  list("--no_latex_cleanup", "no_latex_cleanup", "flag"),
  list("--preview_command", "preview_command", "str"),
  list("--seed", "seed", "int"),
  list(c("-o", "--output_file"), "output_file", "str"),
  list(c("-0", "--zero_pad"), "zero_pad", "int"),
  list("--media_dir", "media_dir", "str"),
  list("--log_dir", "log_dir", "str"),
  list("--log_to_file", "log_to_file", "flag"),
  list(c("-a", "--write_all"), "write_all", "flag"),
  list("--format", "format", "str"),
  list(c("-s", "--save_last_frame"), "save_last_frame", "flag"),
  list(c("-q", "--quality"), "quality", "str"),
  list(c("-r", "--resolution"), "frame_size", function(v) {
    x <- suppressWarnings(as.integer(strsplit(v, "[;,-]")[[1]]))
    if (length(x) != 2 || anyNA(x)) stop("Resolution option is invalid; use W,H.", call. = FALSE)
    x
  }),
  list(c("--fps", "--frame_rate"), "frame_rate", function(v) {
    x <- suppressWarnings(as.numeric(v))
    if (is.na(x) || x <= 0) stop("--fps needs a positive number.", call. = FALSE)
    x
  }),
  list(c("--video-codec", "--video_codec"), "video_codec", "str"),
  list(c("--pixel-format", "--pixel_format"), "pixel_format", "str"),
  list(c("--encoder-option", "--encoder_option"), "video_encoder_options", "str"),
  list(c("--max-inflight-encoders", "--max_inflight_encoders"), "max_inflight_encoders", "int"),
  list(c("--encoder-queue-size", "--encoder_queue_size"), "encoder_queue_size", "int"),
  list("--renderer", "renderer", "str"),
  list("--save_sections", "save_sections", "flag"),
  list(c("-t", "--transparent"), "transparent", "flag"),
  list("--use_projection_fill_shaders", "use_projection_fill_shaders", "flag"),
  list("--use_projection_stroke_shaders", "use_projection_stroke_shaders", "flag"),
  list("--progress_bar", "progress_bar", function(v) {
    if (!v %in% c("display", "leave", "none")) stop("--progress_bar must be display, leave or none.", call. = FALSE)
    v != "none"
  }),
  list(c("-p", "--preview"), "preview", "flag"),
  list(c("-l", "--live-preview", "--live_preview"), "live_preview", "flag"),
  list("--show_in_file_browser", "show_in_file_browser", "flag"),
  list("--jupyter", "jupyter", "flag")
)

cli_option <- function(flag) {
  for (o in CLI_OPTIONS) if (flag %in% o[[1]]) return(o)
  NULL
}

# Asks which scenes to render, as upstream's prompt_user_for_choice().
prompt_scene_choice <- function(names, input = NULL) {
  for (i in seq_along(names)) cat(i, ": ", names[i], "\n", sep = "")
  cat(CHOOSE_NUMBER_MESSAGE)
  answer <- input %||% {
    con <- if (interactive()) stdin() else file("stdin")
    if (!interactive()) on.exit(close(con), add = TRUE)
    readLines(con, n = 1)
  }
  if (!length(answer)) stop("No scenes were selected. Exiting.", call. = FALSE)
  answer <- trimws(answer)
  if (identical(answer, "*")) return(names)
  idx <- suppressWarnings(as.integer(strsplit(answer, "\\s*,\\s*")[[1]]))
  if (!length(idx) || anyNA(idx)) stop("No scenes were selected. Exiting.", call. = FALSE)
  if (any(idx < 1 | idx > length(names))) stop(INVALID_NUMBER_MESSAGE, call. = FALSE)
  names[idx]
}

#' Command line entry point
#'
#' Mirrors `manim render` for use with `Rscript`:
#' `Rscript -e 'manimR::manim_cli()' scenes.R SceneName -ql -p`. FILE is an
#' R script (or a `.cfg` file whose `input_file` names the script), followed
#' by scene names; with no scene names a script with one scene renders it
#' and a script with several asks which to render (`-a` renders all).
#'
#' It takes upstream's options: `-c`/`--config_file`, `--disable_caching`,
#' `--tex_template`, `-v`/`--verbosity`, `--notify_outdated_version` and
#' `--silent`, `--enable_gui`, `--gui_location`, `--fullscreen`,
#' `--enable_wireframe`, `--dry_run`, `--no_latex_cleanup`,
#' `--preview_command`, `--seed`, `-o`/`--output_file`, `-0`/`--zero_pad`,
#' `--media_dir`, `--log_dir`, `--log_to_file`, `-n N[,M]` (render
#' animations N through M, counted from 0), `-a`/`--write_all`, `--format`,
#' `-s`/`--save_last_frame`, `-q`/`--quality` (also `-ql`, `-qm`, `-qh`,
#' `-qp`, `-qk`), `-r`/`--resolution W,H`, `--fps`/`--frame_rate`,
#' `--video-codec`, `--pixel-format`, `--encoder-option KEY=VALUE`
#' (repeatable), `--max-inflight-encoders`, `--encoder-queue-size`,
#' `--renderer`, `--save_sections`, `-t`/`--transparent`,
#' `--use_projection_fill_shaders`, `--use_projection_stroke_shaders`,
#' `--progress_bar`, `-p`/`--preview`, `-l`/`--live-preview`,
#' `--show_in_file_browser`, plus manimR's `--flush_cache`. Short flags can
#' be combined (`-pql`). A `manim.cfg` in the working directory is read
#' first unless `-c` names another file, and the command line wins over
#' both. The OpenGL window options are accepted; asking for a live preview
#' is an error, as with upstream's Cairo renderer. Options can also be
#' written `--name=value`, and `render` may come first, as in `manim render`.
#'
#' The other subcommands of `manim`:
#' * `checkhealth` reports the programs manimR uses ([manim_check()]).
#' * `cfg show` prints the config files read and every setting of
#'   [make_config_parser()]. `cfg write [-l user|cwd] [-o]` asks for each
#'   value (Enter keeps it) and writes the user wide file or `manim.cfg` in
#'   the working directory; `-o` opens the file instead of asking.
#'   `cfg export [-d DIR]` runs `cfg write` and copies its file into `DIR`.
#' * `init project [NAME] [-d]` asks for a template, the frame rate,
#'   background and resolution (`-d` takes upstream's defaults: 1920 x 1080
#'   at 30 fps) and creates `NAME` with `main.R` and `manim.cfg`.
#'   `init scene NAME [FILE]` asks for a template and appends it to `FILE`
#'   (`main.R`). See [get_template_names()].
#' * `plugins -l` lists installed plugins ([list_plugins()]).
#' * `cache clear FILE SCENE ...` deletes the partial movie files of those
#'   scenes, for the quality (`-q`), resolution (`-r W,H`), frame rate
#'   (`--fps`), media directory (`--media-dir`) and config file (`-c`)
#'   given.
#' * `--version` prints the version; every command starts with the same
#'   splash line unless `--hide-splash` is given.
#'
#' Outside an interactive session every prompt takes its default.
#'
#' @param args Character vector of arguments; defaults to the trailing
#'   command line arguments.
#' @return The result of the subcommand, invisibly.
#' @export
manim_cli <- function(args = commandArgs(trailingOnly = TRUE)) {
  usage <- paste("Usage: Rscript -e 'manimR::manim_cli()' FILE [SCENE ...] [OPTIONS]",
                 "See ?manim_cli for the options.\n")
  if (!length(args) || args[1] %in% c("-h", "--help")) {
    cat(usage)
    return(invisible(NULL))
  }
  # --name=value is --name value.
  args <- unlist(lapply(args, function(a) {
    if (grepl("^--[A-Za-z_-]+=", a)) c(sub("=.*$", "", a), sub("^[^=]*=", "", a)) else a
  }))
  if (args[1] %in% c("--version", "version")) {
    show_splash(TRUE)
    return(invisible(utils::packageVersion("manimR")))
  }
  # --show-splash (the default) and --hide-splash, as upstream's main group.
  splash <- !"--hide-splash" %in% args
  args <- args[!args %in% c("--show-splash", "--hide-splash")]
  if (!length(args)) {
    cat(usage)
    return(invisible(NULL))
  }
  show_splash(splash)
  if (args[1] %in% c("checkhealth", "cfg", "init", "plugins", "cache")) return(cli_subcommand(args))
  if (args[1] == "render") args <- args[-1]
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
  encoder_options <- list()
  i <- 1
  while (i <= length(expanded)) {
    a <- expanded[i]
    if (grepl("^-q[lmhpk]$", a)) {
      opts$quality <- substr(a, 3, 3)
    } else if (a %in% c("-n", "--from_animation_number")) {
      i <- i + 1
      v <- suppressWarnings(as.integer(strsplit(expanded[i] %||% "", "[;,-]")[[1]]))
      if (!length(v) || length(v) > 2 || anyNA(v)) stop("Couldn't determine a range for -n option.", call. = FALSE)
      opts$from_animation_number <- v[1]
      if (length(v) == 2) {
        opts$upto_animation_number <- v[2]
      } else {
        logger$info("No end scene number specified in -n option. Rendering from %d onwards...", v[1])
      }
    } else if (!is.null(o <- cli_option(a))) {
      kind <- o[[3]]
      if (identical(kind, "flag")) {
        value <- TRUE
      } else if (is.function(kind) && !length(formals(kind))) {
        value <- kind()
      } else {
        i <- i + 1
        if (i > length(expanded)) stop("Option ", a, " needs a value.", call. = FALSE)
        raw <- expanded[i]
        value <- if (is.function(kind)) kind(raw) else switch(kind, int = as.integer(raw), num = as.numeric(raw), raw)
        if (!is.function(kind) && kind %in% c("int", "num") && is.na(value)) {
          stop("Option ", a, " needs a number.", call. = FALSE)
        }
      }
      if (o[[2]] == "video_encoder_options") {
        kv <- regmatches(value, regexec("^([^=]+)=(.*)$", value))[[1]]
        if (!length(kv)) stop("--encoder-option needs KEY=VALUE.", call. = FALSE)
        encoder_options[[kv[2]]] <- kv[3]
      } else {
        opts[[o[[2]]]] <- value
      }
    } else if (startsWith(a, "-") && nchar(a) > 1) {
      stop("Unknown option '", a, "'. ", usage, call. = FALSE)
    } else {
      positional <- c(positional, a)
    }
    i <- i + 1
  }
  .manim$cli_running <- TRUE
  on.exit(.manim$cli_running <- FALSE, add = TRUE)
  if (isTRUE(opts$jupyter)) stop("--jupyter is for the Jupyter magic of Python manim; use the knitr engine instead.",
                                 call. = FALSE)
  if (length(encoder_options)) opts$video_encoder_options <- encoder_options
  if (!length(positional)) stop("No file given. ", usage, call. = FALSE)
  file <- positional[1]
  scene_names <- positional[-1]
  config_file <- opts$config_file
  opts$config_file <- NULL
  # A .cfg file as FILE is the config file, and names the script itself.
  if (tolower(tools::file_ext(file)) == "cfg") config_file <- file
  with_manim_config(list(), {
    if (!is.null(config_file)) {
      digest_config_file(config_file)
    } else if (file.exists("manim.cfg")) {
      digest_config_file("manim.cfg")
    }
    if (tolower(tools::file_ext(file)) == "cfg") {
      file <- cfg("input_file") %||% ""
      if (!nzchar(file)) stop("The config file does not set input_file.", call. = FALSE)
    }
    # Settings with a template go after media_dir, log_to_file last, as
    # upstream digests them.
    order_last <- c("media_dir", "log_dir", "log_to_file")
    first <- opts[setdiff(names(opts), order_last)]
    if (length(first)) do.call(manim_config, first)
    last <- opts[intersect(order_last, names(opts))]
    if (length(last)) do.call(manim_config, last)
    found <- find_scenes(file)
    if (!length(found)) stop(NO_SCENE_MESSAGE, call. = FALSE)
    if (isTRUE(cfg("write_all"))) {
      chosen <- names(found)
    } else {
      wanted <- if (length(scene_names)) scene_names else cfg("scene_names")
      for (n in setdiff(wanted, c(names(found), ""))) logger$error(sub("{}", n, SCENE_NOT_FOUND_MESSAGE, fixed = TRUE))
      chosen <- intersect(wanted, names(found))
      if (!length(chosen)) chosen <- if (length(found) == 1) names(found) else prompt_scene_choice(names(found))
    }
    manim_config(scene_names = chosen)
    out <- render_file(file, chosen, found = found)
  })
  for (o in out) cat("File ready at", o, "\n")
  invisible(out)
}

# The splash message of upstream's main group: the version, before any
# command.
show_splash <- function(value) {
  if (isTRUE(value)) cat("manimR v", as.character(utils::packageVersion("manimR")), "\n\n", sep = "")
  invisible(NULL)
}

cli_subcommand <- function(args) {
  cmd <- args[1]
  rest <- args[-1]
  opt <- function(names, default = NULL) {
    i <- which(rest %in% names)
    if (length(i) && i[1] < length(rest)) rest[i[1] + 1] else default
  }
  switch(cmd,
    checkhealth = {
      ok <- manim_check()
      invisible(ok)
    },
    cfg = {
      sub_cmd <- rest[1] %||% ""
      flag <- function(names) any(rest[-1] %in% names)
      switch(sub_cmd,
        show = cfg_show(),
        write = {
          level <- opt(c("-l", "--level"))
          if (!is.null(level)) {
            level <- tolower(level)
            if (!level %in% c("user", "cwd")) stop("Invalid value for '-l' / '--level': '", level,
                                                   "' is not one of 'user', 'cwd'.", call. = FALSE)
          }
          cfg_write(level, openfile = flag(c("-o", "--open")))
        },
        export = cfg_export(opt(c("-d", "--directory", "--dir"), ".")),
        stop("Use `cfg show`, `cfg write [-l user|cwd] [-o]` or `cfg export [-d DIR]`.", call. = FALSE)
      )
    },
    init = {
      what <- rest[1] %||% ""
      pos <- rest[-1][!startsWith(rest[-1], "-")]
      if (what == "project") {
        init_project(pos[1], default_settings = any(rest[-1] %in% c("-d", "--default")))
      } else if (what == "scene") {
        if (is.na(pos[1])) stop("init scene needs a SCENE name.", call. = FALSE)
        init_scene(pos[1], pos[2])
      } else {
        stop("Use `init project [NAME] [-d]` or `init scene NAME [FILE]`.", call. = FALSE)
      }
    },
    plugins = {
      if (!any(rest %in% c("-l", "--list"))) stop("Use `plugins -l` to list plugins.", call. = FALSE)
      list_plugins()
    },
    cache = {
      if (!identical(rest[1], "clear")) stop("Use `cache clear FILE SCENE ...`.", call. = FALSE)
      pos <- character()
      settings <- list()
      i <- 2
      while (i <= length(rest)) {
        a <- rest[i]
        if (a %in% c("-q", "--quality")) {
          settings$quality <- rest[i + 1]
          i <- i + 1
        } else if (a %in% c("--media-dir", "--media_dir")) {
          settings$media_dir <- rest[i + 1]
          i <- i + 1
        } else if (a %in% c("-c", "--config-file", "--config_file")) {
          settings$config_file <- rest[i + 1]
          i <- i + 1
        } else if (a %in% c("-r", "--resolution")) {
          wh <- as.integer(strsplit(rest[i + 1], "[;,-]")[[1]])
          if (length(wh) != 2 || anyNA(wh)) stop("Resolution must be given as 'W,H', 'W;H' or 'W-H'.", call. = FALSE)
          settings$pixel_width <- wh[1]
          settings$pixel_height <- wh[2]
          i <- i + 1
        } else if (a %in% c("--fps", "--frame-rate", "--frame_rate")) {
          settings$frame_rate <- as.numeric(rest[i + 1])
          i <- i + 1
        } else {
          pos <- c(pos, a)
        }
        i <- i + 1
      }
      if (length(pos) < 2) stop("cache clear needs FILE and at least one SCENE.", call. = FALSE)
      is_cfg <- tolower(tools::file_ext(pos[1])) == "cfg"
      config_file <- if (is_cfg) pos[1] else settings$config_file
      settings$config_file <- NULL
      with_manim_config(list(), {
        if (!is.null(config_file)) digest_config_file(config_file)
        input <- cfg("input_file")
        if (is.null(input) || !nzchar(input)) {
          if (is_cfg) stop("A configuration file must define input_file.", call. = FALSE)
          input <- pos[1]
        }
        if (length(settings)) do.call(manim_config, settings)
        module <- tools::file_path_sans_ext(basename(input))
        cleared <- vapply(pos[-1], function(scene) {
          dir <- get_dir("partial_movie_dir", module_name = module, scene_name = scene)
          n <- length(list.files(dir))
          unlink(dir, recursive = TRUE)
          cat("Removed ", n, " cached segment(s) for ", scene, " from ", dir, ".\n", sep = "")
          dir
        }, "")
        invisible(cleared)
      })
    }
  )
}
