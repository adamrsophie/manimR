# Mobjects keyed by the rows of a data frame, and the animation that moves
# them to new data while each key keeps its object.

#' Mobjects keyed by data
#'
#' `keyed_mobjects()` makes one mobject per row of a data frame and keeps
#' them in a [VDict()] under the values of a key column.
#' `update_keyed()` animates the group to new data: a key in both tables
#' keeps its object, which transforms into the mobject made from its new
#' row; a new key fades in and a key that is gone fades out. After the
#' animation the group holds the keys of the new data, in its row order,
#' which is also the drawing order.
#'
#' Objects keep their identity: a reference to a key's mobject taken before
#' the update still points to the object on screen after it, with its
#' updaters. Keys may not be missing or repeated; such data is rejected
#' before anything changes. A data frame with no rows empties the group.
#'
#' Each row of `keyed_mobjects()` is a mobject of its own, which costs time
#' to make, copy and draw. For hundreds of rows drawn as points, use
#' `keyed_points()`: one [PMobject()] with a point per row, which
#' `update_keyed()` moves, fades in and fades out by key in the same way.
#'
#' @param data A data frame.
#' @param key Name of the column that identifies each row.
#' @param make A function of one row (a one-row data frame) that returns a
#'   VMobject.
#' @param x,y Names of the columns with the coordinates of the points.
#' @param axes Optional axes (such as [Axes()]) whose `c2p()` maps the
#'   coordinates to the scene; without it they are scene coordinates.
#' @param color Colors of the points, one or one per row. In
#'   `update_keyed()`, `NULL` keeps the color of each kept point and gives
#'   new points the group's color.
#' @param size Drawn size of each point (the `stroke_width` of a
#'   [PMobject()]).
#' @param group A group made by `keyed_mobjects()` or `keyed_points()`.
#' @param ... Arguments passed to the animation, for example `run_time`,
#'   `rate_func` or `lag_ratio`.
#' @return `keyed_mobjects()` returns a [VDict()], `keyed_points()` a
#'   `KeyedPoints` point cloud, and `update_keyed()` an animation to pass to
#'   a scene's `play()`.
#' @export
#' @examples
#' ax <- Axes(x_range = c(0, 4), y_range = c(0, 4))
#' before <- data.frame(id = c("a", "b", "c"), x = 1:3, y = c(1, 3, 2))
#' after <- data.frame(id = c("c", "a", "d"), x = c(3, 1, 2), y = c(3, 2, 1))
#' dot <- function(r) Dot(ax$c2p(r$x, r$y))
#' dots <- keyed_mobjects(before, "id", dot)
#' a <- dots[["a"]]
#' anim <- update_keyed(dots, after)
#' S <- manim_scene(function(self) {
#'   self$add(ax, dots)
#'   self$play(anim)
#' })
#'
#' cloud <- keyed_points(before, "id", "x", "y", axes = ax, color = BLUE)
#' anim2 <- update_keyed(cloud, after)
keyed_mobjects <- function(data, key, make) {
  keys <- keyed_keys(data, key)
  if (!is.function(make)) stop("`make` must be a function of one row.", call. = FALSE)
  group <- VDictClass$new()
  group$keyed_column <- key
  group$keyed_make <- make
  for (i in seq_along(keys)) group$add_key_value_pair(keys[i], keyed_make_row(make, data, i))
  group
}

#' @rdname keyed_mobjects
#' @export
update_keyed <- function(group, data, make = NULL, color = NULL, ...) {
  if (inherits(group, "KeyedPoints")) return(KeyedPointsUpdateClass$new(group, data, color = color, ...))
  KeyedUpdateClass$new(group, data, make = make, ...)
}

#' @rdname keyed_mobjects
#' @export
keyed_points <- function(data, key, x, y, axes = NULL, color = WHITE, size = 8) {
  keys <- keyed_keys(data, key)
  for (col in c(x, y)) if (!col %in% names(data)) stop("`data` has no column '", col, "'.", call. = FALSE)
  group <- KeyedPointsClass$new(stroke_width = size, color = if (length(color) == 1) color else WHITE)
  group$keyed_column <- key
  group$keyed_layout <- function(data) {
    if (!nrow(data)) return(matrix(0, 0, 3))
    if (is.null(axes)) return(cbind(as.numeric(data[[x]]), as.numeric(data[[y]]), 0))
    t(vapply(seq_len(nrow(data)), function(i) as_point(axes$c2p(data[[x]][i], data[[y]][i])), numeric(3)))
  }
  group$keys <- keys
  group$points <- group$keyed_layout(data)
  group$rgbas <- keyed_rgbas(color, length(keys))
  group
}

keyed_rgbas <- function(color, n) {
  if (!n) return(matrix(0, 0, 4))
  if (length(color) != 1 && length(color) != n) stop("`color` must have one value or one per row.", call. = FALSE)
  rgbas <- t(vapply(rep_len(as.list(color), n), color_to_rgba, numeric(4)))
  rgbas
}

# The keys of a data frame as strings, checked before anything changes.
keyed_keys <- function(data, key) {
  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  if (!is.character(key) || length(key) != 1 || !key %in% names(data)) {
    stop("`key` must name a column of `data`.", call. = FALSE)
  }
  keys <- data[[key]]
  if (anyNA(keys)) stop("The key column '", key, "' has missing values.", call. = FALSE)
  keys <- as.character(keys)
  dup <- unique(keys[duplicated(keys)])
  if (length(dup)) {
    stop("The key column '", key, "' repeats ", paste0("'", utils::head(dup, 5), "'", collapse = ", "),
         if (length(dup) > 5) ", ...", ".", call. = FALSE)
  }
  keys
}

keyed_make_row <- function(make, data, i) {
  m <- make(data[i, , drop = FALSE])
  if (!is_vmobject(m)) stop("`make` must return a VMobject; row ", i, " gave a ", class(m)[1], ".", call. = FALSE)
  m
}

#' @rdname keyed_mobjects
#' @format NULL
#' @usage NULL
#' @export
KeyedUpdateClass <- R6::R6Class("KeyedUpdate", inherit = AnimationClass, lock_objects = FALSE,
  public = list(
    keys = NULL,
    arrivals = NULL,
    departures = NULL,
    transform = NULL,
    initialize = function(group, data, make = NULL, run_time = DEFAULT_ANIMATION_RUN_TIME,
                          rate_func = smooth_rate, lag_ratio = 0, ...) {
      if (!inherits(group, "VDict") || is.null(group$keyed_column)) {
        stop("`group` must be made by keyed_mobjects().", call. = FALSE)
      }
      make <- make %||% group$keyed_make
      keys <- keyed_keys(data, group$keyed_column)
      targets <- lapply(seq_along(keys), function(i) keyed_make_row(make, data, i))
      old <- names(group$submob_dict) %||% character()
      self$keys <- keys
      # Each object animates from where it is to its target: kept keys to
      # their new rows, new keys from transparent and departing keys to
      # transparent.
      starts <- list()
      ends <- list()
      self$arrivals <- list()
      for (i in seq_along(keys)) {
        if (keys[i] %in% old) {
          starts[[length(starts) + 1]] <- group$submob_dict[[keys[i]]]
        } else {
          m <- targets[[i]]$copy()$set_opacity(0)
          self$arrivals[[keys[i]]] <- m
          starts[[length(starts) + 1]] <- m
        }
        ends[[length(ends) + 1]] <- targets[[i]]
      }
      self$departures <- setdiff(old, keys)
      for (k in self$departures) {
        starts[[length(starts) + 1]] <- group$submob_dict[[k]]
        ends[[length(ends) + 1]] <- group$submob_dict[[k]]$copy()$set_opacity(0)
      }
      # One transform of two groups moves every object in a single pass.
      self$transform <- TransformClass$new(GroupClass$new(starts), GroupClass$new(ends), run_time = run_time,
                                           rate_func = rate_func, lag_ratio = lag_ratio, ...)
      super$initialize(group, run_time = run_time, rate_func = rate_func, lag_ratio = lag_ratio)
    },
    begin = function() {
      for (k in names(self$arrivals)) self$mobject$add_key_value_pair(k, self$arrivals[[k]])
      self$transform$begin()
    },
    finish = function() self$transform$finish(),
    interpolate = function(alpha) self$transform$interpolate(alpha),
    get_all_mobjects = function() list(self$mobject),
    clean_up_from_scene = function(scene) {
      group <- self$mobject
      for (k in self$departures) group$remove(k)
      group$submob_dict <- group$submob_dict[self$keys]
      group$submobjects <- unname(group$submob_dict)
      super$clean_up_from_scene(scene)
    }
  )
)

#' @rdname keyed_mobjects
#' @format NULL
#' @usage NULL
#' @export
KeyedPointsClass <- R6::R6Class("KeyedPoints", inherit = PMobjectClass, lock_objects = FALSE,
  public = list(
    keys = character(),
    keyed_column = NULL,
    keyed_layout = NULL,
    # The rows of the points of some keys.
    rows_of = function(keys) match(keys, self$keys)
  )
)

#' @rdname keyed_mobjects
#' @format NULL
#' @usage NULL
#' @export
KeyedPointsUpdateClass <- R6::R6Class("KeyedPointsUpdate", inherit = AnimationClass, lock_objects = FALSE,
  public = list(
    keys = NULL,
    start_points = NULL,
    end_points = NULL,
    start_rgbas = NULL,
    end_rgbas = NULL,
    initialize = function(group, data, color = NULL, ...) {
      keys <- keyed_keys(data, group$keyed_column)
      old <- group$keys
      kept <- keys %in% old
      gone <- setdiff(old, keys)
      pts <- group$keyed_layout(data)
      rgbas <- if (is.null(color)) keyed_rgbas(group$color, length(keys)) else keyed_rgbas(color, length(keys))
      if (is.null(color) && any(kept)) rgbas[kept, ] <- group$rgbas[group$rows_of(keys[kept]), , drop = FALSE]
      # Rows: the new keys in order, then the keys that leave.
      self$keys <- keys
      start <- pts
      start_rgbas <- rgbas
      if (any(kept)) {
        start[kept, ] <- group$points[group$rows_of(keys[kept]), , drop = FALSE]
        start_rgbas[kept, ] <- group$rgbas[group$rows_of(keys[kept]), , drop = FALSE]
      }
      # New points fade in where they land.
      start_rgbas[!kept, 4] <- 0
      gone_rows <- group$rows_of(gone)
      gone_end <- group$rgbas[gone_rows, , drop = FALSE]
      gone_end[, 4] <- 0
      self$start_points <- rbind(start, group$points[gone_rows, , drop = FALSE])
      self$end_points <- rbind(pts, group$points[gone_rows, , drop = FALSE])
      self$start_rgbas <- rbind(start_rgbas, group$rgbas[gone_rows, , drop = FALSE])
      self$end_rgbas <- rbind(rgbas, gone_end)
      super$initialize(group, ...)
    },
    begin = function() self$interpolate(0),
    interpolate = function(alpha) {
      a <- self$rate_func(alpha)
      self$mobject$points <- self$start_points + a * (self$end_points - self$start_points)
      self$mobject$rgbas <- self$start_rgbas + a * (self$end_rgbas - self$start_rgbas)
      invisible(self)
    },
    finish = function() self$interpolate(1),
    get_all_mobjects = function() list(self$mobject),
    clean_up_from_scene = function(scene) {
      n <- length(self$keys)
      group <- self$mobject
      group$points <- self$end_points[seq_len(n), , drop = FALSE]
      group$rgbas <- self$end_rgbas[seq_len(n), , drop = FALSE]
      group$keys <- self$keys
      super$clean_up_from_scene(scene)
    }
  )
)
