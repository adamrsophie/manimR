# Path functions ported from manim/utils/paths.py. A path function maps
# (start_points, end_points, alpha) to interpolated points.

STRAIGHT_PATH_THRESHOLD <- 0.01

# Cross product of a fixed vector a with every row of V.
cross_rows <- function(a, V) {
  cbind(a[2] * V[, 3] - a[3] * V[, 2], a[3] * V[, 1] - a[1] * V[, 3], a[1] * V[, 2] - a[2] * V[, 1])
}

#' Path functions
#'
#' Path functions control the trajectory points follow during a `Transform`.
#'
#' @param arc_angle,angle Angle swept along the path.
#' @param axis Rotation axis.
#' @param circles_centers Centers of the circles points travel along.
#' @return A function `f(start_points, end_points, alpha)`.
#' @name paths
NULL

#' @rdname paths
#' @export
straight_path <- function() interpolate

#' @rdname paths
#' @export
path_along_arc <- function(arc_angle, axis = OUT) {
  if (abs(arc_angle) < STRAIGHT_PATH_THRESHOLD) return(straight_path())
  unit_axis <- normalize(axis, fall_back = OUT)
  function(start_points, end_points, alpha) {
    vects <- end_points - start_points
    centers <- start_points + 0.5 * vects
    if (arc_angle != pi) centers <- centers + cross_rows(unit_axis, vects / 2) / tan(arc_angle / 2)
    rot <- rotation_matrix(alpha * arc_angle, unit_axis)
    centers + (start_points - centers) %*% t(rot)
  }
}

#' @rdname paths
#' @export
path_along_circles <- function(arc_angle, circles_centers, axis = OUT) {
  unit_axis <- normalize(axis, fall_back = OUT)
  function(start_points, end_points, alpha) {
    cc <- matrix(circles_centers, nrow(start_points), 3, byrow = !is.matrix(circles_centers))
    detrans <- cc + (end_points - cc) %*% t(rotation_matrix(-arc_angle, unit_axis))
    rot <- rotation_matrix(alpha * arc_angle, unit_axis)
    cc + (interpolate(start_points, detrans, alpha) - cc) %*% t(rot)
  }
}

#' @rdname paths
#' @export
clockwise_path <- function() path_along_arc(-pi)

#' @rdname paths
#' @export
counterclockwise_path <- function() path_along_arc(pi)

#' @rdname paths
#' @export
spiral_path <- function(angle, axis = OUT) {
  if (abs(angle) < STRAIGHT_PATH_THRESHOLD) return(straight_path())
  unit_axis <- normalize(axis, fall_back = OUT)
  function(start_points, end_points, alpha) {
    rot <- rotation_matrix((alpha - 1) * angle, unit_axis)
    start_points + alpha * ((end_points - start_points) %*% t(rot))
  }
}
