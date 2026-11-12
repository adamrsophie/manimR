# Camera: turns mobjects into grid drawing calls.
# Ported from manim/camera/camera.py (Cairo path), drawing through grid.

JOINT_MAP <- c(auto = "mitre", miter = "mitre", mitre = "mitre", round = "round", bevel = "bevel")
CAP_MAP <- c(auto = "butt", butt = "butt", round = "round", square = "square")

rgba_hex <- function(rgba) {
  if (is.matrix(rgba)) {
    r <- pmin(pmax(rgba, 0), 1)
    return(grDevices::rgb(r[, 1], r[, 2], r[, 3], r[, 4]))
  }
  grDevices::rgb(pmin(pmax(rgba[1], 0), 1), pmin(pmax(rgba[2], 0), 1), pmin(pmax(rgba[3], 0), 1),
                 pmin(pmax(rgba[4], 0), 1))
}

#' @title Camera
#' @description Converts mobjects into frames. `CameraClass` handles the
#'   standard 2D view; [MovingCameraClass] adds a movable frame and
#'   [ThreeDCameraClass] a 3D projection.
#' @param pixel_width,pixel_height Size of the frame in pixels.
#' @param frame_width,frame_height Size of the frame in scene units; as
#'   upstream, the camera keeps the frame width and derives its height from
#'   the pixel aspect ratio.
#' @param frame_center Point at the center of the frame.
#' @param frame_rate Frames per second.
#' @param background_color,background_opacity Color and opacity of the
#'   background.
#' @param use_z_index Draw mobjects in order of their `z_index`.
#' @param background_image Path of an image (found with
#'   [get_full_raster_image_path()]) drawn as the background.
#' @param cairo_line_width_multiple Scale of stroke widths, as upstream's.
#' @param image_mode,n_channels,pixel_array_dtype Layout of the pixel array
#'   (see `$get_pixel_array()`): `"RGBA"`, 4 channels and `"uint8"` values, as
#'   upstream. `pixel_array_dtype` sets the largest channel value
#'   (`rgb_max_val`).
#' @param background Accepted as upstream, where the background built from
#'   `background_image` or `background_color` replaces it.
#' @param ... Ignored.
#' @export
CameraClass <- R6::R6Class("Camera", lock_objects = FALSE,
  public = list(
    pixel_width = NULL,
    pixel_height = NULL,
    frame_width_value = NULL,
    frame_height_value = NULL,
    frame_center_value = NULL,
    frame_rate = NULL,
    background_color = NULL,
    background_opacity = 1,
    use_z_index = TRUE,
    curve_tolerance = 0.25,
    initialize = function(background_image = NULL, frame_center = ORIGIN, image_mode = "RGBA", n_channels = 4,
                          pixel_array_dtype = "uint8", cairo_line_width_multiple = 0.01, use_z_index = TRUE,
                          background = NULL, pixel_height = cfg("pixel_height"),
                          pixel_width = cfg("pixel_width"), frame_height = cfg("frame_height"),
                          frame_width = cfg("frame_width"), frame_rate = cfg("frame_rate"),
                          background_color = cfg("background_color"),
                          background_opacity = cfg("background_opacity"), ...) {
      self$use_z_index <- use_z_index
      self$image_mode <- image_mode
      self$n_channels <- n_channels
      self$pixel_array_dtype <- pixel_array_dtype
      self$rgb_max_val <- pixel_dtype_max(pixel_array_dtype)
      # Stroke widths are in hundredths of a frame unit, as upstream.
      self$cairo_line_width_multiple <- cairo_line_width_multiple
      self$background_image <- self$load_background_image(background_image, pixel_width, pixel_height)
      self$pixel_width <- pixel_width
      self$pixel_height <- pixel_height
      self$frame_height <- frame_height
      self$frame_width <- frame_width %||% (frame_height * pixel_width / pixel_height)
      # As upstream's resize_frame_shape(): the frame keeps its width and
      # takes its height from the pixel aspect ratio.
      self$resize_frame_shape(0)
      self$frame_center <- as_point(frame_center)
      self$frame_rate <- frame_rate
      self$background_color <- background_color
      self$background_opacity <- if (isTRUE(cfg("transparent"))) 0 else background_opacity
      self$curve_tolerance <- cfg("curve_tolerance") %||% 0.25
    },
    # Current view, behind the frame_width, frame_height and frame_center
    # properties; MovingCamera overrides these to follow its frame.
    get_frame_width = function() self$frame_width_value,
    get_frame_height = function() self$frame_height_value,
    get_frame_center = function() self$frame_center_value,
    set_frame_width = function(frame_width) {
      self$frame_width_value <- frame_width
      invisible(self)
    },
    set_frame_height = function(frame_height) {
      self$frame_height_value <- frame_height
      invisible(self)
    },
    set_frame_center = function(frame_center) {
      self$frame_center_value <- frame_center
      invisible(self)
    },
    get_mobjects_to_display = function(mobjects, include_submobjects = TRUE, excluded_mobjects = NULL) {
      if (include_submobjects) {
        mobjects <- extract_mobject_family_members(mobjects, use_z_index = self$use_z_index,
                                                   only_those_with_points = TRUE)
        if (length(excluded_mobjects)) {
          ex <- vapply(extract_mobject_family_members(excluded_mobjects), function(m) m$mob_id, "")
          mobjects <- Filter(function(m) !m$mob_id %in% ex, mobjects)
        }
      }
      mobjects
    },
    # Project mobject points (n x 3) to frame coordinates (n x 2).
    project_points = function(points, mobject = NULL) points[, 1:2, drop = FALSE],
    push_view = function() {
      fw <- self$get_frame_width()
      fh <- self$get_frame_height()
      fc <- self$get_frame_center()
      grid::pushViewport(grid::viewport(xscale = fc[1] + c(-fw, fw) / 2, yscale = fc[2] + c(-fh, fh) / 2,
                                        name = "manim_frame"))
    },
    background_image = NULL,
    # Upstream reads the file and keeps its top left pixel_height x
    # pixel_width corner, drawn at its own pixel size.
    load_background_image = function(image, pixel_width, pixel_height) {
      if (is.null(image)) return(NULL)
      if (is.character(image)) {
        if (!file.exists(image)) stop("Background image not found: ", image, call. = FALSE)
        image <- read_raster_file(image)
      }
      if (inherits(image, "nativeRaster") || inherits(image, "raster")) return(image)
      d <- dim(image)
      # Gray and gray plus alpha images become RGB(A), as upstream converts
      # to its RGBA image mode.
      if (length(d) == 2) image <- array(image, c(d, 1))
      if (dim(image)[3] <= 2) {
        alpha <- if (dim(image)[3] == 2) image[, , 2] else 1
        image <- array(c(rep(image[, , 1], 3), rep_len(alpha, d[1] * d[2])), c(d[1:2], 4))
      }
      image[seq_len(min(d[1], pixel_height)), seq_len(min(d[2], pixel_width)), , drop = FALSE]
    },
    draw_background = function() {
      if (isTRUE(self$custom_background) && !is.null(self$background)) {
        grid::grid.raster(pmin(pmax(self$background / self$rgb_max_val, 0), 1), width = grid::unit(1, "npc"),
                          height = grid::unit(1, "npc"), interpolate = FALSE)
        return(invisible(self))
      }
      if (!is.null(self$background_image)) {
        d <- dim(self$background_image)
        grid::grid.raster(self$background_image, x = 0, y = 1, just = c("left", "top"),
                          width = grid::unit(d[2] / self$pixel_width, "npc"),
                          height = grid::unit(d[1] / self$pixel_height, "npc"), interpolate = FALSE)
        return(invisible(self))
      }
      if (self$background_opacity > 0) {
        # Whole 0 to 255 channel values, truncated as upstream fills its pixel array.
        bg <- rgba_hex(color_to_int_rgba(self$background_color, self$background_opacity) / 255)
        grid::grid.rect(gp = grid::gpar(fill = bg, col = NA))
      }
    },
    # Draw a full frame on the current device.
    draw_frame = function(mobjects, include_submobjects = TRUE, excluded_mobjects = NULL,
                                background_raster = NULL) {
      if (!is.null(background_raster)) {
        grid::grid.raster(background_raster, width = grid::unit(1, "npc"), height = grid::unit(1, "npc"),
                          interpolate = FALSE)
      } else {
        self$draw_background()
      }
      self$push_view()
      on.exit(grid::popViewport(), add = TRUE)
      for (m in self$get_mobjects_to_display(mobjects, include_submobjects, excluded_mobjects)) {
        self$display_mobject(m)
      }
      invisible(self)
    },
    display_mobject = function(m) {
      if (inherits(m, "ImageMobject")) self$display_image_mobject(m)
      else if (inherits(m, "PMobject")) self$display_point_cloud(m)
      else if (is_vmobject(m)) self$display_vectorized(m)
    },
    px_per_unit = function() self$pixel_width / self$get_frame_width(),
    display_vectorized = function(vmobject, ignore_background_image = FALSE) {
      paths <- self$vmobject_paths(vmobject)
      if (is.null(paths)) return(invisible(self))
      if (!ignore_background_image && !is.null(vmobject$background_image)) {
        return(self$display_with_background_image(vmobject, paths))
      }
      self$apply_stroke(vmobject, paths, background = TRUE)
      self$apply_fill(vmobject, paths)
      self$apply_stroke(vmobject, paths, background = FALSE)
      invisible(self)
    },
    # Flatten a VMobject into polyline subpaths in frame units.
    vmobject_paths = function(vmobject) {
      pts <- vmobject$points
      if (nrow(pts) < 4) return(NULL)
      xy <- self$project_points(pts, vmobject)
      split <- vmobject$get_subpath_split_indices_from_points(cbind(xy, 0), n_dims = 2)
      if (nrow(split) == 0) return(NULL)
      flatten_subpaths(xy, split, self$px_per_unit(), self$curve_tolerance,
                       vmobject$tolerance_for_point_equality)
    },
    # Draw the mobject's fill and stroke into a mask and show the frame
    # filling background image through it.
    display_with_background_image = function(vmobject, paths) {
      children <- list()
      rgbas <- vmobject$get_fill_rgbas()
      if (any(rgbas[, 4] > 0)) {
        children[[1]] <- grid::pathGrob(paths$x, paths$y, id = paths$id, rule = "winding", default.units = "native",
                                        gp = grid::gpar(fill = grDevices::rgb(0, 0, 0, max(rgbas[, 4])), col = NA))
      }
      width <- vmobject$get_stroke_width()
      if (width > 0) {
        gp <- grid::gpar(col = grDevices::rgb(0, 0, 0, max(vmobject$get_stroke_rgbas()[, 4])), fill = NA,
                         lwd = width * self$cairo_line_width_multiple * self$px_per_unit(), linejoin = JOINT_MAP[[vmobject$joint_type %||% "auto"]],
                         lineend = CAP_MAP[[vmobject$cap_style %||% "auto"]], linemitre = 10)
        children <- c(children, stroke_grobs(paths, gp))
      }
      if (!length(children)) return(invisible(self))
      fw <- self$get_frame_width()
      fh <- self$get_frame_height()
      fc <- self$get_frame_center()
      grid::pushViewport(grid::viewport(xscale = fc[1] + c(-fw, fw) / 2, yscale = fc[2] + c(-fh, fh) / 2,
                                        mask = grid::gTree(children = do.call(grid::gList, children))))
      grid::grid.raster(vmobject$background_image, width = grid::unit(1, "npc"), height = grid::unit(1, "npc"))
      grid::popViewport()
      invisible(self)
    },
    get_fill_rgbas = function(vmobject) vmobject$get_fill_rgbas(),
    get_stroke_rgbas = function(vmobject, background = FALSE) vmobject$get_stroke_rgbas(background),
    # grid resolves gradient coordinates relative to the bounding box of the
    # painted grob, so convert frame coordinates to npc of `bbox`
    # (xmin, xmax, ymin, ymax).
    gradient_paint = function(vmobject, rgbas, bbox) {
      ends <- vmobject$get_gradient_start_and_end_points()
      p <- self$project_points(rbind(ends[[1]], ends[[2]]), vmobject)
      w <- max(bbox[2] - bbox[1], 1e-9)
      h <- max(bbox[4] - bbox[3], 1e-9)
      nx <- (p[, 1] - bbox[1]) / w
      ny <- (p[, 2] - bbox[3]) / h
      cols <- rgba_hex(rgbas)
      grid::linearGradient(cols, stops = seq(0, 1, length.out = length(cols)),
                           x1 = nx[1], y1 = ny[1], x2 = nx[2], y2 = ny[2], extend = "pad", group = TRUE)
    },
    apply_fill = function(vmobject, paths) {
      rgbas <- self$get_fill_rgbas(vmobject)
      if (all(rgbas[, 4] <= 0)) return(invisible(self))
      # Equal stops (common on shaded 3D faces) need no gradient.
      same <- nrow(rgbas) == 1 || all(abs(rgbas - rep(rgbas[1, ], each = nrow(rgbas))) < 1e-12)
      fill <- if (same) rgba_hex(rgbas[1, ]) else {
        self$gradient_paint(vmobject, rgbas, c(range(paths$x), range(paths$y)))
      }
      grid::grid.path(paths$x, paths$y, id = paths$id, rule = "winding", default.units = "native",
                      gp = grid::gpar(fill = fill, col = NA))
      invisible(self)
    },
    apply_stroke = function(vmobject, paths, background = FALSE) {
      width <- vmobject$get_stroke_width(background)
      if (width == 0) return(invisible(self))
      rgbas <- self$get_stroke_rgbas(vmobject, background)
      if (all(rgbas[, 4] <= 0)) return(invisible(self))
      lwd <- width * self$cairo_line_width_multiple * self$px_per_unit()
      join <- JOINT_MAP[[vmobject$joint_type %||% "auto"]]
      cap <- CAP_MAP[[vmobject$cap_style %||% "auto"]]
      if (nrow(rgbas) > 1) {
        return(self$apply_gradient_stroke(vmobject, paths, rgbas, lwd, join, cap))
      }
      gp <- grid::gpar(col = rgba_hex(rgbas[1, ]), fill = NA, lwd = lwd, linejoin = join, lineend = cap, linemitre = 10)
      for (g in stroke_grobs(paths, gp)) grid::grid.draw(g)
      invisible(self)
    },
    # grid cannot stroke with a gradient, so stroke the path into a mask and
    # paint a gradient filled rectangle through it.
    apply_gradient_stroke = function(vmobject, paths, rgbas, lwd, join, cap) {
      gp <- grid::gpar(col = "black", fill = NA, lwd = lwd, linejoin = join, lineend = cap, linemitre = 10)
      mask <- grid::gTree(children = do.call(grid::gList, stroke_grobs(paths, gp)))
      pad <- lwd / self$px_per_unit()
      bbox <- c(range(paths$x) + c(-pad, pad), range(paths$y) + c(-pad, pad))
      fw <- self$get_frame_width()
      fh <- self$get_frame_height()
      fc <- self$get_frame_center()
      grid::pushViewport(grid::viewport(xscale = fc[1] + c(-fw, fw) / 2, yscale = fc[2] + c(-fh, fh) / 2, mask = mask))
      grid::grid.rect(x = mean(bbox[1:2]), y = mean(bbox[3:4]), width = bbox[2] - bbox[1], height = bbox[4] - bbox[3],
                      default.units = "native",
                      gp = grid::gpar(fill = self$gradient_paint(vmobject, rgbas, bbox), col = NA))
      grid::popViewport()
      invisible(self)
    },
    display_point_cloud = function(pmobject) {
      pts <- self$project_points(pmobject$points, pmobject)
      if (nrow(pts) == 0) return(invisible(self))
      rgbas <- stretch_rows(pmobject$rgbas, nrow(pts))
      cols <- rgba_hex(rgbas)
      # OpenGL point clouds are round dots of radius point_radius (upstream's
      # true_dot shader).
      if (inherits(pmobject, "OpenGLPMobject")) {
        grid::grid.circle(pts[, 1], pts[, 2], r = pmobject$point_radius, default.units = "native",
                          gp = grid::gpar(fill = cols, col = NA))
        return(invisible(self))
      }
      # Like upstream, each point is a square of int(thickness) pixels, with
      # the thickness adjusted for cameras smaller than the configured frame
      # (Camera.adjusted_thickness). One device pixel is 72 / 96 bigpts.
      # The squares cover pixels px - t %/% 2 + 1 ... px + t %/% 2 (upstream's
      # thickening nudges), where px is the point's truncated pixel position.
      factor <- (cfg("pixel_height") + cfg("pixel_width")) / (self$pixel_height + self$pixel_width)
      # int() in upstream truncates, so a thickness below 1 draws nothing.
      t <- trunc(1 + (pmobject$stroke_width - 1) * factor)
      if (t <= 0) return(invisible(self))
      ppu <- self$px_per_unit()
      fc <- self$get_frame_center()
      left <- fc[1] - self$get_frame_width() / 2
      top <- fc[2] + self$get_frame_height() / 2
      shift <- (t %/% 2 + 1 + (-t %/% 2 + 1)) / 2
      col_px <- trunc((pts[, 1] - left) * ppu) + shift
      row_px <- trunc((top - pts[, 2]) * ppu) + shift
      grid::grid.rect(left + col_px / ppu, top - row_px / ppu,
                      width = grid::unit(t * 72 / 96, "bigpts"), height = grid::unit(t * 72 / 96, "bigpts"),
                      default.units = "native", gp = grid::gpar(fill = cols, col = NA))
      invisible(self)
    },
    # Draws an image mobject through its four projected corners (upper left,
    # upper right, lower left, lower right), as upstream maps the image with
    # the homography of those corners. A quadrilateral less than half a pixel
    # high is skipped, as upstream. A rotated rectangle (flipped when
    # mirrored) is placed by the device's raster drawing, after a bicubic
    # resize when it is enlarged; any other shape (shear, perspective) is
    # resampled here with the image's algorithm.
    display_image_mobject = function(image_mobject) {
      corners <- self$project_points(image_mobject$points, image_mobject)
      ul <- corners[1, 1:2]; ur <- corners[2, 1:2]; dl <- corners[3, 1:2]
      dr <- if (nrow(corners) >= 4) corners[4, 1:2] else ur + dl - ul
      ppu <- self$pixel_width / self$get_frame_width()
      if (quad_pixel_height(rbind(ul, ur, dr, dl) * ppu) < 0.5) return(invisible(self))
      img <- image_mobject$get_raster()
      method <- image_mobject$resampling_algorithm %||% "bicubic"
      if (!method %in% c("nearest", "bilinear", "bicubic")) method <- "bilinear"
      e1 <- ur - ul
      e2 <- dl - ul
      w <- sqrt(sum(e1^2))
      h <- sqrt(sum(e2^2))
      parallelogram <- sqrt(sum((dr - (ur + dl - ul))^2)) < 1e-6 * max(w, h)
      perpendicular <- abs(sum(e1 * e2)) < 1e-6 * w * h
      if (!(parallelogram && perpendicular)) {
        return(self$display_image_resampled(img, ul, ur, dl, dr, method))
      }
      # An enlarged rectangle is resized with Pillow's bicubic filter first;
      # the device then only places it.
      # Limitation: an image enlarged to more pixels than the whole frame (as
      # in a zoomed camera, which shows a small part of it) uses the device's
      # smooth interpolation instead, which keeps memory and time bounded.
      new_h <- max(round(h * ppu), 1)
      new_w <- max(round(w * ppu), 1)
      if (method == "bicubic" && (new_w > dim(img)[2] || new_h > dim(img)[1]) &&
          new_h * new_w <= self$pixel_width * self$pixel_height) {
        img <- cached_resize(image_mobject$mob_id, img, new_h, new_w)
      }
      # With y pointing up, an upright image has e1 x e2 < 0; a positive
      # cross product means a mirror image.
      if (e1[1] * e2[2] - e1[2] * e2[1] > 0) img <- img[rev(seq_len(dim(img)[1])), , , drop = FALSE]
      angle <- atan2(e1[2], e1[1]) * 180 / pi
      center <- (ur + dl) / 2
      grid::pushViewport(grid::viewport(x = grid::unit(center[1], "native"), y = grid::unit(center[2], "native"),
                                        width = grid::unit(w, "native"), height = grid::unit(h, "native"),
                                        angle = angle))
      grid::grid.raster(array_to_native_raster(img), interpolate = method != "nearest")
      grid::popViewport()
      invisible(self)
    },
    # Resamples `img` onto the quadrilateral ul, ur, dl, dr through the
    # homography of the unit square to those corners, sampling the image
    # with `method` ("nearest", "bilinear" or "bicubic") as Pillow's
    # perspective transform does. Points outside the image are transparent.
    display_image_resampled = function(img, ul, ur, dl, dr, method = "bicubic") {
      if (isTRUE(method)) method <- "bilinear"
      if (isFALSE(method)) method <- "nearest"
      # Three collinear corners make the mapping singular; upstream skips
      # the image then. Other errors are not caught.
      singular <- function(e) if (grepl("singular", conditionMessage(e))) NULL else stop(e)
      H <- tryCatch(homography_from_unit_square(ul, ur, dl, dr), error = singular)
      Hinv <- if (is.null(H)) NULL else tryCatch(solve(H), error = singular)
      if (is.null(Hinv)) return(invisible(self))
      xs <- c(ul[1], ur[1], dl[1], dr[1])
      ys <- c(ul[2], ur[2], dl[2], dr[2])
      ppu <- self$pixel_width / self$get_frame_width()
      nx <- max(ceiling((max(xs) - min(xs)) * ppu), 1)
      ny <- max(ceiling((max(ys) - min(ys)) * ppu), 1)
      # Limitation: the sampling grid has at most as many points as the frame
      # has pixels, so a huge warped image is sampled more coarsely.
      shrink <- sqrt(nx * ny / (self$pixel_width * self$pixel_height))
      if (shrink > 1) {
        nx <- max(floor(nx / shrink), 1)
        ny <- max(floor(ny / shrink), 1)
      }
      gx <- min(xs) + (seq_len(nx) - 0.5) * (max(xs) - min(xs)) / nx
      gy <- max(ys) - (seq_len(ny) - 0.5) * (max(ys) - min(ys)) / ny
      px <- rep(gx, each = ny)
      py <- rep(gy, times = nx)
      q <- Hinv %*% rbind(px, py, 1)
      u <- q[1, ] / q[3, ]
      v <- q[2, ] / q[3, ]
      ih <- dim(img)[1]
      iw <- dim(img)[2]
      inside <- is.finite(u) & is.finite(v) & u >= 0 & u <= 1 & v >= 0 & v <= 1 & q[3, ] > 0
      out <- array(0, c(ny, nx, 4))
      if (any(inside)) {
        vals <- sample_image(img, pmin(u[inside] * iw, iw - 1e-9), pmin(v[inside] * ih, ih - 1e-9), method)
        for (k in 1:4) {
          ch <- numeric(length(u))
          ch[inside] <- vals[, k]
          out[, , k] <- matrix(ch, ny, nx)
        }
      }
      grid::grid.raster(array_to_native_raster(out), x = grid::unit(min(xs), "native"), y = grid::unit(min(ys), "native"),
                        width = grid::unit(max(xs) - min(xs), "native"),
                        height = grid::unit(max(ys) - min(ys), "native"), just = c("left", "bottom"),
                        interpolate = method != "nearest")
      invisible(self)
    }
  ),
  active = list(
    frame_width = function(value) if (missing(value)) self$get_frame_width() else self$set_frame_width(value),
    frame_height = function(value) if (missing(value)) self$get_frame_height() else self$set_frame_height(value),
    frame_center = function(value) if (missing(value)) self$get_frame_center() else self$set_frame_center(value)
  )
)

# The height in pixels of quadrilateral `quad` (corners in order, one per
# row) over its longest side, as upstream checks before drawing an image.
quad_pixel_height <- function(quad) {
  sides <- quad[c(2, 3, 4, 1), , drop = FALSE] - quad
  len <- sqrt(rowSums(sides^2))
  i <- which.max(len)
  if (!length(i) || !is.finite(len[i]) || len[i] == 0) return(0)
  cross <- function(a, b) abs(a[1] * b[2] - a[2] * b[1])
  prev <- sides[(i - 2) %% 4 + 1, ]
  nxt <- sides[i %% 4 + 1, ]
  max(cross(sides[i, ], prev), cross(sides[i, ], nxt)) / len[i]
}

# Weights of Pillow's bicubic filter (a = -0.5) for the four pixels around
# a sample at fraction t (0 <= t < 1) past the second of them.
cubic_weights <- function(t) {
  a <- -0.5
  t2 <- t * t
  t3 <- t2 * t
  s <- 1 - t
  s2 <- s * s
  cbind(a * t3 - 2 * a * t2 + a * t, (a + 2) * t3 - (a + 3) * t2 + 1, (a + 2) * s2 * s - (a + 3) * s2 + 1,
        a * s2 * s - 2 * a * s2 + a * s)
}

# Samples the h x w x 4 image `img` at pixel coordinates x (columns) and y
# (rows) measured from its upper left corner, with Pillow's nearest,
# bilinear or bicubic filter: pixel centers at half integers, edge pixels
# repeated, results clipped to the image's value range.
sample_image <- function(img, x, y, method = "bicubic") {
  ih <- dim(img)[1]
  iw <- dim(img)[2]
  plane <- ih * iw
  if (method == "nearest") {
    idx <- pmin(pmax(floor(y) + 1, 1), ih) + (pmin(pmax(floor(x) + 1, 1), iw) - 1) * ih
    return(vapply(1:4, function(k) img[idx + (k - 1) * plane], numeric(length(x))))
  }
  x <- x - 0.5
  y <- y - 0.5
  x0 <- floor(x)
  y0 <- floor(y)
  if (method == "bilinear") {
    offs <- 0:1
    wx <- cbind(1 - (x - x0), x - x0)
    wy <- cbind(1 - (y - y0), y - y0)
  } else {
    offs <- -1:2
    wx <- cubic_weights(x - x0)
    wy <- cubic_weights(y - y0)
  }
  rows <- lapply(offs, function(o) pmin(pmax(y0 + o + 1, 1), ih))
  cols <- lapply(offs, function(o) (pmin(pmax(x0 + o + 1, 1), iw) - 1) * ih)
  top <- max(1, max(img))
  vapply(1:4, function(k) {
    ch <- img[, , k]
    acc <- 0
    for (i in seq_along(offs)) {
      for (j in seq_along(offs)) acc <- acc + wy[, i] * wx[, j] * ch[rows[[i]] + cols[[j]]]
    }
    pmin(pmax(acc, 0), top)
  }, numeric(length(x)))
}

# The n x size matrix of filter weights that resamples `size` pixels to `n`
# along one axis, as Pillow samples output pixel centers.
resample_weights <- function(size, n, method = "bicubic") {
  pos <- (seq_len(n) - 0.5) * size / n - 0.5
  p0 <- floor(pos)
  if (method == "bilinear") {
    offs <- 0:1
    w <- cbind(1 - (pos - p0), pos - p0)
  } else {
    offs <- -1:2
    w <- cubic_weights(pos - p0)
  }
  out <- matrix(0, n, size)
  for (i in seq_along(offs)) {
    idx <- cbind(seq_len(n), pmin(pmax(p0 + offs[i] + 1, 1), size))
    out[idx] <- out[idx] + w[, i]
  }
  out
}

# resize_image() for the image of mobject `id`, reusing the last result while
# the image and the size stay the same, as they do in most frames.
cached_resize <- function(id, img, new_h, new_w) {
  if (is.null(.manim$resize_cache)) .manim$resize_cache <- new.env(parent = emptyenv())
  hit <- .manim$resize_cache[[id]]
  if (!is.null(hit) && hit$h == new_h && hit$w == new_w && identical(hit$src, img)) return(hit$out)
  out <- resize_image(img, new_h, new_w)
  # Limitation: holds at most 16 images and drops arbitrary ones beyond that.
  keys <- ls(.manim$resize_cache)
  if (length(keys) >= 16) rm(list = keys[seq_len(length(keys) - 15)], envir = .manim$resize_cache)
  assign(id, list(src = img, h = new_h, w = new_w, out = out), envir = .manim$resize_cache)
  out
}

# Resizes an h x w x 4 image to new_h x new_w with a separable filter.
resize_image <- function(img, new_h, new_w, method = "bicubic") {
  wy <- resample_weights(dim(img)[1], new_h, method)
  wx <- t(resample_weights(dim(img)[2], new_w, method))
  top <- max(1, max(img))
  out <- array(0, c(new_h, new_w, 4))
  for (k in 1:4) out[, , k] <- pmin(pmax(wy %*% img[, , k] %*% wx, 0), top)
  out
}

# The 3 x 3 homography that maps the unit square's corners (0, 0), (1, 0),
# (0, 1), (1, 1) to p00, p10, p01, p11.
homography_from_unit_square <- function(p00, p10, p01, p11) {
  src <- rbind(c(0, 0), c(1, 0), c(0, 1), c(1, 1))
  dst <- rbind(p00, p10, p01, p11)
  A <- matrix(0, 8, 8)
  b <- numeric(8)
  for (i in 1:4) {
    u <- src[i, 1]; v <- src[i, 2]; x <- dst[i, 1]; y <- dst[i, 2]
    A[2 * i - 1, ] <- c(u, v, 1, 0, 0, 0, -u * x, -v * x)
    A[2 * i, ] <- c(0, 0, 0, u, v, 1, -u * y, -v * y)
    b[2 * i - 1] <- x
    b[2 * i] <- y
  }
  hvec <- solve(A, b)
  matrix(c(hvec, 1), 3, 3, byrow = TRUE)
}

# Stroke grobs for flattened paths: closed subpaths as paths (so the closing
# corner gets a proper join), open ones as polylines (grid paths always close).
stroke_grobs <- function(paths, gp) {
  out <- list()
  closed <- paths$closed
  if (any(closed)) {
    keep <- paths$id %in% which(closed)
    out[[1]] <- grid::pathGrob(paths$x[keep], paths$y[keep], id = paths$id[keep], default.units = "native", gp = gp)
  }
  if (any(!closed)) {
    keep <- paths$id %in% which(!closed)
    out[[length(out) + 1]] <- grid::polylineGrob(paths$x[keep], paths$y[keep], id = paths$id[keep],
                                                 default.units = "native", gp = gp)
  }
  out
}

# Flatten projected Bezier points into polyline subpaths. Curves are sampled
# with a per-curve segment count from Wang's formula, which bounds the
# deviation from the true curve by `tol` pixels.
flatten_subpaths <- function(xy, split, px_per_unit, tol = 0.25, point_tol = 1e-6) {
  xs <- list(); ys <- list(); ids <- list(); closed <- logical()
  sid <- 0L
  for (r in seq_len(nrow(split))) {
    s <- split[r, 1]
    e <- split[r, 2]
    k <- (e - s) %/% 4
    if (k < 1) next
    i0 <- s + 4 * (seq_len(k) - 1) + 1
    P0 <- xy[i0, , drop = FALSE]
    P1 <- xy[i0 + 1, , drop = FALSE]
    P2 <- xy[i0 + 2, , drop = FALSE]
    P3 <- xy[i0 + 3, , drop = FALSE]
    d1 <- P0 - 2 * P1 + P2
    d2 <- P1 - 2 * P2 + P3
    M <- pmax(sqrt(rowSums(d1^2)), sqrt(rowSums(d2^2))) * px_per_unit
    n <- pmin(pmax(ceiling(sqrt(0.75 * M / tol)), 1), 256)
    n[!is.finite(n)] <- 1
    t <- sequence(n) / rep(n, n)
    cid <- rep(seq_len(k), n)
    mt <- 1 - t
    b0 <- mt^3; b1 <- 3 * mt^2 * t; b2 <- 3 * mt * t^2; b3 <- t^3
    x <- b0 * P0[cid, 1] + b1 * P1[cid, 1] + b2 * P2[cid, 1] + b3 * P3[cid, 1]
    y <- b0 * P0[cid, 2] + b1 * P1[cid, 2] + b2 * P2[cid, 2] + b3 * P3[cid, 2]
    sid <- sid + 1L
    xs[[sid]] <- c(P0[1, 1], x)
    ys[[sid]] <- c(P0[1, 2], y)
    ids[[sid]] <- rep(sid, length(x) + 1)
    first <- xy[s + 1, ]
    last <- xy[s + 4 * k, ]
    closed[sid] <- all(abs(first - last) <= point_tol + 1e-5 * abs(last))
  }
  if (sid == 0) return(NULL)
  list(x = unlist(xs), y = unlist(ys), id = unlist(ids), closed = closed)
}

# Family members of a list of mobjects, deduplicated, optionally z sorted.
#' @rdname list_helpers
#' @export
extract_mobject_family_members <- function(mobject_list, use_z_index = FALSE, only_those_with_points = FALSE) {
  fam <- unlist(lapply(mobject_list, function(m) {
    if (only_those_with_points) m$family_members_with_points() else m$get_family()
  }), recursive = FALSE)
  if (length(fam) == 0) return(list())
  ids <- vapply(fam, function(m) m$mob_id, "")
  fam <- fam[!duplicated(ids, fromLast = TRUE)]
  if (use_z_index) {
    z <- vapply(fam, function(m) as.numeric(m$z_index), numeric(1))
    fam <- fam[order(z, method = "radix")]
  }
  fam
}
