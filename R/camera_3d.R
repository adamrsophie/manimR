# Three dimensional camera. Ported from manim/camera/three_d_camera.py.

#' @title ThreeDCamera
#' @description A camera looking at the scene from spherical angles `phi`
#'   (polar, off the z axis) and `theta` (azimuth), rotated by `gamma` about
#'   its line of sight, with a perspective projection of strength
#'   `focal_distance` and a `zoom` factor. Mobjects with `shade_in_3d = TRUE`
#'   are sorted by depth and shaded by their normal against `light_source`.
#'   The angles live in [ValueTracker()]s (`phi_tracker`, `theta_tracker`,
#'   `gamma_tracker`, `focal_distance_tracker`, `zoom_tracker`) so they can be
#'   animated.
#'
#'   `get_frame_center()` is the 3D point shown at the center of the screen.
#'   Upstream manim subtracts the frame center twice (once in the projection
#'   and once in the 2D view); here it is subtracted once, so a point at the
#'   frame center lands at the screen center and fixed in frame mobjects
#'   really stay fixed.
#' @details Shaded strokes are drawn in the mean of their two shaded colors
#'   rather than as a gradient, which grid can only do through a costly mask.
#' @param focal_distance Distance from the camera to the frame center; smaller
#'   values give a stronger perspective.
#' @param shading_factor,default_distance Kept for compatibility with Manim.
#' @param light_source_start_point Initial position of the light source.
#' @param should_apply_shading Shade mobjects that have `shade_in_3d = TRUE`.
#' @param exponential_projection Scale points in front of the frame by an
#'   exponential rather than the usual perspective factor.
#' @param phi,theta,gamma Polar angle, azimuth and roll of the camera, in
#'   radians.
#' @param zoom Zoom factor.
#' @param frame_center 3D point shown at the center of the screen.
#' @param ... Passed to [CameraClass].
#' @format NULL
#' @usage NULL
#' @export
ThreeDCameraClass <- R6::R6Class("ThreeDCamera", inherit = CameraClass, lock_objects = FALSE,
  public = list(
    focal_distance = 20,
    shading_factor = 0.2,
    default_distance = 5,
    light_source_start_point = NULL,
    light_source = NULL,
    should_apply_shading = TRUE,
    exponential_projection = FALSE,
    phi = 0,
    theta = -pi / 2,
    gamma = 0,
    zoom = 1,
    max_allowable_norm = NULL,
    phi_tracker = NULL,
    theta_tracker = NULL,
    focal_distance_tracker = NULL,
    gamma_tracker = NULL,
    zoom_tracker = NULL,
    frame_center_mob = NULL,
    fixed_orientation_mobjects = NULL,
    fixed_in_frame_mobjects = NULL,
    rotation_matrix = NULL,
    initialize = function(focal_distance = 20, shading_factor = 0.2, default_distance = 5,
                          light_source_start_point = 9 * DOWN + 7 * LEFT + 10 * OUT, should_apply_shading = TRUE,
                          exponential_projection = FALSE, phi = 0, theta = -90 * DEGREES, gamma = 0, zoom = 1,
                          frame_center = ORIGIN, ...) {
      # Upstream uses a Point; a VectorizedPoint draws nothing if it is added
      # to the scene during move_camera().
      self$frame_center_mob <- VectorizedPoint(frame_center)
      super$initialize(frame_center = frame_center, ...)
      self$focal_distance <- focal_distance
      self$phi <- phi
      self$theta <- theta
      self$gamma <- gamma
      self$zoom <- zoom
      self$shading_factor <- shading_factor
      self$default_distance <- default_distance
      self$light_source_start_point <- as_point(light_source_start_point)
      self$light_source <- VectorizedPoint(self$light_source_start_point)
      self$should_apply_shading <- should_apply_shading
      self$exponential_projection <- exponential_projection
      self$max_allowable_norm <- 3 * self$frame_width
      self$phi_tracker <- ValueTracker(phi)
      self$theta_tracker <- ValueTracker(theta)
      self$focal_distance_tracker <- ValueTracker(focal_distance)
      self$gamma_tracker <- ValueTracker(gamma)
      self$zoom_tracker <- ValueTracker(zoom)
      self$fixed_orientation_mobjects <- list()
      self$fixed_in_frame_mobjects <- character()
      self$reset_rotation_matrix()
    },
    get_frame_center = function() self$frame_center_mob$points[1, ],
    set_frame_center = function(point) {
      self$frame_center_mob$move_to(point)
      invisible(self)
    },
    draw_frame = function(mobjects, ...) {
      self$reset_rotation_matrix()
      super$draw_frame(mobjects, ...)
    },
    get_value_trackers = function() {
      list(self$phi_tracker, self$theta_tracker, self$focal_distance_tracker, self$gamma_tracker, self$zoom_tracker)
    },
    modified_rgbas = function(vmobject, rgbas) {
      if (!self$should_apply_shading) return(rgbas)
      if (isTRUE(vmobject$shade_in_3d) && vmobject$get_num_points() > 0) {
        light <- self$light_source$points[1, ]
        shaded <- if (nrow(rgbas) < 2) rgbas[c(1, 1), , drop = FALSE] else rgbas[1:2, , drop = FALSE]
        shaded[1, 1:3] <- get_shaded_rgb(shaded[1, 1:3], get_3d_vmob_start_corner(vmobject),
                                         get_3d_vmob_start_corner_unit_normal(vmobject), light)
        shaded[2, 1:3] <- get_shaded_rgb(shaded[2, 1:3], get_3d_vmob_end_corner(vmobject),
                                         get_3d_vmob_end_corner_unit_normal(vmobject), light)
        return(shaded)
      }
      rgbas
    },
    get_stroke_rgbas = function(vmobject, background = FALSE) {
      self$modified_rgbas(vmobject, vmobject$get_stroke_rgbas(background))
    },
    # A gradient mask per shaded face costs more than the rest of the face,
    # so the closed, opaque stroke of a shaded 3D face is drawn as segments,
    # each colored with the gradient's color at its midpoint, with round ends
    # that fill the joins. At the thin strokes faces use this matches the
    # gradient. Open or translucent strokes, where round ends would show or
    # overlap, use the exact gradient.
    apply_gradient_stroke = function(vmobject, paths, rgbas, lwd, join, cap) {
      # Wide strokes (where round joins would show) also use the exact path.
      if (!(isTRUE(vmobject$shade_in_3d) && self$should_apply_shading) || !all(paths$closed) ||
          any(rgbas[, 4] < 1) || lwd > 3) {
        return(super$apply_gradient_stroke(vmobject, paths, rgbas, lwd, join, cap))
      }
      ends <- self$project_points(do.call(rbind, vmobject$get_gradient_start_and_end_points()), vmobject)
      seg <- lapply(unique(paths$id), function(id) {
        k <- paths$id == id
        x <- paths$x[k]
        y <- paths$y[k]
        if (isTRUE(paths$closed[id]) && (x[1] != x[length(x)] || y[1] != y[length(y)])) {
          x <- c(x, x[1])
          y <- c(y, y[1])
        }
        n <- length(x)
        if (n < 2) return(NULL)
        cbind(x[-n], y[-n], x[-1], y[-1])
      })
      seg <- do.call(rbind, seg)
      if (is.null(seg)) return(invisible(self))
      d <- ends[2, ] - ends[1, ]
      # Split segments that span more than 2% of the gradient, so long
      # straight edges still change color smoothly.
      tpos <- function(x, y) ((x - ends[1, 1]) * d[1] + (y - ends[1, 2]) * d[2]) / max(sum(d^2), 1e-12)
      k <- pmax(1, ceiling(abs(tpos(seg[, 3], seg[, 4]) - tpos(seg[, 1], seg[, 2])) / 0.02))
      if (any(k > 1)) {
        idx <- rep(seq_len(nrow(seg)), k)
        f0 <- unlist(lapply(k, function(n) (seq_len(n) - 1) / n))
        f1 <- unlist(lapply(k, function(n) seq_len(n) / n))
        s <- seg[idx, , drop = FALSE]
        seg <- cbind(s[, 1] + f0 * (s[, 3] - s[, 1]), s[, 2] + f0 * (s[, 4] - s[, 2]),
                     s[, 1] + f1 * (s[, 3] - s[, 1]), s[, 2] + f1 * (s[, 4] - s[, 2]))
      }
      t <- ((seg[, 1] + seg[, 3]) / 2 - ends[1, 1]) * d[1] + ((seg[, 2] + seg[, 4]) / 2 - ends[1, 2]) * d[2]
      t <- pmin(pmax(t / max(sum(d^2), 1e-12), 0), 1)
      stops <- seq(0, 1, length.out = nrow(rgbas))
      cols <- rgba_hex(vapply(1:4, function(ch) stats::approx(stops, rgbas[, ch], t)$y, numeric(length(t))))
      grid::grid.segments(seg[, 1], seg[, 2], seg[, 3], seg[, 4], default.units = "native",
                          gp = grid::gpar(col = cols, lwd = lwd, lineend = "round"))
      invisible(self)
    },
    get_fill_rgbas = function(vmobject) self$modified_rgbas(vmobject, vmobject$get_fill_rgbas()),
    get_mobjects_to_display = function(...) {
      mobjects <- super$get_mobjects_to_display(...)
      if (length(mobjects) == 0) return(mobjects)
      rot <- self$get_rotation_matrix()
      keys <- vapply(mobjects, function(m) {
        if (!isTRUE(m$shade_in_3d)) return(Inf)
        ref <- if (!is.null(m$z_index_group)) m$z_index_group$get_center() else m$get_center()
        sum(rot[3, ] * ref)
      }, numeric(1))
      mobjects[order(keys)]
    },
    get_phi = function() self$phi_tracker$get_value(),
    get_theta = function() self$theta_tracker$get_value(),
    get_focal_distance = function() self$focal_distance_tracker$get_value(),
    get_gamma = function() self$gamma_tracker$get_value(),
    get_zoom = function() self$zoom_tracker$get_value(),
    set_phi = function(value) {
      self$phi_tracker$set_value(value)
      invisible(self)
    },
    set_theta = function(value) {
      self$theta_tracker$set_value(value)
      invisible(self)
    },
    set_focal_distance = function(value) {
      self$focal_distance_tracker$set_value(value)
      invisible(self)
    },
    set_gamma = function(value) {
      self$gamma_tracker$set_value(value)
      invisible(self)
    },
    set_zoom = function(value) {
      self$zoom_tracker$set_value(value)
      invisible(self)
    },
    reset_rotation_matrix = function() {
      self$rotation_matrix <- self$generate_rotation_matrix()
      invisible(self)
    },
    get_rotation_matrix = function() self$rotation_matrix,
    generate_rotation_matrix = function() {
      rotation_about_z(self$get_gamma()) %*% rotation_matrix(-self$get_phi(), RIGHT) %*%
        rotation_about_z(-self$get_theta() - 90 * DEGREES)
    },
    # Upstream ThreeDCamera.project_points: rotate about the frame center and
    # apply the perspective. Returns n x 3 points relative to the frame center.
    project_3d_points = function(points) {
      points <- as_points(points)
      fd <- self$get_focal_distance()
      zoom <- self$get_zoom()
      p <- sweep(points, 2, self$get_frame_center()) %*% t(self$get_rotation_matrix())
      zs <- p[, 3]
      if (self$exponential_projection) {
        factor <- exp(zs / fd)
        lt0 <- zs < 0
        factor[lt0] <- fd / (fd - zs[lt0])
      } else {
        factor <- fd / (fd - zs)
        factor[(fd - zs) < 0] <- 1e6
      }
      p[, 1:2] <- p[, 1:2] * (factor * zoom)
      p
    },
    project_point = function(point) self$project_3d_points(matrix(as_point(point), 1))[1, ],
    # Frame coordinates (n x 2) for drawing. The core view is centered on
    # get_frame_center(), so add it back to keep a single subtraction.
    project_points = function(points, mobject = NULL) {
      if (!all(is.finite(points))) points <- matrix(0, nrow(points), 3)
      fc <- self$get_frame_center()[1:2]
      id <- if (is.null(mobject)) "" else mobject$mob_id
      out <- if (id %in% self$fixed_in_frame_mobjects) {
        points[, 1:2, drop = FALSE]
      } else if (!is.null(self$fixed_orientation_mobjects[[id]])) {
        center <- as_point(self$fixed_orientation_mobjects[[id]]())
        new_center <- self$project_point(center)
        sweep(points, 2, new_center - center, "+")[, 1:2, drop = FALSE]
      } else {
        self$project_3d_points(points)[, 1:2, drop = FALSE]
      }
      sweep(out, 2, fc, "+")
    },
    add_fixed_orientation_mobjects = function(..., use_static_center_func = FALSE, center_func = NULL) {
      for (mobject in flatten_mobjects(list(...))) {
        func <- if (!is.null(center_func)) center_func else if (use_static_center_func) {
          local({
            point <- mobject$get_center()
            function() point
          })
        } else local({
          m <- mobject
          function() m$get_center()
        })
        for (submob in mobject$get_family()) self$fixed_orientation_mobjects[[submob$mob_id]] <- func
      }
      invisible(self)
    },
    add_fixed_in_frame_mobjects = function(...) {
      ids <- vapply(extract_mobject_family_members(flatten_mobjects(list(...))), function(m) m$mob_id, "")
      self$fixed_in_frame_mobjects <- union(self$fixed_in_frame_mobjects, ids)
      invisible(self)
    },
    remove_fixed_orientation_mobjects = function(...) {
      for (m in extract_mobject_family_members(flatten_mobjects(list(...)))) {
        self$fixed_orientation_mobjects[[m$mob_id]] <- NULL
      }
      invisible(self)
    },
    remove_fixed_in_frame_mobjects = function(...) {
      ids <- vapply(extract_mobject_family_members(flatten_mobjects(list(...))), function(m) m$mob_id, "")
      self$fixed_in_frame_mobjects <- setdiff(self$fixed_in_frame_mobjects, ids)
      invisible(self)
    }
  )
)

#' @return A camera: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @rdname ThreeDCameraClass
#' @export
ThreeDCamera <- constructor(ThreeDCameraClass)