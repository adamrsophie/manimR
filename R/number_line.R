# Number lines with ticks and number labels.
# Ported from manim/mobject/graphing/number_line.py.

# Number of decimal places implied by a step, like Python's str(step).
decimal_places_from_step <- function(step) {
  s <- as.character(step)
  if (!grepl(".", s, fixed = TRUE)) return(0L)
  nchar(sub("^.*\\.", "", s))
}

# numpy.isclose with its default tolerances.
np_isclose <- function(a, b, rtol = 1e-5, atol = 1e-8) abs(a - b) <= atol + rtol * abs(b)

# Call a constructor given as a function or an R6 generator.
call_constructor <- function(ctor, ...) {
  if (inherits(ctor, "R6ClassGenerator")) ctor$new(...) else ctor(...)
}

# Points start + alpha * (end - start); one point for a scalar alpha, else a matrix.
interpolate_points <- function(start, end, alphas) {
  if (length(alphas) == 1) return(start + alphas * (end - start))
  outer(alphas, end - start) + rep(start, each = length(alphas))
}

#' Number lines
#'
#' `NumberLine()` draws a line with tick marks and optional number labels.
#' `UnitInterval()` is a number line from 0 to 1 with ticks every 0.1.
#'
#' Useful methods: `number_to_point(x)` (alias `n2p`), `point_to_number(p)`
#' (alias `p2n`), `get_tick_range()`, `add_numbers()`, `add_labels()`,
#' `get_number_mobject()`, `get_unit_size()`, `rotate_about_number()`.
#' `n2p()` of a vector returns an n x 3 matrix; `p2n()` of an n x 3 matrix
#' returns a vector.
#'
#' @param x_range `c(x_min, x_max, x_step)`; the step defaults to 1.
#' @param length Length of the line. Overrides `unit_size` when given.
#' @param unit_size Distance between consecutive integers.
#' @param include_ticks Whether to draw ticks.
#' @param tick_size Half length of each tick.
#' @param numbers_with_elongated_ticks Values whose ticks are longer.
#' @param longer_tick_multiple How much longer elongated ticks are.
#' @param exclude_origin_tick Whether to omit the tick at 0.
#' @param rotation Rotation angle in radians.
#' @param stroke_width Line width.
#' @param include_tip Whether to add an arrow tip.
#' @param tip_width,tip_height Tip size.
#' @param tip_shape Tip class generator, for example `StealthTipClass`.
#' @param include_numbers Whether to add number labels.
#' @param font_size Font size of the labels.
#' @param label_direction Direction of the labels from the line.
#' @param label_constructor Function building labels, such as [MathTex()].
#' @param scaling A scale from [LinearBase()] or [LogBase()].
#' @param line_to_number_buff Gap between line and labels.
#' @param decimal_number_config List of arguments for [DecimalNumber()].
#' @param numbers_to_exclude Values that get no number label.
#' @param numbers_to_include Values that get a number label.
#' @param ... Passed to [Line()] (for example `color`).
#' @return A `NumberLine` mobject.
#' @name NumberLine
#' @examples
#' l <- NumberLine(x_range = c(-5, 5, 1), length = 10)
#' l$n2p(2)
#' \dontrun{
#' # The numbers are typeset with LaTeX.
#' NumberLine(x_range = c(-5, 5, 1), length = 10, include_numbers = TRUE)
#' }
NULL

#' @rdname NumberLine
#' @format NULL
#' @usage NULL
#' @export
NumberLineClass <- R6::R6Class("NumberLine", inherit = LineClass, lock_objects = FALSE,
  public = list(
    x_range = NULL,
    x_min = NULL,
    x_max = NULL,
    x_step = NULL,
    length = NULL,
    unit_size = 1,
    include_ticks = TRUE,
    tick_size = 0.1,
    numbers_with_elongated_ticks = NULL,
    longer_tick_multiple = 2,
    exclude_origin_tick = FALSE,
    rotation = 0,
    include_tip = FALSE,
    tip_width = NULL,
    tip_height = NULL,
    font_size = 36,
    include_numbers = FALSE,
    label_direction = NULL,
    label_constructor = NULL,
    line_to_number_buff = MED_SMALL_BUFF,
    decimal_number_config = NULL,
    numbers_to_exclude = NULL,
    numbers_to_include = NULL,
    scaling = NULL,
    ticks = NULL,
    numbers = NULL,
    labels = NULL,
    pieces = NULL,

    initialize = function(x_range = NULL, length = NULL, unit_size = 1, include_ticks = TRUE, tick_size = 0.1,
                          numbers_with_elongated_ticks = NULL, longer_tick_multiple = 2,
                          exclude_origin_tick = FALSE, rotation = 0, stroke_width = 2, include_tip = FALSE,
                          tip_width = DEFAULT_ARROW_TIP_LENGTH, tip_height = DEFAULT_ARROW_TIP_LENGTH,
                          tip_shape = NULL, include_numbers = FALSE, font_size = 36, label_direction = DOWN,
                          label_constructor = MathTex, scaling = LinearBase(),
                          line_to_number_buff = MED_SMALL_BUFF, decimal_number_config = NULL,
                          numbers_to_exclude = NULL, numbers_to_include = NULL, ...) {
      if (is.null(x_range)) {
        x_range <- c(round(-frame_x_radius()), round(frame_x_radius()), 1)
      } else if (length(x_range) == 2) {
        x_range <- c(x_range, 1)
      }
      x_range <- as.numeric(x_range)
      if (is.null(decimal_number_config)) {
        decimal_number_config <- list(num_decimal_places = decimal_places_from_step(x_range[3]))
      }
      self$x_range <- x_range
      scaled <- scaling$func(x_range)
      self$x_min <- scaled[1]
      self$x_max <- scaled[2]
      self$x_step <- scaled[3]
      self$length <- length
      self$unit_size <- unit_size
      self$include_ticks <- include_ticks
      self$tick_size <- tick_size
      self$numbers_with_elongated_ticks <- numbers_with_elongated_ticks
      self$longer_tick_multiple <- longer_tick_multiple
      self$exclude_origin_tick <- exclude_origin_tick
      self$rotation <- rotation
      self$include_tip <- include_tip
      self$tip_width <- tip_width
      self$tip_height <- tip_height
      self$font_size <- font_size
      self$include_numbers <- include_numbers
      self$label_direction <- as_point(label_direction)
      self$label_constructor <- label_constructor
      self$line_to_number_buff <- line_to_number_buff
      self$decimal_number_config <- decimal_number_config
      self$numbers_to_exclude <- numbers_to_exclude
      self$numbers_to_include <- numbers_to_include
      self$scaling <- scaling
      super$initialize(start = x_range[1] * RIGHT, end = x_range[2] * RIGHT, stroke_width = stroke_width, ...)

      if (!is.null(self$length) && self$length != 0) {
        self$set_length(self$length)
        self$unit_size <- self$get_unit_size()
      } else {
        self$scale(self$unit_size)
      }
      self$center()

      if (self$include_tip) {
        self$add_tip(tip_length = self$tip_height, tip_width = self$tip_width, tip_shape = tip_shape)
        self$tip$set_stroke(self$get_stroke_color(), self$stroke_width)
      }
      if (self$include_ticks) self$add_ticks()
      self$rotate(self$rotation)

      if (self$include_numbers || !is.null(self$numbers_to_include)) {
        if (isTRUE(self$scaling$custom_labels)) {
          tick_range <- self$get_tick_range()
          custom <- self$scaling$get_custom_labels(
            tick_range, unit_decimal_places = decimal_number_config$num_decimal_places
          )
          self$add_labels(stats::setNames(custom, tick_range))
        } else {
          self$add_numbers(x_values = self$numbers_to_include, excluding = self$numbers_to_exclude,
                           font_size = self$font_size)
        }
      }
    },

    rotate_about_zero = function(angle, axis = OUT, ...) self$rotate_about_number(0, angle, axis, ...),
    rotate_about_number = function(number, angle, axis = OUT, ...) {
      self$rotate(angle, axis, about_point = self$n2p(number), ...)
    },

    add_ticks = function() {
      ticks <- VGroup()
      elongated_size <- self$tick_size * self$longer_tick_multiple
      offsets <- as.numeric(self$numbers_with_elongated_ticks) - self$x_min
      for (x in self$get_tick_range()) {
        size <- self$tick_size
        if (length(offsets) && any(np_isclose(x - self$x_min, offsets))) size <- elongated_size
        ticks$add(self$get_tick(x, size))
      }
      self$add(ticks)
      self$ticks <- ticks
      invisible(self)
    },
    get_tick = function(x, size = NULL) {
      size <- size %||% self$tick_size
      result <- Line(size * DOWN, size * UP)
      result$rotate(self$get_angle())
      result$move_to(self$number_to_point(x))
      result$match_style(self)
      result
    },
    get_tick_marks = function() self$ticks,
    get_tick_range = function() {
      x_min <- self$x_range[1]
      x_max <- self$x_range[2]
      x_step <- self$x_range[3]
      if (!self$include_tip) x_max <- x_max + 1e-6
      if ((x_min < x_max && x_max < 0) || (x_max > x_min && x_min > 0)) {
        tick_range <- np_arange(x_min, x_max, x_step)
      } else {
        start_point <- 0
        if (self$exclude_origin_tick) start_point <- start_point + x_step
        x_min_segment <- np_arange(start_point, abs(x_min) + 1e-6, x_step) * -1
        x_max_segment <- np_arange(start_point, x_max, x_step)
        tick_range <- sort(unique(c(x_min_segment, x_max_segment) + 0))
      }
      self$scaling$func(tick_range)
    },

    number_to_point = function(number) {
      number <- self$scaling$inverse_function(as.numeric(number))
      alphas <- (number - self$x_range[1]) / (self$x_range[2] - self$x_range[1])
      interpolate_points(self$get_start(), self$get_end(), alphas)
    },
    point_to_number = function(point) {
      se <- self$get_start_and_end()
      start <- se[[1]]
      end <- se[[2]]
      unit_vect <- normalize(end - start)
      denom <- sum((end - start) * unit_vect)
      proportion <- if (is.matrix(point)) {
        drop((as_points(point) - rep(start, each = nrow(point))) %*% unit_vect) / denom
      } else {
        sum((as_point(point) - start) * unit_vect) / denom
      }
      self$scaling$func(interpolate(self$x_range[1], self$x_range[2], proportion))
    },
    n2p = function(number) self$number_to_point(number),
    p2n = function(point) self$point_to_number(point),
    get_unit_size = function() self$get_length() / (self$x_range[2] - self$x_range[1]),
    get_unit_vector = function() super$get_unit_vector() * self$unit_size,

    # Labels ---------------------------------------------------------------
    get_number_mobject = function(x, direction = NULL, buff = NULL, font_size = NULL,
                                  label_constructor = NULL, ...) {
      config <- utils::modifyList(self$decimal_number_config %||% list(), list(...))
      direction <- direction %||% self$label_direction
      buff <- buff %||% self$line_to_number_buff
      font_size <- font_size %||% self$font_size
      label_constructor <- label_constructor %||% self$label_constructor
      num_mob <- do.call(DecimalNumber, c(list(x, font_size = font_size, mob_class = label_constructor), config))
      num_mob$next_to(self$number_to_point(x), direction = direction, buff = buff)
      if (Re(x) < 0 && self$label_direction[1] == 0) {
        # Align without the minus sign.
        num_mob$shift(num_mob$submobjects[[1]]$width * LEFT / 2)
      }
      num_mob
    },
    get_number_mobjects = function(..., numbers = NULL) {
      numbers <- c(numbers, unlist(list(...)))
      if (!length(numbers)) numbers <- self$get_tick_range()
      VGroup(lapply(numbers, function(n) self$get_number_mobject(n)))
    },
    get_labels = function() self$get_number_mobjects(),
    add_numbers = function(x_values = NULL, excluding = NULL, font_size = NULL, label_constructor = NULL, ...) {
      x_values <- x_values %||% self$get_tick_range()
      excluding <- excluding %||% self$numbers_to_exclude
      font_size <- font_size %||% self$font_size
      label_constructor <- label_constructor %||% self$label_constructor
      numbers <- VGroup()
      for (x in x_values) {
        if (length(excluding) && any(abs(x - as.numeric(excluding)) < 1e-9)) next
        numbers$add(self$get_number_mobject(x, font_size = font_size, label_constructor = label_constructor, ...))
      }
      self$add(numbers)
      self$numbers <- numbers
      invisible(self)
    },
    add_labels = function(dict_values, direction = NULL, buff = NULL, font_size = NULL, label_constructor = NULL) {
      direction <- direction %||% self$label_direction
      buff <- buff %||% self$line_to_number_buff
      font_size <- font_size %||% self$font_size
      label_constructor <- label_constructor %||% self$label_constructor
      xs <- as.numeric(names(dict_values))
      if (anyNA(xs)) stop("add_labels() needs a list named by the numeric positions.", call. = FALSE)
      labels <- VGroup()
      for (i in seq_along(dict_values)) {
        label <- dict_values[[i]]
        if (is.character(label) && identical(label_constructor, MathTex)) {
          label <- Tex(label)
        } else if (is.character(label) && identical(label_constructor, MathTypst)) {
          label <- Typst(label)
        } else {
          label <- self$create_label_tex(label, label_constructor)
        }
        if (!exists("font_size", envir = label, inherits = FALSE)) {
          stop(class(label)[1], " is not compatible with add_labels.", call. = FALSE)
        }
        label$font_size <- font_size
        label$next_to(self$number_to_point(xs[i]), direction = direction, buff = buff)
        labels$add(label)
      }
      self$labels <- labels
      self$add(labels)
      invisible(self)
    },
    create_label_tex = function(label_tex, label_constructor = NULL, ...) {
      if (is_vmobject(label_tex)) return(label_tex)
      label_constructor <- label_constructor %||% self$label_constructor
      call_constructor(label_constructor, as.character(label_tex), ...)
    }
  )
)

#' @rdname NumberLine
#' @export
NumberLine <- constructor(NumberLineClass)
#' @rdname NumberLine
#' @format NULL
#' @usage NULL
#' @export
UnitIntervalClass <- R6::R6Class("UnitInterval", inherit = NumberLineClass, lock_objects = FALSE,
  public = list(
    initialize = function(unit_size = 10, numbers_with_elongated_ticks = NULL, decimal_number_config = NULL, ...) {
      super$initialize(x_range = c(0, 1, 0.1), unit_size = unit_size,
                       numbers_with_elongated_ticks = numbers_with_elongated_ticks %||% c(0, 1),
                       decimal_number_config = decimal_number_config %||% list(num_decimal_places = 1), ...)
    }
  )
)

#' @rdname NumberLine
#' @export
UnitInterval <- constructor(UnitIntervalClass)