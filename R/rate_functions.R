# Rate functions ported from manim/utils/rate_functions.py.
# Each maps animation progress t in [0, 1] to an eased value.

#' Rate function decorators
#'
#' Upstream's decorators for rate functions. `unit_interval(f)` returns a
#' rate function that is 0 below `t = 0`, 1 above `t = 1`, and `f(t)`
#' between; `zero(f)` returns one that is 0 outside `[0, 1]`.
#'
#' @param f A rate function.
#' @return A rate function.
#' @export
#' @examples
#' clamped <- unit_interval(function(t) t^2)
#' clamped(1.5)
unit_interval <- function(f) {
  force(f)
  function(t, ...) {
    if (t < 0) return(0)
    if (t > 1) return(1)
    f(t, ...)
  }
}

#' @rdname unit_interval
#' @export
zero <- function(f) {
  force(f)
  function(t, ...) if (t >= 0 && t <= 1) f(t, ...) else 0
}

#' Numerical helpers
#'
#' Ports of `manim.utils.simple_functions`. `sigmoid()` is the logistic
#' function `1 / (1 + exp(-x))`. `binary_search()` looks, between
#' `lower_bound` and `upper_bound`, for the input at which the monotone
#' function `f` reaches `target`, halving the interval until it is
#' shorter than `tolerance`; it returns `NULL` when `target` is not between
#' the values at the bounds. Upstream's `clip()` is [clip_value()] here (an
#' exported `clip()` would mask `graphics::clip()`), and its `choose()` is
#' [base::choose()].
#'
#' @param x Numeric vector.
#' @return `sigmoid()`: numeric vector. `binary_search()`: a number or `NULL`.
#' @export
#' @examples
#' sigmoid(0)
#' binary_search(function(x) x^2 + 3 * x + 1, 11, 0, 5) # about 2
#' binary_search(function(x) x^2 + 3 * x + 1, 71, 0, 5) # NULL
sigmoid <- function(x) 1 / (1 + exp(-x))

#' Rate functions
#'
#' Functions that map animation progress `t` in `[0, 1]` to an eased value.
#' Pass one as `rate_func` to any animation or to `Scene$play()`. Manim's
#' `smooth` is called `smooth_rate` so it does not mask `stats::smooth()`.
#'
#' @param t Progress between 0 and 1.
#' @param ... Optional shape parameters of some rate functions:
#'   `inflection`, the steepness of the sigmoid (`smooth_rate()`,
#'   `rush_into()`, `rush_from()`, `there_and_back()`; default 10);
#'   `pause_ratio`, the fraction of the time spent paused at the peak
#'   (`there_and_back_with_pause()`; default 1/3); `pull_factor`, how far to
#'   pull back before starting (`running_start()`; default -0.5); `wiggles`,
#'   the number of wiggles (`wiggle()`; default 2); and `half_life`, the half
#'   life of the decay (`exponential_decay()`; default 0.1). Other rate
#'   functions take none.
#' @param func A rate function.
#' @param proportion Final proportion reached.
#' @param a,b Interval to squish the rate function into.
#' @return A rate function returns a number: the progress of an animation at
#'   the proportion `t` of its run time. The functions that take a rate function
#'   return a new rate function.
#' @name rate_funcs
#' @examples
#' smooth_rate(0.5)
#' there_and_back(0.25)
NULL

#' @rdname rate_funcs
#' @export
linear <- unit_interval(function(t) t)

#' @rdname rate_funcs
#' @export
smooth_rate <- unit_interval(function(t, inflection = 10) {
  error <- sigmoid(-inflection / 2)
  min(max((sigmoid(inflection * (t - 0.5)) - error) / (1 - 2 * error), 0), 1)
})

#' @rdname rate_funcs
#' @export
smoothstep <- unit_interval(function(t) 3 * t^2 - 2 * t^3)

#' @rdname rate_funcs
#' @export
smootherstep <- unit_interval(function(t) 6 * t^5 - 15 * t^4 + 10 * t^3)

#' @rdname rate_funcs
#' @export
smoothererstep <- unit_interval(function(t) 35 * t^4 - 84 * t^5 + 70 * t^6 - 20 * t^7)

#' @rdname rate_funcs
#' @export
rush_into <- unit_interval(function(t, inflection = 10) 2 * smooth_rate(t / 2, inflection))

#' @rdname rate_funcs
#' @export
rush_from <- unit_interval(function(t, inflection = 10) 2 * smooth_rate(t / 2 + 0.5, inflection) - 1)

#' @rdname rate_funcs
#' @export
slow_into <- unit_interval(function(t) sqrt(1 - (1 - t) * (1 - t)))

#' @rdname rate_funcs
#' @export
double_smooth <- unit_interval(function(t) {
  if (t < 0.5) 0.5 * smooth_rate(2 * t) else 0.5 * (1 + smooth_rate(2 * t - 1))
})

#' @rdname rate_funcs
#' @export
there_and_back <- zero(function(t, inflection = 10) {
  new_t <- if (t < 0.5) 2 * t else 2 * (1 - t)
  smooth_rate(new_t, inflection)
})

#' @rdname rate_funcs
#' @export
there_and_back_with_pause <- zero(function(t, pause_ratio = 1 / 3) {
  a <- 2 / (1 - pause_ratio)
  if (t < 0.5 - pause_ratio / 2) smooth_rate(a * t)
  else if (t < 0.5 + pause_ratio / 2) 1
  else smooth_rate(a - a * t)
})

#' @rdname rate_funcs
#' @export
running_start <- unit_interval(function(t, pull_factor = -0.5) {
  mt <- 1 - t
  15 * t^2 * mt^4 * pull_factor + 20 * t^3 * mt^3 * pull_factor +
    15 * t^4 * mt^2 + 6 * t^5 * mt + t^6
})

#' @rdname rate_funcs
#' @export
not_quite_there <- function(func = smooth_rate, proportion = 0.7) {
  force(func)
  function(t, ...) proportion * func(t, ...)
}

#' @rdname rate_funcs
#' @export
wiggle <- zero(function(t, wiggles = 2) there_and_back(t) * sin(wiggles * pi * t))

#' @rdname rate_funcs
#' @export
squish_rate_func <- function(func, a = 0.4, b = 0.6) {
  force(func)
  function(t, ...) {
    if (a == b) return(a)
    new_t <- if (t < a) 0 else if (t > b) 1 else (t - a) / (b - a)
    func(new_t, ...)
  }
}

#' @rdname rate_funcs
#' @export
lingering <- unit_interval(function(t) squish_rate_func(function(x) x, 0, 0.8)(t))

#' @rdname rate_funcs
#' @export
exponential_decay <- unit_interval(function(t, half_life = 0.1) 1 - exp(-t / half_life))

#' @rdname rate_funcs
#' @export
ease_in_sine <- unit_interval(function(t) 1 - cos(t * pi / 2))
#' @rdname rate_funcs
#' @export
ease_out_sine <- unit_interval(function(t) sin(t * pi / 2))
#' @rdname rate_funcs
#' @export
ease_in_out_sine <- unit_interval(function(t) -(cos(pi * t) - 1) / 2)
#' @rdname rate_funcs
#' @export
ease_in_quad <- unit_interval(function(t) t * t)
#' @rdname rate_funcs
#' @export
ease_out_quad <- unit_interval(function(t) 1 - (1 - t)^2)
#' @rdname rate_funcs
#' @export
ease_in_out_quad <- unit_interval(function(t) if (t < 0.5) 2 * t^2 else 1 - (-2 * t + 2)^2 / 2)
#' @rdname rate_funcs
#' @export
ease_in_cubic <- unit_interval(function(t) t^3)
#' @rdname rate_funcs
#' @export
ease_out_cubic <- unit_interval(function(t) 1 - (1 - t)^3)
#' @rdname rate_funcs
#' @export
ease_in_out_cubic <- unit_interval(function(t) if (t < 0.5) 4 * t^3 else 1 - (-2 * t + 2)^3 / 2)
#' @rdname rate_funcs
#' @export
ease_in_quart <- unit_interval(function(t) t^4)
#' @rdname rate_funcs
#' @export
ease_out_quart <- unit_interval(function(t) 1 - (1 - t)^4)
#' @rdname rate_funcs
#' @export
ease_in_out_quart <- unit_interval(function(t) if (t < 0.5) 8 * t^4 else 1 - (-2 * t + 2)^4 / 2)
#' @rdname rate_funcs
#' @export
ease_in_quint <- unit_interval(function(t) t^5)
#' @rdname rate_funcs
#' @export
ease_out_quint <- unit_interval(function(t) 1 - (1 - t)^5)
#' @rdname rate_funcs
#' @export
ease_in_out_quint <- unit_interval(function(t) if (t < 0.5) 16 * t^5 else 1 - (-2 * t + 2)^5 / 2)
#' @rdname rate_funcs
#' @export
ease_in_expo <- unit_interval(function(t) if (t == 0) 0 else 2^(10 * t - 10))
#' @rdname rate_funcs
#' @export
ease_out_expo <- unit_interval(function(t) if (t == 1) 1 else 1 - 2^(-10 * t))
#' @rdname rate_funcs
#' @export
ease_in_out_expo <- unit_interval(function(t) {
  if (t == 0) 0
  else if (t == 1) 1
  else if (t < 0.5) 2^(20 * t - 10) / 2
  else (2 - 2^(-20 * t + 10)) / 2
})
#' @rdname rate_funcs
#' @export
ease_in_circ <- unit_interval(function(t) 1 - sqrt(1 - t^2))
#' @rdname rate_funcs
#' @export
ease_out_circ <- unit_interval(function(t) sqrt(1 - (t - 1)^2))
#' @rdname rate_funcs
#' @export
ease_in_out_circ <- unit_interval(function(t) {
  if (t < 0.5) (1 - sqrt(1 - (2 * t)^2)) / 2 else (sqrt(1 - (-2 * t + 2)^2) + 1) / 2
})
#' @rdname rate_funcs
#' @export
ease_in_back <- unit_interval(function(t) {
  c1 <- 1.70158
  (c1 + 1) * t^3 - c1 * t^2
})
#' @rdname rate_funcs
#' @export
ease_out_back <- unit_interval(function(t) {
  c1 <- 1.70158
  1 + (c1 + 1) * (t - 1)^3 + c1 * (t - 1)^2
})
#' @rdname rate_funcs
#' @export
ease_in_out_back <- unit_interval(function(t) {
  c2 <- 1.70158 * 1.525
  if (t < 0.5) ((2 * t)^2 * ((c2 + 1) * 2 * t - c2)) / 2
  else ((2 * t - 2)^2 * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2
})
#' @rdname rate_funcs
#' @export
ease_in_elastic <- unit_interval(function(t) {
  c4 <- 2 * pi / 3
  if (t == 0) 0 else if (t == 1) 1 else -2^(10 * t - 10) * sin((t * 10 - 10.75) * c4)
})
#' @rdname rate_funcs
#' @export
ease_out_elastic <- unit_interval(function(t) {
  c4 <- 2 * pi / 3
  if (t == 0) 0 else if (t == 1) 1 else 2^(-10 * t) * sin((t * 10 - 0.75) * c4) + 1
})
#' @rdname rate_funcs
#' @export
ease_in_out_elastic <- unit_interval(function(t) {
  c5 <- 2 * pi / 4.5
  if (t == 0) 0
  else if (t == 1) 1
  else if (t < 0.5) -(2^(20 * t - 10) * sin((20 * t - 11.125) * c5)) / 2
  else (2^(-20 * t + 10) * sin((20 * t - 11.125) * c5)) / 2 + 1
})
#' @rdname rate_funcs
#' @export
ease_out_bounce <- unit_interval(function(t) {
  n1 <- 7.5625
  d1 <- 2.75
  if (t < 1 / d1) n1 * t^2
  else if (t < 2 / d1) n1 * (t - 1.5 / d1)^2 + 0.75
  else if (t < 2.5 / d1) n1 * (t - 2.25 / d1)^2 + 0.9375
  else n1 * (t - 2.625 / d1)^2 + 0.984375
})
#' @rdname rate_funcs
#' @export
ease_in_bounce <- unit_interval(function(t) 1 - ease_out_bounce(1 - t))
#' @rdname rate_funcs
#' @export
ease_in_out_bounce <- unit_interval(function(t) {
  if (t < 0.5) (1 - ease_out_bounce(1 - 2 * t)) / 2 else (1 + ease_out_bounce(2 * t - 1)) / 2
})
