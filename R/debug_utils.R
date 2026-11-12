# Debugging helpers ported from manim/utils/debug.py.

#' Debugging helpers
#'
#' `print_family()` prints a mobject and, indented by one tab per level,
#' every submobject below it, each with its name and id.
#'
#' `index_labels()` returns a [VGroup()] of [Integer()] labels, one placed on
#' each submobject of `mobject`, which helps when picking parts of a
#' complicated mobject such as a [MathTex()]. The labels count from 1, as
#' `mobject[i]` does in R (upstream labels count from 0). Labels go on the
#' submobjects, the parts `mobject[i]` returns; upstream labels the pieces
#' of `split()`, which also include `mobject` itself when it has points of
#' its own. Each label is
#' scaled to `label_height` and gets a background stroke so it stays legible
#' on top of the mobject.
#'
#' @param mobject A mobject.
#' @param n_tabs Indentation of the first line, in tabs.
#' @param label_height Height of each label.
#' @param background_stroke_width,background_stroke_color Outline drawn
#'   behind each label.
#' @param ... Further arguments passed to [Integer()].
#' @return `print_family()` returns `mobject` invisibly; `index_labels()`
#'   returns a VGroup of labels.
#' @export
#' @examples
#' print_family(VGroup(Square(), VGroup(Circle(), Dot())))
#' \dontrun{
#' # Needs LaTeX and dvisvgm.
#' eq <- MathTex("\\frac{d}{dx}f(x)g(x)=")
#' labels <- index_labels(eq[1])
#' }
print_family <- function(mobject, n_tabs = 0) {
  cat(paste(strrep("\t", n_tabs), mobject$name %||% class(mobject)[1], mobject$mob_id), "\n", sep = "")
  for (submob in mobject$submobjects) print_family(submob, n_tabs + 1)
  invisible(mobject)
}

#' @rdname print_family
#' @export
index_labels <- function(mobject, label_height = 0.15, background_stroke_width = 5,
                         background_stroke_color = BLACK, ...) {
  labels <- VGroup()
  for (n in seq_along(mobject$submobjects)) {
    label <- Integer(n, ...)
    label$set_stroke(background_stroke_color, background_stroke_width, background = TRUE)
    label$height <- label_height
    label$move_to(mobject$submobjects[[n]])
    labels$add(label)
  }
  labels
}
