# Bezier utilities ported from manim/utils/bezier.py.
# A point set is an n x 3 matrix. A cubic curve is 4 consecutive rows:
# anchor, handle, handle, anchor.

#' Interpolation helpers
#'
#' `interpolate()` returns `(1 - alpha) * start + alpha * end`, as upstream
#' computes it, and works on numbers, vectors and matrices.
#'
#' @param start,end Values to interpolate between.
#' @param alpha Interpolation parameter.
#' @export
interpolate <- function(start, end, alpha) (1 - alpha) * start + alpha * end

#' @rdname interpolate
#' @param value Value whose interpolation parameter `inverse_interpolate()`
#'   returns.
#' @export
inverse_interpolate <-function(start, end, value) (value - start) / (end - start)

#' @rdname interpolate
#' @param new_start,new_end,old_start,old_end,old_value Ranges for `match_interpolate()`.
#' @export
match_interpolate <- function(new_start, new_end, old_start, old_end, old_value) {
  interpolate(new_start, new_end, inverse_interpolate(old_start, old_end, old_value))
}

#' @rdname interpolate
#' @details `integer_interpolate()` returns `list(index, residue)`: the
#'   integer part of `interpolate(start, end, alpha)` (truncated as Python's
#'   `int()` does) and the fractional part of `(end - start) * alpha`. When
#'   `alpha >= 1` it returns `end - 1` and residue 1. The numbers follow
#'   upstream exactly, so `integer_interpolate(0, n, alpha)$index` is a 0 based
#'   position: add 1 before using it to index an R vector.
#' @export
#' @examples
#' integer_interpolate(0, 10, 0.46) # index 4, residue 0.6
integer_interpolate <- function(start, end, alpha) {
  if (alpha >= 1) return(list(index = as.integer(end - 1), residue = 1))
  if (alpha <= 0) return(list(index = as.integer(start), residue = 0))
  value <- as.integer(interpolate(start, end, alpha))
  residue <- ((end - start) * alpha) %% 1
  list(index = value, residue = residue)
}

#' @rdname interpolate
#' @details `mid()` returns the midpoint `(start + end) / 2` of two numbers or
#'   points.
#' @export
mid <- function(start, end) (start + end) / 2

#' Evaluate a Bezier curve
#'
#' @param points Control points as an n x 3 matrix.
#' @return A function of `t` returning the point (or a matrix of points for a
#'   vector `t`).
#' @export
bezier <- function(points) {
  points <- as.matrix(points)
  n <- nrow(points) - 1
  force(points)
  function(t) {
    coefs <- outer(t, 0:n, function(tt, k) choose(n, k) * tt^k * (1 - tt)^(n - k))
    res <- coefs %*% points
    if (length(t) == 1) drop(res) else res
  }
}

# Cubic Bernstein basis evaluated at vector t: length(t) x 4 matrix.
cubic_basis <- function(t) {
  mt <- 1 - t
  cbind(mt^3, 3 * mt^2 * t, 3 * mt * t^2, t^3)
}

#' Split, trim and remap Bezier curves
#'
#' Helpers that operate on the control points of Bezier curves, given as an
#' n x 3 matrix with one control point per row (4 rows for a cubic curve).
#'
#' * `partial_bezier_points()` returns the control points of the portion of
#'   the curve with parameter in `[a, b]`, `0 <= a < b <= 1`.
#' * `split_bezier()` splits the curve at `t` and returns the control points
#'   of both halves stacked (`2 n` rows). Like upstream, a line (2 points)
#'   gives 4 rows `p0, m, m, p1` and a single point gives 2 rows.
#' * `subdivide_bezier()` splits the curve into `n_divisions` pieces of equal
#'   parameter length and returns their control points stacked
#'   (`n_divisions * n` rows). For curves of degree 4 or more, upstream's
#'   fallback splits at the wrong parameters (`1/3` and `1/2` for three
#'   pieces); manimR splits at `i / n_divisions`, as upstream documents.
#' * `bezier_remap()` takes a path of `k` cubic curves (a `4k x 3` matrix) and
#'   subdivides its curves so the result has `new_number_of_curves` curves,
#'   which must be at least `k`. Upstream takes a `(k, 4, 3)` array; here the
#'   curves are stacked rows as everywhere in manimR.
#'
#' @param points Control points, an n x 3 matrix (one row per point).
#' @param a,b Start and end of the parameter interval.
#' @param t Parameter at which to split.
#' @param n_divisions Number of pieces.
#' @param bezier_tuples Control points of the curves to remap, a `4k x 3`
#'   matrix.
#' @param new_number_of_curves Number of curves in the result.
#' @return A matrix of control points, one row per point.
#' @export
#' @examples
#' cubic <- rbind(c(0, 0, 0), c(1, 2, 0), c(3, -1, 0), c(4, 1, 0))
#' split_bezier(cubic, 0.5)
#' partial_bezier_points(cubic, 0.25, 0.75)
#' nrow(subdivide_bezier(cubic, 3))
#' nrow(bezier_remap(Square()$points, 7))
partial_bezier_points <- function(points, a, b) {
  points <- as.matrix(points)
  if (a == 1) return(points[rep(nrow(points), nrow(points)), , drop = FALSE])
  if (b == 0) return(points[rep(1, nrow(points)), , drop = FALSE])
  degree <- nrow(points) - 1
  if (degree == 3) {
    ma <- 1 - a
    mb <- 1 - b
    m <- rbind(
      c(ma^3, 3 * ma^2 * a, 3 * ma * a^2, a^3),
      c(ma^2 * mb, 2 * ma * a * mb + ma^2 * b, a^2 * mb + 2 * ma * a * b, a^2 * b),
      c(ma * mb^2, a * mb^2 + 2 * ma * mb * b, 2 * a * mb * b + ma * b^2, a * b^2),
      c(mb^3, 3 * mb^2 * b, 3 * mb * b^2, b^3)
    )
    return(m %*% points)
  }
  if (degree == 2) {
    ma <- 1 - a
    mb <- 1 - b
    m <- rbind(
      c(ma * ma, 2 * a * ma, a * a),
      c(ma * mb, a * mb + ma * b, a * b),
      c(mb * mb, 2 * b * mb, b * b)
    )
    return(m %*% points)
  }
  if (degree == 1) {
    d <- points[2, ] - points[1, ]
    return(rbind(points[1, ] + a * d, points[1, ] + b * d))
  }
  if (degree == 0) return(points)
  arr <- points
  N <- nrow(arr)
  if (a != 0) {
    for (i in 1:(N - 1)) {
      idx <- 1:(N - i)
      arr[idx, ] <- arr[idx, , drop = FALSE] + a * (arr[idx + 1, , drop = FALSE] - arr[idx, , drop = FALSE])
    }
  }
  if (b != 1) {
    mu <- (1 - b) / (1 - a)
    for (i in 1:(N - 1)) {
      idx <- (i + 1):N
      arr[idx, ] <- arr[idx, , drop = FALSE] + mu * (arr[idx - 1, , drop = FALSE] - arr[idx, , drop = FALSE])
    }
  }
  arr
}

#' @rdname partial_bezier_points
#' @export
split_bezier <- function(points, t) {
  points <- as.matrix(points)
  N <- nrow(points)
  # Successive linear interpolation (de Casteljau). Row k of the first half
  # is the first point of the k th level; the second half is the last level
  # read backwards, as upstream's split matrices produce.
  first <- matrix(0, N, ncol(points))
  second <- matrix(0, N, ncol(points))
  arr <- points
  first[1, ] <- arr[1, ]
  second[N, ] <- arr[N, ]
  for (i in seq_len(N - 1)) {
    idx <- seq_len(N - i)
    arr[idx, ] <- arr[idx, , drop = FALSE] + t * (arr[idx + 1, , drop = FALSE] - arr[idx, , drop = FALSE])
    first[i + 1, ] <- arr[1, ]
    second[N - i, ] <- arr[N - i, ]
  }
  rbind(first, second)
}

#' @rdname partial_bezier_points
#' @export
subdivide_bezier <- function(points, n_divisions) {
  n <- n_divisions
  if (n == 0) return(points[0, , drop = FALSE])
  if (n == 1) return(points)
  do.call(rbind, lapply(seq_len(n) - 1, function(k) partial_bezier_points(points, k / n, (k + 1) / n)))
}

#' @rdname partial_bezier_points
#' @export
bezier_remap <- function(bezier_tuples, new_number_of_curves) {
  points <- bezier_tuples
  new_n <- new_number_of_curves
  if (new_n == 0) return(points[0, , drop = FALSE])
  cur_n <- nrow(points) %/% 4
  if (cur_n == 0) return(points)
  repeat_idx <- ((seq_len(new_n) - 1) * cur_n) %/% new_n
  split_factors <- tabulate(repeat_idx + 1, nbins = cur_n)
  out <- vector("list", cur_n)
  for (i in seq_len(cur_n)) {
    sf <- split_factors[i]
    if (sf == 0) next
    out[[i]] <- subdivide_bezier(points[(4 * i - 3):(4 * i), , drop = FALSE], sf)
  }
  do.call(rbind, out)
}

#' Is a spline closed?
#'
#' Returns `TRUE` when the first and last rows of `points` are close, using
#' the tolerance `1e-8 + 1e-5 * start` per coordinate. This reproduces manim
#' 0.20.1 exactly, including its quirk: the tolerance uses the signed start
#' coordinate (no `abs()`), so a spline whose first point has a negative
#' coordinate never counts as closed. Smooth handles (see
#' [get_smooth_cubic_bezier_handle_points()]) depend on this test, so keeping
#' the quirk keeps manimR's curves identical to upstream's.
#'
#' @param points Points of a spline, an n x 3 matrix.
#' @return `TRUE` or `FALSE`.
#' @export
#' @examples
#' is_closed(rbind(c(0, 0, 0), c(1, 2, 3), c(0, 0, 0)))
#' is_closed(rbind(c(-1, 0, 0), c(1, 2, 3), c(-1, 0, 0)))
is_closed <- function(points) {
  n <- nrow(points)
  if (n == 0) return(FALSE)
  start <- points[1, ]
  end <- points[n, ]
  # Relative tolerance on abs(start), as current upstream; manim 0.20.1
  # omitted abs(), so curves starting at negative coordinates never closed.
  tolerance <- 1e-8 + 1e-5 * abs(start)
  if (abs(end[1] - start[1]) > tolerance[1]) return(FALSE)
  if (abs(end[2] - start[2]) > tolerance[2]) return(FALSE)
  abs(end[3] - start[3]) <= tolerance[3]
}

#' Smooth cubic Bezier handles
#'
#' Given the anchors of a cubic spline, computes the first and second handle
#' of every curve so that the spline is smooth (continuous first and second
#' derivatives). A closed spline (see [is_closed()]) is smoothed across its
#' start point too.
#'
#' @param anchors Anchors, an n x 3 matrix.
#' @return `list(h1, h2)`: two `(n - 1) x 3` matrices with the first and
#'   second handles of each curve (upstream returns a tuple).
#' @export
#' @examples
#' anchors <- rbind(c(0, 0, 0), c(1, 1, 0), c(2, 0, 0), c(3, 2, 0))
#' get_smooth_cubic_bezier_handle_points(anchors)
get_smooth_cubic_bezier_handle_points <- function(anchors) {
  anchors <- as.matrix(anchors)
  n_a <- nrow(anchors)
  dim <- ncol(anchors)
  if (n_a == 1) return(list(h1 = matrix(0, 0, dim), h2 = matrix(0, 0, dim)))
  if (n_a == 2) {
    return(list(
      h1 = matrix(interpolate(anchors[1, ], anchors[2, ], 1 / 3), 1),
      h2 = matrix(interpolate(anchors[1, ], anchors[2, ], 2 / 3), 1)
    ))
  }
  if (is_closed(anchors)) smooth_closed_handles(anchors) else smooth_open_handles(anchors)
}

smooth_open_handles <- function(A) {
  N <- nrow(A) - 1
  dim <- ncol(A)
  cp <- numeric(max(N - 1, 1))
  cp[1] <- 0.5
  if (N > 2) for (i in 2:(N - 1)) cp[i] <- 1 / (4 - cp[i - 1])
  Dp <- matrix(0, N, dim)
  Dp[1, ] <- 0.5 * A[1, ] + A[2, ]
  if (N > 2) {
    for (i in 2:(N - 1)) Dp[i, ] <- cp[i] * (4 * A[i, ] + 2 * A[i + 1, ] - Dp[i - 1, ])
  }
  Dp[N, ] <- (1 / (7 - 2 * cp[N - 1])) * (8 * A[N, ] + A[N + 1, ] - 2 * Dp[N - 1, ])
  H1 <- Dp
  for (i in (N - 1):1) H1[i, ] <- Dp[i, ] - cp[i] * H1[i + 1, ]
  H2 <- matrix(0, N, dim)
  if (N > 1) H2[1:(N - 1), ] <- 2 * A[2:N, ] - H1[2:N, ]
  H2[N, ] <- 0.5 * (A[N + 1, ] + H1[N, ])
  list(h1 = H1, h2 = H2)
}

smooth_closed_handles <- function(A) {
  N <- nrow(A) - 1
  dim <- ncol(A)
  cp <- numeric(N - 1)
  up <- numeric(N - 1)
  cp[1] <- 1 / 3
  up[1] <- 1 / 3
  if (N > 2) {
    for (i in 2:(N - 1)) {
      cp[i] <- 1 / (4 - cp[i - 1])
      up[i] <- -cp[i] * up[i - 1]
    }
  }
  cp_last <- 1 / (3 - cp[N - 1])
  up_last <- cp_last * (1 - up[N - 1])
  q <- numeric(N)
  q[N] <- up_last
  for (i in (N - 1):1) q[i] <- up[i] - cp[i] * q[i + 1]
  AUX <- 4 * A[1:N, , drop = FALSE] + 2 * A[2:(N + 1), , drop = FALSE]
  Dp <- matrix(0, N, dim)
  Dp[1, ] <- AUX[1, ] / 3
  if (N > 2) for (i in 2:(N - 1)) Dp[i, ] <- cp[i] * (AUX[i, ] - Dp[i - 1, ])
  Dp[N, ] <- cp_last * (AUX[N, ] - Dp[N - 1, ])
  Y <- Dp
  for (i in (N - 1):1) Y[i, ] <- Dp[i, ] - cp[i] * Y[i + 1, ]
  H1 <- Y - (1 / (1 + q[1] + q[N])) * outer(q, Y[1, ] + Y[N, ])
  H2 <- matrix(0, N, dim)
  H2[1:(N - 1), ] <- 2 * A[2:N, ] - H1[2:N, ]
  H2[N, ] <- 2 * A[N + 1, ] - H1[1, ]
  list(h1 = H1, h2 = H2)
}

#' Does a point lie on a Bezier curve?
#'
#' `proportions_along_bezier_curve_for_point()` solves, for each coordinate,
#' the Bezier polynomial minus the point's coordinate and returns the real
#' roots in `[0, 1]` common to every coordinate: the parameters at which the
#' curve passes through `point`. Roots are rounded to the number of decimals
#' given by `round_to` before they are compared, as upstream does.
#' `point_lies_on_bezier()` is `TRUE` when there is at least one such root.
#'
#' @param point A point, `c(x, y, z)`.
#' @param control_points Control points of the curve, an n x 3 matrix.
#' @param round_to Rounding precision of the roots.
#' @return A numeric vector of parameters (usually of length 0 or 1), or
#'   `TRUE`/`FALSE`.
#' @export
#' @examples
#' cubic <- rbind(c(0, 0, 0), c(1, 2, 0), c(3, -1, 0), c(4, 1, 0))
#' p <- bezier(cubic)(0.25)
#' proportions_along_bezier_curve_for_point(p, cubic)
#' point_lies_on_bezier(c(1, 1, 0), cubic)
proportions_along_bezier_curve_for_point <- function(point, control_points, round_to = 1e-6) {
  control_points <- as.matrix(control_points)
  if (length(point) != ncol(control_points)) {
    stop("The point and the control points have different shapes.", call. = FALSE)
  }
  n <- nrow(control_points) - 1
  digits <- as.integer(log10(1 / round_to))
  roots <- list()
  for (dim in seq_along(point)) {
    coords <- control_points[, dim]
    # Coefficients of the polynomial in power form, highest power first.
    terms <- vapply(n:0, function(term_power) {
      sub <- vapply(term_power:0, function(k) {
        s <- choose(term_power, k) * (-1)^(term_power - k) * coords[k + 1]
        if (term_power == 0) s <- s - point[dim]
        s
      }, numeric(1))
      choose(n, term_power) * sum(sub)
    }, numeric(1))
    if (all(terms == 0)) next
    coefs <- rev(terms)
    # numpy trims zero high order coefficients before solving.
    while (length(coefs) > 1 && coefs[length(coefs)] == 0) coefs <- coefs[-length(coefs)]
    r <- if (length(coefs) < 2) complex(0) else polyroot(coefs)
    r <- complex(real = round(Re(r), digits), imaginary = round(Im(r), digits))
    roots[[length(roots) + 1]] <- Re(r[Im(r) == 0])
  }
  if (!length(roots)) return(numeric())
  common <- sort(unique(Reduce(intersect, roots)))
  common[common >= 0 & common <= 1]
}

#' @rdname proportions_along_bezier_curve_for_point
#' @export
point_lies_on_bezier <- function(point, control_points, round_to = 1e-6) {
  length(proportions_along_bezier_curve_for_point(point, control_points, round_to)) > 0
}

# Approximate length of each cubic curve in a path (4k x 3), by sampling.
curve_lengths <- function(points, n_samples = 10) {
  k <- nrow(points) %/% 4
  if (k == 0) return(numeric())
  B <- cubic_basis(seq(0, 1, length.out = n_samples))
  vapply(seq_len(k), function(i) {
    p <- B %*% points[(4 * i - 3):(4 * i), , drop = FALSE]
    sum(sqrt(rowSums(diff(p)^2)))
  }, numeric(1))
}
