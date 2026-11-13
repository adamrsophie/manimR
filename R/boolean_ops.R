# Boolean operations for two dimensional VMobjects.
# Ported from manim/mobject/geometry/boolean_ops.py. Upstream hands the cubic
# curves to skia-pathops, whose result is made of pieces of the input curves
# cut where they cross. Here the curves are cut at their crossings directly:
# each piece is kept (or reversed) by where it lies relative to the other
# shapes, and the kept pieces are joined into contours. The contours are
# written in the order and from the start points skia's path writer gives
# (outer contours before holes, each from an input contour's start point when
# it lies on it), so the points match upstream's up to skia's single
# precision floats.

# Cubic Bezier helpers on 4 x 2 control point matrices.
bool_eval <- function(P, t) {
  mt <- 1 - t
  outer(mt^3, P[1, ]) + outer(3 * mt^2 * t, P[2, ]) + outer(3 * mt * t^2, P[3, ]) + outer(t^3, P[4, ])
}
bool_deriv <- function(P, t) {
  mt <- 1 - t
  outer(3 * mt^2, P[2, ] - P[1, ]) + outer(6 * mt * t, P[3, ] - P[2, ]) + outer(3 * t^2, P[4, ] - P[3, ])
}
bool_is_line <- function(P, tol = 1e-9) {
  max(abs(P[2, ] - (2 * P[1, ] + P[4, ]) / 3), abs(P[3, ] - (P[1, ] + 2 * P[4, ]) / 3)) < tol * max(1, abs(P))
}

# The cubic segments of a VMobject, by subpath: list of lists of 4 x 2
# matrices, as upstream's _convert_vmobject_to_skia_path reads them (a closed
# subpath is closed; an open one is closed by skia too, with a line).
bool_segments <- function(vmobject) {
  pts <- vmobject$points
  if (nrow(pts) < 4 || !all(is.finite(pts))) return(list())
  lapply(vmobject$gen_subpaths_from_points_2d(pts), function(sp) {
    n <- nrow(sp) %/% 4
    # Skia's edge builder sets coordinates within FLT_EPSILON of 0 to 0. A
    # start point it moves no longer matches pathops' saved start points.
    raw <- sp[1, 1:2]
    sp[, 1:2][abs(sp[, 1:2]) <= 1.1920929e-07] <- 0
    segs <- lapply(seq_len(n), function(k) sp[(4 * k - 3):(4 * k), 1:2, drop = FALSE])
    first <- segs[[1]][1, ]
    last <- segs[[n]][4, ]
    if (sqrt(sum((first - last)^2)) > 1e-9) {
      segs[[n + 1]] <- rbind(last, (2 * last + first) / 3, (last + 2 * first) / 3, first)
    }
    attr(segs, "start") <- if (all(raw == first)) first else c(NA, NA)
    segs
  })
}

# Parameters (t on P, u on Q) where two cubics meet: crossings of their
# sampled polylines refined by Newton's method, and endpoints of one lying on
# the other (which also catches touching and shared pieces).
bool_crossings <- function(P, Q, n = 48) {
  rP <- apply(P, 2, range)
  rQ <- apply(Q, 2, range)
  if (rP[2, 1] < rQ[1, 1] - 1e-9 || rQ[2, 1] < rP[1, 1] - 1e-9 ||
      rP[2, 2] < rQ[1, 2] - 1e-9 || rQ[2, 2] < rP[1, 2] - 1e-9) return(matrix(0, 0, 3))
  # The same curve, either way round: they meet only at their ends.
  if (max(abs(P - Q)) < 1e-9) return(rbind(c(0, 0, 2), c(1, 1, 2)))
  if (max(abs(P - Q[4:1, ])) < 1e-9) return(rbind(c(0, 1, 2), c(1, 0, 2)))
  s <- seq(0, 1, length.out = n + 1)
  a <- bool_eval(P, s)
  b <- bool_eval(Q, s)
  i <- rep(seq_len(n), times = n)
  j <- rep(seq_len(n), each = n)
  p0 <- a[i, , drop = FALSE]; p1 <- a[i + 1, , drop = FALSE]
  q0 <- b[j, , drop = FALSE]; q1 <- b[j + 1, , drop = FALSE]
  r <- p1 - p0
  d <- q1 - q0
  den <- r[, 1] * d[, 2] - r[, 2] * d[, 1]
  w <- q0 - p0
  ta <- (w[, 1] * d[, 2] - w[, 2] * d[, 1]) / den
  ub <- (w[, 1] * r[, 2] - w[, 2] * r[, 1]) / den
  hit <- is.finite(ta) & ta >= -0.01 & ta <= 1.01 & ub >= -0.01 & ub <= 1.01
  out <- matrix(0, 0, 3)
  for (k in which(hit)) {
    t <- (i[k] - 1 + ta[k]) / n
    u <- (j[k] - 1 + ub[k]) / n
    for (it in 1:30) {
      f <- bool_eval(P, t) - bool_eval(Q, u)
      J <- cbind(drop(bool_deriv(P, t)), -drop(bool_deriv(Q, u)))
      det <- J[1, 1] * J[2, 2] - J[1, 2] * J[2, 1]
      if (!is.finite(det) || abs(det) < 1e-300) break
      step <- c(J[2, 2] * f[1] - J[1, 2] * f[2], -J[2, 1] * f[1] + J[1, 1] * f[2]) / det
      t <- t - step[1]
      u <- u - step[2]
      if (max(abs(step)) < 1e-15) break
    }
    if (t >= -1e-9 && t <= 1 + 1e-9 && u >= -1e-9 && u <= 1 + 1e-9 &&
        sqrt(sum((bool_eval(P, t) - bool_eval(Q, u))^2)) < 1e-9) {
      out <- rbind(out, c(min(max(t, 0), 1), min(max(u, 0), 1), NA))
    }
  }
  # Endpoints lying on the other curve.
  on_curve <- function(pt, C) {
    s <- seq(0, 1, length.out = 4 * n + 1)
    dd <- colSums((t(bool_eval(C, s)) - pt)^2)
    u <- s[which.min(dd)]
    for (it in 1:30) {
      f <- drop(bool_eval(C, u)) - pt
      d1 <- drop(bool_deriv(C, u))
      d2 <- drop(6 * (1 - u) * (C[3, ] - 2 * C[2, ] + C[1, ]) + 6 * u * (C[4, ] - 2 * C[3, ] + C[2, ]))
      g <- sum(f * d1)
      h <- sum(d1 * d1) + sum(f * d2)
      if (abs(h) < 1e-300) break
      step <- g / h
      u <- min(max(u - step, 0), 1)
      if (abs(step) < 1e-15) break
    }
    if (sqrt(sum((drop(bool_eval(C, u)) - pt)^2)) < 1e-9) u else NA
  }
  for (t in c(0, 1)) {
    u <- on_curve(drop(bool_eval(P, t)), Q)
    if (!is.na(u)) out <- rbind(out, c(t, u, NA))
  }
  for (u in c(0, 1)) {
    t <- on_curve(drop(bool_eval(Q, u)), P)
    if (!is.na(t)) out <- rbind(out, c(t, u, NA))
  }
  # Third column: 1 where the curves meet at an angle, 0 where they run
  # together, 2 (above) for the same curve.
  for (r in seq_len(nrow(out))) if (is.na(out[r, 3])) {
    a <- drop(bool_deriv(P, out[r, 1]))
    b <- drop(bool_deriv(Q, out[r, 2]))
    out[r, 3] <- abs(a[1] * b[2] - a[2] * b[1]) > 1e-6 * sqrt(sum(a^2) * sum(b^2))
  }
  out
}

# Polyline of a shape's segments, for winding numbers and distances.
bool_flatten <- function(subpaths, n = 64) {
  s <- seq(0, 1, length.out = n + 1)
  lapply(subpaths, function(segs) {
    do.call(rbind, lapply(segs, function(P) bool_eval(P, s)[-(n + 1), , drop = FALSE]))
  })
}

# Nonzero winding number of a point about flattened subpaths.
bool_winding <- function(pt, flat) {
  w <- 0
  for (poly in flat) {
    x0 <- poly[, 1] - pt[1]; y0 <- poly[, 2] - pt[2]
    x1 <- c(x0[-1], x0[1]); y1 <- c(y0[-1], y0[1])
    up <- y0 <= 0 & y1 > 0
    down <- y0 > 0 & y1 <= 0
    cr <- x0 * y1 - x1 * y0
    w <- w + sum(up & cr > 0) - sum(down & cr < 0)
  }
  w
}

# Distance from a point to flattened subpaths, and the direction of the
# nearest polyline segment.
bool_nearest <- function(pt, flat) {
  best <- list(d = Inf, dir = c(0, 0))
  for (poly in flat) {
    a <- poly
    b <- poly[c(2:nrow(poly), 1), , drop = FALSE]
    ab <- b - a
    len2 <- rowSums(ab^2)
    t <- pmin(pmax(((pt[1] - a[, 1]) * ab[, 1] + (pt[2] - a[, 2]) * ab[, 2]) / pmax(len2, 1e-300), 0), 1)
    d <- sqrt((a[, 1] + t * ab[, 1] - pt[1])^2 + (a[, 2] + t * ab[, 2] - pt[2])^2)
    k <- which.min(d)
    if (d[k] < best$d) best <- list(d = d[k], dir = ab[k, ] / sqrt(max(len2[k], 1e-300)))
  }
  best
}

# One boolean operation of shapes (lists of subpaths of segments). op is
# "union" (of any number of shapes, as skia's simplify of them together),
# "intersection", "difference" or "xor" (of two). Returns the contours as
# lists of pieces (4 x 2 matrices with their sort ranks).
bool_op <- function(shapes, op) {
  ns <- length(shapes)
  flat <- lapply(shapes, bool_flatten, n = 400)
  # Cut parameters of every segment.
  cuts <- lapply(shapes, function(sh) lapply(sh, function(segs) lapply(segs, function(P) c(0, 1))))
  # Points where the shapes meet at an angle, and ends of curves they share.
  touch <- matrix(0, 0, 2)
  shared <- matrix(0, 0, 2)
  for (sa in seq_len(ns - 1)) for (sb in (sa + 1):ns) {
    A <- shapes[[sa]]
    B <- shapes[[sb]]
    for (ia in seq_along(A)) for (ka in seq_along(A[[ia]])) for (ib in seq_along(B)) for (kb in seq_along(B[[ib]])) {
      x <- bool_crossings(A[[ia]][[ka]], B[[ib]][[kb]])
      if (nrow(x)) {
        cuts[[sa]][[ia]][[ka]] <- c(cuts[[sa]][[ia]][[ka]], x[, 1])
        cuts[[sb]][[ib]][[kb]] <- c(cuts[[sb]][[ib]][[kb]], x[, 2])
        at <- bool_eval(A[[ia]][[ka]], x[, 1])
        touch <- rbind(touch, at[x[, 3] == 1, , drop = FALSE])
        shared <- rbind(shared, at[x[, 3] == 2, , drop = FALSE])
      }
    }
  }
  pieces <- list()
  rank <- 0
  for (s in seq_len(ns)) {
    others <- setdiff(seq_len(ns), s)
    for (i in seq_along(shapes[[s]])) for (k in seq_along(shapes[[s]][[i]])) {
      P <- shapes[[s]][[i]][[k]]
      t <- sort(unique(round(cuts[[s]][[i]][[k]], 12)))
      t <- t[c(TRUE, diff(t) > 1e-9)]
      t[length(t)] <- 1
      for (m in seq_len(length(t) - 1)) {
        rank <- rank + 1
        piece <- partial_bezier_points(P, t[m], t[m + 1])
        if (max(abs(piece - piece[rep(1, 4), , drop = FALSE])) < 1e-7) next
        mid <- drop(bool_eval(piece, 0.5))
        tan <- drop(bool_deriv(piece, 0.5))
        # Where the piece lies relative to each other shape: on its edge in
        # the same or the opposite direction, inside or outside.
        state <- vapply(others, function(o) {
          near <- bool_nearest(mid, flat[[o]])
          if (near$d < 1e-6) {
            if (sum(tan * near$dir) > 0) "same" else "opposite"
          } else if (bool_winding(mid, flat[[o]]) != 0) "inside" else "outside"
        }, "")
        keep <- switch(op,
          union = all(state == "outside" | (state == "same" & others > s)),
          intersection = state == "inside" || (s == 1 && state == "same"),
          difference = if (s == 1) state %in% c("outside", "opposite") else state == "inside",
          xor = state %in% c("outside", "inside"))
        if (!keep) next
        reverse <- (op == "difference" && s == 2) || (op == "xor" && state == "inside")
        if (reverse) piece <- piece[4:1, , drop = FALSE]
        # Whether the piece starts at a point of the input, not a crossing.
        vertex <- if (reverse) m == length(t) - 1 else m == 1
        # Whether it starts where the shapes meet at an angle (not at the end
        # of a curve they share).
        p0 <- piece[1, ]
        near <- function(M) nrow(M) > 0 && any(abs(M[, 1] - p0[1]) < 1e-7 & abs(M[, 2] - p0[2]) < 1e-7)
        crossing <- near(touch) && !near(shared)
        pieces[[length(pieces) + 1]] <- list(P = piece, rank = rank, reversed = reverse,
                                             inside = any(state == "inside"), vertex = vertex,
                                             crossing = crossing)
      }
    }
  }
  bool_join(pieces)
}

# Joins pieces end to start into closed contours.
bool_join <- function(pieces) {
  used <- logical(length(pieces))
  starts <- t(vapply(pieces, function(p) p$P[1, ], numeric(2)))
  contours <- list()
  while (!all(used)) {
    k <- which(!used)[1]
    contour <- list()
    first <- pieces[[k]]$P[1, ]
    repeat {
      used[k] <- TRUE
      contour[[length(contour) + 1]] <- pieces[[k]]
      end <- pieces[[k]]$P[4, ]
      if (sqrt(sum((end - first)^2)) < 1e-7 && length(contour) > 0) break
      cand <- which(!used & abs(starts[, 1] - end[1]) < 1e-7 & abs(starts[, 2] - end[2]) < 1e-7)
      if (!length(cand)) break
      if (length(cand) > 1) {
        # Where an exclusion's contours cross, skia keeps each region apart:
        # it goes from a piece inside the other shape to one outside it.
        # Where they meet at anchors of both (a circle through a square's
        # corners), skia stays on the same side and walks the outer outline.
        at_anchor <- all(vapply(cand, function(c) pieces[[c]]$vertex, NA))
        alt <- cand[vapply(cand, function(c) xor(pieces[[c]]$inside != pieces[[k]]$inside, at_anchor), NA)]
        if (length(alt)) cand <- alt
      }
      if (length(cand) > 1) {
        # Otherwise turn as far left as possible.
        tin <- pieces[[k]]$P[4, ] - pieces[[k]]$P[3, ]
        ang <- vapply(cand, function(c) {
          tout <- pieces[[c]]$P[2, ] - pieces[[c]]$P[1, ]
          atan2(tin[1] * tout[2] - tin[2] * tout[1], sum(tin * tout))
        }, 0)
        cand <- cand[which.max(ang)]
      }
      k <- cand
    }
    ext <- do.call(rbind, lapply(contour, function(pc) pc$P))
    if (max(apply(ext, 2, function(x) diff(range(x)))) > 1e-7) contours[[length(contours) + 1]] <- contour
  }
  contours
}

bool_area <- function(contour) {
  p <- do.call(rbind, lapply(contour, function(pc) bool_eval(pc$P, seq(0, 1, length.out = 33))[-33, , drop = FALSE]))
  q <- p[c(2:nrow(p), 1), , drop = FALSE]
  0.5 * sum(p[, 1] * q[, 2] - q[, 1] * p[, 2])
}

bool_reverse <- function(contour) {
  lapply(rev(contour), function(pc) {
    pc$P <- pc$P[4:1, , drop = FALSE]
    pc$reversed <- !pc$reversed
    pc
  })
}

# Orders the contours, turns outer ones counterclockwise and holes clockwise,
# picks their start points as skia's path writer does, and writes them as
# cubic curves.
bool_write <- function(contours, input_starts) {
  if (!length(contours)) return(matrix(0, 0, 3))
  flats <- lapply(contours, function(c) list(do.call(rbind, lapply(c, function(pc) bool_eval(pc$P, seq(0, 1, length.out = 33))[-33, , drop = FALSE]))))
  depth <- vapply(seq_along(contours), function(i) {
    pt <- drop(bool_eval(contours[[i]][[1]]$P, 0.5))
    sum(vapply(seq_along(contours)[-i], function(j) bool_winding(pt, flats[[j]]) != 0, NA))
  }, 0)
  for (i in seq_along(contours)) {
    want <- if (depth[i] %% 2 == 0) 1 else -1
    if (sign(bool_area(contours[[i]])) != want) contours[[i]] <- bool_reverse(contours[[i]])
  }
  # pathops' winding fix lists the contours by size, largest first.
  first_rank <- vapply(contours, function(c) min(vapply(c, function(pc) pc$rank, 0)), 0)
  size <- vapply(contours, function(c) abs(bool_area(c)), 0)
  contours <- contours[order(-round(size, 9), first_rank)]
  used <- logical(nrow(input_starts))
  out <- list()
  for (contour in contours) {
    vstart <- t(vapply(contour, function(pc) pc$P[1, ], numeric(2)))
    at <- NA
    moved <- FALSE
    for (s in which(!used)) {
      hit <- which(abs(vstart[, 1] - input_starts[s, 1]) < 1e-7 & abs(vstart[, 2] - input_starts[s, 2]) < 1e-7)
      if (length(hit)) {
        used[s] <- TRUE
        at <- hit[1]
        # Skia's own walk already starts at an input start the other shape
        # touches, so pathops leaves that contour as it is.
        moved <- !contour[[at]]$crossing
        break
      }
    }
    if (is.na(at)) {
      # The original start of the earliest piece: a reversed piece starts
      # where the next one does.
      ranks <- vapply(contour, function(pc) pc$rank, 0)
      e <- which.min(ranks)
      at <- if (contour[[e]]$reversed) e %% length(contour) + 1 else e
    }
    n <- length(contour)
    contour <- contour[c(at:n, seq_len(at - 1))]
    curves <- lapply(contour, function(pc) pc$P)
    lines <- vapply(curves, bool_is_line, NA)
    # Skia's path writer joins consecutive collinear lines into one.
    k <- 2
    while (k <= length(curves)) {
      a <- curves[[k - 1]]
      b <- curves[[k]]
      if (lines[k - 1] && lines[k]) {
        u <- a[4, ] - a[1, ]
        v <- b[4, ] - b[1, ]
        if (abs(u[1] * v[2] - u[2] * v[1]) < 1e-9 * sqrt(sum(u^2) * sum(v^2)) && sum(u * v) > 0) {
          curves[[k - 1]] <- rbind(a[1, ], a[1, ], b[4, ], b[4, ])
          curves[[k]] <- NULL
          lines <- lines[-k]
          next
        }
      }
      k <- k + 1
    }
    n <- length(curves)
    # Skia writes straight pieces as lines, which add_line_to() turns into
    # cubics with handles at a third and two thirds.
    curves[lines] <- lapply(curves[lines], function(P) {
      rbind(P[1, ], interpolate(P[1, ], P[4, ], 1 / 3), interpolate(P[1, ], P[4, ], 2 / 3), P[4, ])
    })
    # Skia draws every piece and closes with a line of zero length. When
    # pathops moves the start to an input point, a last straight piece
    # becomes the implied closing line instead.
    if (!(lines[n] && moved)) {
      p <- curves[[1]][1, ]
      curves[[n + 1]] <- rbind(p, p, p, p)
    }
    out[[length(out) + 1]] <- cbind(do.call(rbind, curves), 0)
  }
  pts <- do.call(rbind, out)
  dimnames(pts) <- NULL
  pts
}

bool_input_starts <- function(...) {
  s <- do.call(c, lapply(list(...), function(sh) lapply(sh, function(segs) attr(segs, "start") %||% segs[[1]][1, ])))
  if (!length(s)) return(matrix(0, 0, 2))
  do.call(rbind, s)
}


#' Boolean operations on VMobjects
#'
#' `Union()` merges two or more shapes, `Intersection()` keeps the region they
#' all share, `Difference()` removes `clip` from `subject` and `Exclusion()`
#' keeps the region covered by exactly one of the two. As upstream's
#' skia-pathops result, the outline is made of pieces of the input curves,
#' cut where they cross.
#'
#' @param ... For `Union()` and `Intersection()`: two or more VMobjects, then
#'   named style arguments passed to [VMobject()]. For `Difference()` and
#'   `Exclusion()`: named style arguments.
#' @param subject,clip The VMobjects to subtract or exclude.
#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @name boolean_ops
#' @examples
#' sq <- Square(color = RED, fill_opacity = 1)$move_to(c(-2, 0, 0))
#' cr <- Circle(color = BLUE, fill_opacity = 1)$move_to(c(-1.3, 0.7, 0))
#' un <- Union(sq, cr, color = GREEN, fill_opacity = 1)$move_to(c(1.5, 0.3, 0))
NULL

#' @rdname boolean_ops
#' @format NULL
#' @usage NULL
#' @export
BooleanOpsClass <- R6::R6Class("BooleanOps", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    # The cubic segments of a VMobject by subpath, as upstream's
    # _convert_vmobject_to_skia_path draws them.
    convert_vmobject_to_skia_path = function(vmobject) bool_segments(vmobject),
    # Append a result's contours (a list of pieces) to this VMobject.
    convert_skia_path_to_vmobject = function(contours, starts) {
      pts <- bool_write(contours, starts)
      if (nrow(pts)) self$append_points(pts)
      invisible(self)
    },
    run_op = function(shapes, op) {
      starts <- do.call(bool_input_starts, shapes)
      contours <- bool_op(shapes, op)
      self$convert_skia_path_to_vmobject(contours, starts)
    }
  )
)

# Split `...` into unnamed mobjects and named keyword arguments.
boolean_ops_split_args <- function(args) {
  nm <- names(args) %||% rep("", length(args))
  list(mobs = args[nm == ""], kwargs = args[nm != ""])
}

#' @rdname boolean_ops
#' @format NULL
#' @usage NULL
#' @export
UnionClass <- R6::R6Class("Union", inherit = BooleanOpsClass, lock_objects = FALSE,
  public = list(
    initialize = function(...) {
      a <- boolean_ops_split_args(list(...))
      if (length(a$mobs) < 2) stop("At least 2 mobjects needed for Union.", call. = FALSE)
      do.call(super$initialize, a$kwargs)
      self$run_op(lapply(a$mobs, self$convert_vmobject_to_skia_path), "union")
    }
  )
)

#' @rdname boolean_ops
#' @export
Union <- constructor(UnionClass)
#' @rdname boolean_ops
#' @format NULL
#' @usage NULL
#' @export
IntersectionClass <- R6::R6Class("Intersection", inherit = BooleanOpsClass, lock_objects = FALSE,
  public = list(
    initialize = function(...) {
      a <- boolean_ops_split_args(list(...))
      if (length(a$mobs) < 2) stop("At least 2 mobjects needed for Intersection.", call. = FALSE)
      do.call(super$initialize, a$kwargs)
      # Upstream intersects the first two, then the result with each next one.
      result <- VMobject()
      shape <- self$convert_vmobject_to_skia_path(a$mobs[[1]])
      for (k in seq_along(a$mobs)[-1]) {
        step <- BooleanOpsClass$new()
        step$run_op(list(shape, self$convert_vmobject_to_skia_path(a$mobs[[k]])), "intersection")
        shape <- bool_segments(step)
        result <- step
      }
      if (nrow(result$points)) self$append_points(result$points)
    }
  )
)

#' @rdname boolean_ops
#' @export
Intersection <- constructor(IntersectionClass)
#' @rdname boolean_ops
#' @format NULL
#' @usage NULL
#' @export
DifferenceClass <- R6::R6Class("Difference", inherit = BooleanOpsClass, lock_objects = FALSE,
  public = list(
    initialize = function(subject, clip, ...) {
      super$initialize(...)
      self$run_op(list(self$convert_vmobject_to_skia_path(subject), self$convert_vmobject_to_skia_path(clip)),
                  "difference")
    }
  )
)

#' @rdname boolean_ops
#' @export
Difference <- constructor(DifferenceClass)
#' @rdname boolean_ops
#' @format NULL
#' @usage NULL
#' @export
ExclusionClass <- R6::R6Class("Exclusion", inherit = BooleanOpsClass, lock_objects = FALSE,
  public = list(
    initialize = function(subject, clip, ...) {
      super$initialize(...)
      self$run_op(list(self$convert_vmobject_to_skia_path(subject), self$convert_vmobject_to_skia_path(clip)),
                  "xor")
    }
  )
)

#' @rdname boolean_ops
#' @export
Exclusion <- constructor(ExclusionClass)
