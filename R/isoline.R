# Zero level curves of a function of two variables, on an adaptive quadtree.
# Ported from the isosurfaces Python package (Jared Hughes, MIT license),
# which upstream's ImplicitFunction uses: its plot_isoline(), following
# Manson and Schaefer, "Isosurfaces over simplicial partitions of
# multiresolution grids" (2010). Comparisons with a NaN value are false, as
# in Python.

iso_gt0 <- function(v) isTRUE(v > 0)

# A position with the value of the function there.
iso_point <- function(pos, fn) list(pos = pos, val = fn(pos))

iso_midpoint <- function(p1, p2, fn) iso_point((p1$pos + p2$pos) / 2, fn)

# The point of the segment p1 to p2 where a linear function with their
# values is zero.
iso_intersect_zero <- function(p1, p2, fn) {
  denom <- p1$val - p2$val
  iso_point((-p2$val / denom) * p1$pos + (p1$val / denom) * p2$pos, fn)
}

# Bisection between a positive and a nonpositive point. Returns the point
# and whether it is a zero (and not an asymptote, such as x = 0 of
# 1 / (x y) - 1).
iso_binary_search_zero <- function(p1, p2, fn, tol) {
  repeat {
    if (all(abs(p2$pos - p1$pos) < tol)) {
      pt <- iso_intersect_zero(p1, p2, fn)
      is_zero <- isTRUE(pt$val == 0) ||
        (isTRUE(sign(pt$val - p1$val) == sign(p2$val - pt$val)) && isTRUE(pt$val < 1e200))
      return(list(pt, is_zero))
    }
    mid <- iso_midpoint(p1, p2, fn)
    if (isTRUE(mid$val == 0)) return(list(mid, TRUE))
    if (iso_gt0(mid$val) == iso_gt0(p1$val)) p1 <- mid else p2 <- mid
  }
}

# The four corners of a cell: (min, min), (max, min), (min, max), (max, max).
iso_corners <- function(pmin, pmax, fn) {
  w <- pmax - pmin
  lapply(0:3, function(i) iso_point(c(pmin[1] + (i %% 2) * w[1], pmin[2] + (i %/% 2) * w[2]), fn))
}

iso_cell <- function(vertices, depth) {
  cell <- new.env(parent = emptyenv())
  cell$vertices <- vertices
  cell$depth <- depth
  cell$children <- list()
  cell
}

iso_should_descend <- function(cell, tol) {
  v <- cell$vertices
  if (all(v[[4]]$pos - v[[1]]$pos < 10 * tol)) return(FALSE)
  vals <- vapply(v, function(p) p$val, 0)
  if (all(is.nan(vals))) return(FALSE)
  if (any(is.nan(vals))) return(TRUE)
  any(sign(vals[-1]) != sign(vals[1]))
}

# Breadth first: cells split down to min_depth, then where the function
# changes sign, until there are max_cells leaves.
iso_build_tree <- function(fn, pmin, pmax, min_depth, max_cells, tol) {
  max_cells <- max(4^min_depth, max_cells)
  root <- iso_cell(iso_corners(pmin, pmax, fn), 0)
  queue <- list(root)
  head <- 1
  leaf_count <- 1
  while (head <= length(queue) && leaf_count < max_cells) {
    cell <- queue[[head]]
    head <- head + 1
    if (cell$depth < min_depth || iso_should_descend(cell, tol)) {
      v <- cell$vertices
      cell$children <- lapply(v, function(vertex) {
        iso_cell(iso_corners((v[[1]]$pos + vertex$pos) / 2, (v[[4]]$pos + vertex$pos) / 2, fn), cell$depth + 1)
      })
      queue <- c(queue, cell$children)
      leaf_count <- leaf_count + 3
    }
  }
  root
}

# Splits the leaves into triangles around the midpoints of their shared
# edges and links each triangle to the next one along the curve (positive
# values on the right).
iso_triangulate <- function(root, fn, tol) {
  triangles <- vector("list", 1024)
  n <- 0
  hanging <- new.env(hash = TRUE, parent = emptyenv())
  triangle <- function(a, b, c) {
    t <- new.env(parent = emptyenv())
    t$vertices <- list(a, b, c)
    t$nxt <- NULL
    t$bisect <- NULL
    t$prev <- NULL
    t$visited <- FALSE
    t
  }
  set_next <- function(t1, t2, vpos, vneg) {
    if (!(iso_gt0(vpos$val) && isTRUE(0 >= vneg$val))) return(invisible())
    found <- iso_binary_search_zero(vpos, vneg, fn, tol)
    if (!found[[2]]) return(invisible())
    t1$bisect <- found[[1]]
    t1$nxt <- t2
    t2$prev <- t1
  }
  # The next triangle of b, which shares its center (third vertex) with a
  # and c; an edge on the outside waits in `hanging` for the triangle of
  # the neighboring group.
  sandwich <- function(a, b, c) {
    x <- b$vertices[[1]]
    y <- b$vertices[[2]]
    center <- b$vertices[[3]]
    if (iso_gt0(center$val) && isTRUE(0 >= y$val)) set_next(b, c, center, y)
    if (iso_gt0(x$val) && isTRUE(0 >= center$val)) set_next(b, a, x, center)
    id <- paste(sprintf("%a", x$pos + y$pos), collapse = " ")
    up <- iso_gt0(y$val) && isTRUE(0 >= x$val)
    down <- isTRUE(y$val <= 0) && iso_gt0(x$val)
    if (!up && !down) return(invisible())
    other <- hanging[[id]]
    if (is.null(other)) {
      hanging[[id]] <- b
      return(invisible())
    }
    if (up) set_next(b, other, y, x) else set_next(other, b, x, y)
    rm(list = id, envir = hanging)
  }
  # Four triangles around `center`; a, b, c, d go clockwise.
  add_four <- function(a, b, c, d, center) {
    ts <- list(triangle(a, b, center), triangle(b, c, center), triangle(c, d, center), triangle(d, a, center))
    for (i in 0:3) sandwich(ts[[i + 1]], ts[[(i + 1) %% 4 + 1]], ts[[(i + 2) %% 4 + 1]])
    if (n + 4 > length(triangles)) length(triangles) <<- 2 * length(triangles)
    triangles[n + 1:4] <<- ts
    n <<- n + 4
  }
  edge_dual <- function(p1, p2) {
    if (iso_gt0(p1$val) != iso_gt0(p2$val)) return(iso_midpoint(p1, p2, fn))
    dt <- 0.01
    df1 <- fn(p1$pos * (1 - dt) + p2$pos * dt)
    df2 <- fn(p1$pos * dt + p2$pos * (1 - dt))
    if (iso_gt0(df1) == iso_gt0(df2)) return(iso_midpoint(p1, p2, fn))
    iso_intersect_zero(list(pos = p1$pos, val = df1), list(pos = p2$pos, val = df2), fn)
  }
  face_dual <- function(cell) iso_midpoint(cell$vertices[[1]], cell$vertices[[4]], fn)
  # Triangles across the edge between a and b: b is to the right of a
  # (row) or above it.
  crossing <- function(a, b, row) {
    ia <- if (row) c(2, 4) else c(3, 4)
    ib <- if (row) c(1, 3) else c(1, 2)
    has_a <- length(a$children) > 0
    has_b <- length(b$children) > 0
    if (has_a && has_b) {
      crossing(a$children[[ia[1]]], b$children[[ib[1]]], row)
      crossing(a$children[[ia[2]]], b$children[[ib[2]]], row)
    } else if (has_a) {
      crossing(a$children[[ia[1]]], b, row)
      crossing(a$children[[ia[2]]], b, row)
    } else if (has_b) {
      crossing(a, b$children[[ib[1]]], row)
      crossing(a, b$children[[ib[2]]], row)
    } else {
      face_a <- face_dual(a)
      face_b <- face_dual(b)
      # The shared edge, taken from the smaller cell.
      if (a$depth < b$depth) {
        p <- b$vertices[[if (row) 3 else 1]]
        q <- b$vertices[[if (row) 1 else 2]]
      } else {
        p <- a$vertices[[if (row) 4 else 3]]
        q <- a$vertices[[if (row) 2 else 4]]
      }
      add_four(p, face_b, q, face_a, edge_dual(p, q))
    }
  }
  inside <- function(cell) {
    ch <- cell$children
    if (!length(ch)) return(invisible())
    for (child in ch) inside(child)
    crossing(ch[[1]], ch[[2]], TRUE)
    crossing(ch[[3]], ch[[4]], TRUE)
    crossing(ch[[1]], ch[[3]], FALSE)
    crossing(ch[[2]], ch[[4]], FALSE)
  }
  inside(root)
  triangles[seq_len(n)]
}

# Follows the links between the triangles; one matrix of points per curve.
iso_trace <- function(triangles) {
  curves <- list()
  for (t in triangles) {
    if (t$visited || is.null(t$nxt)) next
    start <- t
    closed <- FALSE
    while (!is.null(t$prev)) {
      t <- t$prev
      if (identical(t, start)) {
        closed <- TRUE
        break
      }
    }
    pts <- list()
    while (!is.null(t) && !t$visited) {
      if (!is.null(t$bisect)) pts[[length(pts) + 1]] <- t$bisect$pos
      t$visited <- TRUE
      t <- t$nxt
    }
    if (!length(pts)) next
    if (closed) pts[[length(pts) + 1]] <- pts[[1]]
    curves[[length(curves) + 1]] <- do.call(rbind, pts)
  }
  curves
}

# The curves fn(c(x, y)) = 0 inside the rectangle from pmin to pmax, as a
# list of two column matrices of points.
plot_isoline <- function(fn, pmin, pmax, min_depth = 5, max_quads = 10000, tol = NULL) {
  tol <- tol %||% ((pmax - pmin) / 1000)
  root <- iso_build_tree(fn, pmin, pmax, min_depth, max_quads, tol)
  iso_trace(iso_triangulate(root, fn, tol))
}
