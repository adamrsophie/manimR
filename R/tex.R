# LaTeX rendering: Tex, MathTex and TexTemplate.
# Ported from manim/mobject/text/tex_mobject.py, manim/utils/tex.py and
# manim/utils/tex_file_writing.py.

MATHTEX_SUBSTRING <- "substring"
DEFAULT_TEX_PREAMBLE <- "\\usepackage[english]{babel}\n\\usepackage{amsmath}\n\\usepackage{amssymb}"

#' @title TexTemplate
#' @description A LaTeX document template used by [Tex()] and [MathTex()].
#'   Change the default with `manim_config(tex_template = TexTemplate(...))`.
#'   Two templates are `==` when every field matches, as upstream's dataclass
#'   equality.
#' @param tex_compiler Compiler, `"latex"` by default (or `"xelatex"`, `"lualatex"`).
#' @param output_format `".dvi"` (latex), `".xdv"` (xelatex) or `".pdf"`.
#' @param documentclass The `\documentclass` line.
#' @param preamble Preamble between the document class and `\begin{document}`.
#' @param placeholder_text Text replaced by the expression.
#' @param post_doc_commands Commands right after `\begin{document}`.
#' @param description A description.
#' @export
#' @examples
#' tpl <- TexTemplate()
#' tpl$add_to_preamble("\\usepackage{mathrsfs}")
TexTemplateClass <- R6::R6Class("TexTemplate", lock_objects = FALSE,
  public = list(
    tex_compiler = "latex",
    output_format = ".dvi",
    documentclass = "\\documentclass[preview]{standalone}",
    preamble = DEFAULT_TEX_PREAMBLE,
    placeholder_text = "YourTextHere",
    post_doc_commands = "",
    description = "",
    custom_body = NULL,
    initialize = function(tex_compiler = "latex", description = "", output_format = ".dvi",
                          documentclass = "\\documentclass[preview]{standalone}", preamble = DEFAULT_TEX_PREAMBLE,
                          placeholder_text = "YourTextHere", post_doc_commands = "") {
      self$tex_compiler <- tex_compiler
      self$output_format <- output_format
      self$documentclass <- documentclass
      self$preamble <- preamble
      self$placeholder_text <- placeholder_text
      self$post_doc_commands <- post_doc_commands
      self$description <- description
    },
    body = function() {
      if (!is.null(self$custom_body)) return(self$custom_body)
      paste(Filter(nzchar, c(self$documentclass, self$preamble, "\\begin{document}", self$post_doc_commands,
                             self$placeholder_text, "\\end{document}")), collapse = "\n")
    },
    set_body = function(body) {
      self$custom_body <- body
      invisible(self)
    },
    add_to_preamble = function(txt, prepend = FALSE) {
      if (!is.null(self$custom_body) && nzchar(self$custom_body)) {
        warning("This TeX template was created with a fixed body, trying to add text the preamble will have no effect.", call. = FALSE)
      }
      self$preamble <- if (prepend) paste(txt, self$preamble, sep = "\n") else paste(self$preamble, txt, sep = "\n")
      invisible(self)
    },
    add_to_document = function(txt) {
      if (!is.null(self$custom_body) && nzchar(self$custom_body)) {
        warning("This TeX template was created with a fixed body, trying to add text the document will have no effect.", call. = FALSE)
      }
      self$post_doc_commands <- paste0(self$post_doc_commands, txt)
      invisible(self)
    },
    get_texcode_for_expression = function(expression) {
      gsub(self$placeholder_text, expression, self$body(), fixed = TRUE)
    },
    get_texcode_for_expression_in_env = function(expression, environment) {
      env <- texcode_for_environment(environment)
      gsub(self$placeholder_text, paste(env$begin, expression, env$end, sep = "\n"), self$body(), fixed = TRUE)
    },
    copy = function() self$clone(deep = TRUE)
  )
)

#' @return A `TexTemplate`, an R6 object. `TexTemplateClass` is its R6 class
#'   generator.
#' @rdname TexTemplateClass
#' @export
TexTemplate <- constructor(TexTemplateClass)

# The dataclass equality of upstream's TexTemplate: same class and the same
# fields, in order.
TEX_TEMPLATE_FIELDS <- c("custom_body", "tex_compiler", "description", "output_format", "documentclass", "preamble",
                         "placeholder_text", "post_doc_commands")

#' @export
Ops.TexTemplate <- function(e1, e2) {
  if (!.Generic %in% c("==", "!=")) stop("`", .Generic, "` is not defined for a TexTemplate", call. = FALSE)
  fields <- function(t) lapply(TEX_TEMPLATE_FIELDS, function(f) .subset2(t, f) %||% "")
  same <- identical(class(e1), class(e2)) && identical(fields(e1), fields(e2))
  if (.Generic == "==") same else !same
}
texcode_for_environment <- function(environment) {
  env <- sub("^\\\\begin", "", environment)
  env <- sub("^\\{", "", env)
  begin <- paste0("\\begin{", env)
  if (!grepl("[]}]$", begin)) begin <- paste0(begin, "}")
  end <- paste0("\\end{", strsplit(env, "}", fixed = TRUE)[[1]][1], "}")
  list(begin = begin, end = end)
}

# The template of the tex_template setting, else one read from
# tex_template_file, else the default template (upstream's
# config.tex_template).
default_tex_template <- function() {
  tpl <- cfg("tex_template")
  if (!is.null(tpl)) return(tpl)
  file <- cfg("tex_template_file")
  if (!is.null(file) && nzchar(file)) {
    if (!identical(.manim$tex_template_file, file)) {
      .manim$tex_template_from_file <- TexTemplateClass$from_file(file)
      .manim$tex_template_file <- file
    }
    return(.manim$tex_template_from_file)
  }
  if (is.null(.manim$default_tex_template)) .manim$default_tex_template <- TexTemplate()
  .manim$default_tex_template
}

tex_dir <- function() get_dir("tex_dir") %||% file.path(cfg("media_dir") %||% "media", "Tex")

# Deletes every file in the tex directory that is not an .svg or .tex file,
# as upstream's delete_nonsvg_files(); runs unless no_latex_cleanup is set.
delete_nonsvg_files <- function(additional_endings = character()) {
  keep <- c(".svg", ".tex", additional_endings)
  files <- list.files(tex_dir(), full.names = TRUE)
  ends <- paste0(".", tools::file_ext(files))
  unlink(files[!ends %in% keep & !dir.exists(files)])
  invisible(NULL)
}

tex_hash <- function(expression) substr(digest::digest(expression, algo = "sha256", serialize = FALSE), 1, 16)

#' Compile LaTeX to SVG
#'
#' Writes the expression into the template, compiles it and converts the
#' result with `dvisvgm`, caching files in the `tex_dir` setting (`media/Tex`). The
#' .aux, .dvi and .log files are deleted afterwards unless
#' `manim_config(no_latex_cleanup = TRUE)`.
#'
#' @param expression LaTeX code.
#' @param environment Optional environment such as `"align*"`.
#' @param tex_template A [TexTemplate()].
#' @return Path to the SVG file.
#' @export
tex_to_svg_file <- function(expression, environment = NULL, tex_template = NULL) {
  tpl <- tex_template %||% default_tex_template()
  code <- if (is.null(environment)) tpl$get_texcode_for_expression(expression)
    else tpl$get_texcode_for_expression_in_env(expression, environment)
  dir <- tex_dir()
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  base <- file.path(dir, tex_hash(code))
  tex_file <- paste0(base, ".tex")
  svg_file <- paste0(base, ".svg")
  if (file.exists(svg_file)) return(svg_file)
  if (!file.exists(tex_file)) writeLines(code, tex_file, useBytes = TRUE)
  fmt <- tpl$output_format
  out_file <- paste0(base, fmt)
  if (!file.exists(out_file)) {
    compilers <- tpl$tex_compiler
    for (comp in compilers) {
      if (!nzchar(Sys.which(comp))) stop("LaTeX compiler '", comp, "' not found. Install a TeX distribution (for example with tinytex::install_tinytex()).", call. = FALSE)
      args <- if (comp == "xelatex") {
        c(if (fmt == ".xdv") "-no-pdf", "-interaction=batchmode", "-halt-on-error", paste0("-output-directory=", dir), tex_file)
      } else {
        c("-interaction=batchmode", paste0("-output-format=", substring(fmt, 2)), "-halt-on-error",
          paste0("-output-directory=", dir), tex_file)
      }
      status <- system2(comp, shQuote(args), stdout = FALSE, stderr = FALSE)
      if (status != 0) {
        log_file <- paste0(base, ".log")
        msg <- tex_error_lines(log_file)
        stop(comp, " error converting to ", substring(fmt, 2), ". ", msg, "\nLog file: ", log_file, call. = FALSE)
      }
    }
  }
  if (!nzchar(Sys.which("dvisvgm"))) stop("dvisvgm not found; it is needed for Tex and MathTex.", call. = FALSE)
  args <- c(if (fmt == ".pdf") "--pdf", "--page=1", "--no-fonts", "--verbosity=0", paste0("--output=", svg_file), out_file)
  system2("dvisvgm", shQuote(args), stdout = FALSE, stderr = FALSE)
  if (!file.exists(svg_file)) stop("dvisvgm could not convert ", out_file, " to SVG.", call. = FALSE)
  if (!isTRUE(cfg("no_latex_cleanup"))) delete_nonsvg_files()
  svg_file
}

tex_error_lines <- function(log_file) {
  if (!file.exists(log_file)) return("The compiler did not produce a log file. Check your LaTeX installation.")
  lines <- readLines(log_file, warn = FALSE)
  idx <- grep("^!", lines)
  if (!length(idx)) return("")
  i <- idx[1]
  paste(c(lines[i:min(length(lines), i + 4)], tex_error_insights(lines)), collapse = "\n")
}

# Hints for errors with a known cause, as upstream's LATEX_ERROR_INSIGHTS.
tex_error_insights <- function(lines) {
  found <- function(pattern) {
    m <- regmatches(lines, regexec(pattern, lines, perl = TRUE))
    unique(vapply(m[lengths(m) > 0], `[`, "", 2))
  }
  c(
    unlist(lapply(found("inputenc Error: Unicode character (?:.*) \\(U\\+([0-9a-fA-F]+)\\)"), function(code) c(
      sprintf("TexTemplate does not support character U+%s.", code),
      "See TexTemplate() for using a custom template."
    ))),
    unlist(lapply(found("LaTeX Error: File `(.*?[clsty])' not found"), function(pkg) c(
      sprintf("You do not have package %s installed.", pkg),
      sprintf("Install %s using your LaTeX package manager, or check for typos.", pkg)
    )))
  )
}

modify_special_strings <- function(tex) {
  tex <- trimws(tex)
  add_filler <- tex %in% c("\\over", "\\overline", "\\sqrt", "\\sqrt{") || grepl("_$", tex) ||
    grepl("\\^$", tex) || grepl("dot$", tex)
  if (add_filler) tex <- paste0(tex, "{\\quad}")
  if (tex == "\\substack") tex <- "\\quad"
  if (tex == "") tex <- "\\quad"
  if (startsWith(tex, "\\\\")) tex <- gsub("\\\\", "\\quad\\\\", tex, fixed = TRUE)
  count_delims <- function(sub) {
    parts <- strsplit(tex, sub, fixed = TRUE)[[1]][-1]
    sum(vapply(parts, function(s) nzchar(s) && substr(s, 1, 1) %in% strsplit("(){}[]|.\\", "")[[1]], logical(1)))
  }
  if (grepl("\\left", tex, fixed = TRUE) || grepl("\\right", tex, fixed = TRUE)) {
    if (count_delims("\\left") != count_delims("\\right")) {
      tex <- gsub("\\left", "\\big", tex, fixed = TRUE)
      tex <- gsub("\\right", "\\big", tex, fixed = TRUE)
    }
  }
  tex <- remove_stray_braces(tex)
  b <- grepl("\\begin{array}", tex, fixed = TRUE)
  e <- grepl("\\end{array}", tex, fixed = TRUE)
  if (xor(b, e)) tex <- ""
  tex
}

count_fixed <- function(s, pat) {
  m <- gregexpr(pat, s, fixed = TRUE)[[1]]
  if (m[1] == -1) 0L else length(m)
}

remove_stray_braces <- function(tex) {
  nl <- count_fixed(tex, "{") - count_fixed(tex, "\\{") + count_fixed(tex, "\\\\{")
  nr <- count_fixed(tex, "}") - count_fixed(tex, "\\}") + count_fixed(tex, "\\\\}")
  if (nr > nl) tex <- paste0(strrep("{", nr - nl), tex)
  if (nl > nr) tex <- paste0(tex, strrep("}", nl - nr))
  tex
}

#' @title MathTex and Tex
#' @description LaTeX rendered to vectorized mobjects. `MathTex()` typesets
#'   math (in an `align*` environment), `Tex()` typesets text mode LaTeX.
#'   Each string argument becomes one submobject, so
#'   `MathTex("a^2", "+", "b^2")[3]` is the `b^2` part. Double braces
#'   `{{ ... }}` also split parts. `tex_to_color_map` colors matching parts.
#' @param ... Strings (or values coerced to strings), then named arguments.
#' @param tex_string A single LaTeX string.
#' @param arg_separator Separator between the strings.
#' @param substrings_to_isolate Substrings to make addressable parts.
#' @param tex_to_color_map Named list mapping substrings to colors.
#' @param tex_environment LaTeX environment.
#' @param tex_template A [TexTemplate()].
#' @param stroke_width Stroke width.
#' @param should_center Center at the origin.
#' @param height Optional height.
#' @param organize_left_to_right Sort glyphs by x.
#' @param font_size Font size (48 by default).
#' @param color Color.
#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @name tex
#' @examples
#' \dontrun{
#' # Needs LaTeX and dvisvgm.
#' MathTex("e^{i\\pi} + 1 = 0")
#' Tex("Hello \\LaTeX", color = BLUE)
#' }
NULL

#' @rdname tex
#' @format NULL
#' @usage NULL
#' @export
SingleStringMathTexClass <- R6::R6Class("SingleStringMathTex", inherit = SVGMobjectClass, lock_objects = FALSE,
  public = list(
    tex_string = NULL,
    tex_environment = "align*",
    tex_template = NULL,
    organize_left_to_right = FALSE,
    initial_font_size = DEFAULT_FONT_SIZE,
    initial_height = NULL,
    tex_color = "#FFFFFF",
    initialize = function(tex_string, stroke_width = 0, should_center = TRUE, height = NULL,
                          organize_left_to_right = FALSE, tex_environment = "align*", tex_template = NULL,
                          font_size = DEFAULT_FONT_SIZE, color = NULL, ...) {
      self$tex_color <- manim_color(color %||% "#FFFFFF")
      self$initial_font_size <- font_size
      self$organize_left_to_right <- organize_left_to_right
      self$tex_environment <- tex_environment
      self$tex_template <- tex_template %||% default_tex_template()
      self$tex_string <- tex_string
      file <- tex_to_svg_file(modify_special_strings(tex_string), environment = tex_environment,
                              tex_template = self$tex_template)
      super$initialize(file_name = file, should_center = should_center, stroke_width = stroke_width,
                       height = height, color = NULL, ...)
      self$color <- self$tex_color
      self$init_colors()
      # Upstream sets the mobject's own color too, so get_color() reports it.
      self$set_fill(self$tex_color, family = FALSE)
      self$set_stroke(self$tex_color, family = FALSE)
      self$initial_height <- self$height
      if (is.null(height)) self$font_size <- font_size
      if (organize_left_to_right) self$sort(function(p) p[1])
    },
    init_colors = function(propagate_colors = TRUE) {
      if (length(self$submobjects) == 0) return(super$init_colors(propagate_colors))
      for (sm in self$submobjects) {
        if (toupper(sm$get_color()) == "#000000") sm$set_color(self$tex_color)
      }
      invisible(self)
    },
    get_tex_string = function() self$tex_string
  ),
  active = list(
    font_size = function(value) {
      cur <- if (is.null(self$initial_height) || self$initial_height == 0) 0
        else self$height / self$initial_height / SCALE_FACTOR_PER_FONT_POINT
      if (missing(value)) return(cur)
      if (value <= 0) stop("font_size must be greater than 0.", call. = FALSE)
      if (self$height > 0) self$scale(value / cur)
    }
  )
)

#' @rdname tex
#' @export
SingleStringMathTex <- constructor(SingleStringMathTexClass)
# Split a string on Manim's double brace notation, as _split_double_braces.
split_double_braces <- function(s) {
  chars <- strsplit(s, "")[[1]]
  n <- length(chars)
  segs <- character()
  cur <- ""
  i <- 1
  inside <- FALSE
  depth <- 0
  while (i <= n) {
    ch <- chars[i]
    if (ch == "\\" && i < n) {
      nx <- chars[i + 1]
      if (nx == "\\" || nx %in% c("{", "}")) {
        cur <- paste0(cur, ch, nx)
        i <- i + 2
        next
      }
    }
    two <- if (i < n) paste0(ch, chars[i + 1]) else ch
    if (!inside) {
      if (two == "{{" && (i == 1 || grepl("\\s", chars[i - 1]))) {
        segs <- c(segs, cur)
        cur <- ""
        inside <- TRUE
        depth <- 0
        i <- i + 2
      } else {
        cur <- paste0(cur, ch)
        i <- i + 1
      }
    } else {
      if (ch == "{") {
        depth <- depth + 1
        cur <- paste0(cur, ch)
        i <- i + 1
      } else if (ch == "}" && depth == 0 && two == "}}") {
        segs <- c(segs, cur)
        cur <- ""
        inside <- FALSE
        i <- i + 2
      } else if (ch == "}") {
        depth <- depth - 1
        cur <- paste0(cur, ch)
        i <- i + 1
      } else {
        cur <- paste0(cur, ch)
        i <- i + 1
      }
    }
  }
  c(segs, cur)
}

#' @rdname tex
#' @format NULL
#' @usage NULL
#' @export
MathTexClass <- R6::R6Class("MathTex", inherit = SingleStringMathTexClass, lock_objects = FALSE,
  public = list(
    tex_strings = NULL,
    arg_separator = " ",
    substrings_to_isolate = NULL,
    tex_to_color_map = NULL,
    matched_strings_and_ids = NULL,
    brace_notation_split_occurred = FALSE,
    initialize = function(..., arg_separator = " ", substrings_to_isolate = NULL, tex_to_color_map = NULL,
                          tex_environment = "align*", tex_template = NULL) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      strings <- unname(vapply(args[nm == ""], function(s) paste(as.character(s), collapse = ""), ""))
      kwargs <- args[nm != ""]
      self$arg_separator <- arg_separator
      self$tex_to_color_map <- tex_to_color_map %||% list()
      self$substrings_to_isolate <- c(as.character(unlist(substrings_to_isolate)), names(self$tex_to_color_map))
      self$tex_strings <- self$prepare_tex_strings(strings)
      self$matched_strings_and_ids <- list()
      joined <- self$join_tex_strings_with_unique_delimiters(self$tex_strings, self$substrings_to_isolate)
      do.call(super$initialize, c(list(joined, tex_environment = tex_environment, tex_template = tex_template), kwargs))
      self$tex_string <- paste(self$tex_strings, collapse = arg_separator)
      self$break_up_by_substrings()
      self$set_color_by_tex_to_color_map(self$tex_to_color_map)
      if (self$organize_left_to_right) self$sort(function(p) p[1])
    },
    prepare_tex_strings = function(strings) {
      out <- unlist(lapply(strings, split_double_braces))
      if (length(out) > length(strings)) self$brace_notation_split_occurred <- TRUE
      out[nzchar(out)]
    },
    join_tex_strings_with_unique_delimiters = function(tex_strings, substrings) {
      joined <- ""
      ss_idx <- 0
      for (idx in seq_along(tex_strings)) {
        id <- sprintf("unique%03d", idx - 1)
        part <- sprintf("\\special{dvisvgm:raw <g id='%s'>}", id)
        self$matched_strings_and_ids[[length(self$matched_strings_and_ids) + 1]] <- list(tex_strings[idx], id)
        rest <- tex_strings[idx]
        processed <- ""
        while (nzchar(rest)) {
          m <- locate_first_match(substrings, rest)
          if (!is.null(m)) {
            sid <- sprintf("unique%03d%s", ss_idx, MATHTEX_SUBSTRING)
            self$matched_strings_and_ids[[length(self$matched_strings_and_ids) + 1]] <- list(m$match, sid)
            processed <- paste0(processed, m$pre, sprintf("\\special{dvisvgm:raw <g id='%s'>}", sid), m$match,
                                "\\special{dvisvgm:raw </g>}")
            rest <- m$post
            ss_idx <- ss_idx + 1
          } else {
            processed <- paste0(processed, rest)
            rest <- ""
          }
        }
        part <- paste0(part, processed)
        if (idx < length(tex_strings)) part <- paste0(part, self$arg_separator)
        part <- paste0(part, "\\special{dvisvgm:raw </g>}")
        joined <- paste0(joined, part)
      }
      joined
    },
    break_up_by_substrings = function() {
      parts <- list()
      for (m in self$matched_strings_and_ids) {
        if (endsWith(m[[2]], MATHTEX_SUBSTRING)) next
        mtp <- MathTexPartClass$new()
        mtp$tex_string <- m[[1]]
        g <- self$id_to_vgroup_dict[[m[[2]]]]
        if (is.null(g)) {
          warning("MathTex: could not find SVG group for tex part '", m[[1]], "'; using the whole expression.", call. = FALSE)
          parts <- list(self$id_to_vgroup_dict[["root"]])
          break
        }
        mtp$add(g$submobjects)
        parts[[length(parts) + 1]] <- mtp
      }
      self$submobjects <- parts
      invisible(self)
    },
    get_part_by_tex = function(tex) {
      for (m in self$matched_strings_and_ids) if (identical(m[[1]], tex)) return(self$id_to_vgroup_dict[[m[[2]]]])
      NULL
    },
    get_parts_by_tex = function(tex) {
      out <- list()
      for (m in self$matched_strings_and_ids) if (identical(m[[1]], tex)) out[[length(out) + 1]] <- self$id_to_vgroup_dict[[m[[2]]]]
      VGroup(out)
    },
    set_color_by_tex = function(tex, color) {
      for (m in self$matched_strings_and_ids) if (identical(m[[1]], tex)) self$id_to_vgroup_dict[[m[[2]]]]$set_color(color)
      invisible(self)
    },
    set_opacity_by_tex = function(tex, opacity = 0.5, remaining_opacity = NULL) {
      if (!is.null(remaining_opacity)) self$set_opacity(remaining_opacity)
      for (m in self$matched_strings_and_ids) if (identical(m[[1]], tex)) self$id_to_vgroup_dict[[m[[2]]]]$set_opacity(opacity)
      invisible(self)
    },
    set_color_by_tex_to_color_map = function(texs_to_color_map) {
      for (k in names(texs_to_color_map)) self$set_color_by_tex(k, texs_to_color_map[[k]])
      invisible(self)
    },
    index_of_part = function(part) {
      ids <- self$submobject_ids()
      i <- match(part$mob_id, ids)
      if (is.na(i)) stop("Trying to get index of part not in MathTex", call. = FALSE)
      i
    },
    index_of_part_by_tex = function(tex) {
      strs <- vapply(self$submobjects, function(m) m$tex_string %||% "", "")
      i <- match(tex, strs)
      if (!is.na(i)) return(i)
      g <- self$get_part_by_tex(tex)
      if (is.null(g) || !length(g$submobjects)) stop("Trying to get index of part not in MathTex", call. = FALSE)
      first <- g$submobjects[[1]]$mob_id
      for (k in seq_along(self$submobjects)) {
        if (first %in% vapply(self$submobjects[[k]]$get_family(), function(m) m$mob_id, "")) return(k)
      }
      stop("Trying to get index of part not in MathTex", call. = FALSE)
    },
    sort_alphabetically = function() {
      keys <- vapply(self$submobjects, function(m) m$tex_string %||% "", "")
      self$submobjects <- self$submobjects[order(keys)]
      invisible(self)
    }
  )
)

#' @rdname tex
#' @export
MathTex <- constructor(MathTexClass)
MathTexPartClass <- R6::R6Class("MathTexPart", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(tex_string = NULL, get_tex_string = function() self$tex_string)
)

locate_first_match <- function(substrings, s) {
  best <- NULL
  best_start <- nchar(s) + 1
  best_len <- 0
  for (sub in substrings) {
    if (!nzchar(sub)) next
    pos <- regexpr(sub, s, fixed = TRUE)
    if (pos == -1) next
    start <- pos - 1
    if (start < best_start - 1 || (start == best_start - 1 && nchar(sub) > best_len)) {
      best <- list(pre = substr(s, 1, pos - 1), match = sub, post = substr(s, pos + nchar(sub), nchar(s)))
      best_start <- pos
      best_len <- nchar(sub)
    }
  }
  best
}

#' @rdname tex
#' @export
Tex <- constructor(TexClass)

#' @title BulletedList and Title
#' @description `BulletedList()` typesets items with bullets; `Title()`
#'   places underlined LaTeX text at the top of the frame. Both use [Tex()].
#' @param ... Strings, then named arguments for [Tex()].
#' @param buff Gap between items.
#' @param dot_scale_factor Bullet size.
#' @param tex_environment LaTeX environment.
#' @param dot_buff Gap between bullet and item.
#' @param include_underline Draw an underline.
#' @param match_underline_width_to_text Underline only under the text.
#' @param underline_buff Gap below the title.
#' @export
BulletedList <- constructor(BulletedListClass)

#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @rdname BulletedList
#' @export
Title <- constructor(TitleClass)

#' @rdname tex
#' @format NULL
#' @usage NULL
#' @export
TexClass <- R6::R6Class("Tex", inherit = MathTexClass, lock_objects = FALSE,
  public = list(
    initialize = function(..., arg_separator = "", tex_environment = "center") {
      super$initialize(..., arg_separator = arg_separator, tex_environment = tex_environment)
    }
  )
)

#' @rdname BulletedList
#' @format NULL
#' @usage NULL
#' @export
BulletedListClass <- R6::R6Class("BulletedList", inherit = TexClass, lock_objects = FALSE,
  public = list(
    buff = MED_LARGE_BUFF,
    dot_scale_factor = 2,
    initialize = function(..., buff = MED_LARGE_BUFF, dot_scale_factor = 2, tex_environment = NULL, dot_buff = SMALL_BUFF) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      items <- vapply(unlist(args[nm == ""]), function(s) paste0(s, "\\\\"), "", USE.NAMES = FALSE)
      self$buff <- buff
      self$dot_scale_factor <- dot_scale_factor
      do.call(super$initialize, c(as.list(items), list(tex_environment = tex_environment), args[nm != ""]))
      for (part in self$submobjects) {
        dot <- MathTex("\\cdot")$scale(dot_scale_factor)
        dot$next_to(part$submobjects[[1]], LEFT, buff = dot_buff)
        part$add_to_back(dot)
      }
      self$arrange(DOWN, aligned_edge = LEFT, buff = buff)
    },
    fade_all_but = function(index_or_string, opacity = 0.5) {
      part <- if (is.character(index_or_string)) self$get_part_by_tex(index_or_string) else self$submobjects[[index_or_string]]
      if (is.null(part)) stop("Could not locate part by provided tex string '", index_or_string, "'.", call. = FALSE)
      for (other in self$submobjects) other$set_fill(opacity = if (identical(other$mob_id, part$mob_id)) 1 else opacity)
      invisible(self)
    }
  )
)

#' @rdname BulletedList
#' @format NULL
#' @usage NULL
#' @export
TitleClass <- R6::R6Class("Title", inherit = TexClass, lock_objects = FALSE,
  public = list(
    include_underline = TRUE,
    underline = NULL,
    initialize = function(..., include_underline = TRUE, match_underline_width_to_text = FALSE,
                          underline_buff = MED_SMALL_BUFF) {
      self$include_underline <- include_underline
      super$initialize(...)
      self$to_edge(UP)
      if (include_underline) {
        ul <- Line(LEFT, RIGHT)
        ul$next_to(self, DOWN, buff = underline_buff)
        if (match_underline_width_to_text) ul$match_width(self) else ul$width <- frame_width() - 2
        self$add(ul)
        self$underline <- ul
      }
    }
  )
)
