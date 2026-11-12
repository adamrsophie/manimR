# Creation animations. Ported from manim/animation/creation.py.

#' Creation animations
#'
#' Animations that draw, write, or reveal mobjects.
#'
#' @param mobject,vmobject,text,group The mobject to animate.
#' @param lag_ratio Stagger between submobjects; for `Write()` and
#'   `Unwrite()` the default depends on the number of submobjects.
#' @param introducer Add the mobject to the scene at the start.
#' @param ... Passed to [Animation()].
#' @name creation
NULL

#' @rdname creation
#' @format NULL
#' @usage NULL
#' @export
ShowPartialClass <- R6::R6Class("ShowPartial", inherit = AnimationClass, lock_objects = FALSE,
  public = list(
    initialize = function(mobject, ...) {
      if (!is.function(mobject$pointwise_become_partial)) stop(class(self)[1], " only works for VMobjects.", call. = FALSE)
      super$initialize(mobject, ...)
    },
    interpolate_submobject = function(submobject, starting_submobject, alpha) {
      b <- self$get_bounds(alpha)
      submobject$pointwise_become_partial(starting_submobject, b[1], b[2])
    },
    get_bounds = function(alpha) stop("Please use Create or ShowPassingFlash", call. = FALSE)
  )
)

#' @rdname creation
#' @format NULL
#' @usage NULL
#' @export
CreateClass <- R6::R6Class("Create", inherit = ShowPartialClass, lock_objects = FALSE,
  public = list(
    initialize = function(mobject, lag_ratio = 1, introducer = TRUE, ...) {
      super$initialize(mobject, lag_ratio = lag_ratio, introducer = introducer, ...)
    },
    get_bounds = function(alpha) c(0, alpha)
  )
)

#' @rdname creation
#' @export
Create <- function(mobject, ...) {
  ov <- animation_override("Create", mobject, match.call(), parent.frame())
  if (!is.null(ov)) return(ov$value)
  # Upstream override_animation: a mobject may define how it is created.
  if (is.function(mobject$create_override)) return(mobject$create_override(...))
  CreateClass$new(mobject, ...)
}

#' @rdname creation
#' @param reverse_rate_function Run backwards.
#' @param remover Remove the mobject when done.
#' @export
Uncreate <- function(mobject, reverse_rate_function = TRUE, remover = TRUE, ...) {
  ov <- animation_override("Uncreate", mobject, match.call(), parent.frame())
  if (!is.null(ov)) return(ov$value)
  a <- CreateClass$new(mobject, reverse_rate_function = reverse_rate_function, introducer = FALSE,
                       remover = remover, ...)
  class(a) <- c("Uncreate", class(a))
  a
}

#' @rdname creation
#' @format NULL
#' @usage NULL
#' @export
DrawBorderThenFillClass <- R6::R6Class("DrawBorderThenFill", inherit = AnimationClass, lock_objects = FALSE,
  public = list(
    stroke_width = 2,
    stroke_color = NULL,
    outline = NULL,
    initialize = function(vmobject, run_time = 2, rate_func = double_smooth, stroke_width = 2,
                          stroke_color = NULL, introducer = TRUE, ...) {
      if (!is_vmobject(vmobject)) stop(class(self)[1], " only works for vectorized Mobjects", call. = FALSE)
      super$initialize(vmobject, run_time = run_time, introducer = introducer, rate_func = rate_func, ...)
      self$stroke_width <- stroke_width
      self$stroke_color <- stroke_color
      self$outline <- self$get_outline()
    },
    begin = function() {
      self$outline <- self$get_outline()
      super$begin()
    },
    get_outline = function() {
      outline <- self$mobject$copy()
      outline$set_fill(opacity = 0)
      for (sm in outline$family_members_with_points()) {
        sm$set_stroke(color = self$get_stroke_color(sm), width = self$stroke_width)
      }
      outline
    },
    get_stroke_color = function(vmobject) {
      if (!is.null(self$stroke_color)) return(self$stroke_color)
      if (vmobject$get_stroke_width() > 0) return(vmobject$get_stroke_color())
      vmobject$get_color()
    },
    get_all_mobjects = function() c(super$get_all_mobjects(), list(self$outline)),
    interpolate_submobject = function(submobject, starting_submobject, outline, alpha) {
      ii <- integer_interpolate(0, 2, alpha)
      if (ii$index == 0) {
        submobject$pointwise_become_partial(outline, 0, ii$residue)
        submobject$match_style(outline)
      } else {
        submobject$interpolate(outline, starting_submobject, ii$residue)
      }
    }
  )
)

#' @rdname creation
#' @param stroke_width,stroke_color Width and color of the outline drawn
#'   before filling; a `NULL` color uses each submobject's own color.
#' @export
DrawBorderThenFill <- constructor(DrawBorderThenFillClass)
write_defaults <- function(vmobject, run_time, lag_ratio) {
  n <- length(vmobject$family_members_with_points())
  list(run_time = run_time %||% (if (n < 15) 1 else 2),
       lag_ratio = lag_ratio %||% min(4 / max(1, n), 0.2))
}

#' @rdname creation
#' @format NULL
#' @usage NULL
#' @export
WriteClass <- R6::R6Class("Write", inherit = DrawBorderThenFillClass, lock_objects = FALSE,
  public = list(
    reverse = FALSE,
    initialize = function(vmobject, rate_func = linear, reverse = FALSE, run_time = NULL, lag_ratio = NULL,
                          remover = NULL, ...) {
      d <- write_defaults(vmobject, run_time, lag_ratio)
      self$reverse <- reverse
      super$initialize(vmobject, rate_func = rate_func, run_time = d$run_time, lag_ratio = d$lag_ratio,
                       introducer = !reverse, remover = remover %||% reverse, ...)
    },
    reverse_submobjects = function() self$mobject$invert(recursive = TRUE),
    begin = function() {
      if (self$reverse) self$reverse_submobjects()
      super$begin()
    },
    finish = function() {
      super$finish()
      if (self$reverse) self$reverse_submobjects()
    }
  )
)

#' @rdname creation
#' @param rate_func Rate function.
#' @param reverse Write in reverse order.
#' @param run_time Duration in seconds; for `Write()` and `Unwrite()` the
#'   default depends on the number of submobjects.
#' @export
Write <- constructor(WriteClass)
#' @rdname creation
#' @export
Unwrite <- function(vmobject, rate_func = linear, reverse = TRUE, run_time = NULL, lag_ratio = NULL, ...) {
  ov <- animation_override("Unwrite", vmobject, match.call(), parent.frame(), "vmobject")
  if (!is.null(ov)) return(ov$value)
  d <- write_defaults(vmobject, run_time, lag_ratio)
  a <- WriteClass$new(vmobject, rate_func = rate_func, run_time = d$run_time, lag_ratio = d$lag_ratio,
                      reverse_rate_function = TRUE, reverse = reverse, ...)
  class(a) <- c("Unwrite", class(a))
  a
}

#' @rdname creation
#' @format NULL
#' @usage NULL
#' @export
SpiralInClass <- R6::R6Class("SpiralIn", inherit = AnimationClass, lock_objects = FALSE,
  public = list(
    shapes = NULL,
    scale_factor = 8,
    shape_center = NULL,
    fade_in_fraction = 0.3,
    initialize = function(shapes, scale_factor = 8, fade_in_fraction = 0.3, ...) {
      self$shapes <- shapes$copy()
      self$scale_factor <- scale_factor
      self$shape_center <- shapes$get_center()
      self$fade_in_fraction <- fade_in_fraction
      for (s in shapes$submobjects) {
        s$final_position <- s$get_center()
        s$initial_position <- s$final_position + (s$final_position - self$shape_center) * scale_factor
        s$move_to(s$initial_position)
        s$save_state()
      }
      super$initialize(shapes, introducer = TRUE, ...)
    },
    interpolate_mobject = function(alpha) {
      alpha <- self$rate_func(alpha)
      orig <- self$shapes$submobjects
      cur <- self$mobject$submobjects
      for (i in seq_along(cur)) {
        s <- cur[[i]]
        s$restore()
        fo <- orig[[i]]$get_fill_opacity()
        so <- orig[[i]]$get_stroke_opacity()
        s$shift((s$final_position - s$initial_position) * alpha)
        s$rotate(TAU * alpha, about_point = self$shape_center)
        s$rotate(-TAU * alpha, about_point = s$get_center_of_mass())
        s$set_fill(opacity = min(fo, alpha * fo / self$fade_in_fraction))
        s$set_stroke(opacity = min(so, alpha * so / self$fade_in_fraction))
      }
    }
  )
)

#' @rdname creation
#' @param shapes A group of shapes.
#' @param scale_factor How far out the shapes start.
#' @param fade_in_fraction Fraction of the run time spent fading in.
#' @export
SpiralIn <- constructor(SpiralInClass)
#' @rdname creation
#' @format NULL
#' @usage NULL
#' @export
ShowIncreasingSubsetsClass <- R6::R6Class("ShowIncreasingSubsets", inherit = AnimationClass, lock_objects = FALSE,
  public = list(
    all_submobs = NULL,
    int_func = NULL,
    initialize = function(group, suspend_mobject_updating = FALSE, int_func = floor,
                          reverse_rate_function = FALSE, ...) {
      self$all_submobs <- group$submobjects
      self$int_func <- int_func
      for (m in self$all_submobs) m$set_opacity(0)
      super$initialize(group, suspend_mobject_updating = suspend_mobject_updating,
                       reverse_rate_function = reverse_rate_function, ...)
    },
    interpolate_mobject = function(alpha) {
      n <- length(self$all_submobs)
      value <- if (self$reverse_rate_function) 1 - self$rate_func(alpha) else self$rate_func(alpha)
      self$update_submobject_list(as.integer(self$int_func(value * n)))
    },
    update_submobject_list = function(index) {
      n <- length(self$all_submobs)
      for (i in seq_len(n)) self$all_submobs[[i]]$set_opacity(if (i <= index) 1 else 0)
    }
  )
)

#' @rdname creation
#' @param int_func Rounding function for the number of visible submobjects.
#' @param suspend_mobject_updating Pause updaters while running.
#' @export
ShowIncreasingSubsets <- constructor(ShowIncreasingSubsetsClass)
#' @rdname creation
#' @format NULL
#' @usage NULL
#' @export
AddTextLetterByLetterClass <- R6::R6Class("AddTextLetterByLetter", inherit = ShowIncreasingSubsetsClass, lock_objects = FALSE,
  public = list(
    time_per_char = 0.1,
    initialize = function(text, suspend_mobject_updating = FALSE, int_func = ceiling, rate_func = linear,
                          time_per_char = 0.1, run_time = NULL, reverse_rate_function = FALSE,
                          introducer = TRUE, ...) {
      self$time_per_char <- time_per_char
      if (length(text$family_members_with_points()) == 0) {
        stop("The text mobject does not seem to contain any characters.", call. = FALSE)
      }
      if (is.null(run_time)) run_time <- max(1 / cfg("frame_rate"), time_per_char) * length(text$submobjects)
      super$initialize(text, suspend_mobject_updating = suspend_mobject_updating, int_func = int_func,
                       rate_func = rate_func, run_time = run_time, reverse_rate_function = reverse_rate_function,
                       introducer = introducer, ...)
    }
  )
)

#' @rdname creation
#' @param time_per_char Seconds per character.
#' @export
AddTextLetterByLetter <- constructor(AddTextLetterByLetterClass)
#' @rdname creation
#' @export
RemoveTextLetterByLetter <- function(text, reverse_rate_function = TRUE, introducer = FALSE, remover = TRUE, ...) {
  ov <- animation_override("RemoveTextLetterByLetter", text, match.call(), parent.frame(), "text")
  if (!is.null(ov)) return(ov$value)
  AddTextLetterByLetterClass$new(text, reverse_rate_function = reverse_rate_function, introducer = introducer,
                                 remover = remover, ...)
}

#' @rdname creation
#' @format NULL
#' @usage NULL
#' @export
ShowSubmobjectsOneByOneClass <- R6::R6Class("ShowSubmobjectsOneByOne", inherit = ShowIncreasingSubsetsClass, lock_objects = FALSE,
  public = list(
    initialize = function(group, int_func = ceiling, ...) {
      mobs <- if (is_mobject(group)) group$submobjects else group
      super$initialize(do.call(Group, mobs), int_func = int_func, ...)
    },
    update_submobject_list = function(index) {
      n <- length(self$all_submobs)
      for (i in seq_len(n)) self$all_submobs[[i]]$set_opacity(if (i == index) 1 else 0)
    }
  )
)

#' @rdname creation
#' @export
ShowSubmobjectsOneByOne <- constructor(ShowSubmobjectsOneByOneClass)
#' @rdname creation
#' @param text_mobject A text mobject whose submobjects are words.
#' @export
AddTextWordByWord <- function(text_mobject, run_time = NULL, time_per_char = 0.06, ...) {
  ov <- animation_override("AddTextWordByWord", text_mobject, match.call(), parent.frame(), "text_mobject")
  if (!is.null(ov)) return(ov$value)
  anims <- list()
  for (word in text_mobject$submobjects) {
    n <- max(1, length(word$submobjects))
    anims <- c(anims, list(ShowIncreasingSubsets(word, run_time = time_per_char * n),
                           Animation(word, run_time = 0.005 * n^1.5)))
  }
  do.call(Succession, c(anims, list(...)))
}

#' @rdname creation
#' @format NULL
#' @usage NULL
#' @export
TypeWithCursorClass <- R6::R6Class("TypeWithCursor", inherit = AddTextLetterByLetterClass, lock_objects = FALSE,
  public = list(
    cursor = NULL,
    buff = 0.1,
    keep_cursor_y = TRUE,
    leave_cursor_on = TRUE,
    y_cursor = NULL,
    initialize = function(text, cursor, buff = 0.1, keep_cursor_y = TRUE, leave_cursor_on = TRUE,
                          time_per_char = 0.1, reverse_rate_function = FALSE, introducer = TRUE, ...) {
      self$cursor <- cursor
      self$buff <- buff
      self$keep_cursor_y <- keep_cursor_y
      self$leave_cursor_on <- leave_cursor_on
      super$initialize(text, time_per_char = time_per_char, reverse_rate_function = reverse_rate_function,
                       introducer = introducer, ...)
    },
    begin = function() {
      self$y_cursor <- self$cursor$get_y()
      self$cursor$initial_position <- self$mobject$get_center()
      if (self$keep_cursor_y) self$cursor$set_y(self$y_cursor)
      self$cursor$set_opacity(0)
      self$mobject$add(self$cursor)
      super$begin()
    },
    finish = function() {
      if (self$leave_cursor_on) {
        self$cursor$set_opacity(1)
      } else {
        self$cursor$set_opacity(0)
        self$mobject$remove(self$cursor)
      }
      super$finish()
    },
    clean_up_from_scene = function(scene) {
      if (!self$leave_cursor_on) scene$remove(self$cursor)
      super$clean_up_from_scene(scene)
    },
    update_submobject_list = function(index) {
      n <- length(self$all_submobs)
      for (i in seq_len(n)) self$all_submobs[[i]]$set_opacity(if (i <= index) 1 else 0)
      if (index != 0) {
        self$cursor$next_to(self$all_submobs[[index]], RIGHT, buff = self$buff)$set_y(self$cursor$initial_position[2])
      } else {
        self$cursor$move_to(self$all_submobs[[1]])$set_y(self$cursor$initial_position[2])
      }
      if (self$keep_cursor_y) self$cursor$set_y(self$y_cursor)
      self$cursor$set_opacity(1)
    }
  )
)

#' @rdname creation
#' @param cursor A mobject used as the cursor.
#' @param buff Gap between text and cursor.
#' @param keep_cursor_y Keep the cursor's y coordinate.
#' @param leave_cursor_on Keep the cursor visible at the end.
#' @export
TypeWithCursor <- constructor(TypeWithCursorClass)
#' @rdname creation
#' @export
UntypeWithCursor <- function(text, cursor = NULL, time_per_char = 0.1, reverse_rate_function = TRUE,
                             introducer = FALSE, remover = TRUE, ...) {
  ov <- animation_override("UntypeWithCursor", text, match.call(), parent.frame(), "text")
  if (!is.null(ov)) return(ov$value)
  TypeWithCursorClass$new(text, cursor = cursor, time_per_char = time_per_char,
                          reverse_rate_function = reverse_rate_function, introducer = introducer,
                          remover = remover, ...)
}
