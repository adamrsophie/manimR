# Upstream class methods and static methods, attached to the R6 class
# generators (R6 has no class methods), so `CircleClass$from_three_points()`
# mirrors `Circle.from_three_points()`. This file loads after every class.

#' Class methods
#'
#' Upstream's class and static methods live on the class generators:
#'
#' * `CircleClass$from_three_points(p1, p2, p3, ...)`: the circle through
#'   three points.
#' * `AngleClass$from_three_points(A, B, C, ...)`: the angle at `B` between
#'   the lines to `A` and `C`.
#' * `Line3DClass$parallel_to(line, point, length, ...)` and
#'   `Line3DClass$perpendicular_to(line, point, length, ...)`: a 3D line
#'   through `point` parallel or perpendicular to `line`.
#' * `ChangeSpeedClass$add_updater(mobject, update_function, index,
#'   call_updater)`: an updater that follows speed changes (the same as
#'   [change_speed_add_updater()]).
#' * `MobjectClass$set_default(...)` and `AnimationClass$set_default(...)`:
#'   [set_default()] for those base classes.
#' * `MobjectClass$add_animation_override(animation_class, override_func,
#'   mobject_class = MobjectClass)`: registers an override, as
#'   [override_animation()] does, and errors if the class already has one.
#' * `TextClass$font_list()` and `MarkupTextClass$font_list()`: the font
#'   families installed.
#' * `TexTemplateClass$from_file(file, ...)`: a template whose whole body
#'   is read from a `.tex` file.
#' * `CodeClass$get_styles_list()` and `CodeClass$get_pygments_style(name)`:
#'   the names and colors of the highlighting styles (all of Pygments' when
#'   it is available, see [Code()]).
#' * `GraphClass$from_igraph(graph, ...)` and `DiGraphClass$from_igraph(graph,
#'   ...)`: a [Graph()] or [DiGraph()] with the vertices (by name when they
#'   have names) and edges of an igraph graph, the R counterpart of
#'   upstream's `Graph.from_networkx()`; `...` goes to the constructor, for
#'   example `layout = "spring"`.
#'
#' @name class_methods
#' @examples
#' CircleClass$from_three_points(LEFT, UP, RIGHT)$radius
#' head(TextClass$font_list())
NULL

CircleClass$from_three_points <- function(p1, p2, p3, ...) {
  p1 <- as_point(p1)
  p2 <- as_point(p2)
  p3 <- as_point(p3)
  center <- line_intersection(perpendicular_bisector(rbind(p1, p2)), perpendicular_bisector(rbind(p2, p3)))
  Circle(radius = get_norm(p1 - center), ...)$shift(center)
}

AngleClass$from_three_points <- function(A, B, C, ...) Angle(Line(B, A), Line(B, C), ...)

Line3DClass$parallel_to <- function(line, point = ORIGIN, length = 5, ...) {
  point <- as_point(point)
  vect <- normalize(line$vect)
  Line3D(point + vect * length / 2, point - vect * length / 2, ...)
}

Line3DClass$perpendicular_to <- function(line, point = ORIGIN, length = 5, ...) {
  point <- as_point(point)
  norm <- cross(line$vect, point - line$start)
  if (all(norm == 0)) stop("Could not find the perpendicular.", call. = FALSE)
  ends <- perpendicular_bisector(rbind(line$start, line$end), norm)
  vect <- normalize(ends[2, ] - ends[1, ])
  Line3D(point + vect * length / 2, point - vect * length / 2, ...)
}

ChangeSpeedClass$add_updater <- function(mobject, update_function, index = NULL, call_updater = FALSE) {
  change_speed_add_updater(mobject, update_function, index = index, call_updater = call_updater)
}

MobjectClass$set_default <- function(...) set_default(MobjectClass, ...)
AnimationClass$set_default <- function(...) set_default(AnimationClass, ...)

MobjectClass$add_animation_override <- function(animation_class, override_func, mobject_class = MobjectClass) {
  name <- if (inherits(animation_class, "R6ClassGenerator")) animation_class$classname else animation_class
  if (paste0("animation_override_", name) %in% names(mobject_class$public_methods)) {
    stop("The animation ", name, " for ", mobject_class$classname, " is overridden by more than one method.",
         call. = FALSE)
  }
  override_animation(mobject_class, name, override_func)
}

TextClass$font_list <- function() sort(unique(systemfonts::system_fonts()$family))
MarkupTextClass$font_list <- TextClass$font_list

TexTemplateClass$from_file <- function(file = "tex_template.tex", ...) {
  tpl <- TexTemplateClass$new(...)
  tpl$set_body(paste(readLines(file, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
  tpl
}

CodeClass$get_styles_list <- function() pygments_styles() %||% names(code_styles())
CodeClass$get_pygments_style <- function(name) {
  style <- code_styles()[[name]]
  if (is.null(style) && !is.null(pygments_python())) {
    p <- code_pygments("x", "text", name)
    return(list(background = p$background, line_number = p$line_number, text = p$foreground))
  }
  if (is.null(style)) stop("Unknown style '", name, "'. Available: ", paste(names(code_styles()), collapse = ", "),
                           call. = FALSE)
  style
}

graph_from_igraph <- function(constructor) {
  force(constructor)
  function(graph, ...) {
    if (!requireNamespace("igraph", quietly = TRUE)) stop("from_igraph() needs the igraph package.", call. = FALSE)
    n <- igraph::vcount(graph)
    names <- igraph::V(graph)$name
    vertices <- if (is.null(names)) seq_len(n) else names
    el <- igraph::as_edgelist(graph, names = !is.null(names))
    edges <- lapply(seq_len(nrow(el)), function(i) el[i, ])
    constructor(vertices, edges, ...)
  }
}

GraphClass$from_igraph <- graph_from_igraph(Graph)
DiGraphClass$from_igraph <- graph_from_igraph(DiGraph)
