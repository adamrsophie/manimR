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
#' @export
CameraClass <- R6::R6Class("Camera", lock_objects = FALSE,
  public = list(
    pixel_width = NULL,
    pixel_height = NULL,
    frame_width = NULL,
    frame_height = NULL,
    frame_center = NULL,
    frame_rate = NULL,
    background_color = NULL,
    background_opacity = 1,
    use_z_index = TRUE,
    curve_tolerance = 0.25,
    initialize = function(pixel_width = cfg("pixel_width"), pixel_height = cfg("pixel_height"),
                          frame_height = cfg("frame_height"), frame_width = cfg("frame_width"),
                          frame_center = ORIGIN, frame_rate = cfg("frame_rate"),
                          background_color = cfg("background_color"),
                          background_opacity = cfg("background_opacity"), use_z_index = TRUE,
                          background_image = NULL, ...) {
      self$use_z_index <- use_z_index
      self$background_image <- self$load_background_image(background_image, pixel_width, pixel_height)
      self$pixel_width <- pixel_width
      self$pixel_height <- pixel_height
      self$frame_height <- frame_height
      self$frame_width <- frame_width %||% (frame_height * pixel_width / pixel_height)
      self$frame_center <- as_point(frame_center)
      self$frame_rate <- frame_rate
      self$background_color <- background_color
      self$background_opacity <- if (isTRUE(cfg("transparent"))) 0 else background_opacity
      self$curve_tolerance <- cfg("curve_tolerance") %||% 0.25
    },
    # Current view; MovingCamera overrides these to follow its frame.
    get_frame_width = function() self$frame_width,
    get_frame_height = function() self$frame_height,
    get_frame_center = function() self$frame_center,
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
      if (!is.null(self$background_image)) {
        d <- dim(self$background_image)
        grid::grid.raster(self$background_image, x = 0, y = 1, just = c("left", "top"),
                          width = grid::unit(d[2] / self$pixel_width, "npc"),
                          height = grid::unit(d[1] / self$pixel_height, "npc"), interpolate = FALSE)
        return(invisible(self))
      }
      if (self$background_opacity > 0) {
        bg <- rgba_hex(c(color_to_rgb(self$background_color), self$background_opacity))
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
                         lwd = width * 0.01 * self$px_per_unit(), linejoin = JOINT_MAP[[vmobject$joint_type %||% "auto"]],
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
      lwd <- width * 0.01 * self$px_per_unit()
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
    display_image_mobject = function(image_mobject) {
      corners <- self$project_points(image_mobject$points, image_mobject)
      img <- image_mobject$get_raster()
      ul <- corners[1, ]; ur <- corners[2, ]; dl <- corners[3, ]
      w <- get_norm(ur - ul)
      h <- get_norm(dl - ul)
      angle <- atan2(ur[2] - ul[2], ur[1] - ul[1]) * 180 / pi
      cx <- mean(corners[c(2, 3), 1])
      cy <- mean(corners[c(2, 3), 2])
      grid::pushViewport(grid::viewport(x = grid::unit(cx, "native"), y = grid::unit(cy, "native"),
                                        width = grid::unit(w, "native"), height = grid::unit(h, "native"),
                                        angle = angle))
      grid::grid.raster(img, interpolate = !identical(image_mobject$resampling_algorithm, "nearest"))
      grid::popViewport()
      invisible(self)
    }
  )
)

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
extract_mobject_family_members <- function(mobjects, use_z_index = FALSE, only_those_with_points = FALSE) {
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
