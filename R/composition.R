# Animation composition and indication animations.
# Ported from manim/animation/composition.py and manim/animation/indication.py.

DEFAULT_LAGGED_START_LAG_RATIO <- 0.05

#' Composing animations
#'
#' `AnimationGroup()` plays animations together, offset by `lag_ratio`
#' times each run time. `Succession()` plays them one after another.
#' `LaggedStart()` uses a small default lag. `LaggedStartMap()` applies an
#' animation constructor to every submobject.
#'
#' @param ... Animations (or lists of them), then named arguments.
#' @param group Mobject group used as the animation's mobject.
#' @param run_time Total run time; defaults to the length of the schedule.
#' @param rate_func Rate function applied to the whole group.
#' @param lag_ratio Offset between consecutive animations, as a fraction of their run time.
#' @param animation_class An animation constructor such as `FadeIn`.
#' @param mobject Mobject whose submobjects are animated.
#' @param arg_creator Function mapping a submobject to a list of arguments.
#' @return An animation: an R6 object of the class named by the function
#'   called, to pass to a scene's `play()`. The objects whose names end in
#'   `Class` are the R6 class generators that these functions call.
#' @name composition
NULL

#' @rdname composition
#' @format NULL
#' @usage NULL
#' @export
AnimationGroupClass <- R6::R6Class("AnimationGroup", inherit = AnimationClass, lock_objects = FALSE,
  public = list(
    animations = NULL,
    group = NULL,
    anim_starts = NULL,
    anim_ends = NULL,
    anims_begun = NULL,
    anims_finished = NULL,
    max_end_time = 0,
    anim_group_time = 0,
    initialize = function(..., group = NULL, run_time = NULL, rate_func = linear, lag_ratio = 0) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      self$animations <- lapply(flatten_animation_args(args[nm == ""]), prepare_animation)
      if (is.null(group)) {
        mobs <- lapply(Filter(function(a) !a$is_introducer(), self$animations), function(a) a$mobject)
        ids <- vapply(mobs, function(m) m$mob_id, "")
        mobs <- mobs[!duplicated(ids, fromLast = TRUE)]
        self$group <- do.call(Group, mobs)
      } else {
        self$group <- group
      }
      do.call(super$initialize, c(list(self$group, rate_func = rate_func, lag_ratio = lag_ratio), args[nm != ""]))
      self$run_time <- self$init_run_time(run_time)
    },
    get_all_mobjects = function() self$group$submobjects,
    begin = function() {
      if (length(self$animations) == 0) stop("Trying to play an AnimationGroup without animations.", call. = FALSE)
      self$anim_group_time <- 0
      if (self$suspend_mobject_updating) self$group$suspend_updating()
      for (a in self$animations) a$begin()
    },
    setup_scene = function(scene) {
      for (a in self$animations) a$setup_scene(scene)
    },
    finish = function() {
      for (a in self$animations) a$finish()
      self$anims_begun[] <- TRUE
      self$anims_finished[] <- TRUE
      if (self$suspend_mobject_updating) self$group$resume_updating()
    },
    clean_up_from_scene = function(scene) {
      if (!is.null(self$on_finish)) self$on_finish(scene)
      for (a in self$animations) {
        if (self$remover) a$remover <- self$remover
        a$clean_up_from_scene(scene)
      }
    },
    update_mobjects = function(dt) {
      for (i in which(self$anims_begun & !self$anims_finished)) self$animations[[i]]$update_mobjects(dt)
    },
    init_run_time = function(run_time) {
      self$build_animations_with_timings()
      self$max_end_time <- if (length(self$anim_ends)) max(self$anim_ends) else 0
      run_time %||% self$max_end_time
    },
    build_animations_with_timings = function() {
      rts <- vapply(self$animations, function(a) a$run_time, numeric(1))
      n <- length(rts)
      self$anims_begun <- rep(FALSE, n)
      self$anims_finished <- rep(FALSE, n)
      if (n == 0) {
        self$anim_starts <- numeric()
        self$anim_ends <- numeric()
        return(invisible(self))
      }
      lags <- rts[-n] * self$lag_ratio
      self$anim_starts <- c(0, cumsum(lags))
      self$anim_ends <- self$anim_starts + rts
      invisible(self)
    },
    interpolate = function(alpha) {
      t <- self$rate_func(alpha) * self$max_end_time
      goes_back <- t < self$anim_group_time
      new_begun <- t >= self$anim_starts
      new_finished <- t > self$anim_ends
      upd <- which((self$anims_begun | new_begun) & (!self$anims_finished | !new_finished))
      rts <- self$anim_ends[upd] - self$anim_starts[upd]
      zero <- rts == 0
      rts[zero] <- 1
      sub <- (t - self$anim_starts[upd]) / rts
      if (goes_back) sub[sub < 0 | zero] <- 0 else sub[sub > 1 | zero] <- 1
      for (k in seq_along(upd)) self$animations[[upd[k]]]$interpolate(sub[k])
      self$anim_group_time <- t
      self$anims_begun <- new_begun
      self$anims_finished <- new_finished
    }
  )
)

#' @rdname composition
#' @export
AnimationGroup <- constructor(AnimationGroupClass)
#' @rdname composition
#' @format NULL
#' @usage NULL
#' @export
SuccessionClass <- R6::R6Class("Succession", inherit = AnimationGroupClass, lock_objects = FALSE,
  public = list(
    active_index = 0,
    active_animation = NULL,
    active_start_time = NULL,
    active_end_time = NULL,
    scene = NULL,
    initialize = function(..., lag_ratio = 1) super$initialize(..., lag_ratio = lag_ratio),
    begin = function() {
      if (length(self$animations) == 0) stop("Trying to play a Succession without animations.", call. = FALSE)
      self$update_active_animation(1)
    },
    finish = function() {
      while (!is.null(self$active_animation)) self$next_animation()
    },
    update_mobjects = function(dt) {
      if (!is.null(self$active_animation)) self$active_animation$update_mobjects(dt)
    },
    setup_scene = function(scene) {
      if (is.null(scene)) return(invisible(NULL))
      if (self$is_introducer()) {
        for (a in self$animations) if (!a$is_introducer() && !is.null(a$mobject)) scene$add(a$mobject)
      }
      self$scene <- scene
    },
    update_active_animation = function(index) {
      self$active_index <- index
      if (index > length(self$animations)) {
        self$active_animation <- NULL
        self$active_start_time <- NULL
        self$active_end_time <- NULL
      } else {
        self$active_animation <- self$animations[[index]]
        self$active_animation$setup_scene(self$scene)
        self$active_animation$begin()
        self$active_start_time <- self$anim_starts[index]
        self$active_end_time <- self$anim_ends[index]
      }
    },
    next_animation = function() {
      if (!is.null(self$active_animation)) self$active_animation$finish()
      self$update_active_animation(self$active_index + 1)
    },
    interpolate = function(alpha) {
      t <- self$rate_func(alpha) * self$max_end_time
      while (!is.null(self$active_end_time) && t >= self$active_end_time) self$next_animation()
      if (!is.null(self$active_animation) && !is.null(self$active_start_time)) {
        rt <- self$active_animation$run_time
        self$active_animation$interpolate(if (rt != 0) (t - self$active_start_time) / rt else 1)
      }
    }
  )
)

#' @rdname composition
#' @export
Succession <- constructor(SuccessionClass)
#' @rdname composition
#' @export
LaggedStart <- function(..., lag_ratio = DEFAULT_LAGGED_START_LAG_RATIO) {
  a <- AnimationGroupClass$new(..., lag_ratio = lag_ratio)
  class(a) <- c("LaggedStart", class(a))
  a
}

#' @rdname composition
#' @export
LaggedStartMap <- function(animation_class, mobject, arg_creator = NULL, run_time = 2,
                           lag_ratio = DEFAULT_LAGGED_START_LAG_RATIO, ...) {
  if (is.null(arg_creator)) arg_creator <- function(m) list(m)
  kw <- list(...)
  anims <- lapply(mobject$submobjects, function(sm) do.call(animation_class, c(arg_creator(sm), kw)))
  a <- do.call(AnimationGroupClass$new, c(anims, list(run_time = run_time, lag_ratio = lag_ratio)))
  class(a) <- c("LaggedStartMap", "LaggedStart", class(a))
  a
}

#' Indication animations
#'
#' Animations that draw attention to a mobject or point.
#'
#' @param mobject,vmobject The mobject to indicate.
#' @param focus_point,point Point or mobject to focus or flash on.
#' @param opacity Opacity of the focusing spotlight.
#' @param color Color.
#' @param run_time Duration.
#' @param scale_factor Scale at the peak.
#' @param rate_func Rate function.
#' @param line_length,num_lines,flash_radius,line_stroke_width Flash geometry.
#' @param time_width Width of the traveling flash, as a fraction of the path.
#' @param n_segments Number of strokes for the thinning flash.
#' @param remover Remove when done.
#' @param direction,amplitude,wave_func,ripples Wave settings.
#' @param scale_value,rotation_angle,n_wiggles,scale_about_point,rotate_about_point Wiggle settings.
#' @param shape `"rectangle"` or `"circle"` for `Circumscribe()`.
#' @param fade_in,fade_out Fade the frame in or out.
#' @param buff Buffer around the mobject.
#' @param stroke_width Stroke width.
#' @param time_on,time_off,blinks,hide_at_end Blink settings.
#' @param ... Passed on to the underlying animation.
#' @return An animation: an R6 object of the class named by the function
#'   called, to pass to a scene's `play()`. The objects whose names end in
#'   `Class` are the R6 class generators that these functions call.
#' @name indication
NULL

#' @rdname indication
#' @format NULL
#' @usage NULL
#' @export
FocusOnClass <- R6::R6Class("FocusOn", inherit = TransformClass, lock_objects = FALSE,
  public = list(
    focus_point = NULL,
    color = NULL,
    opacity = 0.2,
    initialize = function(focus_point, opacity = 0.2, color = GREY, run_time = 2, ...) {
      self$focus_point <- focus_point
      self$color <- color
      self$opacity <- opacity
      starting_dot <- Dot(radius = frame_x_radius() + frame_y_radius(), stroke_width = 0,
                          fill_color = color, fill_opacity = 0)
      super$initialize(starting_dot, run_time = run_time, remover = TRUE, ...)
    },
    create_target = function() {
      little <- Dot(radius = 0)
      little$set_fill(self$color, opacity = self$opacity)
      fp <- self$focus_point
      little$add_updater(function(d) d$move_to(fp))
      little
    }
  )
)

#' @rdname indication
#' @export
FocusOn <- constructor(FocusOnClass)
#' @rdname indication
#' @format NULL
#' @usage NULL
#' @export
IndicateClass <- R6::R6Class("Indicate", inherit = TransformClass, lock_objects = FALSE,
  public = list(
    color = NULL,
    scale_factor = 1.2,
    initialize = function(mobject, scale_factor = 1.2, color = PURE_YELLOW, rate_func = there_and_back, ...) {
      self$color <- color
      self$scale_factor <- scale_factor
      super$initialize(mobject, rate_func = rate_func, ...)
    },
    create_target = function() {
      target <- self$mobject$copy()
      target$scale(self$scale_factor)
      target$set_color(self$color)
      target
    }
  )
)

#' @rdname indication
#' @export
Indicate <- constructor(IndicateClass)
#' @rdname indication
#' @format NULL
#' @usage NULL
#' @export
ShowPassingFlashClass <- R6::R6Class("ShowPassingFlash", inherit = ShowPartialClass, lock_objects = FALSE,
  public = list(
    time_width = 0.1,
    initialize = function(mobject, time_width = 0.1, ...) {
      self$time_width <- time_width
      super$initialize(mobject, remover = TRUE, introducer = TRUE, ...)
    },
    get_bounds = function(alpha) {
      tw <- self$time_width
      upper <- interpolate(0, 1 + tw, alpha)
      lower <- upper - tw
      c(max(lower, 0), min(upper, 1))
    },
    clean_up_from_scene = function(scene) {
      super$clean_up_from_scene(scene)
      for (pair in self$get_all_families_zipped()) pair[[1]]$pointwise_become_partial(pair[[2]], 0, 1)
    }
  )
)

#' @rdname indication
#' @export
ShowPassingFlash <- constructor(ShowPassingFlashClass)
#' @rdname indication
#' @export
Flash <- function(point, line_length = 0.2, num_lines = 12, flash_radius = 0.1, line_stroke_width = 3,
                  color = PURE_YELLOW, time_width = 1, run_time = 1, ...) {
  ov <- animation_override("Flash", point, match.call(), parent.frame(), "point")
  if (!is.null(ov)) return(ov$value)
  FlashClass$new(point, line_length = line_length, num_lines = num_lines, flash_radius = flash_radius,
                 line_stroke_width = line_stroke_width, color = color, time_width = time_width,
                 run_time = run_time, ...)
}

#' @rdname indication
#' @format NULL
#' @usage NULL
#' @export
FlashClass <- R6::R6Class("Flash", inherit = AnimationGroupClass, lock_objects = FALSE,
  public = list(
    point = NULL,
    color = NULL,
    line_length = 0.2,
    num_lines = 12,
    flash_radius = 0.1,
    line_stroke_width = 3,
    time_width = 1,
    animation_config = NULL,
    lines = NULL,
    initialize = function(point, line_length = 0.2, num_lines = 12, flash_radius = 0.1, line_stroke_width = 3,
                          color = PURE_YELLOW, time_width = 1, run_time = 1, ...) {
      self$point <- if (is_mobject(point)) point$get_center() else as_point(point)
      self$color <- color
      self$line_length <- line_length
      self$num_lines <- num_lines
      self$flash_radius <- flash_radius
      self$line_stroke_width <- line_stroke_width
      self$time_width <- time_width
      self$run_time <- run_time
      self$animation_config <- list(...)
      self$lines <- self$create_lines()
      do.call(super$initialize, c(self$create_line_anims(), list(group = self$lines)))
    },
    create_lines = function() {
      p <- self$point
      lines <- VGroup()
      for (angle in seq(0, TAU - 1e-9, by = TAU / self$num_lines)) {
        line <- Line(p, p + self$line_length * RIGHT)
        line$shift(self$flash_radius * RIGHT)
        line$rotate(angle, about_point = p)
        lines$add(line)
      }
      lines$set_color(self$color)
      lines$set_stroke(width = self$line_stroke_width)
      lines
    },
    create_line_anims = function() {
      lapply(self$lines$submobjects, function(l) {
        do.call(ShowPassingFlash, c(list(l, time_width = self$time_width, run_time = self$run_time),
                                    self$animation_config))
      })
    }
  )
)

#' @rdname indication
#' @export
ShowPassingFlashWithThinningStrokeWidth <- function(vmobject, n_segments = 10, time_width = 0.1, remover = TRUE, ...) {
  ov <- animation_override("ShowPassingFlashWithThinningStrokeWidth", vmobject, match.call(), parent.frame(), "vmobject")
  if (!is.null(ov)) return(ov$value)
  msw <- vmobject$get_stroke_width()
  sws <- seq(0, msw, length.out = n_segments)
  tws <- seq(time_width, 0, length.out = n_segments)
  anims <- lapply(seq_len(n_segments), function(i) {
    ShowPassingFlash(vmobject$copy()$set_stroke(width = sws[i]), time_width = tws[i], ...)
  })
  a <- do.call(AnimationGroupClass$new, anims)
  a$remover <- remover
  a
}

#' @rdname indication
#' @export
ApplyWave <- function(mobject, direction = UP, amplitude = 0.2, wave_func = smooth_rate, time_width = 1,
                      ripples = 1, run_time = 2, ...) {
  ov <- animation_override("ApplyWave", mobject, match.call(), parent.frame())
  if (!is.null(ov)) return(ov$value)
  x_min <- mobject$get_left()[1]
  x_max <- mobject$get_right()[1]
  vect <- amplitude * normalize(direction)
  wave <- function(t) {
    t <- 1 - t
    if (t >= 1 || t <= 0) return(0)
    phases <- ripples * 2
    phase <- as.integer(t * phases)
    if (phase == 0) return(wave_func(t * phases))
    if (phase == phases - 1) {
      t <- t - phase / phases
      return((1 - wave_func(t * phases)) * (2 * (ripples %% 2) - 1))
    }
    phase <- as.integer((phase - 1) / 2)
    t <- t - (2 * phase + 1) / phases
    (1 - 2 * wave_func(t * ripples)) * (1 - 2 * (phase %% 2))
  }
  homotopy <- function(x, y, z, t) {
    upper <- interpolate(0, 1 + time_width, t)
    lower <- upper - time_width
    rel_x <- inverse_interpolate(x_min, x_max, x)
    phase <- inverse_interpolate(lower, upper, rel_x)
    c(x, y, z) + wave(phase) * vect
  }
  a <- HomotopyClass$new(homotopy, mobject, run_time = run_time, ...)
  class(a) <- c("ApplyWave", class(a))
  a
}

#' @rdname indication
#' @format NULL
#' @usage NULL
#' @export
WiggleClass <- R6::R6Class("Wiggle", inherit = AnimationClass, lock_objects = FALSE,
  public = list(
    scale_value = 1.1,
    rotation_angle = 0.01 * TAU,
    n_wiggles = 6,
    scale_about_point = NULL,
    rotate_about_point = NULL,
    initialize = function(mobject, scale_value = 1.1, rotation_angle = 0.01 * TAU, n_wiggles = 6,
                          scale_about_point = NULL, rotate_about_point = NULL, run_time = 2, ...) {
      self$scale_value <- scale_value
      self$rotation_angle <- rotation_angle
      self$n_wiggles <- n_wiggles
      self$scale_about_point <- scale_about_point
      self$rotate_about_point <- rotate_about_point
      super$initialize(mobject, run_time = run_time, ...)
    },
    get_scale_about_point = function() self$scale_about_point %||% self$mobject$get_center(),
    get_rotate_about_point = function() self$rotate_about_point %||% self$mobject$get_center(),
    interpolate_submobject = function(submobject, starting_submobject, alpha) {
      submobject$points <- starting_submobject$points
      submobject$scale(interpolate(1, self$scale_value, there_and_back(alpha)), about_point = self$get_scale_about_point())
      submobject$rotate(wiggle(alpha, self$n_wiggles) * self$rotation_angle, about_point = self$get_rotate_about_point())
      invisible(self)
    }
  )
)

#' @rdname indication
#' @export
Wiggle <- constructor(WiggleClass)
#' @rdname indication
#' @export
Circumscribe <- function(mobject, shape = c("rectangle", "circle"), fade_in = FALSE, fade_out = FALSE,
                         time_width = 0.3, buff = SMALL_BUFF, color = PURE_YELLOW, run_time = 1,
                         stroke_width = DEFAULT_STROKE_WIDTH, ...) {
  ov <- animation_override("Circumscribe", mobject, match.call(), parent.frame())
  if (!is.null(ov)) return(ov$value)
  if (!is.character(shape)) shape <- if (identical(shape, CircleClass) || identical(shape, Circle)) "circle" else "rectangle"
  shape <- match.arg(shape)
  if (shape == "rectangle") {
    frame <- SurroundingRectangle(mobject, color = color, buff = buff, stroke_width = stroke_width)
  } else {
    frame <- Circle(color = color, stroke_width = stroke_width)$surround(mobject, buffer_factor = 1)
    radius <- frame$width / 2
    frame$scale((radius + buff) / radius)
  }
  anims <- if (fade_in && fade_out) {
    list(FadeIn(frame, run_time = run_time / 2), FadeOut(frame, run_time = run_time / 2))
  } else if (fade_in) {
    frame$reverse_direction()
    list(FadeIn(frame, run_time = run_time / 2), Uncreate(frame, run_time = run_time / 2))
  } else if (fade_out) {
    list(Create(frame, run_time = run_time / 2), FadeOut(frame, run_time = run_time / 2))
  } else {
    list(ShowPassingFlash(frame, time_width, run_time = run_time))
  }
  a <- do.call(SuccessionClass$new, c(anims, list(...)))
  class(a) <- c("Circumscribe", class(a))
  a
}

#' @rdname indication
#' @export
Blink <- function(mobject, time_on = 0.5, time_off = 0.5, blinks = 1, hide_at_end = FALSE, ...) {
  ov <- animation_override("Blink", mobject, match.call(), parent.frame())
  if (!is.null(ov)) return(ov$value)
  on <- function() UpdateFromFunc(mobject, function(m) m$set_opacity(1), run_time = time_on)
  off <- function() UpdateFromFunc(mobject, function(m) m$set_opacity(0), run_time = time_off)
  anims <- unlist(lapply(seq_len(blinks), function(i) list(on(), off())), recursive = FALSE)
  if (!hide_at_end) anims <- c(anims, list(on()))
  do.call(SuccessionClass$new, c(anims, list(...)))
}
