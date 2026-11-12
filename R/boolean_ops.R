# Boolean operations for two dimensional VMobjects.
# Ported from manim/mobject/geometry/boolean_ops.py. Upstream runs skia-pathops
# on the Bezier paths. Here every curve is flattened to a fine polygon, the
# polygons are clipped with the 'polyclip' package (a Suggests dependency), and
# the resulting contours become straight segment subpaths of a VMobject.

boolean_ops_require_polyclip <- function() {
  if (!requireNamespace("polyclip", quietly = TRUE)) {
    stop("Boolean operations (Union, Intersection, Difference, Exclusion) need the 'polyclip' package. ",
         "Install it with install.packages(\"polyclip\").", call. = FALSE)
  }
}

# Run one polyclip operation with nonzero winding on both inputs, which
# matches the winding fill rule the camera uses. Empty inputs are handled here
# because polyclip expects at least one contour.
boolean_ops_clip <- function(A, B, op) {
  if (length(A) == 0) return(if (op %in% c("union", "xor")) B else list())
  if (length(B) == 0) return(if (op == "intersection") list() else A)
  polyclip::polyclip(A, B, op = op, fillA = "nonzero", fillB = "nonzero")
}

#' Boolean operations on VMobjects
#'
#' `Union()` merges two or more shapes, `Intersection()` keeps the region they
#' all share, `Difference()` removes `clip` from `subject` and `Exclusion()`
#' keeps the region covered by exactly one of the two. The inputs are
#' flattened to polygons (curves are sampled finely) and clipped with the
#' 'polyclip' package, so the result is made of straight segments. Install
#' 'polyclip' to use these classes.
#'
#' @param ... For `Union()` and `Intersection()`: two or more VMobjects, then
#'   named style arguments passed to [VMobject()]. For `Difference()` and
#'   `Exclusion()`: named style arguments.
#' @param subject,clip The VMobjects to subtract or exclude.
#' @name boolean_ops
#' @examples
#' \dontrun{
#' sq <- Square(color = RED, fill_opacity = 1)$move_to(c(-2, 0, 0))
#' cr <- Circle(color = BLUE, fill_opacity = 1)$move_to(c(-1.3, 0.7, 0))
#' un <- Union(sq, cr, color = GREEN, fill_opacity = 1)$move_to(c(1.5, 0.3, 0))
#' }
NULL

#' @rdname boolean_ops
#' @format NULL
#' @usage NULL
#' @export
BooleanOpsClass <- R6::R6Class("BooleanOps", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    # Flattening density: curves are sampled so that they deviate from the
    # true curve by less than 0.25 / flatten_resolution units.
    flatten_resolution = 1000,
    # Convert a VMobject's own points into polyclip contours, list(list(x, y), ...).
    convert_vmobject_to_polygons = function(vmobject) {
      pts <- vmobject$points
      if (nrow(pts) < 4 || !all(is.finite(pts))) return(list())
      split <- vmobject$get_subpath_split_indices_from_points(pts, n_dims = 2)
      if (nrow(split) == 0) return(list())
      flat <- flatten_subpaths(pts[, 1:2, drop = FALSE], split, self$flatten_resolution, 0.25,
                               vmobject$tolerance_for_point_equality)
      if (is.null(flat)) return(list())
      out <- list()
      for (id in unique(flat$id)) {
        keep <- flat$id == id
        x <- flat$x[keep]
        y <- flat$y[keep]
        n <- length(x)
        if (n > 1 && abs(x[1] - x[n]) < 1e-12 && abs(y[1] - y[n]) < 1e-12) {
          x <- x[-n]
          y <- y[-n]
        }
        if (length(x) >= 3) out[[length(out) + 1]] <- list(x = x, y = y)
      }
      out
    },
    # Append polyclip contours to this VMobject as closed polygonal subpaths.
    convert_polygons_to_vmobject = function(polygons) {
      parts <- lapply(polygons, function(p) {
        m <- length(p$x)
        if (m < 2) return(NULL)
        a1 <- cbind(p$x, p$y, 0)
        a2 <- a1[c(seq_len(m)[-1], 1), , drop = FALSE]
        interleave_curves(a1, interpolate(a1, a2, 1 / 3), interpolate(a1, a2, 2 / 3), a2)
      })
      parts <- Filter(Negate(is.null), parts)
      if (length(parts)) self$append_points(do.call(rbind, parts))
      invisible(self)
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
      boolean_ops_require_polyclip()
      do.call(super$initialize, a$kwargs)
      polys <- lapply(a$mobs, self$convert_vmobject_to_polygons)
      result <- polys[[1]]
      for (k in seq_along(polys)[-1]) result <- boolean_ops_clip(result, polys[[k]], "union")
      self$convert_polygons_to_vmobject(result)
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
      boolean_ops_require_polyclip()
      do.call(super$initialize, a$kwargs)
      polys <- lapply(a$mobs, self$convert_vmobject_to_polygons)
      result <- polys[[1]]
      for (k in seq_along(polys)[-1]) result <- boolean_ops_clip(result, polys[[k]], "intersection")
      self$convert_polygons_to_vmobject(result)
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
      boolean_ops_require_polyclip()
      super$initialize(...)
      self$convert_polygons_to_vmobject(boolean_ops_clip(
        self$convert_vmobject_to_polygons(subject), self$convert_vmobject_to_polygons(clip), "minus"))
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
      boolean_ops_require_polyclip()
      super$initialize(...)
      self$convert_polygons_to_vmobject(boolean_ops_clip(
        self$convert_vmobject_to_polygons(subject), self$convert_vmobject_to_polygons(clip), "xor"))
    }
  )
)

#' @rdname boolean_ops
#' @export
Exclusion <- constructor(ExclusionClass)