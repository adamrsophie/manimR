# Mobjects for probability: sample spaces and bar charts.
# Ported from manim/mobject/graphing/probability.py.

PROBABILITY_EPSILON <- 0.0001

#' Sample spaces and bar charts
#'
#' `SampleSpace()` is a rectangle that can be divided horizontally or
#' vertically into parts with areas proportional to probabilities, with
#' braces and labels. `BarChart()` is an [Axes()] with one bar per value.
#'
#' SampleSpace methods: `add_title()`, `add_label()`, `complete_p_list()`,
#' `get_horizontal_division()`, `get_vertical_division()`,
#' `divide_horizontally()`, `divide_vertically()`,
#' `get_side_braces_and_labels()`, `get_top_braces_and_labels()`,
#' `get_bottom_braces_and_labels()`, `add_braces_and_labels()`. Indexing
#' `space[i]` returns the i-th part once the space is divided.
#'
#' BarChart methods: `get_bar_labels()`, `change_bar_values()`. Bars are in
#' the field `bars`.
#'
#' @param height,width Size of the sample space.
#' @param fill_color,fill_opacity,stroke_width,stroke_color Style.
#' @param default_label_scale_val Scale applied to string labels.
#' @param values Numeric bar heights.
#' @param bar_names Labels under the bars.
#' @param y_range `c(min, max, step)` of the y axis; computed from `values`
#'   when `NULL`.
#' @param x_length,y_length Axis lengths.
#' @param bar_colors Colors spread over the bars as a gradient.
#' @param bar_width Width of each bar in x units.
#' @param bar_fill_opacity,bar_stroke_width Bar style.
#' @param x_axis_config,y_axis_config Lists of [NumberLine()] arguments.
#' @param tips Whether the axes get tips.
#' @param ... Passed to [Rectangle()] or [Axes()].
#' @return A mobject.
#' @name probability
#' @examples
#' \dontrun{
#' # Needs LaTeX and dvisvgm.
#' s <- SampleSpace()$divide_vertically(c(0.3, 0.7))
#' chart <- BarChart(c(1, 3, 2), bar_names = c("a", "b", "c"))
#' }
NULL

#' @rdname probability
#' @format NULL
#' @usage NULL
#' @export
SampleSpaceClass <- R6::R6Class("SampleSpace", inherit = RectangleClass, lock_objects = FALSE,
  public = list(
    default_label_scale_val = 1,
    title = NULL,
    label = NULL,
    horizontal_parts = NULL,
    vertical_parts = NULL,
    initialize = function(height = 3, width = 3, fill_color = DARK_GREY, fill_opacity = 1, stroke_width = 0.5,
                          stroke_color = LIGHT_GREY, default_label_scale_val = 1, ...) {
      super$initialize(height = height, width = width, fill_color = fill_color, fill_opacity = fill_opacity,
                       stroke_width = stroke_width, stroke_color = stroke_color, ...)
      self$default_label_scale_val <- default_label_scale_val
    },
    add_title = function(title = "Sample space", buff = MED_SMALL_BUFF) {
      title_mob <- Tex(title)
      if (title_mob$width > self$width) title_mob$width <- self$width
      title_mob$next_to(self, UP, buff = buff)
      self$title <- title_mob
      self$add(title_mob)
      invisible(self)
    },
    add_label = function(label) {
      self$label <- label
      invisible(self)
    },
    complete_p_list = function(p_list) {
      p_list <- as.numeric(unlist(p_list))
      remainder <- 1 - sum(p_list)
      if (abs(remainder) > PROBABILITY_EPSILON) p_list <- c(p_list, remainder)
      p_list
    },
    get_division_along_dimension = function(p_list, dim, colors, vect) {
      p_list <- self$complete_p_list(p_list)
      colors <- color_gradient(colors, length(p_list))
      last_point <- self$get_edge_center(-vect)
      parts <- VGroup()
      for (i in seq_along(p_list)) {
        part <- SampleSpace()
        part$set_fill(colors[i], 1)
        part$replace(self, stretch = TRUE)
        part$stretch(p_list[i], dim)
        part$move_to(last_point, -vect)
        last_point <- part$get_edge_center(vect)
        parts$add(part)
      }
      parts
    },
    get_horizontal_division = function(p_list, colors = c(GREEN_E, BLUE_E), vect = DOWN) {
      self$get_division_along_dimension(p_list, 2, colors, vect)
    },
    get_vertical_division = function(p_list, colors = c(MAROON_B, YELLOW), vect = RIGHT) {
      self$get_division_along_dimension(p_list, 1, colors, vect)
    },
    divide_horizontally = function(...) {
      self$horizontal_parts <- self$get_horizontal_division(...)
      self$add(self$horizontal_parts)
      invisible(self)
    },
    divide_vertically = function(...) {
      self$vertical_parts <- self$get_vertical_division(...)
      self$add(self$vertical_parts)
      invisible(self)
    },
    get_subdivision_braces_and_labels = function(parts, labels, direction, buff = SMALL_BUFF, min_num_quads = 1) {
      label_mobs <- VGroup()
      braces <- VGroup()
      for (i in seq_len(min(length(labels), length(parts$submobjects)))) {
        label <- labels[[i]]
        part <- parts$submobjects[[i]]
        # Upstream passes min_num_quads on to Brace, whose base class rejects
        # it; the argument is accepted here and has no effect.
        brace <- Brace(part, direction, buff = buff)
        if (is_vmobject(label)) {
          label_mob <- label
        } else {
          label_mob <- MathTex(label)
          label_mob$scale(self$default_label_scale_val)
        }
        label_mob$next_to(brace, direction, buff)
        braces$add(brace)
        label_mobs$add(label_mob)
      }
      parts$braces <- braces
      parts$labels <- label_mobs
      parts$label_kwargs <- list(labels = label_mobs$copy(), direction = direction, buff = buff)
      VGroup(parts$braces, parts$labels)
    },
    get_side_braces_and_labels = function(labels, direction = LEFT, ...) {
      stopifnot(!is.null(self$horizontal_parts))
      self$get_subdivision_braces_and_labels(self$horizontal_parts, labels, direction, ...)
    },
    get_top_braces_and_labels = function(labels, ...) {
      stopifnot(!is.null(self$vertical_parts))
      self$get_subdivision_braces_and_labels(self$vertical_parts, labels, UP, ...)
    },
    get_bottom_braces_and_labels = function(labels, ...) {
      stopifnot(!is.null(self$vertical_parts))
      self$get_subdivision_braces_and_labels(self$vertical_parts, labels, DOWN, ...)
    },
    add_braces_and_labels = function() {
      for (parts in list(self$horizontal_parts, self$vertical_parts)) {
        if (is.null(parts)) next
        for (sub in c("braces", "labels")) if (!is.null(parts[[sub]])) self$add(parts[[sub]])
      }
      invisible(self)
    }
  )
)

#' @rdname probability
#' @export
SampleSpace <- constructor(SampleSpaceClass)
#' @rdname probability
#' @param x A SampleSpace.
#' @param i Index (1 based).
#' @export
`[.SampleSpace` <- function(x, i, ...) {
  if (!is.null(x$horizontal_parts)) return(x$horizontal_parts[i])
  if (!is.null(x$vertical_parts)) return(x$vertical_parts[i])
  NextMethod()
}

#' @rdname probability
#' @format NULL
#' @usage NULL
#' @export
BarChartClass <- R6::R6Class("BarChart", inherit = AxesClass, lock_objects = FALSE,
  public = list(
    values = NULL,
    bar_names = NULL,
    bar_colors = NULL,
    bar_width = 0.6,
    bar_fill_opacity = 0.7,
    bar_stroke_width = 3,
    bars = NULL,
    x_labels = NULL,
    bar_labels = NULL,

    initialize = function(values, bar_names = NULL, y_range = NULL, x_length = NULL, y_length = NULL,
                          bar_colors = c("#003f5c", "#58508d", "#bc5090", "#ff6361", "#ffa600"),
                          bar_width = 0.6, bar_fill_opacity = 0.7, bar_stroke_width = 3,
                          x_axis_config = NULL, y_axis_config = NULL, tips = FALSE, ...) {
      y_length <- y_length %||% (frame_height() - 4)
      self$values <- as.numeric(values)
      self$bar_names <- bar_names
      self$bar_colors <- bar_colors
      self$bar_width <- bar_width
      self$bar_fill_opacity <- bar_fill_opacity
      self$bar_stroke_width <- bar_stroke_width
      n <- length(self$values)
      x_range <- c(0, n, 1)
      y_defaults <- list(include_numbers = TRUE)
      if (is.null(y_range) || length(y_range) == 2) {
        step <- round(max(self$values) / y_length, 2)
        y_range <- if (is.null(y_range)) c(min(0, min(self$values)), max(0, max(self$values)), step) else c(y_range, step)
        # Upstream computes a float step, whose str() always shows a decimal place.
        y_defaults$decimal_number_config <- list(num_decimal_places = max(1L, decimal_places_from_step(step)))
      }
      x_length <- x_length %||% min(n, frame_width() - 2)
      x_axis_config <- update_config(list(font_size = 24, label_constructor = Tex), x_axis_config)
      y_axis_config <- update_config(y_defaults, y_axis_config)
      self$bars <- VGroup()
      super$initialize(x_range = x_range, y_range = y_range, x_length = x_length, y_length = y_length,
                       x_axis_config = x_axis_config, y_axis_config = y_axis_config, tips = tips, ...)
      self$add_bars()
      if (!is.null(self$bar_names)) self$add_x_axis_labels()
    },
    update_colors = function() {
      self$bars$set_color_by_gradient(self$bar_colors)
      invisible(self)
    },
    add_x_axis_labels = function() {
      val_range <- np_arange(0.5, length(self$bar_names), 1)
      labels <- VGroup()
      for (i in seq_along(self$bar_names)) {
        direction <- if (self$values[i] < 0) UP else DOWN
        lab <- call_constructor(self$x_axis$label_constructor, self$bar_names[[i]])
        lab$font_size <- self$x_axis$font_size
        lab$next_to(self$x_axis$number_to_point(val_range[i]), direction = direction,
                    buff = self$x_axis$line_to_number_buff)
        labels$add(lab)
      }
      self$x_axis$labels <- labels
      self$x_labels <- labels
      self$x_axis$add(labels)
      invisible(self)
    },
    create_bar = function(bar_number, value) {
      # bar_number is 0 based, as upstream.
      bar_h <- abs(self$c2p(0, value)[2] - self$c2p(0, 0)[2])
      bar_w <- self$c2p(self$bar_width, 0)[1] - self$c2p(0, 0)[1]
      bar <- Rectangle(height = bar_h, width = bar_w, stroke_width = self$bar_stroke_width,
                       fill_opacity = self$bar_fill_opacity)
      pos <- if (value >= 0) UP else DOWN
      bar$next_to(self$c2p(bar_number + 0.5, 0), pos, buff = 0)
      bar
    },
    add_bars = function() {
      for (i in seq_along(self$values)) self$bars$add(self$create_bar(i - 1, self$values[i]))
      self$update_colors()
      self$add_to_back(self$bars)
      invisible(self)
    },
    get_bar_labels = function(color = NULL, font_size = 24, buff = MED_SMALL_BUFF, label_constructor = Tex) {
      bar_labels <- VGroup()
      bars <- self$bars$submobjects
      for (i in seq_len(min(length(bars), length(self$values)))) {
        bar <- bars[[i]]
        value <- self$values[i]
        lbl <- call_constructor(label_constructor, as.character(value))
        lbl$set_color(color %||% bar$get_fill_color())
        lbl$font_size <- font_size
        lbl$next_to(bar, if (value >= 0) UP else DOWN, buff = buff)
        bar_labels$add(lbl)
      }
      bar_labels
    },
    change_bar_values = function(values, update_colors = TRUE) {
      values <- as.numeric(values)
      bars <- self$bars$submobjects
      for (i in seq_len(min(length(bars), length(values)))) {
        bar <- bars[[i]]
        value <- values[i]
        chart_val <- self$values[i]
        if (chart_val > 0) {
          bar_lim <- bar$get_bottom()
          aligned_edge <- DOWN
        } else {
          bar_lim <- bar$get_top()
          aligned_edge <- UP
        }
        if (chart_val != 0) {
          quotient <- value / chart_val
          # A sign change flips the bar to the other side of the axis.
          if (quotient < 0) aligned_edge <- if (chart_val > 0) UP else DOWN
          bar$stretch_to_fit_height(abs(quotient) * bar$height)
        } else {
          # A zero height bar cannot be stretched, so build a new one.
          temp_bar <- self$create_bar(i - 1, value)
          self$bars$remove(bar)
          self$bars$insert(i, temp_bar)
        }
        bar$move_to(bar_lim, aligned_edge)
      }
      if (update_colors) self$update_colors()
      self$values[seq_along(values)] <- values
      invisible(self)
    }
  )
)

#' @rdname probability
#' @export
BarChart <- constructor(BarChartClass)