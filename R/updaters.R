# Value trackers and updater helpers. Ported from manim/mobject/value_tracker.py,
# manim/animation/updaters/mobject_update_utils.py, manim/animation/numbers.py
# and manim/animation/specialized.py.

#' Value trackers
#'
#' A `ValueTracker` stores a number that can be animated, for example with
#' `tracker$animate$set_value(5)`, and read in updaters with `get_value()`.
#' `ComplexValueTracker` stores a complex number.
#'
#' @param value Initial value.
#' @param ... Passed to the Mobject initializer.
#' @export
#' @examples
#' t <- ValueTracker(1)
#' t$increment_value(2)
#' t$get_value()
ValueTrackerClass <- R6::R6Class("ValueTracker", inherit = MobjectClass, lock_objects = FALSE,
  public = list(
    initialize = function(value = 0, ...) {
      super$initialize(...)
      self$points <- matrix(0, 1, 3)
      self$set_value(value)
    },
    get_value = function() self$points[1, 1],
    set_value = function(value) {
      self$points[1, 1] <- value
      invisible(self)
    },
    increment_value = function(d_value) self$set_value(self$get_value() + d_value),
    interpolate = function(mobject1, mobject2, alpha, path_func = straight_path()) {
      self$points <- path_func(mobject1$points, mobject2$points, alpha)
      invisible(self)
    },
    get_point_mobject = function(center = NULL) PointClass$new(location = center %||% self$get_center())
  )
)

#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @rdname ValueTrackerClass
#' @export
ValueTracker <- constructor(ValueTrackerClass)
#' @rdname ValueTrackerClass
#' @format NULL
#' @usage NULL
#' @export
ComplexValueTrackerClass <- R6::R6Class("ComplexValueTracker", inherit = ValueTrackerClass, lock_objects = FALSE,
  public = list(
    get_value = function() complex(real = self$points[1, 1], imaginary = self$points[1, 2]),
    set_value = function(value) {
      z <- as.complex(value)
      self$points[1, 1:2] <- c(Re(z), Im(z))
      invisible(self)
    }
  )
)

#' @rdname ValueTrackerClass
#' @export
ComplexValueTracker <- constructor(ComplexValueTrackerClass)
#' @export
Ops.ValueTracker <- function(e1, e2) {
  if (missing(e2)) {
    res <- get(.Generic)(e1$get_value())
    return(if (.Generic %in% c("+", "-")) ValueTracker(res) else res)
  }
  v1 <- if (inherits(e1, "ValueTracker")) e1$get_value() else e1
  v2 <- if (inherits(e2, "ValueTracker")) e2$get_value() else e2
  if (is_mobject(v1) || is_mobject(v2)) stop("Cannot combine a ValueTracker with a Mobject.", call. = FALSE)
  res <- get(.Generic)(v1, v2)
  if (.Generic %in% c("+", "-", "*", "/", "^", "%%", "%/%")) ValueTracker(res) else res
}

#' Updater helpers
#'
#' * `always_redraw(func)` returns `func()` and rebuilds it every frame.
#' * `always(mob$method, ...)` calls the method with fixed arguments every frame.
#' * `f_always(mob$method, ...)` calls it with arguments produced by the given functions.
#' * `always_shift()` and `always_rotate()` move a mobject at a constant rate.
#' * `turn_animation_into_updater()` and `cycle_animation()` run an animation as an updater.
#'
#' @param func Function with no arguments returning a mobject.
#' @param method A mobject method such as `dot$move_to`.
#' @param ... Arguments (or argument generators for `f_always()`).
#' @param mobject A mobject.
#' @param direction Direction of motion.
#' @param rate Speed in units (or radians) per second.
#' @param animation An animation.
#' @param cycle Restart the animation when it ends.
#' @param delay Seconds to wait before starting.
#' @return The mobject.
#' @name updater_helpers
NULL

#' @rdname updater_helpers
#' @export
always_redraw <- function(func) {
  mob <- func()
  mob$add_updater(function(m) m$become(func()))
  mob
}

method_owner <- function(method) {
  mob <- environment(method)$self
  if (!is_mobject(mob)) stop("Expected a mobject method such as mob$shift", call. = FALSE)
  list(mobject = mob, name = find_method_name(mob, method))
}

#' @rdname updater_helpers
#' @export
always <- function(method, ...) {
  o <- method_owner(method)
  args <- list(...)
  o$mobject$add_updater(function(m) do.call(m[[o$name]], args))
  o$mobject
}

#' @rdname updater_helpers
#' @export
f_always <- function(method, ...) {
  o <- method_owner(method)
  gens <- list(...)
  nm <- names(gens) %||% rep("", length(gens))
  o$mobject$add_updater(function(m) {
    args <- lapply(gens[nm == ""], function(g) g())
    do.call(m[[o$name]], c(args, gens[nm != ""]))
  })
  o$mobject
}

#' @rdname updater_helpers
#' @export
always_shift <- function(mobject, direction = RIGHT, rate = 0.1) {
  d <- normalize(direction)
  mobject$add_updater(function(m, dt) m$shift(dt * rate * d))
  mobject
}

#' @rdname updater_helpers
#' @export
always_rotate <- function(mobject, rate = 20 * DEGREES, ...) {
  kw <- list(...)
  mobject$add_updater(function(m, dt) do.call(m$rotate, c(list(dt * rate), kw)))
  mobject
}

#' @rdname updater_helpers
#' @export
turn_animation_into_updater <- function(animation, cycle = FALSE, delay = 0, ...) {
  mobject <- animation$mobject
  animation$suspend_mobject_updating <- FALSE
  animation$begin()
  animation$total_time <- -delay
  update <- function(m, dt) {
    if (animation$total_time >= 0) {
      rt <- animation$get_run_time()
      if (rt <= 0) {
        animation$interpolate(1)
        animation$update_mobjects(dt)
        animation$finish()
        m$remove_updater(update)
        return(invisible(NULL))
      }
      ratio <- animation$total_time / rt
      if (cycle) {
        alpha <- ratio %% 1
      } else {
        alpha <- min(max(ratio, 0), 1)
        if (alpha >= 1) {
          animation$finish()
          m$remove_updater(update)
          return(invisible(NULL))
        }
      }
      animation$interpolate(alpha)
      animation$update_mobjects(dt)
    }
    animation$total_time <- animation$total_time + dt
  }
  mobject$add_updater(update)
  mobject
}

#' @rdname updater_helpers
#' @export
cycle_animation <- function(animation, ...) turn_animation_into_updater(animation, cycle = TRUE, ...)

#' Number animations
#'
#' `ChangingDecimal()` sets a [DecimalNumber()] to `number_update_func(alpha)`;
#' `ChangeDecimalToValue()` counts it to a target.
#'
#' @param decimal_mob A [DecimalNumber()].
#' @param number_update_func Function of alpha.
#' @param target_number Final number.
#' @param suspend_mobject_updating Pause other updaters.
#' @param ... Passed to [Animation()].
#' @return An animation: an R6 object of the class named by the function
#'   called, to pass to a scene's `play()`. The objects whose names end in
#'   `Class` are the R6 class generators that these functions call.
#' @name number_animations
NULL

#' @rdname number_animations
#' @format NULL
#' @usage NULL
#' @export
ChangingDecimalClass <- R6::R6Class("ChangingDecimal", inherit = AnimationClass, lock_objects = FALSE,
  public = list(
    number_update_func = NULL,
    initialize = function(decimal_mob, number_update_func, suspend_mobject_updating = FALSE, ...) {
      self$check_validity_of_input(decimal_mob)
      self$number_update_func <- number_update_func
      super$initialize(decimal_mob, suspend_mobject_updating = suspend_mobject_updating, ...)
    },
    interpolate_mobject = function(alpha) self$mobject$set_value(self$number_update_func(self$rate_func(alpha))),
    check_validity_of_input = function(decimal_mob) {
      if (!inherits(decimal_mob, "DecimalNumber")) stop("ChangingDecimal can only take in a DecimalNumber", call. = FALSE)
      invisible(TRUE)
    }
  )
)

#' @rdname number_animations
#' @export
ChangingDecimal <- constructor(ChangingDecimalClass)
#' @rdname number_animations
#' @export
ChangeDecimalToValue <- function(decimal_mob, target_number, ...) {
  start <- decimal_mob$number
  ChangingDecimalClass$new(decimal_mob, function(a) interpolate(start, target_number, a), ...)
}

#' Broadcast
#'
#' Emits expanding copies of a mobject from a focal point.
#'
#' @param mobject Mobject to broadcast.
#' @param focal_point Point the copies emanate from.
#' @param n_mobs Number of copies.
#' @param initial_opacity,final_opacity Opacities.
#' @param initial_width Starting width.
#' @param remover Remove the copies when done.
#' @param lag_ratio Lag between copies.
#' @param run_time Duration.
#' @param ... Passed to [LaggedStart()].
#' @return A `Broadcast` animation, an R6 object to pass to a scene's `play()`.
#' @export
Broadcast <- function(mobject, focal_point = ORIGIN, n_mobs = 5, initial_opacity = 1, final_opacity = 0,
                      initial_width = 0, remover = TRUE, lag_ratio = 0.2, run_time = 3, ...) {
  fill_o <- isTRUE(mobject$fill_opacity > 0)
  anims <- lapply(seq_len(n_mobs), function(i) {
    mob <- mobject$copy()
    if (fill_o) mob$set_opacity(final_opacity) else mob$set_stroke(opacity = final_opacity)
    mob$move_to(focal_point)
    mob$save_state()
    mob$width <- initial_width
    if (fill_o) mob$set_opacity(initial_opacity) else mob$set_stroke(opacity = initial_opacity)
    Restore(mob, remover = remover)
  })
  do.call(LaggedStart, c(anims, list(run_time = run_time, lag_ratio = lag_ratio, ...)))
}
