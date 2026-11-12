# The pixel array side of manim/camera/camera.py. manimR's renderer draws
# each frame on a graphics device (draw_frame()); these methods give the
# camera upstream's `pixel_array` (height x width x 4, values 0 to 255) and
# the methods that work on it, drawing through the same code.

CameraClass$set("public", "pixel_array", NULL)
CameraClass$set("public", "background", NULL)
CameraClass$set("public", "rgb_max_val", 255)
CameraClass$set("public", "n_channels", 4)
CameraClass$set("public", "image_mode", "RGBA")
CameraClass$set("public", "pixel_array_dtype", "uint8")
CameraClass$set("public", "cairo_line_width_multiple", 0.01)
CameraClass$set("public", "max_allowable_norm", NULL)
CameraClass$set("public", "background_colored_vmobject_displayer", NULL)

# The background as a pixel array: the background image (its top left
# corner) or the background color.
CameraClass$set("public", "init_background", function() {
  h <- self$pixel_height
  w <- self$pixel_width
  self$background <- if (!is.null(self$background_image)) {
    img <- change_to_rgba_array(round(self$background_image * 255))
    img[seq_len(min(h, dim(img)[1])), seq_len(min(w, dim(img)[2])), , drop = FALSE]
  } else {
    rgba <- color_to_int_rgba(self$background_color, self$background_opacity)
    array(rep(rgba, each = h * w), c(h, w, 4))
  }
  invisible(self)
})

CameraClass$set("public", "convert_pixel_array", function(pixel_array) trunc(pixel_array * self$rgb_max_val))

CameraClass$set("public", "set_pixel_array", function(pixel_array, convert_from_floats = FALSE) {
  self$pixel_array <- if (convert_from_floats) self$convert_pixel_array(pixel_array) else pixel_array
  invisible(self)
})

# A background set here (or from a function) is what draw_frame() paints
# behind the mobjects, instead of the background color or image.
CameraClass$set("public", "set_background", function(pixel_array, convert_from_floats = FALSE) {
  self$background <- if (convert_from_floats) self$convert_pixel_array(pixel_array) else pixel_array
  self$custom_background <- TRUE
  invisible(self)
})

# Frame coordinates (x, y) of every pixel, as a height x width x 2 array.
CameraClass$set("public", "get_coords_of_all_pixels", function() {
  h <- self$pixel_height
  w <- self$pixel_width
  fw <- self$get_frame_width()
  fh <- self$get_frame_height()
  xs <- (seq_len(w) - 1) * fw / w - fw / 2
  ys <- -((seq_len(h) - 1) * fh / h - fh / 2)
  array(c(rep(xs, each = h), rep(ys, times = w)), c(h, w, 2))
})

# A background from a function of a pixel's coordinates c(x, y) that
# returns RGBA values from 0 to 1.
CameraClass$set("public", "make_background_from_func", function(coords_to_colors_func) {
  coords <- self$get_coords_of_all_pixels()
  d <- dim(coords)
  vals <- apply(coords, c(1, 2), coords_to_colors_func)
  self$convert_pixel_array(aperm(array(vals, c(4, d[1], d[2])), c(2, 3, 1)))
})

CameraClass$set("public", "set_background_from_func", function(coords_to_colors_func) {
  self$set_background(self$make_background_from_func(coords_to_colors_func))
})

CameraClass$set("public", "reset", function() {
  if (is.null(self$background)) self$init_background()
  self$set_pixel_array(self$background)
  invisible(self)
})

CameraClass$set("public", "set_frame_to_background", function(background) self$set_pixel_array(background))

CameraClass$set("public", "reset_pixel_shape", function(new_height, new_width) {
  self$pixel_width <- new_width
  self$pixel_height <- new_height
  self$init_background()
  self$resize_frame_shape()
  self$reset()
})

# Keeps the frame's aspect ratio equal to the pixels' (fixed_dimension 0
# keeps the width, 1 the height).
CameraClass$set("public", "resize_frame_shape", function(fixed_dimension = 0) {
  aspect <- self$pixel_width / self$pixel_height
  if (fixed_dimension == 0) self$frame_height <- self$frame_width / aspect else self$frame_width <- aspect * self$frame_height
  invisible(self)
})

# The pixel array as an R raster (for plot() or grid.raster()).
CameraClass$set("public", "get_image", function(pixel_array = NULL) {
  pa <- pixel_array %||% self$pixel_array
  if (is.null(pa)) {
    self$reset()
    pa <- self$pixel_array
  }
  grDevices::as.raster(pmin(pmax(pa, 0), 255) / 255)
})

CameraClass$set("public", "is_in_frame", function(mobject) {
  fc <- self$get_frame_center()
  fh <- self$get_frame_height()
  fw <- self$get_frame_width()
  !(mobject$get_right()[1] < fc[1] - fw / 2 || mobject$get_bottom()[2] > fc[2] + fh / 2 ||
      mobject$get_left()[1] > fc[1] + fw / 2 || mobject$get_top()[2] < fc[2] - fh / 2)
})

# Draws `expr` (grid drawing in frame coordinates) over the pixel array.
CameraClass$set("public", "draw_on_pixel_array", function(draw, pixel_array = NULL) {
  pa <- pixel_array %||% self$pixel_array
  if (is.null(pa)) {
    self$reset()
    pa <- self$pixel_array
  }
  dev <- ragg::agg_capture(width = self$pixel_width, height = self$pixel_height, units = "px", res = 96,
                           background = "transparent")
  dev_index <- grDevices::dev.cur()
  on.exit(grDevices::dev.off(dev_index), add = TRUE)
  grid::grid.newpage(recording = FALSE)
  grid::grid.raster(pmin(pmax(pa, 0), 255) / 255, width = grid::unit(1, "npc"), height = grid::unit(1, "npc"),
                    interpolate = FALSE)
  self$push_view()
  draw()
  grid::popViewport()
  native_raster_to_array(dev(native = TRUE))
})

# Upstream's capture: draws the mobjects into the pixel array.
CameraClass$set("public", "capture_mobjects", function(mobjects, include_submobjects = TRUE, excluded_mobjects = NULL) {
  mobs <- self$get_mobjects_to_display(mobjects, include_submobjects, excluded_mobjects)
  self$pixel_array <- self$draw_on_pixel_array(function() for (m in mobs) self$display_mobject(m))
  invisible(self)
})

CameraClass$set("public", "capture_mobject", function(mobject, ...) self$capture_mobjects(list(mobject), ...))

# The class whose display method draws a mobject (upstream groups runs of
# mobjects by it).
CameraClass$set("public", "type_or_raise", function(mobject) {
  for (cls in c("VMobject", "PMobject", "AbstractImageMobject", "Mobject")) if (inherits(mobject, cls)) return(cls)
  stop("Displaying an object of class ", class(mobject)[1], " is not supported", call. = FALSE)
})

CameraClass$set("public", "display_multiple_vectorized_mobjects", function(vmobjects, pixel_array = NULL) {
  if (!length(vmobjects)) return(invisible(self))
  has_bg <- vapply(vmobjects, function(m) !is.null(m$background_image), NA)
  runs <- rle(has_bg)
  ends <- cumsum(runs$lengths)
  for (r in seq_along(ends)) {
    batch <- vmobjects[(ends[r] - runs$lengths[r] + 1):ends[r]]
    if (runs$values[r]) {
      self$display_multiple_background_colored_vmobjects(batch, pixel_array)
    } else {
      self$display_multiple_non_background_colored_vmobjects(batch, pixel_array)
    }
  }
  invisible(self)
})

CameraClass$set("public", "display_multiple_non_background_colored_vmobjects", function(vmobjects, pixel_array = NULL) {
  self$pixel_array <- self$draw_on_pixel_array(function() for (m in vmobjects) self$display_vectorized(m), pixel_array)
  invisible(self)
})

CameraClass$set("public", "get_background_colored_vmobject_displayer", function() {
  self$background_colored_vmobject_displayer <- self$background_colored_vmobject_displayer %||%
    BackgroundColoredVMobjectDisplayer(self)
  self$background_colored_vmobject_displayer
})

CameraClass$set("public", "display_multiple_background_colored_vmobjects", function(cvmobjects, pixel_array = NULL) {
  arr <- self$get_background_colored_vmobject_displayer()$display(cvmobjects)
  if (is.null(pixel_array) && is.null(self$pixel_array)) self$reset()
  self$pixel_array <- self$overlay_rgba_array(pixel_array %||% self$pixel_array, arr)
  invisible(self)
})

CameraClass$set("public", "display_multiple_point_cloud_mobjects", function(pmobjects, pixel_array = NULL) {
  self$pixel_array <- self$draw_on_pixel_array(function() for (m in pmobjects) self$display_point_cloud(m), pixel_array)
  invisible(self)
})

CameraClass$set("public", "display_multiple_image_mobjects", function(image_mobjects, pixel_array = NULL) {
  self$pixel_array <- self$draw_on_pixel_array(function() for (m in image_mobjects) self$display_image_mobject(m),
                                               pixel_array)
  invisible(self)
})

# Alpha composites `new_array` over `pixel_array` (both 0 to 255) and
# returns the result (R arrays are values, so it is not changed in place).
CameraClass$set("public", "overlay_rgba_array", function(pixel_array, new_array) {
  a <- new_array[, , 4] / 255
  b <- pixel_array[, , 4] / 255
  out_a <- a + b * (1 - a)
  out <- pixel_array
  for (k in 1:3) {
    num <- new_array[, , k] * a + pixel_array[, , k] * b * (1 - a)
    out[, , k] <- ifelse(out_a > 0, num / out_a, 0)
  }
  out[, , 4] <- out_a * 255
  round(out)
})

CameraClass$set("public", "overlay_PIL_image", function(pixel_array, image) {
  arr <- if (inherits(image, "raster")) t(grDevices::col2rgb(as.matrix(image), alpha = TRUE)) else image
  if (is.matrix(arr)) arr <- array(arr, c(dim(as.matrix(image)), 4))
  self$overlay_rgba_array(pixel_array, arr)
})

# Points far outside the frame are pulled in to max_allowable_norm
# (default: the frame width).
CameraClass$set("public", "adjust_out_of_range_points", function(points) {
  limit <- self$max_allowable_norm %||% self$get_frame_width()
  if (!any(points > limit)) return(points)
  norms <- sqrt(rowSums(points^2))
  bad <- norms > limit
  points[bad, ] <- limit * points[bad, , drop = FALSE] / norms[bad]
  points
})

CameraClass$set("public", "transform_points_pre_display", function(mobject, points) {
  if (!all(is.finite(points))) points <- matrix(0, 1, 3)
  points
})

CameraClass$set("public", "points_to_subpixel_coords", function(mobject, points) {
  points <- self$transform_points_pre_display(mobject, points)
  fc <- self$get_frame_center()
  cbind((points[, 1] - fc[1]) * self$pixel_width / self$get_frame_width() + self$pixel_width / 2,
        (points[, 2] - fc[2]) * -self$pixel_height / self$get_frame_height() + self$pixel_height / 2)
})

CameraClass$set("public", "points_to_pixel_coords", function(mobject, points) {
  pc <- self$points_to_subpixel_coords(mobject, points)
  pc[] <- trunc(pc)
  pc
})

CameraClass$set("public", "on_screen_pixels", function(pixel_coords) {
  pixel_coords[, 1] >= 0 & pixel_coords[, 1] < self$pixel_width & pixel_coords[, 2] >= 0 &
    pixel_coords[, 2] < self$pixel_height
})

CameraClass$set("public", "adjusted_thickness", function(thickness) {
  factor <- (cfg("pixel_height") + cfg("pixel_width")) / (self$pixel_height + self$pixel_width)
  1 + (thickness - 1) * factor
})

CameraClass$set("public", "get_thickening_nudges", function(thickness) {
  t <- trunc(thickness)
  # Python's range(-t // 2 + 1, t // 2 + 1), and every pair of its values.
  r <- seq.int(-t %/% 2 + 1, length.out = max(t, 0))
  cbind(rep(r, each = length(r)), rep(r, times = length(r)))
})

CameraClass$set("public", "thickened_coordinates", function(pixel_coords, thickness) {
  nudges <- self$get_thickening_nudges(thickness)
  do.call(rbind, lapply(seq_len(nrow(nudges)), function(i) sweep(pixel_coords, 2, nudges[i, ], "+")))
})

# 3D cameras project points before they are shown.
ThreeDCameraClass$set("public", "transform_points_pre_display", function(mobject, points) {
  points <- super$transform_points_pre_display(mobject, points)
  proj <- self$project_points(points, mobject)
  cbind(proj, 0)
})

MappingCameraClass$set("public", "points_to_pixel_coords", function(mobject, points) {
  super$points_to_pixel_coords(mobject, t(apply(points, 1, self$mapping_func)))
})

# MultiCamera: resetting also resets its sub cameras.
MultiCameraClass$set("public", "reset", function() {
  for (imfc in self$image_mobjects_from_cameras) imfc$camera$reset()
  super$reset()
})

OldMultiCameraClass$set("public", "init_background", function() {
  super$init_background()
  for (sc in self$shifted_cameras) sc$camera$init_background()
  invisible(self)
})

OldMultiCameraClass$set("public", "set_background", function(pixel_array, ...) {
  for (sc in self$shifted_cameras) sc$camera$set_background(pixel_array, ...)
  super$set_background(pixel_array, ...)
})

OldMultiCameraClass$set("public", "set_pixel_array", function(pixel_array, ...) {
  super$set_pixel_array(pixel_array, ...)
  for (sc in self$shifted_cameras) sc$camera$set_pixel_array(pixel_array, ...)
  invisible(self)
})
