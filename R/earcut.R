# Polygon triangulation: manim.utils.space_ops.earclip_triangulation and the
# part of mapbox's earcut (earcut.hpp 2.2.4, used by the mapbox_earcut Python
# package) that it calls.

#' Triangulate a polygon with holes
#'
#' Port of manim's `earclip_triangulation()`. The rings (the outer boundary
#' and its holes) are first joined into one ring by bridges between nearby
#' vertices, then that ring is cut into triangles by ear clipping (mapbox's
#' earcut algorithm).
#'
#' Indices are 1 based here: the result indexes rows of `verts` (upstream
#' returns 0 based indices). `ring_ends` holds, for each ring, the number of
#' vertices up to and including that ring, which is both upstream's
#' exclusive 0 based end and the 1 based row of the ring's last vertex.
#'
#' The ring lookup accepts a bridge to the last vertex of a hole. manim 0.20.1
#' raises "Could not find a ring to attach" there; newer upstream versions
#' fix it the same way. Otherwise the result matches upstream index for
#' index.
#'
#' @param verts Vertices, an n x 2 or n x 3 matrix (one vertex per row). Only
#'   x and y are used for the triangulation.
#' @param ring_ends Cumulative vertex counts of the rings, for example
#'   `c(4, 8)` for a square with a square hole after it.
#' @return An integer vector of row indices of `verts`, three per triangle;
#'   `matrix(result, ncol = 3, byrow = TRUE)` gives one triangle per row.
#' @export
#' @examples
#' outer <- rbind(c(0, 0, 0), c(6, 0, 0), c(6, 4, 0), c(0, 4, 0))
#' hole <- rbind(c(1, 1, 0), c(1, 3, 0), c(2, 3, 0), c(2, 1, 0))
#' tri <- earclip_triangulation(rbind(outer, hole), c(4, 8))
#' matrix(tri, ncol = 3, byrow = TRUE)
earclip_triangulation <- function(verts, ring_ends) {
  verts <- as.matrix(verts)
  ring_ends <- as.integer(ring_ends)
  # Work with 0 based vertex numbers like upstream; row of vertex v is v + 1.
  starts <- c(0L, ring_ends[-length(ring_ends)])
  rings <- lapply(seq_along(ring_ends), function(k) seq.int(starts[k], length.out = ring_ends[k] - starts[k]))
  attached <- rings[1]
  detached <- rings[-1]
  link <- rep(NA_integer_, nrow(verts))
  dist2 <- function(v, p) {
    d <- verts[v + 1, , drop = FALSE] - matrix(p, length(v), ncol(verts), byrow = TRUE)
    rowSums(d * d)
  }
  # Connect the holes to the rings attached so far, each through the pair of
  # vertices closest to each other (not already used by a connection).
  while (length(detached)) {
    i_range <- unlist(attached)
    i_range <- i_range[is.na(link[i_range + 1])]
    j_range <- unlist(detached)
    j_range <- j_range[is.na(link[j_range + 1])]
    tmp <- midpoint(verts[j_range[1] + 1, ], verts[j_range[length(j_range) %/% 2 + 1] + 1, ])
    i <- i_range[which.min(dist2(i_range, tmp))]
    j <- j_range[which.min(dist2(j_range, verts[i + 1, ]))]
    i <- i_range[which.min(dist2(i_range, verts[j + 1, ]))]
    link[i + 1] <- j
    link[j + 1] <- i
    k <- which(vapply(detached, function(r) r[1] <= j && j <= r[length(r)], logical(1)))[1]
    if (is.na(k)) stop("Could not find a ring to attach.", call. = FALSE)
    attached <- c(attached, detached[k])
    detached <- detached[-k]
  }
  # Walk around the joined polygon, crossing each connection.
  after <- integer(0)
  end0 <- 0L
  for (end1 in ring_ends) {
    after <- c(after, seq_len(end1 - end0 - 1) + end0, end0)
    end0 <- end1
  }
  walk <- integer(0)
  i <- 0L
  for (step in seq_len(nrow(verts) + length(ring_ends) - 1)) {
    if (!is.na(link[i + 1])) {
      j <- link[i + 1]
      walk <- c(walk, i, j)
      i <- after[j + 1]
    } else {
      walk <- c(walk, i)
      i <- after[i + 1]
    }
    if (i == 0) break
  }
  # Upstream calls mapbox_earcut's triangulate_float32, so coordinates are
  # rounded to single precision first; near ties then break the same way.
  ring <- verts[walk + 1, 1:2, drop = FALSE]
  ring[] <- readBin(writeBin(as.vector(ring), raw(), size = 4), "double", length(ring), size = 4)
  meta <- earcut_ring(ring)
  walk[meta] + 1L
}

# Ear clipping of one ring given as an n x 2 matrix, following earcut.hpp
# 2.2.4 step by step so the triangles and their order match. Nodes of the
# circular doubly linked list live in parallel vectors: coordinates X, Y,
# vertex row I, and links P (previous) and N (next). Removing a node keeps
# its own links, as earcut relies on. Returns 1 based rows of `xy`, three per
# triangle.
# Limitation: earcut's z-order hash only speeds up the ear test for rings above
# 80 points (the result is the same), so it is skipped; the ear test is
# O(n) per candidate, O(n^2) per polygon.
earcut_ring <- function(xy) {
  n <- nrow(xy)
  if (n < 3) return(integer())
  cap <- 3 * n + 4
  X <- numeric(cap)
  Y <- numeric(cap)
  I <- integer(cap)
  P <- integer(cap)
  N <- integer(cap)
  used <- 0L
  tris <- integer(0)

  new_node <- function(i, x, y) {
    used <<- used + 1L
    if (used > length(X)) {
      X <<- c(X, numeric(cap)); Y <<- c(Y, numeric(cap)); I <<- c(I, integer(cap))
      P <<- c(P, integer(cap)); N <<- c(N, integer(cap))
    }
    X[used] <<- x
    Y[used] <<- y
    I[used] <<- i
    used
  }
  insert_node <- function(i, last) {
    p <- new_node(i, xy[i, 1], xy[i, 2])
    if (is.null(last)) {
      P[p] <<- p
      N[p] <<- p
    } else {
      N[p] <<- N[last]
      P[p] <<- last
      P[N[last]] <<- p
      N[last] <<- p
    }
    p
  }
  remove_node <- function(p) {
    P[N[p]] <<- P[p]
    N[P[p]] <<- N[p]
  }
  area <- function(p, q, r) (Y[q] - Y[p]) * (X[r] - X[q]) - (X[q] - X[p]) * (Y[r] - Y[q])
  equals <- function(p, q) X[p] == X[q] && Y[p] == Y[q]
  point_in_triangle <- function(a, b, c, p) {
    (X[c] - X[p]) * (Y[a] - Y[p]) >= (X[a] - X[p]) * (Y[c] - Y[p]) &&
      (X[a] - X[p]) * (Y[b] - Y[p]) >= (X[b] - X[p]) * (Y[a] - Y[p]) &&
      (X[b] - X[p]) * (Y[c] - Y[p]) >= (X[c] - X[p]) * (Y[b] - Y[p])
  }
  on_segment <- function(p, q, r) {
    X[q] <= max(X[p], X[r]) && X[q] >= min(X[p], X[r]) && Y[q] <= max(Y[p], Y[r]) && Y[q] >= min(Y[p], Y[r])
  }
  intersects <- function(p1, q1, p2, q2) {
    o1 <- sign(area(p1, q1, p2))
    o2 <- sign(area(p1, q1, q2))
    o3 <- sign(area(p2, q2, p1))
    o4 <- sign(area(p2, q2, q1))
    if (o1 != o2 && o3 != o4) return(TRUE)
    (o1 == 0 && on_segment(p1, p2, q1)) || (o2 == 0 && on_segment(p1, q2, q1)) ||
      (o3 == 0 && on_segment(p2, p1, q2)) || (o4 == 0 && on_segment(p2, q1, q2))
  }
  intersects_polygon <- function(a, b) {
    p <- a
    repeat {
      if (I[p] != I[a] && I[N[p]] != I[a] && I[p] != I[b] && I[N[p]] != I[b] && intersects(p, N[p], a, b)) {
        return(TRUE)
      }
      p <- N[p]
      if (p == a) return(FALSE)
    }
  }
  locally_inside <- function(a, b) {
    if (area(P[a], a, N[a]) < 0) area(a, b, N[a]) >= 0 && area(a, P[a], b) >= 0
    else area(a, b, P[a]) < 0 || area(a, N[a], b) < 0
  }
  middle_inside <- function(a, b) {
    p <- a
    inside <- FALSE
    px <- (X[a] + X[b]) / 2
    py <- (Y[a] + Y[b]) / 2
    repeat {
      q <- N[p]
      if (((Y[p] > py) != (Y[q] > py)) && Y[q] != Y[p] &&
          (px < (X[q] - X[p]) * (py - Y[p]) / (Y[q] - Y[p]) + X[p])) inside <- !inside
      p <- q
      if (p == a) return(inside)
    }
  }
  is_valid_diagonal <- function(a, b) {
    I[N[a]] != I[b] && I[P[a]] != I[b] && !intersects_polygon(a, b) &&
      ((locally_inside(a, b) && locally_inside(b, a) && middle_inside(a, b) &&
          (area(P[a], a, P[b]) != 0 || area(a, P[b], b) != 0)) ||
         (equals(a, b) && area(P[a], a, N[a]) > 0 && area(P[b], b, N[b]) > 0))
  }
  split_polygon <- function(a, b) {
    a2 <- new_node(I[a], X[a], Y[a])
    b2 <- new_node(I[b], X[b], Y[b])
    an <- N[a]
    bp <- P[b]
    N[a] <<- b
    P[b] <<- a
    N[a2] <<- an
    P[an] <<- a2
    N[b2] <<- a2
    P[a2] <<- b2
    N[bp] <<- b2
    P[b2] <<- bp
    b2
  }
  filter_points <- function(start, end = start) {
    p <- start
    repeat {
      again <- FALSE
      if (equals(p, N[p]) || area(P[p], p, N[p]) == 0) {
        remove_node(p)
        p <- end <- P[p]
        if (p == N[p]) break
        again <- TRUE
      } else {
        p <- N[p]
      }
      if (!again && p == end) break
    }
    end
  }
  is_ear <- function(ear) {
    a <- P[ear]
    c <- N[ear]
    if (area(a, ear, c) >= 0) return(FALSE)
    p <- N[c]
    while (p != a) {
      if (point_in_triangle(a, ear, c, p) && area(P[p], p, N[p]) >= 0) return(FALSE)
      p <- N[p]
    }
    TRUE
  }
  cure_local_intersections <- function(start) {
    p <- start
    repeat {
      a <- P[p]
      b <- N[N[p]]
      if (!equals(a, b) && intersects(a, p, N[p], b) && locally_inside(a, b) && locally_inside(b, a)) {
        tris <<- c(tris, I[a], I[p], I[b])
        remove_node(p)
        remove_node(N[p])
        p <- start <- b
      }
      p <- N[p]
      if (p == start) break
    }
    filter_points(p)
  }
  split_earcut <- function(start) {
    a <- start
    repeat {
      b <- N[N[a]]
      while (b != P[a]) {
        if (I[a] != I[b] && is_valid_diagonal(a, b)) {
          c <- split_polygon(a, b)
          a <- filter_points(a, N[a])
          c <- filter_points(c, N[c])
          earcut_linked(a)
          earcut_linked(c)
          return(invisible())
        }
        b <- N[b]
      }
      a <- N[a]
      if (a == start) return(invisible())
    }
  }
  earcut_linked <- function(ear, pass = 0) {
    stop_node <- ear
    while (P[ear] != N[ear]) {
      prev <- P[ear]
      nxt <- N[ear]
      if (is_ear(ear)) {
        tris <<- c(tris, I[prev], I[ear], I[nxt])
        remove_node(ear)
        # Skipping the next vertex leads to fewer sliver triangles.
        ear <- stop_node <- N[nxt]
        next
      }
      ear <- nxt
      if (ear == stop_node) {
        if (pass == 0) {
          earcut_linked(filter_points(ear), 1)
        } else if (pass == 1) {
          earcut_linked(cure_local_intersections(filter_points(ear)), 2)
        } else {
          split_earcut(ear)
        }
        break
      }
    }
  }

  # Link the points counterclockwise (earcut's "clockwise" in its y down
  # convention), as earcut does for the outer ring.
  j <- c(n, seq_len(n - 1))
  s <- sum((xy[j, 1] - xy[, 1]) * (xy[, 2] + xy[j, 2]))
  last <- NULL
  for (i in if (s > 0) seq_len(n) else rev(seq_len(n))) last <- insert_node(i, last)
  if (equals(last, N[last])) {
    remove_node(last)
    last <- N[last]
  }
  if (P[last] == N[last]) return(integer())
  earcut_linked(last)
  tris
}
