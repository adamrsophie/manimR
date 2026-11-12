# Helpers of upstream's command line: manim/cli/cfg/group.py,
# manim/cli/init/commands.py, manim/utils/file_ops.py (templates) and
# manim/_config/utils.py (make_config_parser).

# Reads one answer to a prompt. readline() returns "" outside interactive
# sessions, which every prompt reads as "keep the default".
cli_input <- function(prompt = "") {
  if (interactive()) readline(prompt) else {
    cat(prompt)
    ""
  }
}

# A literal of Python's ast.literal_eval() for the scalars, tuples and lists
# a config value can hold. Returns list(value = ...) or NULL when `s` is not
# such a literal.
py_literal <- function(s) {
  s <- sub("[ \t\r\n]+$", "", sub("^[ \t]+", "", s))
  if (!nzchar(s)) return(NULL)
  parts <- py_split_top(s)
  if (is.null(parts)) return(NULL)
  if (length(parts) > 1) {
    empty <- !nzchar(trimws(parts))
    if (any(empty[-length(parts)])) return(NULL)
    items <- parts[!empty]
    vals <- lapply(items, py_literal)
    if (any(vapply(vals, is.null, NA))) return(NULL)
    return(list(value = structure(lapply(vals, `[[`, "value"), py_type = "tuple")))
  }
  open <- substr(s, 1, 1)
  close <- substr(s, nchar(s), nchar(s))
  if ((open == "(" && close == ")") || (open == "[" && close == "]")) {
    inner <- substr(s, 2, nchar(s) - 1)
    if (is.null(py_split_top(inner))) return(NULL)
    kind <- if (open == "(") "tuple" else "list"
    if (!nzchar(trimws(inner))) return(list(value = structure(list(), py_type = kind)))
    v <- py_literal(inner)
    if (is.null(v)) return(NULL)
    if (open == "(" && !identical(attr(v$value, "py_type"), "tuple")) return(v)
    val <- if (identical(attr(v$value, "py_type"), "tuple")) v$value else list(v$value)
    attr(val, "py_type") <- kind
    return(list(value = val))
  }
  if (s == "True") return(list(value = TRUE))
  if (s == "False") return(list(value = FALSE))
  if (s == "None") return(list(value = NULL))
  num <- gsub("_", "", s, fixed = TRUE)
  if (grepl("^[+-]?(0+|[1-9][0-9_]*)$", s)) {
    v <- as.numeric(num)
    return(list(value = if (abs(v) <= .Machine$integer.max) as.integer(v) else v))
  }
  if (grepl("^[+-]?0[xX][0-9a-fA-F_]+$", s)) {
    sign <- if (startsWith(s, "-")) -1L else 1L
    return(list(value = sign * strtoi(sub("^[+-]?0[xX]", "", num), 16L)))
  }
  if (grepl("^[+-]?([0-9][0-9_]*\\.[0-9_]*|\\.[0-9][0-9_]*|[0-9][0-9_]*)([eE][+-]?[0-9]+)?$", s) &&
      grepl("[.eE]", s)) {
    return(list(value = as.numeric(num)))
  }
  q <- substr(s, 1, 1)
  if (q %in% c("'", "\"") && nchar(s) >= 2 && substr(s, nchar(s), nchar(s)) == q) {
    body <- substr(s, 2, nchar(s) - 1)
    if (grepl(paste0("(^|[^\\\\])(\\\\\\\\)*", q), body)) return(NULL)
    body <- gsub("\\\\n", "\n", gsub("\\\\t", "\t", body))
    return(list(value = gsub("\\\\(.)", "\\1", body)))
  }
  NULL
}

# Splits `s` at the commas outside quotes and brackets; NULL when the
# brackets or quotes do not balance.
py_split_top <- function(s) {
  ch <- strsplit(s, "")[[1]]
  depth <- 0L
  quote <- ""
  start <- 1L
  out <- character()
  i <- 1L
  while (i <= length(ch)) {
    c1 <- ch[i]
    if (nzchar(quote)) {
      if (c1 == "\\") i <- i + 1L
      else if (c1 == quote) quote <- ""
    } else if (c1 %in% c("'", "\"")) {
      quote <- c1
    } else if (c1 %in% c("(", "[", "{")) {
      depth <- depth + 1L
    } else if (c1 %in% c(")", "]", "}")) {
      depth <- depth - 1L
      if (depth < 0L) return(NULL)
    } else if (c1 == "," && depth == 0L) {
      out <- c(out, if (start <= i - 1L) paste(ch[start:(i - 1L)], collapse = "") else "")
      start <- i + 1L
    }
    i <- i + 1L
  }
  if (depth != 0L || nzchar(quote)) return(NULL)
  c(out, if (start <= length(ch)) paste(ch[start:length(ch)], collapse = "") else "")
}

py_type_of <- function(x) {
  if (is.null(x)) "NoneType"
  else if (is.list(x)) attr(x, "py_type") %||% "list"
  else if (is.logical(x)) "bool"
  else if (is.integer(x)) "int"
  else if (is.double(x)) "float"
  else "str"
}

#' Command line helpers of `manim cfg` and `manim init`
#'
#' The helpers behind the prompts of `manim cfg write` and `manim init`
#' ([manim_cli()]), as upstream's `manim.cli.cfg.group` and
#' `manim.cli.init.commands`.
#'
#' * `value_from_string(value)` reads a config value as a Python literal:
#'   `"5"` is `5L`, `"1.5"` is `1.5`, `"True"` is `TRUE`, `"0,0"` a list of
#'   two integers; anything else (`"BLACK"`, `"60%"`) stays a string.
#' * `replace_keys(default)` swaps `_` and `.` in the names, as the logger
#'   section is shown to the user.
#' * `select_resolution()` asks for a resolution among the qualities and
#'   returns `c(height, width)` (default `480p`).
#' * `update_cfg(cfg_dict, project_cfg_path)` sets `[CLI]` keys of a
#'   `manim.cfg`; `resolution` sets `pixel_height` and `pixel_width`.
#'
#' Outside an interactive session every prompt takes its default.
#'
#' @param value A string.
#' @param default A named list or vector.
#' @param cfg_dict Named list of settings.
#' @param project_cfg_path Path of a `manim.cfg`.
#' @return `value_from_string()` the literal; `replace_keys()` `default`
#'   renamed; `select_resolution()` an integer vector; `update_cfg()` the
#'   path, invisibly.
#' @export
#' @examples
#' value_from_string("60")
#' value_from_string("0,0")
#' value_from_string("BLACK")
#' replace_keys(list(log_width = "-1", logging.keyword = "bold yellow"))
#' select_resolution()
#' f <- tempfile(fileext = ".cfg")
#' writeLines(c("[CLI]", "frame_rate = 60"), f)
#' update_cfg(list(frame_rate = 30, resolution = c(480, 854)), f)
#' readLines(f)
value_from_string <- function(value) {
  lit <- py_literal(value)
  if (is.null(lit)) value else lit$value
}

#' @rdname value_from_string
#' @export
replace_keys <- function(default) {
  n <- names(default)
  names(default) <- ifelse(grepl("_", n, fixed = TRUE), gsub("_", ".", n, fixed = TRUE), gsub(".", "_", n, fixed = TRUE))
  default
}

# Upstream's _is_expected_datatype(): the literal of `value` is an instance
# of the type of the literal of `expected` (a bool is an int, as in Python).
# Styles are not validated: there is no rich console in R.
is_expected_datatype <- function(value, expected, validate_style = FALSE) {
  got <- py_type_of(value_from_string(value))
  want <- py_type_of(value_from_string(expected))
  ok <- got == want || (got == "bool" && want == "int")
  if (validate_style) ok && got == "str" else ok
}

#' @rdname value_from_string
#' @export
select_resolution <- function() {
  q <- QUALITIES[-length(QUALITIES)]
  opts <- lapply(q, function(x) c(x$pixel_height, x$pixel_width))
  labels <- vapply(opts, function(o) paste0(o[1], "p"), "")
  repeat {
    choice <- cli_input(paste0("\nSelect resolution:\n (", paste(labels, collapse = ", "), "): "))
    if (!nzchar(choice)) choice <- "480p"
    if (choice %in% labels) break
    cat("Error: '", choice, "' is not one of ", paste(sprintf("'%s'", labels), collapse = ", "), ".\n", sep = "")
  }
  as.integer(opts[[match(choice, labels)]])
}

#' @rdname value_from_string
#' @export
update_cfg <- function(cfg_dict, project_cfg_path) {
  parser <- if (file.exists(project_cfg_path)) read_cfg_file(project_cfg_path) else list()
  cli <- parser[["CLI"]] %||% list()
  for (key in names(cfg_dict)) {
    value <- cfg_dict[[key]]
    if (key == "resolution") {
      cli[["pixel_height"]] <- as.character(value[1])
      cli[["pixel_width"]] <- as.character(value[2])
    } else {
      cli[[key]] <- py_str(value)
    }
  }
  parser[["CLI"]] <- cli
  write_cfg_parser(parser, project_cfg_path)
}

# str() of a Python value, for values written to a config file.
py_str <- function(x) {
  if (is.logical(x)) return(if (isTRUE(x)) "True" else "False")
  if (is.numeric(x) && length(x) > 1) return(paste0("(", paste(x, collapse = ", "), ")"))
  as.character(x)
}

# Writes parsed sections as configparser.write() does: "key = value" lines,
# a blank line after each section, and % written as %%.
write_cfg_parser <- function(parser, path) {
  lines <- unlist(lapply(names(parser), function(sec) {
    v <- parser[[sec]]
    c(paste0("[", sec, "]"),
      vapply(names(v), function(k) paste0(k, " = ", gsub("%", "%%", gsub("\n", "\n\t", v[[k]], fixed = TRUE), fixed = TRUE)), ""),
      "")
  }))
  writeLines(lines, path)
  invisible(path)
}

#' Config parser of the library, user and folder files
#'
#' `make_config_parser()` reads upstream's library wide `default.cfg`
#' (shipped with manimR), then the user wide file and the folder wide
#' `manim.cfg` (or `custom_file`), each overriding the keys it sets, as
#' upstream's `make_config_parser()` does. The result has one element per
#' section, each a named list of strings, with `%%` read as `%`.
#'
#' @param custom_file A `.cfg` file read instead of the folder wide one.
#' @return A named list of sections.
#' @export
#' @examples
#' p <- make_config_parser()
#' names(p)
#' p$CLI$frame_rate
make_config_parser <- function(custom_file = NULL) {
  paths <- config_file_paths()
  parser <- read_cfg_file(paths[["library_wide"]])
  for (f in c(paths[["user_wide"]], custom_file %||% paths[["folder_wide"]])) {
    if (file.exists(f) && !dir.exists(f)) {
      more <- read_cfg_file(f)
      for (sec in names(more)) {
        cur <- parser[[sec]] %||% list()
        for (k in names(more[[sec]])) cur[[k]] <- more[[sec]][[k]]
        parser[[sec]] <- cur
      }
    }
  }
  parser
}

# The style free logger entries of upstream's cfg writer.
RICH_NON_STYLE_ENTRIES <- c("log.width", "log.height", "log.timestamps")

# `manim cfg write`: asks for every value of the merged config and writes it
# to the user wide file or to manim.cfg in the working directory.
cfg_write <- function(level = NULL, openfile = FALSE) {
  paths <- config_file_paths()
  cat("Manim Configuration File Writer\n")
  parser <- make_config_parser()
  if (!openfile) {
    action <- "save this as"
    for (category in names(parser)) {
      cat(category, "\n", sep = "")
      default <- parser[[category]]
      if (category == "logger") default <- replace_keys(default)
      for (key in names(default)) {
        style <- category == "logger" && !key %in% RICH_NON_STYLE_ENTRIES
        desc <- if (style) "style" else "value"
        prompt <- paste0("Enter the ", desc, " for ", key, " ")
        if (!style) {
          val <- default[[key]]
          shown <- if (is.character(value_from_string(val))) paste0("'", val, "'") else val
          prompt <- paste0(prompt, "(defaults to ", shown, ") :")
        }
        temp <- cli_input(prompt)
        if (nzchar(temp)) {
          while (nzchar(temp) && !is_expected_datatype(temp, default[[key]], style)) {
            cat("Invalid ", desc, ". Try again.\n", sep = "")
            temp <- cli_input(paste0("Enter the ", desc, " for ", key, ":"))
          }
          if (nzchar(temp)) default[[key]] <- temp
        }
      }
      if (category == "logger") default <- replace_keys(default)
      parser[[category]] <- default
    }
  } else {
    action <- "open"
  }
  answer <- if (is.null(level)) {
    cli_input(paste0("Do you want to ", action, " the default config for this User?(y/n)[n]"))
  } else ""
  if (tolower(answer) == "y" || identical(level, "user")) {
    path <- paths[["user_wide"]]
    guarantee_existence(dirname(path))
    cat("A configuration file at ", path, " has been created with your required changes.\n",
        "This will be used when running the manim command. If you want to override this config,\n",
        "you will have to create a manim.cfg in the local directory, where you want those changes to be overridden.\n",
        sep = "")
  } else {
    path <- paths[["folder_wide"]]
    cat("A configuration file at ", path, " has been created.\n",
        "To save your config please save that file and place it in your current working directory, ",
        "from where you run the manim command.\n", sep = "")
  }
  write_cfg_parser(parser, path)
  if (openfile) open_file(path)
  invisible(path)
}

# `manim cfg show`: the files read, then every section of the merged config.
cfg_show <- function() {
  cat("CONFIG FILES READ\n")
  for (p in config_file_paths()) if (file.exists(p)) cat(p, "\n", sep = "")
  cat("\n")
  parser <- make_config_parser()
  for (category in names(parser)) {
    cat(category, "\n", sep = "")
    for (entry in names(parser[[category]])) cat(entry, " : ", parser[[category]][[entry]], "\n", sep = "")
    cat("\n\n")
  }
  invisible(parser)
}

# `manim cfg export`: runs `cfg write` and copies the file it wrote into
# `directory`. Upstream prints the export message without copying.
cfg_export <- function(directory = ".") {
  same <- grepl("^(/|[A-Za-z]:)", directory) &&
    normalizePath(directory, mustWork = FALSE) == normalizePath(getwd())
  proceed <- TRUE
  if (same) {
    proceed <- tolower(cli_input(paste0(
      "You are reading the config from the same directory you are exporting to.\n",
      "This means that the exported config will overwrite the config for this directory.\n",
      "Are you sure you want to continue? (y/n)"))) == "y"
  }
  if (!proceed) {
    cat("Aborted...\n")
    return(invisible(NULL))
  }
  if (!dir.exists(directory)) {
    cat("Creating folder: ", directory, ".\n", sep = "")
    dir.create(directory, recursive = TRUE)
  }
  from <- cfg_write()
  to <- file.path(directory, "manim.cfg")
  if (normalizePath(from, mustWork = FALSE) != normalizePath(to, mustWork = FALSE)) file.copy(from, to, overwrite = TRUE)
  cat("Exported final Config at ", normalizePath(from), " to ", normalizePath(to), ".\n", sep = "")
  invisible(to)
}

# Upstream's CFG_DEFAULTS of `manim init project`.
CFG_DEFAULTS <- list(frame_rate = 30L, background_color = "BLACK", background_opacity = 1L,
                     scene_names = "Default", resolution = c(1080L, 1920L))

# Prompts as click.prompt() with a default: an empty answer is the default,
# and the answer takes the type of the default.
prompt_default <- function(text, default) {
  ans <- cli_input(paste0(text, " [", py_str(default), "]: "))
  if (!nzchar(ans)) return(default)
  if (is.integer(default)) {
    v <- suppressWarnings(as.integer(ans))
    if (!is.na(v) && grepl("^[+-]?[0-9]+$", ans)) return(v)
  } else if (is.double(default)) {
    v <- suppressWarnings(as.numeric(ans))
    if (!is.na(v)) return(v)
  } else {
    return(ans)
  }
  stop("Error: '", ans, "' is not a valid ", if (is.integer(default)) "integer" else "float", ".", call. = FALSE)
}

prompt_choice <- function(text, choices, default) {
  repeat {
    ans <- cli_input(paste0(text, " (", paste(choices, collapse = ", "), ") [", default, "]: "))
    if (!nzchar(ans)) ans <- default
    hit <- choices[tolower(choices) == tolower(ans)]
    if (length(hit)) return(hit[1])
    cat("Error: '", ans, "' is not one of ", paste(sprintf("'%s'", choices), collapse = ", "), ".\n", sep = "")
  }
}

# `manim init project`.
init_project <- function(project_name = NULL, default_settings = FALSE) {
  if (is.null(project_name) || is.na(project_name)) project_name <- cli_input("Project Name: ")
  if (!nzchar(project_name)) stop("init project needs a PROJECT_NAME.", call. = FALSE)
  template_name <- prompt_choice("Template", get_template_names(), "Default")
  if (dir.exists(project_name)) {
    cat("\nFolder ", project_name, " exists. Please type another name\n\n", sep = "")
    return(invisible(NULL))
  }
  dir.create(project_name, recursive = TRUE)
  new_cfg_path <- file.path(normalizePath(project_name), "manim.cfg")
  if (!default_settings) {
    new_cfg <- list()
    for (key in names(CFG_DEFAULTS)) {
      new_cfg[[key]] <- if (key == "scene_names") paste0(template_name, "Template")
                        else if (key == "resolution") select_resolution()
                        else prompt_default(paste0("\n", key), CFG_DEFAULTS[[key]])
    }
    utils::str(new_cfg)
    ans <- cli_input("Do you want to continue? [Y/n]: ")
    if (nzchar(ans) && !tolower(ans) %in% c("y", "yes")) stop("Aborted!", call. = FALSE)
    copy_template_files(project_name, template_name)
    update_cfg(new_cfg, new_cfg_path)
  } else {
    copy_template_files(project_name, template_name)
    update_cfg(CFG_DEFAULTS, new_cfg_path)
  }
  invisible(normalizePath(project_name))
}

# `manim init scene`.
init_scene <- function(scene_name, file_name = NULL) {
  template_name <- prompt_choice("template", get_template_names(), "Default")
  scene <- paste(readLines(file.path(get_template_path(), paste0(template_name, ".mtp")), warn = FALSE), collapse = "\n")
  scene <- sub(paste0(template_name, "Template"), scene_name, scene, fixed = TRUE)
  scene <- sub(paste0("\"", template_name, "Template\""), paste0("\"", scene_name, "\""), scene, fixed = TRUE)
  if (!is.null(file_name) && !is.na(file_name)) {
    if (!grepl("\\.[Rr]$", file_name)) file_name <- paste0(file_name, ".R")
    if (file.exists(file_name)) {
      cat("\n\n\n", scene, "\n", file = file_name, append = TRUE, sep = "")
    } else {
      cat("\n\n\n", scene, "\n", file = file_name, sep = "")
      add_import_statement(file_name)
    }
  } else {
    file_name <- "main.R"
    cat("\n\n\n", scene, "\n", file = file_name, append = TRUE, sep = "")
  }
  invisible(file_name)
}

#' Scene templates
#'
#' The templates of `manim init` (upstream's `manim/templates`), written in
#' R: `Default`, `Axes` and `MovingCamera`.
#'
#' * `get_template_path()` is the folder of the templates.
#' * `get_template_names()` lists them.
#' * `copy_template_files(project_dir, template_name)` copies the template
#'   `manim.cfg` and the scene, as `main.R`, into `project_dir`. Unlike
#'   upstream, `project_dir` has no default, so nothing is written to the
#'   working directory unless asked.
#' * `add_import_statement(file)` puts `library(manimR)` on the first line
#'   of `file`.
#'
#' @param project_dir Folder to copy into.
#' @param template_name One of `get_template_names()`.
#' @param file Path of an R file.
#' @return `get_template_path()` a path; `get_template_names()` a character
#'   vector; the others `NULL`, invisibly.
#' @export
#' @examples
#' get_template_names()
#' d <- tempfile()
#' dir.create(d)
#' copy_template_files(d, "Axes")
#' readLines(file.path(d, "main.R"))
get_template_path <- function() {
  system.file("templates", package = "manimR", mustWork = TRUE)
}

#' @rdname get_template_path
#' @export
get_template_names <- function() {
  tools::file_path_sans_ext(list.files(get_template_path(), "\\.mtp$"))
}

#' @rdname get_template_path
#' @export
add_import_statement <- function(file) {
  content <- readLines(file, warn = FALSE)
  writeLines(c("library(manimR)", content), file)
  invisible(NULL)
}

#' @rdname get_template_path
#' @export
copy_template_files <- function(project_dir, template_name = "Default") {
  cfg_path <- file.path(get_template_path(), "template.cfg")
  scene_path <- file.path(get_template_path(), paste0(template_name, ".mtp"))
  if (!file.exists(cfg_path)) stop(cfg_path, " : file does not exist", call. = FALSE)
  if (!file.exists(scene_path)) stop(scene_path, " : file does not exist", call. = FALSE)
  file.copy(cfg_path, file.path(project_dir, "manim.cfg"), overwrite = TRUE)
  cat("\n\tcopied manim.cfg\n\n")
  file.copy(scene_path, file.path(project_dir, "main.R"), overwrite = TRUE)
  cat("\n\tcopied main.R\n\n")
  add_import_statement(file.path(project_dir, "main.R"))
  invisible(NULL)
}
