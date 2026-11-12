# Mobjects representing vector fields. Ported from manim/mobject/vector_field.py.

#' @rdname VectorFieldClass
#' @export
DEFAULT_SCALAR_FIELD_COLORS <- c(BLUE_E, GREEN, YELLOW, RED)

# numpy.arange(start, stop, step): ceil((stop - start) / step) values.
vf_arange <- function(start, stop, step) {
  n <- ceiling((stop - start) / step)
  if (n <= 0) return(numeric())
  start + (seq_len(n) - 1) * step
}

# Complete a range c(min, max) or c(min, max, step) the way upstream does:
# a missing step becomes 0.5 and the end is pushed by one step, so that
# vf_arange() includes it.
vf_complete_range <- function(r) {
  r <- as.numeric(r)
  if (length(r) == 2) r <- c(r, 0.5)
  r[2] <- r[2] + r[3]
  r
}

vf_ranges <- function(x_range, y_range, z_range, three_dimensions) {
  x <- if (length(x_range)) x_range else c(floor(-frame_width() / 2), ceiling(frame_width() / 2))
  y <- if (length(y_range)) y_range else c(floor(-frame_height() / 2), ceiling(frame_height() / 2))
  z <- if (three_dimensions || length(z_range)) (if (length(z_range)) z_range else y) else c(0, 0)
  list(x = vf_complete_range(x), y = vf_complete_range(y), z = vf_complete_range(z))
}

# Evaluate expr with a fixed random seed, restoring the caller's RNG state.
vf_with_seed <- function(seed, expr) {
  old <- if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) get(".Random.seed", envir = globalenv()) else NULL
  on.exit(if (is.null(old)) rm(".Random.seed", envir = globalenv()) else assign(".Random.seed", old, envir = globalenv()))
  set.seed(seed)
  expr
}

#' @title Vector fields
#' @description `VectorField()` holds a function mapping a position to a
#'   vector and provides methods to move other mobjects along the field.
#'   `ArrowVectorField()` draws the field as a grid of arrows and
#'   `StreamLines()` as traces of agents moving through it. Unless `color` is
#'   given, colors come from `color_scheme` (by default the vector's length)
#'   mapped onto the gradient `colors`.
#'
#'   Methods: `nudge(mob, dt, substeps, pointwise)`,
#'   `nudge_submobjects(dt, substeps, pointwise)`,
#'   `get_nudge_updater(speed, pointwise)`,
#'   `start_submobject_movement(speed, pointwise)`,
#'   `stop_submobject_movement()`, `fit_to_coordinate_system(cs)`,
#'   `shift_func(func, shift_vector)`, `scale_func(func, scalar)`,
#'   `get_colored_background_image(sampling_rate)` (an RGB array) and
#'   `get_vectorized_rgba_gradient_function(start, end, colors)`.
#'   `StreamLines` adds `create()`, `start_animation()` and `end_animation()`.
#' @param func Function of a position `c(x, y, z)` returning a vector.
#' @param color Single color for the whole field; disables position based coloring.
#' @param color_scheme Function mapping a vector to a number; defaults to its length.
#' @param min_color_scheme_value,max_color_scheme_value Values mapped to the
#'   first and last of `colors`.
#' @param colors Colors of the gradient.
#' @param x_range,y_range,z_range `c(min, max, step)` (step defaults to 0.5).
#' @param three_dimensions Build a 3D grid (automatic when `z_range` is given).
#' @param length_func Maps a vector's length to its displayed length.
#' @param opacity Opacity of the arrows or stream lines.
#' @param vector_config Named list passed to [Vector()].
#' @param noise_factor Random offset of the stream line starting points;
#'   defaults to half of the y step.
#' @param n_repeats Number of agents per starting point.
#' @param dt Integration step of the stream lines.
#' @param virtual_time Simulated time; longer gives longer stream lines.
#' @param max_anchors_per_line Maximum anchors per stream line.
#' @param padding Distance agents may leave the spawning area.
#' @param stroke_width Stroke width of the stream lines.
#' @param ... Passed to [VGroup()].
#' @details As upstream, stream lines in the plane are colored through a
#'   background image of the field's colors (`get_colored_background_image()`,
#'   so a line's color changes along it with the field), and 3D stream lines
#'   get a stroke gradient from the colors at their anchors.
#' @export
#' @examples
#' \dontrun{
#' func <- function(pos) ((pos[1] * UR + pos[2] * LEFT) - pos) / 3
#' ArrowVectorField(func)
#' StreamLines(func)
#' }
VectorFieldClass <- R6::R6Class("VectorField", inherit = VGroupClass, lock_objects = FALSE,
  public = list(
    func = NULL,
    single_color = FALSE,
    color_scheme = NULL,
    min_color_scheme_value = 0,
    max_color_scheme_value = 2,
    rgbs = NULL,
    submob_movement_updater = NULL,
    initialize = function(func, color = NULL, color_scheme = NULL, min_color_scheme_value = 0,
                          max_color_scheme_value = 2, colors = DEFAULT_SCALAR_FIELD_COLORS, ...) {
      super$initialize(...)
      self$func <- func
      self$min_color_scheme_value <- min_color_scheme_value
      self$max_color_scheme_value <- max_color_scheme_value
      if (is.null(color)) {
        self$single_color <- FALSE
        self$color_scheme <- color_scheme %||% function(vec) sqrt(sum(vec^2))
        self$rgbs <- t(vapply(unlist(colors), color_to_rgb, numeric(3)))
      } else {
        self$single_color <- TRUE
        self$color <- manim_color(color)
      }
      self$submob_movement_updater <- NULL
    },
    eval_func = function(pos) as_point(self$func(as_point(pos))),
    pos_to_rgb = function(pos) {
      vec <- self$eval_func(pos)
      lo <- self$min_color_scheme_value
      hi <- self$max_color_scheme_value
      value <- min(max(self$color_scheme(vec), lo), hi)
      alpha <- inverse_interpolate(lo, hi, value) * (nrow(self$rgbs) - 1)
      i <- floor(alpha)
      c1 <- self$rgbs[i + 1, ]
      c2 <- self$rgbs[min(i + 2, nrow(self$rgbs)), ]
      interpolate(c1, c2, alpha %% 1)
    },
    pos_to_color = function(pos) rgb_hex(self$pos_to_rgb(pos)),
    shift_func = function(func, shift_vector) vector_field_shift_func(func, shift_vector),
    scale_func = function(func, scalar) vector_field_scale_func(func, scalar),
    fit_to_coordinate_system = function(coordinate_system) {
      self$apply_function(function(pos) do.call(coordinate_system$coords_to_point, as.list(pos)))
      invisible(self)
    },
    nudge = function(mob, dt = 1, substeps = 1, pointwise = FALSE) {
      runge_kutta <- function(p, step_size) {
        k_1 <- self$eval_func(p)
        k_2 <- self$eval_func(p + step_size * (k_1 * 0.5))
        k_3 <- self$eval_func(p + step_size * (k_2 * 0.5))
        k_4 <- self$eval_func(p + step_size * k_3)
        step_size / 6 * (k_1 + 2 * k_2 + 2 * k_3 + k_4)
      }
      step_size <- dt / substeps
      for (s in seq_len(substeps)) {
        if (pointwise) mob$apply_function(function(p) p + runge_kutta(p, step_size))
        else mob$shift(runge_kutta(mob$get_center(), step_size))
      }
      invisible(self)
    },
    nudge_submobjects = function(dt = 1, substeps = 1, pointwise = FALSE) {
      for (mob in self$submobjects) self$nudge(mob, dt, substeps, pointwise)
      invisible(self)
    },
    get_nudge_updater = function(speed = 1, pointwise = FALSE) {
      function(mob, dt) self$nudge(mob, dt * speed, pointwise = pointwise)
    },
    start_submobject_movement = function(speed = 1, pointwise = FALSE) {
      self$stop_submobject_movement()
      self$submob_movement_updater <- function(mob, dt) mob$nudge_submobjects(dt * speed, pointwise = pointwise)
      self$add_updater(self$submob_movement_updater)
      invisible(self)
    },
    stop_submobject_movement = function() {
      if (!is.null(self$submob_movement_updater)) self$remove_updater(self$submob_movement_updater)
      self$submob_movement_updater <- NULL
      invisible(self)
    },
    # An RGB array (rows from top to bottom) coloring every sampled pixel of
    # the frame by the field; usable with as.raster() or an ImageMobject.
    get_colored_background_image = function(sampling_rate = 5) {
      if (self$single_color) {
        stop("There is no point in generating an image if the vector field uses a single color.", call. = FALSE)
      }
      ph <- as.integer(cfg("pixel_height") / sampling_rate)
      pw <- as.integer(cfg("pixel_width") / sampling_rate)
      xs <- seq(-frame_width() / 2, frame_width() / 2, length.out = pw)
      ys <- seq(frame_height() / 2, -frame_height() / 2, length.out = ph)
      img <- array(0, c(ph, pw, 3))
      for (r in seq_len(ph)) for (cc in seq_len(pw)) img[r, cc, ] <- self$pos_to_rgb(c(xs[cc], ys[r], 0))
      img
    },
    get_vectorized_rgba_gradient_function = function(start, end, colors) {
      rgbs <- t(vapply(unlist(colors), color_to_rgb, numeric(3)))
      function(values, opacity = 1) {
        alphas <- pmin(pmax(inverse_interpolate(start, end, as.numeric(values)), 0), 1)
        scaled <- alphas * (nrow(rgbs) - 1)
        idx <- floor(scaled)
        nxt <- pmin(idx + 1, nrow(rgbs) - 1)
        inter <- scaled %% 1
        cbind(rgbs[idx + 1, , drop = FALSE] * (1 - inter) + rgbs[nxt + 1, , drop = FALSE] * inter, opacity)
      }
    }
  )
)

#' @rdname VectorFieldClass
#' @export
VectorField <- constructor(VectorFieldClass)
#' @rdname VectorFieldClass
#' @param shift_vector Shift applied to the field.
#' @param scalar Scale applied to the positions.
#' @export
vector_field_shift_func <- function(func, shift_vector) {
  force(func)
  sv <- as_point(shift_vector)
  function(p) func(p - sv)
}

#' @rdname VectorFieldClass
#' @export
vector_field_scale_func <- function(func, scalar) {
  force(func)
  force(scalar)
  function(p) func(p * scalar)
}

#' @rdname VectorFieldClass
#' @format NULL
#' @usage NULL
#' @export
ArrowVectorFieldClass <- R6::R6Class("ArrowVectorField", inherit = VectorFieldClass, lock_objects = FALSE,
  public = list(
    x_range = NULL,
    y_range = NULL,
    z_range = NULL,
    ranges = NULL,
    length_func = NULL,
    opacity = 1,
    vector_config = NULL,
    initialize = function(func, color = NULL, color_scheme = NULL, min_color_scheme_value = 0,
                          max_color_scheme_value = 2, colors = DEFAULT_SCALAR_FIELD_COLORS, x_range = NULL,
                          y_range = NULL, z_range = NULL, three_dimensions = FALSE, length_func = NULL,
                          opacity = 1, vector_config = NULL, ...) {
      r <- vf_ranges(x_range, y_range, z_range, three_dimensions)
      self$x_range <- r$x
      self$y_range <- r$y
      self$z_range <- r$z
      self$ranges <- unname(r)
      super$initialize(func, color, color_scheme, min_color_scheme_value, max_color_scheme_value, colors, ...)
      self$length_func <- length_func %||% function(norm) 0.45 * stats::plogis(norm)
      self$opacity <- opacity
      self$vector_config <- vector_config %||% list()
      xs <- vf_arange(r$x[1], r$x[2], r$x[3])
      ys <- vf_arange(r$y[1], r$y[2], r$y[3])
      zs <- vf_arange(r$z[1], r$z[2], r$z[3])
      vecs <- list()
      for (x in xs) for (y in ys) for (z in zs) vecs[[length(vecs) + 1]] <- self$get_vector(c(x, y, z))
      self$add(vecs)
      self$set_opacity(self$opacity)
    },
    # The Vector rooted at `point`, with length and color following the field.
    get_vector = function(point) {
      point <- as_point(point)
      output <- self$eval_func(point)
      norm <- sqrt(sum(output^2))
      if (norm != 0) output <- output * self$length_func(norm) / norm
      vect <- do.call(Vector, c(list(output), self$vector_config))
      vect$shift(point)
      vect$set_color(if (self$single_color) self$color else self$pos_to_color(point))
      vect
    }
  )
)

#' @rdname VectorFieldClass
#' @export
ArrowVectorField <- constructor(ArrowVectorFieldClass)
#' @rdname VectorFieldClass
#' @format NULL
#' @usage NULL
#' @export
StreamLineClass <- R6::R6Class("StreamLine", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    # Simulated time this line took to be traced.
    duration = 0,
    # Current virtual time position of the flowing animation.
    time = 0,
    # The animation currently flashing this line, if any.
    anim = NULL
  )
)

#' @rdname VectorFieldClass
#' @format NULL
#' @usage NULL
#' @export
StreamLinesClass <- R6::R6Class("StreamLines", inherit = VectorFieldClass, lock_objects = FALSE,
  public = list(
    x_range = NULL,
    y_range = NULL,
    z_range = NULL,
    ranges = NULL,
    noise_factor = NULL,
    n_repeats = 1,
    virtual_time = 3,
    max_anchors_per_line = 100,
    padding = 3,
    stream_lines = NULL,
    flow_animation = NULL,
    flow_speed = 1,
    time_width = 0.3,
    initialize = function(func, color = NULL, color_scheme = NULL, min_color_scheme_value = 0,
                          max_color_scheme_value = 2, colors = DEFAULT_SCALAR_FIELD_COLORS, x_range = NULL,
                          y_range = NULL, z_range = NULL, three_dimensions = FALSE, noise_factor = NULL,
                          n_repeats = 1, dt = 0.05, virtual_time = 3, max_anchors_per_line = 100, padding = 3,
                          stroke_width = 1, opacity = 1, ...) {
      r <- vf_ranges(x_range, y_range, z_range, three_dimensions)
      self$x_range <- r$x
      self$y_range <- r$y
      self$z_range <- r$z
      self$ranges <- unname(r)
      super$initialize(func, color, color_scheme, min_color_scheme_value, max_color_scheme_value, colors, ...)
      self$noise_factor <- noise_factor %||% (r$y[3] / 2)
      self$n_repeats <- n_repeats
      self$virtual_time <- virtual_time
      self$max_anchors_per_line <- max_anchors_per_line
      self$padding <- padding
      self$stroke_width <- stroke_width

      half_noise <- self$noise_factor / 2
      xs <- vf_arange(r$x[1], r$x[2], r$x[3])
      ys <- vf_arange(r$y[1], r$y[2], r$y[3])
      zs <- vf_arange(r$z[1], r$z[2], r$z[3])
      # Upstream draws the noise from numpy's default_rng(0); a fixed R seed
      # keeps the layout reproducible (the exact values differ from numpy).
      n_start <- n_repeats * length(xs) * length(ys) * length(zs)
      noise <- vf_with_seed(0, matrix(stats::runif(3 * n_start), ncol = 3, byrow = TRUE))
      grid <- expand.grid(z = zs, y = ys, x = xs, n = seq_len(n_repeats))
      start_points <- cbind(grid$x, grid$y, grid$z) - half_noise + self$noise_factor * noise

      lo <- c(r$x[1], r$y[1], r$z[1]) - padding
      hi <- c(r$x[2], r$y[2], r$z[2]) + padding - c(r$x[3], r$y[3], r$z[3])
      outside_box <- function(p) any(p < lo | p > hi)

      max_steps <- ceiling(virtual_time / dt) + 1
      # As upstream, flat stream lines show the field's colors through a
      # background image; 3D ones get a gradient from their anchors.
      flat <- isTRUE(all.equal(as.numeric(r$z), c(0, 0.5, 0.5)))
      if (!self$single_color && flat) self$background_img <- self$get_colored_background_image()
      for (k in seq_len(nrow(start_points))) {
        pts <- matrix(0, max_steps + 1, 3)
        pts[1, ] <- start_points[k, ]
        n <- 1
        for (s in seq_len(max_steps)) {
          new_point <- pts[n, ] + dt * self$eval_func(pts[n, ])
          if (outside_box(new_point)) break
          n <- n + 1
          pts[n, ] <- new_point
        }
        pts <- pts[seq_len(n), , drop = FALSE]
        line <- StreamLineClass$new()
        line$duration <- max_steps * dt
        step <- max(1, as.integer(n / self$max_anchors_per_line))
        line$set_points_smoothly(pts[seq(1, n, by = step), , drop = FALSE])
        if (self$single_color) {
          line$set_stroke(color = self$color, width = self$stroke_width, opacity = opacity)
        } else if (flat) {
          line$color_using_background_image(self$background_img)
          line$set_stroke(width = self$stroke_width, opacity = opacity)
        } else {
          anchors <- line$get_anchors()
          if (nrow(anchors) > 0) {
            line$set_stroke(color = vapply(seq_len(nrow(anchors)), function(i) self$pos_to_color(anchors[i, ]), ""))
            # Orient the stroke gradient from the first to the last anchor.
            d <- anchors[nrow(anchors), ] - anchors[1, ]
            if (max(abs(d)) > 0) line$set_sheen_direction(d / max(abs(d)), family = FALSE)
          }
          line$set_stroke(width = self$stroke_width, opacity = opacity)
        }
        self$add(line)
      }
      self$stream_lines <- Filter(function(m) inherits(m, "StreamLine"), self$submobjects)
    },
    # The creation animation of the stream lines, in random order.
    create = function(lag_ratio = NULL, run_time = NULL, ...) {
      run_time <- run_time %||% self$virtual_time
      run_time <- as.numeric(if (is.function(run_time)) run_time(self$virtual_time) else run_time)
      if (is.null(lag_ratio)) lag_ratio <- run_time / 2 / length(self$submobjects)
      animations <- lapply(self$stream_lines, function(line) Create(line, run_time = run_time, ...))
      animations <- animations[sample.int(length(animations))]
      do.call(AnimationGroup, c(animations, list(lag_ratio = lag_ratio)))
    },
    # Animates the stream lines continuously using an updater.
    start_animation = function(warm_up = TRUE, flow_speed = 1, time_width = 0.3, rate_func = linear,
                               line_animation_class = ShowPassingFlash, ...) {
      for (line in self$stream_lines) {
        anim <- line_animation_class(line, run_time = line$duration / flow_speed, rate_func = rate_func,
                                     time_width = time_width, ...)
        line$anim <- anim
        anim$begin()
        line$time <- stats::runif(1) * self$virtual_time
        if (warm_up) line$time <- -line$time
        self$add(anim$mobject)
      }
      updater <- function(mob, dt) {
        for (line in mob$stream_lines) {
          line$time <- line$time + dt * flow_speed
          # A modulo where upstream subtracts once, so one long step (a
          # skipped wait) also wraps around.
          if (line$time >= mob$virtual_time) line$time <- line$time %% mob$virtual_time
          line$anim$interpolate(min(max(line$time / line$anim$run_time, 0), 1))
        }
        mob
      }
      self$add_updater(updater)
      self$flow_animation <- updater
      self$flow_speed <- flow_speed
      self$time_width <- time_width
      invisible(self)
    },
    # An animation ending the flow smoothly with fully displayed lines.
    end_animation = function() {
      if (is.null(self$flow_animation)) stop("You have to start the animation before fading it out.", call. = FALSE)
      hide_and_wait <- function(mob, alpha) {
        if (alpha == 0) mob$set_stroke(opacity = 0)
        else if (alpha == 1) mob$set_stroke(opacity = 1)
      }
      dt <- 1 / cfg("frame_rate")
      finish_updater_cycle <- function(line, alpha) {
        line$time <- line$time + dt * self$flow_speed
        line$anim$interpolate(min(line$time / line$anim$run_time, 1))
        if (alpha == 1) {
          self$remove(line$anim$mobject)
          stream_lines_finish_flash(line)
        }
      }
      max_run_time <- self$virtual_time / self$flow_speed
      creation_rate_func <- ease_out_sine
      creation_starting_speed <- creation_rate_func(0.001) * 1000
      # Chosen so that creation starts at the speed of the flashing lines and eases out.
      creation_run_time <- max_run_time / (1 + self$time_width) * creation_starting_speed
      self$remove_updater(self$flow_animation)
      self$flow_animation <- NULL
      animations <- list()
      for (line in self$stream_lines) {
        create <- Create(line, run_time = creation_run_time, rate_func = creation_rate_func)
        if (line$time <= 0) {
          animations[[length(animations) + 1]] <- Succession(
            UpdateFromAlphaFunc(line, hide_and_wait, run_time = -line$time / self$flow_speed), create)
          self$remove(line$anim$mobject)
          stream_lines_finish_flash(line)
        } else {
          remaining_time <- max_run_time - line$time / self$flow_speed
          animations[[length(animations) + 1]] <- Succession(
            UpdateFromAlphaFunc(line, finish_updater_cycle, run_time = remaining_time), create)
        }
      }
      do.call(AnimationGroup, animations)
    }
  )
)

#' @rdname VectorFieldClass
#' @export
StreamLines <- constructor(StreamLinesClass)
# Finish a line's flash animation and restore its full shape, as
# ShowPassingFlash does when cleaning up. Upstream skips the restore, which
# leaves every line collapsed to a point once end_animation() has played.
stream_lines_finish_flash <- function(line) {
  line$anim$finish()
  for (pair in line$anim$get_all_families_zipped()) pair[[1]]$pointwise_become_partial(pair[[2]], 0, 1)
  invisible(line)
}
