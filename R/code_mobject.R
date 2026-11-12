# Highlighted source code listings. Ported from
# manim/mobject/text/code_mobject.py. Upstream highlights with Pygments; manimR
# has a small built in tokenizer for R and Python (comments, strings, numbers
# and keywords) and the colors of a few Pygments styles.

# Colors of some Pygments styles for the token kinds the tokenizer emits.
# NA means "no color", which falls back to the foreground color.
code_styles <- function() {
  list(
    vim = list(background = "#000000", line_number = NA, text = "#CCCCCC", comment = "#000080",
               keyword = "#CDCD00", namespace = "#CD00CD", constant = "#CDCD00", operator_word = "#CDCD00",
               string = "#CD0000", number = "#CD00CD"),
    monokai = list(background = "#272822", line_number = NA, text = "#F8F8F2", comment = "#959077",
                   keyword = "#66D9EF", namespace = "#FF4689", constant = "#66D9EF", operator_word = "#FF4689",
                   string = "#E6DB74", number = "#AE81FF"),
    emacs = list(background = "#F8F8F8", line_number = NA, text = NA, comment = "#008800", keyword = "#AA22FF",
                 namespace = "#AA22FF", constant = "#AA22FF", operator_word = "#AA22FF", string = "#BB4444",
                 number = "#666666"),
    default = list(background = "#F8F8F8", line_number = NA, text = NA, comment = "#3D7B7B", keyword = "#008000",
                   namespace = "#008000", constant = "#008000", operator_word = "#AA22FF", string = "#BA2121",
                   number = "#666666")
  )
}

code_keywords <- function(language) {
  if (language == "python") {
    list(keyword = c("assert", "async", "await", "break", "continue", "del", "elif", "else", "except",
                     "finally", "for", "global", "if", "lambda", "pass", "raise", "nonlocal", "return", "try",
                     "while", "yield", "as", "with", "def", "class"),
         namespace = c("import", "from"),
         constant = c("True", "False", "None"),
         operator_word = c("and", "or", "not", "in", "is"))
  } else {
    list(keyword = c("if", "else", "for", "while", "repeat", "in", "next", "break", "return", "switch", "function"),
         namespace = character(),
         constant = c("NULL", "NA", "NA_integer_", "NA_real_", "NA_complex_", "NA_character_", "letters", "LETTERS",
                      "Inf", "TRUE", "FALSE", "NaN", "pi"),
         operator_word = character())
  }
}

# Tokenize code into a data frame with 1 based start and end positions and a
# kind (comment, string, number, keyword, namespace, constant, operator_word).
# Text in between is plain.
code_tokenize <- function(code, language) {
  if (!language %in% c("r", "python")) return(data.frame(start = integer(), end = integer(), kind = character()))
  if (language == "python") {
    patterns <- c(
      comment = "#[^\n]*",
      string = "(?i:[rbfu]{0,2})(?:\"\"\"[\\s\\S]*?(?:\"\"\"|$)|'''[\\s\\S]*?(?:'''|$)|\"(?:\\\\.|[^\"\\\\\n])*\"?|'(?:\\\\.|[^'\\\\\n])*'?)",
      number = "(?:0[xX][0-9a-fA-F_]+|0[oO][0-7_]+|0[bB][01_]+|(?:\\d[\\d_]*\\.?[\\d_]*|\\.\\d[\\d_]*)(?:[eE][+-]?\\d[\\d_]*)?)",
      name = "[A-Za-z_][A-Za-z0-9_]*"
    )
  } else {
    patterns <- c(
      comment = "#[^\n]*",
      string = "[rR]\"(-*)[\\[\\(\\{][\\s\\S]*?[\\]\\)\\}]\\1\"|\"(?:\\\\.|[^\"\\\\])*\"?|'(?:\\\\.|[^'\\\\])*'?",
      number = "(?:0[xX][0-9a-fA-F]+[Li]?|(?:\\d+(?:\\.\\d*)?|\\.\\d+)(?:[eE][+-]?\\d+)?[Li]?)",
      name = "`[^`]*`|[A-Za-z.][A-Za-z0-9._]*"
    )
  }
  kw <- code_keywords(language)
  n <- nchar(code)
  starts <- integer(); ends <- integer(); kinds <- character()
  i <- 1L
  prev_word <- FALSE
  # ponytail: rescans the remaining string at every token (quadratic in the
  # code length); fine for slide sized listings, use gregexpr passes if not.
  while (i <= n) {
    rest <- substr(code, i, n)
    matched <- FALSE
    for (kind in names(patterns)) {
      m <- regexpr(paste0("^(?:", patterns[[kind]], ")"), rest, perl = TRUE)
      len <- attr(m, "match.length")
      if (m == 1 && len > 0) {
        if (kind == "number" && prev_word) next
        if (kind == "name") {
          word <- substr(rest, 1, len)
          k <- names(kw)[vapply(kw, function(v) word %in% v, logical(1))]
          if (length(k)) {
            starts <- c(starts, i); ends <- c(ends, i + len - 1L); kinds <- c(kinds, k[1])
          }
          prev_word <- TRUE
        } else {
          starts <- c(starts, i); ends <- c(ends, i + len - 1L); kinds <- c(kinds, kind)
          prev_word <- FALSE
        }
        i <- i + len
        matched <- TRUE
        break
      }
    }
    if (!matched) {
      prev_word <- FALSE
      i <- i + 1L
    }
  }
  data.frame(start = starts, end = ends, kind = kinds, stringsAsFactors = FALSE)
}

# str.expandtabs: tabs advance to the next multiple of tab_width per line.
code_expand_tabs <- function(code, tab_width = 4) {
  lines <- strsplit(code, "\n", fixed = TRUE)[[1]]
  out <- vapply(lines, function(line) {
    if (!grepl("\t", line, fixed = TRUE)) return(line)
    chars <- strsplit(line, "")[[1]]
    res <- character()
    col <- 0
    for (ch in chars) {
      if (ch == "\t") {
        k <- if (tab_width > 0) tab_width - col %% tab_width else 0
        res <- c(res, strrep(" ", k))
        col <- col + k
      } else {
        res <- c(res, ch)
        col <- col + 1
      }
    }
    paste(res, collapse = "")
  }, "", USE.NAMES = FALSE)
  out <- paste(out, collapse = "\n")
  if (endsWith(code, "\n")) out <- paste0(out, "\n")
  out
}

code_guess_language <- function(code, file = NULL) {
  if (!is.null(file)) {
    ext <- tolower(tools::file_ext(file))
    if (ext %in% c("r", "rmd", "qmd")) return("r")
    if (ext %in% c("py", "pyw")) return("python")
  }
  if (grepl("<-|function\\s*\\(", code)) return("r")
  if (grepl("(^|\n)\\s*(def |class |import |from )", code)) return("python")
  "text"
}

#' @title Code
#' @description A highlighted source code listing: monospaced [Text()]
#'   lines colored by token kind, optional line numbers, and a rounded
#'   background (`"rectangle"`) or a window with three buttons (`"window"`).
#'
#'   Pygments is not available in R, so a small built in tokenizer
#'   highlights R and Python comments, strings, numbers and keywords; other
#'   languages are shown in the foreground color. The styles `"vim"`
#'   (default), `"monokai"`, `"emacs"` and `"default"` reproduce the
#'   colors of the Pygments styles of the same names. A custom style is a
#'   named list like the entries of those styles, with fields `background`,
#'   `line_number`, `text`, `comment`, `keyword`, `namespace`, `constant`,
#'   `operator_word`, `string` and `number`.
#'
#'   Fields: `code_lines` (a VGroup of [Text()] lines), `line_numbers` and
#'   `background`.
#' @param code_file Path of a file with the code.
#' @param code_string Alternatively, the code as a string.
#' @param language `"r"` or `"python"`; guessed from the file extension or
#'   the code when `NULL`.
#' @param formatter_style Style name or a named list of colors.
#' @param tab_width Width of a tab in spaces.
#' @param add_line_numbers Show line numbers.
#' @param line_numbers_from First line number.
#' @param background `"rectangle"` or `"window"`.
#' @param background_config Named list of arguments for the background
#'   [SurroundingRectangle()]; `fill_color` defaults to the style's background.
#' @param paragraph_config Named list of [Text()] arguments for the code and
#'   line numbers: `font` (default `"mono"`), `font_size` (24),
#'   `line_spacing` (0.5, extra space between lines as a fraction of the
#'   font size, as upstream), `disable_ligatures`, and any other [Text()]
#'   option such as `weight` or `slant`. `color` is ignored; colors come
#'   from the style. `alignment`, `width` and `height` are ignored.
#' @export
#' @examples
#' \dontrun{
#' code <- "f <- function(x) {\n  # square it\n  x^2 + 1\n}"
#' Code(code_string = code, language = "r", background = "window",
#'      background_config = list(stroke_color = "maroon"))
#' }
CodeClass <- R6::R6Class("Code", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    code_string = NULL,
    language = NULL,
    code_lines = NULL,
    line_numbers = NULL,
    background = NULL,
    tokens = NULL,
    initialize = function(code_file = NULL, code_string = NULL, language = NULL, formatter_style = "vim",
                          tab_width = 4, add_line_numbers = TRUE, line_numbers_from = 1,
                          background = c("rectangle", "window"), background_config = NULL, paragraph_config = NULL) {
      super$initialize()
      if (is.character(background)) background <- background[1]
      if (!is.null(code_file)) {
        code_string <- paste(readLines(code_file, encoding = "UTF-8", warn = FALSE), collapse = "\n")
      } else if (is.null(code_string)) {
        stop("Either a code file or a code string must be specified.", call. = FALSE)
      }
      code_string <- paste(code_string, collapse = "\n")
      language <- tolower(language %||% code_guess_language(code_string, code_file))
      if (language == "py") language <- "python"
      if (!language %in% c("r", "python", "text")) {
        warning("Code: no highlighting for language '", language, "'; only R and Python are highlighted.",
                call. = FALSE)
      }
      style <- if (is.list(formatter_style)) formatter_style else code_styles()[[formatter_style]]
      if (is.null(style)) {
        stop("Unknown formatter_style '", formatter_style, "'. Available: ",
             paste(names(code_styles()), collapse = ", "), ".", call. = FALSE)
      }
      code_string <- code_expand_tabs(code_string, tab_width)
      self$code_string <- code_string
      self$language <- language

      code <- sub("\n$", "", code_string)
      code_lines <- strsplit(code, "\n", fixed = TRUE)[[1]]
      if (length(code_lines) == 0) code_lines <- ""
      if (endsWith(code, "\n")) code_lines <- c(code_lines, "")
      rendered <- if (any(nzchar(trimws(code_lines)))) code_lines else rep("", length(code_lines))

      pc <- labeled_merge(list(font = "mono", font_size = 24, line_spacing = 0.5, disable_ligatures = TRUE),
                          paragraph_config)
      pc$color <- NULL
      if (tolower(pc$font) == "monospace") pc$font <- "mono"
      foreground <- if (is.na(style$text %||% NA)) BLACK else style$text
      line_number_color <- if (is.na(style$line_number %||% NA)) foreground else style$line_number
      # Upstream forwards paragraph_config to Paragraph; every line is a Text
      # here, so all but the paragraph level options go to each line.
      text_args <- pc[setdiff(names(pc), c("line_spacing", "alignment", "width", "height"))]
      text_args$should_center <- FALSE
      step <- code_line_step(pc$font, pc$font_size, pc$line_spacing)

      # Temporary glyphs with an ascender and a descender on the first and
      # last lines make the vertical bounds independent of the contents.
      suffix <- paste0(" pA", line_numbers_from)
      boundary <- unique(c(1, length(rendered)))
      lines <- lapply(seq_along(rendered), function(i) {
        txt <- if (i %in% boundary) paste0(rendered[i], suffix) else rendered[i]
        do.call(Text, c(list(txt, color = foreground), text_args))$shift(DOWN * (i - 1) * step)
      })
      # Center the listing (with the temporary glyphs) at the origin, as
      # upstream's Paragraph does, then take the temporary glyphs out.
      offset <- -VGroup(lines)$get_center()
      alignment <- list()
      for (i in seq_along(lines)) {
        lines[[i]]$shift(offset)
        if (i %in% boundary) {
          extra <- Filter(function(g) g$char_index > nchar(rendered[i]), lines[[i]]$submobjects)
          lines[[i]]$remove(extra)
          alignment <- c(alignment, extra)
        }
      }
      alignment_mobjects <- VGroup(alignment)
      alignment_mobjects$stretch_to_fit_width(0, about_edge = LEFT)
      self$code_lines <- VGroup(lines)

      # Color glyphs by token.
      self$tokens <- code_tokenize(paste(rendered, collapse = "\n"), language)
      line_start <- cumsum(c(0, nchar(rendered) + 1))
      for (k in seq_len(nrow(self$tokens))) {
        col <- style[[self$tokens$kind[k]]]
        if (is.null(col) || is.na(col)) next
        for (i in seq_along(rendered)) {
          a <- max(self$tokens$start[k] - line_start[i], 1)
          b <- min(self$tokens$end[k] - line_start[i], nchar(rendered[i]))
          if (a > b) next
          for (g in lines[[i]]$glyphs_for_range(a, b)) g$set_color(col)
        }
      }

      if (add_line_numbers) {
        nums <- lapply(seq_along(rendered), function(i) {
          t <- do.call(Text, c(list(as.character(line_numbers_from + i - 1), color = line_number_color), text_args))
          t$shift(DOWN * (i - 1) * step + offset)
        })
        right <- max(vapply(nums, function(t) t$get_right()[1], 0))
        for (t in nums) t$shift(RIGHT * (right - t$get_right()[1]))
        self$line_numbers <- VGroup(nums)
        self$line_numbers$next_to(self$code_lines, LEFT, coor_mask = c(1, 0, 0))
        self$add(self$line_numbers)
      }
      self$add(self$code_lines)

      bc <- labeled_merge(list(buff = 0.3, fill_color = NULL, stroke_color = WHITE, corner_radius = 0.2,
                               stroke_width = 1, fill_opacity = 1), background_config)
      if (is.null(bc$fill_color)) bc$fill_color <- style$background
      if (identical(background, "rectangle")) {
        self$background <- do.call(SurroundingRectangle, c(list(self, alignment_mobjects), bc))
      } else if (identical(background, "window")) {
        buttons <- VGroup(lapply(c("#FF5F56", "#FFBD2E", "#27C93F"), function(cl) {
          Dot(radius = 0.1, stroke_width = 0, color = cl)
        }))
        buttons$arrange(RIGHT, buff = 0.1)
        code_and_alignment <- VGroup(self, alignment_mobjects)
        buttons$next_to(code_and_alignment, UP, buff = 0.1)$align_to(code_and_alignment, LEFT)$shift(LEFT * 0.1)
        self$background <- do.call(SurroundingRectangle, c(list(code_and_alignment, buttons), bc))
        buttons$shift(UP * 0.1 + LEFT * 0.1)
        self$background$add(buttons)
      } else {
        stop("Unknown background type: ", background, call. = FALSE)
      }
      self$add_to_back(self$background)
    }
  )
)

#' @rdname CodeClass
#' @export
Code <- constructor(CodeClass)
# Distance between code lines. Upstream lines are (1 + line_spacing) font
# sizes apart, against 1.3 font sizes for default text; the same ratio is
# applied to manimR's default line height (1.2 natural line heights).
code_line_step <- function(font, font_size, line_spacing) {
  ref <- Text("M\nM", font = font, font_size = font_size, line_spacing = 1, should_center = FALSE)
  g <- ref$submobjects
  natural <- g[[1]]$get_center()[2] - g[[2]]$get_center()[2]
  1.2 * natural * (1 + line_spacing) / 1.3
}
