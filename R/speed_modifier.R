# Changing the speed of animations. Ported from manim/animation/speedmodifier.py.

# Shared state replacing the class attributes ChangeSpeed.dt and
# ChangeSpeed.is_changing_dt of upstream.
change_speed_state <- new.env(parent = emptyenv())
change_speed_state$dt <- 0
change_speed_state$is_changing_dt <- FALSE

# Upstream patches Wait.interpolate so that the (speed changing) rate function
# is still evaluated every frame. R6 methods cannot be patched on instances,
# so a Wait subclass does it.
ChangeSpeedWaitClass <- R6::R6Class("ChangeSpeedWait", inherit = WaitClass, lock_objects = FALSE,
  public = list(
    interpolate = function(alpha) self$rate_func(alpha)
  )
)

change_speed_setup <- function(anim) {
  anim <- prepare_animation(anim)
  if (identical(class(anim)[1], "Wait")) {
    anim <- ChangeSpeedWaitClass$new(run_time = anim$run_time, stop_condition = anim$stop_condition,
                                     frozen_frame = anim$is_static_wait, rate_func = anim$rate_func)
  }
  anim
}

#' @title ChangeSpeed
#' @description Modifies the speed of an animation. `speedinfo` maps nodes
#'   (proportions of the animation's `run_time`) to speed factors; between two
#'   nodes the speed changes smoothly. The run time of the wrapped animation
#'   is stretched accordingly. An [AnimationGroup()] with any `lag_ratio`
#'   counts as one animation.
#'
#'   Updaters added with [change_speed_add_updater()] follow the modified
#'   speed while a `ChangeSpeed` with `affects_speed_updaters = TRUE` plays.
#' @param anim The animation (or `mob$animate` builder) to modify.
#' @param speedinfo Named numeric vector or list: names are the nodes in
#'   `[0, 1]`, values the speed factors, for example
#'   `c("0.3" = 1, "0.4" = 0.1, "0.6" = 0.1, "1" = 1)`. A missing node 0 gets
#'   speed 1 and a missing node 1 gets the speed of the last node.
#' @param rate_func Overrides the rate function of `anim`; it is applied
#'   before changing the speed.
#' @param affects_speed_updaters Whether updaters added with
#'   [change_speed_add_updater()] follow the speed change. Only one such
#'   animation can play at a time.
#' @param ... Passed to [Animation()].
#' @export
#' @examples
#' \dontrun{
#' SpeedModifierExample <- manim_scene(function(self) {
#'   a <- Dot()$shift(LEFT * 4)
#'   b <- Dot()$shift(RIGHT * 4)
#'   self$add(a, b)
#'   self$play(ChangeSpeed(
#'     AnimationGroup(a$animate(run_time = 1)$shift(RIGHT * 8),
#'                    b$animate(run_time = 1)$shift(LEFT * 8)),
#'     speedinfo = c("0.3" = 1, "0.4" = 0.1, "0.6" = 0.1, "1" = 1),
#'     rate_func = linear))
#' })
#' }
ChangeSpeedClass <- R6::R6Class("ChangeSpeed", inherit = AnimationClass, lock_objects = FALSE,
  public = list(
    anim = NULL,
    speedinfo = NULL,
    affects_speed_updaters = TRUE,
    t = 0,
    nodes = NULL,
    speeds = NULL,
    # Prepares an animation to be sped up, as upstream's ChangeSpeed.setup().
    setup = function(anim) change_speed_setup(anim),
    initialize = function(anim, speedinfo, rate_func = NULL, affects_speed_updaters = TRUE, ...) {
      anim <- prepare_animation(anim)
      if (inherits(anim, "AnimationGroup")) {
        anim$animations <- lapply(anim$animations, change_speed_setup)
      } else {
        anim <- change_speed_setup(anim)
      }
      self$anim <- anim
      if (affects_speed_updaters && isTRUE(change_speed_state$is_changing_dt)) {
        stop("Only one animation at a time can play that changes speed (dt) for ChangeSpeed updaters",
             call. = FALSE)
      }
      self$affects_speed_updaters <- affects_speed_updaters
      rate_func <- rate_func %||% anim$rate_func

      # Unlike upstream, everything is validated and computed before the
      # global lock is taken, so a failed construction does not leave it set.
      info <- unlist(speedinfo)
      nodes <- suppressWarnings(as.numeric(names(info)))
      speeds <- suppressWarnings(as.numeric(info))
      if (is.null(names(info)) || !length(info) || anyNA(nodes) || anyNA(speeds)) {
        stop("speedinfo must map numeric nodes to numeric speeds, for example c(\"0.5\" = 0.2, \"1\" = 1).",
             call. = FALSE)
      }
      if (!0 %in% nodes) {
        nodes <- c(nodes, 0)
        speeds <- c(speeds, 1)
      }
      if (!1 %in% nodes) {
        speeds <- c(speeds, speeds[which.max(nodes)])
        nodes <- c(nodes, 1)
      }
      o <- order(nodes)
      self$nodes <- nodes[o]
      self$speeds <- speeds[o]
      self$speedinfo <- stats::setNames(self$speeds, self$nodes)

      k <- length(self$nodes)
      seg_init <- self$speeds[-k]
      seg_final <- self$speeds[-1]
      seg_prev <- self$nodes[-k]
      seg_dur <- diff(self$nodes)
      # One running sum for the bounds and the total, so the last upper bound is exactly 1.
      ends <- cumsum(change_speed_f_inv_1(seg_init, seg_final) * seg_dur)
      total <- ends[k - 1]
      seg_start <- c(0, ends[-(k - 1)])
      lower <- seg_start / total
      upper <- ends / total

      func <- function(t) {
        if (t == 1) change_speed_state$is_changing_dt <- FALSE
        rt <- self$rate_func(t)
        # numpy.piecewise semantics: 0 where no condition holds, and the
        # last condition that holds wins.
        new_t <- 0
        for (i in seq_along(lower)) {
          if (lower[i] <= rt && rt <= upper[i]) {
            new_t <- change_speed_modifier((total * rt - seg_start[i]) / seg_dur[i], seg_init[i], seg_final[i]) *
              seg_dur[i] + seg_prev[i]
          }
        }
        if (self$affects_speed_updaters) {
          change_speed_state$dt <- (new_t - self$t) * self$anim$run_time
          self$t <- new_t
        }
        new_t
      }
      self$anim$set_rate_func(func)
      super$initialize(self$anim$mobject, rate_func = rate_func, run_time = total * self$anim$run_time, ...)
      if (affects_speed_updaters) {
        change_speed_state$is_changing_dt <- TRUE
        self$t <- 0
      }
    },
    # Time taken by the animation if its run_time is 1.
    get_scaled_total_time = function() {
      k <- length(self$nodes)
      utils::tail(cumsum(diff(self$nodes) * change_speed_f_inv_1(self$speeds[-k], self$speeds[-1])), 1)
    },
    interpolate = function(alpha) self$anim$interpolate(alpha),
    update_mobjects = function(dt) self$anim$update_mobjects(dt),
    finish = function() {
      change_speed_state$is_changing_dt <- FALSE
      self$anim$finish()
    },
    begin = function() self$anim$begin(),
    clean_up_from_scene = function(scene) self$anim$clean_up_from_scene(scene),
    setup_scene = function(scene) self$anim$setup_scene(scene)
  )
)

#' @rdname ChangeSpeedClass
#' @export
ChangeSpeed <- constructor(ChangeSpeedClass)
# A function with f(0) = 0, f'(0) = init_speed and f'(f^-1(1)) = final_speed,
# obtained by applying these conditions to a vertical parabola.
change_speed_modifier <- function(x, init_speed, final_speed) {
  (final_speed^2 - init_speed^2) * x^2 / 4 + init_speed * x
}

# The x for which change_speed_modifier(x) = 1.
change_speed_f_inv_1 <- function(init_speed, final_speed) 2 / (init_speed + final_speed)

#' Updaters that follow ChangeSpeed
#'
#' Adds an updater to `mobject` that follows the speed and rate function of
#' any [ChangeSpeed()] animation playing with `affects_speed_updaters = TRUE`.
#' Updaters added with the usual `mob$add_updater()` ignore speed changes.
#' This is the R form of upstream's `ChangeSpeed.add_updater()`.
#'
#' @param mobject The mobject to which the updater is attached.
#' @param update_function The updater, `function(m)` or `function(m, dt)`.
#' @param index Position in the mobject's updater list.
#' @param call_updater Call the updater once when attaching it.
#' @return The mobject, invisibly.
#' @export
#' @examples
#' \dontrun{
#' SpeedModifierUpdaterExample <- manim_scene(function(self) {
#'   a <- Dot()$shift(LEFT * 4)
#'   self$add(a)
#'   change_speed_add_updater(a, function(x, dt) x$shift(RIGHT * 4 * dt))
#'   self$play(ChangeSpeed(Wait(2), speedinfo = c("0.4" = 1, "0.5" = 0.2, "0.8" = 0.2, "1" = 1),
#'                         affects_speed_updaters = TRUE))
#' })
#' }
change_speed_add_updater <- function(mobject, update_function, index = NULL, call_updater = FALSE) {
  if (updater_takes_dt(update_function)) {
    mobject$add_updater(function(mob, dt) {
      update_function(mob, if (isTRUE(change_speed_state$is_changing_dt)) change_speed_state$dt else dt)
    }, index = index, call_updater = call_updater)
  } else {
    mobject$add_updater(update_function, index = index, call_updater = call_updater)
  }
  invisible(mobject)
}
