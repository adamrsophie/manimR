# Mobjects that carry a framed label: Label, LabeledLine, LabeledArrow and
# LabeledPolygram. Ported from manim/mobject/geometry/labeled.py and
# manim/utils/polylabel.py.

# Merge `user` into `defaults`, keeping explicit NULL entries.
labeled_merge <- function(defaults, user) {
  for (nm in names(user)) defaults[nm] <- list(user[[nm]])
  defaults
}

#' @title Labels
#' @description `Label()` is a label surrounded by a background box and a
#'   frame. `LabeledLine()` and `LabeledArrow()` put such a label at
#'   `label_position` (a proportion of the length) along a line or arrow.
#'   `LabeledPolygram()` puts it at the pole of inaccessibility of a polygram,
#'   the interior point farthest from its edges, stored in `$pole` with the
#'   distance in `$radius`.
#' @param label A string (rendered with [MathTex()]) or a mobject such as [Text()].
#' @param label_config Named list of arguments for [MathTex()] when `label`
#'   is a string.
#' @param box_config Named list of arguments for the [BackgroundRectangle()].
#' @param frame_config Named list of arguments for the [SurroundingRectangle()] frame.
#' @param label_position Position of the label along the line, in `[0, 1]`.
#' @param precision Precision of the pole of inaccessibility search.
#' @param ... For `Label()`: passed to [VGroup()]. For `LabeledLine()` and
#'   `LabeledArrow()`: passed to [Line()] or [Arrow()] (`start`, `end`, ...).
#'   For `LabeledPolygram()`: vertex groups (one matrix or list of points per
#'   ring), then named arguments for [Polygram()].
#' @export
#' @examples
#' Label(Text("Label Text"), box_config = list(color = BLUE, fill_opacity = 0.75))$scale(3)
#' \dontrun{
#' # A label given as a string is typeset with LaTeX.
#' LabeledLine("0.5", label_position = 0.8, label_config = list(font_size = 20),
#'             start = LEFT + DOWN, end = RIGHT + UP)
#' }
LabelClass <- R6::R6Class("Label", inherit = VGroupClass, lock_objects = FALSE,
  public = list(
    rendered_label = NULL,
    background_rect = NULL,
    frame = NULL,
    initialize = function(label, label_config = NULL, box_config = NULL, frame_config = NULL, ...) {
      super$initialize(...)
      label_config <- labeled_merge(list(color = WHITE, font_size = DEFAULT_FONT_SIZE), label_config)
      box_config <- labeled_merge(list(color = NULL, buff = 0.05, fill_opacity = 1, stroke_width = 0.5), box_config)
      frame_config <- labeled_merge(list(color = WHITE, buff = 0.05, stroke_width = 0.5), frame_config)
      if (is.character(label)) {
        self$rendered_label <- do.call(MathTex, c(list(label), label_config))
      } else if (inherits(label, c("MathTex", "Text", "Typst"))) {
        self$rendered_label <- label
      } else {
        stop("Unsupported label type. Must be MathTex, Tex, Text, Typst, or MathTypst.", call. = FALSE)
      }
      self$background_rect <- do.call(BackgroundRectangle, c(list(self$rendered_label), box_config))
      self$frame <- do.call(SurroundingRectangle, c(list(self$rendered_label), frame_config))
      self$add(self$background_rect, self$rendered_label, self$frame)
    }
  )
)

#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @rdname LabelClass
#' @export
Label <- constructor(LabelClass)
# Add a Label at `label_position` along a line or arrow.
labeled_add_line_label <- function(self, label, label_position, label_config, box_config, frame_config) {
  self$label <- Label(label, label_config = label_config, box_config = box_config, frame_config = frame_config)
  se <- self$get_start_and_end()
  self$label$move_to(se[[1]] + (se[[2]] - se[[1]]) * label_position)
  self$add(self$label)
  invisible(self)
}

#' @rdname LabelClass
#' @format NULL
#' @usage NULL
#' @export
LabeledLineClass <- R6::R6Class("LabeledLine", inherit = LineClass, lock_objects = FALSE,
  public = list(
    label = NULL,
    initialize = function(label, label_position = 0.5, label_config = NULL, box_config = NULL,
                          frame_config = NULL, ...) {
      super$initialize(...)
      labeled_add_line_label(self, label, label_position, label_config, box_config, frame_config)
    }
  )
)

#' @rdname LabelClass
#' @export
LabeledLine <- constructor(LabeledLineClass)
#' @rdname LabelClass
#' @format NULL
#' @usage NULL
#' @export
LabeledArrowClass <- R6::R6Class("LabeledArrow", inherit = ArrowClass, lock_objects = FALSE,
  public = list(
    label = NULL,
    initialize = function(label, label_position = 0.5, label_config = NULL, box_config = NULL,
                          frame_config = NULL, ...) {
      super$initialize(...)
      labeled_add_line_label(self, label, label_position, label_config, box_config, frame_config)
    }
  )
)

#' @rdname LabelClass
#' @export
LabeledArrow <- constructor(LabeledArrowClass)
#' @rdname LabelClass
#' @format NULL
#' @usage NULL
#' @export
LabeledPolygramClass <- R6::R6Class("LabeledPolygram", inherit = PolygramClass, lock_objects = FALSE,
  public = list(
    label = NULL,
    pole = NULL,
    radius = NULL,
    initialize = function(..., label, precision = 0.01, label_config = NULL, box_config = NULL,
                          frame_config = NULL) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      do.call(super$initialize, args)
      self$label <- Label(label, label_config = label_config, box_config = box_config, frame_config = frame_config)
      # Close the rings for the pole search.
      rings <- lapply(args[nm == ""], function(g) {
        g <- as_points(g)
        if (any(g[1, ] != g[nrow(g), ])) g <- rbind(g, g[1, ])
        g
      })
      cell <- polylabel(rings, precision = precision)
      self$pole <- c(cell$c, 0)
      self$radius <- cell$d
      self$label$move_to(self$pole)
      self$add(self$label)
    }
  )
)

#' @rdname LabelClass
#' @export
LabeledPolygram <- constructor(LabeledPolygramClass)
# Pole of inaccessibility --------------------------------------------------

# Boundary data of polygon rings (closed n x 2 or n x 3 matrices), as the
# Polygon helper class of manim/utils/polylabel.py.
polylabel_polygon <- function(rings) {
  rings <- lapply(rings, function(r) as.matrix(r)[, 1:2, drop = FALSE])
  sizes <- vapply(rings, nrow, 1)
  arr <- do.call(rbind, rings)
  csum <- cumsum(sizes)
  start <- arr[-csum, , drop = FALSE]
  stop <- arr[-c(1, csum[-length(csum)] + 1), , drop = FALSE]
  diff <- stop - start
  norm <- diff / rowSums(diff * diff)
  x <- start[, 1]; y <- start[, 2]; xr <- stop[, 1]; yr <- stop[, 2]
  area <- 0.5 * (sum(x * yr) - sum(xr * y))
  centroid <- NULL
  if (area != 0) {
    factor <- x * yr - xr * y
    centroid <- c(sum((x + xr) * factor) / (6 * area), sum((y + yr) * factor) / (6 * area))
  }
  list(array = arr, start = start, stop = stop, diff = diff, norm = norm, area = area, centroid = centroid)
}

# Ray casting test; points on the boundary count as inside.
polylabel_inside <- function(poly, point) {
  x0 <- poly$start[, 1]; y0 <- poly$start[, 2]; x1 <- poly$stop[, 1]; y1 <- poly$stop[, 2]
  px <- point[1]; py <- point[2]
  in_box <- pmin(x0, x1) <= px & px <= pmax(x0, x1) & pmin(y0, y1) <= py & py <= pmax(y0, y1)
  cr <- (x1 - x0) * (py - y0) - (y1 - y0) * (px - x0)
  if (any(in_box & abs(cr) <= 1e-8)) return(TRUE)
  straddle <- (y0 > py) != (y1 > py)
  x_int <- (x1 - x0) / (y1 - y0) * (py - y0) + x0
  sum(straddle & px < x_int) %% 2 == 1
}

# Signed distance from a point to the boundary: positive inside.
polylabel_distance <- function(poly, point) {
  rel <- cbind(point[1] - poly$start[, 1], point[2] - poly$start[, 2])
  clips <- pmin(pmax(rowSums(poly$norm * rel), 0), 1)
  dx <- poly$start[, 1] + poly$diff[, 1] * clips - point[1]
  dy <- poly$start[, 2] + poly$diff[, 2] * clips - point[2]
  d <- min(sqrt(dx^2 + dy^2))
  if (polylabel_inside(poly, point)) d else -d
}

#' Pole of inaccessibility
#'
#' Finds the point inside a polygon (with optional holes) that is farthest
#' from its edges, by the iterative grid search of the polylabel algorithm.
#'
#' @param rings List of closed rings, each a matrix of points (n x 2 or n x 3).
#'   Extra rings are holes.
#' @param precision Precision of the result.
#' @return A list with `c` (the 2D pole), `d` (its distance to the edges) and
#'   `h` (half the size of the cell it was found in).
#' @export
#' @examples
#' polylabel(list(rbind(c(0, 0), c(4, 0), c(4, 2), c(0, 2), c(0, 0))))
polylabel <- function(rings, precision = 0.01) {
  poly <- polylabel_polygon(rings)
  mins <- apply(poly$array, 2, min)
  maxs <- apply(poly$array, 2, max)
  dims <- maxs - mins
  s <- min(dims)
  h <- s / 2
  # Cells are processed in increasing order of distance, as upstream's priority queue.
  cx <- numeric(); cy <- numeric(); ch <- numeric(); cd <- numeric()
  push <- function(x, y, hh) {
    cx[length(cx) + 1] <<- x
    cy[length(cy) + 1] <<- y
    ch[length(ch) + 1] <<- hh
    cd[length(cd) + 1] <<- polylabel_distance(poly, c(x, y))
  }
  if (s > 0) for (y in vf_arange(mins[2], maxs[2], s)) for (x in vf_arange(mins[1], maxs[1], s)) push(x + h, y + h, h)
  best_c <- poly$centroid %||% (mins + dims / 2)
  best_d <- polylabel_distance(poly, best_c)
  best_h <- 0
  bbox_c <- mins + dims / 2
  bbox_d <- polylabel_distance(poly, bbox_c)
  if (bbox_d > best_d) {
    best_c <- bbox_c
    best_d <- bbox_d
  }
  dirs <- rbind(c(-1, -1), c(1, -1), c(-1, 1), c(1, 1))
  alive <- rep(TRUE, length(cx))
  while (any(alive)) {
    cand <- which(alive)
    i <- cand[which.min(cd[cand])]
    alive[i] <- FALSE
    if (cd[i] > best_d) {
      best_c <- c(cx[i], cy[i])
      best_d <- cd[i]
      best_h <- ch[i]
    }
    if (cd[i] + ch[i] * sqrt(2) - best_d > precision) {
      hh <- ch[i] / 2
      for (k in 1:4) push(cx[i] + dirs[k, 1] * hh, cy[i] + dirs[k, 2] * hh, hh)
      alive <- c(alive, rep(TRUE, 4))
    }
  }
  list(c = best_c, d = best_d, h = best_h)
}
