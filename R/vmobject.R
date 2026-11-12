# VMobject: vectorized mobjects made of cubic Bezier curves.
# Ported from manim/mobject/types/vectorized_mobject.py.

is_vmobject <- function(x) inherits(x, "VMobject")

# Interleave anchors and handles into a 4k x 3 point matrix.
interleave_curves <- function(a1, h1, h2, a2) {
  k <- nrow(a1)
  out <- matrix(0, 4 * k, ncol(a1))
  idx <- 4 * (seq_len(k) - 1)
  out[idx + 1, ] <- a1
  out[idx + 2, ] <- h1
  out[idx + 3, ] <- h2
  out[idx + 4, ] <- a2
  out
}

# As numpy.allclose: equal infinities are close, NaN is close to nothing.
points_close <- function(p0, p1, atol = 1e-6, rtol = 1e-5) {
  d <- abs(p0 - p1)
  all((is.finite(d) & d <= atol + rtol * abs(p1)) | (!is.na(p0) & !is.na(p1) & p0 == p1))
}

#' @title VMobject
#' @description Vectorized mobject: a path of cubic Bezier curves with fill
#'   and stroke styling. Points come in groups of four per curve (anchor,
#'   handle, handle, anchor).
#' @param color Color used for fill and stroke when they are not given.
#' @param fill_color,fill_opacity Fill color and opacity.
#' @param stroke_color,stroke_opacity,stroke_width Stroke color, opacity and
#'   width.
#' @param background_stroke_color,background_stroke_opacity,background_stroke_width
#'   Style of a stroke drawn behind the fill.
#' @param sheen_factor,sheen_direction Strength and direction of a lighter
#'   gradient across the fill.
#' @param joint_type How stroke segments are joined: `"auto"`, `"round"`,
#'   `"bevel"` or `"miter"`.
#' @param cap_style Shape of the stroke ends: `"auto"`, `"round"`, `"butt"`
#'   or `"square"`.
#' @param close_new_points Close the path when new points are added.
#' @param make_smooth_after_applying_functions Smooth the curve after
#'   `apply_function()`.
#' @param shade_in_3d Shade the mobject by its orientation in a 3D scene.
#' @param pre_function_handle_to_anchor_scale_factor How far the handles are
#'   pulled toward their anchors before `apply_function()`.
#' @param background_image An image whose colors fill the mobject (see
#'   `$color_using_background_image()`).
#' @param tolerance_for_point_equality Distance below which two points count
#'   as the same.
#' @param n_points_per_cubic_curve Points per Bezier curve, 4.
#' @param ... Passed to [MobjectClass], for example `z_index` or `name`.
#' @export
VMobjectClass <- R6::R6Class("VMobject", inherit = MobjectClass, lock_objects = FALSE,
  public = list(
    fill_rgbas = NULL,
    stroke_rgbas = NULL,
    background_stroke_rgbas = NULL,
    fill_opacity = 0,
    stroke_opacity = 1,
    stroke_width = DEFAULT_STROKE_WIDTH,
    background_stroke_width = 0,
    background_stroke_opacity = 1,
    sheen_factor = 0,
    sheen_direction = NULL,
    joint_type = "auto",
    cap_style = "auto",
    close_new_points = FALSE,
    pre_function_handle_to_anchor_scale_factor = 0.01,
    make_smooth_after_applying_functions = FALSE,
    shade_in_3d = FALSE,
    tolerance_for_point_equality = 1e-6,
    n_points_per_cubic_curve = 4,
    init_fill_color = NULL,
    init_stroke_color = NULL,
    init_background_stroke_color = NULL,

    initialize = function(fill_color = NULL, fill_opacity = 0, stroke_color = NULL,
                          stroke_opacity = 1, stroke_width = DEFAULT_STROKE_WIDTH,
                          background_stroke_color = "#000000", background_stroke_opacity = 1,
                          background_stroke_width = 0, sheen_factor = 0, joint_type = "auto",
                          sheen_direction = UL, close_new_points = FALSE,
                          pre_function_handle_to_anchor_scale_factor = 0.01,
                          make_smooth_after_applying_functions = FALSE, background_image = NULL,
                          shade_in_3d = FALSE, tolerance_for_point_equality = 1e-6,
                          n_points_per_cubic_curve = 4, cap_style = "auto", color = "#FFFFFF", ...) {
      if (is.null(color)) color <- "#FFFFFF"
      self$pre_function_handle_to_anchor_scale_factor <- pre_function_handle_to_anchor_scale_factor
      self$background_image <- background_image
      self$tolerance_for_point_equality <- tolerance_for_point_equality
      self$n_points_per_cubic_curve <- n_points_per_cubic_curve
      self$init_fill_color <- fill_color %||% color
      self$init_stroke_color <- stroke_color %||% color
      self$init_background_stroke_color <- background_stroke_color
      self$fill_opacity <- fill_opacity
      self$stroke_opacity <- stroke_opacity
      self$stroke_width <- stroke_width
      self$background_stroke_opacity <- background_stroke_opacity
      self$background_stroke_width <- background_stroke_width
      self$sheen_factor <- sheen_factor
      self$sheen_direction <- as_point(sheen_direction)
      self$joint_type <- joint_type %||% "auto"
      self$cap_style <- cap_style
      self$close_new_points <- close_new_points
      self$make_smooth_after_applying_functions <- make_smooth_after_applying_functions
      self$shade_in_3d <- shade_in_3d
      super$initialize(color = color_items(color)[[1]], ...)
    },

    get_group_class = function() VGroup,

    init_colors = function(propagate_colors = TRUE) {
      # Upstream reads the fill_color / stroke_color properties here, which
      # return the current colors once style arrays exist.
      fill_col <- if (is.null(self$fill_rgbas)) self$init_fill_color else self$get_fill_colors()
      stroke_col <- if (is.null(self$stroke_rgbas)) self$init_stroke_color else self$get_stroke_colors()
      bg_col <- if (is.null(self$background_stroke_rgbas)) self$init_background_stroke_color
        else self$get_stroke_colors(background = TRUE)
      self$set_fill(color = fill_col, opacity = self$fill_opacity, family = propagate_colors)
      self$set_stroke(color = stroke_col, width = self$stroke_width,
                      opacity = self$stroke_opacity, family = propagate_colors)
      self$set_stroke(color = bg_col, width = self$background_stroke_width,
                      opacity = self$background_stroke_opacity, background = TRUE, family = propagate_colors)
      self$set_sheen(factor = self$sheen_factor, direction = self$sheen_direction, family = propagate_colors)
      invisible(self)
    },

    # Style ----------------------------------------------------------------
    generate_rgbas_array = function(color, opacity) {
      rgbas <- rgbas_from(color, opacity)
      sf <- self$sheen_factor
      if (sf != 0 && nrow(rgbas) == 1) {
        light <- rgbas
        light[, 1:3] <- pmin(pmax(light[, 1:3] + sf, 0), 1)
        rgbas <- rbind(rgbas, light)
      }
      rgbas
    },
    update_rgbas_array = function(array_name, color = NULL, opacity = NULL) {
      rgbas <- self$generate_rgbas_array(color, opacity)
      curr <- self[[array_name]]
      if (is.null(curr)) {
        self[[array_name]] <- rgbas
        return(invisible(self))
      }
      if (nrow(curr) < nrow(rgbas)) curr <- stretch_rows(curr, nrow(rgbas))
      else if (nrow(rgbas) < nrow(curr)) rgbas <- stretch_rows(rgbas, nrow(curr))
      if (!is.null(color)) curr[, 1:3] <- rgbas[, 1:3]
      if (!is.null(opacity)) curr[, 4] <- rgbas[, 4]
      self[[array_name]] <- curr
      invisible(self)
    },
    set_fill = function(color = NULL, opacity = NULL, family = TRUE) {
      if (family) for (sm in self$submobjects) if (is_vmobject(sm)) sm$set_fill(color, opacity, family)
      self$update_rgbas_array("fill_rgbas", color, opacity)
      if (!is.null(opacity)) self$fill_opacity <- opacity
      invisible(self)
    },
    set_stroke = function(color = NULL, width = NULL, opacity = NULL, background = FALSE, family = TRUE) {
      if (family) for (sm in self$submobjects) if (is_vmobject(sm)) sm$set_stroke(color, width, opacity, background, family)
      if (background) {
        self$update_rgbas_array("background_stroke_rgbas", color, opacity)
        if (!is.null(width)) self$background_stroke_width <- width
        if (!is.null(opacity)) self$background_stroke_opacity <- opacity
      } else {
        self$update_rgbas_array("stroke_rgbas", color, opacity)
        if (!is.null(width)) self$stroke_width <- width
        if (!is.null(opacity)) self$stroke_opacity <- opacity
      }
      invisible(self)
    },
    set_cap_style = function(cap_style) {
      self$cap_style <- cap_style
      invisible(self)
    },
    set_background_stroke = function(color = NULL, width = NULL, opacity = NULL, family = TRUE) {
      self$set_stroke(color, width, opacity, background = TRUE, family = family)
    },
    set_style = function(fill_color = NULL, fill_opacity = NULL, stroke_color = NULL, stroke_width = NULL,
                         stroke_opacity = NULL, background_stroke_color = NULL, background_stroke_width = NULL,
                         background_stroke_opacity = NULL, sheen_factor = NULL, sheen_direction = NULL,
                         background_image = NULL, family = TRUE) {
      self$set_fill(fill_color, fill_opacity, family = family)
      self$set_stroke(stroke_color, stroke_width, stroke_opacity, family = family)
      self$set_stroke(background_stroke_color, background_stroke_width, background_stroke_opacity,
                      background = TRUE, family = family)
      if (!is.null(sheen_factor) && sheen_factor != 0) {
        self$set_sheen(factor = sheen_factor, direction = sheen_direction, family = family)
      }
      if (!is.null(background_image)) self$color_using_background_image(background_image)
      invisible(self)
    },
    get_style = function(simple = FALSE) {
      ret <- list(stroke_opacity = self$get_stroke_opacity(), stroke_width = self$get_stroke_width())
      if (simple) {
        ret$fill_color <- self$get_fill_color()
        ret$fill_opacity <- self$get_fill_opacity()
        ret$stroke_color <- self$get_stroke_color()
      } else {
        ret$fill_color <- self$get_fill_colors()
        ret$fill_opacity <- self$get_fill_opacities()
        ret$stroke_color <- self$get_stroke_colors()
        ret$background_stroke_color <- self$get_stroke_colors(background = TRUE)
        ret$background_stroke_width <- self$get_stroke_width(background = TRUE)
        ret$background_stroke_opacity <- self$get_stroke_opacity(background = TRUE)
        ret$sheen_factor <- self$sheen_factor
        ret$sheen_direction <- self$sheen_direction
      }
      ret
    },
    match_style = function(vmobject, family = TRUE) {
      st <- vmobject$get_style()
      st$family <- FALSE
      do.call(self$set_style, st)
      if (family) {
        s1 <- self$submobjects
        s2 <- vmobject$submobjects
        if (length(s1) == 0) return(invisible(self))
        if (length(s2) == 0) s2 <- list(vmobject)
        n <- max(length(s1), length(s2))
        s1 <- stretch_list(s1, n)
        s2 <- stretch_list(s2, n)
        for (i in seq_len(n)) if (is_vmobject(s1[[i]]) && is_vmobject(s2[[i]])) s1[[i]]$match_style(s2[[i]])
      }
      invisible(self)
    },
    set_color = function(color = "#FFFF00", family = TRUE) {
      self$set_fill(color, family = family)
      self$set_stroke(color, family = family)
      self$color <- manim_color(color_items(color)[[1]])
      invisible(self)
    },
    set_opacity = function(opacity, family = TRUE) {
      self$set_fill(opacity = opacity, family = family)
      self$set_stroke(opacity = opacity, family = family)
      self$set_stroke(opacity = opacity, background = TRUE, family = family)
      invisible(self)
    },
    scale = function(scale_factor, scale_stroke = FALSE, about_point = NULL, about_edge = NULL, ...) {
      if (scale_stroke) {
        for (m in self$get_family()) {
          if (is_vmobject(m)) {
            m$set_stroke(width = abs(scale_factor[1]) * m$get_stroke_width(), family = FALSE)
            m$set_stroke(width = abs(scale_factor[1]) * m$get_stroke_width(background = TRUE),
                         background = TRUE, family = FALSE)
          }
        }
      }
      super$scale(scale_factor, about_point = about_point, about_edge = about_edge)
    },
    fade = function(darkness = 0.5, family = TRUE) {
      factor <- 1 - darkness
      self$set_fill(opacity = factor * self$get_fill_opacity(), family = FALSE)
      self$set_stroke(opacity = factor * self$get_stroke_opacity(), family = FALSE)
      self$set_stroke(opacity = factor * self$get_stroke_opacity(background = TRUE), background = TRUE, family = FALSE)
      super$fade(darkness, family)
    },
    get_fill_rgbas = function() self$fill_rgbas %||% matrix(0, 1, 4),
    get_fill_color = function() rgb_hex(self$get_fill_rgbas()[1, 1:3]),
    get_fill_opacity = function() self$get_fill_rgbas()[1, 4],
    get_fill_colors = function() apply(self$get_fill_rgbas(), 1, function(r) rgb_hex(r[1:3])),
    get_fill_opacities = function() self$get_fill_rgbas()[, 4],
    get_stroke_rgbas = function(background = FALSE) {
      (if (background) self$background_stroke_rgbas else self$stroke_rgbas) %||% matrix(0, 1, 4)
    },
    get_stroke_color = function(background = FALSE) rgb_hex(self$get_stroke_rgbas(background)[1, 1:3]),
    get_stroke_width = function(background = FALSE) {
      max(0, if (background) self$background_stroke_width else self$stroke_width)
    },
    get_stroke_opacity = function(background = FALSE) self$get_stroke_rgbas(background)[1, 4],
    get_stroke_colors = function(background = FALSE) {
      apply(self$get_stroke_rgbas(background), 1, function(r) rgb_hex(r[1:3]))
    },
    get_stroke_opacities = function(background = FALSE) self$get_stroke_rgbas(background)[, 4],
    get_color = function() {
      if (all(self$get_fill_opacities() == 0)) self$get_stroke_color() else self$get_fill_color()
    },
    set_sheen_direction = function(direction, family = TRUE) {
      direction <- as_point(direction)
      if (family) for (m in self$get_family()) m$sheen_direction <- direction
      else self$sheen_direction <- direction
      invisible(self)
    },
    rotate_sheen_direction = function(angle, axis = OUT, family = TRUE) {
      mobs <- if (family) self$get_family() else list(self)
      for (m in mobs) if (is_vmobject(m)) m$sheen_direction <- rotate_vector(m$sheen_direction, angle, axis)
      invisible(self)
    },
    set_sheen = function(factor, direction = NULL, family = TRUE) {
      if (family) for (sm in self$submobjects) if (is_vmobject(sm)) sm$set_sheen(factor, direction, family)
      self$sheen_factor <- factor
      if (!is.null(direction)) self$set_sheen_direction(direction, family = FALSE)
      if (factor != 0) {
        self$set_stroke(self$get_stroke_color(), family = family)
        self$set_fill(self$get_fill_color(), family = family)
      }
      invisible(self)
    },
    get_sheen_direction = function() self$sheen_direction,
    get_sheen_factor = function() self$sheen_factor,
    get_gradient_start_and_end_points = function() {
      if (isTRUE(self$shade_in_3d)) return(get_3d_vmob_gradient_start_and_end_points(self))
      direction <- self$get_sheen_direction()
      cc <- self$get_center()
      bases <- cbind(self$get_edge_center(RIGHT) - cc, self$get_edge_center(UP) - cc, self$get_edge_center(OUT) - cc)
      offset <- drop(bases %*% direction)
      list(cc - offset, cc + offset)
    },
    background_image = NULL,
    background_image_source = NULL,
    # The image (a file name looked up like upstream's
    # get_full_raster_image_path(), or an array of values 0 to 1) spans the
    # whole frame and shows through this mobject's fill and stroke, like
    # upstream's BackgroundColoredVMobjectDisplayer.
    color_using_background_image = function(background_image) {
      img <- if (is.character(background_image)) {
        read_raster_file(get_full_raster_image_path(background_image))
      } else {
        background_image
      }
      for (m in self$get_family()) {
        if (is_vmobject(m)) {
          m$background_image <- img
          m$background_image_source <- background_image
          m$set_color("#FFFFFF", family = FALSE)
        }
      }
      invisible(self)
    },
    get_background_image = function() self$background_image_source %||% self$background_image,
    match_background_image = function(vmobject) {
      if (!is.null(vmobject$background_image)) self$color_using_background_image(vmobject$get_background_image())
      invisible(self)
    },
    set_shade_in_3d = function(value = TRUE, z_index_as_group = FALSE) {
      for (m in self$get_family()) {
        if (is_vmobject(m)) {
          m$shade_in_3d <- value
          if (z_index_as_group) m$z_index_group <- self
        }
      }
      invisible(self)
    },

    # Points ---------------------------------------------------------------
    set_points = function(points) {
      self$points <- as_points(points)
      invisible(self)
    },
    resize_points = function(new_length, resize_func = resize_array) {
      if (new_length != nrow(self$points)) {
        self$points <- if (new_length == 0) matrix(0, 0, 3) else resize_func(self$points, new_length)
      }
      invisible(self)
    },
    set_anchors_and_handles = function(anchors1, handles1, handles2, anchors2) {
      self$points <- interleave_curves(as_points(anchors1), as_points(handles1), as_points(handles2), as_points(anchors2))
      invisible(self)
    },
    clear_points = function() {
      self$points <- matrix(0, 0, 3)
      invisible(self)
    },
    append_points = function(new_points) {
      self$points <- rbind(self$points, as_points(new_points))
      invisible(self)
    },
    start_new_path = function(point) {
      point <- as_point(point)
      n <- nrow(self$points)
      if (n %% 4 != 0) {
        last_anchor <- self$get_start_anchors()
        last_anchor <- last_anchor[nrow(last_anchor), ]
        closure <- matrix(last_anchor, 4 - n %% 4, 3, byrow = TRUE)
        self$append_points(rbind(closure, point))
      } else {
        self$append_points(matrix(point, 1))
      }
      invisible(self)
    },
    add_cubic_bezier_curve = function(anchor1, handle1, handle2, anchor2) {
      self$append_points(rbind(as_point(anchor1), as_point(handle1), as_point(handle2), as_point(anchor2)))
    },
    add_cubic_bezier_curves = function(curves) {
      self$append_points(as_points(curves))
    },
    add_cubic_bezier_curve_to = function(handle1, handle2, anchor) {
      self$throw_error_if_no_points()
      new <- rbind(as_point(handle1), as_point(handle2), as_point(anchor))
      if (self$has_new_path_started()) self$append_points(new)
      else self$append_points(rbind(self$get_last_point(), new))
      invisible(self)
    },
    add_quadratic_bezier_curve_to = function(handle, anchor) {
      handle <- as_point(handle)
      anchor <- as_point(anchor)
      last <- self$get_last_point()
      self$add_cubic_bezier_curve_to(2 / 3 * handle + 1 / 3 * last, 2 / 3 * handle + 1 / 3 * anchor, anchor)
    },
    add_line_to = function(point) {
      point <- as_point(point)
      last <- self$get_last_point()
      self$add_cubic_bezier_curve_to(interpolate(last, point, 1 / 3), interpolate(last, point, 2 / 3), point)
    },
    add_smooth_curve_to = function(...) {
      pts <- list(...)
      if (length(pts) == 1) {
        handle2 <- NULL
        new_anchor <- as_point(pts[[1]])
      } else if (length(pts) == 2) {
        handle2 <- as_point(pts[[1]])
        new_anchor <- as_point(pts[[2]])
      } else {
        stop("Only call add_smooth_curve_to with 1 or 2 points", call. = FALSE)
      }
      if (self$has_new_path_started()) {
        self$add_line_to(new_anchor)
      } else {
        self$throw_error_if_no_points()
        n <- nrow(self$points)
        last_h2 <- self$points[n - 1, ]
        last_a2 <- self$points[n, ]
        last_tangent <- last_a2 - last_h2
        handle1 <- last_a2 + last_tangent
        if (is.null(handle2)) {
          new_tangent <- rotate_vector(last_tangent, pi, axis = new_anchor - last_a2)
          handle2 <- new_anchor - new_tangent
        }
        self$append_points(rbind(last_a2, handle1, handle2, new_anchor))
      }
      invisible(self)
    },
    has_new_path_started = function() nrow(self$points) %% 4 == 1,
    get_last_point = function() self$points[nrow(self$points), ],
    is_closed = function() {
      n <- nrow(self$points)
      n > 0 && self$consider_points_equals(self$points[1, ], self$points[n, ])
    },
    close_path = function() {
      if (!self$is_closed()) {
        sp <- self$get_subpaths()
        self$add_line_to(sp[[length(sp)]][1, ])
      }
      invisible(self)
    },
    add_points_as_corners = function(points) {
      points <- as_points(points)
      np <- nrow(points)
      if (np == 0) return(invisible(self))
      start_corners <- rbind(self$points[nrow(self$points), ], points[-np, , drop = FALSE])
      end_corners <- points
      if (self$has_new_path_started()) self$points <- self$points[-nrow(self$points), , drop = FALSE]
      new <- interleave_curves(start_corners, interpolate(start_corners, end_corners, 1 / 3),
                               interpolate(start_corners, end_corners, 2 / 3), end_corners)
      self$append_points(new)
    },
    set_points_as_corners = function(points) {
      points <- as_points(points)
      n <- nrow(points)
      if (n < 2) {
        self$points <- points
        return(invisible(self))
      }
      a1 <- points[-n, , drop = FALSE]
      a2 <- points[-1, , drop = FALSE]
      self$set_anchors_and_handles(a1, interpolate(a1, a2, 1 / 3), interpolate(a1, a2, 2 / 3), a2)
    },
    set_points_smoothly = function(points) {
      self$set_points_as_corners(points)
      self$make_smooth()
    },
    change_anchor_mode = function(mode = c("jagged", "smooth")) {
      mode <- match.arg(mode)
      for (m in self$family_members_with_points()) {
        if (!is_vmobject(m)) next
        subpaths <- m$get_subpaths()
        m$clear_points()
        for (sp in subpaths) {
          anchors <- rbind(sp[seq(1, nrow(sp), by = 4), , drop = FALSE], sp[nrow(sp), ])
          na <- nrow(anchors)
          if (mode == "smooth") {
            hh <- get_smooth_cubic_bezier_handle_points(anchors)
            h1 <- hh$h1
            h2 <- hh$h2
          } else {
            a1 <- anchors[-na, , drop = FALSE]
            a2 <- anchors[-1, , drop = FALSE]
            h1 <- interpolate(a1, a2, 1 / 3)
            h2 <- interpolate(a1, a2, 2 / 3)
          }
          new_sp <- sp
          new_sp[seq(2, nrow(sp), by = 4), ] <- h1
          new_sp[seq(3, nrow(sp), by = 4), ] <- h2
          m$append_points(new_sp)
        }
      }
      invisible(self)
    },
    make_smooth = function() self$change_anchor_mode("smooth"),
    make_jagged = function() self$change_anchor_mode("jagged"),
    add_subpath = function(points) {
      self$append_points(points)
    },
    append_vectorized_mobject = function(vectorized_mobject) {
      if (self$has_new_path_started()) self$points <- self$points[-nrow(self$points), , drop = FALSE]
      self$append_points(vectorized_mobject$points)
    },
    apply_function = function(func, about_point = NULL, about_edge = NULL, ...) {
      factor <- self$pre_function_handle_to_anchor_scale_factor
      self$scale_handle_to_anchor_distances(factor)
      super$apply_function(func, about_point = about_point %||% ORIGIN, ...)
      self$scale_handle_to_anchor_distances(1 / factor)
      if (self$make_smooth_after_applying_functions) self$make_smooth()
      invisible(self)
    },
    rotate = function(angle, axis = OUT, about_point = NULL, about_edge = NULL, ...) {
      self$rotate_sheen_direction(angle, axis)
      super$rotate(angle, axis, about_point = about_point, about_edge = about_edge)
    },
    scale_handle_to_anchor_distances = function(factor) {
      for (m in self$family_members_with_points()) {
        n <- nrow(m$points)
        if (n < 4 || !is_vmobject(m)) next
        k <- n %/% 4
        i <- 4 * (seq_len(k) - 1)
        p <- m$points[seq_len(4 * k), , drop = FALSE]
        p[i + 2, ] <- p[i + 1, ] + factor * (p[i + 2, ] - p[i + 1, ])
        p[i + 3, ] <- p[i + 4, ] + factor * (p[i + 3, ] - p[i + 4, ])
        m$points <- p
      }
      invisible(self)
    },
    consider_points_equals = function(p0, p1) {
      points_close(p0, p1, atol = self$tolerance_for_point_equality)
    },
    consider_points_equals_2d = function(p0, p1) {
      rtol <- 1e-5
      atol <- self$tolerance_for_point_equality
      if (!isTRUE(p0[1] == p1[1])) {
        x_diff <- abs(p0[1] - p1[1])
        if (!(is.finite(x_diff) && x_diff <= atol + rtol * abs(p1[1]))) return(FALSE)
      }
      if (isTRUE(p0[2] == p1[2])) return(TRUE)
      y_diff <- abs(p0[2] - p1[2])
      is.finite(y_diff) && y_diff <= atol + rtol * abs(p1[2])
    },
    # A VMobject takes only VMobjects as submobjects.
    assert_valid_submobjects = function(submobjects) {
      self$assert_valid_submobjects_internal(submobjects, "VMobject")
    },

    # Curves and subpaths --------------------------------------------------
    get_cubic_bezier_tuples_from_points = function(points) {
      k <- nrow(points) %/% 4
      lapply(seq_len(k), function(i) points[(4 * i - 3):(4 * i), , drop = FALSE])
    },
    get_cubic_bezier_tuples = function() self$get_cubic_bezier_tuples_from_points(self$points),
    get_subpath_split_indices_from_points = function(points, n_dims = 3) {
      n <- nrow(points)
      if (n < 4) return(matrix(integer(), 0, 2))
      b <- if (n > 4) seq(4, n - 1, by = 4) else integer()
      if (length(b) == 0) return(matrix(c(0L, n), 1))
      ends <- points[b, 1:n_dims, drop = FALSE]
      starts <- points[b + 1, 1:n_dims, drop = FALSE]
      thr <- self$tolerance_for_point_equality + 1e-5 * abs(starts)
      close <- abs(ends - starts) <= thr
      close[is.na(close)] <- FALSE
      is_split <- rowSums(!close) > 0
      sp <- c(0, b[is_split], n)
      cbind(sp[-length(sp)], sp[-1])
    },
    get_subpaths_from_points = function(points) {
      idx <- self$get_subpath_split_indices_from_points(points)
      out <- list()
      for (r in seq_len(nrow(idx))) {
        s <- idx[r, 1]
        e <- idx[r, 2]
        if (e - s >= 4) out[[length(out) + 1]] <- points[(s + 1):e, , drop = FALSE]
      }
      out
    },
    get_subpaths = function() self$get_subpaths_from_points(self$points),
    get_nth_curve_points = function(n) {
      # n is 1 based
      self$points[(4 * n - 3):(4 * n), , drop = FALSE]
    },
    get_nth_curve_function = function(n) bezier(self$get_nth_curve_points(n)),
    get_nth_curve_length_pieces = function(n, sample_points = NULL) {
      sample_points <- sample_points %||% 10
      p <- cubic_basis(seq(0, 1, length.out = sample_points)) %*% self$get_nth_curve_points(n)
      sqrt(rowSums(diff(p)^2))
    },
    get_nth_curve_length = function(n, sample_points = NULL) sum(self$get_nth_curve_length_pieces(n, sample_points)),
    get_num_curves = function() nrow(self$points) %/% 4,
    n_points_per_curve = function() self$n_points_per_cubic_curve,
    gen_cubic_bezier_tuples_from_points = function(points) self$get_cubic_bezier_tuples_from_points(points),
    # Subpaths split where consecutive curves do not meet in the xy plane.
    gen_subpaths_from_points_2d = function(points) {
      n <- nrow(points) %/% 4
      if (n == 0) return(list())
      starts <- 1
      if (n > 1) {
        for (k in 2:n) {
          if (!self$consider_points_equals_2d(points[4 * (k - 1), ], points[4 * k - 3, ])) starts <- c(starts, k)
        }
      }
      ends <- c(starts[-1] - 1, n)
      lapply(seq_along(starts), function(i) points[(4 * starts[i] - 3):(4 * ends[i]), , drop = FALSE])
    },
    get_curve_functions = function() lapply(seq_len(self$get_num_curves()), self$get_nth_curve_function),
    get_nth_curve_function_with_length = function(n, sample_points = NULL) {
      list(curve = self$get_nth_curve_function(n),
           length = sum(self$get_nth_curve_length_pieces(n, sample_points = sample_points)))
    },
    get_curve_functions_with_lengths = function(...) {
      lapply(seq_len(self$get_num_curves()), function(n) self$get_nth_curve_function_with_length(n, ...))
    },
    get_curve_lengths = function(sample_points = NULL) {
      curve_lengths(self$points[seq_len(4 * self$get_num_curves()), , drop = FALSE], sample_points %||% 10)
    },
    point_from_proportion = function(alpha) {
      if (alpha < 0 || alpha > 1) stop("Alpha ", alpha, " not between 0 and 1.", call. = FALSE)
      self$throw_error_if_no_points()
      if (alpha == 1) return(self$points[nrow(self$points), ])
      lens <- self$get_curve_lengths()
      target <- alpha * sum(lens)
      cum <- 0
      for (i in seq_along(lens)) {
        if (cum + lens[i] >= target) {
          residue <- if (lens[i] != 0) (target - cum) / lens[i] else 0
          return(drop(cubic_basis(residue) %*% self$get_nth_curve_points(i)))
        }
        cum <- cum + lens[i]
      }
      self$points[nrow(self$points), ]
    },
    # As upstream: the arc length up to the point, found by solving each
    # cubic for the point (proportions_along_bezier_curve_for_point()),
    # divided by the total arc length.
    proportion_from_point = function(point) {
      self$throw_error_if_no_points()
      point <- as_point(point)
      lens <- self$get_curve_lengths()
      target <- 0
      for (i in seq_along(lens)) {
        props <- proportions_along_bezier_curve_for_point(point, self$get_nth_curve_points(i))
        if (length(props)) {
          target <- target + lens[i] * max(props)
          return(target / sum(lens))
        }
        target <- target + lens[i]
      }
      stop("Point ", paste0("(", paste(format(point), collapse = ", "), ")"), " does not lie on this curve.",
           call. = FALSE)
    },
    get_anchors_and_handles = function() {
      k <- nrow(self$points) %/% 4
      i <- 4 * (seq_len(k) - 1)
      list(self$points[i + 1, , drop = FALSE], self$points[i + 2, , drop = FALSE],
           self$points[i + 3, , drop = FALSE], self$points[i + 4, , drop = FALSE])
    },
    get_start_anchors = function() {
      n <- nrow(self$points)
      if (n == 0) return(matrix(0, 0, 3))
      self$points[seq(1, n, by = 4), , drop = FALSE]
    },
    get_end_anchors = function() {
      n <- nrow(self$points)
      if (n < 4) return(matrix(0, 0, 3))
      self$points[seq(4, n, by = 4), , drop = FALSE]
    },
    get_anchors = function() {
      n <- nrow(self$points)
      if (n == 1) return(self$points)
      if (n < 4) return(matrix(0, 0, 3))
      s <- self$get_start_anchors()
      e <- self$get_end_anchors()
      k <- min(nrow(s), nrow(e))
      out <- matrix(0, 2 * k, 3)
      out[seq(1, 2 * k, by = 2), ] <- s[seq_len(k), , drop = FALSE]
      out[seq(2, 2 * k, by = 2), ] <- e[seq_len(k), , drop = FALSE]
      out
    },
    get_points_defining_boundary = function() {
      pts <- lapply(self$get_family(), function(m) if (is_vmobject(m)) m$get_anchors() else m$points)
      out <- do.call(rbind, pts)
      if (is.null(out)) matrix(0, 0, 3) else out
    },
    get_arc_length = function(sample_points_per_curve = NULL) sum(self$get_curve_lengths(sample_points_per_curve)),

    # Alignment and interpolation -------------------------------------------
    align_points = function(vmobject) {
      self$align_rgbas(vmobject)
      if (self$get_num_points() == vmobject$get_num_points()) return(invisible(self))
      for (m in list(self, vmobject)) {
        if (m$has_no_points()) m$start_new_path(m$get_center())
        if (m$has_new_path_started()) m$add_line_to(m$get_last_point())
      }
      sp1 <- self$get_subpaths()
      sp2 <- vmobject$get_subpaths()
      n_sub <- max(length(sp1), length(sp2))
      get_nth <- function(lst, n) {
        if (n > length(lst)) {
          if (length(lst) == 0) return(matrix(0, 4, 3))
          last <- lst[[length(lst)]]
          return(matrix(last[nrow(last), ], 4, 3, byrow = TRUE))
        }
        path <- lst[[n]]
        while (nrow(path) > 4) {
          np <- nrow(path)
          tail4 <- path[(np - 3):np, , drop = FALSE]
          prev <- path[np - 4, ]
          if (all(apply(tail4, 1, function(r) self$consider_points_equals(r, prev)))) {
            path <- path[seq_len(np - 4), , drop = FALSE]
          } else {
            break
          }
        }
        path
      }
      new1 <- vector("list", n_sub)
      new2 <- vector("list", n_sub)
      for (n in seq_len(n_sub)) {
        a <- get_nth(sp1, n)
        b <- get_nth(sp2, n)
        diff1 <- max(0, (nrow(b) - nrow(a)) %/% 4)
        diff2 <- max(0, (nrow(a) - nrow(b)) %/% 4)
        new1[[n]] <- self$insert_n_curves_to_point_list(diff1, a)
        new2[[n]] <- self$insert_n_curves_to_point_list(diff2, b)
      }
      self$points <- do.call(rbind, new1)
      vmobject$points <- do.call(rbind, new2)
      invisible(self)
    },
    insert_n_curves = function(n) {
      new_path_point <- if (self$has_new_path_started()) self$get_last_point() else NULL
      self$points <- self$insert_n_curves_to_point_list(n, self$points)
      if (!is.null(new_path_point)) self$append_points(matrix(new_path_point, 1))
      invisible(self)
    },
    insert_n_curves_to_point_list = function(n, points) {
      if (nrow(points) == 1) return(points[rep(1, 4 * n), , drop = FALSE])
      if (n == 0) return(points[seq_len(4 * (nrow(points) %/% 4)), , drop = FALSE])
      cur <- nrow(points) %/% 4
      bezier_remap(points[seq_len(4 * cur), , drop = FALSE], cur + n)
    },
    align_rgbas = function(vmobject) {
      for (attr in c("fill_rgbas", "stroke_rgbas", "background_stroke_rgbas")) {
        a1 <- self[[attr]]
        a2 <- vmobject[[attr]]
        if (nrow(a1) > nrow(a2)) vmobject[[attr]] <- stretch_rows(a2, nrow(a1))
        else if (nrow(a2) > nrow(a1)) self[[attr]] <- stretch_rows(a1, nrow(a2))
      }
      invisible(self)
    },
    get_point_mobject = function(center = NULL) {
      pt <- VectorizedPoint(center %||% self$get_center())
      pt$match_style(self)
      pt
    },
    interpolate_color = function(mobject1, mobject2, alpha) {
      for (attr in c("fill_rgbas", "stroke_rgbas", "background_stroke_rgbas", "stroke_width",
                     "background_stroke_width", "sheen_direction", "sheen_factor")) {
        v1 <- mobject1[[attr]]
        v2 <- mobject2[[attr]]
        if (alpha == 1) {
          self[[attr]] <- v2
        } else if (is.matrix(v1) && is.matrix(v2) && nrow(v1) != nrow(v2)) {
          n <- max(nrow(v1), nrow(v2))
          self[[attr]] <- interpolate(stretch_rows(v1, n), stretch_rows(v2, n), alpha)
        } else {
          self[[attr]] <- interpolate(v1, v2, alpha)
        }
      }
      invisible(self)
    },
    pointwise_become_partial = function(vmobject, a, b) {
      if (!is_vmobject(vmobject)) stop("Expected a VMobject.", call. = FALSE)
      if (a <= 0 && b >= 1) {
        self$points <- vmobject$points
        return(invisible(self))
      }
      num_curves <- vmobject$get_num_curves()
      if (num_curves == 0) return(invisible(self))
      lo <- integer_interpolate(0, num_curves, a)
      hi <- integer_interpolate(0, num_curves, b)
      vp <- vmobject$points
      curve <- function(i) vp[(4 * i + 1):(4 * i + 4), , drop = FALSE]
      if (lo$index == hi$index) {
        self$points <- partial_bezier_points(curve(lo$index), lo$residue, hi$residue)
      } else {
        mid <- if (hi$index - lo$index > 1) vp[(4 * (lo$index + 1) + 1):(4 * hi$index), , drop = FALSE] else NULL
        self$points <- rbind(partial_bezier_points(curve(lo$index), lo$residue, 1), mid,
                             partial_bezier_points(curve(hi$index), 0, hi$residue))
      }
      invisible(self)
    },
    get_subcurve = function(a, b) {
      if (self$is_closed() && a > b) {
        vmob <- self$copy()
        vmob$pointwise_become_partial(self, a, 1)
        vmob2 <- self$copy()
        vmob2$pointwise_become_partial(self, 0, b)
        vmob$append_vectorized_mobject(vmob2)
      } else {
        vmob <- self$copy()
        vmob$pointwise_become_partial(self, a, b)
      }
      vmob
    },
    get_direction = function() shoelace_direction(self$get_start_anchors()),
    reverse_direction = function() {
      self$points <- self$points[rev(seq_len(nrow(self$points))), , drop = FALSE]
      invisible(self)
    },
    force_direction = function(target_direction = c("CW", "CCW")) {
      target_direction <- match.arg(target_direction)
      if (self$get_direction() != target_direction) self$reverse_direction()
      invisible(self)
    }
  )
)

# Upstream's fill_color and stroke_color properties: reading gives the
# current color, assigning sets it (as set_fill() and set_stroke()).
VMobjectClass$set("active", "fill_color", function(value) {
  if (missing(value)) return(self$get_fill_color())
  self$set_fill(value)
})
VMobjectClass$set("active", "stroke_color", function(value) {
  if (missing(value)) return(self$get_stroke_color())
  self$set_stroke(value)
})

#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @rdname VMobjectClass
#' @export
VMobject <- constructor(VMobjectClass)
#' @title VGroup
#' @description Group vectorized mobjects so they move and style together.
#' @param ... VMobjects, or lists of them. Named style arguments are passed to
#'   [VMobject()].
#' @export
#' @examples
#' g <- VGroup(Circle(), Square())$arrange(RIGHT)
VGroupClass <- R6::R6Class("VGroup", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    initialize = function(...) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      mobs <- args[nm == ""]
      do.call(super$initialize, args[nm != ""])
      self$add(mobs)
    },
    add = function(...) {
      mobs <- flatten_mobjects(list(...))
      for (i in seq_along(mobs)) {
        if (!is_vmobject(mobs[[i]])) {
          stop(sprintf("Only values of type VMobject can be added as submobjects of VGroup, but the value at index %d is of type %s. You can try adding this value into a Group instead.",
                       i, class(mobs[[i]])[1]), call. = FALSE)
        }
      }
      super$add(mobs)
    }
  )
)

#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @rdname VGroupClass
#' @export
VGroup <- constructor(VGroupClass)
#' @title VDict
#' @description A VGroup whose submobjects are addressed by key, as
#'   upstream's `VDict`: `d$add(list(s = Square()))` adds pairs,
#'   `d$remove("s")` removes one, `d[["s"]]` or `d$get("s")` reads one and
#'   `d[["s"]] <- Circle()` replaces it. With `show_keys = TRUE` each value
#'   gets its key as a [Tex()] label on its left (this needs LaTeX).
#' @param mapping_or_iterable A named list of VMobjects, or a list of
#'   `list(key, mobject)` pairs.
#' @param show_keys Whether to show the keys next to the values.
#' @param ... Passed to [VGroup()].
#' @export
VDictClass <- R6::R6Class("VDict", inherit = VGroupClass, lock_objects = FALSE,
  public = list(
    submob_dict = NULL,
    show_keys = FALSE,
    initialize = function(mapping_or_iterable = list(), show_keys = FALSE, ...) {
      super$initialize(...)
      self$show_keys <- show_keys
      self$submob_dict <- list()
      self$add(mapping_or_iterable)
    },
    # Adds key and value pairs. Mobjects given without keys are added as
    # plain submobjects, which the group methods of Mobject rely on.
    add = function(...) {
      args <- list(...)
      if (length(args) == 1 && is.list(args[[1]]) && !is_mobject(args[[1]])) {
        pairs <- vdict_pairs(args[[1]])
        for (i in seq_along(pairs$keys)) self$add_key_value_pair(pairs$keys[[i]], pairs$values[[i]])
        return(invisible(self))
      }
      do.call(super$add, args)
    },
    # Removes the value of a key (upstream's VDict.remove()); given
    # mobjects, removes them as submobjects.
    remove = function(...) {
      args <- list(...)
      if (length(args) == 1 && (is.character(args[[1]]) || is.numeric(args[[1]]))) {
        key <- as.character(args[[1]])
        if (!key %in% names(self$submob_dict)) {
          stop("The given key '", key, "' is not present in the VDict", call. = FALSE)
        }
        super$remove(self$submob_dict[[key]])
        self$submob_dict[[key]] <- NULL
        return(invisible(self))
      }
      do.call(super$remove, args)
    },
    add_key_value_pair = function(key, value) {
      key <- as.character(key)
      if (!inherits(value, "VMobject")) stop("All submobjects of a VDict must be of type VMobject", call. = FALSE)
      if (self$show_keys) value$add(Tex(key)$next_to(value, LEFT))
      self$submob_dict[[key]] <- value
      super$add(value)
      invisible(self)
    },
    get = function(key) {
      key <- as.character(unlist(key))
      bad <- setdiff(key, names(self$submob_dict))
      if (length(bad)) stop("No entry named '", bad[1], "' in this VDict", call. = FALSE)
      if (length(key) == 1) return(self$submob_dict[[key]])
      do.call(VGroup, unname(self$submob_dict[key]))
    },
    # Upstream's `del vdict[key]`: forgets the key and removes its value.
    remove_key = function(key) {
      if (as.character(key) %in% names(self$submob_dict)) self$remove(as.character(key))
      invisible(self)
    },
    has_key = function(key) as.character(key) %in% names(self$submob_dict),
    get_all_submobjects = function() unname(self$submob_dict)
  )
)

# The keys and values of a named list or of a list of (key, value) pairs.
vdict_pairs <- function(x) {
  if (!length(x)) return(list(keys = list(), values = list()))
  if (!is.null(names(x)) && all(nzchar(names(x)))) return(list(keys = as.list(names(x)), values = unname(x)))
  if (all(vapply(x, function(p) is.list(p) && length(p) == 2 && is_mobject(p[[2]]), NA))) {
    return(list(keys = lapply(x, `[[`, 1), values = lapply(x, `[[`, 2)))
  }
  stop("A VDict takes a named list of VMobjects or a list of list(key, mobject) pairs.", call. = FALSE)
}

#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @rdname VDictClass
#' @export
VDict <- constructor(VDictClass)
#' @title VectorizedPoint
#' @description An invisible vectorized point, used as an anchor for animations.
#' @param location The point.
#' @param color,fill_opacity,stroke_width Style; the point is invisible by
#'   default.
#' @param artificial_width,artificial_height Width and height reported for
#'   the point, which has no extent of its own.
#' @param ... Passed to [VMobject()].
#' @export
VectorizedPointClass <- R6::R6Class("VectorizedPoint", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    artificial_width = 0.01,
    artificial_height = 0.01,
    initialize = function(location = ORIGIN, color = "#000000", fill_opacity = 0, stroke_width = 0,
                          artificial_width = 0.01, artificial_height = 0.01, ...) {
      self$artificial_width <- artificial_width
      self$artificial_height <- artificial_height
      super$initialize(color = color, fill_opacity = fill_opacity, stroke_width = stroke_width, ...)
      self$set_points(matrix(as_point(location), 1))
    },
    get_location = function() self$points[1, ],
    set_location = function(new_loc) self$set_points(matrix(as_point(new_loc), 1))
  ),
  active = list(
    width = function(value) {
      if (missing(value)) return(self$artificial_width)
      self$scale_to_fit_width(value)
    },
    height = function(value) {
      if (missing(value)) return(self$artificial_height)
      self$scale_to_fit_height(value)
    }
  )
)

#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @rdname VectorizedPointClass
#' @export
VectorizedPoint <- constructor(VectorizedPointClass)
#' @title CurvesAsSubmobjects
#' @description Split a VMobject into one submobject per Bezier curve.
#' @param vmobject The VMobject to split.
#' @param ... Passed to [VGroup()].
#' @details `$point_from_proportion(alpha)` measures `alpha` along the total
#'   arc length of the curves, as upstream.
#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @name CurvesAsSubmobjects
#' @format NULL
#' @usage NULL
#' @export
CurvesAsSubmobjectsClass <- R6::R6Class("CurvesAsSubmobjects", inherit = VGroupClass, lock_objects = FALSE,
  public = list(
    initialize = function(vmobject, ...) {
      super$initialize(...)
      for (tup in vmobject$get_cubic_bezier_tuples()) {
        part <- VMobject()
        part$set_points(tup)
        part$match_style(vmobject)
        self$add(part)
      }
    },
    # The point at proportion `alpha` of the total arc length of the curves.
    point_from_proportion = function(alpha) {
      if (alpha < 0 || alpha > 1) stop("Alpha ", alpha, " not between 0 and 1.", call. = FALSE)
      parts <- Filter(function(p) p$has_points(), self$submobjects)
      if (!length(parts)) stop("This CurvesAsSubmobjects does not have any submobjects with points", call. = FALSE)
      if (alpha == 1) {
        last <- parts[[length(parts)]]$points
        return(last[nrow(last), ])
      }
      lengths <- vapply(parts, function(p) p$get_arc_length(), 0)
      target <- alpha * sum(lengths)
      current <- 0
      for (i in seq_along(parts)) {
        if (current + lengths[i] >= target) {
          return(parts[[i]]$point_from_proportion((target - current) / lengths[i]))
        }
        current <- current + lengths[i]
      }
    }
  )
)

#' @rdname CurvesAsSubmobjects
#' @export
CurvesAsSubmobjects <- constructor(CurvesAsSubmobjectsClass)

#' @title DashedVMobject
#' @description A dashed copy of a VMobject.
#' @param vmobject The VMobject to dash.
#' @param num_dashes Number of dashes.
#' @param dashed_ratio Fraction of the path covered by dashes.
#' @param dash_offset Shift of the dash pattern along the path.
#' @param color Color.
#' @param equal_lengths Whether dashes have equal arc lengths.
#' @param ... Passed to [VMobject()].
#' @return A `DashedVMobject`, an R6 mobject.
#' @export
DashedVMobject <- function(vmobject, num_dashes = 15, dashed_ratio = 0.5, dash_offset = 0,
                           color = "#FFFFFF", equal_lengths = TRUE, ...) {
  self <- VMobjectClass$new(color = color, ...)
  class(self) <- c("DashedVMobject", class(self))
  vm <- vmobject$copy()
  tips <- NULL
  if (!is.null(vm$pop_tips)) {
    popped <- vm$pop_tips()
    if (length(popped$submobjects)) tips <- popped
  }
  r <- dashed_ratio
  n <- num_dashes
  if (n > 0) {
    closed <- vm$is_closed()
    dash_len <- r / n
    void_len <- if (closed) (1 - r) / n else if (n == 1) 1 - r else (1 - r) / (n - 1)
    period <- dash_len + void_len
    phase <- (dash_offset %% 1) * period
    pattern_len <- if (closed) 1 else 1 + void_len
    starts <- ((0:(n - 1)) * period + phase) %% pattern_len
    ends <- ((0:(n - 1)) * period + dash_len + phase) %% pattern_len
    if (!closed) {
      L <- length(starts)
      if (ends[L] > 1 && starts[L] > 1) {
        starts <- starts[-L]
        ends <- ends[-L]
      } else if (ends[L] < dash_len) {
        if (starts[L] < 1) {
          starts <- c(starts, 0)
          ends <- c(ends, ends[L])
          ends[L] <- 1
        } else {
          starts[L] <- 0
        }
      } else if (starts[L] > 1 - dash_len) {
        ends[L] <- 1
      }
    }
    if (equal_lengths) {
      norms <- 0
      for (k in seq_len(vm$get_num_curves())) norms <- c(norms, vm$get_nth_curve_length_pieces(k))
      lv <- cumsum(norms)
      ref <- seq(0, 1, length.out = length(lv))
      total <- lv[length(lv)]
      for (i in seq_along(starts)) {
        a <- stats::approx(lv, ref, starts[i] * total, ties = "ordered", rule = 2)$y
        b <- stats::approx(lv, ref, ends[i] * total, ties = "ordered", rule = 2)$y
        self$add(vm$get_subcurve(a, b))
      }
    } else {
      for (i in seq_along(starts)) self$add(vm$get_subcurve(starts[i], ends[i]))
    }
  }
  self$match_style(vmobject, family = FALSE)
  if (!is.null(tips)) self$add(tips$submobjects)
  self
}
