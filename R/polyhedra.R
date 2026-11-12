# Polyhedra. Ported from manim/mobject/three_d/polyhedra.py.

#' @title Polyhedra
#' @description `Polyhedron(vertex_coords, faces_list)` builds a polyhedron
#'   from vertex coordinates (a matrix or list of points) and faces given as
#'   vectors of 1 based vertex indices, like the OFF file format. The faces
#'   are in `$faces` (a [VGroup()] of [Polygon()]s) and the vertices and
#'   edges in `$graph`, a [Graph()]: `graph[i]` (or `graph$vertices[[i]]`) is
#'   vertex `i`, a [Dot3D()]. Moving a vertex moves the faces with it
#'   (through an updater).
#'
#'   `Tetrahedron()`, `Octahedron()`, `Icosahedron()` and `Dodecahedron()` are
#'   the platonic solids; `ConvexHull3D()` is the convex hull of points.
#' @param vertex_coords Vertex coordinates.
#' @param faces_list List of integer vectors of vertex indices (1 based).
#' @param faces_config List of [Polygon()] arguments for the faces; the
#'   default is `fill_opacity = 0.5, shade_in_3d = TRUE`.
#' @param graph_config List with `vertex_type` (default [Dot3D()]),
#'   `vertex_config`, `edge_type` (default [Line()]) and `edge_config`
#'   (default invisible edges).
#' @param edge_length Edge length of the platonic solid.
#' @param tolerance Coplanarity tolerance of the hull.
#' @param ... For `ConvexHull3D()`, the points (then named arguments for
#'   `Polyhedron()`); otherwise passed to `Polyhedron()`.
#' @name polyhedra
#' @examples
#' pyramid <- Polyhedron(
#'   rbind(c(1, 1, 0), c(1, -1, 0), c(-1, -1, 0), c(-1, 1, 0), c(0, 0, 2)),
#'   list(c(1, 2, 5), c(2, 3, 5), c(3, 4, 5), c(4, 1, 5), c(1, 2, 3, 4))
#' )
#' \donttest{
#' oct <- Octahedron(edge_length = 3)
#' oct$graph[1]$set_color(RED)
#' oct$faces[3]$set_color(YELLOW)
#' }
NULL

#' @rdname polyhedra
#' @format NULL
#' @usage NULL
#' @export
PolyhedronClass <- R6::R6Class("Polyhedron", inherit = VGroupClass, lock_objects = FALSE,
  public = list(
    faces_config = NULL,
    graph_config = NULL,
    vertex_coords = NULL,
    vertex_indices = NULL,
    layout = NULL,
    faces_list = NULL,
    face_coords = NULL,
    edges = NULL,
    faces = NULL,
    graph = NULL,
    initialize = function(vertex_coords, faces_list, faces_config = list(), graph_config = list()) {
      super$initialize()
      self$faces_config <- utils::modifyList(list(fill_opacity = 0.5, shade_in_3d = TRUE), faces_config)
      self$graph_config <- utils::modifyList(
        list(vertex_type = Dot3D, edge_config = list(stroke_opacity = 0)), graph_config)
      self$vertex_coords <- as_points(vertex_coords)
      self$vertex_indices <- seq_len(nrow(self$vertex_coords))
      self$layout <- stats::setNames(lapply(self$vertex_indices, function(i) self$vertex_coords[i, ]),
                                     self$vertex_indices)
      self$faces_list <- lapply(faces_list, as.integer)
      self$face_coords <- lapply(self$faces_list, function(f) self$vertex_coords[f, , drop = FALSE])
      self$edges <- self$get_edges(self$faces_list)
      self$faces <- self$create_faces(self$face_coords)
      self$graph <- do.call(Graph, c(list(self$vertex_indices, self$edges, layout = self$layout), self$graph_config))
      self$add(self$faces, self$graph)
      self$add_updater(function(m) m$update_faces())
    },
    # Cyclic pairs of each face, each undirected edge once (upstream passes
    # both directions of a shared edge to Graph).
    get_edges = function(faces_list) {
      pairs <- do.call(rbind, lapply(faces_list, function(f) cbind(f, c(f[-1], f[1]))))
      key <- paste(pmin(pairs[, 1], pairs[, 2]), pmax(pairs[, 1], pairs[, 2]))
      pairs <- pairs[!duplicated(key), , drop = FALSE]
      lapply(seq_len(nrow(pairs)), function(i) unname(pairs[i, ]))
    },
    create_faces = function(face_coords) {
      VGroup(lapply(face_coords, function(fc) do.call(Polygon, c(list(fc), self$faces_config))))
    },
    # Updater: keep the faces on the current vertex positions. Equivalent to
    # upstream's match_points with freshly built polygons, without building them.
    update_faces = function() {
      coords <- self$extract_face_coords()
      for (i in seq_along(coords)) {
        fc <- coords[[i]]
        self$faces$submobjects[[i]]$set_points_as_corners(rbind(fc, fc[1, ]))
      }
      invisible(self)
    },
    extract_face_coords = function() {
      layout <- do.call(rbind, lapply(self$graph$vertices, function(v) v$get_center()))
      lapply(self$faces_list, function(f) layout[f, , drop = FALSE])
    }
  )
)

#' @rdname polyhedra
#' @export
Polyhedron <- constructor(PolyhedronClass)
#' @rdname polyhedra
#' @export
Tetrahedron <- function(edge_length = 1, ...) {
  unit <- edge_length * sqrt(2) / 4
  Polyhedron(
    rbind(c(unit, unit, unit), c(unit, -unit, -unit), c(-unit, unit, -unit), c(-unit, -unit, unit)),
    lapply(list(c(0, 1, 2), c(3, 0, 2), c(0, 1, 3), c(3, 1, 2)), `+`, 1),
    ...
  )
}

#' @rdname polyhedra
#' @export
Octahedron <- function(edge_length = 1, ...) {
  unit <- edge_length * sqrt(2) / 2
  Polyhedron(
    rbind(c(unit, 0, 0), c(-unit, 0, 0), c(0, unit, 0), c(0, -unit, 0), c(0, 0, unit), c(0, 0, -unit)),
    lapply(list(c(2, 4, 1), c(0, 4, 2), c(4, 3, 0), c(1, 3, 4), c(3, 5, 0), c(1, 5, 3), c(2, 5, 1), c(0, 5, 2)),
           `+`, 1),
    ...
  )
}

#' @rdname polyhedra
#' @export
Icosahedron <- function(edge_length = 1, ...) {
  a <- edge_length * ((1 + sqrt(5)) / 4)
  b <- edge_length * (1 / 2)
  Polyhedron(
    rbind(c(0, b, a), c(0, -b, a), c(0, b, -a), c(0, -b, -a), c(b, a, 0), c(b, -a, 0), c(-b, a, 0), c(-b, -a, 0),
          c(a, 0, b), c(a, 0, -b), c(-a, 0, b), c(-a, 0, -b)),
    lapply(list(c(1, 8, 0), c(1, 5, 7), c(8, 5, 1), c(7, 3, 5), c(5, 9, 3), c(8, 9, 5), c(3, 2, 9), c(9, 4, 2),
                c(8, 4, 9), c(0, 4, 8), c(6, 4, 0), c(6, 2, 4), c(11, 2, 6), c(3, 11, 2), c(0, 6, 10), c(10, 1, 0),
                c(10, 7, 1), c(11, 7, 3), c(10, 11, 7), c(10, 11, 6)), `+`, 1),
    ...
  )
}

#' @rdname polyhedra
#' @export
Dodecahedron <- function(edge_length = 1, ...) {
  a <- edge_length * ((1 + sqrt(5)) / 4)
  b <- edge_length * ((3 + sqrt(5)) / 4)
  c0 <- edge_length * (1 / 2)
  Polyhedron(
    rbind(c(a, a, a), c(a, a, -a), c(a, -a, a), c(a, -a, -a), c(-a, a, a), c(-a, a, -a), c(-a, -a, a),
          c(-a, -a, -a), c(0, c0, b), c(0, c0, -b), c(0, -c0, -b), c(0, -c0, b), c(c0, b, 0), c(-c0, b, 0),
          c(c0, -b, 0), c(-c0, -b, 0), c(b, 0, c0), c(-b, 0, c0), c(b, 0, -c0), c(-b, 0, -c0)),
    lapply(list(c(18, 16, 0, 12, 1), c(3, 18, 16, 2, 14), c(3, 10, 9, 1, 18), c(1, 9, 5, 13, 12),
                c(0, 8, 4, 13, 12), c(2, 16, 0, 8, 11), c(4, 17, 6, 11, 8), c(17, 19, 5, 13, 4),
                c(19, 7, 15, 6, 17), c(6, 15, 14, 2, 11), c(19, 5, 9, 10, 7), c(7, 10, 3, 14, 15)), `+`, 1),
    ...
  )
}

# Faces of the 3D convex hull of the rows of `P`, each as hull vertex indices
# ordered counterclockwise seen from outside. Coplanar hull points form one
# polygonal face.
# Limitation: brute force O(n^4) over point triples instead of upstream's
# QuickHull; fine for the tens of points hulls are drawn with, port
# utils/qhull.py if large clouds are needed.
convex_hull_3d_faces <- function(P, tol = 1e-5) {
  n <- nrow(P)
  if (n < 4) stop("ConvexHull3D needs at least 4 points.", call. = FALSE)
  faces <- list()
  seen <- character()
  for (i in 1:(n - 2)) for (j in (i + 1):(n - 1)) for (k in (j + 1):n) {
    nv <- cross(P[j, ] - P[i, ], P[k, ] - P[i, ])
    nn <- sqrt(sum(nv^2))
    if (nn < tol) next
    nv <- nv / nn
    d <- drop(P %*% nv) - sum(nv * P[i, ])
    if (all(d <= tol)) {
      out <- nv
    } else if (all(d >= -tol)) {
      out <- -nv
    } else {
      next
    }
    on_plane <- which(abs(d) <= tol)
    key <- paste(on_plane, collapse = ",")
    if (key %in% seen) next
    seen <- c(seen, key)
    # 2D hull of the coplanar points, in a basis (u, w) with w = out x u.
    u <- normalize(P[j, ] - P[i, ])
    w <- cross(out, u)
    q <- sweep(P[on_plane, , drop = FALSE], 2, P[i, ])
    hull <- grDevices::chull(drop(q %*% u), drop(q %*% w))
    faces[[length(faces) + 1]] <- on_plane[rev(hull)]
  }
  faces
}

#' @rdname polyhedra
#' @export
ConvexHull3D <- function(..., tolerance = 1e-5) {
  args <- list(...)
  nm <- names(args) %||% rep("", length(args))
  pts <- args[nm == ""]
  P <- as_points(if (length(pts) == 1 && is.matrix(pts[[1]])) pts[[1]] else pts)
  faces <- convex_hull_3d_faces(P, tolerance)
  used <- sort(unique(unlist(faces)))
  remap <- match(seq_len(nrow(P)), used)
  do.call(Polyhedron, c(list(P[used, , drop = FALSE], lapply(faces, function(f) remap[f])), args[nm != ""]))
}
