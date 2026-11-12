# QuickHull convex hull in any dimension. Ported from manim/utils/qhull.py.

# The facets of the convex hull of the rows of `points`: a list of vectors
# of `ncol(points)` row indices each (edges in 2D, triangles in 3D). A point
# closer than `tolerance` to a facet's plane is not outside it, so points
# on a face are not hull vertices unless they start the hull.
# Upstream keeps facets and their sides in sets, so the order of its facets
# (and, for points on a common face, which triangles it makes) changes from
# run to run; here the order is fixed.
quick_hull <- function(points, tolerance = 1e-5) {
  n <- nrow(points)
  d <- ncol(points)
  if (d == 0 || n < d + 1) stop("Not enough points supplied to build Convex Hull!", call. = FALSE)
  if (d == 1) stop("The Convex Hull of 1D data is its min-max!", call. = FALSE)
  matrix_rank <- function(m) {
    sv <- svd(m, nu = 0, nv = 0)$d
    sum(sv > max(sv) * max(dim(m)) * .Machine$double.eps)
  }
  # A deterministic, affinely independent initial simplex.
  simplex <- 1L
  for (i in seq_len(n)[-1]) {
    rest <- points[c(simplex[-1], i), , drop = FALSE]
    if (matrix_rank(sweep(rest, 2, points[1, ])) == length(simplex)) {
      simplex <- c(simplex, i)
      if (length(simplex) == d + 1) break
    }
  }
  if (length(simplex) < d + 1) stop("The points do not span the full coordinate dimension.", call. = FALSE)
  internal <- colMeans(points[simplex, , drop = FALSE])

  facets <- list()
  removed <- character()
  unclaimed <- seq_len(n)
  neighbors <- new.env(hash = TRUE, parent = emptyenv())
  side_key <- function(v) paste(sort(v), collapse = ",")
  add_facet <- function(v) {
    co <- points[v, , drop = FALSE]
    center <- colMeans(co)
    normal <- svd(sweep(co, 2, center), nu = 0, nv = d)$v[, d]
    normal <- normal / sqrt(sum(normal^2))
    if (sum(normal * (center - internal)) < 0) normal <- -normal
    # The unclaimed points outside the facet, and the farthest one.
    outside <- integer()
    eye <- NA_integer_
    if (length(unclaimed)) {
      proj <- drop(sweep(points[unclaimed, , drop = FALSE], 2, center) %*% normal)
      far <- which.max(proj)
      if (proj[far] > tolerance) eye <- unclaimed[far]
      mask <- proj > tolerance
      outside <- unclaimed[mask]
      unclaimed <<- unclaimed[!mask]
    }
    id <- length(facets) + 1
    facets[[id]] <<- list(v = v, key = side_key(v), center = center, normal = normal, outside = outside, eye = eye)
    for (k in seq_along(v)) {
      key <- side_key(v[-k])
      neighbors[[key]] <- c(neighbors[[key]], id)
    }
  }
  for (k in seq_along(simplex)) add_facet(simplex[-k])

  # The facets visible from `eye`, starting at facet `id`, and the sides
  # where they meet the facets that are not.
  horizon <- integer()
  boundary <- list()
  visit <- function(eye, id) {
    facet <- facets[[id]]
    if (!(sum(facet$normal * (points[eye, ] - facet$center)) > 0)) return(FALSE)
    horizon <<- c(horizon, id)
    for (k in seq_along(facet$v)) {
      side <- facet$v[-k]
      neighbor <- setdiff(neighbors[[side_key(side)]], id)[1]
      if (!(neighbor %in% horizon) && !visit(eye, neighbor)) boundary[[length(boundary) + 1]] <<- side
    }
    TRUE
  }
  repeat {
    updated <- FALSE
    i <- 1
    # New facets join the end of the list and are visited in the same pass.
    while (i <= length(facets)) {
      facet <- facets[[i]]
      i <- i + 1
      if (facet$key %in% removed || is.na(facet$eye)) next
      updated <- TRUE
      horizon <- integer()
      boundary <- list()
      visit(facet$eye, i - 1)
      for (id in horizon) {
        gone <- facets[[id]]
        unclaimed <- c(unclaimed, gone$outside)
        removed <- c(removed, gone$key)
        for (k in seq_along(gone$v)) {
          key <- side_key(gone$v[-k])
          left <- setdiff(neighbors[[key]], id)
          if (length(left)) neighbors[[key]] <- left else rm(list = key, envir = neighbors)
        }
      }
      for (side in boundary) add_facet(c(side, facet$eye))
    }
    if (!updated) break
  }
  keys <- vapply(facets, function(f) f$key, "")
  keep <- !(keys %in% removed) & !duplicated(keys)
  lapply(facets[keep], function(f) f$v)
}
