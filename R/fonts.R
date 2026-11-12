# Font registration, the counterpart of manim's register_font() in
# manim/mobject/text/text_mobject.py.

#' Use a font file with Text
#'
#' Makes the font in `font_file` available to [Text()], [MarkupText()] and
#' [Paragraph()] under its family name, which is returned. The file is looked
#' up as given, then in `assets/fonts/` and `fonts/` below the working
#' directory, as upstream does relative to the scene file.
#'
#' Upstream's `register_font()` is a context manager that unregisters the
#' font when the `with` block ends. Here the font stays registered for the
#' rest of the R session (through [systemfonts::register_font()]), so
#' `Text("Hi", font = register_font("MyFont.ttf"))` works directly.
#'
#' The first file registered for a family is used for every style (regular,
#' bold, italic, bold italic) the system does not already provide for that
#' family. A later file of the same family replaces only its own style, so
#' registering a regular and a bold file gives `weight = "BOLD"` the bold
#' one, and registering only a bold file for an installed family keeps the
#' installed regular face.
#'
#' @param font_file Path to a font file (for example `.ttf` or `.otf`).
#' @return The font family name, invisibly.
#' @export
#' @examples
#' \dontrun{
#' family <- register_font("fonts/MyFont-Regular.ttf")
#' Text("Hello", font = family)
#' }
register_font <- function(font_file) {
  candidates <- c(font_file, file.path("assets", "fonts", font_file), file.path("fonts", font_file))
  found <- candidates[file.exists(candidates)]
  if (!length(found)) {
    stop("Can't find ", font_file, ". Checked paths: ", paste(candidates, collapse = ", "), call. = FALSE)
  }
  path <- normalizePath(found[1])
  info <- systemfonts::font_info(path = path)
  family <- info$family[1]
  # Registry rows come in the order plain, bold, italic, bold italic.
  old <- systemfonts::registry_fonts()
  old <- old$path[old$family == family]
  styles <- list(c(FALSE, FALSE), c(TRUE, FALSE), c(FALSE, TRUE), c(TRUE, TRUE))
  files <- if (length(old) == 4) {
    as.list(old)
  } else if (family %in% systemfonts::system_fonts()$family) {
    lapply(styles, function(st) {
      systemfonts::match_fonts(family, italic = st[2], weight = if (st[1]) "bold" else "normal")$path
    })
  } else {
    as.list(rep(path, 4))
  }
  files[[1 + isTRUE(info$bold[1]) + 2 * isTRUE(info$italic[1])]] <- path
  systemfonts::register_font(family, files[[1]], files[[2]], files[[3]], files[[4]])
  invisible(family)
}
