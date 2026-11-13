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
      # A face of an OpenGLTexturedSurface with a dark image takes its color
      # from where this camera sees it.
      if (!is.null(vmobject$texture_rgbas) && nrow(vmobject$texture_rgbas) > 1) opengl_texture_shade(vmobject, self)
      paths <- self$vmobject_paths(vmobject)
      if (is.null(paths)) return(invisible(self))
      if (!ignore_background_image && !is.null(vmobject$background_image)) {
        return(self$display_with_background_image(vmobject, paths))
      }
      self$apply_stroke(vmobject, paths, background = TRUE)
      # An OpenGL mobject may draw its stroke behind the fill, as upstream's
      # draw_stroke_behind_fill.
      behind <- isTRUE(vmobject$draw_stroke_behind_fill)
      if (behind) self$apply_stroke(vmobject, paths, background = FALSE)
      self$apply_fill(vmobject, paths)
      if (!behind) self$apply_stroke(vmobject, paths, background = FALSE)
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
    # Draws an image mobject as upstream's Camera.display_image_mobject():
    # the four projected corners (upper left, upper right, lower left, lower
    # right) in subpixel coordinates give the box the image is pasted into
    # and the perspective transform Pillow resamples it with.
    display_image_mobject = function(image_mobject) {
      corners <- self$project_points(image_mobject$points, image_mobject)
      ul <- corners[1, 1:2]; ur <- corners[2, 1:2]; dl <- corners[3, 1:2]
      dr <- if (nrow(corners) >= 4) corners[4, 1:2] else ur + dl - ul
      method <- image_mobject$resampling_algorithm %||% "bicubic"
      if (!method %in% c("nearest", "bilinear", "bicubic")) method <- "bilinear"
      self$display_image_resampled(image_mobject$get_raster(), ul, ur, dl, dr, method, id = image_mobject$mob_id)
    },
    # Maps `img` (values in 0 to 1) onto the quadrilateral ul, ur, dl, dr (in
    # frame coordinates) as upstream does: truncated pixel corners give the
    # paste box, the homography from the subpixel corners to the image's
    # corners drives Pillow's perspective transform with `method`
    # ("nearest", "bilinear" or "bicubic"), and pixels outside the frame are
    # dropped. A quadrilateral less than half a pixel high is skipped.
    display_image_resampled = function(img, ul, ur, dl, dr, method = "bicubic", id = NULL) {
      if (isTRUE(method)) method <- "bilinear"
      if (isFALSE(method)) method <- "nearest"
      fc <- self$get_frame_center()
      pw <- self$pixel_width
      ph <- self$pixel_height
      to_px <- function(p) c((p[1] - fc[1]) * pw / self$get_frame_width() + pw / 2,
                             (p[2] - fc[2]) * -ph / self$get_frame_height() + ph / 2)
      target <- rbind(to_px(ul), to_px(ur), to_px(dl), to_px(dr))
      if (!all(is.finite(target))) return(invisible(self))
      itarget <- trunc(target)
      shift <- c(min(itarget[, 1]), min(itarget[, 2]))
      target <- sweep(target, 2, shift)
      itarget <- sweep(itarget, 2, shift)
      size <- c(max(itarget[, 1]), max(itarget[, 2]))
      if (quad_pixel_height(target[c(1, 2, 4, 3), ]) < 0.5) return(invisible(self))
      coeffs <- pillow_perspective_coefficients(target, dim(img)[2], dim(img)[1])
      if (is.null(coeffs) || any(size < 1)) return(invisible(self))
      # Paste box clipped to the frame, as pasting into a frame sized image.
      c0 <- max(shift[1], 0); c1 <- min(shift[1] + size[1], pw)
      r0 <- max(shift[2], 0); r1 <- min(shift[2] + size[2], ph)
      if (c1 <= c0 || r1 <= r0) return(invisible(self))
      key <- list(img, coeffs, size, method, c(c0, c1, r0, r1) - c(shift[1], shift[1], shift[2], shift[2]))
      if (is.null(.manim$transform_cache)) .manim$transform_cache <- new.env(parent = emptyenv())
      hit <- if (is.null(id)) NULL else .manim$transform_cache[[id]]
      if (!is.null(hit) && identical(hit$key, key)) {
        out <- hit$out
      } else {
        out <- pillow_transform(round(img * 255), coeffs, key[[5]], method) / 255
        if (!is.null(id)) {
          # Limitation: holds at most 16 images and drops arbitrary ones beyond that.
          keys <- ls(.manim$transform_cache)
          if (length(keys) >= 16) rm(list = keys[seq_len(length(keys) - 15)], envir = .manim$transform_cache)
          assign(id, list(key = key, out = out), envir = .manim$transform_cache)
        }
      }
      x0 <- fc[1] - self$get_frame_width() / 2
      y1 <- fc[2] + self$get_frame_height() / 2
      dx <- self$get_frame_width() / pw
      dy <- self$get_frame_height() / ph
      grid::grid.raster(array_to_native_raster(out), x = grid::unit(x0 + c0 * dx, "native"),
                        y = grid::unit(y1 - r1 * dy, "native"), width = grid::unit((c1 - c0) * dx, "native"),
                        height = grid::unit((r1 - r0) * dy, "native"), just = c("left", "bottom"), interpolate = FALSE)
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

# The 8 coefficients of Pillow's perspective transform that map the
# subpixel corners `target` (upper left, upper right, lower left, lower
# right; one per row) to the corners of a w x h image, solved as upstream
# does. NULL when the system is singular (three collinear corners), where
# upstream skips the image.
pillow_perspective_coefficients <- function(target, w, h) {
  orig <- rbind(c(0, 0), c(w, 0), c(0, h), c(w, h))
  A <- matrix(0, 8, 8)
  for (i in 1:4) {
    x <- target[i, 1]; y <- target[i, 2]; X <- orig[i, 1]; Y <- orig[i, 2]
    A[2 * i - 1, ] <- c(x, y, 1, 0, 0, 0, -X * x, -X * y)
    A[2 * i, ] <- c(0, 0, 0, x, y, 1, -Y * x, -Y * y)
  }
  tryCatch(solve(A, as.vector(t(orig))), error = function(e) NULL)
}

# Pillow's Image.transform() with Transform.PERSPECTIVE on an h x w x 4
# array of 8 bit values, for the output columns cols[1] to cols[2] - 1 and
# rows cols[3] to cols[4] - 1 (zero based). Each output pixel center maps
# through `coeffs`; nearest takes the pixel there, bilinear and bicubic
# (Pillow's transform cubic, a = -1) interpolate premultiplied colors with
# edge pixels repeated and truncate to 8 bits. Samples outside the image
# are transparent. Returns the 8 bit result.
pillow_transform <- function(img, coeffs, box, method = "bicubic") {
  ih <- dim(img)[1]
  iw <- dim(img)[2]
  cols <- seq(box[1], box[2] - 1)
  rows <- seq(box[3], box[4] - 1)
  nx <- length(cols)
  ny <- length(rows)
  xo <- rep(cols, each = ny) + 0.5
  yo <- rep(rows, times = nx) + 0.5
  a <- coeffs
  den <- a[7] * xo + a[8] * yo + 1
  xin <- (a[1] * xo + a[2] * yo + a[3]) / den
  yin <- (a[4] * xo + a[5] * yo + a[6]) / den
  out <- array(0, c(ny, nx, 4))
  if (method == "nearest") {
    ok <- is.finite(xin) & is.finite(yin) & xin >= 0 & yin >= 0
    xi <- trunc(xin); yi <- trunc(yin)
    ok <- ok & xi < iw & yi < ih
    idx <- yi[ok] + 1 + xi[ok] * ih
    for (k in 1:4) {
      ch <- numeric(length(xin))
      ch[ok] <- img[, , k][idx]
      out[, , k] <- ch
    }
    return(out)
  }
  ok <- is.finite(xin) & is.finite(yin) & xin >= 0 & xin < iw & yin >= 0 & yin < ih
  if (!any(ok)) return(out)
  alpha <- img[, , 4]
  pre <- img
  for (k in 1:3) {
    t <- img[, , k] * alpha + 128
    pre[, , k] <- floor((floor(t / 256) + t) / 256)
  }
  x <- xin[ok] - 0.5
  y <- yin[ok] - 0.5
  x0 <- floor(x); y0 <- floor(y)
  dx <- x - x0; dy <- y - y0
  clipx <- function(v) pmin(pmax(v, 0), iw - 1)
  clipy <- function(v) pmin(pmax(v, 0), ih - 1)
  if (method == "bilinear") {
    offs <- 0:1
    interp <- function(v, d) v[[1]] + (v[[2]] - v[[1]]) * d
  } else {
    offs <- -1:2
    interp <- function(v, d) {
      p1 <- v[[2]]; p2 <- -v[[1]] + v[[3]]
      p3 <- 2 * (v[[1]] - v[[2]]) + v[[3]] - v[[4]]
      p4 <- -v[[1]] + v[[2]] - v[[3]] + v[[4]]
      p1 + d * (p2 + d * (p3 + d * p4))
    }
  }
  xs <- lapply(offs, function(o) clipx(x0 + o) * ih)
  ys <- lapply(offs, function(o) clipy(y0 + o) + 1)
  res <- matrix(0, sum(ok), 4)
  for (k in 1:4) {
    ch <- pre[, , k]
    rowv <- lapply(ys, function(yy) interp(lapply(xs, function(xx) ch[yy + xx]), dx))
    v <- interp(rowv, dy)
    res[, k] <- ifelse(v <= 0, 0, ifelse(v >= 255, 255, trunc(v)))
  }
  # Back from premultiplied colors, as Pillow's RGBa to RGBA conversion.
  al <- res[, 4]
  part <- al > 0 & al < 255
  for (k in 1:3) res[part, k] <- pmin(floor(255 * res[part, k] / al[part]), 255)
  for (k in 1:4) {
    ch <- numeric(length(xin))
    ch[ok] <- res[, k]
    out[, , k] <- ch
  }
  out
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
# `mobjects` is the parameter of manim.utils.family, `mobject_list` that of
# manim.utils.family_ops.
extract_mobject_family_members <- function(mobjects = mobject_list, use_z_index = FALSE, only_those_with_points = FALSE,
                                           mobject_list = NULL) {
  fam <- unlist(lapply(mobjects, function(m) {
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
