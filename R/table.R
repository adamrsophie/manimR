# Mobjects representing tables. Ported from manim/mobject/table.py.

#' @title Table
#' @description Displays a table: entries made with `element_to_mobject` (by
#'   default [Paragraph()]) arranged in a grid, with optional row and column
#'   labels and lines between the cells. `MathTable()`, `MobjectTable()`,
#'   `IntegerTable()` and `DecimalTable()` use [MathTex()], the given
#'   mobjects, [Integer()] and [DecimalNumber()] as entries.
#'
#'   Positions `pos = c(row, col)` are 1 based with `c(1, 1)` the top left
#'   entry. Methods: `get_rows()`, `get_columns()`, `get_entries(pos)`,
#'   `get_entries_without_labels(pos)`, `get_row_labels()`,
#'   `get_col_labels()`, `get_labels()`, `get_horizontal_lines()`,
#'   `get_vertical_lines()`, `set_row_colors(...)`, `set_column_colors(...)`,
#'   `get_cell(pos, ...)`, `get_highlighted_cell(pos, color, ...)`,
#'   `add_highlighted_cell(pos, color, ...)`, `add_background_to_entries()`
#'   and `create(...)`, an animation drawing the table.
#' @param table An R matrix, a data frame, or a list of rows (vectors or
#'   lists) of equal length.
#' @param row_labels,col_labels Lists of mobjects labeling the rows and columns.
#' @param top_left_entry Mobject in the top left corner (needs both kinds of labels).
#' @param v_buff,h_buff Vertical and horizontal buffer between cells.
#' @param include_outer_lines Draw the outer border.
#' @param include_inner_lines Draw the lines between cells.
#' @param add_background_rectangles_to_entries Add a background rectangle to each entry.
#' @param entries_background_color Color of those rectangles.
#' @param include_background_rectangle Add a background rectangle to the table.
#' @param background_rectangle_color Color of that rectangle.
#' @param element_to_mobject Constructor applied to each entry.
#' @param element_to_mobject_config Named list of extra arguments for it.
#' @param arrange_in_grid_config Named list passed to `arrange_in_grid()`.
#' @param line_config Named list passed to [Line()] for the table lines.
#' @param ... Passed to [VGroup()].
#' @export
#' @examples
#' t <- Table(list(c("This", "is a"), c("simple", "Table in \n Manim.")))
#' t$add_highlighted_cell(c(2, 2), color = GREEN)
TableClass <- R6::R6Class("Table", inherit = VGroupClass, lock_objects = FALSE,
  public = list(
    row_labels = NULL,
    col_labels = NULL,
    top_left_entry = NULL,
    row_dim = 0,
    col_dim = 0,
    v_buff = 0.8,
    h_buff = 1.3,
    include_outer_lines = FALSE,
    include_inner_lines = TRUE,
    add_background_rectangles_to_entries = FALSE,
    entries_background_color = NULL,
    include_background_rectangle = FALSE,
    background_rectangle_color = NULL,
    element_to_mobject = NULL,
    element_to_mobject_config = NULL,
    arrange_in_grid_config = NULL,
    line_config = NULL,
    elements_without_labels = NULL,
    elements = NULL,
    # The cells of the arranged grid (labels included) in row major order,
    # with the grid size; get_mob_table() rebuilds the rows.
    mob_table_cells = NULL,
    mob_table_rows = 0,
    mob_table_cols = 0,
    horizontal_lines = NULL,
    vertical_lines = NULL,
    initialize = function(table, row_labels = NULL, col_labels = NULL, top_left_entry = NULL, v_buff = 0.8,
                          h_buff = 1.3, include_outer_lines = FALSE, include_inner_lines = TRUE,
                          add_background_rectangles_to_entries = FALSE, entries_background_color = BLACK,
                          include_background_rectangle = FALSE, background_rectangle_color = BLACK,
                          element_to_mobject = Paragraph, element_to_mobject_config = list(),
                          arrange_in_grid_config = list(), line_config = list(), ...) {
      table_data <- matrix_rows(table)
      self$row_labels <- if (length(row_labels)) as.list(row_labels) else NULL
      self$col_labels <- if (length(col_labels)) as.list(col_labels) else NULL
      self$top_left_entry <- top_left_entry
      self$row_dim <- length(table_data)
      self$col_dim <- length(table_data[[1]])
      self$v_buff <- v_buff
      self$h_buff <- h_buff
      self$include_outer_lines <- include_outer_lines
      self$include_inner_lines <- include_inner_lines
      self$add_background_rectangles_to_entries <- add_background_rectangles_to_entries
      self$entries_background_color <- manim_color(entries_background_color)
      self$include_background_rectangle <- include_background_rectangle
      self$background_rectangle_color <- manim_color(background_rectangle_color)
      self$element_to_mobject <- element_to_mobject
      self$element_to_mobject_config <- element_to_mobject_config
      self$arrange_in_grid_config <- arrange_in_grid_config
      self$line_config <- line_config
      if (any(lengths(table_data) != self$col_dim)) stop("Not all rows in table have the same length.", call. = FALSE)
      super$initialize(...)
      mob_table <- self$table_to_mob_table(table_data)
      self$elements_without_labels <- VGroup(unlist(mob_table, recursive = FALSE))
      mob_table <- self$add_labels(mob_table)
      self$organize_mob_table(mob_table)
      self$elements <- VGroup(unlist(mob_table, recursive = FALSE))
      first <- self$elements$submobjects[[1]]
      if (nrow(first$get_all_points()) == 0) self$elements$remove(first)
      self$add(self$elements)
      self$center()
      self$mob_table_rows <- length(mob_table)
      self$mob_table_cols <- length(mob_table[[1]])
      self$mob_table_cells <- unlist(mob_table, recursive = FALSE)
      self$add_horizontal_lines()
      self$add_vertical_lines()
      if (self$add_background_rectangles_to_entries) self$add_background_to_entries(color = self$entries_background_color)
      if (self$include_background_rectangle) self$add_background_rectangle(color = self$background_rectangle_color)
    },
    table_to_mob_table = function(table) {
      f <- self$element_to_mobject
      lapply(table, function(row) {
        lapply(row, function(item) {
          # Paragraph needs strings; upstream entries are usually strings already.
          if (identical(f, Paragraph) && !is_mobject(item)) item <- as.character(item)
          matrix_entry_mobject(f, item, self$element_to_mobject_config)
        })
      })
    },
    organize_mob_table = function(table) {
      help_table <- VGroup(unlist(table, recursive = FALSE))
      do.call(help_table$arrange_in_grid, c(list(rows = length(table), cols = length(table[[1]]),
                                                 buff = c(self$h_buff, self$v_buff)), self$arrange_in_grid_config))
      help_table
    },
    add_labels = function(mob_table) {
      if (!is.null(self$row_labels)) {
        for (k in seq_along(self$row_labels)) mob_table[[k]] <- c(list(self$row_labels[[k]]), mob_table[[k]])
      }
      if (!is.null(self$col_labels)) {
        if (!is.null(self$row_labels)) {
          # A placeholder keeps arrange_in_grid working without top_left_entry.
          corner <- self$top_left_entry %||% VMobject()
          mob_table <- c(list(c(list(corner), self$col_labels)), mob_table)
        } else {
          mob_table <- c(list(self$col_labels), mob_table)
        }
      }
      mob_table
    },
    # The grid cells (labels included) as a list of rows.
    get_mob_table = function() {
      n <- self$mob_table_cols
      lapply(seq_len(self$mob_table_rows), function(i) self$mob_table_cells[(i - 1) * n + seq_len(n)])
    },
    add_horizontal_lines = function() {
      anchor_left <- self$get_left()[1] - 0.5 * self$h_buff
      anchor_right <- self$get_right()[1] + 0.5 * self$h_buff
      line_group <- VGroup()
      rows <- self$get_rows()$submobjects
      hline <- function(y) {
        line <- do.call(Line, c(list(c(anchor_left, y, 0), c(anchor_right, y, 0)), self$line_config))
        line_group$add(line)
        self$add(line)
      }
      if (self$include_outer_lines) {
        hline(rows[[1]]$get_top()[2] + 0.5 * self$v_buff)
        hline(rows[[length(rows)]]$get_bottom()[2] - 0.5 * self$v_buff)
      }
      if (self$include_inner_lines) {
        for (k in seq_len(self$mob_table_rows - 1)) {
          hline(rows[[k + 1]]$get_top()[2] + 0.5 * (rows[[k]]$get_bottom()[2] - rows[[k + 1]]$get_top()[2]))
        }
      }
      self$horizontal_lines <- line_group
      invisible(self)
    },
    add_vertical_lines = function() {
      rows <- self$get_rows()
      anchor_top <- rows$get_top()[2] + 0.5 * self$v_buff
      anchor_bottom <- rows$get_bottom()[2] - 0.5 * self$v_buff
      cols <- self$get_columns()$submobjects
      line_group <- VGroup()
      vline <- function(x, from, to) {
        line <- do.call(Line, c(list(c(x, from, 0), c(x, to, 0)), self$line_config))
        line_group$add(line)
        self$add(line)
      }
      if (self$include_outer_lines) {
        vline(cols[[1]]$get_left()[1] - 0.5 * self$h_buff, anchor_top, anchor_bottom)
        vline(cols[[length(cols)]]$get_right()[1] + 0.5 * self$h_buff, anchor_top, anchor_bottom)
      }
      if (self$include_inner_lines) {
        for (k in seq_len(self$mob_table_cols - 1)) {
          x <- cols[[k + 1]]$get_left()[1] + 0.5 * (cols[[k]]$get_right()[1] - cols[[k + 1]]$get_left()[1])
          vline(x, anchor_bottom, anchor_top)
        }
      }
      self$vertical_lines <- line_group
      invisible(self)
    },
    get_horizontal_lines = function() self$horizontal_lines,
    get_vertical_lines = function() self$vertical_lines,
    get_columns = function() {
      mt <- self$get_mob_table()
      VGroup(lapply(seq_len(self$mob_table_cols), function(j) VGroup(lapply(mt, `[[`, j))))
    },
    get_rows = function() VGroup(lapply(self$get_mob_table(), VGroup)),
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
    get_entries = function(pos = NULL) {
      if (is.null(pos)) return(self$elements)
      offset <- if (!is.null(self$row_labels) && !is.null(self$col_labels) && is.null(self$top_left_entry)) 2 else 1
      self$elements$submobjects[[self$mob_table_cols * (pos[1] - 1) + pos[2] - offset + 1]]
    },
    get_entries_without_labels = function(pos = NULL) {
      if (is.null(pos)) return(self$elements_without_labels)
      self$elements_without_labels$submobjects[[self$col_dim * (pos[1] - 1) + pos[2]]]
    },
    get_row_labels = function() VGroup(self$row_labels),
    get_col_labels = function() VGroup(self$col_labels),
    get_labels = function() {
      label_group <- VGroup()
      if (!is.null(self$top_left_entry)) label_group$add(self$top_left_entry)
      for (lab in list(self$col_labels, self$row_labels)) if (!is.null(lab)) label_group$add(lab)
      label_group
    },
    add_background_to_entries = function(color = BLACK) {
      for (mob in self$get_entries()$submobjects) mob$add_background_rectangle(color = manim_color(color))
      invisible(self)
    },
    # The cell at `pos` as a rectangular Polygon, without the entry.
    get_cell = function(pos = c(1, 1), ...) {
      row <- self$get_rows()$submobjects[[pos[1]]]
      col <- self$get_columns()$submobjects[[pos[2]]]
      left <- col$get_left()[1] - self$h_buff / 2
      right <- col$get_right()[1] + self$h_buff / 2
      top <- row$get_top()[2] + self$v_buff / 2
      bottom <- row$get_bottom()[2] - self$v_buff / 2
      Polygon(c(left, top, 0), c(right, top, 0), c(right, bottom, 0), c(left, bottom, 0), ...)
    },
    get_highlighted_cell = function(pos = c(1, 1), color = PURE_YELLOW, ...) {
      BackgroundRectangle(self$get_cell(pos), color = manim_color(color), ...)
    },
    add_highlighted_cell = function(pos = c(1, 1), color = PURE_YELLOW, ...) {
      bg_cell <- self$get_highlighted_cell(pos, color = color, ...)
      self$add_to_back(bg_cell)
      entry <- self$get_entries(pos)
      entry$background_rectangle <- bg_cell
      invisible(self)
    },
    create = function(lag_ratio = 1, line_animation = Create, label_animation = Write, element_animation = Create,
                      entry_animation = FadeIn, ...) {
      animations <- list(
        line_animation(VGroup(self$vertical_lines, self$horizontal_lines), ...),
        element_animation(self$elements_without_labels$set_z_index(2), ...)
      )
      labels <- self$get_labels()
      if (length(labels$submobjects)) animations[[length(animations) + 1]] <- label_animation(labels, ...)
      if (length(self$get_entries()$submobjects)) {
        for (entry in self$elements_without_labels$submobjects) {
          if (!is.null(entry$background_rectangle)) {
            animations[[length(animations) + 1]] <- entry_animation(entry$background_rectangle, ...)
          }
        }
      }
      do.call(AnimationGroup, c(animations, list(lag_ratio = lag_ratio)))
    },
    # h_buff and v_buff follow the scale so get_cell stays accurate.
    scale = function(scale_factor, scale_stroke = FALSE, ...) {
      self$h_buff <- self$h_buff * scale_factor
      self$v_buff <- self$v_buff * scale_factor
      super$scale(scale_factor, scale_stroke = scale_stroke, ...)
    }
  )
)

#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @rdname TableClass
#' @export
Table <- constructor(TableClass)
#' @rdname TableClass
#' @export
MathTable <- function(table, element_to_mobject = MathTex, ...) {
  t <- TableClass$new(table, element_to_mobject = element_to_mobject, ...)
  class(t) <- c("MathTable", class(t))
  t
}

#' @rdname TableClass
#' @export
MobjectTable <- function(table, element_to_mobject = function(m) m, ...) {
  t <- TableClass$new(table, element_to_mobject = element_to_mobject, ...)
  class(t) <- c("MobjectTable", class(t))
  t
}

#' @rdname TableClass
#' @export
IntegerTable <- function(table, element_to_mobject = Integer, ...) {
  t <- TableClass$new(table, element_to_mobject = element_to_mobject, ...)
  class(t) <- c("IntegerTable", class(t))
  t
}

#' @rdname TableClass
#' @export
DecimalTable <- function(table, element_to_mobject = DecimalNumber,
                         element_to_mobject_config = list(num_decimal_places = 1), ...) {
  t <- TableClass$new(table, element_to_mobject = element_to_mobject,
                      element_to_mobject_config = element_to_mobject_config, ...)
  class(t) <- c("DecimalTable", class(t))
  t
}
