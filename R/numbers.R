# Numbers and braces. Ported from manim/mobject/text/numbers.py and
# manim/mobject/svg/brace.py.

format_number <- function(x, digits, include_sign = FALSE, group_with_commas = TRUE) {
  s <- formatC(x, format = "f", digits = digits, big.mark = if (group_with_commas) "," else "",
               flag = if (include_sign) "+" else "")
  s
}

string_to_mob <- function(string, mob_class, font_size, ...) {
  if (is.null(.manim$string_to_mob_map)) .manim$string_to_mob_map <- new.env(parent = emptyenv())
  key <- paste(digest::digest(deparse(mob_class)), string, digest::digest(list(...)), sep = "\r")
  cached <- .manim$string_to_mob_map[[key]]
  if (is.null(cached)) {
    cached <- mob_class(string, ...)
    # The SVG id lookup table is not needed for digits and doubles copy cost.
    if (!is.null(cached$id_to_vgroup_dict)) cached$id_to_vgroup_dict <- NULL
    assign(key, cached, envir = .manim$string_to_mob_map)
  }
  mob <- cached$copy()
  mob$font_size <- font_size
  mob
}

#' @title DecimalNumber, Integer and Variable
#' @description A number typeset digit by digit (with LaTeX by default) that
#'   can be updated with `set_value()`, for example in an updater or with
#'   [ChangeDecimalToValue()]. `Variable()` shows `label = value` driven by a
#'   [ValueTracker()] stored in `$tracker`.
#' @param number The number (real or complex).
#' @param num_decimal_places Digits after the decimal point.
#' @param mob_class Constructor for each character, [MathTex()] by default.
#' @param include_sign Always show the sign.
#' @param group_with_commas Insert thousands separators.
#' @param digit_buff_per_font_unit Gap between characters per font size unit.
#' @param show_ellipsis Append an ellipsis.
#' @param unit Optional unit string; aligned to the top when it starts with `^`.
#' @param unit_buff_per_font_unit Gap before the unit.
#' @param include_background_rectangle Add a background rectangle.
#' @param edge_to_fix Edge kept fixed when the value changes.
#' @param font_size Font size.
#' @param stroke_width,fill_opacity Style.
#' @param ... Passed to [VMobject()].
#' @export
#' @examples
#' \dontrun{
#' # Needs LaTeX and dvisvgm.
#' d <- DecimalNumber(3.14159, num_decimal_places = 3)
#' d$set_value(2.71828)
#' }
DecimalNumberClass <- R6::R6Class("DecimalNumber", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    number = 0,
    num_string = NULL,
    num_decimal_places = 2,
    mob_class = NULL,
    include_sign = FALSE,
    group_with_commas = TRUE,
    digit_buff_per_font_unit = 0.001,
    show_ellipsis = FALSE,
    unit = NULL,
    unit_sign = NULL,
    unit_buff_per_font_unit = 0,
    include_background_rectangle = FALSE,
    edge_to_fix = NULL,
    base_font_size = DEFAULT_FONT_SIZE,
    initial_height = NULL,
    initialize = function(number = 0, num_decimal_places = 2, mob_class = MathTex, include_sign = FALSE,
                          group_with_commas = TRUE, digit_buff_per_font_unit = 0.001, show_ellipsis = FALSE,
                          unit = NULL, unit_buff_per_font_unit = 0, include_background_rectangle = FALSE,
                          edge_to_fix = LEFT, font_size = DEFAULT_FONT_SIZE, stroke_width = 0, fill_opacity = 1, ...) {
      super$initialize(..., fill_opacity = fill_opacity, stroke_width = stroke_width)
      self$number <- number
      self$num_decimal_places <- num_decimal_places
      self$include_sign <- include_sign
      self$mob_class <- mob_class
      self$group_with_commas <- group_with_commas
      self$digit_buff_per_font_unit <- digit_buff_per_font_unit
      self$show_ellipsis <- show_ellipsis
      self$unit <- unit
      self$unit_buff_per_font_unit <- unit_buff_per_font_unit
      self$include_background_rectangle <- include_background_rectangle
      self$edge_to_fix <- edge_to_fix
      self$base_font_size <- font_size
      self$fill_opacity <- fill_opacity
      self$set_submobjects_from_number(number)
      self$init_colors()
      # init_colors() paints the whole family, the background rectangle too;
      # give it back its own style (upstream leaves it opaque white).
      if (self$include_background_rectangle && !is.null(self$background_rectangle)) {
        self$background_rectangle$set_style(fill_color = cfg("background_color"), fill_opacity = 0.75, stroke_width = 0)
      }
    },
    get_num_string = function(number) {
      if (is.complex(number)) {
        s <- paste0(format_number(Re(number), self$num_decimal_places, self$include_sign, self$group_with_commas),
                    format_number(Im(number), self$num_decimal_places, TRUE, self$group_with_commas), "i")
        return(s)
      }
      s <- format_number(number, self$num_decimal_places, self$include_sign, self$group_with_commas)
      if (startsWith(s, "-") && round(number, self$num_decimal_places) == 0) {
        s <- if (self$include_sign) paste0("+", substring(s, 2)) else substring(s, 2)
      }
      s
    },
    string_to_mob = function(string, mob_class = NULL, ...) {
      string_to_mob(string, mob_class %||% self$mob_class, self$base_font_size, ...)
    },
    set_submobjects_from_number = function(number) {
      self$number <- number
      self$submobjects <- list()
      num_string <- self$get_num_string(number)
      self$num_string <- num_string
      chars <- strsplit(num_string, "")[[1]]
      self$add(lapply(chars, function(ch) self$string_to_mob(ch)))
      if (self$show_ellipsis) self$add(self$string_to_mob("\\dots", SingleStringMathTex, color = self$color))
      self$arrange(buff = self$digit_buff_per_font_unit * self$base_font_size, aligned_edge = DOWN)
      if (!is.null(self$unit)) {
        self$unit_sign <- self$string_to_mob(self$unit, SingleStringMathTex)
        self$add(self$unit_sign$next_to(self, direction = RIGHT,
                                        buff = (self$unit_buff_per_font_unit + self$digit_buff_per_font_unit) * self$base_font_size,
                                        aligned_edge = DOWN))
      }
      self$move_to(ORIGIN)
      sm <- self$submobjects
      for (i in seq_along(chars)) {
        if (chars[i] == "-" && length(chars) > i) {
          sm[[i]]$align_to(sm[[i + 1]], UP)
          sm[[i]]$shift(sm[[i + 1]]$height * DOWN / 2)
        } else if (chars[i] == ",") {
          sm[[i]]$shift(sm[[i]]$height * DOWN / 2)
        }
      }
      if (!is.null(self$unit) && startsWith(self$unit, "^")) self$unit_sign$align_to(self, UP)
      self$initial_height <- self$height
      if (self$include_background_rectangle) self$add_background_rectangle()
      invisible(self)
    },
    set_value = function(number) {
      old_family <- self$get_family()
      old_font_size <- self$font_size
      move_to_point <- self$get_edge_center(self$edge_to_fix)
      old_sub <- self$submobjects
      self$set_submobjects_from_number(number)
      self$font_size <- old_font_size
      self$move_to(move_to_point, self$edge_to_fix)
      new_sub <- self$submobjects
      for (i in seq_len(min(length(new_sub), length(old_sub)))) {
        if (is_vmobject(new_sub[[i]]) && is_vmobject(old_sub[[i]])) new_sub[[i]]$match_style(old_sub[[i]])
      }
      for (m in old_family) if (nrow(m$points)) m$points[] <- 0
      self$init_colors()
      invisible(self)
    },
    get_value = function() self$number,
    increment_value = function(delta_t = 1) self$set_value(self$get_value() + delta_t)
  ),
  active = list(
    font_size = function(value) {
      cur <- if (is.null(self$initial_height) || self$initial_height == 0) self$base_font_size
        else self$height / self$initial_height * self$base_font_size
      if (missing(value)) return(cur)
      if (value <= 0) stop("font_size must be greater than 0.", call. = FALSE)
      if (self$height > 0) self$scale(value / cur)
    }
  )
)

#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @rdname DecimalNumberClass
#' @export
DecimalNumber <- constructor(DecimalNumberClass)
#' @rdname DecimalNumberClass
#' @format NULL
#' @usage NULL
#' @export
IntegerClass <- R6::R6Class("Integer", inherit = DecimalNumberClass, lock_objects = FALSE,
  public = list(
    initialize = function(number = 0, num_decimal_places = 0, ...) {
      super$initialize(number = number, num_decimal_places = num_decimal_places, ...)
    },
    get_value = function() round(super$get_value())
  )
)

#' @rdname DecimalNumberClass
#' @export
Integer <- constructor(IntegerClass)
#' @rdname DecimalNumberClass
#' @param var Initial value of the variable.
#' @param label Label string (typeset with [MathTex()]) or a mobject.
#' @param var_type `"decimal"` or `"integer"` (or the constructors `DecimalNumber` / `Integer`).
#' @export
Variable <- function(var, label, var_type = "decimal", num_decimal_places = 2, ...) {
  lab <- if (is.character(label)) MathTex(label) else label
  eq <- MathTex("=")$next_to(lab, RIGHT)
  lab$add(eq)
  tracker <- ValueTracker(var)
  is_int <- identical(var_type, "integer") ||
    (!is.character(var_type) && identical(as_generator(var_type, "var_type"), IntegerClass))
  value <- if (is_int) Integer(tracker$get_value()) else DecimalNumber(tracker$get_value(), num_decimal_places = num_decimal_places)
  value$add_updater(function(v) v$set_value(tracker$get_value()))
  value$next_to(lab, RIGHT)
  v <- VMobject(...)
  class(v) <- c("Variable", class(v))
  v$label <- lab
  v$tracker <- tracker
  v$value <- value
  v$add(lab, value)
  v
}

BRACE_PATH_TEMPLATE <- paste0(
  "m0.01216 0c-0.01152 0-0.01216 6.103e-4 -0.01216 0.01311v0.007762c0.06776 ",
  "0.122 0.1799 0.1455 0.2307 0.1455h{0}c0.03046 3.899e-4 0.07964 0.00449 ",
  "0.1246 0.02636 0.0537 0.02695 0.07418 0.05816 0.08648 0.07769 0.001562 ",
  "0.002538 0.004539 0.002563 0.01098 0.002563 0.006444-2e-8 0.009421-2.47e-",
  "5 0.01098-0.002563 0.0123-0.01953 0.03278-0.05074 0.08648-0.07769 0.04491",
  "-0.02187 0.09409-0.02597 0.1246-0.02636h{0}c0.05077 0 0.1629-0.02346 ",
  "0.2307-0.1455v-0.007762c-1.78e-6 -0.0125-6.365e-4 -0.01311-0.01216-0.0131",
  "1-0.006444-3.919e-8 -0.009348 2.448e-5 -0.01091 0.002563-0.0123 0.01953-",
  "0.03278 0.05074-0.08648 0.07769-0.04491 0.02187-0.09416 0.02597-0.1246 ",
  "0.02636h{1}c-0.04786 0-0.1502 0.02094-0.2185 0.1256-0.06833-0.1046-0.1706",
  "-0.1256-0.2185-0.1256h{1}c-0.03046-3.899e-4 -0.07972-0.004491-0.1246-0.02",
  "636-0.0537-0.02695-0.07418-0.05816-0.08648-0.07769-0.001562-0.002538-",
  "0.004467-0.002563-0.01091-0.002563z"
)

#' @title Brace
#' @description A curly brace spanning a mobject on the side given by
#'   `direction`. `BraceLabel()` adds a label at its tip, `BraceText()` uses
#'   [Text()] for the label, `BraceBetweenPoints()` spans two points and
#'   `ArcBrace()` follows an arc.
#' @param mobject,obj The mobject to brace.
#' @param direction Side of the mobject.
#' @param buff Gap between mobject and brace.
#' @param sharpness Sharpness of the brace tip.
#' @param stroke_width,fill_opacity,background_stroke_width,background_stroke_color Style.
#' @param ... Passed to [VMobject()] (for `BraceLabel()`, to the label constructor).
#' @export
#' @examples
#' sq <- Square()
#' b <- Brace(sq, DOWN)
BraceClass <- R6::R6Class("Brace", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    buff = 0.2,
    tip_point_index = 1,
    initialize = function(mobject, direction = DOWN, buff = 0.2, sharpness = 2, stroke_width = 0, fill_opacity = 1,
                          background_stroke_width = 0, background_stroke_color = "#000000", ...) {
      default_min_width <- 0.90552
      self$buff <- buff
      direction <- as_point(direction)
      angle <- -atan2(direction[1], direction[2]) + pi
      mobject$rotate(-angle, about_point = ORIGIN)
      left <- mobject$get_corner(DOWN + LEFT)
      right <- mobject$get_corner(DOWN + RIGHT)
      target_width <- right[1] - left[1]
      lin <- max(0, (target_width * sharpness - default_min_width) / 2)
      d <- gsub("{0}", format(lin, scientific = FALSE, digits = 15), BRACE_PATH_TEMPLATE, fixed = TRUE)
      d <- gsub("{1}", format(-lin, scientific = FALSE, digits = 15), d, fixed = TRUE)
      super$initialize(stroke_width = stroke_width, fill_opacity = fill_opacity,
                       background_stroke_width = background_stroke_width,
                       background_stroke_color = background_stroke_color, ...)
      self$points <- svg_path_to_points(d)
      self$flip(RIGHT)
      bottom <- self$get_bottom()
      dist <- sqrt(rowSums((self$points - rep(bottom, each = nrow(self$points)))^2))
      self$tip_point_index <- which.min(dist)
      self$stretch_to_fit_width(target_width)
      self$shift(left - self$get_corner(UP + LEFT) + self$buff * DOWN)
      mobject$rotate(angle, about_point = ORIGIN)
      self$rotate(angle, about_point = ORIGIN)
    },
    put_at_tip = function(mob, use_next_to = TRUE, ...) {
      if (use_next_to) {
        mob$next_to(self$get_tip(), round(self$get_direction()), ...)
      } else {
        mob$move_to(self$get_tip())
        buff <- list(...)$buff %||% DEFAULT_MOBJECT_TO_MOBJECT_BUFFER
        mob$shift(self$get_direction() * (mob$width / 2 + buff))
      }
      invisible(self)
    },
    get_text = function(...) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      t <- do.call(Tex, args[nm == ""])
      do.call(self$put_at_tip, c(list(t), args[nm != ""]))
      t
    },
    get_tex = function(...) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      t <- do.call(MathTex, args[nm == ""])
      do.call(self$put_at_tip, c(list(t), args[nm != ""]))
      t
    },
    get_tip = function() self$points[self$tip_point_index, ],
    get_direction = function() {
      v <- self$get_tip() - self$get_center()
      v / get_norm(v)
    }
  )
)

#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @rdname BraceClass
#' @export
Brace <- constructor(BraceClass)
#' @rdname BraceClass
#' @param text Label text (a string or a vector of strings).
#' @param brace_direction Side of the mobject.
#' @param label_constructor Label constructor, [MathTex()] by default.
#' @param font_size Label font size.
#' @param brace_config List of extra [Brace()] arguments.
#' @export
BraceLabel <- function(obj, text, brace_direction = DOWN, label_constructor = MathTex, font_size = DEFAULT_FONT_SIZE,
                       buff = 0.2, brace_config = NULL, ...) {
  BraceLabelClass$new(obj, text, brace_direction = brace_direction, label_constructor = label_constructor,
                      font_size = font_size, buff = buff, brace_config = brace_config, ...)
}

#' @rdname BraceClass
#' @format NULL
#' @usage NULL
#' @export
BraceLabelClass <- R6::R6Class("BraceLabel", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    label_constructor = NULL,
    brace_direction = NULL,
    brace = NULL,
    label = NULL,
    initialize = function(obj, text, brace_direction = DOWN, label_constructor = MathTex, font_size = DEFAULT_FONT_SIZE,
                          buff = 0.2, brace_config = NULL, ...) {
      self$label_constructor <- label_constructor
      super$initialize()
      self$brace_direction <- brace_direction
      self$brace <- do.call(Brace, c(list(obj, brace_direction, buff), brace_config %||% list()))
      self$label <- if (length(text) > 1) do.call(label_constructor, c(as.list(text), list(font_size = font_size), list(...)))
        else label_constructor(as.character(text), font_size = font_size)
      self$brace$put_at_tip(self$label)
      self$add(self$brace, self$label)
    },
    creation_anim = function(label_anim = FadeIn, brace_anim = GrowFromCenter) {
      AnimationGroup(brace_anim(self$brace), label_anim(self$label))
    },
    shift_brace = function(obj, ...) {
      if (is.list(obj) && !is_mobject(obj)) obj <- do.call(VGroup, obj)
      self$brace <- Brace(obj, self$brace_direction, ...)
      self$brace$put_at_tip(self$label)
      invisible(self)
    },
    change_label = function(...) {
      self$remove(self$label)
      self$label <- self$label_constructor(...)
      self$brace$put_at_tip(self$label)
      self$add(self$label)
      invisible(self)
    },
    change_brace_label = function(obj, ...) {
      self$shift_brace(obj)
      self$change_label(...)
    }
  )
)

#' @rdname BraceClass
#' @export
BraceText <- function(obj, text, label_constructor = Text, ...) BraceLabel(obj, text, label_constructor = label_constructor, ...)

#' @rdname BraceClass
#' @param point_1,point_2 End points.
#' @export
BraceBetweenPoints <- function(point_1, point_2, direction = ORIGIN, ...) {
  point_1 <- as_point(point_1)
  point_2 <- as_point(point_2)
  direction <- as_point(direction)
  if (all(direction == 0)) {
    lv <- point_2 - point_1
    direction <- c(lv[2], -lv[1], 0)
  }
  b <- BraceClass$new(Line(point_1, point_2), direction = direction, ...)
  class(b) <- c("BraceBetweenPoints", class(b))
  b
}

#' @rdname BraceClass
#' @param arc An [Arc()].
#' @export
ArcBrace <- function(arc = NULL, direction = RIGHT, ...) {
  if (is.null(arc)) arc <- Arc(start_angle = -1, angle = 2, radius = 1)
  end_angle <- arc$start_angle + arc$angle
  line <- Line(UP * arc$start_angle, UP * end_angle)
  scale_shift <- RIGHT * log(arc$radius)
  if (arc$radius >= 1) {
    line$scale(arc$radius, about_point = ORIGIN)
    b <- BraceClass$new(line, direction = direction, ...)
    b$scale(1 / arc$radius, about_point = ORIGIN)
  } else {
    b <- BraceClass$new(line, direction = direction, ...)
  }
  if (arc$radius >= 0.3) b$shift(scale_shift) else b$shift(RIGHT * log(0.3))
  b$apply_complex_function(exp)
  b$shift(arc$get_arc_center())
  class(b) <- c("ArcBrace", class(b))
  b
}
