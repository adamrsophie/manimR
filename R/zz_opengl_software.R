# Upstream's OpenGL renderer (manim/renderer/opengl_renderer.py), its window
# (opengl_renderer_window.py) and the render_* functions of
# vectorized_mobject_rendering.py. Upstream hands vertex buffers to moderngl;
# here the context is a software one: the framebuffer is an off screen ragg
# device, and a vertex array draws the triangles and curve tiles with the
# rules of upstream's GLSL shaders (Loop-Blinn fill triangles, strokes within
# a distance of their quadratic curve). Mobjects drawn through their shader
# wrappers are drawn by manimR's grid camera with the OpenGL camera's
# rotation, frame, focal projection and upstream's add_light().

# Software context ------------------------------------------------------------

# Framebuffer of a software context: an off screen device of its size.
OpenGLSoftwareFramebufferClass <- R6::R6Class("OpenGLSoftwareFramebuffer", lock_objects = FALSE,
  public = list(
    context = NULL,
    viewport = NULL,
    capture = NULL,
    device = NULL,
    initialize = function(context, width, height) {
      self$context <- context
      self$viewport <- c(0, 0, width, height)
    },
    open = function() {
      if (!is.null(self$device) && self$device %in% grDevices::dev.list()) return(invisible(self))
      prev <- grDevices::dev.cur()
      self$capture <- ragg::agg_capture(width = self$viewport[3], height = self$viewport[4], units = "px",
                                        res = 96, background = "transparent")
      self$device <- grDevices::dev.cur()
      grid::grid.newpage(recording = FALSE)
      if (prev > 1) grDevices::dev.set(prev)
      invisible(self)
    },
    # Runs `draw()` with this framebuffer's device current.
    with_device = function(draw) {
      self$open()
      prev <- grDevices::dev.cur()
      grDevices::dev.set(self$device)
      on.exit(if (prev > 1 && prev != self$device && prev %in% grDevices::dev.list()) grDevices::dev.set(prev),
              add = TRUE)
      draw()
    },
    # The device opens when the framebuffer is first drawn to or read.
    use = function() {
      self$context$target <- self
      invisible(self)
    },
    # The depth attachment: window depth of each pixel, rows from the top.
    depth = NULL,
    clear = function(red = 0, green = 0, blue = 0, alpha = 0, depth = 1, ...) {
      self$depth <- matrix(depth, self$viewport[4], self$viewport[3])
      self$with_device(function() {
        grid::grid.newpage(recording = FALSE)
        grid::grid.rect(gp = grid::gpar(fill = grDevices::rgb(red, green, blue, alpha), col = NA))
      })
      invisible(self)
    },
    # The pixels as an h x w x 4 array of values 0 to 255, bottom row first as
    # OpenGL reads them.
    read = function(viewport = self$viewport, components = 4, dtype = "f1") {
      a <- self$with_device(function() native_raster_to_array(self$capture(native = TRUE)))
      a[rev(seq_len(dim(a)[1])), , seq_len(components), drop = FALSE]
    },
    release = function() {
      if (!is.null(self$device) && self$device %in% grDevices::dev.list()) {
        prev <- grDevices::dev.cur()
        grDevices::dev.off(self$device)
        if (prev != self$device && prev %in% grDevices::dev.list()) grDevices::dev.set(prev)
      }
      self$device <- NULL
      invisible(NULL)
    }
  )
)

# A vertex array of a software context: render() draws the buffer with the
# rules of the shader it was made with.
OpenGLSoftwareVertexArrayClass <- R6::R6Class("OpenGLSoftwareVertexArray", lock_objects = FALSE,
  public = list(
    context = NULL,
    shader = NULL,
    buffer = NULL,
    attribute_names = NULL,
    initialize = function(context, shader, buffer, attribute_names) {
      self$context <- context
      self$shader <- shader
      self$buffer <- buffer
      self$attribute_names <- attribute_names
    },
    render = function() {
      draw <- switch(self$shader$name %||% "",
        vectorized_mobject_fill = software_draw_fill,
        vectorized_mobject_stroke = software_draw_stroke,
        stop("The software context draws the vectorized_mobject_fill and vectorized_mobject_stroke shaders, not ",
             self$shader$name %||% "inline shader code", ".", call. = FALSE)
      )
      fbo <- self$context$target
      if (is.null(fbo)) stop("No framebuffer is in use.", call. = FALSE)
      wire <- isTRUE(self$context$wireframe)
      fbo$with_device(function() {
        if (wire) {
          wdraw <- if (identical(draw, software_draw_fill)) software_wire_fill else software_wire_stroke
          wdraw(self$buffer, self$shader$uniforms, fbo$viewport)
        } else {
          draw(self$buffer, self$shader$uniforms, fbo$viewport)
        }
      })
      invisible(NULL)
    },
    release = function() invisible(NULL)
  )
)

#' @rdname opengl_renderer
#' @format NULL
#' @usage NULL
#' @export
OpenGLSoftwareContextClass <- R6::R6Class("OpenGLSoftwareContext", lock_objects = FALSE,
  public = list(
    blend = FALSE,
    depth_test = FALSE,
    wireframe = FALSE,
    blend_func = NULL,
    target = NULL,
    screen = NULL,
    enable = function(flag) {
      if (identical(flag, "BLEND")) self$blend <- TRUE
      if (identical(flag, "DEPTH_TEST")) self$depth_test <- TRUE
      invisible(self)
    },
    disable = function(flag) {
      if (identical(flag, "BLEND")) self$blend <- FALSE
      if (identical(flag, "DEPTH_TEST")) self$depth_test <- FALSE
      invisible(self)
    },
    texture = function(size, components = 4, data = NULL, samples = 0, ...) {
      list(size = as.integer(size), components = components, data = data, samples = samples)
    },
    depth_renderbuffer = function(size, samples = 0) list(size = as.integer(size), samples = samples),
    framebuffer = function(color_attachments = NULL, depth_attachment = NULL) {
      size <- color_attachments$size
      OpenGLSoftwareFramebufferClass$new(self, size[1], size[2])
    },
    detect_framebuffer = function() self$screen,
    buffer = function(data) data,
    simple_vertex_array = function(program, buffer, ...) {
      OpenGLSoftwareVertexArrayClass$new(self, program, buffer, c(...))
    },
    release = function() {
      if (!is.null(self$target)) self$target$release()
      invisible(NULL)
    }
  )
)

#' @rdname opengl_renderer
#' @export
OpenGLSoftwareContext <- build_constructor(OpenGLSoftwareContextClass)

# Rasterizers ------------------------------------------------------------------

# Normalized device coordinates (n x 2) of model points through the shader's
# u_projection_matrix * u_model_view_matrix.
software_ndc <- function(points, uniforms) {
  mv <- matrix(uniforms$u_model_view_matrix, 4, 4)
  p <- matrix(uniforms$u_projection_matrix, 4, 4)
  clip <- p %*% mv %*% rbind(t(points), 1)
  cbind(clip[1, ] / clip[4, ], clip[2, ] / clip[4, ])
}

software_push_ndc <- function() {
  grid::pushViewport(grid::viewport(xscale = c(-1, 1), yscale = c(-1, 1)))
}

software_rgba <- function(m) {
  m <- matrix(m, ncol = 4)
  grDevices::rgb(pmin(pmax(m[, 1], 0), 1), pmin(pmax(m[, 2], 0), 1), pmin(pmax(m[, 3], 0), 1),
                 pmin(pmax(m[, 4], 0), 1))
}

# The rasterizer of the software context, as a GPU without multisampling:
# a triangle covers the pixels whose centers lie in it, and the vertex
# attributes are interpolated there with perspective correction. The
# fragments a shader keeps are blended over the framebuffer with
# SRC_ALPHA, ONE_MINUS_SRC_ALPHA, in the order of the triangles.

# Clip coordinates (4 x n) of model points.
software_clip <- function(points, uniforms) {
  mv <- matrix(uniforms$u_model_view_matrix, 4, 4)
  p <- matrix(uniforms$u_projection_matrix, 4, 4)
  p %*% mv %*% rbind(t(points), 1)
}

# Pixels covered by one triangle (clip coordinates c3, 4 x 3) in a W x H
# viewport: their row (from the top) and column, and the perspective correct
# weights of the three vertices there.
software_raster_triangle <- function(c3, W, H) {
  w <- c3[4, ]
  if (any(!is.finite(w)) || any(w <= 0)) return(NULL)
  sx <- (c3[1, ] / w + 1) / 2 * W
  sy <- (1 - c3[2, ] / w) / 2 * H
  area <- (sx[2] - sx[1]) * (sy[3] - sy[1]) - (sx[3] - sx[1]) * (sy[2] - sy[1])
  if (!is.finite(area) || abs(area) < 1e-12) return(NULL)
  c0 <- max(floor(min(sx)), 0); c1 <- min(ceiling(max(sx)), W)
  r0 <- max(floor(min(sy)), 0); r1 <- min(ceiling(max(sy)), H)
  if (c1 <= c0 || r1 <= r0) return(NULL)
  cols <- (c0 + 1):c1
  rows <- (r0 + 1):r1
  # Nudged as in software_fragments(), so a shared edge is drawn once.
  px <- rep(cols - 0.5 + 1e-7, each = length(rows))
  py <- rep(rows - 0.5 - 1e-11, times = length(cols))
  e <- function(i, j) ((sx[j] - sx[i]) * (py - sy[i]) - (sy[j] - sy[i]) * (px - sx[i])) / area
  l0 <- e(2, 3); l1 <- e(3, 1); l2 <- e(1, 2)
  inside <- l0 > 0 & l1 > 0 & l2 > 0
  if (!any(inside)) return(NULL)
  b <- cbind(l0[inside] / w[1], l1[inside] / w[2], l2[inside] / w[3])
  b <- b / rowSums(b)
  list(row = rep(rows, times = length(cols))[inside], col = rep(cols, each = length(rows))[inside], b = b)
}

# Collects the fragments of one draw call and blends them over the
# framebuffer as one pixel aligned raster.
software_layer <- function(W, H) {
  frags <- list()
  list(
    add = function(row, col, rgba) {
      keep <- rgba[, 4] > 0
      if (any(keep)) frags[[length(frags) + 1]] <<- list(row = row[keep], col = col[keep], rgba = rgba[keep, , drop = FALSE])
    },
    draw = function() {
      if (!length(frags)) return(invisible(NULL))
      r0 <- min(vapply(frags, function(f) min(f$row), 0)); r1 <- max(vapply(frags, function(f) max(f$row), 0))
      c0 <- min(vapply(frags, function(f) min(f$col), 0)); c1 <- max(vapply(frags, function(f) max(f$col), 0))
      h <- r1 - r0 + 1
      w <- c1 - c0 + 1
      out <- array(0, c(h, w, 4))
      for (f in frags) {
        idx <- (f$col - c0) * h + (f$row - r0 + 1)
        a <- pmin(pmax(f$rgba[, 4], 0), 1)
        for (k in 1:3) {
          ch <- out[, , k]
          ch[idx] <- pmin(pmax(f$rgba[, k], 0), 1) * a + ch[idx] * (1 - a)
          out[, , k] <- ch
        }
        ch <- out[, , 4]
        ch[idx] <- a + ch[idx] * (1 - a)
        out[, , 4] <- ch
      }
      # The layer holds premultiplied color; the device wants it straight.
      for (k in 1:3) out[, , k] <- ifelse(out[, , 4] > 0, out[, , k] / pmax(out[, , 4], 1e-12), 0)
      grid::grid.raster(array_to_native_raster(out), x = grid::unit((c0 - 1) / W, "npc"),
                        y = grid::unit(1 - r1 / H, "npc"), width = grid::unit(w / W, "npc"),
                        height = grid::unit(h / H, "npc"), just = c("left", "bottom"), interpolate = FALSE)
      invisible(NULL)
    }
  )
}

# The pixels covered by many triangles at once, for vertices at window
# coordinates sx, sy (y down) and triangles as rows of 1 based vertex indices.
# A pixel is covered when its center is inside the triangle; a center on an
# edge goes to one of the two triangles sharing it, as a GPU's fill rule does.
# Returns the triangle, row (from the top) and column of each fragment and
# the weights of the triangle's vertices there (linear: w is 1).
software_fragments <- function(sx, sy, tri, W, H) {
  X <- matrix(sx[tri], ncol = 3)
  Y <- matrix(sy[tri], ncol = 3)
  area <- (X[, 2] - X[, 1]) * (Y[, 3] - Y[, 1]) - (X[, 3] - X[, 1]) * (Y[, 2] - Y[, 1])
  c0 <- pmax(floor(pmin(X[, 1], X[, 2], X[, 3])), 0)
  c1 <- pmin(ceiling(pmax(X[, 1], X[, 2], X[, 3])), W)
  r0 <- pmax(floor(pmin(Y[, 1], Y[, 2], Y[, 3])), 0)
  r1 <- pmin(ceiling(pmax(Y[, 1], Y[, 2], Y[, 3])), H)
  ok <- which(is.finite(area) & abs(area) > 1e-12 & c1 > c0 & r1 > r0)
  if (!length(ok)) return(NULL)
  nh <- (r1 - r0)[ok]
  n <- (c1 - c0)[ok] * nh
  id <- rep(ok, n)
  k <- sequence(n) - 1
  nh <- rep(nh, n)
  col <- c0[id] + k %/% nh + 1
  row <- r0[id] + k %% nh + 1
  # The sample point is nudged right, and much less up, so that a center
  # exactly on a shared edge lies inside one triangle only.
  px <- col - 0.5 + 1e-7
  py <- row - 0.5 - 1e-11
  e <- function(i, j) {
    ((X[id, j] - X[id, i]) * (py - Y[id, i]) - (Y[id, j] - Y[id, i]) * (px - X[id, i])) / area[id]
  }
  b <- cbind(e(2, 3), e(3, 1), e(1, 2))
  inside <- b[, 1] > 0 & b[, 2] > 0 & b[, 3] > 0
  if (!any(inside)) return(NULL)
  list(tri = id[inside], row = row[inside], col = col[inside], b = b[inside, , drop = FALSE])
}

# add_light() of finalize_color.glsl for rows of colors, points and normals.
software_add_light <- function(rgb, point, normal, light, gloss, shadow) {
  if (gloss == 0 && shadow == 0) return(rgb)
  flip <- which(normal[, 3] < 0)
  normal[flip, ] <- -normal[flip, ]
  unit <- function(v) v / sqrt(rowSums(v * v))
  to_camera <- cbind(-point[, 1], -point[, 2], 6 - point[, 3])
  to_light <- sweep(-point, 2, light, "+")
  reflection <- -to_light + 2 * normal * rowSums(to_light * normal)
  shine <- gloss * exp(-3 * (1 - rowSums(unit(reflection) * unit(to_camera)))^2)
  darkening <- 1 + (pmax(rowSums(unit(to_light) * normal), 0) - 1) * shadow
  darkening * (rgb + (1 - rgb) * shine)
}

# position_point_into_frame.glsl for rows of points.
software_frame_points <- function(P, u) {
  if (isTRUE(as.logical(u$is_fixed_in_frame))) return(P)
  rot <- matrix(u$camera_rotation, 3, 3)
  if (isTRUE(as.logical(u$is_fixed_orientation))) {
    foc <- as.numeric(u$fixed_orientation_center)
    return(sweep(P, 2, drop(rot %*% foc) - foc, "+"))
  }
  sweep(P, 2, as.numeric(u$camera_center)) %*% t(rot)
}

# get_gl_Position.glsl for rows of points (w is 1).
software_gl_position <- function(xyz, u) {
  fixed <- isTRUE(as.logical(u$is_fixed_in_frame))
  frame <- if (!fixed || isTRUE(as.logical(u$is_fixed_orientation))) u$frame_shape else DEFAULT_OPENGL_FRAME_SHAPE
  gl <- xyz
  gl[, 1] <- gl[, 1] * 2 / frame[1]
  gl[, 2] <- gl[, 2] * 2 / frame[2]
  if (!fixed) {
    psf <- pmax(0, u$focal_distance / (u$focal_distance - gl[, 3]))
    on <- psf > 0
    gl[on, 1:2] <- gl[on, 1:2] * psf[on]
    gl[on, 3] <- gl[on, 3] * 0.01
  }
  gl[, 3] <- -gl[, 3]
  gl
}

# Draws triangles (rows of 1 based indices into the rows of gl, positions
# from get_gl_Position()) into the framebuffer. Fragments outside the depth
# range are clipped and those `discard(at, tri_id)` flags are dropped; with
# `depth_test`, a fragment is kept where its depth is less than the
# framebuffer's (GL_LESS, moderngl's default) and then writes its depth.
# The kept fragments take the colors `shade(at, tri_id)` gives (rows of
# RGBA; tri_id is the row of `tri` of each fragment) and blend in triangle
# order. `at(v)` interpolates per vertex rows `v` at the
# fragments.
software_rasterize <- function(fbo, gl, tri, depth_test, shade, discard = NULL) {
  W <- fbo$viewport[3]
  H <- fbo$viewport[4]
  f <- software_fragments((gl[, 1] + 1) / 2 * W, (1 - gl[, 2]) / 2 * H, tri, W, H)
  if (is.null(f)) return(invisible(NULL))
  at <- function(v) {
    v <- as.matrix(v)
    out <- 0
    for (j in 1:3) out <- out + f$b[, j] * v[tri[f$tri, j], , drop = FALSE]
    out
  }
  subset <- function(keep) {
    f <<- list(tri = f$tri[keep], row = f$row[keep], col = f$col[keep], b = f$b[keep, , drop = FALSE])
  }
  z <- drop(at(gl[, 3]))
  keep <- z >= -1 & z <= 1
  subset(keep)
  z <- z[keep]
  if (!is.null(discard) && length(z)) {
    keep <- !discard(at, f$tri)
    subset(keep)
    z <- z[keep]
  }
  if (!length(z)) return(invisible(NULL))
  if (is.null(fbo$depth)) fbo$depth <- matrix(1, H, W)
  pix <- (f$col - 1) * H + f$row
  ord <- order(pix, f$tri)
  subset(ord)
  pix <- pix[ord]
  depth <- (z[ord] + 1) / 2
  start <- c(TRUE, pix[-1] != pix[-length(pix)])
  if (depth_test) {
    # Each fragment is tested against the depth left by the fragments
    # before it at its pixel.
    group <- cumsum(start)
    before <- c(Inf, stats::ave(depth, group, FUN = cummin)[-length(depth)])
    before[start] <- Inf
    pass <- depth < pmin(fbo$depth[pix], before)
    fbo$depth[pix] <- pmin(fbo$depth[pix], stats::ave(depth, group, FUN = min))
    subset(pass)
    pix <- pix[pass]
    if (!length(pix)) return(invisible(NULL))
    start <- c(TRUE, pix[-1] != pix[-length(pix)])
  }
  rgba <- shade(at, f$tri)
  rgba[is.na(rgba)] <- 0
  layer <- software_layer(W, H)
  rank <- seq_along(pix) - which(start)[cumsum(start)] + 1
  for (r in seq_len(max(rank))) {
    k <- rank == r
    layer$add(f$row[k], f$col[k], rgba[k, , drop = FALSE])
  }
  layer$draw()
}

# The fill color of each vertex of a surface's grid, from the face it
# starts (the last row and column from the faces before them). manimR's
# animations change a surface's faces, where upstream changes its rgbas.
software_surface_face_rgbas <- function(mobject, n) {
  faces <- mobject$list_of_faces
  ui <- vapply(faces, function(f) as.numeric(f$u_index %||% NA), 0)
  vi <- vapply(faces, function(f) as.numeric(f$v_index %||% NA), 0)
  if (!length(faces) || anyNA(ui) || anyNA(vi)) return(NULL)
  nfu <- max(ui) + 1
  nfv <- max(vi) + 1
  if ((nfu + 1) * (nfv + 1) != n) return(NULL)
  rgba <- t(vapply(faces, function(f) f$get_fill_rgbas()[1, ], numeric(4)))
  k <- seq_len(n) - 1
  rgba[match(pmin(k %/% (nfv + 1), nfu - 1) * nfv + pmin(k %% (nfv + 1), nfv - 1), ui * nfv + vi), , drop = FALSE]
}

# The surface and textured_surface shaders: vert.glsl places each vertex
# and rotates the normal of its du and dv neighbors; frag.glsl lights the
# interpolated color at the interpolated point and normal.
software_draw_surface <- function(fbo, mobject, uniforms) {
  # A surface group has no points of its own, as upstream's.
  if (!length(mobject$list_of_faces)) return(invisible(NULL))
  sd <- mobject$get_shader_data()
  P <- get("point", envir = sd)
  if (!nrow(P)) return(invisible(NULL))
  tri <- matrix(as.integer(mobject$get_shader_vert_indices()) + 1L, ncol = 3, byrow = TRUE)
  if (!nrow(tri)) return(invisible(NULL))
  u <- c(uniforms, mobject$get_shader_uniforms())
  # Vertex attributes reach the GPU as float32, which matters for the
  # normal: the nudged points are only epsilon away.
  P <- as_float32(P)
  xyz <- software_frame_points(P, u)
  a <- as_float32(get("du_point", envir = sd)) - P
  b <- as_float32(get("dv_point", envir = sd)) - P
  cross <- function(x, y) cbind(x[, 2] * y[, 3] - x[, 3] * y[, 2], x[, 3] * y[, 1] - x[, 1] * y[, 3],
                                x[, 1] * y[, 2] - x[, 2] * y[, 1])
  cp <- cross(a, b)
  flat <- rowSums(cp * cp) == 0
  if (any(flat)) cp[flat, ] <- cross(cross(b[flat, , drop = FALSE], P[flat, , drop = FALSE]), b[flat, , drop = FALSE])
  normal <- if (isTRUE(as.logical(u$is_fixed_in_frame))) cp else cp %*% t(matrix(u$camera_rotation, 3, 3))
  normal <- normal / sqrt(rowSums(normal * normal))
  light <- as.numeric(u$light_source_position)
  textured <- inherits(mobject, "OpenGLTexturedSurface")
  if (!length(mobject$colorscale) || is.null(mobject$axes) || textured) {
    faces <- software_surface_face_rgbas(mobject, nrow(P))
    if (!is.null(faces)) {
      if (textured) assign("opacity", faces[, 4, drop = FALSE], envir = sd) else assign("color", faces, envir = sd)
    }
  }
  shade <- function(at, ...) {
    n <- at(normal)
    n <- n / sqrt(rowSums(n * n))
    point <- at(xyz)
    if (textured) {
      # textured_surface/frag.glsl: the image at im_coords (nearest texel,
      # clamped at the edges), blended toward the dark image where the
      # surface faces away from the light; the alpha is the opacity.
      uv <- at(get("im_coords", envir = sd))
      texel <- function(img) {
        h <- dim(img)[1]
        w <- dim(img)[2]
        col <- pmin(pmax(floor(uv[, 1] * w), 0), w - 1)
        row <- pmin(pmax(floor(uv[, 2] * h), 0), h - 1)
        i <- row + 1 + col * h
        cbind(img[i], img[i + h * w], img[i + 2 * h * w], if (dim(img)[3] > 3) img[i + 3 * h * w] else 255) / 255
      }
      color <- texel(mobject$image)
      if (identical(as.numeric(mobject$num_textures), 2) && !is.null(mobject$dark_image)) {
        to_light <- sweep(-point, 2, light, "+")
        dp <- rowSums(to_light * n) / sqrt(rowSums(to_light * to_light))
        t <- pmin(pmax((dp + 0.2) / 0.4, 0), 1)
        alpha <- t * t * (3 - 2 * t)
        color <- texel(mobject$dark_image) * (1 - alpha) + color * alpha
      }
      color[, 4] <- at(get("opacity", envir = sd))
    } else {
      color <- at(get("color", envir = sd))
    }
    cbind(software_add_light(color[, 1:3, drop = FALSE], point, n, light, u$gloss %||% 0, u$shadow %||% 0),
          color[, 4])
  }
  software_rasterize(fbo, software_gl_position(xyz, u), tri, isTRUE(mobject$depth_test), shade)
}

# The true_dot shader: geom.glsl puts a square of half side point_radius +
# anti_alias_width around each point (the radius grown with the point's z),
# and frag.glsl discards what lies more than half anti_alias_width outside
# the circle, lights the rest as a sphere seen from the front and fades the
# alpha over anti_alias_width at the edge.
software_draw_true_dot <- function(fbo, mobject, uniforms) {
  sd <- mobject$get_shader_data()
  P <- as_points(sd$point)
  n <- nrow(P)
  if (!n) return(invisible(NULL))
  u <- c(uniforms, list(is_fixed_in_frame = as.numeric(isTRUE(as.logical(mobject$is_fixed_in_frame))),
                        is_fixed_orientation = 0, fixed_orientation_center = c(0, 0, 0)))
  v <- software_frame_points(P, u)
  aaw <- u$anti_alias_width
  radius <- mobject$point_radius / pmax(1 - v[, 3] / u$focal_distance / u$frame_shape[2], 0)
  rpa <- radius + aaw
  corners <- do.call(rbind, lapply(0:3, function(i) {
    cbind(v[, 1] + (2 * (i %% 2) - 1) * rpa, v[, 2] + (2 * (i %/% 2) - 1) * rpa, v[, 3])
  }))
  # Vertex k + 1 of point j is row j + k * n; the strip makes triangles 0 1 2
  # and 1 2 3.
  j <- seq_len(n)
  tri <- rbind(cbind(j, j + n, j + 2 * n), cbind(j + n, j + 2 * n, j + 3 * n))
  ctr <- rbind(v[, 1:2], v[, 1:2], v[, 1:2], v[, 1:2])
  rad <- rep(radius, 4)
  col <- as.matrix(sd$color)
  col <- rbind(col, col, col, col)
  geometry <- function(at) {
    d <- at(corners[, 1:2]) - at(ctr)
    r <- drop(at(rad))
    list(d = d, r = r, dist = sqrt(rowSums(d * d)))
  }
  discard <- function(at, ...) {
    g <- geometry(at)
    g$dist - g$r > 0.5 * aaw
  }
  light <- as.numeric(u$light_source_position)
  shade <- function(at, ...) {
    g <- geometry(at)
    normal <- cbind(g$d / g$r, suppressWarnings(sqrt(1 - g$dist^2 / g$r^2)))
    color <- at(col)
    rgb <- software_add_light(color[, 1:3, drop = FALSE], cbind(at(corners[, 1:2]), 0), normal, light,
                              mobject$gloss %||% 0, mobject$shadow %||% 0)
    t <- pmin(pmax(0.5 - (g$dist - g$r) / aaw, 0), 1)
    cbind(rgb, color[, 4] * t * t * (3 - 2 * t))
  }
  software_rasterize(fbo, software_gl_position(corners, u), tri, isTRUE(mobject$depth_test), shade, discard)
}

# vectorized_mobject_fill: a fragment of a triangle is drawn where
# texture_mode * (u^2 - v) >= 0, (u, v) being the interpolated texture
# coordinates. With (0, 0), (0.5, 0), (1, 1) at the vertices that is the
# whole triangle for mode 0, the part between the curve and the control
# point for mode 1 and the part between the chord and the curve for mode -1.
# The mode is flat, taken from the triangle's last vertex as OpenGL does.
software_draw_fill <- function(buffer, uniforms, viewport) {
  verts <- get("in_vert", envir = buffer)
  if (!nrow(verts)) return(invisible(NULL))
  colors <- get("in_color", envir = buffer)
  tex <- get("texture_coords", envir = buffer)
  modes <- get("texture_mode", envir = buffer)[, 1]
  W <- viewport[3]
  H <- viewport[4]
  clip <- software_clip(verts, uniforms)
  layer <- software_layer(W, H)
  for (k in seq(1, nrow(verts) - 2, by = 3)) {
    rows <- k:(k + 2)
    f <- software_raster_triangle(clip[, rows, drop = FALSE], W, H)
    if (is.null(f)) next
    uv <- f$b %*% tex[rows, , drop = FALSE]
    keep <- modes[k + 2] * (uv[, 1] * uv[, 1] - uv[, 2]) >= 0
    if (!any(keep)) next
    rgba <- f$b[keep, , drop = FALSE] %*% colors[rows, , drop = FALSE]
    layer$add(f$row[keep], f$col[keep], rgba)
  }
  layer$draw()
}

# Wireframe (moderngl's ctx.wireframe): the triangles are drawn as lines one
# pixel wide, and the fragment shader still keeps or drops each fragment. On
# a fill triangle the edges v0 v1 and v1 v2 have u^2 - v >= 0 and the chord
# v0 v2 has u^2 - v <= 0, so mode 0 draws all three edges, mode 1 the two
# outer ones and mode -1 the chord.
software_wire_fill <- function(buffer, uniforms, viewport) {
  verts <- get("in_vert", envir = buffer)
  if (!nrow(verts)) return(invisible(NULL))
  colors <- get("in_color", envir = buffer)
  modes <- get("texture_mode", envir = buffer)[, 1]
  software_push_ndc()
  on.exit(grid::popViewport(), add = TRUE)
  for (k in seq(1, nrow(verts), by = 3)) {
    xy <- software_ndc(verts[k:(k + 2), , drop = FALSE], uniforms)
    if (!all(is.finite(xy))) next
    edges <- if (modes[k] == 0) list(1:2, 2:3, c(3, 1)) else if (modes[k] > 0) list(1:2, 2:3) else list(c(1, 3))
    for (e in edges) {
      grid::grid.lines(xy[e, 1], xy[e, 2], default.units = "native",
                       gp = grid::gpar(col = software_rgba(colors[k, ]), lwd = 72 / 96, lineend = "butt"))
    }
  }
  invisible(NULL)
}

# Wireframe of a stroke: the edges of each curve's tile, as the vertex
# shader builds it, keep only the fragments within the stroke's thickness of
# the curve, which is where an edge crosses the stroke.
software_wire_stroke <- function(buffer, uniforms, viewport) {
  curves <- get("current_curve", envir = buffer)
  if (!nrow(curves)) return(invisible(NULL))
  tiles <- get("tile_coordinate", envir = buffer)
  colors <- get("in_color", envir = buffer)
  widths <- get("in_width", envir = buffer)[, 1]
  normal <- uniforms$manim_unit_normal %||% OUT
  s <- seq(0, 1, length.out = 201)
  software_push_ndc()
  on.exit(grid::popViewport(), add = TRUE)
  for (k in seq(1, nrow(curves) - 2, by = 3)) {
    tile <- software_stroke_tile(matrix(curves[k, ], 3, 3, byrow = TRUE), tiles[k:(k + 2), , drop = FALSE],
                                 widths[k], normal)
    if (is.null(tile)) next
    tri <- tile$corners
    for (e in list(1:2, 2:3, c(3, 1))) {
      seg <- outer(1 - s, tri[e[1], ]) + outer(s, tri[e[2], ])
      suv <- outer(1 - s, tile$corner_uv[e[1], ]) + outer(s, tile$corner_uv[e[2], ])
      keep <- software_curve_distance(suv, tile$curve_uv, tile$quad) < tile$thick
      if (!any(keep)) next
      runs <- rle(keep)
      ends <- cumsum(runs$lengths)
      starts <- ends - runs$lengths + 1
      for (r in which(runs$values)) {
        xy <- software_ndc(seg[starts[r]:ends[r], , drop = FALSE], uniforms)
        grid::grid.lines(xy[, 1], xy[, 2], default.units = "native",
                         gp = grid::gpar(col = software_rgba(colors[k, ]), lwd = 72 / 96, lineend = "butt"))
      }
    }
  }
  invisible(NULL)
}

# vectorized_mobject_stroke: the vertex shader spans each curve with a tile
# (two triangles) in the plane of the curve, and a fragment is drawn where
# its point is within 0.004 * width of the curve: the quadratic Bezier
# curve, or the line between its ends when the three points are aligned or
# two coincide. A curve whose points all coincide draws nothing.
software_stroke_tile <- function(pts, tile, width, normal) {
  v01 <- pts[2, ] - pts[1, ]
  v12 <- pts[3, ] - pts[2, ]
  distinct <- c(get_norm(v01), get_norm(v12)) > 1e-6
  if (!any(distinct)) return(NULL)
  aligned <- all(distinct) && acos(min(max(sum(normalize(v01) * normalize(v12)), -1), 1)) < 5e-2
  quad <- all(distinct) && !aligned
  x_unit <- normalize(pts[3, ] - pts[1, ])
  unit_normal <- if (quad) normalize(cross(v01, v12)) else normal
  y_unit <- cross(unit_normal, x_unit)
  if (quad && sum(y_unit * v01) < 0) y_unit <- -y_unit
  uv <- cbind(pts %*% x_unit, pts %*% y_unit)
  lo <- pmin(uv[1, ], uv[3, ])
  hi <- pmax(uv[1, ], uv[3, ])
  if (any(uv[2, ] < lo | uv[2, ] > hi)) {
    tt <- pmin(pmax((uv[1, ] - uv[2, ]) / (uv[1, ] - 2 * uv[2, ] + uv[3, ]), 0), 1)
    tt[!is.finite(tt)] <- 0
    q <- (1 - tt)^2 * uv[1, ] + 2 * (1 - tt) * tt * uv[2, ] + tt^2 * uv[3, ]
    lo <- pmin(lo, q)
    hi <- pmax(hi, q)
  }
  thick <- 0.004 * width
  origin <- pts[1, ] - thick * (x_unit + y_unit)
  xv <- x_unit * (hi[1] - lo[1] + 2 * thick)
  yv <- y_unit * (hi[2] - lo[2] + 2 * thick)
  corners <- t(vapply(seq_len(nrow(tile)), function(r) origin + tile[r, 1] * xv + tile[r, 2] * yv, numeric(3)))
  list(corners = corners, corner_uv = cbind(corners %*% x_unit, corners %*% y_unit), curve_uv = uv,
       quad = quad, thick = thick)
}

# Distance from points (n x 2) to a quadratic Bezier curve or a segment in
# the tile's plane: the nearest of dense samples, refined by Newton steps.
software_curve_distance <- function(q, uv, quad) {
  if (!quad) {
    a <- uv[1, ]; d <- uv[3, ] - a
    h <- pmin(pmax(((q[, 1] - a[1]) * d[1] + (q[, 2] - a[2]) * d[2]) / sum(d^2), 0), 1)
    return(sqrt((q[, 1] - a[1] - h * d[1])^2 + (q[, 2] - a[2] - h * d[2])^2))
  }
  t <- seq(0, 1, length.out = 65)
  cx <- (1 - t)^2 * uv[1, 1] + 2 * t * (1 - t) * uv[2, 1] + t^2 * uv[3, 1]
  cy <- (1 - t)^2 * uv[1, 2] + 2 * t * (1 - t) * uv[2, 2] + t^2 * uv[3, 2]
  d2 <- outer(q[, 1], cx, "-")^2 + outer(q[, 2], cy, "-")^2
  s <- t[max.col(-d2, ties.method = "first")]
  A <- uv[2, ] - uv[1, ]
  B <- uv[1, ] - 2 * uv[2, ] + uv[3, ]
  for (it in 1:4) {
    px <- uv[1, 1] + 2 * A[1] * s + B[1] * s^2
    py <- uv[1, 2] + 2 * A[2] * s + B[2] * s^2
    dx <- 2 * A[1] + 2 * B[1] * s
    dy <- 2 * A[2] + 2 * B[2] * s
    g <- (px - q[, 1]) * dx + (py - q[, 2]) * dy
    h <- dx^2 + dy^2 + (px - q[, 1]) * 2 * B[1] + (py - q[, 2]) * 2 * B[2]
    s <- pmin(pmax(s - ifelse(abs(h) > 1e-300, g / h, 0), 0), 1)
  }
  px <- uv[1, 1] + 2 * A[1] * s + B[1] * s^2
  py <- uv[1, 2] + 2 * A[2] * s + B[2] * s^2
  sqrt((px - q[, 1])^2 + (py - q[, 2])^2)
}

software_draw_stroke <- function(buffer, uniforms, viewport) {
  curves <- get("current_curve", envir = buffer)
  if (!nrow(curves)) return(invisible(NULL))
  tiles <- get("tile_coordinate", envir = buffer)
  colors <- get("in_color", envir = buffer)
  widths <- get("in_width", envir = buffer)[, 1]
  normal <- uniforms$manim_unit_normal %||% OUT
  W <- viewport[3]
  H <- viewport[4]
  layer <- software_layer(W, H)
  for (k in seq(1, nrow(curves) - 2, by = 3)) {
    rows <- k:(k + 2)
    tile <- software_stroke_tile(matrix(curves[k, ], 3, 3, byrow = TRUE), tiles[rows, , drop = FALSE], widths[k], normal)
    if (is.null(tile)) next
    f <- software_raster_triangle(software_clip(tile$corners, uniforms), W, H)
    if (is.null(f)) next
    q <- f$b %*% tile$corner_uv
    keep <- software_curve_distance(q, tile$curve_uv, tile$quad) < tile$thick
    if (!any(keep)) next
    layer$add(f$row[keep], f$col[keep], f$b[keep, , drop = FALSE] %*% colors[rows, , drop = FALSE])
  }
  layer$draw()
}

# vectorized_mobject_rendering ----------------------------------------------------

#' @rdname opengl_renderer
#' @export
render_opengl_vectorized_mobject_fill <- function(renderer, mobject) {
  matrix_to_mobject_list <- build_matrix_lists(mobject)
  for (key in names(matrix_to_mobject_list)) {
    model_matrix <- matrix(as.numeric(strsplit(key, ",")[[1]]), 4, 4, byrow = TRUE)
    render_mobject_fills_with_matrix(renderer, model_matrix, matrix_to_mobject_list[[key]])
  }
  invisible(NULL)
}

#' @rdname opengl_renderer
#' @export
render_mobject_fills_with_matrix <- function(renderer, model_matrix, mobjects) {
  total_size <- sum(vapply(mobjects, function(m) length(triangulate_mobject(m)), 0L))
  attributes <- shader_data(c(in_vert = 3, in_color = 4, texture_coords = 2, texture_mode = 1), total_size)
  write_offset <- 0
  for (submob in mobjects) {
    if (!submob$has_points()) next
    tri <- triangulate_mobject(submob)
    rows <- write_offset + seq_len(length(tri))
    for (name in c("in_vert", "texture_coords", "texture_mode")) {
      m <- get(name, envir = attributes)
      m[rows, ] <- get(name, envir = tri)
      assign(name, m, envir = attributes)
    }
    m <- get("in_color", envir = attributes)
    m[rows, ] <- matrix(as.numeric(submob$fill_rgba[1, ]), length(rows), 4, byrow = TRUE)
    assign("in_color", m, envir = attributes)
    write_offset <- write_offset + length(rows)
  }
  fill_shader <- Shader(renderer$context, name = "vectorized_mobject_fill")
  fill_shader$set_uniform("u_model_view_matrix",
                          matrix_to_shader_input(renderer$camera$unformatted_view_matrix %*% model_matrix))
  fill_shader$set_uniform("u_projection_matrix", renderer$camera$projection_matrix)
  vbo <- renderer$context$buffer(attributes)
  vao <- renderer$context$simple_vertex_array(fill_shader, vbo, names(attributes))
  vao$render()
  vao$release()
  invisible(NULL)
}

#' @rdname opengl_renderer
#' @export
render_opengl_vectorized_mobject_stroke <- function(renderer, mobject) {
  matrix_to_mobject_list <- build_matrix_lists(mobject)
  for (key in names(matrix_to_mobject_list)) {
    model_matrix <- matrix(as.numeric(strsplit(key, ",")[[1]]), 4, 4, byrow = TRUE)
    render_mobject_strokes_with_matrix(renderer, model_matrix, matrix_to_mobject_list[[key]])
  }
  invisible(NULL)
}

#' @rdname opengl_renderer
#' @export
render_mobject_strokes_with_matrix <- function(renderer, model_matrix, mobjects) {
  quads <- lapply(mobjects, opengl_quadratic_points)
  total_size <- sum(vapply(quads, nrow, 0L))
  points <- matrix(0, total_size, 3)
  colors <- matrix(0, total_size, 4)
  widths <- numeric(total_size)
  write_offset <- 0
  for (i in seq_along(mobjects)) {
    submob <- mobjects[[i]]
    if (!submob$has_points()) next
    rows <- write_offset + seq_len(nrow(quads[[i]]))
    points[rows, ] <- quads[[i]]
    rgba <- matrix(as.numeric(submob$stroke_rgba), ncol = 4)
    colors[rows, ] <- if (nrow(rgba) == length(rows)) rgba else rgba[rep(seq_len(nrow(rgba)), each = length(rows)), ]
    widths[rows] <- rep(submob$stroke_width[1], length(rows))
    write_offset <- write_offset + length(rows)
  }
  n <- total_size
  stroke_data <- shader_data(c(current_curve = 9, tile_coordinate = 2, in_color = 4, in_width = 1), 2 * n)
  curve_rows <- if (n) rep(seq_len(n %/% 3), each = 3) else integer(0)
  # Each row holds the 3 x 3 points of its curve, column by column as numpy's
  # (3, 3) rows flatten.
  curve <- t(vapply(curve_rows, function(j) as.numeric(t(points[(3 * j - 2):(3 * j), ])), numeric(9)))
  if (!n) curve <- matrix(0, 0, 9)
  assign("current_curve", rbind(curve, curve), envir = stroke_data)
  assign("in_color", rbind(colors, colors), envir = stroke_data)
  assign("in_width", matrix(c(widths, widths), ncol = 1), envir = stroke_data)
  tiles <- function(m) m[rep(seq_len(3), n %/% 3), , drop = FALSE]
  assign("tile_coordinate", rbind(tiles(rbind(c(0, 0), c(0, 1), c(1, 1))), tiles(rbind(c(0, 0), c(1, 0), c(1, 1)))),
         envir = stroke_data)
  shader <- Shader(renderer$context, "vectorized_mobject_stroke")
  shader$set_uniform("u_model_view_matrix",
                     matrix_to_shader_input(renderer$camera$unformatted_view_matrix %*% model_matrix))
  shader$set_uniform("u_projection_matrix", renderer$camera$projection_matrix)
  shader$set_uniform("manim_unit_normal", -as.numeric(mobjects[[1]]$unit_normal[1, ]))
  vbo <- renderer$context$buffer(stroke_data)
  vao <- renderer$context$simple_vertex_array(shader, vbo, names(stroke_data))
  renderer$frame_buffer_object$use()
  vao$render()
  vao$release()
  invisible(NULL)
}

# Grid camera for shader wrappers ------------------------------------------------

# Whether a mobject is one of upstream's OpenGLVMobjects. manimR's OpenGL
# shapes are subclasses of their Cairo counterparts, so their class names
# tell; manimR's OpenGLSurface is a VMobject but upstream's is not.
opengl_is_vmobject <- function(m) {
  is_vmobject(m) && any(startsWith(class(m), "OpenGL")) && !inherits(m, "OpenGLSurface")
}

DEFAULT_OPENGL_FRAME_SHAPE <- c(8 * 16 / 9, 8)

# The mobjects drawn with upstream's surface and textured_surface shaders.
opengl_is_software_surface <- function(m) inherits(m, "OpenGLSurface")

# Draws OpenGL mobjects as upstream's shaders place them: points rotated by
# camera_rotation about camera_center, scaled by focal_distance /
# (focal_distance - z), and lit by add_light() with the light at
# light_source_position (all from the perspective uniforms).
OpenGLGridCameraClass <- R6::R6Class("OpenGLGridCamera", inherit = ThreeDCameraClass, lock_objects = FALSE,
  public = list(
    uniforms = NULL,
    set_uniforms = function(uniforms) {
      self$uniforms <- uniforms
      self$rotation_matrix <- matrix(uniforms$camera_rotation, 3, 3)
      invisible(self)
    },
    get_frame_width = function() self$uniforms$frame_shape[1],
    get_frame_height = function() self$uniforms$frame_shape[2],
    get_frame_center = function() as.numeric(self$uniforms$camera_center),
    get_focal_distance = function() self$uniforms$focal_distance,
    get_zoom = function() 1,
    reset_rotation_matrix = function() invisible(self),
    # With the projection shaders on, upstream's get_shader_wrapper_list()
    # leaves out the fill (or stroke) wrappers of OpenGL VMobjects.
    apply_fill = function(vmobject, paths) {
      if (opengl_is_vmobject(vmobject) && isTRUE(cfg("use_projection_fill_shaders"))) return(invisible(self))
      super$apply_fill(vmobject, paths)
    },
    apply_stroke = function(vmobject, paths, background = FALSE) {
      if (opengl_is_vmobject(vmobject) && isTRUE(cfg("use_projection_stroke_shaders"))) return(invisible(self))
      super$apply_stroke(vmobject, paths, background)
    },
    draw_background = function() invisible(self),
    project_3d_points = function(points) {
      points <- as_points(points)
      fd <- self$get_focal_distance()
      p <- sweep(points, 2, self$get_frame_center()) %*% t(self$get_rotation_matrix())
      psf <- pmax(0, fd / (fd - p[, 3]))
      scale <- ifelse(psf > 0, psf, 1)
      p[, 1:2] <- p[, 1:2] * scale
      p
    },
    project_points = function(points, mobject = NULL) {
      if (!all(is.finite(points))) points <- matrix(0, nrow(points), 3)
      fc <- self$get_frame_center()[1:2]
      if (isTRUE(as.logical(mobject$is_fixed_in_frame %||% FALSE))) {
        scale <- c(self$get_frame_width(), self$get_frame_height()) / DEFAULT_OPENGL_FRAME_SHAPE
        return(sweep(sweep(points[, 1:2, drop = FALSE], 2, scale, "*"), 2, fc, "+"))
      }
      sweep(self$project_3d_points(points)[, 1:2, drop = FALSE], 2, fc, "+")
    },
    modified_rgbas = function(vmobject, rgbas) {
      gloss <- vmobject$gloss %||% 0
      shadow <- vmobject$shadow %||% 0
      if ((gloss == 0 && shadow == 0) || vmobject$get_num_points() == 0) return(rgbas)
      rot <- self$get_rotation_matrix()
      point <- drop(rot %*% (vmobject$get_center() - self$get_frame_center()))
      normal <- drop(rot %*% vmobject$get_unit_normal())
      for (i in seq_len(nrow(rgbas))) {
        rgbas[i, ] <- opengl_add_light(rgbas[i, ], point, normal, as.numeric(self$uniforms$light_source_position),
                                       gloss, shadow)
      }
      rgbas
    }
  )
)

# add_light() of upstream's finalize_color.glsl.
opengl_add_light <- function(color, point, unit_normal, light_coords, gloss, shadow) {
  if (gloss == 0 && shadow == 0) return(color)
  if (unit_normal[3] < 0) unit_normal <- -unit_normal
  to_camera <- c(0, 0, 6) - point
  to_light <- light_coords - point
  light_reflection <- -to_light + 2 * unit_normal * sum(to_light * unit_normal)
  dot_prod <- sum(normalize(light_reflection) * normalize(to_camera))
  shine <- gloss * exp(-3 * (1 - dot_prod)^2)
  dp2 <- sum(normalize(to_light) * unit_normal)
  darkening <- 1 + (max(dp2, 0) - 1) * shadow
  c(darkening * (color[1:3] + (1 - color[1:3]) * shine), color[4])
}

# Renderer ---------------------------------------------------------------------------

#' @rdname opengl_renderer
#' @format NULL
#' @usage NULL
#' @export
OpenGLRendererClass <- R6::R6Class("OpenGLRenderer", inherit = RendererClass, lock_objects = FALSE,
  public = list(
    capabilities = RendererCapabilities(live_preview = TRUE),
    anti_alias_width = 1.5,
    animation_start_time = 0,
    animation_elapsed_time = 0,
    pressed_keys = NULL,
    window = NULL,
    path_to_texture_id = NULL,
    context = NULL,
    frame_buffer_object = NULL,
    perspective_uniforms = NULL,
    partial_movie_files = NULL,
    scene = NULL,
    initialize = function(file_writer_class = SceneFileWriterClass, skip_animations = FALSE) {
      self$file_writer_class <- file_writer_class
      self$skip_animations <- skip_animations
      self$original_skipping_status <- skip_animations
      self$animations_hashes <- list()
      self$camera <- OpenGLCamera()
      # manimR's scenes step by the camera's frame rate; upstream's OpenGL
      # scenes step by config$frame_rate.
      self$camera$frame_rate <- cfg("frame_rate")
      self$camera$use_z_index <- TRUE
      self$pressed_keys <- integer(0)
      self$path_to_texture_id <- list()
      self$background_color <- cfg("background_color")
    },
    init_scene = function(scene, session_spec = scene$session_spec, file_writer_settings = scene$file_writer_settings) {
      self$partial_movie_files <- list()
      self$file_writer <- self$file_writer_class$new(file_writer_settings)
      self$scene <- scene
      self$background_color <- cfg("background_color")
      self$context <- OpenGLSoftwareContext()
      if (self$should_create_window(session_spec)) {
        self$window <- Window(self)
        self$context$screen <- self$get_frame_buffer_object(self$context, 0)
        self$frame_buffer_object <- self$context$detect_framebuffer()
      } else {
        self$frame_buffer_object <- self$get_frame_buffer_object(self$context, 0)
      }
      self$frame_buffer_object$use()
      self$context$enable("BLEND")
      self$context$wireframe <- isTRUE(cfg("enable_wireframe"))
      self$context$blend_func <- c("SRC_ALPHA", "ONE_MINUS_SRC_ALPHA", "ONE", "ONE")
      invisible(self)
    },
    should_create_window = function(session_spec) isTRUE(session_spec$presentation$live_preview),
    get_pixel_shape = function() {
      if (is.null(self$frame_buffer_object)) return(NULL)
      self$frame_buffer_object$viewport[3:4]
    },
    refresh_perspective_uniforms = function(camera) {
      pixel_shape <- self$get_pixel_shape()
      if (is.null(pixel_shape)) stop("Pixel shape is None, cannot refresh perspective uniforms.", call. = FALSE)
      frame_shape <- camera$get_shape()
      anti_alias_width <- self$anti_alias_width / (pixel_shape[2] / frame_shape[2])
      rotation <- camera$inverse_rotation_matrix
      light_pos <- drop(rotation %*% camera$light_source$get_location())
      self$perspective_uniforms <- list(
        frame_shape = frame_shape,
        anti_alias_width = anti_alias_width,
        camera_center = as.numeric(camera$get_center()),
        camera_rotation = as.numeric(rotation),
        light_source_position = light_pos,
        focal_distance = camera$get_focal_distance()
      )
      invisible(self)
    },
    render_mobject = function(mobject) {
      if (opengl_is_vmobject(mobject)) {
        if (isTRUE(cfg("use_projection_fill_shaders"))) render_opengl_vectorized_mobject_fill(self, mobject)
        if (isTRUE(cfg("use_projection_stroke_shaders"))) render_opengl_vectorized_mobject_stroke(self, mobject)
      }
      # The shader wrappers, in the order of upstream's
      # get_shader_wrapper_list(): a mobject before its submobjects, and a
      # VMobject's whole family through the quadratic_bezier shaders.
      fbo <- self$frame_buffer_object
      pixel_shape <- self$get_pixel_shape()
      cam <- OpenGLGridCameraClass$new(pixel_width = pixel_shape[1], pixel_height = pixel_shape[2],
                                       should_apply_shading = FALSE)
      cam$set_uniforms(self$perspective_uniforms)
      u <- self$perspective_uniforms
      walk <- function(m) {
        if (opengl_is_software_surface(m)) {
          # manimR's surfaces also hold their faces as submobjects, which
          # upstream's do not; only the surfaces among them are drawn.
          software_draw_surface(fbo, m, u)
          for (sm in Filter(opengl_is_software_surface, m$submobjects)) walk(sm)
          return(invisible(NULL))
        }
        if (is_vmobject(m)) {
          for (sm in software_draw_vmobject(fbo, m, u)) walk(sm)
          return(invisible(NULL))
        }
        if (inherits(m, "OpenGLPMobject")) {
          software_draw_true_dot(fbo, m, u)
        } else if (NROW(m$points) > 0) {
          # Images and other mobjects are drawn by the grid camera.
          cam$display_mobject(m)
        }
        for (sm in m$submobjects) walk(sm)
      }
      fbo$with_device(function() {
        cam$push_view()
        on.exit(grid::popViewport(), add = TRUE)
        walk(mobject)
      })
      invisible(self)
    },
    get_texture_id = function(path) {
      key <- if (is.character(path)) path else paste0("<image ", digest::digest(path), ">")
      if (is.null(self$path_to_texture_id[[key]])) self$create_texture(path, key)
      self$path_to_texture_id[[key]]
    },
    create_texture = function(source, key) {
      img <- if (is.character(source)) ImageMobject(source)$pixel_array else change_to_rgba_array(source)
      tid <- length(self$path_to_texture_id)
      self$context$texture(size = dim(img)[2:1], components = 4, data = img)
      self$path_to_texture_id[[key]] <- tid
      tid
    },
    play = function(scene, ...) {
      self$skip_animations <- self$original_skipping_status
      self$update_skipping_status()
      if (!is.null(self$target_time)) {
        scene$compile_animation_data(...)
        return(self$play_to_target(scene))
      }
      # handle_caching_play, as for the Cairo renderer, with the OpenGL backend.
      scene$compile_animation_data(...)
      fw <- self$file_writer
      hash <- NULL
      if (!self$skip_animations) {
        if (isTRUE(cfg("disable_caching"))) {
          hash <- sprintf("uncached_%05d", self$num_plays)
        } else {
          hash <- get_hash_from_play_call(scene, self$camera, scene$animations, scene$mobjects, backend = "opengl",
                                          encoder_fingerprint = video_encoder_fingerprint(scene$session_spec$video_encoder))
          if (fw$is_already_cached(hash)) {
            logger$info("Animation %d : Using cached data (hash : %s)", self$num_plays, hash)
            self$skip_animations <- TRUE
          }
        }
      }
      fw$add_partial_movie_file(hash)
      self$animations_hashes[[length(self$animations_hashes) + 1]] <- hash
      self$animation_start_time <- as.numeric(Sys.time())
      fw$begin_animation(!self$skip_animations, animation_index = self$num_plays)
      scene$begin_animations()
      if (scene$is_current_animation_frozen_frame()) {
        self$update_frame(scene)
        output <- fw$output_spec
        if (!self$skip_animations && (output$is_video || output$is_image_sequence)) {
          fw$write_frame(self$get_frame(), as.integer(cfg("frame_rate") * scene$duration))
        }
        if (!is.null(self$window)) self$window$swap_buffers()
        self$animation_elapsed_time <- scene$duration
      } else {
        scene$play_internal()
      }
      fw$end_animation(!self$skip_animations)
      self$time <- self$time + scene$duration
      self$num_plays <- self$num_plays + 1
      invisible(self)
    },
    clear_screen = function() {
      do.call(self$frame_buffer_object$clear, as.list(self$background_color))
      if (!is.null(self$window)) self$window$swap_buffers()
      invisible(self)
    },
    render = function(scene, time, moving_mobjects = NULL) {
      self$update_frame(scene)
      if (self$skip_animations) return(invisible(self))
      output <- self$file_writer$output_spec
      if (output$is_video || output$is_image_sequence) self$file_writer$write_frame(self$get_frame())
      if (!is.null(self$window)) self$window$swap_buffers()
      invisible(self)
    },
    update_frame = function(scene, ...) {
      do.call(self$frame_buffer_object$clear, as.list(self$background_color))
      cam <- scene$camera
      self$refresh_perspective_uniforms(cam)
      for (mobject in scene$mobjects) {
        if (isFALSE(mobject$should_render)) next
        self$render_mobject(mobject)
      }
      for (obj in scene$meshes) {
        for (mesh in obj$get_meshes()) {
          mesh$set_uniforms(self)
          mesh$render()
        }
      }
      self$animation_elapsed_time <- as.numeric(Sys.time()) - self$animation_start_time
      invisible(self)
    },
    scene_finished = function(scene) {
      on.exit(self$close_device(), add = TRUE)
      output <- self$file_writer$output_spec
      if (self$num_plays > 0 && (output$is_video || output$is_image_sequence)) {
        self$file_writer$finish()
      } else if (self$num_plays == 0) {
        self$update_frame(scene)
      }
      if (self$should_save_last_frame()) {
        if (self$num_plays > 0) self$update_frame(scene)
        self$file_writer$save_image(self$get_frame())
      }
      self$file_writer$final_file_path
    },
    should_save_last_frame = function() {
      output <- self$file_writer$output_spec
      if (isTRUE(output$is_still)) return(TRUE)
      if (isTRUE(self$scene$interactive_mode)) return(FALSE)
      self$num_plays == 0 && isTRUE(output$fallback_to_still)
    },
    # The frame as an R raster (upstream returns a PIL image).
    get_image = function() grDevices::as.raster(native_raster_to_array(self$get_frame()) / 255),
    save_static_frame_data = function(scene, static_mobjects) invisible(NULL),
    get_frame_buffer_object = function(context, samples = 0) {
      size <- c(cfg("pixel_width"), cfg("pixel_height"))
      context$framebuffer(color_attachments = context$texture(size, components = 4, samples = samples),
                          depth_attachment = context$depth_renderbuffer(size, samples = samples))
    },
    get_raw_frame_buffer_object_data = function(dtype = "f1") {
      self$frame_buffer_object$read(viewport = self$frame_buffer_object$viewport, components = 4, dtype = dtype)
    },
    # The frame as a nativeRaster, as manimR's file writer takes it (upstream
    # returns the RGBA array, top row first).
    get_frame = function() {
      if (is.null(self$get_pixel_shape())) stop("Pixel shape is None, cannot get frame.", call. = FALSE)
      raw <- self$get_raw_frame_buffer_object_data(dtype = "f1")
      self$last_frame <- array_to_native_raster(raw[rev(seq_len(dim(raw)[1])), , , drop = FALSE] / 255)
      self$last_frame
    },
    pixel_coords_to_space_coords = function(px, py, relative = FALSE, top_left = FALSE) {
      pixel_shape <- self$get_pixel_shape()
      if (is.null(pixel_shape)) return(c(0, 0, 0))
      pixel_width <- pixel_shape[1]
      pixel_height <- pixel_shape[2]
      frame_height <- cfg("frame_height")
      frame_center <- self$camera$get_center()
      if (relative) return(2 * c(px / pixel_width, py / pixel_height, 0))
      scale <- frame_height / pixel_height
      y_direction <- if (top_left) -1 else 1
      frame_center + scale * c(px - pixel_width / 2, y_direction * (py - pixel_height / 2), 0)
    },
    open_device = function() {
      if (!is.null(self$frame_buffer_object)) self$frame_buffer_object$open()
      invisible(self)
    },
    close_device = function() {
      if (!is.null(self$frame_buffer_object)) self$frame_buffer_object$release()
      if (!is.null(self$window)) self$window$close()
      invisible(self)
    }
  ),
  active = list(
    background_color = function(value) {
      if (missing(value)) return(private$.background_color)
      private$.background_color <- as.numeric(color_to_rgba(value))
    }
  ),
  private = list(.background_color = NULL)
)

#' @rdname opengl_renderer
#' @export
OpenGLRenderer <- build_constructor(OpenGLRendererClass)

# Window ------------------------------------------------------------------------------

# The monitor config$window_monitor picks, as upstream: monitors[min(index,
# len(monitors) - 1)]. `monitors` is one monitor (a list with x, y, width and
# height) or a list of them; R cannot list the screens itself.
opengl_monitor <- function(monitors, index = 0) {
  if (is.null(monitors)) monitors <- list(list(x = 0, y = 0, width = 1920, height = 1080))
  if (!is.null(monitors$width)) monitors <- list(monitors)
  monitors[[min(as.integer(index %||% 0), length(monitors) - 1) + 1]]
}

# Size of upstream's window from config$window_size and the monitor.
opengl_window_size <- function(window_size, monitor) {
  msg <- paste0("window_size must be specified either as 'default', a string of the form 'width,height', ",
                "or a tuple of 2 ints of the form (width, height).")
  if (is.numeric(window_size)) {
    if (length(window_size) != 2) stop(msg, call. = FALSE)
    return(as.integer(window_size))
  }
  if (identical(window_size, "default")) {
    window_width <- monitor$width
    if (!isTRUE(cfg("fullscreen"))) window_width <- window_width %/% 2
    window_height <- as.integer((window_width * cfg("frame_height")) %/% cfg("frame_width"))
    return(as.integer(c(window_width, window_height)))
  }
  parts <- strsplit(window_size, ",", fixed = TRUE)[[1]]
  if (length(parts) == 2) return(as.integer(parts))
  stop(msg, call. = FALSE)
}

#' @rdname opengl_renderer
#' @format NULL
#' @usage NULL
#' @export
WindowClass <- R6::R6Class("Window", lock_objects = FALSE,
  public = list(
    fullscreen = FALSE,
    resizable = TRUE,
    gl_version = c(3, 3),
    vsync = TRUE,
    cursor = TRUE,
    title = NULL,
    size = NULL,
    position = NULL,
    renderer = NULL,
    device = NULL,
    last_mouse = NULL,
    # The monitor is the one of `getOption("manimR.monitor")` (a monitor, a
    # list with x, y, width and height, or a list of them) that
    # config$window_monitor picks, else 1920 by 1080 pixels at the origin: R
    # has no portable way to list the screens. The window is an R graphics
    # device.
    initialize = function(renderer, window_size = cfg("window_size"), monitor = NULL, open = TRUE, ...) {
      monitor <- monitor %||% opengl_monitor(getOption("manimR.monitor"), cfg("window_monitor"))
      size <- opengl_window_size(window_size, monitor)
      self$title <- paste("Manim Community", as.character(utils::packageVersion("manimR")))
      self$size <- size
      self$renderer <- renderer
      self$position <- self$find_initial_position(size, monitor)
      if (open) {
        if (!interactive()) stop("A Window needs an interactive R session.", call. = FALSE)
        prev <- grDevices::dev.cur()
        grDevices::dev.new(width = size[1] / 96, height = size[2] / 96, noRStudioGD = TRUE)
        self$device <- grDevices::dev.cur()
        if (prev > 1) grDevices::dev.set(prev)
      }
      self$swap_buffers()
    },
    # Shows the renderer's frame in the window.
    swap_buffers = function() {
      if (is.null(self$device) || !self$device %in% grDevices::dev.list()) return(invisible(self))
      if (is.null(self$renderer$frame_buffer_object)) return(invisible(self))
      frame <- self$renderer$get_frame()
      prev <- grDevices::dev.cur()
      grDevices::dev.set(self$device)
      on.exit(if (prev > 1 && prev != self$device && prev %in% grDevices::dev.list()) grDevices::dev.set(prev),
              add = TRUE)
      grid::grid.newpage(recording = FALSE)
      grid::grid.raster(frame, interpolate = TRUE)
      invisible(self)
    },
    # Waits for one mouse or key event in the window and passes it to the
    # handlers below, as pyglet's event loop does. Positions are in pixels
    # from the bottom left corner; R's buttons 0, 1 and 2 are pyglet's 1, 2
    # and 4. Only devices that report events (X11 with the Xlib type, and
    # Windows) can do this.
    handle_event = function() {
      if (is.null(self$device) || !self$device %in% grDevices::dev.list()) return(invisible(self))
      prev <- grDevices::dev.cur()
      grDevices::dev.set(self$device)
      on.exit(if (prev > 1 && prev != self$device && prev %in% grDevices::dev.list()) grDevices::dev.set(prev),
              add = TRUE)
      if (!length(grDevices::dev.capabilities("events")$events)) {
        stop("This graphics device does not report mouse and key events.", call. = FALSE)
      }
      px <- function(x, y) c(x * self$size[1], y * self$size[2])
      moved <- function(p) {
        d <- if (is.null(self$last_mouse)) c(0, 0) else p - self$last_mouse
        self$last_mouse <- p
        d
      }
      grDevices::setGraphicsEventHandlers(
        which = self$device, prompt = self$title,
        onMouseDown = function(buttons, x, y) {
          p <- px(x, y)
          moved(p)
          self$on_mouse_press(p[1], p[2], 2^buttons[1])
          TRUE
        },
        onMouseMove = function(buttons, x, y) {
          p <- px(x, y)
          d <- moved(p)
          if (length(buttons)) self$on_mouse_drag(p[1], p[2], d[1], d[2], 2^buttons[1])
          else self$on_mouse_motion(p[1], p[2], d[1], d[2])
          TRUE
        },
        onKeybd = function(key) {
          self$on_key_press(key)
          self$on_key_release(key)
          TRUE
        }
      )
      grDevices::getGraphicsEvent()
      invisible(self)
    },
    close = function() {
      if (!is.null(self$device) && self$device %in% grDevices::dev.list()) grDevices::dev.off(self$device)
      self$device <- NULL
      invisible(NULL)
    },
    on_mouse_motion = function(x, y, dx, dy) {
      point <- self$renderer$pixel_coords_to_space_coords(x, y)
      d_point <- self$renderer$pixel_coords_to_space_coords(dx, dy, relative = TRUE)
      self$renderer$scene$on_mouse_motion(point, d_point)
    },
    on_mouse_scroll = function(x, y, x_offset, y_offset) {
      point <- self$renderer$pixel_coords_to_space_coords(x, y)
      offset <- self$renderer$pixel_coords_to_space_coords(x_offset, y_offset, relative = TRUE)
      self$renderer$scene$on_mouse_scroll(point, offset)
    },
    on_key_press = function(symbol, modifiers = 0) {
      self$renderer$pressed_keys <- union(self$renderer$pressed_keys, symbol)
      self$renderer$scene$on_key_press(symbol, modifiers)
      FALSE
    },
    on_key_release = function(symbol, modifiers = 0) {
      self$renderer$pressed_keys <- setdiff(self$renderer$pressed_keys, symbol)
      self$renderer$scene$on_key_release(symbol, modifiers)
    },
    on_mouse_drag = function(x, y, dx, dy, buttons, modifiers = 0) {
      point <- self$renderer$pixel_coords_to_space_coords(x, y)
      d_point <- self$renderer$pixel_coords_to_space_coords(dx, dy, relative = TRUE)
      self$renderer$scene$on_mouse_drag(point, d_point, buttons, modifiers)
    },
    find_initial_position = function(size, monitor) {
      custom_position <- cfg("window_position")
      window_width <- size[1]
      window_height <- size[2]
      if (nchar(custom_position) == 1) {
        stop("window_position must specify both Y and X positions (Y/X -> UR). Also accepts LEFT/RIGHT/ORIGIN/UP/DOWN.",
             call. = FALSE)
      }
      if (custom_position %in% c("LEFT", "RIGHT")) {
        custom_position <- paste0("O", substr(custom_position, 1, 1))
      } else if (custom_position %in% c("UP", "DOWN")) {
        custom_position <- paste0(substr(custom_position, 1, 1), "O")
      } else if (custom_position == "ORIGIN") {
        custom_position <- "OO"
      } else if (grepl(",", custom_position, fixed = TRUE)) {
        pos <- as.integer(strsplit(custom_position, ",", fixed = TRUE)[[1]])
        return(c(pos[2], pos[1]))
      }
      char_to_n <- c(L = 0, U = 0, O = 1, R = 2, D = 2)
      width_diff <- monitor$width - window_width
      height_diff <- monitor$height - window_height
      c(monitor$x + (char_to_n[[substr(custom_position, 2, 2)]] * width_diff) %/% 2,
        -monitor$y + (char_to_n[[substr(custom_position, 1, 1)]] * height_diff) %/% 2)
    },
    on_mouse_press = function(x, y, button, modifiers = 0) {
      point <- self$renderer$pixel_coords_to_space_coords(x, y)
      mouse_button_map <- c(`1` = "LEFT", `2` = "MOUSE", `4` = "RIGHT")
      self$renderer$scene$on_mouse_press(point, mouse_button_map[[as.character(button)]], modifiers)
    }
  )
)

#' @rdname opengl_renderer
#' @export
Window <- build_constructor(WindowClass)
