# Methods of upstream's OpenGL mobject classes (manim/mobject/opengl/) that
# the Cairo classes do not have. manimR's OpenGL classes are subclasses of
# their Cairo counterparts (zz_opengl_mobjects.R). Each one also gets the
# methods below of its upstream OpenGL ancestors, root first, so that a
# subclass overrides its base, and only where the Cairo parent has no member
# of that name.
#
# The data model is manimR's: points, colors and widths are fields, and
# upstream's `data` arrays are read from them (`rgbas` of a plain mobject,
# `fill_rgba` and `stroke_rgba` of a VMobject are its color rows). manimR
# keeps no bounding box cache, no parents list and no cached family, so
# refresh_bounding_box(), assemble_family() and refresh_triangulation() have
# nothing to refresh and return the mobject.

# Writes rows of `value` into one attribute of shader data, a single row
# being repeated for every vertex as numpy broadcasting does.
opengl_fill_shader_field <- function(sd, key, value) {
  width <- attr(sd, "dtype")[[key]]
  m <- matrix(as.numeric(value), ncol = width)
  n <- length(sd)
  if (nrow(m) == 1 && n != 1) m <- m[rep(1, n), , drop = FALSE]
  assign(key, m, envir = sd)
}

# The quadratic Bezier points upstream's OpenGL shaders read: each cubic curve
# of a manimR VMobject becomes two quadratic curves (three points each).
opengl_quadratic_points <- function(vmob) {
  pts <- vmob$points
  n <- nrow(pts) - nrow(pts) %% 4
  if (n == 0) return(matrix(0, 0, 3))
  i <- seq(1, n, by = 4)
  q <- get_quadratic_approximation_of_cubic(pts[i, , drop = FALSE], pts[i + 1, , drop = FALSE],
                                            pts[i + 2, , drop = FALSE], pts[i + 3, , drop = FALSE])
  q
}

LINE_JOINT_TYPE_VALUES <- c(auto = 0, round = 1, bevel = 2, miter = 3)

# Shader data methods of upstream's OpenGLMobject.
opengl_mobject_shader_methods <- list(
  shader_dtype = c(point = 3),
  shader_folder = "",
  texture_paths = NULL,
  render_primitive = 4L,
  check_data_alignment = function(array, data_key) {
    value <- .subset2(self, data_key)
    d_len <- if (is.matrix(value)) nrow(value) else length(value)
    if (d_len != 1 && d_len != length(array)) {
      self$set_data(stats::setNames(list(resize_with_interpolation(value, length(array))), data_key))
    }
    invisible(self)
  },
  get_resized_shader_data_array = function(length) shader_data(self$shader_dtype, nrow(self$points)),
  read_data_to_shader = function(shader_data, shader_data_key, data_key) {
    if (data_key %in% self$locked_data_keys) return(invisible(self))
    self$check_data_alignment(shader_data, data_key)
    opengl_fill_shader_field(shader_data, shader_data_key, .subset2(self, data_key))
    invisible(self)
  },
  get_shader_data = function() {
    sd <- self$get_resized_shader_data_array(self$get_num_points())
    self$read_data_to_shader(sd, "point", "points")
    sd
  },
  refresh_shader_data = function() {
    self$get_shader_data()
    invisible(self)
  },
  get_shader_wrapper = function() {
    self$shader_wrapper <- ShaderWrapper(vert_data = self$get_shader_data(), vert_indices = self$get_shader_vert_indices(),
                                         uniforms = self$get_shader_uniforms(), depth_test = self$depth_test,
                                         texture_paths = self$texture_paths, render_primitive = self$render_primitive,
                                         shader_folder = self$shader_folder)
    self$shader_wrapper
  },
  get_shader_wrapper_list = function() {
    wrappers <- c(list(self$get_shader_wrapper()), unlist(lapply(self$submobjects, function(sm) {
      if (exists("get_shader_wrapper_list", envir = sm, inherits = FALSE)) sm$get_shader_wrapper_list()
    }), recursive = FALSE))
    result <- list()
    for (batch in batch_by_property(wrappers, function(sw) sw$get_id())) {
      group <- batch[[1]]
      first <- group[[1]]
      if (!first$is_valid()) next
      do.call(first$combine_with, group[-1])
      if (length(first$vert_data) > 0) result[[length(result) + 1]] <- first
    }
    result
  },
  refresh_shader_wrapper_id = function() {
    self$get_shader_wrapper()$refresh_id()
    invisible(self)
  },
  replace_shader_code = function(old_code, new_code) {
    for (wrapper in self$get_shader_wrapper_list()) wrapper$replace_code(old_code, new_code)
    invisible(self)
  },
  set_color_by_code = function(glsl_code) {
    self$replace_shader_code("///// INSERT COLOR FUNCTION HERE /////", glsl_code)
    invisible(self)
  },
  set_color_by_xyz_func = function(glsl_snippet, min_value = -5, max_value = 5, colormap = "viridis") {
    for (ch in c("x", "y", "z")) glsl_snippet <- gsub(ch, paste0("point.", ch), glsl_snippet, fixed = TRUE)
    rgb_list <- t(grDevices::col2rgb(grDevices::hcl.colors(9, colormap)) / 255)
    self$set_color_by_code(sprintf("color.rgb = float_to_color(%s, %s, %s, %s);", glsl_snippet, format(as.numeric(min_value)),
                                   format(as.numeric(max_value)), get_colormap_code(rgb_list)))
    invisible(self)
  }
)

# Shader data methods of upstream's OpenGLVMobject.
opengl_vmobject_shader_methods <- list(
  fill_dtype = c(point = 3, unit_normal = 3, color = 4, vert_index = 1),
  stroke_dtype = c(point = 3, prev_point = 3, next_point = 3, unit_normal = 3, stroke_width = 1, color = 4),
  stroke_shader_folder = "quadratic_bezier_stroke",
  fill_shader_folder = "quadratic_bezier_fill",
  draw_stroke_behind_fill = FALSE,
  fill_data = NULL,
  stroke_data = NULL,
  fill_shader_wrapper = NULL,
  stroke_shader_wrapper = NULL,
  init_shader_data = function() {
    self$fill_data <- shader_data(self$fill_dtype, 0)
    self$stroke_data <- shader_data(self$stroke_dtype, 0)
    self$fill_shader_wrapper <- ShaderWrapper(vert_data = self$fill_data, vert_indices = integer(),
                                              shader_folder = self$fill_shader_folder,
                                              render_primitive = self$render_primitive)
    self$stroke_shader_wrapper <- ShaderWrapper(vert_data = self$stroke_data, shader_folder = self$stroke_shader_folder,
                                                render_primitive = self$render_primitive)
    invisible(self)
  },
  refresh_shader_wrapper_id = function() {
    if (is.null(self$fill_shader_wrapper)) self$init_shader_data()
    self$fill_shader_wrapper$refresh_id()
    self$stroke_shader_wrapper$refresh_id()
    invisible(self)
  },
  get_fill_shader_wrapper = function() {
    self$update_fill_shader_wrapper()
    self$fill_shader_wrapper
  },
  update_fill_shader_wrapper = function() {
    if (is.null(self$fill_shader_wrapper)) self$init_shader_data()
    w <- self$fill_shader_wrapper
    w$vert_data <- self$get_fill_shader_data()
    w$vert_indices <- self$get_triangulation()
    w$uniforms <- self$get_fill_uniforms()
    w$depth_test <- self$depth_test
    invisible(self)
  },
  get_stroke_shader_wrapper = function() {
    self$update_stroke_shader_wrapper()
    self$stroke_shader_wrapper
  },
  update_stroke_shader_wrapper = function() {
    if (is.null(self$stroke_shader_wrapper)) self$init_shader_data()
    w <- self$stroke_shader_wrapper
    w$vert_data <- self$get_stroke_shader_data()
    w$uniforms <- self$get_stroke_uniforms()
    w$depth_test <- self$depth_test
    invisible(self)
  },
  get_shader_wrapper_list = function() {
    fills <- list()
    strokes <- list()
    backs <- list()
    for (sm in self$family_members_with_points()) {
      if (!exists("get_fill_shader_wrapper", envir = sm, inherits = FALSE)) next
      if (sm$has_fill() && !isTRUE(cfg("use_projection_fill_shaders"))) fills[[length(fills) + 1]] <- sm$get_fill_shader_wrapper()
      if (sm$has_stroke() && !isTRUE(cfg("use_projection_stroke_shaders"))) {
        ssw <- sm$get_stroke_shader_wrapper()
        if (isTRUE(sm$draw_stroke_behind_fill)) backs[[length(backs) + 1]] <- ssw else strokes[[length(strokes) + 1]] <- ssw
      }
    }
    result <- list()
    for (wlist in list(backs, fills, strokes)) {
      if (!length(wlist)) next
      wrapper <- wlist[[1]]
      do.call(wrapper$combine_with, wlist[-1])
      result[[length(result) + 1]] <- wrapper
    }
    result
  },
  get_stroke_uniforms = function() {
    c(self$get_shader_uniforms(), list(joint_type = unname(LINE_JOINT_TYPE_VALUES[tolower(self$joint_type %||% "auto")]),
                                      flat_stroke = as.numeric(isTRUE(self$flat_stroke))))
  },
  get_fill_uniforms = function() {
    list(is_fixed_in_frame = as.numeric(self$is_fixed_in_frame), is_fixed_orientation = as.numeric(self$is_fixed_orientation),
         fixed_orientation_center = self$fixed_orientation_center, gloss = self$gloss, shadow = self$shadow)
  },
  # The point attributes come from the quadratic form of the points (see
  # opengl_quadratic_points()); the colors, widths and normal are read as
  # upstream reads them.
  get_stroke_shader_data = function() {
    points <- opengl_quadratic_points(self)
    n <- nrow(points)
    if (is.null(self$stroke_data) || length(self$stroke_data) != n) self$stroke_data <- shader_data(self$stroke_dtype, n)
    sd <- self$stroke_data
    if (!"points" %in% self$locked_data_keys && n > 0) {
      nppc <- 3
      assign("point", points, envir = sd)
      assign("prev_point", rbind(points[(n - nppc + 1):n, , drop = FALSE], points[seq_len(n - nppc), , drop = FALSE]), envir = sd)
      assign("next_point", rbind(points[-seq_len(nppc), , drop = FALSE], points[seq_len(nppc), , drop = FALSE]), envir = sd)
    }
    self$read_data_to_shader(sd, "color", "stroke_rgba")
    self$read_data_to_shader(sd, "stroke_width", "stroke_width")
    self$read_data_to_shader(sd, "unit_normal", "unit_normal")
    sd
  },
  get_fill_shader_data = function() {
    points <- opengl_quadratic_points(self)
    n <- nrow(points)
    if (is.null(self$fill_data) || length(self$fill_data) != n) {
      self$fill_data <- shader_data(self$fill_dtype, n)
      assign("vert_index", matrix(seq_len(n) - 1, n, 1), envir = self$fill_data)
    }
    sd <- self$fill_data
    if (!"points" %in% self$locked_data_keys) assign("point", points, envir = sd)
    self$read_data_to_shader(sd, "color", "fill_rgba")
    self$read_data_to_shader(sd, "unit_normal", "unit_normal")
    sd
  },
  refresh_shader_data = function() {
    self$get_fill_shader_data()
    self$get_stroke_shader_data()
    invisible(self)
  },
  get_fill_shader_vert_indices = function() self$get_triangulation(),
  # Upstream's triangulation of the fill, on the quadratic points: 0 based
  # vertex indices, every curve's own triangle followed by the ear clipped
  # triangles of the inner polygon.
  get_triangulation = function(normal_vector = NULL) {
    normal_vector <- normal_vector %||% self$get_unit_normal()
    points <- opengl_quadratic_points(self)
    if (nrow(points) <= 1) return(integer())
    if (!isTRUE(all(abs(normal_vector - OUT) < 1e-8))) points <- points %*% z_to_vector(normal_vector)
    n <- nrow(points)
    indices <- seq_len(n) - 1L
    i0 <- seq(1, n, by = 3)
    b0 <- points[i0, , drop = FALSE]
    b1 <- points[i0 + 1, , drop = FALSE]
    b2 <- points[i0 + 2, , drop = FALSE]
    convexities <- sign(cross2d(b1 - b0, b2 - b1))
    atol <- self$tolerance_for_point_equality
    k <- nrow(b0)
    end_of_loop <- logical(k)
    if (k > 1) end_of_loop[-k] <- apply(abs(b2[-k, , drop = FALSE] - b0[-1, , drop = FALSE]) > atol, 1, any)
    end_of_loop[k] <- TRUE
    inner <- sort(c(indices[i0], indices[i0 + 1][convexities < 0], indices[i0 + 2][end_of_loop]))
    rings <- seq_along(inner)[inner %% 3 == 2]
    tri <- earclip_triangulation(points[inner + 1, , drop = FALSE], rings)
    c(indices, inner[tri])
  }
)


opengl_bounding_box <- function(points) {
  if (!nrow(points)) return(matrix(0, 3, 3))
  mins <- apply(points, 2, min)
  maxs <- apply(points, 2, max)
  unname(rbind(mins, (mins + maxs) / 2, maxs))
}

# The data arrays of a mobject, as upstream's OpenGLMobject.data.
opengl_data <- function(mob) {
  keys <- if (inherits(mob, "VMobject")) c("points", "bounding_box", "fill_rgba", "stroke_rgba", "stroke_width", "unit_normal")
          else c("points", "bounding_box", "rgbas")
  stats::setNames(lapply(keys, function(k) .subset2(mob, k)), keys)
}

OPENGL_MOBJECT_METHODS <- list(
  public = list(
    gloss = 0,
    shadow = 0,
    depth_test = FALSE,
    is_fixed_in_frame = 0,
    is_fixed_orientation = 0,
    fixed_orientation_center = c(0, 0, 0),
    model_matrix = diag(4),
    parent = NULL,
    locked_data_keys = character(),
    shader_indices = NULL,
    has_updaters = FALSE,
    init_data = function() {
      self$points <- matrix(0, 0, 3)
      self$rgbas <- matrix(0, 1, 4)
      invisible(self)
    },
    set_data = function(data) {
      for (key in names(data)) assign(key, data[[key]], envir = self)
      invisible(self)
    },
    set_uniforms = function(uniforms) {
      for (key in names(uniforms)) assign(key, uniforms[[key]], envir = self)
      invisible(self)
    },
    resize_points = function(new_length, resize_func = resize_array) {
      if (new_length != nrow(self$points)) self$points <- resize_func(self$points, new_length)
      invisible(self)
    },
    set_points = function(points) {
      self$points <- as_points(points)
      invisible(self)
    },
    append_points = function(new_points) {
      self$points <- rbind(self$points, as_points(new_points))
      invisible(self)
    },
    apply_points_function = function(func, about_point = NULL, about_edge = ORIGIN, works_on_bounding_box = FALSE) {
      if (is.null(about_point) && !is.null(about_edge)) about_point <- self$get_bounding_box_point(about_edge)
      for (mob in self$get_family()) {
        if (!mob$has_points()) next
        if (is.null(about_point)) {
          mob$points <- func(mob$points)
        } else {
          shifted <- sweep(mob$points, 2, as_point(about_point))
          mob$points <- sweep(func(shifted), 2, as_point(about_point), "+")
        }
      }
      invisible(self)
    },
    clear_points = function() {
      self$points <- matrix(0, 0, 3)
      invisible(self)
    },
    get_bounding_box = function() self$compute_bounding_box(),
    compute_bounding_box = function() {
      pts <- do.call(rbind, c(list(self$points), lapply(self$get_family()[-1], function(m) m$points)))
      opengl_bounding_box(pts)
    },
    refresh_bounding_box = function(recurse_down = FALSE, recurse_up = TRUE) invisible(self),
    is_point_touching = function(point, buff = MED_SMALL_BUFF) {
      bb <- self$get_bounding_box()
      point <- as_point(point)
      all(point >= bb[1, ] - buff) && all(point <= bb[3, ] + buff)
    },
    assemble_family = function() invisible(self),
    replace_submobject = function(index, new_submob) {
      old <- self$submobjects[[index]]
      if (identical(old, new_submob)) return(invisible(self))
      existing <- which(vapply(self$submobjects, identical, NA, new_submob))
      self$submobjects[[index]] <- new_submob
      if (length(existing)) self$submobjects[[existing[1]]] <- NULL
      invisible(self)
    },
    get_grid = function(n_rows, n_cols, height = NULL, ...) {
      grid <- self$duplicate(n_rows * n_cols)
      grid$arrange_in_grid(n_rows, n_cols, ...)
      if (!is.null(height)) grid$set_height(height)
      grid
    },
    duplicate = function(n) do.call(self$get_group_class(), lapply(seq_len(n), function(i) self$copy())),
    deepcopy = function() self$copy(),
    init_updaters = function() {
      self$updaters <- list()
      self$has_updaters <- FALSE
      self$updating_suspended <- FALSE
      invisible(self)
    },
    refresh_has_updater_status = function() {
      self$has_updaters <- any(vapply(self$get_family(), function(m) length(m$get_updaters()) > 0, NA))
      invisible(self)
    },
    hierarchical_model_matrix = function() {
      matrices <- list()
      mob <- self
      while (!is.null(mob)) {
        matrices <- c(list(mob$model_matrix %||% diag(4)), matrices)
        mob <- mob$parent
      }
      Reduce(`%*%`, matrices)
    },
    wag = function(direction = RIGHT, axis = DOWN, wag_factor = 1) {
      for (mob in self$family_members_with_points()) {
        alphas <- as.numeric(mob$points %*% as_point(axis))
        alphas <- alphas - min(alphas)
        alphas <- (alphas / max(alphas))^wag_factor
        mob$set_points(mob$points + outer(alphas, as_point(direction)))
      }
      invisible(self)
    },
    set_rgba_array = function(color = NULL, opacity = NULL, name = "rgbas", recurse = TRUE) {
      rgbs <- if (!is.null(color)) do.call(rbind, lapply(listify(color), color_to_rgb))
      opacities <- if (!is.null(opacity)) unlist(listify(opacity))
      for (mob in self$get_family(recurse)) {
        current <- .subset2(mob, name) %||% matrix(0, 1, 4)
        if (!is.null(rgbs) && is.null(opacities)) {
          arr <- resize_array(current, nrow(rgbs))
          arr[, 1:3] <- rgbs
        } else if (is.null(rgbs) && !is.null(opacities)) {
          arr <- resize_array(current, length(opacities))
          arr[, 4] <- opacities
        } else if (!is.null(rgbs)) {
          even <- make_even(lapply(seq_len(nrow(rgbs)), function(i) rgbs[i, ]), as.list(opacities))
          arr <- do.call(rbind, Map(function(rgb, o) c(rgb, o), even[[1]], even[[2]]))
        } else {
          next
        }
        assign(name, arr, envir = mob)
      }
      invisible(self)
    },
    set_rgba_array_direct = function(rgbas, name = "rgbas", recurse = TRUE) {
      for (mob in self$get_family(recurse)) assign(name, rgbas, envir = mob)
      invisible(self)
    },
    set_opacity = function(opacity, recurse = TRUE) {
      self$set_rgba_array(color = NULL, opacity = opacity, recurse = FALSE)
      if (recurse) for (sm in self$submobjects) sm$set_opacity(opacity, recurse = TRUE)
      invisible(self)
    },
    get_opacity = function() self$rgbas[1, 4],
    get_gloss = function() self$gloss,
    set_gloss = function(gloss, recurse = TRUE) {
      for (mob in self$get_family(recurse)) mob$gloss <- gloss
      invisible(self)
    },
    get_shadow = function() self$shadow,
    set_shadow = function(shadow, recurse = TRUE) {
      for (mob in self$get_family(recurse)) mob$shadow <- shadow
      invisible(self)
    },
    get_bounding_box_point = function(direction) {
      bb <- self$get_bounding_box()
      idx <- sign(as_point(direction)) + 2
      vapply(1:3, function(i) bb[idx[i], i], 0)
    },
    get_continuous_bounding_box_point = function(direction) {
      bb <- self$get_bounding_box()
      center <- bb[2, ]
      corner <- bb[3, ] - center
      direction <- as_point(direction)
      ratio <- ifelse(corner != 0, direction / corner, 0)
      center + direction / max(abs(ratio))
    },
    pfp = function(alpha) self$point_from_proportion(alpha),
    align_data_and_family = function(mobject) {
      self$align_family(mobject)
      self$align_data(mobject)
      invisible(self)
    },
    align_family = function(mobject) {
      n1 <- length(self)
      n2 <- length(mobject)
      if (n1 != n2) {
        self$add_n_more_submobjects(max(0, n2 - n1))
        mobject$add_n_more_submobjects(max(0, n1 - n2))
      }
      for (i in seq_along(self$submobjects)) self$submobjects[[i]]$align_family(mobject$submobjects[[i]])
      invisible(self)
    },
    lock_data = function(keys) {
      if (isTRUE(self$has_updaters)) return(invisible(self))
      self$locked_data_keys <- unique(as.character(unlist(keys)))
      invisible(self)
    },
    lock_matching_data = function(mobject1, mobject2) {
      fams <- list(self$get_family(), mobject1$get_family(), mobject2$get_family())
      for (i in seq_len(min(lengths(fams)))) {
        d1 <- opengl_data(fams[[2]][[i]])
        d2 <- opengl_data(fams[[3]][[i]])
        keys <- intersect(intersect(names(opengl_data(fams[[1]][[i]])), names(d1)), names(d2))
        same <- Filter(function(k) isTRUE(all(d1[[k]] == d2[[k]])), keys)
        fams[[1]][[i]]$lock_data(same)
      }
      invisible(self)
    },
    unlock_data = function() {
      for (mob in self$get_family()) mob$locked_data_keys <- character()
      invisible(self)
    },
    fix_in_frame = function() {
      self$is_fixed_in_frame <- 1
      invisible(self)
    },
    fix_orientation = function() {
      self$is_fixed_orientation <- 1
      self$fixed_orientation_center <- self$get_center()
      self$depth_test <- TRUE
      invisible(self)
    },
    unfix_from_frame = function() {
      self$is_fixed_in_frame <- 0
      invisible(self)
    },
    unfix_orientation = function() {
      self$is_fixed_orientation <- 0
      self$fixed_orientation_center <- c(0, 0, 0)
      self$depth_test <- FALSE
      invisible(self)
    },
    apply_depth_test = function() {
      self$depth_test <- TRUE
      invisible(self)
    },
    deactivate_depth_test = function() {
      self$depth_test <- FALSE
      invisible(self)
    },
    get_shader_uniforms = function() {
      list(is_fixed_in_frame = self$is_fixed_in_frame, is_fixed_orientation = self$is_fixed_orientation,
           fixed_orientation_center = self$fixed_orientation_center, gloss = self$gloss, shadow = self$shadow)
    },
    get_shader_vert_indices = function() self$shader_indices
  ),
  active = list(
    rgbas = function(value) {
      if (missing(value)) {
        return(private$.rgbas %||% matrix(c(color_to_rgb(self$color %||% WHITE), 1), 1))
      }
      private$.rgbas <- value
    },
    bounding_box = function(value) {
      if (missing(value)) return(self$get_bounding_box())
      invisible(NULL)
    },
    data = function(value) {
      if (missing(value)) return(opengl_data(self))
      self$set_data(value)
    },
    uniforms = function(value) {
      if (missing(value)) return(self$get_shader_uniforms())
      self$set_uniforms(value)
    }
  ),
  private = list(.rgbas = NULL)
)

# Upstream's OpenGLVMobject draws quadratic curves (three points each);
# manimR's OpenGL VMobjects are its Cairo VMobjects, with cubic curves (four
# points each). The methods below take the curve size from
# n_points_per_cubic_curve, so for quadratic input they do what upstream does.
OPENGL_VMOBJECT_METHODS <- list(
  public = list(
    flat_stroke = TRUE,
    triangulation_locked = FALSE,
    init_data = function() {
      self$points <- matrix(0, 0, 3)
      self$fill_rgbas <- matrix(0, 1, 4)
      self$stroke_rgbas <- matrix(0, 1, 4)
      invisible(self)
    },
    get_stroke_widths = function() self$stroke_width,
    get_colors = function() if (self$has_stroke()) self$get_stroke_colors() else self$get_fill_colors(),
    has_stroke = function() {
      widths <- self$get_stroke_widths()
      opacities <- self$get_stroke_opacities()
      !is.null(widths) && !is.null(opacities) && any(widths != 0) && any(opacities != 0)
    },
    has_fill = function() {
      opacities <- self$get_fill_opacities()
      !is.null(opacities) && any(opacities != 0)
    },
    get_opacity = function() if (self$has_fill()) self$get_fill_opacity() else self$get_stroke_opacity(),
    set_flat_stroke = function(flat_stroke = TRUE, recurse = TRUE) {
      for (mob in self$get_family(recurse)) mob$flat_stroke <- flat_stroke
      invisible(self)
    },
    get_flat_stroke = function() self$flat_stroke,
    add_smooth_cubic_curve_to = function(handle, point) {
      self$throw_error_if_no_points()
      new_handle <- self$get_reflection_of_last_handle()
      self$add_cubic_bezier_curve_to(new_handle, handle, point)
      invisible(self)
    },
    get_reflection_of_last_handle = function() {
      n <- nrow(self$points)
      2 * self$points[n, ] - self$points[n - 1, ]
    },
    subdivide_sharp_curves = function(angle_threshold = 30 * DEGREES, recurse = TRUE) {
      for (vmob in Filter(function(m) m$has_points(), self$get_family(recurse))) {
        new_points <- list()
        for (tup in vmob$get_bezier_tuples()) {
          k <- nrow(tup)
          angle <- angle_between_vectors(tup[2, ] - tup[1, ], tup[k, ] - tup[k - 1, ])
          if (angle > angle_threshold) {
            n <- ceiling(angle / angle_threshold)
            alphas <- seq(0, 1, length.out = n + 1)
            for (i in seq_len(n)) new_points[[length(new_points) + 1]] <- partial_bezier_points(tup, alphas[i], alphas[i + 1])
          } else {
            new_points[[length(new_points) + 1]] <- tup
          }
        }
        vmob$set_points(do.call(rbind, new_points))
      }
      invisible(self)
    },
    make_approximately_smooth = function() {
      self$change_anchor_mode("smooth")
      invisible(self)
    },
    get_bezier_tuples_from_points = function(points) {
      nppc <- self$n_points_per_cubic_curve
      k <- nrow(points) %/% nppc
      lapply(seq_len(k), function(i) points[(nppc * (i - 1) + 1):(nppc * i), , drop = FALSE])
    },
    get_bezier_tuples = function() self$get_bezier_tuples_from_points(self$points),
    get_points_without_null_curves = function(atol = 1e-9) {
      nppc <- self$n_points_per_cubic_curve
      points <- self$points
      starts <- seq(1, nrow(points), by = nppc)
      distinct <- Reduce(`|`, lapply(seq_len(nppc - 1), function(i) {
        apply(abs(points[starts + i, , drop = FALSE] - points[starts, , drop = FALSE]) > atol, 1, any)
      }))
      points[rep(distinct, each = nppc), , drop = FALSE]
    },
    get_area_vector = function() {
      if (!self$has_points()) return(c(0, 0, 0))
      nppc <- self$n_points_per_cubic_curve
      points <- self$points
      p0 <- points[seq(1, nrow(points), by = nppc), , drop = FALSE]
      p1 <- points[seq(nppc, nrow(points), by = nppc), , drop = FALSE]
      0.5 * c(sum((p0[, 2] + p1[, 2]) * (p1[, 3] - p0[, 3])),
              sum((p0[, 3] + p1[, 3]) * (p1[, 1] - p0[, 1])),
              sum((p0[, 1] + p1[, 1]) * (p1[, 2] - p0[, 2])))
    },
    get_unit_normal = function(recompute = FALSE) {
      points <- self$points
      if (nrow(points) < 3) return(OUT)
      area_vect <- self$get_area_vector()
      area <- sqrt(sum(area_vect^2))
      if (area > 0) return(area_vect / area)
      get_unit_normal(points[2, ] - points[1, ], points[3, ] - points[2, ])
    },
    refresh_unit_normal = function() invisible(self),
    refresh_triangulation = function() invisible(self)
  ),
  active = list(
    fill_rgba = function(value) {
      if (missing(value)) return(self$fill_rgbas %||% matrix(0, 1, 4))
      self$fill_rgbas <- value
    },
    stroke_rgba = function(value) {
      if (missing(value)) return(self$stroke_rgbas %||% matrix(0, 1, 4))
      self$stroke_rgbas <- value
    },
    unit_normal = function(value) {
      if (missing(value)) return(matrix(self$get_unit_normal(), 1))
      invisible(NULL)
    }
  )
)

# Upstream's OpenGLArc.create_quadratic_bezier_points(): quadratic Bezier
# points (three per curve) of an arc of the unit circle.
opengl_quadratic_arc_points <- function(angle, start_angle = 0, n_components = 8) {
  a <- seq(start_angle, start_angle + angle, length.out = 2 * n_components + 1)
  samples <- cbind(cos(a), sin(a), 0)
  theta <- angle / n_components
  odd <- seq(2, nrow(samples), by = 2)
  samples[odd, ] <- samples[odd, ] / cos(theta / 2)
  points <- matrix(0, 3 * n_components, 3)
  points[seq(1, by = 3, length.out = n_components), ] <- samples[seq(1, by = 2, length.out = n_components), ]
  points[seq(2, by = 3, length.out = n_components), ] <- samples[odd, ]
  points[seq(3, by = 3, length.out = n_components), ] <- samples[seq(3, by = 2, length.out = n_components), ]
  points
}

OPENGL_CLASS_METHODS <- list(
  OpenGLArc = list(public = list(
    create_quadratic_bezier_points = function(angle, start_angle = 0, n_components = 8) {
      opengl_quadratic_arc_points(angle, start_angle, n_components)
    },
    get_start_angle = function() angle_of_vector(self$get_start() - self$get_arc_center()) %% TAU,
    get_stop_angle = function() angle_of_vector(self$get_end() - self$get_arc_center()) %% TAU
  )),
  OpenGLPoint = list(public = list(
    get_location = function() self$points[1, ],
    get_bounding_box_point = function(...) self$get_location(),
    set_location = function(new_loc) {
      self$set_points(matrix(as_point(new_loc), 1))
      invisible(self)
    }
  ))
)

# OpenGLSurface. Upstream keeps a grid of nu x nv points and two copies
# nudged by epsilon along u and along v. manimR's surface is a group of faces;
# its grid is the corners of the faces as they are now (surface_corner_grid(),
# so it follows transformations), and the nudged points are the grid moved by
# epsilon times its derivative along u or v (finite differences).
opengl_surface_points <- function(surface) {
  grid <- surface_corner_grid(surface)
  nu <- dim(grid)[1]
  nv <- dim(grid)[2]
  flat <- function(g) matrix(aperm(g, c(2, 1, 3)), ncol = 3)
  deriv <- function(along, step) {
    d <- array(0, dim(grid))
    n <- dim(grid)[along]
    take <- function(i) if (along == 1) grid[i, , , drop = FALSE] else grid[, i, , drop = FALSE]
    put <- function(i, v) if (along == 1) d[i, , ] <<- v else d[, i, ] <<- v
    for (i in seq_len(n)) {
      lo <- max(i - 1, 1)
      hi <- min(i + 1, n)
      put(i, (take(hi) - take(lo)) / ((hi - lo) * step))
    }
    d
  }
  eps <- surface$epsilon %||% 1e-5
  ur <- surface$u_range
  vr <- surface$v_range
  # Upstream evaluates uv_func at u + epsilon and v + epsilon and moves those
  # points with the surface. When the grid is still an affine image of
  # uv_func's grid, the same map gives the nudged points exactly.
  exact <- opengl_surface_uv_grids(surface, nu, nv, eps)
  if (!is.null(exact)) {
    X <- cbind(exact[[1]], 1)
    Y <- flat(grid)
    A <- qr.coef(qr(X), Y)
    A[is.na(A)] <- 0
    if (all(is.finite(A)) && max(abs(X %*% A - Y)) <= 1e-7 * max(1, abs(Y))) {
      return(list(Y, cbind(exact[[2]], 1) %*% A, cbind(exact[[3]], 1) %*% A, resolution = c(nu, nv)))
    }
  }
  du <- grid + eps * deriv(1, (ur[2] - ur[1]) / (nu - 1))
  dv <- grid + eps * deriv(2, (vr[2] - vr[1]) / (nv - 1))
  list(flat(grid), flat(du), flat(dv), resolution = c(nu, nv))
}

# uv_func's points on the grid and nudged by epsilon along u and along v,
# in upstream's order (v varying fastest), kept on the surface.
opengl_surface_uv_grids <- function(surface, nu, nv, eps) {
  f <- surface$uv_func
  if (!is.function(f) || nu < 2 || nv < 2) return(NULL)
  key <- c(nu, nv, eps, surface$u_range, surface$v_range)
  cached <- surface$.uv_grids
  if (!is.null(cached) && identical(cached$key, key)) return(cached$grids)
  u <- rep(seq(surface$u_range[1], surface$u_range[2], length.out = nu), each = nv)
  v <- rep(seq(surface$v_range[1], surface$v_range[2], length.out = nv), times = nu)
  at <- function(du, dv) {
    t(vapply(seq_along(u), function(k) as.numeric(f(u[k] + du, v[k] + dv))[1:3], numeric(3)))
  }
  grids <- tryCatch(list(at(0, 0), at(eps, 0), at(0, eps)), error = function(e) NULL)
  surface$.uv_grids <- list(key = key, grids = grids)
  grids
}

OPENGL_SURFACE_METHODS <- list(
  public = list(
    shader_dtype = c(point = 3, du_point = 3, dv_point = 3, color = 4),
    shader_folder = "surface",
    epsilon = 1e-5,
    triangle_indices = NULL,
    compute_triangle_indices = function() {
      res <- opengl_surface_points(self)$resolution
      nu <- res[1]
      nv <- res[2]
      if (nu == 0 || nv == 0) {
        self$triangle_indices <- integer()
        return(invisible(self))
      }
      grid <- matrix(seq_len(nu * nv) - 1L, nu, nv, byrow = TRUE)
      tl <- as.vector(t(grid[-nu, -nv, drop = FALSE]))
      bl <- as.vector(t(grid[-1, -nv, drop = FALSE]))
      tr <- as.vector(t(grid[-nu, -1, drop = FALSE]))
      br <- as.vector(t(grid[-1, -1, drop = FALSE]))
      self$triangle_indices <- as.vector(rbind(tl, bl, tr, tr, bl, br))
      invisible(self)
    },
    get_triangle_indices = function() {
      if (is.null(self$triangle_indices)) self$compute_triangle_indices()
      self$triangle_indices
    },
    get_surface_points_and_nudged_points = function() opengl_surface_points(self)[1:3],
    get_unit_normals = function() {
      p <- self$get_surface_points_and_nudged_points()
      a <- (p[[2]] - p[[1]]) / self$epsilon
      b <- (p[[3]] - p[[1]]) / self$epsilon
      normals <- cbind(a[, 2] * b[, 3] - a[, 3] * b[, 2], a[, 3] * b[, 1] - a[, 1] * b[, 3], a[, 1] * b[, 2] - a[, 2] * b[, 1])
      normalize_along_axis(normals, 1)
    },
    get_partial_points_array = function(points, a, b, resolution, axis) {
      if (!nrow(points)) return(points)
      nu <- resolution[1]
      nv <- resolution[2]
      arr <- aperm(array(t(points), c(ncol(points), nv, nu)), c(3, 2, 1))
      max_index <- resolution[axis + 1] - 1
      lo <- integer_interpolate(0, max_index, a)
      hi <- integer_interpolate(0, max_index, b)
      at <- function(i) if (axis == 0) arr[i + 1, , , drop = FALSE] else arr[, i + 1, , drop = FALSE]
      low <- interpolate(at(lo[[1]]), at(lo[[1]] + 1), lo[[2]])
      high <- interpolate(at(hi[[1]]), at(hi[[1]] + 1), hi[[2]])
      n_axis <- resolution[axis + 1]
      for (i in seq_len(n_axis) - 1) {
        v <- if (i < lo[[1]]) low else if (i > hi[[1]]) high else next
        if (axis == 0) arr[i + 1, , ] <- v else arr[, i + 1, ] <- v
      }
      matrix(aperm(arr, c(2, 1, 3)), ncol = dim(arr)[3])
    },
    sort_faces_back_to_front = function(vect = OUT) {
      tri <- self$get_triangle_indices()
      s_points <- self$get_surface_points_and_nudged_points()[[1]]
      first <- tri[seq(1, length(tri), by = 3)]
      ord <- order(as.numeric(s_points[first + 1, , drop = FALSE] %*% as_point(vect)))
      m <- matrix(tri, nrow = 3)
      self$triangle_indices <- as.vector(m[, ord, drop = FALSE])
      invisible(self)
    },
    get_shader_data = function() {
      p <- self$get_surface_points_and_nudged_points()
      sd <- shader_data(self$shader_dtype, nrow(p[[1]]))
      if (!"points" %in% self$locked_data_keys) {
        assign("point", p[[1]], envir = sd)
        assign("du_point", p[[2]], envir = sd)
        assign("dv_point", p[[3]], envir = sd)
        if (length(self$colorscale) && !is.null(self$axes) && !inherits(self, "OpenGLTexturedSurface")) {
          # Computed once, as upstream keeps color_by_val.
          if (is.null(self$color_by_val)) self$color_by_val <- opengl_color_by_value(self, p[[1]])
          assign("color", self$color_by_val, envir = sd)
        } else {
          self$fill_in_shader_color_info(sd)
        }
      }
      sd
    },
    fill_in_shader_color_info = function(shader_data) {
      self$read_data_to_shader(shader_data, "color", "rgbas")
      shader_data
    },
    get_shader_vert_indices = function() self$get_triangle_indices()
  ),
  active = list(
    rgbas = function(value) {
      if (missing(value)) return(self$get_fill_rgbas())
      self$fill_rgbas <- value
    }
  )
)

# Upstream's OpenGLSurface._get_color_by_value(): the color of each vertex
# from its coordinate along colorscale_axis, between pivots spread evenly
# over the axes' z range or given with the colors as (color, pivot) pairs.
opengl_color_by_value <- function(surface, s_points) {
  scale <- surface$colorscale
  if (is.list(scale) && length(scale) && length(scale[[1]]) == 2 && !inherits(scale[[1]], "ManimColor")) {
    colors <- lapply(scale, `[[`, 1)
    pivots <- vapply(scale, function(x) as.numeric(x[[2]]), numeric(1))
  } else {
    colors <- as.list(unlist(scale))
    z <- surface$axes$z_range
    freq <- (z[2] - z[1]) / (length(colors) - 1)
    # numpy's arange(z[1], z[2] + freq, freq).
    pivots <- z[1] + freq * (seq_len(ceiling((z[2] + freq - z[1]) / freq)) - 1)
  }
  opacity <- surface$get_fill_opacity() %||% 1
  t(apply(s_points, 1, function(point) {
    value <- surface$axes$point_to_coords(point)[surface$colorscale_axis + 1]
    if (value <= pivots[1]) return(color_to_rgba(colors[[1]], opacity))
    if (value >= pivots[length(pivots)]) return(color_to_rgba(colors[[length(colors)]], opacity))
    i <- which(pivots > value)[1]
    index <- min(max((value - pivots[i - 1]) / (pivots[i] - pivots[i - 1]), 0), 1)
    color_to_rgba(interpolate_color(colors[[i - 1]], colors[[i]], index), opacity)
  }))
}

# OpenGLTexturedSurface: image coordinates of the grid (u from 0 to 1,
# v from 1 to 0, as upstream flips the image vertically) and the opacity.
opengl_image_from_file <- function(image_file, image_mode) {
  ImageMobject(get_full_raster_image_path(image_file), image_mode = image_mode)$pixel_array
}

OPENGL_TEXTURED_SURFACE_METHODS <- list(
  public = list(
    shader_dtype = c(point = 3, du_point = 3, dv_point = 3, im_coords = 2, opacity = 1),
    shader_folder = "textured_surface",
    get_image_from_file = function(image_file, image_mode) opengl_image_from_file(image_file, image_mode),
    init_data = function() {
      self$points <- matrix(0, 0, 3)
      self$im_coords <- matrix(0, 0, 2)
      self$opacity <- matrix(0, 0, 1)
      invisible(self)
    },
    fill_in_shader_color_info = function(shader_data) {
      self$read_data_to_shader(shader_data, "opacity", "opacity")
      self$read_data_to_shader(shader_data, "im_coords", "im_coords")
      shader_data
    }
  ),
  active = list(
    im_coords = function(value) {
      if (!missing(value)) {
        private$.im_coords <- value
        return(invisible(NULL))
      }
      if (!is.null(private$.im_coords) && nrow(private$.im_coords)) return(private$.im_coords)
      res <- opengl_surface_points(self)$resolution
      grid <- expand.grid(v = seq(1, 0, length.out = res[2]), u = seq(0, 1, length.out = res[1]))
      unname(cbind(grid$u, grid$v))
    },
    opacity = function(value) {
      if (!missing(value)) {
        private$.opacity <- value
        return(invisible(NULL))
      }
      if (!is.null(private$.opacity) && nrow(private$.opacity)) return(private$.opacity)
      matrix(self$get_fill_opacity() %||% 1, 1, 1)
    }
  ),
  private = list(.im_coords = NULL, .opacity = NULL)
)


OPENGL_MOBJECT_METHODS$public <- c(OPENGL_MOBJECT_METHODS$public, opengl_mobject_shader_methods)
OPENGL_VMOBJECT_METHODS$public <- c(OPENGL_VMOBJECT_METHODS$public, opengl_vmobject_shader_methods)
# Upstream's OpenGL renderer samples textures with nearest neighbor
# filtering, so an image array is first upscaled with resampling_algorithm:
# by at most 200 times, to at most 4096 pixels along its longer side.
OPENGL_CLASS_METHODS$OpenGLImageMobject <- list(public = list(
  get_image_from_file = function(image_file, image_mode) {
    if (is.character(image_file)) return(opengl_image_from_file(image_file, image_mode))
    opengl_upscale_image(ImageMobject(image_file, image_mode = image_mode)$pixel_array,
                         self$resampling_algorithm %||% "bicubic")
  }
))

# Pillow's resize() by a whole factor: the coefficients of its
# precompute_coeffs() in 22 bit fixed point, a horizontal then a vertical
# pass, each rounded to 8 bits. An image with alpha is resized with
# premultiplied colors, as Pillow does.
opengl_upscale_image <- function(img, method = "bicubic") {
  hw <- dim(img)[1:2]
  scale <- max(1, min(200, 4096 %/% max(hw)))
  if (scale == 1) return(img)
  if (method == "nearest") {
    return(img[rep(seq_len(hw[1]), each = scale), rep(seq_len(hw[2]), each = scale), , drop = FALSE])
  }
  nc <- dim(img)[3]
  alpha <- nc %in% c(2, 4)
  img <- round(img)
  if (alpha) for (k in seq_len(nc - 1)) {
    t <- img[, , k] * img[, , nc] + 128
    img[, , k] <- (t %/% 256 + t) %/% 256
  }
  wx <- t(pillow_coefficients(hw[2], hw[2] * scale, method))
  wy <- pillow_coefficients(hw[1], hw[1] * scale, method)
  pass <- function(x) pmin(pmax((x + 2^21) %/% 2^22, 0), 255)
  out <- array(0, c(hw * scale, nc))
  for (k in seq_len(nc)) out[, , k] <- pass(wy %*% pass(img[, , k] %*% wx))
  if (alpha) for (k in seq_len(nc - 1)) {
    a <- out[, , nc]
    out[, , k] <- ifelse(a == 0 | a == 255, out[, , k], pmin((255 * out[, , k]) %/% pmax(a, 1), 255))
  }
  out
}

# Pillow's resampling filters (Resample.c) and their supports.
pillow_sinc <- function(x) ifelse(x == 0, 1, sin(x * pi) / (x * pi))
PILLOW_FILTERS <- list(
  box = list(support = 0.5, f = function(x) as.numeric(x > -0.5 & x <= 0.5)),
  bilinear = list(support = 1, f = function(x) pmax(1 - abs(x), 0)),
  hamming = list(support = 1, f = function(x) {
    x <- abs(x)
    ifelse(x == 0, 1, ifelse(x >= 1, 0, sin(x * pi) / (x * pi) * (0.54 + 0.46 * cos(x * pi))))
  }),
  bicubic = list(support = 2, f = function(x) {
    x <- abs(x)
    ifelse(x < 1, (1.5 * x - 2.5) * x * x + 1, ifelse(x < 2, (((x - 5) * x + 8) * x - 4) * -0.5, 0))
  }),
  lanczos = list(support = 3, f = function(x) ifelse(x >= -3 & x < 3, pillow_sinc(x) * pillow_sinc(x / 3), 0))
)

pillow_coefficients <- function(in_size, out_size, method) {
  scale <- in_size / out_size
  fs <- max(scale, 1)
  filter <- PILLOW_FILTERS[[method]]
  support <- filter$support * fs
  f <- filter$f
  w <- matrix(0, out_size, in_size)
  for (i in seq_len(out_size)) {
    center <- (i - 0.5) * scale
    x <- max(trunc(center - support + 0.5), 0):(min(trunc(center + support + 0.5), in_size) - 1)
    k <- f((x - center + 0.5) / fs)
    k <- k / sum(k) * 2^22
    w[i, x + 1] <- trunc(k + ifelse(k < 0, -0.5, 0.5))
  }
  w
}

# Upstream's OpenGL classes name some arguments differently from its Cairo
# classes: `recurse` where the Cairo methods have `recursive` or `family`,
# `opacity` in set_color(), `stretch` in set_width(). These wrappers take
# upstream's OpenGL arguments and still accept the Cairo names, which
# manimR's own code passes. They replace the inherited methods of each
# OpenGL class (not methods the class defines itself).
OPENGL_MOBJECT_SIGNATURES <- list(public = list(
  clear_updaters = function(recurse = TRUE, recursive = recurse) super$clear_updaters(recursive),
  suspend_updating = function(recurse = TRUE, recursive = recurse) super$suspend_updating(recursive),
  resume_updating = function(recurse = TRUE, call_updater = TRUE, recursive = recurse) {
    self$updating_suspended <- FALSE
    if (recursive) for (sm in self$submobjects) sm$resume_updating(recursive)
    if (call_updater) self$update(dt = 0, recursive = recursive)
    invisible(self)
  },
  update = function(dt = 0, recurse = TRUE, recursive = recurse) super$update(dt, recursive),
  shuffle = function(recurse = FALSE, recursive = recurse) super$shuffle(recursive),
  fade = function(darkness = 0.5, recurse = TRUE, family = recurse) super$fade(darkness, family = family),
  # A shallow copy, as upstream's, copies the family but shares the mobjects
  # held in other fields.
  copy = function(shallow = FALSE, .memo = NULL) {
    if (is.environment(shallow)) return(super$copy(shallow))
    new <- super$copy(.memo)
    if (isTRUE(shallow)) {
      family <- self$get_family()
      for (nm in mobject_fields(self)) {
        v <- .subset2(self, nm)
        if (is_mobject(v) && !any(vapply(family, identical, NA, v))) assign(nm, v, envir = new)
      }
    }
    new
  },
  save_state = function(use_deepcopy = FALSE) super$save_state(),
  # manimR keeps no parents list, so update_parent has nothing to update.
  insert = function(index, mobject, update_parent = FALSE) super$insert(index, mobject),
  set_color = function(color, opacity = NULL, recurse = TRUE, family = recurse, alpha = NULL) {
    super$set_color(color, family = family)
    opacity <- opacity %||% alpha
    if (!is.null(opacity)) {
      if ("recurse" %in% names(formals(self$set_opacity))) self$set_opacity(opacity, recurse = family)
      else self$set_opacity(opacity)
    }
    invisible(self)
  },
  set_width = function(width, stretch = FALSE, ...) self$rescale_to_fit(width, 1, stretch = stretch, ...),
  set_height = function(height, stretch = FALSE, ...) self$rescale_to_fit(height, 2, stretch = stretch, ...),
  set_depth = function(depth, stretch = FALSE, ...) self$rescale_to_fit(depth, 3, stretch = stretch, ...)
))

OPENGL_VMOBJECT_SIGNATURES <- list(public = list(
  set_fill = function(color = NULL, opacity = NULL, recurse = TRUE, family = recurse) {
    super$set_fill(color, opacity, family = family)
  },
  # As upstream, `background` sets whether the stroke is drawn behind the
  # fill (the Cairo classes' background stroke is set_background_stroke()).
  set_stroke = function(color = NULL, width = NULL, opacity = NULL, background = NULL, recurse = TRUE,
                        family = recurse) {
    super$set_stroke(color, width, opacity, family = family)
    if (!is.null(background)) for (mob in self$get_family(family)) mob$draw_stroke_behind_fill <- background
    invisible(self)
  },
  set_opacity = function(opacity, recurse = TRUE, family = recurse) super$set_opacity(opacity, family = family),
  match_style = function(vmobject, recurse = TRUE, family = recurse) super$match_style(vmobject, family = family),
  set_style = function(fill_color = NULL, fill_opacity = NULL, fill_rgba = NULL, stroke_color = NULL,
                       stroke_opacity = NULL, stroke_rgba = NULL, stroke_width = NULL, gloss = NULL, shadow = NULL,
                       recurse = TRUE, family = recurse, ...) {
    super$set_style(fill_color = fill_color, fill_opacity = fill_opacity, stroke_color = stroke_color,
                    stroke_width = stroke_width, stroke_opacity = stroke_opacity, family = family, ...)
    for (mob in self$get_family(family)) {
      if (!is.null(fill_rgba)) mob$fill_rgbas <- matrix(as.numeric(fill_rgba), ncol = 4)
      if (!is.null(stroke_rgba)) mob$stroke_rgbas <- matrix(as.numeric(stroke_rgba), ncol = 4)
    }
    if (!is.null(gloss)) self$set_gloss(gloss, recurse = family)
    if (!is.null(shadow)) self$set_shadow(shadow, recurse = family)
    invisible(self)
  },
  insert_n_curves = function(n, recurse = TRUE) {
    for (mob in self$get_family(recurse)) {
      if (mob$get_num_curves() == 0) next
      if (identical(mob, self)) super$insert_n_curves(n)
      else if ("recurse" %in% names(formals(mob$insert_n_curves))) mob$insert_n_curves(n, recurse = FALSE)
      else mob$insert_n_curves(n)
    }
    invisible(self)
  },
  set_points_smoothly = function(points, true_smooth = FALSE) super$set_points_smoothly(points),
  # Upstream's quadratic form (anchors, one handle, anchors) is raised to the
  # cubic curves manimR draws; the cubic form of the Cairo classes, with two
  # handles, is passed on.
  set_anchors_and_handles = function(anchors1, handles, anchors2, ...) {
    if (...length()) return(super$set_anchors_and_handles(anchors1, handles, anchors2, ...))
    a1 <- as_points(anchors1)
    h <- as_points(handles)
    a2 <- as_points(anchors2)
    super$set_anchors_and_handles(a1, a1 + 2 / 3 * (h - a1), a2 + 2 / 3 * (h - a2), a2)
  },
  pointwise_become_partial = function(vmobject, a, b, remap = TRUE) super$pointwise_become_partial(vmobject, a, b)
))

# Upstream's OpenGLCircle.surround() keeps a circle shape, then stretches it
# to leave `buff` on every side.
OPENGL_CLASS_METHODS$OpenGLCircle <- list(public = list(
  surround = function(mobject, dim_to_match = 1, stretch = FALSE, buff = MED_SMALL_BUFF) {
    self$replace(mobject, dim_to_match, stretch)
    self$stretch((self$width + 2 * buff) / self$width, 1)
    self$stretch((self$height + 2 * buff) / self$height, 2)
    invisible(self)
  }
))
OPENGL_CLASS_METHODS$OpenGLDashedLine <- list(public = list(
  calculate_num_dashes = function(dashed_ratio = self$dashed_ratio) {
    max(2L, as.integer(ceiling((self$get_length() / self$dash_length) * dashed_ratio)))
  }
))
# Upstream's OpenGLSurface.pointwise_become_partial(): the grid points
# outside [a, b] along `axis` (0 for u, 1 for v) collapse onto its ends.
OPENGL_CLASS_METHODS$OpenGLSurface <- list(public = list(
  prefered_creation_axis = 1,
  passed_uv_func = NULL,
  axes = NULL,
  colorscale = NULL,
  colorscale_axis = 2,
  color_by_val = NULL,
  # Upstream's arguments: resolution counts grid points (one more than the
  # faces along u and v), and the surface is one color without outlines.
  # ponytail: upstream's default is 101 by 101 points for the GPU; grid draws
  # each face as a polygon, so the default is Surface()'s 32 faces.
  initialize = function(uv_func = NULL, u_range = NULL, v_range = NULL, resolution = NULL, axes = NULL,
                        color = GREY, colorscale = NULL, colorscale_axis = 2, opacity = 1, gloss = 0.3,
                        shadow = 0.4, prefered_creation_axis = 1, epsilon = 1e-5, render_primitive = 4L,
                        depth_test = TRUE, shader_folder = NULL, ...) {
    resolution <- rep_len(resolution %||% 33, 2)
    self$passed_uv_func <- uv_func
    self$axes <- axes
    self$colorscale <- colorscale
    self$colorscale_axis <- colorscale_axis
    self$prefered_creation_axis <- prefered_creation_axis
    self$epsilon <- epsilon
    super$initialize(uv_func %||% function(u, v) c(u, v, 0), u_range = u_range %||% c(0, 1),
                     v_range = v_range %||% c(0, 1), resolution = resolution - 1, fill_color = color,
                     fill_opacity = opacity, checkerboard_colors = FALSE, stroke_width = 0, ...)
    self$set_gloss(gloss)
    self$set_shadow(shadow)
    self$render_primitive <- render_primitive
    self$depth_test <- depth_test
    self$shader_folder <- shader_folder %||% "surface"
    if (!is.null(colorscale) && !is.null(axes)) self$set_fill_by_value(axes, colorscale, axis = colorscale_axis + 1)
  },
  pointwise_become_partial = function(smobject, a, b, axis = NULL) {
    axis <- axis %||% self$prefered_creation_axis
    grid <- surface_corner_grid(smobject)
    nu <- dim(grid)[1]
    nv <- dim(grid)[2]
    flat <- matrix(aperm(grid, c(2, 1, 3)), ncol = 3)
    if (!(a <= 0 && b >= 1)) flat <- self$get_partial_points_array(flat, a, b, c(nu, nv), axis)
    g <- aperm(array(t(flat), c(3, nv, nu)), c(3, 2, 1))
    for (f in self$list_of_faces) {
      i <- f$u_index + 1
      j <- f$v_index + 1
      f$set_points_as_corners(rbind(g[i, j, ], g[i + 1, j, ], g[i + 1, j + 1, ], g[i, j + 1, ], g[i, j, ]))
    }
    invisible(self)
  }
))
OPENGL_TEXTURED_SURFACE_METHODS$public$pointwise_become_partial <- function(tsmobject, a, b, axis = 1) {
  super$pointwise_become_partial(tsmobject, a, b, axis)
  self$im_coords <- tsmobject$im_coords
  if (a <= 0 && b >= 1) return(invisible(self))
  res <- opengl_surface_points(tsmobject)$resolution
  self$im_coords <- self$get_partial_points_array(tsmobject$im_coords, a, b, res, axis)
  invisible(self)
}
# The opacity of upstream's textured surface; manimR draws it with the faces'
# opacity.
OPENGL_TEXTURED_SURFACE_METHODS$public$set_opacity <- function(opacity, recurse = TRUE, family = recurse) {
  values <- unlist(listify(opacity))
  for (mob in self$get_family(family)) {
    if (inherits(mob, "OpenGLTexturedSurface")) mob$opacity <- matrix(values, ncol = 1)
  }
  super$set_opacity(values[1], family = family)
}
OPENGL_PMOBJECT_METHODS <- list(public = list(
  shader_dtype = c(point = 3, color = 4),
  shader_folder = "true_dot",
  OPENGL_POINT_RADIUS_SCALE_FACTOR = 0.01,
  match_colors = function(pmobject) super$match_colors(pmobject),
  pointwise_become_partial = function(pmobject, a, b) super$pointwise_become_partial(pmobject, a, b)
))

# Cubic curves of the shape of upstream's quadratic ones, given as rows of
# three points per curve: each quadratic is raised to a cubic.
opengl_cubic_from_quadratic <- function(q) {
  k <- nrow(q) %/% 3
  if (k == 0) return(matrix(0, 0, 3))
  i <- 3 * seq_len(k) - 2
  a <- q[i, , drop = FALSE]
  h <- q[i + 1, , drop = FALSE]
  b <- q[i + 2, , drop = FALSE]
  out <- matrix(0, 4 * k, 3)
  j <- 4 * seq_len(k) - 3
  out[j, ] <- a
  out[j + 1, ] <- a + 2 / 3 * (h - a)
  out[j + 2, ] <- b + 2 / 3 * (h - b)
  out[j + 3, ] <- b
  out
}

# Upstream's OpenGLLine and its subclasses. As upstream, `buff` is applied
# twice: set_start_and_end_attrs() moves the ends by it, and
# set_points_by_ends() then cuts it off again through account_for_buff(),
# which reads the `buff` field rather than its argument. A path arc is
# upstream's quadratic arc of 8 pieces.
OPENGL_LINE_METHODS <- list(public = list(
  set_start_and_end_attrs = function(start, end) {
    rough_start <- self$pointify(start)
    rough_end <- self$pointify(end)
    vect <- normalize(rough_end - rough_start)
    self$start <- self$pointify(start, vect) + self$buff * vect
    self$end <- self$pointify(end, -vect) - self$buff * vect
    invisible(self)
  },
  pointify = function(mob_or_point, direction = NULL) {
    if (is_mobject(mob_or_point)) {
      if (is.null(direction)) return(mob_or_point$get_center())
      return(mob_or_point$get_continuous_bounding_box_point(direction))
    }
    as_point(mob_or_point)
  },
  set_points_by_ends = function(start, end, buff = 0, path_arc = 0) {
    if (path_arc != 0) {
      self$set_points(opengl_cubic_from_quadratic(opengl_quadratic_arc_points(path_arc)))
      self$put_start_and_end_on(start, end)
    } else {
      self$set_points_as_corners(rbind(as_point(start), as_point(end)))
    }
    self$account_for_buff(self$buff)
    invisible(self)
  },
  put_start_and_end_on = function(start, end) {
    se <- self$get_start_and_end()
    if (all(se[[1]] == se[[2]])) self$set_points_by_ends(start, end, self$path_arc)
    super$put_start_and_end_on(start, end)
  },
  set_path_arc = function(new_value) {
    self$path_arc <- new_value
    self$init_points()
    invisible(self)
  }
))
OPENGL_LINE_CLASSES <- c("OpenGLLine", "OpenGLDashedLine", "OpenGLTangentLine")

# Upstream's OpenGLArc and the classes built on it draw `n_components`
# quadratic pieces (8 by default); manimR raises them to cubic curves.
OPENGL_ARC_POINTS <- list(public = list(
  n_components = 8,
  set_pre_positioned_points = function() {
    self$set_points(opengl_cubic_from_quadratic(
      opengl_quadratic_arc_points(self$angle, self$start_angle, self$n_components %||% 8)))
  }
))
OPENGL_ARC_CLASSES <- c("OpenGLArc", "OpenGLArcBetweenPoints", "OpenGLCurvedArrow", "OpenGLCurvedDoubleArrow",
                        "OpenGLCircle", "OpenGLDot", "OpenGLEllipse")

# A straight cubic piece from a to b (upstream's add_line_to(), raised).
# Tips of upstream's OpenGLTipableVMobject: add_tip(at_start, ...) makes an
# OpenGLArrowTip from tip_config and the arguments given.
OPENGL_TIPABLE_METHODS <- list(public = list(
  tip_config = list(),
  add_tip = function(at_start = FALSE, ...) {
    tip <- self$create_tip(at_start, ...)
    self$reset_endpoints_based_on_tip(tip, at_start)
    self$assign_tip_attr(tip, at_start)
    self$add(tip)
    invisible(self)
  },
  create_tip = function(at_start = FALSE, ...) {
    tip <- self$get_unpositioned_tip(...)
    self$position_tip(tip, at_start)
    tip
  },
  get_unpositioned_tip = function(...) do.call(OpenGLArrowTip, utils::modifyList(as.list(self$tip_config), list(...))),
  position_tip = function(tip, at_start = FALSE) {
    if (at_start) {
      anchor <- self$get_start()
      handle <- self$get_first_handle()
    } else {
      handle <- self$get_last_handle()
      anchor <- self$get_end()
    }
    tip$rotate(angle_of_vector(handle - anchor) - PI - tip$get_angle())
    tip$shift(anchor - tip$get_tip_point())
    tip
  },
  reset_endpoints_based_on_tip = function(tip, at_start) {
    if (self$get_length() == 0) return(invisible(self))
    if (at_start) self$put_start_and_end_on(tip$get_base(), self$get_end())
    else self$put_start_and_end_on(self$get_start(), tip$get_base())
    invisible(self)
  }
))
OPENGL_TIPABLE_CLASSES <- c("OpenGLTipableVMobject", "OpenGLArc", "OpenGLArcBetweenPoints", "OpenGLCurvedArrow",
                            "OpenGLCurvedDoubleArrow", "OpenGLCircle", "OpenGLDot", "OpenGLEllipse",
                            "OpenGLAnnularSector", "OpenGLSector", "OpenGLAnnulus", "OpenGLLine", "OpenGLDashedLine",
                            "OpenGLTangentLine")
opengl_line_piece <- function(a, b) rbind(a, a + (b - a) / 3, a + 2 * (b - a) / 3, b, deparse.level = 0)

# Constructors whose upstream arguments differ from their Cairo counterpart.
OPENGL_CLASS_METHODS$OpenGLArc$public$initialize <- function(start_angle = 0, angle = TAU / 4, radius = 1,
                                                              n_components = 8, arc_center = ORIGIN, ...) {
  self$n_components <- n_components
  super$initialize(radius = radius, start_angle = start_angle, angle = angle, arc_center = arc_center, ...)
}
OPENGL_CLASS_METHODS$OpenGLCircle$public$initialize <- function(color = RED, ...) {
  super$initialize(color = color, ...)
}
OPENGL_CLASS_METHODS$OpenGLAnnularSector <- list(public = list(
  generate_points = function() {
    arc <- function(r) OpenGLArc(start_angle = self$start_angle, angle = self$angle, radius = r,
                                 arc_center = self$arc_center)$points
    inner <- arc(self$inner_radius)
    outer <- arc(self$outer_radius)
    outer <- outer[rev(seq_len(nrow(outer))), , drop = FALSE]
    self$set_points(rbind(inner, opengl_line_piece(inner[nrow(inner), ], outer[1, ]), outer,
                          opengl_line_piece(outer[nrow(outer), ], inner[1, ])))
    invisible(self)
  }
))
OPENGL_CLASS_METHODS$OpenGLSector <- list(public = list(
  initialize = function(outer_radius = 1, inner_radius = 0, ...) {
    # Sector() adopts the points of a Cairo AnnularSector, so draw them again.
    super$initialize(radius = outer_radius, ...)
    self$inner_radius <- inner_radius
    self$generate_points()
  },
  generate_points = OPENGL_CLASS_METHODS$OpenGLAnnularSector$public$generate_points
))
OPENGL_CLASS_METHODS$OpenGLAnnulus <- list(public = list(
  generate_points = function() {
    self$radius <- self$outer_radius
    outer <- OpenGLCircle(radius = self$outer_radius)$points
    inner <- OpenGLCircle(radius = self$inner_radius)$points
    self$set_points(rbind(outer, inner[rev(seq_len(nrow(inner))), , drop = FALSE]))
    self$shift(self$arc_center)
    invisible(self)
  }
))
# Upstream's OpenGL dashes take no dash_offset and split the curve by its
# parameter rather than by arc length.
OPENGL_CLASS_METHODS$OpenGLDashedVMobject <- list(public = list(
  initialize = function(vmobject, num_dashes = 15, dashed_ratio = 0.5, color = WHITE, ...) {
    args <- utils::modifyList(list(equal_lengths = FALSE), list(...))
    do.call(super$initialize, c(list(vmobject, num_dashes = num_dashes, dashed_ratio = dashed_ratio,
                                     color = color), args))
    self$num_dashes <- num_dashes
    self$dashed_ratio <- dashed_ratio
  },
  num_dashes = NULL,
  dashed_ratio = NULL
))
OPENGL_CLASS_METHODS$OpenGLTipableVMobject <- list(public = list(
  initialize = function(tip_length = DEFAULT_ARROW_TIP_LENGTH, normal_vector = OUT, tip_config = list(), ...) {
    super$initialize(tip_length = tip_length, normal_vector = normal_vector, ...)
    self$tip_config <- tip_config
  }
))
OPENGL_CLASS_METHODS$OpenGLCurvedArrow <- list(public = list(
  initialize = function(start_point, end_point, ...) {
    super$initialize(start_point, end_point, ...)
    self$add_tip()
  }
))
OPENGL_CLASS_METHODS$OpenGLCurvedDoubleArrow <- list(public = list(
  initialize = function(start_point, end_point, ...) {
    super$initialize(start_point, end_point, ...)
    self$add_tip(at_start = TRUE)
  }
))
# Upstream's OpenGL image is 4 units high unless width or height is given.
OPENGL_CLASS_METHODS$OpenGLImageMobject$public$initialize <-
  function(filename_or_array, width = NULL, height = NULL, image_mode = "RGBA",
           resampling_algorithm = "bicubic", opacity = 1, gloss = 0, shadow = 0, ...) {
    super$initialize(filename_or_array, image_mode = image_mode, resampling_algorithm = resampling_algorithm, ...)
    hw <- self$pixel_shape()
    if (is.null(width) && is.null(height)) height <- 4
    if (is.null(height)) height <- width * hw[1] / hw[2]
    if (is.null(width)) width <- height * hw[2] / hw[1]
    self$stretch_to_fit_height(height)
    self$stretch_to_fit_width(width)
    if (opacity != 1) self$set_opacity(opacity)
    self$set_gloss(gloss)
    self$set_shadow(shadow)
  }
# Upstream's arguments of the base classes, in upstream's order.
OPENGL_CLASS_METHODS$OpenGLMobject <- list(public = list(
  opacity = 1,
  listen_to_events = FALSE,
  should_render = TRUE,
  initialize = function(color = WHITE, opacity = 1, dim = 3, gloss = 0, shadow = 0, render_primitive = 4L,
                        texture_paths = NULL, depth_test = FALSE, is_fixed_in_frame = FALSE,
                        is_fixed_orientation = FALSE, listen_to_events = FALSE, model_matrix = NULL,
                        should_render = TRUE, name = NULL, ...) {
    super$initialize(color = color, name = name, ...)
    self$opacity <- opacity
    self$dim <- dim
    self$gloss <- gloss
    self$shadow <- shadow
    self$render_primitive <- render_primitive
    self$texture_paths <- texture_paths
    self$depth_test <- depth_test
    self$is_fixed_in_frame <- as.numeric(is_fixed_in_frame)
    self$is_fixed_orientation <- as.numeric(is_fixed_orientation)
    self$listen_to_events <- listen_to_events
    if (!is.null(model_matrix)) self$model_matrix <- model_matrix
    self$should_render <- should_render
  }
))
# n_points_per_curve is taken but not used: manimR's curves are cubic.
OPENGL_CLASS_METHODS$OpenGLVMobject <- list(public = list(
  long_lines = FALSE,
  should_subdivide_sharp_curves = FALSE,
  should_remove_null_curves = FALSE,
  initialize = function(fill_color = NULL, fill_opacity = 0, stroke_color = NULL, stroke_opacity = 1,
                        stroke_width = DEFAULT_STROKE_WIDTH, draw_stroke_behind_fill = FALSE,
                        pre_function_handle_to_anchor_scale_factor = 0.01,
                        make_smooth_after_applying_functions = FALSE, background_image_file = NULL,
                        tolerance_for_point_equality = 1e-8, n_points_per_curve = 3, long_lines = FALSE,
                        should_subdivide_sharp_curves = FALSE, should_remove_null_curves = FALSE,
                        joint_type = NULL, flat_stroke = TRUE, render_primitive = 4L,
                        triangulation_locked = FALSE, ...) {
    super$initialize(fill_color = fill_color, fill_opacity = fill_opacity, stroke_color = stroke_color,
                     stroke_opacity = stroke_opacity, stroke_width = stroke_width,
                     pre_function_handle_to_anchor_scale_factor = pre_function_handle_to_anchor_scale_factor,
                     make_smooth_after_applying_functions = make_smooth_after_applying_functions,
                     background_image = background_image_file,
                     tolerance_for_point_equality = tolerance_for_point_equality,
                     joint_type = joint_type %||% "auto", ...)
    self$draw_stroke_behind_fill <- draw_stroke_behind_fill
    self$long_lines <- long_lines
    self$should_subdivide_sharp_curves <- should_subdivide_sharp_curves
    self$should_remove_null_curves <- should_remove_null_curves
    self$flat_stroke <- flat_stroke
    self$render_primitive <- render_primitive
    self$triangulation_locked <- triangulation_locked
  }
))
OPENGL_CLASS_METHODS$OpenGLCubicBezier <- list(public = list(
  initialize = function(a0, h0, h1, a1, ...) super$initialize(a0, h0, h1, a1, ...)
))
OPENGL_CLASS_METHODS$OpenGLRegularPolygon <- list(public = list(
  initialize = function(n = 6, start_angle = NULL, ...) super$initialize(n = n, start_angle = start_angle, ...)
))
OPENGL_CLASS_METHODS$OpenGLRectangle <- list(public = list(
  initialize = function(color = WHITE, width = 4, height = 2, ...) {
    super$initialize(color = color, height = height, width = width, ...)
  }
))
OPENGL_CLASS_METHODS$OpenGLPoint$public$artificial_width <- 1e-6
OPENGL_CLASS_METHODS$OpenGLPoint$public$artificial_height <- 1e-6
OPENGL_CLASS_METHODS$OpenGLPoint$public$initialize <- function(location = ORIGIN, artificial_width = 1e-6,
                                                                artificial_height = 1e-6, color = WHITE, ...) {
  self$artificial_width <- artificial_width
  self$artificial_height <- artificial_height
  super$initialize(location = location, color = color, ...)
}
OPENGL_CLASS_METHODS$OpenGLPoint$public$get_width <- function() self$artificial_width
OPENGL_CLASS_METHODS$OpenGLPoint$public$get_height <- function() self$artificial_height
