# The CPU side of upstream's OpenGL renderer: manim/renderer/shader.py,
# opengl_renderer.py (OpenGLCamera) and vectorized_mobject_rendering.py.
# These classes and functions hold and compute what upstream's renderer
# sends to the GPU; zz_opengl_software.R draws it.

#' Upstream's OpenGL renderer
#'
#' Upstream's OpenGL renderer keeps a camera mobject, a tree of 3D objects
#' and meshes, and compiled shader programs, and draws them with moderngl.
#' manimR computes what upstream computes on the CPU and draws the result in
#' software, with a context whose framebuffers are off screen graphics
#' devices:
#'
#' * `OpenGLCamera()` is upstream's camera mobject: a frame of five points
#'   (center, left, right, bottom, top), a model matrix that places it at
#'   `(0, 0, 11)`, Euler angles (`theta`, `phi`, `gamma`) and the projection
#'   and view matrices.
#' * `Object3D(...)` is a node of a tree of objects with a model matrix,
#'   a normal matrix and updaters; `Mesh()` adds vertex attributes, indices
#'   and a shader, and `FullScreenQuad()` is a mesh covering the frame.
#'   A scene takes meshes with `add()`, and `OpenGLRenderer` draws them
#'   after the mobjects: a mesh whose shader is one of upstream's mesh
#'   shaders (the `default`, `manim_coords`, `vertex_colors` and `test`
#'   folders) is rasterized by their rules, and other GLSL code (a
#'   `FullScreenQuad`'s too) runs in manimR's GLSL interpreter: the vertex
#'   shader on the vertices and the fragment shader on the fragments, with
#'   perspective-correct varyings, depth test and alpha blending. The
#'   interpreter takes the scalar, vector and square matrix types, in, out,
#'   uniform and const globals, user functions, `if`, `for`, `while`,
#'   `break`, `continue`, `return`, `discard`, structs and the common
#'   built-in functions, and runs a geometry shader (points or triangles in,
#'   a triangle strip out) between the two stages. A `sampler2D` uniform
#'   holds a texture unit: `context$texture(size, components, data)` makes
#'   a texture (bytes, the row at v = 0 first) and its `use(location)` binds
#'   it, sampled linearly and repeated as moderngl does; `texture()`,
#'   `textureLod()`, `texelFetch()` and `textureSize()` read it. Other
#'   sampler types, and units with no texture, read (0, 0, 0, 1), as
#'   OpenGL's default texture does, since upstream binds only 2D textures.
#'   Arrays inside structs raise an error, and
#'   `Mesh$render()` of a mesh it cannot run needs an OpenGL context and
#'   stops.
#' * `Shader(context, name, source)` reads the GLSL code of a shader folder
#'   under `SHADER_FOLDER` (or takes `source`, a list of
#'   `vertex_shader`, `fragment_shader` and `geometry_shader` code) and keeps
#'   it in `shader_program_cache` by name; `set_uniform()` stores a value for
#'   a uniform the code declares and ignores others, as upstream.
#' * `filter_attributes()` keeps the named attributes of shader data.
#' * `build_matrix_lists()` groups a mobject's family by hierarchical model
#'   matrix, and `triangulate_mobject()` gives the fill triangles of a
#'   VMobject with upstream's texture coordinates and modes.
#' * `affects_shader_info_id(func)` and `triggers_refreshed_triangulation(func)`
#'   are upstream's decorators as functions: they wrap a method `func(self,
#'   ...)`.
#'
#' * `OpenGLRenderer()` renders scenes as upstream's renderer: it clears its
#'   framebuffer to the background color, sets the perspective uniforms from
#'   the camera (`refresh_perspective_uniforms()`) and draws each mobject.
#'   The shader wrappers run upstream's GLSL rules in software, in the
#'   order of upstream's `get_shader_wrapper_list()`: a VMobject's family
#'   runs the quadratic_bezier_fill and quadratic_bezier_stroke shaders
#'   (anti aliased fills, and strokes with upstream's joints and ends), an
#'   `OpenGLSurface` the surface shader, an `OpenGLTexturedSurface` or
#'   `OpenGLImageMobject` the textured_surface shader (nearest texel), and an
#'   OpenGL point cloud the
#'   true_dot shader. Points are placed as the shaders place them (rotated
#'   by `camera_rotation`, scaled by `focal_distance / (focal_distance -
#'   z)`, fixed in frame mobjects in the default frame); triangles are
#'   rasterized at pixel centers, lit per pixel by upstream's `add_light()`,
#'   and with `depth_test` (on by default for surfaces) tested against and
#'   written to the framebuffer's depth buffer. A plain `ImageMobject`, on
#'   which upstream's OpenGL renderer raises, is drawn by a grid camera.
#'   `config$renderer = "opengl"` makes
#'   scenes use it. Mobjects of the classes upstream converts to OpenGL
#'   classes under that setting (all but a bare `VMobject()` or `Mobject()`,
#'   `StreamLine`, images and user classes made directly on `VMobjectClass`
#'   or `MobjectClass`) follow upstream's OpenGL classes: they get the OpenGL mobject methods
#'   (`get_triangulation()`, `get_shader_data()`, `set_gloss()` and the rest)
#'   and upstream's OpenGL geometry. Each quadratic curve is stored raised
#'   to a cubic, so `$points`, `get_num_points()`, `get_subpaths()`,
#'   `get_nth_curve_points()` and `get_bezier_tuples()` give 4 points per
#'   curve where upstream gives 3; curve counts, anchors, bounds and drawn
#'   frames match upstream. `get_frame()` gives a `nativeRaster`;
#'   `get_raw_frame_buffer_object_data()` the pixels bottom row first, as
#'   OpenGL reads them.
#' * `render_opengl_vectorized_mobject_fill()`,
#'   `render_opengl_vectorized_mobject_stroke()` and their `_with_matrix`
#'   helpers build upstream's vertex buffers and uniforms and draw them as
#'   upstream's projection shaders do (with `config$use_projection_fill_shaders`
#'   and `config$use_projection_stroke_shaders`): the fill keeps the part of
#'   each triangle on the side of its curve given by its texture mode, and the
#'   stroke the points within `0.004 * width` of its curve.
#' * `OpenGLSoftwareContext()` stands for moderngl's context: `framebuffer()`,
#'   `buffer()` and `simple_vertex_array()`, whose `render()` draws the
#'   `vectorized_mobject_fill` and `vectorized_mobject_stroke` shaders.
#' * `Window(renderer)` is the window of a live preview: an R graphics
#'   device (an interactive session is needed) that shows the renderer's frame
#'   on `swap_buffers()`; `handle_event()` waits for a mouse or key event
#'   in it and passes it to the scene's handlers, on devices that report
#'   events (X11 and Windows). Its size follows `config$window_size` and its position
#'   `config$window_position` on the monitor, which is
#'   `getOption("manimR.monitor")` (a list of `x`, `y`, `width` and `height`)
#'   or 1920 by 1080 pixels at the origin.
#'
#' @param renderer An `OpenGLRenderer`.
#' @param mobject An OpenGL VMobject.
#' @param model_matrix A 4 by 4 model matrix.
#' @param mobjects A list of OpenGL VMobjects.
#' @param file_writer_class Class of the scene's file writer.
#' @param skip_animations Whether animations are skipped.
#' @param window_size `"default"`, `"width,height"` or two integers.
#' @param monitor List of `x`, `y`, `width` and `height` of the monitor.
#' @param open Whether to open the window's graphics device.
#'
#' @param frame_shape Width and height of the frame; the config's frame
#'   size by default.
#' @param center_point Center of the frame.
#' @param euler_angles `theta`, `phi` and `gamma`, in radians.
#' @param focal_distance Focal distance, in frame heights.
#' @param light_source_position Position of the light.
#' @param orthographic Whether the projection is orthographic.
#' @param minimum_polar_angle,maximum_polar_angle Limits of `phi`.
#' @param model_matrix Initial model matrix.
#' @param ... For `OpenGLCamera()`, further arguments for [OpenGLMobject()];
#'   for `Object3D()`, child objects.
#' @param shader,material A `Shader`.
#' @param attributes For `Mesh()`, shader data (see [ShaderWrapper()]); for
#'   `filter_attributes()`, the names of the attributes to keep.
#' @param geometry A mesh whose attributes and indices are used.
#' @param indices Vertex indices, 0 based.
#' @param use_depth_test Whether the mesh is drawn with a depth test.
#' @param primitive moderngl primitive number (4 for triangles).
#' @param context A context, as `OpenGLSoftwareContext()`, kept with the shader.
#' @param name Name of a shader folder under `SHADER_FOLDER`.
#' @param source List of GLSL code.
#' @param fragment_shader_source,fragment_shader_name Code of the fragment
#'   shader, or the name of a `.frag` file under `SHADER_FOLDER`.
#' @param unfiltered_attributes Shader data.
#' @param mob An OpenGL mobject.
#' @param func A method, a function of `self` and further arguments.
#' @return `OpenGLCamera()`, `Object3D()`, `Mesh()`, `Shader()`,
#'   `FullScreenQuad()`, `OpenGLRenderer()`, `OpenGLSoftwareContext()` and
#'   `Window()` return R6 objects; the `render_*` functions return `NULL`
#'   invisibly; `filter_attributes()` and
#'   `triangulate_mobject()` shader data; `build_matrix_lists()` a list of
#'   mobject lists named by the 16 values of their matrix, row by row; the
#'   decorators a function.
#' @name opengl_renderer
#' @examples
#' cam <- OpenGLCamera()
#' cam$set_euler_angles(theta = PI / 4, phi = PI / 3)
#' round(cam$inverse_rotation_matrix, 3)
#' cam$get_position()
#' tri <- triangulate_mobject(OpenGLSquare())
#' length(tri)
#' s <- Shader(name = "surface")
#' names(s$shader_program)
#' \donttest{
#' r <- OpenGLRenderer()
#' scene <- Scene$new(renderer = r)
#' scene$add(OpenGLCircle()$set_fill(RED, 1))
#' r$update_frame(scene)
#' dim(r$get_raw_frame_buffer_object_data())
#' r$close_device()
#' }
NULL

#' @rdname opengl_renderer
#' @format NULL
#' @usage NULL
#' @export
SHADER_FOLDER <- NULL

#' @rdname opengl_renderer
#' @format NULL
#' @usage NULL
#' @export
shader_program_cache <- new.env(parent = emptyenv())

#' @rdname opengl_renderer
#' @format NULL
#' @usage NULL
#' @export
file_path_to_code_map <- new.env(parent = emptyenv())

#' @rdname opengl_renderer
#' @format NULL
#' @usage NULL
#' @export
filename_to_code_map <- new.env(parent = emptyenv())

# get_shader_code_from_file() of upstream's shader.py: the code of a file
# given by its path, with includes relative to the file's folder.
shader_file_code <- function(path) {
  key <- normalizePath(path, winslash = "/", mustWork = TRUE)
  if (!is.null(file_path_to_code_map[[key]])) return(file_path_to_code_map[[key]])
  source <- gsub("\r\n?", "\n", rawToChar(readBin(key, "raw", file.size(key))))
  for (line in regmatches(source, gregexpr("(?m)^#include .*\\.glsl$", source, perl = TRUE))[[1]]) {
    source <- gsub(line, shader_file_code(file.path(dirname(key), sub("^#include ", "", line))), source, fixed = TRUE)
  }
  assign(key, source, envir = file_path_to_code_map)
  source
}

opengl_needs_context <- function(what) {
  stop(what, " needs an OpenGL context; manimR draws with grid.", call. = FALSE)
}

#' @rdname opengl_renderer
#' @format NULL
#' @usage NULL
#' @export
OpenGLCameraClass <- R6::R6Class("OpenGLCamera", inherit = OpenGLMobjectClass, lock_objects = FALSE,
  public = list(
    use_z_index = TRUE,
    frame_rate = 60,
    orthographic = FALSE,
    minimum_polar_angle = -PI / 2,
    maximum_polar_angle = PI / 2,
    projection_matrix = NULL,
    unformatted_projection_matrix = NULL,
    frame_shape = NULL,
    center_point = NULL,
    focal_distance = 2,
    light_source_position = NULL,
    light_source = NULL,
    default_model_matrix = NULL,
    euler_angles = NULL,
    inverse_rotation_matrix = NULL,
    initialize = function(frame_shape = NULL, center_point = NULL, euler_angles = NULL, focal_distance = 2,
                          light_source_position = NULL, orthographic = FALSE, minimum_polar_angle = -PI / 2,
                          maximum_polar_angle = PI / 2, model_matrix = NULL, ...) {
      self$orthographic <- orthographic
      self$minimum_polar_angle <- minimum_polar_angle
      self$maximum_polar_angle <- maximum_polar_angle
      projection <- if (orthographic) orthographic_projection_matrix else perspective_projection_matrix
      self$projection_matrix <- projection()
      self$unformatted_projection_matrix <- projection(format_ = FALSE)
      self$frame_shape <- frame_shape %||% c(cfg("frame_width"), cfg("frame_height"))
      self$center_point <- if (is.null(center_point)) ORIGIN else as_point(center_point)
      model_matrix <- model_matrix %||% translation_matrix(0, 0, 11)
      self$focal_distance <- focal_distance
      self$light_source_position <- as.numeric(light_source_position %||% c(-10, 10, 10))
      self$light_source <- OpenGLPoint(self$light_source_position)
      self$default_model_matrix <- model_matrix
      super$initialize(model_matrix = model_matrix, should_render = FALSE, ...)
      self$init_points()
      self$euler_angles <- as.numeric(euler_angles %||% c(0, 0, 0))
      self$refresh_rotation_matrix()
    },
    get_position = function() self$model_matrix[1:3, 4],
    set_position = function(position) {
      self$model_matrix[1:3, 4] <- position
      invisible(self)
    },
    init_points = function() {
      self$set_points(rbind(ORIGIN, LEFT, RIGHT, DOWN, UP))
      self$stretch_to_fit_width(self$frame_shape[1])
      self$stretch_to_fit_height(self$frame_shape[2])
      self$move_to(self$center_point)
      invisible(self)
    },
    to_default_state = function() {
      self$center()
      self$set_height(cfg("frame_height"))
      self$set_width(cfg("frame_width"))
      self$set_euler_angles(0, 0, 0)
      self$model_matrix <- self$default_model_matrix
      invisible(self)
    },
    refresh_rotation_matrix = function() {
      a <- self$euler_angles
      quat <- quaternion_mult(quaternion_from_angle_axis(a[1], OUT, axis_normalized = TRUE),
                              quaternion_from_angle_axis(a[2], RIGHT, axis_normalized = TRUE),
                              quaternion_from_angle_axis(a[3], OUT, axis_normalized = TRUE))
      self$inverse_rotation_matrix <- do.call(rbind, rotation_matrix_transpose_from_quaternion(quat))
      invisible(self)
    },
    # The camera always turns about its own center.
    rotate = function(angle, axis = OUT, about_point = NULL, ...) {
      new_rot_t <- self$inverse_rotation_matrix %*% rotation_matrix_transpose(angle, axis)
      fz <- new_rot_t[3, ]
      phi <- acos(fz[3])
      theta <- angle_of_vector(fz[1:2]) + PI / 2
      partial_rot_t <- rotation_matrix_transpose(phi, RIGHT) %*% rotation_matrix_transpose(theta, OUT)
      gamma <- angle_of_vector((partial_rot_t %*% t(new_rot_t))[, 1])
      self$set_euler_angles(theta, phi, gamma)
    },
    set_euler_angles = function(theta = NULL, phi = NULL, gamma = NULL) {
      if (!is.null(theta)) self$euler_angles[1] <- theta
      if (!is.null(phi)) self$euler_angles[2] <- phi
      if (!is.null(gamma)) self$euler_angles[3] <- gamma
      self$refresh_rotation_matrix()
    },
    set_theta = function(theta) self$set_euler_angles(theta = theta),
    set_phi = function(phi) self$set_euler_angles(phi = phi),
    set_gamma = function(gamma) self$set_euler_angles(gamma = gamma),
    increment_theta = function(dtheta) {
      self$euler_angles[1] <- self$euler_angles[1] + dtheta
      self$refresh_rotation_matrix()
    },
    increment_phi = function(dphi) {
      self$euler_angles[2] <- min(max(self$euler_angles[2] + dphi, -PI / 2), PI / 2)
      self$refresh_rotation_matrix()
    },
    increment_gamma = function(dgamma) {
      self$euler_angles[3] <- self$euler_angles[3] + dgamma
      self$refresh_rotation_matrix()
    },
    set_zoom = function(zoom) self$scale(cfg("frame_height") / (zoom * self$get_height())),
    set_focal_distance = function(focal_distance) {
      warning("focal distance of OpenGLCamera can not be adjusted.", call. = FALSE)
      invisible(self)
    },
    get_shape = function() c(self$get_width(), self$get_height()),
    # The first point is the center.
    get_center = function() self$points[1, ],
    get_width = function() self$points[3, 1] - self$points[2, 1],
    get_height = function() self$points[5, 2] - self$points[4, 2],
    get_focal_distance = function() self$focal_distance * self$get_height(),
    # manimR's scenes ask their camera for these.
    get_frame_width = function() self$get_width(),
    get_frame_height = function() self$get_height(),
    get_frame_center = function() self$get_center(),
    interpolate = function(mobject1, mobject2, alpha, path_func = straight_path()) {
      super$interpolate(mobject1, mobject2, alpha, path_func)
      # The angles are not wrapped, so full turns asked for are animated.
      if (inherits(mobject1, "OpenGLCamera") && inherits(mobject2, "OpenGLCamera")) {
        self$euler_angles <- interpolate(mobject1$euler_angles, mobject2$euler_angles, alpha)
      }
      self$refresh_rotation_matrix()
    }
  ),
  active = list(
    # Upstream caches these on first use; manimR computes them each time.
    formatted_view_matrix = function() matrix_to_shader_input(self$unformatted_view_matrix),
    unformatted_view_matrix = function() solve(self$model_matrix),
    pixel_width = function() cfg("pixel_width"),
    pixel_height = function() cfg("pixel_height"),
    frame_center = function(value) {
      if (missing(value)) return(self$get_center())
      self$move_to(value)
    }
  )
)

#' @rdname opengl_renderer
#' @export
OpenGLCamera <- build_constructor(OpenGLCameraClass)

#' @rdname opengl_renderer
#' @format NULL
#' @usage NULL
#' @export
Object3DClass <- R6::R6Class("Object3D", lock_objects = FALSE,
  public = list(
    model_matrix = NULL,
    normal_matrix = NULL,
    children = NULL,
    parent = NULL,
    time_based_updaters = NULL,
    non_time_updaters = NULL,
    has_updaters = FALSE,
    updating_suspended = FALSE,
    initialize = function(...) {
      self$model_matrix <- diag(4)
      self$normal_matrix <- diag(4)
      self$children <- list()
      self$add(...)
      self$init_updaters()
    },
    interpolate = function(start, end, alpha, ...) {
      self$model_matrix <- (1 - alpha) * start$model_matrix + alpha * end$model_matrix
      self$normal_matrix <- (1 - alpha) * start$normal_matrix + alpha * end$normal_matrix
      invisible(self)
    },
    single_copy = function() {
      copy <- Object3DClass$new()
      copy$model_matrix <- self$model_matrix
      copy$normal_matrix <- self$normal_matrix
      copy
    },
    # Copies the tree below this object, breadth first.
    copy = function() {
      originals <- list()
      copies <- list()
      bfs <- list(self)
      while (length(bfs)) {
        node <- bfs[[1]]
        bfs <- c(bfs[-1], node$children)
        node_copy <- node$single_copy()
        originals[[length(originals) + 1]] <- node
        copies[[length(copies) + 1]] <- node_copy
        if (!is.null(node$parent) && !identical(node, self)) {
          k <- which(vapply(originals, identical, NA, node$parent))
          copies[[k]]$add(node_copy)
        }
      }
      copies[[1]]
    },
    add = function(...) {
      children <- list(...)
      for (child in children) {
        if (!is.null(child$parent)) stop("Attempt to add child that's already added to another Object3D", call. = FALSE)
      }
      do.call(self$remove, c(children, list(current_children_only = FALSE)))
      self$children <- c(self$children, children)
      for (child in children) child$parent <- self
      invisible(NULL)
    },
    remove = function(..., current_children_only = TRUE) {
      children <- list(...)
      if (current_children_only) {
        for (child in children) {
          if (!identical(child$parent, self)) {
            stop("Attempt to remove child that isn't added to this Object3D", call. = FALSE)
          }
        }
      }
      gone <- function(x) any(vapply(children, identical, NA, x))
      self$children <- Filter(Negate(gone), self$children)
      for (child in children) child$parent <- NULL
      invisible(NULL)
    },
    get_position = function() self$model_matrix[1:3, 4],
    set_position = function(position) {
      self$model_matrix[1:3, 4] <- position
      invisible(self)
    },
    # Depth first, last child first, as upstream's generators.
    get_family = function() {
      out <- list()
      dfs <- list(self)
      while (length(dfs)) {
        node <- dfs[[length(dfs)]]
        dfs <- c(dfs[-length(dfs)], node$children)
        out[[length(out) + 1]] <- node
      }
      out
    },
    get_meshes = function() Filter(function(node) inherits(node, "Mesh"), self$get_family()),
    align_data_and_family = function(...) invisible(NULL),
    hierarchical_model_matrix = function() {
      if (is.null(self$parent)) return(self$model_matrix)
      m <- self$model_matrix
      node <- self$parent
      while (!is.null(node)) {
        m <- node$model_matrix %*% m
        node <- node$parent
      }
      m
    },
    # As upstream, the parents contribute their model matrices.
    hierarchical_normal_matrix = function() {
      if (is.null(self$parent)) return(self$normal_matrix[1:3, 1:3])
      m <- self$normal_matrix
      node <- self$parent
      while (!is.null(node)) {
        m <- node$model_matrix %*% m
        node <- node$parent
      }
      m[1:3, 1:3]
    },
    init_updaters = function() {
      self$time_based_updaters <- list()
      self$non_time_updaters <- list()
      self$has_updaters <- FALSE
      self$updating_suspended <- FALSE
      invisible(NULL)
    },
    update = function(dt = 0) {
      if (!self$has_updaters || self$updating_suspended) return(invisible(self))
      for (f in self$time_based_updaters) f(self, dt)
      for (f in self$non_time_updaters) f(self)
      invisible(self)
    },
    get_time_based_updaters = function() self$time_based_updaters,
    has_time_based_updater = function() length(self$time_based_updaters) > 0,
    get_updaters = function() c(self$time_based_updaters, self$non_time_updaters),
    add_updater = function(update_function, index = NULL, call_updater = TRUE) {
      field <- if ("dt" %in% names(formals(update_function))) "time_based_updaters" else "non_time_updaters"
      current <- self[[field]]
      self[[field]] <- if (is.null(index)) c(current, list(update_function))
                       else append(current, list(update_function), after = index)
      self$refresh_has_updater_status()
      if (call_updater) self$update()
      invisible(self)
    },
    remove_updater = function(update_function) {
      keep <- function(f) !identical(f, update_function)
      self$time_based_updaters <- Filter(keep, self$time_based_updaters)
      self$non_time_updaters <- Filter(keep, self$non_time_updaters)
      self$refresh_has_updater_status()
    },
    clear_updaters = function() {
      self$time_based_updaters <- list()
      self$non_time_updaters <- list()
      self$refresh_has_updater_status()
    },
    match_updaters = function(mesh) {
      self$clear_updaters()
      for (f in mesh$get_updaters()) self$add_updater(f)
      invisible(self)
    },
    suspend_updating = function() {
      self$updating_suspended <- TRUE
      invisible(self)
    },
    resume_updating = function(call_updater = TRUE) {
      self$updating_suspended <- FALSE
      if (call_updater) self$update(dt = 0)
      invisible(self)
    },
    refresh_has_updater_status = function() {
      self$has_updaters <- length(self$get_updaters()) > 0
      invisible(self)
    }
  )
)

#' @rdname opengl_renderer
#' @export
Object3D <- build_constructor(Object3DClass)

#' @rdname opengl_renderer
#' @format NULL
#' @usage NULL
#' @export
MeshClass <- R6::R6Class("Mesh", inherit = Object3DClass, lock_objects = FALSE,
  public = list(
    shader = NULL,
    attributes = NULL,
    indices = NULL,
    use_depth_test = TRUE,
    primitive = 4L,
    skip_render = FALSE,
    initialize = function(shader = NULL, attributes = NULL, geometry = NULL, material = NULL, indices = NULL,
                          use_depth_test = TRUE, primitive = 4L) {
      super$initialize()
      if (!is.null(shader) && !is.null(attributes)) {
        self$shader <- shader
        self$attributes <- attributes
        self$indices <- indices
      } else if (!is.null(geometry) && !is.null(material)) {
        self$shader <- material
        self$attributes <- geometry$attributes
        self$indices <- geometry$indices
      } else {
        stop("Mesh requires either attributes and a Shader or a Geometry and a Material", call. = FALSE)
      }
      self$use_depth_test <- use_depth_test
      self$primitive <- primitive
      self$skip_render <- FALSE
      self$init_updaters()
    },
    single_copy = function() {
      copy <- MeshClass$new(attributes = filter_attributes(self$attributes, names(self$attributes)),
                            shader = self$shader, indices = self$indices,
                            use_depth_test = self$use_depth_test, primitive = self$primitive)
      copy$skip_render <- self$skip_render
      copy$model_matrix <- self$model_matrix
      copy$normal_matrix <- self$normal_matrix
      copy
    },
    set_uniforms = function(renderer) {
      self$shader$set_uniform("u_model_matrix", matrix_to_shader_input(self$model_matrix))
      self$shader$set_uniform("u_view_matrix", renderer$camera$formatted_view_matrix)
      self$shader$set_uniform("u_projection_matrix", renderer$camera$projection_matrix)
      invisible(NULL)
    },
    render = function() {
      if (self$skip_render) return(invisible(NULL))
      opengl_needs_context("Drawing a Mesh")
    }
  )
)

#' @rdname opengl_renderer
#' @export
Mesh <- build_constructor(MeshClass)

#' @rdname opengl_renderer
#' @format NULL
#' @usage NULL
#' @export
ShaderClass <- R6::R6Class("Shader", lock_objects = FALSE,
  public = list(
    context = NULL,
    name = NULL,
    source = NULL,
    shader_program = NULL,
    uniforms = NULL,
    initialize = function(context = NULL, name = NULL, source = NULL) {
      self$context <- context
      self$name <- name
      self$source <- source
      self$uniforms <- list()
      cached <- if (!is.null(name)) shader_program_cache[[name]]
      if (!is.null(cached) && identical(attr(cached, "context"), context)) {
        self$shader_program <- cached
      } else if (!is.null(source)) {
        self$shader_program <- source
      } else if (!is.null(name)) {
        keys <- c(vert = "vertex_shader", frag = "fragment_shader", geom = "geometry_shader")
        folder <- file.path(SHADER_FOLDER, name)
        program <- list()
        for (f in list.files(folder)) {
          program[[keys[[tools::file_path_sans_ext(f)]]]] <- shader_file_code(file.path(folder, f))
        }
        self$shader_program <- program
      } else {
        stop("Must either pass shader name or shader source.", call. = FALSE)
      }
      attr(self$shader_program, "context") <- context
      if (!is.null(name) && is.null(shader_program_cache[[name]])) {
        assign(name, self$shader_program, envir = shader_program_cache)
      }
    },
    # A uniform the code does not declare is ignored, as upstream.
    set_uniform = function(name, value) {
      pattern <- paste0("uniform\\s+\\w+\\s+", name, "\\b")
      if (any(grepl(pattern, unlist(self$shader_program), perl = TRUE))) self$uniforms[[name]] <- value
      invisible(NULL)
    }
  )
)

#' @rdname opengl_renderer
#' @export
Shader <- build_constructor(ShaderClass)

#' @rdname opengl_renderer
#' @format NULL
#' @usage NULL
#' @export
FullScreenQuadClass <- R6::R6Class("FullScreenQuad", inherit = MeshClass, lock_objects = FALSE,
  public = list(
    initialize = function(context = NULL, fragment_shader_source = NULL, fragment_shader_name = NULL) {
      if (is.null(fragment_shader_source) && is.null(fragment_shader_name)) {
        stop("Must either pass shader name or shader source.", call. = FALSE)
      }
      if (!is.null(fragment_shader_name)) {
        fragment_shader_source <- shader_file_code(file.path(SHADER_FOLDER, paste0(fragment_shader_name, ".frag")))
      } else {
        fragment_shader_source <- dedent(sub("^\\s+", "", fragment_shader_source))
      }
      # Upstream's vertex shader, with its doubled braces.
      vertex_shader <- paste(
        "", "                #version 330", "                in vec4 in_vert;",
        "                uniform mat4 u_model_view_matrix;", "                uniform mat4 u_projection_matrix;",
        "                void main() {{", "                    vec4 camera_space_vertex = u_model_view_matrix * in_vert;",
        "                    vec4 clip_space_vertex = u_projection_matrix * camera_space_vertex;",
        "                    gl_Position = clip_space_vertex;", "                }}", "                ", sep = "\n")
      shader <- Shader(context, source = list(vertex_shader = vertex_shader,
                                              fragment_shader = fragment_shader_source))
      x <- cfg("frame_width") / 2
      y <- cfg("frame_height") / 2
      attributes <- shader_data(c(in_vert = 4), 6)
      assign("in_vert", rbind(c(-x, -y, 0, 1), c(-x, y, 0, 1), c(x, y, 0, 1),
                              c(-x, -y, 0, 1), c(x, -y, 0, 1), c(x, y, 0, 1)), envir = attributes)
      shader$set_uniform("u_model_view_matrix", view_matrix())
      shader$set_uniform("u_projection_matrix", orthographic_projection_matrix())
      super$initialize(shader, attributes)
    },
    render = function() super$render()
  )
)

#' @rdname opengl_renderer
#' @export
FullScreenQuad <- build_constructor(FullScreenQuadClass)

# Python's textwrap.dedent(): removes the indent common to all lines that are
# not blank.
dedent <- function(text) {
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  full <- lines[grepl("\\S", lines)]
  if (!length(full)) return(text)
  indent <- min(nchar(sub("\\S.*$", "", full)))
  paste(ifelse(grepl("\\S", lines), substring(lines, indent + 1), sub("^[ \t]+$", "", lines)), collapse = "\n")
}

#' @rdname opengl_renderer
#' @export
filter_attributes <- function(unfiltered_attributes, attributes) {
  dtype <- attr(unfiltered_attributes, "dtype")
  keep <- dtype[names(dtype) %in% attributes]
  out <- shader_data(keep, length(unfiltered_attributes))
  for (name in names(keep)) assign(name, get(name, envir = unfiltered_attributes), envir = out)
  out
}

#' @rdname opengl_renderer
#' @export
build_matrix_lists <- function(mob) {
  out <- list()
  key <- function(m) paste(sprintf("%.17g", as.vector(t(m))), collapse = ",")
  put <- function(m, x) {
    k <- key(m)
    out[[k]] <<- c(out[[k]], list(x))
  }
  root <- mob$hierarchical_model_matrix()
  if (mob$has_points()) put(root, mob)
  matrices <- list(root)
  nodes <- list(mob)
  dfs <- list(mob)
  while (length(dfs)) {
    parent <- dfs[[length(dfs)]]
    dfs <- dfs[-length(dfs)]
    parent_matrix <- matrices[[which(vapply(nodes, identical, NA, parent))[1]]]
    for (child in parent$submobjects) {
      child_matrix <- parent_matrix %*% (child$model_matrix %||% diag(4))
      nodes[[length(nodes) + 1]] <- child
      matrices[[length(matrices) + 1]] <- child_matrix
      if (child$has_points()) put(child_matrix, child)
      dfs[[length(dfs) + 1]] <- child
    }
  }
  out
}

#' @rdname opengl_renderer
#' @export
triangulate_mobject <- function(mob) {
  # manimR's OpenGL mobjects do not flag point changes, so the triangulation
  # is computed on every call; upstream reuses it until the points change.
  points <- opengl_quadratic_points(mob)
  n <- nrow(points)
  dtype <- c(in_vert = 3, in_color = 4, texture_coords = 2, texture_mode = 1)
  if (n == 0) {
    mob$triangulation <- shader_data(dtype, 0)
    mob$needs_new_triangulation <- FALSE
    return(mob$triangulation)
  }
  i0 <- seq(1, n, by = 3)
  b0 <- points[i0, , drop = FALSE]
  b1 <- points[i0 + 1, , drop = FALSE]
  b2 <- points[i0 + 2, , drop = FALSE]
  convexities <- sign(cross2d(b1 - b0, b2 - b1))
  if ((mob$orientation %||% 1) == 1) {
    concave <- convexities > 0
  } else {
    concave <- convexities < 0
  }
  convex <- !concave
  atol <- mob$tolerance_for_point_equality %||% 1e-8
  k <- length(i0)
  end_of_loop <- logical(k)
  if (k > 1) end_of_loop[-k] <- apply(abs(b2[-k, , drop = FALSE] - b0[-1, , drop = FALSE]) > atol, 1, any)
  end_of_loop[k] <- TRUE
  indices <- seq_len(n) - 1L
  inner <- sort(c(indices[i0], indices[i0 + 1][concave], indices[i0 + 2][end_of_loop]))
  rings <- seq_along(inner)[inner %% 3 == 2]
  inner_tri <- inner[earclip_triangulation(points[inner + 1, , drop = FALSE], rings)]
  triangles <- matrix(indices, nrow = 3)
  concave_idx <- as.vector(triangles[, concave, drop = FALSE])
  convex_idx <- as.vector(triangles[, convex, drop = FALSE])
  verts <- points[c(concave_idx, convex_idx, inner_tri) + 1, , drop = FALSE]
  out <- shader_data(dtype, nrow(verts))
  assign("in_vert", verts, envir = out)
  assign("texture_coords", matrix(rep(c(0, 0, 0.5, 0, 1, 1), nrow(verts) %/% 3), ncol = 2, byrow = TRUE),
         envir = out)
  assign("texture_mode", matrix(c(rep(1, length(concave_idx)), rep(-1, length(convex_idx)),
                                  rep(0, length(inner_tri))), ncol = 1), envir = out)
  mob$triangulation <- out
  mob$needs_new_triangulation <- FALSE
  out
}

#' @rdname opengl_renderer
#' @export
affects_shader_info_id <- function(func) {
  function(self) {
    for (mob in self$get_family()) {
      func(mob)
      mob$refresh_shader_wrapper_id()
    }
    invisible(self)
  }
}

#' @rdname opengl_renderer
#' @export
triggers_refreshed_triangulation <- function(func) {
  function(self, ...) {
    all_points <- function() do.call(rbind, c(list(matrix(0, 0, 3)), lapply(self$family_members_with_points(),
                                                                           function(m) m$points)))
    old_points <- all_points()
    func(self, ...)
    new_points <- all_points()
    if (!identical(dim(new_points), dim(old_points)) || any(new_points != old_points)) {
      self$refresh_triangulation()
      self$refresh_unit_normal()
    }
    invisible(self)
  }
}
