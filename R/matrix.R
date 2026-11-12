# Mobjects representing matrices. Ported from manim/mobject/matrix.py.

# Rows of a matrix like input as a list of lists of entries. Accepts an R
# matrix or data frame, a list of rows (vectors or lists), or a vector, which
# becomes a single column.
matrix_rows <- function(x) {
  if (is.data.frame(x)) return(lapply(seq_len(nrow(x)), function(i) unname(as.list(x[i, , drop = TRUE]))))
  if (is.matrix(x)) return(lapply(seq_len(nrow(x)), function(i) as.list(x[i, ])))
  if (is_mobject(x)) return(list(list(x)))
  if (is.list(x)) return(lapply(x, function(r) if (is_mobject(r)) list(r) else as.list(r)))
  lapply(x, list)
}

# Build entry mobjects with `element_to_mobject`, which may be a constructor
# function or an R6 generator.
matrix_entry_mobject <- function(element_to_mobject, item, config) {
  ctor <- if (inherits(element_to_mobject, "R6ClassGenerator")) element_to_mobject$new else element_to_mobject
  do.call(ctor, c(list(item), config))
}

#' Matrix helpers
#'
#' `matrix_to_tex_string()` writes a matrix as a LaTeX `array` in square
#' brackets and `matrix_to_mobject()` renders it with [MathTex()]. A vector
#' becomes a column.
#'
#' @param matrix A matrix or vector.
#' @export
#' @examples
#' matrix_to_tex_string(matrix(1:4, 2))
matrix_to_tex_string <- function(matrix) {
  m <- if (is.null(dim(matrix))) base::matrix(matrix, ncol = 1) else as.matrix(matrix)
  m <- base::matrix(as.character(m), nrow(m))
  rows <- apply(m, 1, paste, collapse = " & ")
  paste0("\\left[ \\begin{array}{", strrep("c", ncol(m)), "}", paste(rows, collapse = " \\\\ "),
         "\\end{array} \\right]")
}

#' @rdname matrix_to_tex_string
#' @export
matrix_to_mobject <- function(matrix) MathTex(matrix_to_tex_string(matrix))

#' @title Matrix
#' @description Displays a matrix: entries made with `element_to_mobject`
#'   (by default [MathTex()]) laid out in a grid between brackets.
#'   `DecimalMatrix()`, `IntegerMatrix()` and `MobjectMatrix()` use
#'   [DecimalNumber()], [Integer()] and the given mobjects as entries.
#'
#'   Methods: `get_rows()`, `get_columns()`, `get_entries()`,
#'   `get_brackets()`, `get_mob_matrix()`, `set_row_colors(...)`,
#'   `set_column_colors(...)` and `add_background_to_entries()`.
#' @param matrix An R matrix, a data frame, a list of rows (vectors or lists),
#'   or a vector (one column).
#' @param v_buff,h_buff Vertical and horizontal distance between entries.
#' @param bracket_h_buff Distance of the brackets from the entries.
#' @param bracket_v_buff How far the brackets extend above and below the entries.
#' @param add_background_rectangles_to_entries Add a background rectangle to each entry.
#' @param include_background_rectangle Add a background rectangle to the matrix.
#' @param element_to_mobject Constructor applied to each entry.
#' @param element_to_mobject_config Named list of extra arguments for it.
#' @param element_alignment_corner Corner of each entry aligned to the grid.
#' @param left_bracket,right_bracket LaTeX bracket delimiters, such as `"("` or `"["`.
#' @param stretch_brackets Stretch the brackets to the height of the entries.
#' @param bracket_config Named list of arguments for the bracket [MathTex()].
#' @param ... Passed to [VMobject()].
#' @export
#' @examples
#' \dontrun{
#' Matrix(list(list(2, "\\pi"), list(-1, 1)))
#' IntegerMatrix(rbind(c(3.7, 2), c(42.2, 12)), left_bracket = "(", right_bracket = ")")
#' }
MatrixClass <- R6::R6Class("Matrix", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    v_buff = 0.8,
    h_buff = 1.3,
    bracket_h_buff = MED_SMALL_BUFF,
    bracket_v_buff = MED_SMALL_BUFF,
    add_background_rectangles_to_entries = FALSE,
    include_background_rectangle = FALSE,
    element_to_mobject = NULL,
    element_to_mobject_config = NULL,
    element_alignment_corner = NULL,
    left_bracket = "[",
    right_bracket = "]",
    stretch_brackets = TRUE,
    elements = NULL,
    brackets = NULL,
    n_rows = 0,
    n_cols = 0,
    initialize = function(matrix, v_buff = 0.8, h_buff = 1.3, bracket_h_buff = MED_SMALL_BUFF,
                          bracket_v_buff = MED_SMALL_BUFF, add_background_rectangles_to_entries = FALSE,
                          include_background_rectangle = FALSE, element_to_mobject = MathTex,
                          element_to_mobject_config = list(), element_alignment_corner = DR, left_bracket = "[",
                          right_bracket = "]", stretch_brackets = TRUE, bracket_config = list(), ...) {
      self$v_buff <- v_buff
      self$h_buff <- h_buff
      self$bracket_h_buff <- bracket_h_buff
      self$bracket_v_buff <- bracket_v_buff
      self$add_background_rectangles_to_entries <- add_background_rectangles_to_entries
      self$include_background_rectangle <- include_background_rectangle
      self$element_to_mobject <- element_to_mobject
      self$element_to_mobject_config <- element_to_mobject_config
      self$element_alignment_corner <- element_alignment_corner
      self$left_bracket <- left_bracket
      self$right_bracket <- right_bracket
      self$stretch_brackets <- stretch_brackets
      super$initialize(...)
      mob_matrix <- self$matrix_to_mob_matrix(matrix)
      self$organize_mob_matrix(mob_matrix)
      self$n_rows <- length(mob_matrix)
      self$n_cols <- if (length(mob_matrix)) length(mob_matrix[[1]]) else 0
      self$elements <- VGroup(unlist(mob_matrix, recursive = FALSE))
      self$add(self$elements)
      do.call(self$add_brackets, c(list(self$left_bracket, self$right_bracket), bracket_config))
      self$center()
      if (self$add_background_rectangles_to_entries) {
        for (mob in self$elements$submobjects) mob$add_background_rectangle()
      }
      if (self$include_background_rectangle) self$add_background_rectangle()
    },
    matrix_to_mob_matrix = function(matrix) {
      lapply(matrix_rows(matrix), function(row) {
        lapply(row, function(item) matrix_entry_mobject(self$element_to_mobject, item, self$element_to_mobject_config))
      })
    },
    organize_mob_matrix = function(matrix) {
      for (i in seq_along(matrix)) {
        for (j in seq_along(matrix[[i]])) {
          matrix[[i]][[j]]$move_to((i - 1) * self$v_buff * DOWN + (j - 1) * self$h_buff * RIGHT,
                                   self$element_alignment_corner)
        }
      }
      invisible(self)
    },
    # Brackets are LaTeX delimiters around an empty array tall enough for the entries.
    add_brackets = function(left = "[", right = "]", ...) {
      bracket_height <- 0.5977
      n <- as.integer(self$height / bracket_height) + 1
      empty_tex_array <- paste0("\\begin{array}{c}", strrep("\\quad \\\\", n), "\\end{array}")
      tex_left <- paste0("\\left", left, empty_tex_array, "\\right.")
      tex_right <- paste0("\\left.", empty_tex_array, "\\right", right)
      l_bracket <- MathTex(tex_left, ...)
      r_bracket <- MathTex(tex_right, ...)
      bracket_pair <- VGroup(l_bracket, r_bracket)
      if (self$stretch_brackets) bracket_pair$stretch_to_fit_height(self$height + 2 * self$bracket_v_buff)
      l_bracket$next_to(self, LEFT, self$bracket_h_buff)
      r_bracket$next_to(self, RIGHT, self$bracket_h_buff)
      self$brackets <- bracket_pair
      self$add(l_bracket, r_bracket)
      invisible(self)
    },
    # The entries as a list of rows (each a list of mobjects).
    get_mob_matrix = function() {
      e <- self$elements$submobjects
      lapply(seq_len(self$n_rows), function(i) e[(i - 1) * self$n_cols + seq_len(self$n_cols)])
    },
    get_columns = function() {
      e <- self$elements$submobjects
      VGroup(lapply(seq_len(self$n_cols), function(j) VGroup(e[(seq_len(self$n_rows) - 1) * self$n_cols + j])))
    },
    get_rows = function() VGroup(lapply(self$get_mob_matrix(), VGroup)),
    set_column_colors = function(...) {
      colors <- list(...)
      cols <- self$get_columns()$submobjects
      for (k in seq_len(min(length(colors), length(cols)))) cols[[k]]$set_color(colors[[k]])
      invisible(self)
    },
    set_row_colors = function(...) {
      colors <- list(...)
      rows <- self$get_rows()$submobjects
      for (k in seq_len(min(length(colors), length(rows)))) rows[[k]]$set_color(colors[[k]])
      invisible(self)
    },
    add_background_to_entries = function() {
      for (mob in self$get_entries()$submobjects) mob$add_background_rectangle()
      invisible(self)
    },
    get_entries = function() self$elements,
    get_brackets = function() self$brackets
  )
)

#' @rdname MatrixClass
#' @export
Matrix <- constructor(MatrixClass)
#' @rdname MatrixClass
#' @export
DecimalMatrix <- function(matrix, element_to_mobject = DecimalNumber,
                          element_to_mobject_config = list(num_decimal_places = 1), ...) {
  m <- MatrixClass$new(matrix, element_to_mobject = element_to_mobject,
                       element_to_mobject_config = element_to_mobject_config, ...)
  class(m) <- c("DecimalMatrix", class(m))
  m
}

#' @rdname MatrixClass
#' @export
IntegerMatrix <- function(matrix, element_to_mobject = Integer, ...) {
  m <- MatrixClass$new(matrix, element_to_mobject = element_to_mobject, ...)
  class(m) <- c("IntegerMatrix", class(m))
  m
}

#' @rdname MatrixClass
#' @export
MobjectMatrix <- function(matrix, element_to_mobject = function(m) m, ...) {
  m <- MatrixClass$new(matrix, element_to_mobject = element_to_mobject, ...)
  class(m) <- c("MobjectMatrix", class(m))
  m
}

#' Determinant label
#'
#' Builds "det" with parentheses around `matrix` and, if `determinant` is
#' given, "= determinant" after it. Add the matrix to the scene separately.
#'
#' @param matrix A [Matrix()].
#' @param determinant Optional value of the determinant.
#' @param background_rect Add a background rectangle behind "det".
#' @param initial_scale_factor Scale of "det" and the parentheses.
#' @return A [VGroup()].
#' @export
#' @examples
#' \dontrun{
#' m <- Matrix(rbind(c(2, 0), c(-1, 1)))
#' det <- get_det_text(m, determinant = 3, initial_scale_factor = 1)
#' }
get_det_text <- function(matrix, determinant = NULL, background_rect = FALSE, initial_scale_factor = 2) {
  parens <- MathTex("(", ")")
  parens$scale(initial_scale_factor)
  parens$stretch_to_fit_height(matrix$height)
  l_paren <- parens$submobjects[[1]]
  r_paren <- parens$submobjects[[2]]
  l_paren$next_to(matrix, LEFT, buff = 0.1)
  r_paren$next_to(matrix, RIGHT, buff = 0.1)
  det <- Tex("det")
  det$scale(initial_scale_factor)
  det$next_to(l_paren, LEFT, buff = 0.1)
  if (background_rect) det$add_background_rectangle()
  det_text <- VGroup(det, l_paren, r_paren)
  if (!is.null(determinant)) {
    eq <- MathTex("=")
    eq$next_to(r_paren, RIGHT, buff = 0.1)
    result <- MathTex(as.character(determinant))
    result$next_to(eq, RIGHT, buff = 0.2)
    det_text$add(eq, result)
  }
  det_text
}
