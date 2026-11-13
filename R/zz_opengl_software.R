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
    clear = function(red = 0, green = 0, blue = 0, alpha = 0, ...) {
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
      fbo$with_device(function() draw(self$buffer, self$shader$uniforms, fbo$viewport))
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

# vectorized_mobject_fill: a fragment of a triangle is drawn where
# texture_mode * (u^2 - v) >= 0. With the texture coordinates (0, 0),
# (0.5, 0), (1, 1) that is the whole triangle for mode 0, the part between
# the curve and the control point for mode 1 and the part between the chord
# and the curve for mode -1, the curve being the quadratic Bezier curve of
# the three vertices. Pieces of one color are drawn as one path, so they
# leave no seams.
software_draw_fill <- function(buffer, uniforms, viewport) {
  verts <- get("in_vert", envir = buffer)
  if (!nrow(verts)) return(invisible(NULL))
  colors <- get("in_color", envir = buffer)
  modes <- get("texture_mode", envir = buffer)[, 1]
  t <- seq(0, 1, length.out = 17)
  pieces <- list()
  keys <- character(0)
  for (k in seq(1, nrow(verts), by = 3)) {
    v0 <- verts[k, ]; v1 <- verts[k + 1, ]; v2 <- verts[k + 2, ]
    mode <- modes[k]
    curve <- outer((1 - t)^2, v0) + outer(2 * t * (1 - t), v1) + outer(t^2, v2)
    poly <- if (mode == 0) rbind(v0, v1, v2) else if (mode > 0) rbind(v0, v1, curve[rev(seq_along(t)), ]) else curve
    xy <- software_ndc(poly, uniforms)
    area <- sum(xy[, 1] * xy[c(2:nrow(xy), 1), 2] - xy[c(2:nrow(xy), 1), 1] * xy[, 2])
    if (!is.finite(area) || abs(area) < 1e-14) next
    if (area < 0) xy <- xy[rev(seq_len(nrow(xy))), , drop = FALSE]
    key <- software_rgba(colors[k, ])
    keys <- c(keys, key)
    pieces[[length(pieces) + 1]] <- xy
  }
  if (!length(pieces)) return(invisible(NULL))
  software_push_ndc()
  on.exit(grid::popViewport(), add = TRUE)
  for (key in unique(keys)) {
    sel <- pieces[keys == key]
    xy <- do.call(rbind, sel)
    grid::grid.path(xy[, 1], xy[, 2], id = rep(seq_along(sel), vapply(sel, nrow, 0L)), default.units = "native",
                    rule = "winding", gp = grid::gpar(fill = key, col = NA))
  }
  invisible(NULL)
}

# vectorized_mobject_stroke: a fragment of a curve's tile is drawn within
# 0.004 * width of the curve (the quadratic Bezier curve, or the line between
# its ends when the three points are aligned), which is the curve drawn
# 0.008 * width wide with round ends. A curve whose points coincide has an
# empty tile.
software_draw_stroke <- function(buffer, uniforms, viewport) {
  curves <- get("current_curve", envir = buffer)
  n <- nrow(curves) %/% 2
  if (!n) return(invisible(NULL))
  colors <- get("in_color", envir = buffer)
  widths <- get("in_width", envir = buffer)[, 1]
  px_per_ndc <- viewport[4] / 2
  t <- seq(0, 1, length.out = 17)
  software_push_ndc()
  on.exit(grid::popViewport(), add = TRUE)
  for (k in seq(1, n, by = 3)) {
    pts <- matrix(curves[k, ], 3, 3, byrow = TRUE)
    v01 <- pts[2, ] - pts[1, ]
    v12 <- pts[3, ] - pts[2, ]
    distinct <- c(get_norm(v01), get_norm(v12)) > 1e-6
    if (!any(distinct)) next
    aligned <- all(distinct) && acos(min(max(sum(normalize(v01) * normalize(v12)), -1), 1)) < 5e-2
    line <- !all(distinct) || aligned
    path <- if (line) pts[c(1, 3), ] else outer((1 - t)^2, pts[1, ]) + outer(2 * t * (1 - t), pts[2, ]) + outer(t^2, pts[3, ])
    thickness <- 0.004 * widths[k]
    # The thickness at the curve's middle, measured on screen across it.
    mid <- path[ceiling(nrow(path) / 2), ]
    across <- cross(OUT, normalize(pts[3, ] - pts[1, ], fall_back = RIGHT))
    xy <- software_ndc(rbind(path, mid, mid + thickness * across), uniforms)
    m <- nrow(xy)
    lwd_px <- 2 * sqrt(sum((xy[m, ] - xy[m - 1, ])^2)) * px_per_ndc
    if (!is.finite(lwd_px) || lwd_px <= 0) next
    grid::grid.lines(xy[seq_len(m - 2), 1], xy[seq_len(m - 2), 2], default.units = "native",
                     gp = grid::gpar(col = software_rgba(colors[k, ]), lwd = lwd_px * 72 / 96,
                                     lineend = "round", linejoin = "round"))
  }
  invisible(NULL)
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
      # The shader wrappers: the mobject's family drawn by the grid camera.
      fbo <- self$frame_buffer_object
      pixel_shape <- self$get_pixel_shape()
      cam <- OpenGLGridCameraClass$new(pixel_width = pixel_shape[1], pixel_height = pixel_shape[2],
                                       should_apply_shading = FALSE)
      cam$set_uniforms(self$perspective_uniforms)
      fbo$with_device(function() {
        cam$push_view()
        on.exit(grid::popViewport(), add = TRUE)
        for (m in cam$get_mobjects_to_display(list(mobject))) cam$display_mobject(m)
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
    # The monitor is `getOption("manimR.monitor")` (a list with x, y, width
    # and height) or 1920 by 1080 pixels at the origin: R has no portable way
    # to ask for it. The window is an R graphics device.
    initialize = function(renderer, window_size = cfg("window_size"), monitor = NULL, open = TRUE, ...) {
      monitor <- monitor %||% getOption("manimR.monitor") %||% list(x = 0, y = 0, width = 1920, height = 1080)
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
