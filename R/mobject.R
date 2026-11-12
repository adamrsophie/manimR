# Mobject: the base class for all objects that can be displayed.
# Ported from manim/mobject/mobject.py.

is_mobject <- function(x) inherits(x, "Mobject")

# Reduce a numeric direction component to the sign key used for critical points.
dir_key <- function(d) if (d < 0) -1 else if (d > 0) 1 else 0

updater_takes_dt <- function(f) "dt" %in% names(formals(args(f)) %||% list())

#' @title Mobject
#' @description Base class for mathematical objects. Most users construct
#'   subclasses such as [Circle()] or [VGroup()]. All transformation methods
#'   modify the object in place and return it invisibly, so calls chain:
#'   `Square()$shift(LEFT)$scale(2)`.
#' @details Fields: `points` (n x 3 matrix), `submobjects` (list), `z_index`,
#'   `updaters`, `name`. Active bindings `width`, `height`, `depth` get or set
#'   the size. The active binding `animate` records method calls as an
#'   animation, as in `scene$play(sq$animate$shift(RIGHT)$scale(2))`.
#' @param color Color of the mobject.
#' @param name Name; the class name by default.
#' @param z_index Drawing order: higher values are drawn on top.
#' @param ... Fields of the class to set, such as those [set_default()]
#'   gives; any other name is an error.
#' @aliases Mobject
#' @export
MobjectClass <- R6::R6Class("Mobject",
  lock_objects = FALSE,
  public = list(
    points = NULL,
    submobjects = NULL,
    name = NULL,
    color = NULL,
    dim = 3,
    z_index = 0,
    updaters = NULL,
    updating_suspended = FALSE,
    target = NULL,
    saved_state = NULL,
    mob_id = NULL,

    initialize = function(color = "#FFFFFF", name = NULL, z_index = 0, ...) {
      extra <- list(...)
      if (length(extra)) {
        nms <- names(extra)
        if (is.null(nms) || any(nms == "")) stop("Unnamed arguments are not allowed here.", call. = FALSE)
        # Only settings of the class pass through (as set_default() and
        # subclasses use them); anything else is a mistake, as upstream's
        # TypeError for an unexpected keyword argument.
        unknown <- nms[!vapply(nms, exists, NA, envir = self, inherits = FALSE)]
        if (length(unknown)) {
          stop(class(self)[1], "() got unexpected argument", if (length(unknown) > 1) "s", ": ",
               paste(unknown, collapse = ", "), call. = FALSE)
        }
        for (nm in nms) assign(nm, extra[[nm]], envir = self)
      }
      self$mob_id <- next_mob_id()
      self$name <- name %||% class(self)[1]
      self$z_index <- z_index
      self$submobjects <- list()
      self$updaters <- list()
      self$color <- manim_color(color)
      self$reset_points()
      self$generate_points()
      self$init_colors()
    },

    reset_points = function() {
      self$points <- matrix(0, 0, self$dim)
      invisible(self)
    },
    generate_points = function() invisible(self),
    init_colors = function(propagate_colors = TRUE) invisible(self),

    print = function(...) {
      cat("<", class(self)[1], "> ", nrow(self$points), " points, ",
          length(self$submobjects), " submobjects\n", sep = "")
      invisible(self)
    },

    # Submobject management ------------------------------------------------
    # The kind of mobject this one takes as a submobject: VMobject overrides
    # it, as upstream's _assert_valid_submobjects().
    assert_valid_submobjects = function(submobjects) {
      self$assert_valid_submobjects_internal(submobjects, "Mobject")
    },
    assert_valid_submobjects_internal = function(submobjects, mob_class) {
      for (i in seq_along(submobjects)) {
        m <- submobjects[[i]]
        if (!inherits(m, mob_class)) {
          msg <- sprintf("Only values of type %s can be added as submobjects of %s, but the value at index %d is of type %s.",
                         mob_class, class(self)[1], i, class(m)[1])
          if (is_mobject(m)) msg <- paste(msg, "You can try adding this value into a Group instead.")
          stop(msg, call. = FALSE)
        }
        if (identical(m$mob_id, self$mob_id)) {
          stop(sprintf("Cannot add %s as a submobject of itself (at index %d).", class(self)[1], i), call. = FALSE)
        }
      }
      invisible(self)
    },
    # Upstream's _insert_submobjects(): `index` counts from 0 and follows
    # Python's list.insert (negative values count from the end). Mobjects
    # that are already submobjects move to the new position.
    insert_submobjects = function(index, mobjects) {
      self$assert_valid_submobjects(mobjects)
      if (!length(mobjects)) return(invisible(self))
      ids <- vapply(mobjects, function(m) m$mob_id, "")
      keep <- !duplicated(ids, fromLast = TRUE)
      if (!all(keep)) {
        logger$warning("Attempted adding some Mobject as a child more than once, this is not possible. Repetitions are ignored.")
      }
      mobjects <- mobjects[keep]
      ids <- ids[keep]
      n <- length(self$submobjects)
      if (!n) {
        self$submobjects <- mobjects
        return(invisible(self))
      }
      norm_index <- max(0, min(if (index >= 0) index else n + index, n))
      cur_ids <- self$submobject_ids()
      if (length(mobjects) == 1) {
        # Nothing to do when the mobject is already at or next to the index.
        near <- c(norm_index, norm_index + 1)
        if (any(cur_ids[near[near >= 1 & near <= n]] == ids)) return(invisible(self))
        old <- match(ids, cur_ids)
        if (is.na(old)) {
          self$submobjects <- append(self$submobjects, mobjects, after = norm_index)
        } else {
          new_index <- if (norm_index < old - 1) norm_index else norm_index - 1
          self$submobjects <- append(self$submobjects[-old], mobjects, after = new_index)
        }
        return(invisible(self))
      }
      before <- seq_len(n) <= norm_index
      fresh <- !cur_ids %in% ids
      self$submobjects <- c(self$submobjects[before & fresh], mobjects, self$submobjects[!before & fresh])
      invisible(self)
    },
    add = function(...) {
      self$insert_submobjects(length(self$submobjects), flatten_mobjects(list(...)))
    },
    # `index` counts from 1; a negative index counts from the end, so that
    # insert(-1, m) puts m before the last submobject.
    insert = function(index, mobject) {
      self$insert_submobjects(if (index >= 1) index - 1 else index, list(mobject))
    },
    add_to_back = function(...) {
      self$insert_submobjects(0, flatten_mobjects(list(...)))
    },
    remove = function(...) {
      mobs <- flatten_mobjects(list(...))
      ids <- vapply(mobs, function(m) m$mob_id, "")
      self$submobjects <- self$submobjects[!self$submobject_ids() %in% ids]
      invisible(self)
    },
    submobject_ids = function() vapply(self$submobjects, function(m) m$mob_id, ""),
    set = function(...) {
      args <- list(...)
      for (nm in names(args)) self[[nm]] <- args[[nm]]
      invisible(self)
    },

    # Copying --------------------------------------------------------------
    copy = function(.memo = NULL) {
      if (is.null(.memo)) .memo <- new.env(parent = emptyenv())
      key <- self$mob_id
      if (!is.null(.memo[[key]])) return(.memo[[key]])
      new <- fast_clone(self)
      new$mob_id <- next_mob_id()
      assign(key, new, envir = .memo)
      # Like Python's deepcopy, mobjects and animations held in fields (or in
      # lists) are copied through the shared memo, so references between them
      # stay consistent in the copy.
      for (nm in mobject_fields(self)) {
        v <- .subset2(self, nm)
        if (is_mobject(v) || inherits(v, "Animation") || (is.list(v) && length(v) && !is.data.frame(v))) {
          assign(nm, copy_nested(v, .memo), envir = new)
        }
      }
      copy_private_nested(self, new, .memo)
      new
    },
    # Upstream's name for generate_points() in some classes.
    init_points = function() {
      self$generate_points()
      invisible(self)
    },
    get_array_attrs = function() "points",
    apply_over_attr_arrays = function(func) {
      for (attr in self$get_array_attrs()) self[[attr]] <- func(.subset2(self, attr))
      invisible(self)
    },
    # Repeats the points of every family member `count` times (upstream's
    # repeat(); `repeat` is reserved in R, so call it as mob$`repeat`(2) or
    # mob$repeat_points(2)).
    `repeat` = function(count) {
      rep_rows <- function(a) if (is.matrix(a)) a[rep(seq_len(nrow(a)), count), , drop = FALSE] else rep(a, count)
      for (m in self$family_members_with_points()) m$apply_over_attr_arrays(rep_rows)
      invisible(self)
    },
    repeat_points = function(count) self$`repeat`(count),
    pose_at_angle = function(...) {
      self$rotate(TAU / 14, RIGHT + UP, ...)
      invisible(self)
    },
    to_original_color = function() {
      self$set_color(self$color)
      invisible(self)
    },
    add_background_rectangle_to_family_members_with_points = function(...) {
      for (m in self$family_members_with_points()) m$add_background_rectangle(...)
      invisible(self)
    },
    get_mobject_type_class = function() MobjectClass,
    # The override this mobject's class registers for an animation class (see
    # override_animation()), or NULL.
    animation_override_for = function(animation_class) {
      name <- if (inherits(animation_class, "R6ClassGenerator")) animation_class$classname else animation_class
      f <- .subset2(self, paste0("animation_override_", name))
      if (is.function(f)) f
    },
    generate_target = function(use_deepcopy = FALSE) {
      self$target <- NULL
      self$target <- self$copy()
      self$target
    },
    save_state = function() {
      self$saved_state <- NULL
      self$saved_state <- self$copy()
      invisible(self)
    },
    restore = function() {
      if (is.null(self$saved_state)) stop("Trying to restore without having saved", call. = FALSE)
      self$become(self$saved_state)
      invisible(self)
    },

    # Updaters -------------------------------------------------------------
    update = function(dt = 0, recursive = TRUE) {
      if (self$updating_suspended) return(invisible(self))
      for (f in self$updaters) {
        if (updater_takes_dt(f)) f(self, dt) else f(self)
      }
      if (recursive) for (sm in self$submobjects) sm$update(dt, recursive)
      invisible(self)
    },
    get_time_based_updaters = function() Filter(updater_takes_dt, self$updaters),
    has_time_based_updater = function() any(vapply(self$updaters, updater_takes_dt, logical(1))),
    get_updaters = function() self$updaters,
    get_family_updaters = function() unlist(lapply(self$get_family(), function(m) m$updaters), recursive = FALSE),
    add_updater = function(update_function, index = NULL, call_updater = FALSE) {
      if (is.null(index)) {
        self$updaters <- c(self$updaters, list(update_function))
      } else {
        self$updaters <- append(self$updaters, list(update_function), after = index - 1)
      }
      if (call_updater) {
        if (updater_takes_dt(update_function)) update_function(self, 0) else update_function(self)
      }
      invisible(self)
    },
    remove_updater = function(update_function) {
      self$updaters <- Filter(function(f) !identical(f, update_function), self$updaters)
      invisible(self)
    },
    clear_updaters = function(recursive = TRUE) {
      self$updaters <- list()
      if (recursive) for (sm in self$submobjects) sm$clear_updaters()
      invisible(self)
    },
    match_updaters = function(mobject) {
      self$clear_updaters()
      for (f in mobject$get_updaters()) self$add_updater(f)
      invisible(self)
    },
    suspend_updating = function(recursive = TRUE) {
      self$updating_suspended <- TRUE
      if (recursive) for (sm in self$submobjects) sm$suspend_updating(recursive)
      invisible(self)
    },
    resume_updating = function(recursive = TRUE) {
      self$updating_suspended <- FALSE
      if (recursive) for (sm in self$submobjects) sm$resume_updating(recursive)
      self$update(dt = 0, recursive = recursive)
      invisible(self)
    },

    # Transformations ------------------------------------------------------
    apply_to_family = function(func) {
      for (m in self$family_members_with_points()) func(m)
      invisible(self)
    },
    shift = function(...) {
      v <- Reduce(`+`, lapply(list(...), as_point), c(0, 0, 0))
      for (m in self$family_members_with_points()) {
        m$points <- m$points + rep(v, each = nrow(m$points))
      }
      invisible(self)
    },
    scale = function(scale_factor, about_point = NULL, about_edge = NULL, ...) {
      self$apply_points_function_about_point(function(p) {
        if (length(scale_factor) == 1) p * scale_factor else p * rep(scale_factor, each = nrow(p))
      }, about_point, about_edge)
      invisible(self)
    },
    rotate_about_origin = function(angle, axis = OUT) {
      self$rotate(angle, axis, about_point = ORIGIN)
    },
    rotate = function(angle, axis = OUT, about_point = NULL, about_edge = NULL, ...) {
      rot <- t(rotation_matrix(angle, axis))
      self$apply_points_function_about_point(function(p) p %*% rot, about_point, about_edge)
      invisible(self)
    },
    flip = function(axis = UP, ...) {
      self$rotate(TAU / 2, axis, ...)
    },
    stretch = function(factor, dim, ...) {
      self$apply_points_function_about_point(function(p) {
        p[, dim] <- p[, dim] * factor
        p
      }, ...)
      invisible(self)
    },
    # about_point defaults to the origin unless about_edge is given, as
    # upstream.
    apply_function = function(func, about_point = NULL, about_edge = NULL, ...) {
      if (is.null(about_point) && is.null(about_edge)) about_point <- ORIGIN
      self$apply_points_function_about_point(function(p) apply_rowwise(p, func), about_point = about_point,
                                             about_edge = about_edge, ...)
      invisible(self)
    },
    apply_function_to_position = function(func) {
      self$move_to(func(self$get_center()))
    },
    apply_function_to_submobject_positions = function(func) {
      for (sm in self$submobjects) sm$apply_function_to_position(func)
      invisible(self)
    },
    apply_matrix = function(matrix, about_point = NULL, about_edge = NULL, ...) {
      if (is.null(about_point) && is.null(about_edge)) about_point <- ORIGIN
      m <- as.matrix(matrix)
      full <- diag(self$dim)
      full[seq_len(nrow(m)), seq_len(ncol(m))] <- m
      tm <- t(full)
      self$apply_points_function_about_point(function(p) p %*% tm, about_point = about_point,
                                             about_edge = about_edge, ...)
      invisible(self)
    },
    apply_complex_function = function(func, ...) {
      self$apply_function(function(p) {
        z <- func(complex(real = p[1], imaginary = p[2]))
        c(Re(z), Im(z), p[3])
      }, ...)
    },
    reverse_points = function() {
      for (m in self$family_members_with_points()) m$points <- m$points[nrow(m$points):1, , drop = FALSE]
      invisible(self)
    },
    apply_points_function_about_point = function(func, about_point = NULL, about_edge = NULL) {
      if (is.null(about_point)) {
        if (is.null(about_edge)) about_edge <- ORIGIN
        about_point <- self$get_critical_point(about_edge)
      }
      about_point <- as_point(about_point)
      for (m in self$family_members_with_points()) {
        n <- nrow(m$points)
        ap <- rep(about_point, each = n)
        m$points <- func(m$points - ap) + ap
      }
      invisible(self)
    },

    # Positioning ----------------------------------------------------------
    center = function() {
      self$shift(-self$get_center())
    },
    align_on_border = function(direction, buff = DEFAULT_MOBJECT_TO_EDGE_BUFFER) {
      direction <- as_point(direction)
      target_point <- sign(direction) * c(frame_x_radius(), frame_y_radius(), 0)
      point_to_align <- self$get_critical_point(direction)
      shift_val <- (target_point - point_to_align - buff * direction) * abs(sign(direction))
      self$shift(shift_val)
    },
    to_corner = function(corner = DL, buff = DEFAULT_MOBJECT_TO_EDGE_BUFFER) {
      self$align_on_border(corner, buff)
    },
    to_edge = function(edge = LEFT, buff = DEFAULT_MOBJECT_TO_EDGE_BUFFER) {
      self$align_on_border(edge, buff)
    },
    next_to = function(mobject_or_point, direction = RIGHT, buff = DEFAULT_MOBJECT_TO_MOBJECT_BUFFER,
                       aligned_edge = ORIGIN, submobject_to_align = NULL,
                       index_of_submobject_to_align = NULL, coor_mask = c(1, 1, 1)) {
      direction <- as_point(direction)
      aligned_edge <- as_point(aligned_edge)
      if (is_mobject(mobject_or_point)) {
        mob <- mobject_or_point
        target_aligner <- if (!is.null(index_of_submobject_to_align)) mob$submobjects[[index_of_submobject_to_align]] else mob
        target_point <- target_aligner$get_critical_point(aligned_edge + direction)
      } else {
        target_point <- as_point(mobject_or_point)
      }
      aligner <- if (!is.null(submobject_to_align)) submobject_to_align
        else if (!is.null(index_of_submobject_to_align)) self$submobjects[[index_of_submobject_to_align]]
        else self
      point_to_align <- aligner$get_critical_point(aligned_edge - direction)
      self$shift((target_point - point_to_align + buff * direction) * coor_mask)
    },
    shift_onto_screen = function(buff = DEFAULT_MOBJECT_TO_EDGE_BUFFER) {
      lens <- c(frame_x_radius(), frame_y_radius())
      for (v in list(UP, DOWN, LEFT, RIGHT)) {
        d <- which.max(abs(v))
        if (sum(self$get_edge_center(v) * v) > lens[d] - buff) self$to_edge(v, buff = buff)
      }
      invisible(self)
    },
    is_off_screen = function() {
      self$get_left()[1] > frame_x_radius() || self$get_right()[1] < -frame_x_radius() ||
        self$get_bottom()[2] > frame_y_radius() || self$get_top()[2] < -frame_y_radius()
    },
    stretch_about_point = function(factor, dim, point) {
      self$stretch(factor, dim, about_point = point)
    },
    rescale_to_fit = function(length, dim, stretch = FALSE, ...) {
      old <- self$length_over_dim(dim)
      if (old == 0) return(invisible(self))
      if (stretch) self$stretch(length / old, dim, ...) else self$scale(length / old, ...)
      invisible(self)
    },
    scale_to_fit_width = function(width, ...) self$rescale_to_fit(width, 1, stretch = FALSE, ...),
    stretch_to_fit_width = function(width, ...) self$rescale_to_fit(width, 1, stretch = TRUE, ...),
    scale_to_fit_height = function(height, ...) self$rescale_to_fit(height, 2, stretch = FALSE, ...),
    stretch_to_fit_height = function(height, ...) self$rescale_to_fit(height, 2, stretch = TRUE, ...),
    scale_to_fit_depth = function(depth, ...) self$rescale_to_fit(depth, 3, stretch = FALSE, ...),
    stretch_to_fit_depth = function(depth, ...) self$rescale_to_fit(depth, 3, stretch = TRUE, ...),
    set_coord = function(value, dim, direction = ORIGIN) {
      curr <- self$get_coord(dim, direction)
      shift_vect <- c(0, 0, 0)
      shift_vect[dim] <- value - curr
      self$shift(shift_vect)
    },
    set_x = function(x, direction = ORIGIN) self$set_coord(x, 1, direction),
    set_y = function(y, direction = ORIGIN) self$set_coord(y, 2, direction),
    set_z = function(z, direction = ORIGIN) self$set_coord(z, 3, direction),
    space_out_submobjects = function(factor = 1.5, ...) {
      self$scale(factor, ...)
      for (sm in self$submobjects) sm$scale(1 / factor)
      invisible(self)
    },
    move_to = function(point_or_mobject, aligned_edge = ORIGIN, coor_mask = c(1, 1, 1)) {
      target <- if (is_mobject(point_or_mobject)) point_or_mobject$get_critical_point(aligned_edge)
        else as_point(point_or_mobject)
      point_to_align <- self$get_critical_point(aligned_edge)
      self$shift((target - point_to_align) * coor_mask)
    },
    replace = function(mobject, dim_to_match = 1, stretch = FALSE) {
      if (!mobject$get_num_points() && !length(mobject$submobjects)) {
        stop("Attempting to replace mobject with no points", call. = FALSE)
      }
      if (stretch) {
        self$stretch_to_fit_width(mobject$width)
        self$stretch_to_fit_height(mobject$height)
      } else {
        self$rescale_to_fit(mobject$length_over_dim(dim_to_match), dim_to_match, stretch = FALSE)
      }
      self$shift(mobject$get_center() - self$get_center())
    },
    surround = function(mobject, dim_to_match = 1, stretch = FALSE, buff = MED_SMALL_BUFF) {
      self$replace(mobject, dim_to_match, stretch)
      len <- mobject$length_over_dim(dim_to_match)
      self$scale((len + buff) / len)
    },
    put_start_and_end_on = function(start, end) {
      se <- self$get_start_and_end()
      cur_start <- se[[1]]
      cur_vec <- se[[2]] - cur_start
      start <- as_point(start)
      end <- as_point(end)
      if (all(cur_vec == 0)) {
        warning("put_start_and_end_on has been called on a closed loop or zero-length mobject.", call. = FALSE)
        return(self$shift(start - cur_start))
      }
      target_vec <- end - start
      cr <- cross(cur_vec, target_vec)
      axis <- if (get_norm(cr) != 0) normalize(cr) else OUT
      self$scale(get_norm(target_vec) / get_norm(cur_vec), about_point = cur_start)
      self$rotate(angle_between_vectors(cur_vec, target_vec), axis = axis, about_point = cur_start)
      self$shift(start - cur_start)
    },

    # Background rectangles ------------------------------------------------
    add_background_rectangle = function(color = NULL, opacity = 0.75, ...) {
      self$background_rectangle <- BackgroundRectangle(self, color = color, fill_opacity = opacity, ...)
      self$add_to_back(self$background_rectangle)
      invisible(self)
    },
    add_background_rectangle_to_submobjects = function(...) {
      for (sm in self$submobjects) sm$add_background_rectangle(...)
      invisible(self)
    },

    # Color ----------------------------------------------------------------
    # `alpha` is accepted for upstream's signature; the base class has no
    # opacity of its own.
    set_color = function(color = "#FFFF00", alpha = NULL, family = TRUE) {
      if (family) for (sm in self$submobjects) sm$set_color(color, family = family)
      self$color <- manim_color(color)
      invisible(self)
    },
    set_color_by_gradient = function(...) {
      self$set_submobject_colors_by_gradient(...)
    },
    set_submobject_colors_by_gradient = function(...) {
      colors <- unlist(list(...))
      if (length(colors) == 0) stop("Need at least one color", call. = FALSE)
      if (length(colors) == 1) return(self$set_color(colors))
      mobs <- self$family_members_with_points()
      new_colors <- color_gradient(colors, length(mobs))
      for (i in seq_along(mobs)) mobs[[i]]$set_color(new_colors[i], family = FALSE)
      invisible(self)
    },
    set_colors_by_radial_gradient = function(center = NULL, radius = 1, inner_color = "#FFFFFF", outer_color = "#000000") {
      self$set_submobject_colors_by_radial_gradient(center, radius, inner_color, outer_color)
    },
    set_submobject_colors_by_radial_gradient = function(center = NULL, radius = 1, inner_color = "#FFFFFF", outer_color = "#000000") {
      if (is.null(center)) center <- self$get_center()
      for (m in self$family_members_with_points()) {
        t <- get_norm(m$get_center() - center) / radius
        m$set_color(interpolate_color(inner_color, outer_color, min(t, 1)), family = FALSE)
      }
      invisible(self)
    },
    fade_to = function(color, alpha, family = TRUE) {
      if (self$get_num_points() > 0) {
        self$set_color(interpolate_color(self$get_color(), color, alpha), family = FALSE)
      }
      if (family) for (sm in self$submobjects) sm$fade_to(color, alpha)
      invisible(self)
    },
    fade = function(darkness = 0.5, family = TRUE) {
      if (family) for (sm in self$submobjects) sm$fade(darkness, family)
      invisible(self)
    },
    get_color = function() self$color,

    # Queries --------------------------------------------------------------
    reduce_across_dimension = function(reduce_func, dim) {
      vals <- unlist(lapply(self$get_family(), function(m) {
        if (nrow(m$points)) reduce_func(m$points[, dim]) else NULL
      }))
      if (is.null(vals)) NULL else reduce_func(vals)
    },
    nonempty_submobjects = function() Filter(function(m) length(m$submobjects) || nrow(m$points), self$submobjects),
    get_merged_array = function(array_attr) {
      do.call(rbind, lapply(self$get_family(), function(m) m[[array_attr]]))
    },
    get_all_points = function() {
      fam <- self$get_family()
      pts <- lapply(fam, function(m) m$points)
      out <- do.call(rbind, pts)
      if (is.null(out)) matrix(0, 0, self$dim) else out
    },
    get_points_defining_boundary = function() self$get_all_points(),
    get_num_points = function() nrow(self$points),
    get_extremum_along_dim = function(points = NULL, dim = 1, key = 0) {
      if (is.null(points)) points <- self$get_points_defining_boundary()
      if (nrow(points) == 0) return(0)
      v <- points[, dim]
      if (key < 0) min(v) else if (key == 0) (min(v) + max(v)) / 2 else max(v)
    },
    get_critical_point = function(direction) {
      direction <- as_point(direction)
      result <- c(0, 0, 0)
      pts <- self$get_points_defining_boundary()
      if (nrow(pts) == 0) return(result)
      for (d in 1:3) {
        v <- pts[, d]
        k <- dir_key(direction[d])
        result[d] <- if (k < 0) min(v) else if (k == 0) (min(v) + max(v)) / 2 else max(v)
      }
      result
    },
    get_edge_center = function(direction) self$get_critical_point(direction),
    get_corner = function(direction) self$get_critical_point(direction),
    get_center = function() self$get_critical_point(c(0, 0, 0)),
    get_center_of_mass = function() colMeans(self$get_all_points()),
    get_boundary_point = function(direction) {
      pts <- self$get_points_defining_boundary()
      pts[which.max(pts %*% as_point(direction)), ]
    },
    get_midpoint = function() self$point_from_proportion(0.5),
    get_top = function() self$get_edge_center(UP),
    get_bottom = function() self$get_edge_center(DOWN),
    get_right = function() self$get_edge_center(RIGHT),
    get_left = function() self$get_edge_center(LEFT),
    get_zenith = function() self$get_edge_center(OUT),
    get_nadir = function() self$get_edge_center(IN),
    length_over_dim = function(dim) {
      mx <- self$reduce_across_dimension(max, dim)
      mn <- self$reduce_across_dimension(min, dim)
      if (is.null(mx) || is.null(mn)) 0 else mx - mn
    },
    get_coord = function(dim, direction = ORIGIN) {
      self$get_extremum_along_dim(dim = dim, key = dir_key(as_point(direction)[dim]))
    },
    get_x = function(direction = ORIGIN) self$get_coord(1, direction),
    get_y = function(direction = ORIGIN) self$get_coord(2, direction),
    get_z = function(direction = ORIGIN) self$get_coord(3, direction),
    get_start = function() {
      self$throw_error_if_no_points()
      self$points[1, ]
    },
    get_end = function() {
      self$throw_error_if_no_points()
      self$points[nrow(self$points), ]
    },
    get_start_and_end = function() list(self$get_start(), self$get_end()),
    point_from_proportion = function(alpha) stop("Not implemented for this class", call. = FALSE),
    proportion_from_point = function(point) stop("Not implemented for this class", call. = FALSE),
    get_pieces = function(n_pieces) {
      template <- self$copy()
      template$submobjects <- list()
      alphas <- seq(0, 1, length.out = n_pieces + 1)
      pieces <- lapply(seq_len(n_pieces), function(i) {
        template$copy()$pointwise_become_partial(self, alphas[i], alphas[i + 1])
      })
      do.call(Group, pieces)
    },
    get_z_index_reference_point = function() {
      (if (!is.null(self$z_index_group)) self$z_index_group else self)$get_center()
    },
    has_points = function() nrow(self$points) > 0,
    has_no_points = function() !self$has_points(),
    throw_error_if_no_points = function() {
      if (self$has_no_points()) stop("Cannot call this method for a Mobject with no points", call. = FALSE)
    },

    # Matching -------------------------------------------------------------
    match_color = function(mobject) self$set_color(mobject$get_color()),
    match_dim_size = function(mobject, dim, ...) self$rescale_to_fit(mobject$length_over_dim(dim), dim, ...),
    match_width = function(mobject, ...) self$match_dim_size(mobject, 1, ...),
    match_height = function(mobject, ...) self$match_dim_size(mobject, 2, ...),
    match_depth = function(mobject, ...) self$match_dim_size(mobject, 3, ...),
    match_coord = function(mobject, dim, direction = ORIGIN) {
      self$set_coord(mobject$get_coord(dim, direction), dim, direction)
    },
    match_x = function(mobject, direction = ORIGIN) self$match_coord(mobject, 1, direction),
    match_y = function(mobject, direction = ORIGIN) self$match_coord(mobject, 2, direction),
    match_z = function(mobject, direction = ORIGIN) self$match_coord(mobject, 3, direction),
    align_to = function(mobject_or_point, direction = ORIGIN) {
      direction <- as_point(direction)
      point <- if (is_mobject(mobject_or_point)) mobject_or_point$get_critical_point(direction) else as_point(mobject_or_point)
      for (d in 1:3) if (direction[d] != 0) self$set_coord(point[d], d, direction)
      invisible(self)
    },

    # Family ---------------------------------------------------------------
    # The mobject and all its submobjects, depth first, each once (the last
    # occurrence is kept, as remove_list_redundancies() does). A mobject on
    # the current path is skipped, so cycles end, as upstream's _iter_family().
    # Upstream's get_*/set_* fallbacks for its size properties
    # (Mobject.__getattr__), which much existing code still uses.
    get_width = function() self$width,
    get_height = function() self$height,
    get_depth = function() self$depth,
    set_width = function(value) {
      self$width <- value
      invisible(self)
    },
    set_height = function(value) {
      self$height <- value
      invisible(self)
    },
    set_depth = function(value) {
      self$depth <- value
      invisible(self)
    },
    get_family = function(recurse = TRUE) {
      if (!length(self$submobjects)) return(list(self))
      fam <- iter_family(self, character())
      ids <- vapply(fam, function(m) m$mob_id, "")
      if (anyDuplicated(ids)) fam <- fam[!duplicated(ids, fromLast = TRUE)]
      fam
    },
    family_members_with_points = function() {
      Filter(function(m) nrow(m$points) > 0, self$get_family())
    },
    split = function() {
      res <- if (nrow(self$points) > 0) list(self) else list()
      c(res, self$submobjects)
    },
    get_group_class = function() Group,

    # Arrangement ----------------------------------------------------------
    arrange = function(direction = RIGHT, buff = DEFAULT_MOBJECT_TO_MOBJECT_BUFFER, center = TRUE, ...) {
      sm <- self$submobjects
      if (length(sm) > 1) for (i in 2:length(sm)) sm[[i]]$next_to(sm[[i - 1]], direction, buff, ...)
      if (center) self$center()
      invisible(self)
    },
    arrange_in_grid = function(rows = NULL, cols = NULL, buff = MED_SMALL_BUFF, cell_alignment = ORIGIN,
                               row_alignments = NULL, col_alignments = NULL, row_heights = NULL,
                               col_widths = NULL, flow_order = "rd") {
      arrange_in_grid_impl(self, rows, cols, buff, cell_alignment, row_alignments, col_alignments,
                           row_heights, col_widths, flow_order)
    },
    sort = function(point_to_num_func = function(p) p[1], submob_func = NULL) {
      if (is.null(submob_func)) submob_func <- function(m) point_to_num_func(m$get_center())
      keys <- vapply(self$submobjects, submob_func, numeric(1))
      self$submobjects <- self$submobjects[order(keys)]
      invisible(self)
    },
    shuffle = function(recursive = FALSE) {
      if (recursive) for (sm in self$submobjects) sm$shuffle(recursive = TRUE)
      self$submobjects <- self$submobjects[sample.int(length(self$submobjects))]
      invisible(self)
    },
    invert = function(recursive = FALSE) {
      if (recursive) for (sm in self$submobjects) sm$invert(recursive = TRUE)
      self$submobjects <- rev(self$submobjects)
      invisible(self)
    },
    arrange_submobjects = function(...) self$arrange(...),
    sort_submobjects = function(...) self$sort(...),
    shuffle_submobjects = function(...) self$shuffle(...),

    # Alignment for animations ---------------------------------------------
    align_data = function(mobject, skip_point_alignment = FALSE) {
      self$null_point_align(mobject)
      self$align_submobjects(mobject)
      if (!skip_point_alignment) self$align_points(mobject)
      s1 <- self$submobjects
      s2 <- mobject$submobjects
      for (i in seq_along(s1)) s1[[i]]$align_data(s2[[i]])
      invisible(self)
    },
    get_point_mobject = function(center = NULL) stop("get_point_mobject not implemented for ", class(self)[1], call. = FALSE),
    align_points = function(mobject) {
      n1 <- self$get_num_points()
      n2 <- mobject$get_num_points()
      if (n1 < n2) self$align_points_with_larger(mobject)
      else if (n2 < n1) mobject$align_points_with_larger(self)
      invisible(self)
    },
    align_points_with_larger = function(larger_mobject) stop("Not implemented", call. = FALSE),
    align_submobjects = function(mobject) {
      n1 <- length(self$submobjects)
      n2 <- length(mobject$submobjects)
      self$add_n_more_submobjects(max(0, n2 - n1))
      mobject$add_n_more_submobjects(max(0, n1 - n2))
      invisible(self)
    },
    null_point_align = function(mobject) {
      if (self$has_no_points() && mobject$has_points()) mobject$push_self_into_submobjects()
      if (mobject$has_no_points() && self$has_points()) self$push_self_into_submobjects()
      invisible(self)
    },
    push_self_into_submobjects = function() {
      cp <- self$copy()
      cp$submobjects <- list()
      self$reset_points()
      self$add(cp)
      invisible(self)
    },
    add_n_more_submobjects = function(n) {
      if (n == 0) return(invisible(NULL))
      curr <- length(self$submobjects)
      if (curr == 0) {
        self$submobjects <- lapply(seq_len(n), function(k) self$get_point_mobject())
        return(invisible(NULL))
      }
      target <- curr + n
      repeat_indices <- ((0:(target - 1)) * curr) %/% target
      split_factors <- tabulate(repeat_indices + 1, nbins = curr)
      new_sub <- list()
      for (i in seq_len(curr)) {
        sm <- self$submobjects[[i]]
        new_sub[[length(new_sub) + 1]] <- sm
        if (split_factors[i] > 1) {
          for (k in 2:split_factors[i]) new_sub[[length(new_sub) + 1]] <- sm$copy()$fade(1)
        }
      }
      self$submobjects <- new_sub
      invisible(self)
    },
    repeat_submobject = function(submob) submob$copy(),
    interpolate = function(mobject1, mobject2, alpha, path_func = straight_path()) {
      self$points <- path_func(mobject1$points, mobject2$points, alpha)
      self$interpolate_color(mobject1, mobject2, alpha)
      invisible(self)
    },
    interpolate_color = function(mobject1, mobject2, alpha) invisible(self),
    become = function(mobject, match_height = FALSE, match_width = FALSE, match_depth = FALSE,
                      match_center = FALSE, stretch = FALSE) {
      if (stretch || match_height || match_width || match_depth || match_center) {
        mobject <- mobject$copy()
        if (stretch) {
          mobject$stretch_to_fit_height(self$height)
          mobject$stretch_to_fit_width(self$width)
          mobject$stretch_to_fit_depth(self$depth)
        } else {
          if (match_height) mobject$match_height(self)
          if (match_width) mobject$match_width(self)
          if (match_depth) mobject$match_depth(self)
        }
        if (match_center) mobject$move_to(self$get_center())
      }
      self$align_data(mobject, skip_point_alignment = TRUE)
      f1 <- self$get_family()
      f2 <- mobject$get_family()
      for (i in seq_along(f1)) {
        f1[[i]]$points <- f2[[i]]$points
        f1[[i]]$interpolate_color(f1[[i]], f2[[i]], 1)
      }
      invisible(self)
    },
    match_points = function(mobject, copy_submobjects = TRUE) {
      f1 <- self$get_family()
      f2 <- mobject$get_family()
      for (i in seq_len(min(length(f1), length(f2)))) f1[[i]]$points <- f2[[i]]$points
      invisible(self)
    },
    pointwise_become_partial = function(mobject, a, b) invisible(self),
    set_z_index = function(z_index_value, family = TRUE) {
      if (family) for (sm in self$submobjects) sm$set_z_index(z_index_value, family)
      self$z_index <- z_index_value
      invisible(self)
    },
    set_z_index_by_z_Point3D = function() {
      z <- self$get_center()[3]
      self$set_z_index(z)
    },

    # Display --------------------------------------------------------------
    get_image = function(...) render_mobject_image(self, ...),
    show = function(...) {
      plot.Mobject(self, ...)
      invisible(self)
    },
    save_image = function(file, ...) {
      write_mobject_png(self, file, ...)
      invisible(self)
    }
  ),
  active = list(
    width = function(value) {
      if (missing(value)) return(self$length_over_dim(1))
      self$scale_to_fit_width(value)
    },
    height = function(value) {
      if (missing(value)) return(self$length_over_dim(2))
      self$scale_to_fit_height(value)
    },
    depth = function(value) {
      if (missing(value)) return(self$length_over_dim(3))
      self$scale_to_fit_depth(value)
    },
    animate = function(value) {
      if (!missing(value)) stop("animate is read-only", call. = FALSE)
      animation_builder(self)
    },
    always = function(value) {
      if (!missing(value)) stop("always is read-only", call. = FALSE)
      updater_builder(self)
    }
  )
)

# Names of public data fields (not methods or active bindings) of an R6 object.
mobject_fields <- function(obj) {
  setdiff(ls(obj, all.names = TRUE),
          c(nonfield_names(obj), ".__enclos_env__", ".__active__", "points", "updaters", "mob_id", "color", "name"))
}

# Method and active binding names of an object's class, cached per class.
nonfield_names <- function(obj) {
  key <- paste(class(obj), collapse = "/")
  if (is.null(.manim$nonfield_cache)) .manim$nonfield_cache <- new.env(parent = emptyenv())
  hit <- .manim$nonfield_cache[[key]]
  if (is.null(hit)) {
    nms <- ls(obj, all.names = TRUE)
    nms <- setdiff(nms, c(".__enclos_env__", ".__active__"))
    is_nonfield <- vapply(nms, function(n) {
      bindingIsActive(n, obj) || is.function(get(n, envir = obj, inherits = FALSE))
    }, logical(1))
    hit <- nms[is_nonfield]
    assign(key, hit, envir = .manim$nonfield_cache)
  }
  hit
}

# Apply a point function row by row; func takes and returns length 3 vectors.
apply_rowwise <- function(points, func) {
  if (nrow(points) == 0) return(points)
  out <- t(apply(points, 1, function(p) as_point(func(p))))
  if (nrow(points) == 1) out <- matrix(out, 1)
  out
}

# Flatten nested lists of mobjects.
flatten_mobjects <- function(x) {
  out <- list()
  for (el in x) {
    if (is_mobject(el)) out[[length(out) + 1]] <- el
    else if (is.list(el)) out <- c(out, flatten_mobjects(el))
    else if (!is.null(el)) stop("Expected Mobjects, got ", class(el)[1], call. = FALSE)
  }
  out
}

#' Group of mobjects
#'
#' `Group()` groups any mobjects; [VGroup()] groups vectorized mobjects.
#'
#' @param ... Mobjects (or lists of mobjects) to group.
#' @param color Color of the group.
#' @param name Name of the group; defaults to the class name.
#' @param z_index Drawing order; higher values are drawn on top.
#' @export
GroupClass <-R6::R6Class("Group", inherit = MobjectClass, lock_objects = FALSE,
  public = list(
    initialize = function(..., color = "#FFFFFF", name = NULL, z_index = 0) {
      super$initialize(color = color, name = name, z_index = z_index)
      self$add(...)
    },
    get_point_mobject = function(center = NULL) {
      PointClass$new(location = center %||% self$get_center())
    }
  )
)

#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @rdname GroupClass
#' @export
Group <- constructor(GroupClass)
#' Index submobjects
#'
#' `mob[i]` returns the i-th submobject (1 based). A vector index returns a
#' group of the selected submobjects.
#'
#' A character key looks up an entry of a [VDict] (`vd["square"]`, or several
#' entries as a group with `vd[c("a", "b")]`) or a vertex of a [Graph]
#' (`g["a"]`, or `g[c("a", "b")]` for an edge), as upstream's
#' `vdict["square"]` and `g["a"]` do; an unknown key is an error.
#' `vd["square"] <- Square()` adds or replaces an entry. With `[[`, a
#' character key returns the field or method of that name when there is one,
#' as for any environment, and otherwise the dictionary entry or vertex.
#'
#' `mob$name` reads a field or method. As upstream's compatibility layer, an
#' unknown `mob$get_x()` returns the field `x` and an unknown
#' `mob$set_x(value)` sets it, each with a deprecation warning; other unknown
#' names give `NULL`, as for any environment.
#'
#' @param x A mobject.
#' @param i Index.
#' @param ... Ignored.
#' @export
`[.Mobject` <- function(x, i, ...) {
  if (is.character(i)) {
    if (!inherits(x, c("VDict", "GenericGraph"))) stop("Character indices need a VDict or a Graph", call. = FALSE)
    return(x$get(if (length(i) > 1) as.list(i) else i))
  }
  # As upstream, a mobject with points of its own comes first, then its
  # submobjects (Mobject.split()).
  sm <- x$split()
  if (is.logical(i)) i <- which(rep_len(i, length(sm)))
  if (length(i) == 1 && i > 0) return(sm[[i]])
  sel <- sm[i]
  gen <- x$get_group_class()
  do.call(gen, sel)
}

#' @return `[` returns a submobject, or a group of them for a vector index.
#'   `[[` returns a submobject, a field or an entry. `length()` returns the
#'   number of submobjects, plus one when the mobject has points of its own.
#'   The assignment forms return the changed mobject; `mob[[i]] <- value` with
#'   a position does what `mob[i] <- value` does. `$` returns the field or
#'   method, or the generated getter or setter function.
#' @rdname sub-.Mobject
#' @param value A mobject to store under key `i` of a [VDict].
#' @export
`[<-.Mobject` <- function(x, i, value) {
  # A group member by position, as upstream's VGroup.__setitem__.
  if (is.numeric(i) && length(i) == 1 && inherits(x, c("VGroup", "Group")) && !inherits(x, "VDict")) {
    if (!is_mobject(value)) stop("Only a mobject can be put into a group", call. = FALSE)
    x$submobjects[[i]] <- value
    return(x)
  }
  if (!inherits(x, "VDict") || !is.character(i) || length(i) != 1) {
    stop("Only a group member (vg[2] <- mobject) or a VDict entry (vd[\"key\"] <- mobject) can be assigned ",
         "with [<-", call. = FALSE)
  }
  # Replaces the value of an existing key, as upstream's __setitem__.
  if (x$has_key(i)) x$remove(i)
  x$add_key_value_pair(i, value)
  x
}

#' @rdname sub-.Mobject
#' @export
`[[<-.Mobject` <- function(x, i, value) {
  if (is.numeric(i)) return(`[<-.Mobject`(x, i, value))
  if (inherits(x, "VDict") && is.character(i) && length(i) == 1 && !exists(i, envir = x, inherits = FALSE)) {
    if (x$has_key(i)) x$remove(i)
    x$add_key_value_pair(i, value)
    return(x)
  }
  # Anything else sets a field, as for any R6 object.
  assign(i, value, envir = x)
  x
}

#' @rdname sub-.Mobject
#' @export
length.Mobject <- function(x) length(x$submobjects) + (nrow(x$points) > 0)

#' @export
`+.Mobject` <- function(e1, e2) {
  # As upstream, only a VGroup adds (VGroup.__add__ gives a new VGroup with one
  # more member); Mobject.__add__ raises NotImplementedError.
  if (!missing(e2) && inherits(e1, "VGroup") && !inherits(e1, "VDict")) {
    return(do.call(VGroup, c(e1$submobjects, list(e2))))
  }
  stop("NotImplementedError: `+` needs a VGroup on the left; use Group() or $add() to group mobjects",
       call. = FALSE)
}

#' @export
`-.Mobject` <- function(e1, e2) {
  # VGroup.__sub__ gives a new VGroup without the member; Mobject.__sub__ raises.
  if (!missing(e2) && inherits(e1, "VGroup") && !inherits(e1, "VDict")) {
    out <- do.call(VGroup, e1$submobjects)
    out$remove(e2)
    return(out)
  }
  stop("NotImplementedError: `-` needs a VGroup on the left; use $remove() to take a member out", call. = FALSE)
}

# As upstream's Mobject.__iter__: the mobject itself first when it has points,
# then its submobjects.
#' @export
as.list.Mobject <- function(x, ...) x$split()

# Port of Mobject.arrange_in_grid. Indices r and c are 0 based as upstream.
arrange_in_grid_impl <- function(self, rows, cols, buff, cell_alignment, row_alignments, col_alignments,
                                 row_heights, col_widths, flow_order) {
  mobs <- self$submobjects
  start_pos <- self$get_center()
  init_size <- function(num, alignments, sizes) {
    if (!is.null(num)) return(num)
    if (!is.null(alignments)) return(nchar(alignments))
    if (!is.null(sizes)) return(length(sizes))
    NULL
  }
  cols <- init_size(cols, col_alignments, col_widths)
  rows <- init_size(rows, row_alignments, row_heights)
  n <- length(mobs)
  if (is.null(rows) && is.null(cols)) cols <- ceiling(sqrt(n))
  if (is.null(rows)) rows <- ceiling(n / cols)
  if (is.null(cols)) cols <- ceiling(n / rows)
  if (rows * cols < n) stop("Too few rows and columns to fit all submobjects.", call. = FALSE)
  buff_x <- buff[1]
  buff_y <- buff[length(buff)]
  cell_alignment <- as_point(cell_alignment)
  init_alignments <- function(alignments, num, map, name, dir) {
    if (is.null(alignments)) return(rep(list(cell_alignment * dir), num))
    chars <- strsplit(alignments, "")[[1]]
    if (length(chars) != num) stop(name, "_alignments has a mismatching size.", call. = FALSE)
    lapply(chars, function(ch) map[[ch]])
  }
  row_dirs <- init_alignments(row_alignments, rows, list(u = UP, c = ORIGIN, d = DOWN), "row", RIGHT)
  col_dirs <- init_alignments(col_alignments, cols, list(l = LEFT, c = ORIGIN, r = RIGHT), "col", UP)
  mapper <- list(
    dr = function(r, c) (rows - r - 1) + c * rows,
    dl = function(r, c) (rows - r - 1) + (cols - c - 1) * rows,
    ur = function(r, c) r + c * rows,
    ul = function(r, c) r + (cols - c - 1) * rows,
    rd = function(r, c) (rows - r - 1) * cols + c,
    ld = function(r, c) (rows - r - 1) * cols + (cols - c - 1),
    ru = function(r, c) r * cols + c,
    lu = function(r, c) r * cols + (cols - c - 1)
  )
  idx_fun <- mapper[[flow_order]]
  if (is.null(idx_fun)) stop('flow_order must be one of "dr", "rd", "ld", "dl", "ru", "ur", "lu", "ul".', call. = FALSE)
  row_dirs <- rev(row_dirs)
  row_heights <- rev(as.list(row_heights))
  col_widths <- as.list(col_widths)
  placeholder <- MobjectClass$new()
  mobs <- c(mobs, rep(list(placeholder), rows * cols - n))
  grid <- lapply(0:(rows - 1), function(r) lapply(0:(cols - 1), function(c) mobs[[idx_fun(r, c) + 1]]))
  measured_h <- vapply(seq_len(rows), function(r) max(vapply(grid[[r]], function(m) m$height, 0)), 0)
  measured_w <- vapply(seq_len(cols), function(c) max(vapply(seq_len(rows), function(r) grid[[r]][[c]]$width, 0)), 0)
  init_sizes <- function(sizes, num, measures, name) {
    if (length(sizes) == 0) sizes <- rep(list(NULL), num)
    if (length(sizes) != num) stop(name, " has a mismatching size.", call. = FALSE)
    vapply(seq_len(num), function(i) if (is.null(sizes[[i]])) measures[i] else sizes[[i]], 0)
  }
  heights <- init_sizes(row_heights, rows, measured_h, "row_heights")
  widths <- init_sizes(col_widths, cols, measured_w, "col_widths")
  y <- 0
  for (r in seq_len(rows)) {
    x <- 0
    for (c in seq_len(cols)) {
      m <- grid[[r]][[c]]
      if (!identical(m$mob_id, placeholder$mob_id)) {
        alignment <- row_dirs[[r]] + col_dirs[[c]]
        line <- Line(x * RIGHT + y * UP, (x + widths[c]) * RIGHT + (y + heights[r]) * UP)
        m$move_to(line, alignment)
      }
      x <- x + widths[c] + buff_x
    }
    y <- y + heights[r] + buff_y
  }
  self$move_to(start_pos)
  invisible(self)
}

#' @rdname sub-.Mobject
#' @export
`[[.Mobject` <- function(x, i, ...) {
  if (is.numeric(i)) return(.subset2(x, "submobjects")[[i]])
  if (is.character(i) && length(i) == 1 && !exists(i, envir = x, inherits = FALSE)) {
    dict <- if (inherits(x, "VDict")) .subset2(x, "submob_dict") else if (inherits(x, "GenericGraph")) .subset2(x, "vertices")
    if (!is.null(dict) && i %in% names(dict)) return(dict[[i]])
  }
  .subset2(x, i)
}

#' @rdname sub-.Mobject
#' @param name A field or method name.
#' @export
`$.Mobject` <- function(x, name) {
  v <- .subset2(x, name)
  if (!is.null(v) || !(startsWith(name, "get_") || startsWith(name, "set_")) || exists(name, envir = x, inherits = FALSE)) {
    return(v)
  }
  # Upstream's Mobject.__getattr__ compatibility layer: an unknown get_x()
  # reads the field x and an unknown set_x(value) sets it, with a
  # deprecation warning.
  field <- substring(name, 5)
  if (startsWith(name, "get_")) {
    return(function() {
      warning(warningCondition("This method is not guaranteed to stay around. Please prefer getting the attribute normally.",
                               class = "deprecatedWarning"))
      if (!exists(field, envir = x, inherits = FALSE)) {
        stop(class(x)[1], " object has no attribute '", field, "'", call. = FALSE)
      }
      .subset2(x, field)
    })
  }
  function(value) {
    warning(warningCondition(paste("This method is not guaranteed to stay around. Please prefer setting the attribute",
                                   "normally or with Mobject.set()."), class = "deprecatedWarning"))
    assign(field, value, envir = x)
    invisible(x)
  }
}

iter_family <- function(m, active) {
  if (m$mob_id %in% active) return(list())
  active <- c(active, m$mob_id)
  c(list(m), unlist(lapply(m$submobjects, iter_family, active = active), recursive = FALSE))
}

# Copies the mobjects and animations in `x`, at any depth of nested lists,
# through the shared memo of a deep copy.
copy_nested <- function(x, memo) {
  if (is_mobject(x) || inherits(x, "Animation")) return(x$copy(memo))
  if (is.list(x) && length(x) && !is.data.frame(x) && !is.environment(x)) {
    y <- lapply(x, copy_nested, memo = memo)
    attributes(y) <- attributes(x)
    return(y)
  }
  x
}

# Copies the mobjects and animations held in the private fields of `old`
# into the private fields of its clone `new` through the same memo, so a
# private reference to a submobject points to the copy's submobject, as with
# Python's deepcopy of every instance attribute.
copy_private_nested <- function(old, new, memo) {
  op <- .subset2(old, ".__enclos_env__")$private
  np <- .subset2(new, ".__enclos_env__")$private
  if (!is.environment(op) || !is.environment(np)) return(invisible(NULL))
  for (nm in ls(op, all.names = TRUE)) {
    if (bindingIsActive(nm, op) || !exists(nm, envir = np, inherits = FALSE) || bindingIsLocked(nm, np)) next
    v <- get(nm, envir = op, inherits = FALSE)
    if (is_mobject(v) || inherits(v, "Animation") || (is.list(v) && length(v) && !is.data.frame(v))) {
      assign(nm, copy_nested(v, memo), envir = np)
    }
  }
  invisible(NULL)
}
