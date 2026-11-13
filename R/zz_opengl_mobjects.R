# Mobject classes of upstream's OpenGL renderer (manim/mobject/opengl/).
# manimR draws everything with grid, so most are a subclass of their Cairo
# counterpart; OpenGLSurfaceMesh,
# OpenGLTexturedSurface, the arrow tip and the filled arrows, which differ
# from any Cairo class, are ported here.

#' OpenGL mobject classes
#'
#' Upstream's OpenGL renderer has its own mobject classes, such as
#' `OpenGLCircle` or `OpenGLVGroup`. manimR draws every mobject with grid, so
#' each of them is a subclass of its Cairo counterpart: `OpenGLCircle()` is
#' a [Circle()] and `inherits(x,
#' "OpenGLCircle")` is `TRUE`. Code written for the OpenGL renderer runs
#' unchanged. The classes also have the methods of upstream's OpenGL
#' mobjects, such as `fix_in_frame()`, `set_gloss()`, `get_shader_data()`,
#' `get_triangulation()` and `get_shader_wrapper_list()`: they compute the
#' data upstream's renderer sends to the GPU (see [ShaderWrapper()]), from
#' manimR's cubic curves, which they split into upstream's quadratic ones.
#' manimR draws with grid and has no OpenGL window; the CPU side of upstream's
#' renderer (its camera, meshes and shaders) is in [opengl_renderer].
#'
#' Where upstream's OpenGL class differs from its Cairo counterpart, manimR
#' follows the OpenGL class:
#'
#' * `OpenGLArrowTip()` is an `OpenGLTriangle` pointing right.
#' * `OpenGLArrow()`, `OpenGLVector()` and `OpenGLDoubleArrow()` are filled
#'   shapes (a stem `thickness` wide and a head, grey by default) and
#'   subclasses of `OpenGLLine`, not of [Arrow()].
#' * `OpenGLLine()`, `OpenGLDashedLine()` and `OpenGLTangentLine()` apply
#'   `buff` twice, as upstream: `OpenGLLine(2 * LEFT, 2 * RIGHT, buff = 0.5)`
#'   runs from -1 to 1.
#' * `OpenGLArc(start_angle, angle, radius, n_components, arc_center)`,
#'   `OpenGLCircle(color)`, `OpenGLSector(outer_radius, inner_radius)`,
#'   `OpenGLRectangle(color, width, height)`,
#'   `OpenGLRegularPolygon(n, start_angle)`,
#'   `OpenGLCubicBezier(a0, h0, h1, a1)` and
#'   `OpenGLPoint(location, artificial_width, artificial_height)` take
#'   upstream's arguments in upstream's order.
#' * Arcs, circles, dots, ellipses, sectors and annuli are made of
#'   `n_components` quadratic pieces (8 by default), as upstream, stored as
#'   cubic curves.
#' * `add_tip(at_start, ...)` of OpenGL lines and arcs adds an
#'   `OpenGLArrowTip()` made from the `tip_config` of the line and the
#'   arguments given (white unless they say otherwise).
#'   `OpenGLCurvedArrow()` and `OpenGLCurvedDoubleArrow()` are
#'   `OpenGLArcBetweenPoints` with such tips, not [CurvedArrow()]s.
#' * `OpenGLDashedVMobject(vmobject, num_dashes, dashed_ratio, color)` spaces
#'   its dashes by the curve's parameter rather than by arc length.
#' * `OpenGLSurface(uv_func, u_range, v_range, resolution, axes, color,
#'   colorscale, colorscale_axis, opacity, gloss, shadow, ...)` takes
#'   upstream's arguments: `resolution` counts grid points, one more than
#'   the faces along `u` and `v`, and the surface is one `color`
#'   (grey) without outlines, and `colorscale` with `axes` colors it by value
#'   along `colorscale_axis` (0 for x, as upstream). The default
#'   `resolution` is 33 points (32 faces, as [Surface()]) rather than
#'   upstream's 101: manimR draws each face with grid, not on a GPU.
#' * `OpenGLImageMobject(filename_or_array, width, height, ...)` is 4 units
#'   high unless `width` or `height` is given.
#' * `OpenGLMobject(color, opacity, dim, gloss, shadow, ...)` and
#'   `OpenGLVMobject(fill_color, fill_opacity, stroke_color, stroke_opacity,
#'   stroke_width, draw_stroke_behind_fill, ...)` take upstream's arguments
#'   in upstream's order; `n_points_per_curve` is taken but not used, since
#'   manimR's curves are cubic.
#'
#' Three classes have no Cairo counterpart:
#'
#' * `OpenGLSurfaceGroup(...)` is a surface without faces of its own that
#'   holds the surfaces it is given.
#' * `OpenGLSurfaceMesh(uv_surface)` is a [VGroup()] of curves along the
#'   grid lines of a surface (`resolution` lines in each direction, 21 by
#'   default), lifted `normal_nudge` along the surface normal so they show
#'   on top of it.
#' * `OpenGLTexturedSurface(uv_surface, image_file)` is a copy of a surface
#'   whose faces take the color of the image at their center: `u` runs
#'   along the image from left to right and `v` from bottom to top, as
#'   upstream's texture coordinates. Upstream's shader shows
#'   `dark_image_file` on the side facing away from the light, which is at
#'   (-10, 10, 10) in the camera's frame; each face is blended from its two
#'   colors when the camera draws it, as upstream's shader does.
#'
#' @param uv_surface A [Surface()].
#' @param resolution Number of mesh lines along `u` and `v`.
#' @param stroke_width Width of the mesh lines.
#' @param normal_nudge Distance the mesh is moved along the surface normal.
#' @param depth_test,flat_stroke,shader_folder Settings of upstream's
#'   shaders, kept but not used.
#' @param image_file Image file (looked up with
#'   [get_full_raster_image_path()]) or array for the texture.
#' @param dark_image_file Image for the dark side, stored in `dark_image`.
#' @param image_mode Mode the image is converted to, as in [ImageMobject()].
#' @param ... Further arguments for [VGroup()] or [Surface()].
#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @name opengl_mobjects
#' @aliases OpenGLMobject OpenGLGroup OpenGLPoint OpenGLVMobject OpenGLVGroup OpenGLVectorizedPoint
#' @aliases OpenGLCurvesAsSubmobjects OpenGLDashedVMobject OpenGLTipableVMobject OpenGLArc
#' @aliases OpenGLArcBetweenPoints OpenGLCurvedArrow OpenGLCurvedDoubleArrow OpenGLCircle OpenGLDot
#' @aliases OpenGLEllipse OpenGLAnnularSector OpenGLSector OpenGLAnnulus OpenGLLine OpenGLDashedLine
#' @aliases OpenGLTangentLine OpenGLElbow OpenGLArrow OpenGLVector OpenGLDoubleArrow OpenGLCubicBezier
#' @aliases OpenGLPolygon OpenGLRegularPolygon OpenGLTriangle OpenGLArrowTip OpenGLImageMobject
#' @aliases OpenGLSurface OpenGLSurfaceMesh OpenGLTexturedSurface OpenGLSurfaceGroup
#' @aliases OpenGLRectangle OpenGLSquare OpenGLRoundedRectangle
#' @aliases OpenGLRectangleClass OpenGLSquareClass OpenGLRoundedRectangleClass OpenGLSurfaceGroupClass
#' @aliases OpenGLMobjectClass OpenGLGroupClass OpenGLPointClass OpenGLVMobjectClass OpenGLVGroupClass
#' @aliases OpenGLVectorizedPointClass OpenGLCurvesAsSubmobjectsClass OpenGLDashedVMobjectClass
#' @aliases OpenGLTipableVMobjectClass OpenGLArcClass OpenGLArcBetweenPointsClass OpenGLCurvedArrowClass
#' @aliases OpenGLCurvedDoubleArrowClass OpenGLCircleClass OpenGLDotClass OpenGLEllipseClass
#' @aliases OpenGLAnnularSectorClass OpenGLSectorClass OpenGLAnnulusClass OpenGLLineClass
#' @aliases OpenGLDashedLineClass OpenGLTangentLineClass OpenGLElbowClass OpenGLArrowClass
#' @aliases OpenGLVectorClass OpenGLDoubleArrowClass OpenGLCubicBezierClass OpenGLPolygonClass
#' @aliases OpenGLRegularPolygonClass OpenGLTriangleClass OpenGLArrowTipClass OpenGLImageMobjectClass
#' @aliases OpenGLSurfaceClass OpenGLSurfaceMeshClass OpenGLTexturedSurfaceClass
#' @usage NULL
#' @format NULL
#' @rawNamespace export(OpenGLMobject, OpenGLGroup, OpenGLPoint, OpenGLVMobject, OpenGLVGroup)
#' @rawNamespace export(OpenGLRectangle, OpenGLSquare, OpenGLRoundedRectangle, OpenGLSurfaceGroup)
#' @rawNamespace export(OpenGLRectangleClass, OpenGLSquareClass, OpenGLRoundedRectangleClass)
#' @rawNamespace export(OpenGLSurfaceGroupClass)
#' @rawNamespace export(OpenGLVectorizedPoint, OpenGLCurvesAsSubmobjects, OpenGLDashedVMobject)
#' @rawNamespace export(OpenGLTipableVMobject, OpenGLArc, OpenGLArcBetweenPoints, OpenGLCurvedArrow)
#' @rawNamespace export(OpenGLCurvedDoubleArrow, OpenGLCircle, OpenGLDot, OpenGLEllipse, OpenGLAnnularSector)
#' @rawNamespace export(OpenGLSector, OpenGLAnnulus, OpenGLLine, OpenGLDashedLine, OpenGLTangentLine)
#' @rawNamespace export(OpenGLElbow, OpenGLArrow, OpenGLVector, OpenGLDoubleArrow, OpenGLCubicBezier)
#' @rawNamespace export(OpenGLPolygon, OpenGLRegularPolygon, OpenGLTriangle, OpenGLArrowTip)
#' @rawNamespace export(OpenGLImageMobject, OpenGLSurface, OpenGLSurfaceMesh, OpenGLTexturedSurface)
#' @rawNamespace export(OpenGLMobjectClass, OpenGLGroupClass, OpenGLPointClass, OpenGLVMobjectClass)
#' @rawNamespace export(OpenGLVGroupClass, OpenGLVectorizedPointClass, OpenGLCurvesAsSubmobjectsClass)
#' @rawNamespace export(OpenGLDashedVMobjectClass, OpenGLTipableVMobjectClass, OpenGLArcClass)
#' @rawNamespace export(OpenGLArcBetweenPointsClass, OpenGLCurvedArrowClass, OpenGLCurvedDoubleArrowClass)
#' @rawNamespace export(OpenGLCircleClass, OpenGLDotClass, OpenGLEllipseClass, OpenGLAnnularSectorClass)
#' @rawNamespace export(OpenGLSectorClass, OpenGLAnnulusClass, OpenGLLineClass, OpenGLDashedLineClass)
#' @rawNamespace export(OpenGLTangentLineClass, OpenGLElbowClass, OpenGLArrowClass, OpenGLVectorClass)
#' @rawNamespace export(OpenGLDoubleArrowClass, OpenGLCubicBezierClass, OpenGLPolygonClass)
#' @rawNamespace export(OpenGLRegularPolygonClass, OpenGLTriangleClass, OpenGLArrowTipClass)
#' @rawNamespace export(OpenGLImageMobjectClass, OpenGLSurfaceClass, OpenGLSurfaceMeshClass)
#' @rawNamespace export(OpenGLTexturedSurfaceClass)
#' @examples
#' c1 <- OpenGLCircle(radius = 2)
#' inherits(c1, "Circle")
#' s <- OpenGLSurface(function(u, v) c(u, v, u * v), u_range = c(-1, 1), v_range = c(-1, 1),
#'                    resolution = 9)
#' mesh <- OpenGLSurfaceMesh(s, resolution = c(5, 5))
#' length(mesh$submobjects)
#' img <- matrix(c("red", "blue", "green", "white"), 2, 2)
#' tex <- OpenGLTexturedSurface(s, img)
NULL

# Class name and parent: its Cairo counterpart, or an OpenGL class defined
# earlier when the Cairo class is a factory that upstream's OpenGL class is not.
OPENGL_MOBJECT_CLASSES <- c(
  OpenGLMobject = "Mobject", OpenGLGroup = "Group", OpenGLPoint = "Point", OpenGLVMobject = "VMobject",
  OpenGLVGroup = "VGroup", OpenGLVectorizedPoint = "VectorizedPoint",
  OpenGLCurvesAsSubmobjects = "CurvesAsSubmobjects", OpenGLDashedVMobject = "DashedVMobject",
  OpenGLTipableVMobject = "TipableVMobject", OpenGLArc = "Arc", OpenGLArcBetweenPoints = "ArcBetweenPoints",
  OpenGLCurvedArrow = "OpenGLArcBetweenPoints", OpenGLCurvedDoubleArrow = "OpenGLCurvedArrow", OpenGLCircle = "Circle",
  OpenGLDot = "Dot", OpenGLEllipse = "Ellipse", OpenGLAnnularSector = "AnnularSector",
  OpenGLSector = "Sector", OpenGLAnnulus = "Annulus", OpenGLLine = "Line", OpenGLDashedLine = "DashedLine",
  OpenGLTangentLine = "TangentLine", OpenGLElbow = "Elbow", OpenGLCubicBezier = "CubicBezier", OpenGLPolygon = "Polygon",
  OpenGLRegularPolygon = "RegularPolygon", OpenGLTriangle = "Triangle",
  OpenGLRectangle = "Rectangle", OpenGLSquare = "Square", OpenGLRoundedRectangle = "RoundedRectangle",
  OpenGLImageMobject = "ImageMobject", OpenGLSurface = "Surface"
)

# R6 looks up `inherit` when an object is made, so each class gets its own
# function environment holding its parent.
opengl_subclass <- function(name, parent) R6::R6Class(name, inherit = parent, lock_objects = FALSE)

local({
  ns <- topenv()
  for (name in names(OPENGL_MOBJECT_CLASSES)) {
    gen <- opengl_subclass(name, get(paste0(OPENGL_MOBJECT_CLASSES[[name]], "Class"), envir = ns))
    assign(paste0(name, "Class"), gen, envir = ns)
    assign(name, build_constructor(gen), envir = ns)
  }
})

# The grid of a surface's face corners, nu + 1 by nv + 1 points, from its
# faces as they are now (so it follows the surface's transformations).
surface_corner_grid <- function(surface) {
  faces <- surface$list_of_faces
  if (!length(faces)) stop("The surface has no faces.", call. = FALSE)
  nu <- max(vapply(faces, function(f) f$u_index, 0)) + 1
  nv <- max(vapply(faces, function(f) f$v_index, 0)) + 1
  grid <- array(NA_real_, c(nu + 1, nv + 1, 3))
  for (f in faces) {
    i <- f$u_index + 1
    j <- f$v_index + 1
    p <- f$points
    grid[i, j, ] <- p[1, ]
    grid[i + 1, j, ] <- p[5, ]
    grid[i + 1, j + 1, ] <- p[9, ]
    grid[i, j + 1, ] <- p[13, ]
  }
  grid
}

OpenGLSurfaceMeshClass <- R6::R6Class("OpenGLSurfaceMesh", inherit = VGroupClass, lock_objects = FALSE,
  public = list(
    uv_surface = NULL,
    resolution = NULL,
    normal_nudge = NULL,
    depth_test = TRUE,
    flat_stroke = FALSE,
    initialize = function(uv_surface, resolution = NULL, stroke_width = 1, normal_nudge = 1e-2, depth_test = TRUE,
                          flat_stroke = FALSE, ...) {
      if (!inherits(uv_surface, "Surface")) stop("uv_surface must be a Surface (or OpenGLSurface).", call. = FALSE)
      self$uv_surface <- uv_surface
      self$resolution <- rep_len(resolution %||% c(21, 21), 2)
      self$normal_nudge <- normal_nudge
      self$depth_test <- depth_test
      self$flat_stroke <- flat_stroke
      super$initialize(...)
      grid <- surface_corner_grid(uv_surface)
      gu <- dim(grid)[1]
      gv <- dim(grid)[2]
      # Unit normals from differences along u and v (one sided at the edges).
      normals <- array(0, dim(grid))
      for (i in seq_len(gu)) {
        for (j in seq_len(gv)) {
          du <- grid[min(i + 1, gu), j, ] - grid[max(i - 1, 1), j, ]
          dv <- grid[i, min(j + 1, gv), ] - grid[i, max(j - 1, 1), ]
          n <- c(du[2] * dv[3] - du[3] * dv[2], du[3] * dv[1] - du[1] * dv[3], du[1] * dv[2] - du[2] * dv[1])
          len <- sqrt(sum(n^2))
          if (len > 0) normals[i, j, ] <- n / len
        }
      }
      nudged <- grid + normal_nudge * normals
      u_lines <- unique(round(seq(1, gu, length.out = self$resolution[1])))
      v_lines <- unique(round(seq(1, gv, length.out = self$resolution[2])))
      for (i in u_lines) {
        path <- VMobject()
        path$set_points_smoothly(matrix(nudged[i, , ], ncol = 3))
        self$add(path)
      }
      for (j in v_lines) {
        path <- VMobject()
        path$set_points_smoothly(matrix(nudged[, j, ], ncol = 3))
        self$add(path)
      }
      self$set_stroke(width = stroke_width)
      invisible(self)
    }
  )
)

OpenGLTexturedSurfaceClass <- R6::R6Class("OpenGLTexturedSurface", inherit = OpenGLSurfaceClass,
  lock_objects = FALSE,
  public = list(
    uv_surface = NULL,
    image = NULL,
    dark_image = NULL,
    num_textures = 1,
    initialize = function(uv_surface, image_file, dark_image_file = NULL, image_mode = "RGBA",
                          shader_folder = NULL, ...) {
      if (!inherits(uv_surface, "Surface")) stop("uv_surface must be a Surface (or OpenGLSurface).", call. = FALSE)
      texture <- function(x) {
        m <- if (is.character(x) && is.null(dim(x))) ImageMobject(x, image_mode = image_mode) else ImageMobject(x)
        m$pixel_array
      }
      self$uv_surface <- uv_surface
      self$image <- texture(image_file)
      if (!is.null(dark_image_file)) {
        self$dark_image <- texture(dark_image_file)
        self$num_textures <- 2
      }
      # A surface's resolution field counts faces; OpenGLSurface() takes points.
      super$initialize(uv_surface$uv_func, u_range = uv_surface$u_range, v_range = uv_surface$v_range,
                       resolution = uv_surface$resolution + 1, gloss = uv_surface$gloss %||% 0.3,
                       shadow = uv_surface$shadow %||% 0.4, ...)
      # The faces take the surface's current shape, then the image's colors.
      for (k in seq_along(self$list_of_faces)) {
        if (k <= length(uv_surface$list_of_faces)) {
          self$list_of_faces[[k]]$points <- uv_surface$list_of_faces[[k]]$points
        }
      }
      # The opacity is the surface's, as upstream's init_colors() takes it.
      self$opacity <- matrix(uv_surface$get_fill_opacity() %||% 1, ncol = 1)
      self$apply_texture()
      invisible(self)
    },
    # Fills each face with the image's color at the face's center: u from
    # left to right, v from the bottom of the image to its top. The opacity
    # is the surface's, as upstream's shader ignores the image's alpha. With a
    # dark image each face keeps both colors, and the camera blends them
    # when it draws the face (opengl_texture_shade()).
    apply_texture = function() {
      ur <- self$u_range
      vr <- self$v_range
      at <- function(img, un, vn) {
        sample_image(img, min(max(un, 0), 1) * dim(img)[2], min(max(1 - vn, 0), 1) * dim(img)[1], "bilinear")
      }
      for (f in self$list_of_faces) {
        un <- ((f$u1 + f$u2) / 2 - ur[1]) / (ur[2] - ur[1])
        vn <- ((f$v1 + f$v2) / 2 - vr[1]) / (vr[2] - vr[1])
        f$texture_rgbas <- rbind(at(self$image, un, vn), if (!is.null(self$dark_image)) at(self$dark_image, un, vn))
        opengl_texture_shade(f)
        f$set_fill(opacity = if (length(self$opacity)) self$opacity[1] else 1)
      }
      invisible(self)
    }
  )
)

OpenGLSurfaceMesh <- build_constructor(OpenGLSurfaceMeshClass)

# The color of a textured face, as upstream's textured_surface shader gives
# it: with a dark image, dp is the cosine between the face's normal and the
# direction to the light at (-10, 10, 10) in the camera's frame, and the
# dark color shows where dp is below 0, blended with smoothstep over 0.2 on
# either side. Without a camera the frame is upstream's default one.
opengl_texture_shade <- function(face, camera = NULL) {
  rgbas <- face$texture_rgbas
  rgba <- rgbas[1, ]
  if (nrow(rgbas) > 1) {
    p <- face$points
    rot <- if (!is.null(camera) && is.function(camera$get_rotation_matrix)) camera$get_rotation_matrix() else diag(3)
    center <- if (is.null(camera)) ORIGIN else camera$get_frame_center()
    # The face's normal from its diagonals: u x v on a regular face, and not
    # zero on a face with a pole corner. Upstream's shader turns the normal
    # of the pole vertex itself around (its fallback in
    # get_rotated_surface_unit_normal_vector.glsl), so its interpolated
    # normal nearly cancels across such a face.
    normal <- drop(rot %*% cross(p[9, ] - p[1, ], p[13, ] - p[5, ]))
    xyz <- drop(rot %*% (face$get_center() - center))
    dp <- if (get_norm(normal) > 0) sum(normalize(c(-10, 10, 10) - xyz) * normal) / get_norm(normal) else 1
    t <- min(max((dp + 0.2) / 0.4, 0), 1)
    a <- t * t * (3 - 2 * t)
    rgba <- rgbas[2, ] * (1 - a) + rgbas[1, ] * a
  }
  face$set_fill(color = grDevices::rgb(rgba[1], rgba[2], rgba[3], maxColorValue = 255))
  invisible(face)
}

# A surface with no faces of its own that groups other surfaces.
OpenGLSurfaceGroupClass <- R6::R6Class("OpenGLSurfaceGroup", inherit = OpenGLSurfaceClass, lock_objects = FALSE,
  public = list(
    initialize = function(..., resolution = NULL) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      do.call(super$initialize, c(list(uv_func = NULL, resolution = c(1, 1)), args[nm != ""]))
      self$resolution <- resolution %||% c(0, 0)
      self$add(args[nm == ""])
    }
  )
)
OpenGLSurfaceGroup <- build_constructor(OpenGLSurfaceGroupClass)
OpenGLTexturedSurface <- build_constructor(OpenGLTexturedSurfaceClass)

# Upstream's OpenGLArrowTip is a triangle pointing right, its tip the first
# point; `angle` is accepted and not used, as upstream.
OpenGLArrowTipClass <- R6::R6Class("OpenGLArrowTip", inherit = OpenGLTriangleClass, lock_objects = FALSE,
  public = list(
    initialize = function(fill_opacity = 1, fill_color = WHITE, stroke_width = 0, width = DEFAULT_ARROW_TIP_WIDTH,
                          length = DEFAULT_ARROW_TIP_LENGTH, angle = 0, ...) {
      super$initialize(start_angle = 0, fill_opacity = fill_opacity, fill_color = fill_color,
                       stroke_width = stroke_width, ...)
      self$stretch_to_fit_width(width)
      self$stretch_to_fit_height(length)
      invisible(self)
    },
    get_base = function() self$point_from_proportion(0.5),
    get_tip_point = function() self$points[1, ],
    get_vector = function() self$get_tip_point() - self$get_base(),
    get_angle = function() angle_of_vector(self$get_vector()),
    get_length = function() sqrt(sum(self$get_vector()^2))
  )
)
OpenGLArrowTip <- build_constructor(OpenGLArrowTipClass)

# Upstream's OpenGLArrow is a filled shape, its stem `thickness` wide and its
# head `tip_width_ratio` times that, drawn as one closed curve with the tip at
# point `tip_index`. As upstream, `buff` is applied only by
# set_start_and_end_attrs(), and scale() rebuilds the shape around its ends.
OpenGLArrowClass <- R6::R6Class("OpenGLArrow", inherit = OpenGLLineClass, lock_objects = FALSE,
  public = list(
    thickness = 0.05,
    tip_width_ratio = 5,
    tip_angle = PI / 3,
    max_tip_length_to_length_ratio = 0.5,
    max_width_to_length_ratio = 0.1,
    tip_index = NULL,
    initialize = function(start = LEFT, end = RIGHT, path_arc = 0, fill_color = GREY_A, fill_opacity = 1,
                          stroke_width = 0, buff = MED_SMALL_BUFF, thickness = 0.05, tip_width_ratio = 5,
                          tip_angle = PI / 3, max_tip_length_to_length_ratio = 0.5,
                          max_width_to_length_ratio = 0.1, ...) {
      self$thickness <- thickness
      self$tip_width_ratio <- tip_width_ratio
      self$tip_angle <- tip_angle
      self$max_tip_length_to_length_ratio <- max_tip_length_to_length_ratio
      self$max_width_to_length_ratio <- max_width_to_length_ratio
      super$initialize(start = start, end = end, buff = buff, path_arc = path_arc, fill_color = fill_color,
                       fill_opacity = fill_opacity, stroke_width = stroke_width, ...)
    },
    set_points_by_ends = function(start, end, buff = 0, path_arc = 0) {
      start <- as_point(start)
      vect <- as_point(end) - start
      len <- max(sqrt(sum(vect^2)), 1e-8)
      thickness <- self$thickness
      w_ratio <- self$max_width_to_length_ratio / (thickness / len)
      if (w_ratio < 1) thickness <- thickness * w_ratio
      tip_width <- self$tip_width_ratio * thickness
      tip_length <- tip_width / (2 * tan(self$tip_angle / 2))
      t_ratio <- self$max_tip_length_to_length_ratio / (tip_length / len)
      if (t_ratio < 1) {
        tip_length <- tip_length * t_ratio
        tip_width <- tip_width * t_ratio
      }
      if (path_arc == 0) {
        points1 <- (len - tip_length) * rbind(RIGHT, 0.5 * RIGHT, ORIGIN)
        points1 <- sweep(points1, 2, thickness * UP / 2, "+")
        points2 <- sweep(points1[3:1, , drop = FALSE], 2, thickness * DOWN, "+")
      } else {
        # The radius for which the tip to tail length is |end - start|.
        a <- 2 * (1 - cos(path_arc))
        b <- -2 * tip_length * sin(path_arc)
        cc <- tip_length^2 - len^2
        R <- (-b + sqrt(b^2 - 4 * a * cc)) / (2 * a)
        points1 <- opengl_quadratic_arc_points(path_arc)
        points2 <- points1[rev(seq_len(nrow(points1))), , drop = FALSE]
        points1 <- points1 * (R + thickness / 2)
        points2 <- points2 * (R - thickness / 2)
        if (path_arc < 0) tip_length <- -tip_length
        rot_t <- rotation_matrix_transpose(PI / 2 - path_arc, OUT)
        points1 <- sweep(points1 %*% rot_t, 2, R * DOWN, "+")
        points2 <- sweep(points2 %*% rot_t, 2, R * DOWN, "+")
      }
      # Upstream's add_line_to(): one straight quadratic piece.
      line_to <- function(q, p) {
        e <- q[nrow(q), ]
        rbind(q, e, e + 0.5 * (p - e), p)
      }
      q <- line_to(points1, tip_width * UP / 2)
      q <- line_to(q, tip_length * LEFT)
      tip_curve <- nrow(q) / 3
      q <- line_to(q, tip_width * DOWN / 2)
      q <- line_to(q, points2[1, ])
      q <- rbind(q, points2)
      q <- line_to(q, points1[1, ])
      self$set_points(opengl_cubic_from_quadratic(unname(q)))
      self$tip_index <- 4 * tip_curve
      super$scale(len / self$get_length())
      self$rotate(angle_of_vector(vect) - self$get_angle())
      tilt <- PI / 2 - acos(normalize(vect)[3])
      if (tilt != 0) self$rotate(tilt, axis = rotate_vector(self$get_unit_vector(), -PI / 2))
      self$shift(start - self$get_start())
      invisible(self)
    },
    reset_points_around_ends = function() {
      self$set_points_by_ends(self$get_start(), self$get_end(), path_arc = self$path_arc)
      invisible(self)
    },
    get_start = function() {
      n <- nrow(self$points)
      (self$points[1, ] + self$points[n - 3, ]) / 2
    },
    get_end = function() self$points[self$tip_index, ],
    get_length = function() sqrt(sum((self$get_end() - self$get_start())^2)),
    put_start_and_end_on = function(start, end) {
      self$set_points_by_ends(start, end, buff = 0, path_arc = self$path_arc)
      invisible(self)
    },
    scale = function(...) {
      super$scale(...)
      self$reset_points_around_ends()
      invisible(self)
    },
    set_thickness = function(thickness) {
      self$thickness <- thickness
      self$reset_points_around_ends()
      invisible(self)
    },
    set_path_arc = function(path_arc) {
      self$path_arc <- path_arc
      self$reset_points_around_ends()
      invisible(self)
    },
    # Upstream's OpenGLTipableVMobject.add_tip(), with an OpenGLArrowTip
    # placed along the first handle (at the start) or the last.
    add_tip = function(at_start = FALSE, ...) {
      tip <- OpenGLArrowTip(...)
      # Upstream's handles are those of its quadratic pieces.
      n <- nrow(self$points)
      if (at_start) {
        anchor <- self$get_start()
        handle <- self$points[1, ] + 1.5 * (self$points[2, ] - self$points[1, ])
      } else {
        anchor <- self$get_end()
        handle <- self$points[n, ] + 1.5 * (self$points[n - 1, ] - self$points[n, ])
      }
      tip$rotate(angle_of_vector(handle - anchor) - PI - tip$get_angle())
      tip$shift(anchor - tip$get_tip_point())
      if (self$get_length() != 0) {
        if (at_start) self$put_start_and_end_on(tip$get_base(), self$get_end())
        else self$put_start_and_end_on(self$get_start(), tip$get_base())
      }
      if (at_start) self$start_tip <- tip else self$tip <- tip
      self$add(tip)
      invisible(self)
    }
  )
)
OpenGLArrow <- build_constructor(OpenGLArrowClass)

OpenGLVectorClass <- R6::R6Class("OpenGLVector", inherit = OpenGLArrowClass, lock_objects = FALSE,
  public = list(
    initialize = function(direction = RIGHT, buff = 0, ...) {
      self$buff <- buff
      super$initialize(ORIGIN, as_point(direction), buff = buff, ...)
    }
  )
)
OpenGLVector <- build_constructor(OpenGLVectorClass)

OpenGLDoubleArrowClass <- R6::R6Class("OpenGLDoubleArrow", inherit = OpenGLArrowClass, lock_objects = FALSE,
  public = list(
    initialize = function(...) {
      super$initialize(...)
      self$add_tip(at_start = TRUE)
    }
  )
)
OpenGLDoubleArrow <- build_constructor(OpenGLDoubleArrowClass)

# Names of the members of an R6 class generator and of its ancestors.
r6_member_names <- function(gen) {
  out <- character()
  while (!is.null(gen)) {
    out <- c(out, names(gen$public_methods), names(gen$public_fields), names(gen$active))
    gen <- gen$get_inherit()
  }
  unique(out)
}

r6_inherits <- function(gen, classname) {
  while (!is.null(gen)) {
    if (identical(gen$classname, classname)) return(TRUE)
    gen <- gen$get_inherit()
  }
  FALSE
}

# Member lists merged in order, later lists replacing earlier entries.
opengl_merge <- function(specs) {
  merged <- list(public = list(), active = list(), private = list())
  for (spec in specs) {
    for (type in names(merged)) merged[[type]][names(spec[[type]])] <- spec[[type]]
  }
  merged
}

# Adds the members of upstream's OpenGL classes (zz_opengl_methods.R) to a
# generator. `ancestry` lists the member lists of its upstream ancestors,
# root first; a member is added only when the class and its Cairo parents
# have none of that name. `signatures` (upstream's OpenGL arguments) replace
# inherited methods but not the class's own, and `own` lists the class's own
# members, which replace everything.
opengl_add_members <- function(gen, ancestry = list(), signatures = list(), own = NULL) {
  have <- r6_member_names(gen)
  defined <- c(names(gen$public_methods), names(gen$public_fields), names(gen$active))
  add <- function(merged, keep) {
    for (type in names(merged)) {
      for (name in names(merged[[type]])) {
        if (type == "private" || !name %in% keep) gen$set(type, name, merged[[type]][[name]], overwrite = TRUE)
      }
    }
  }
  add(opengl_merge(ancestry), have)
  add(opengl_merge(signatures), defined)
  add(opengl_merge(list(own)), character())
  invisible(gen)
}

local({
  ns <- topenv()
  vmobject <- list(OPENGL_MOBJECT_METHODS, OPENGL_VMOBJECT_METHODS)
  vmobject_signatures <- list(OPENGL_MOBJECT_SIGNATURES, OPENGL_VMOBJECT_SIGNATURES)
  for (name in names(OPENGL_MOBJECT_CLASSES)) {
    gen <- get(paste0(name, "Class"), envir = ns)
    # manimR's surfaces are VMobjects; upstream's OpenGLSurface is not.
    is_vmobject <- r6_inherits(gen, "VMobject") && name != "OpenGLSurface"
    ancestry <- if (name == "OpenGLSurface") list(OPENGL_MOBJECT_METHODS, OPENGL_SURFACE_METHODS)
                else if (is_vmobject) vmobject
                else list(OPENGL_MOBJECT_METHODS)
    signatures <- if (is_vmobject) vmobject_signatures else list(OPENGL_MOBJECT_SIGNATURES)
    own <- OPENGL_CLASS_METHODS[[name]]
    if (name %in% OPENGL_LINE_CLASSES) own <- list(public = c(OPENGL_LINE_METHODS$public, own$public))
    if (name %in% OPENGL_ARC_CLASSES) own <- list(public = c(OPENGL_ARC_POINTS$public, own$public))
    if (name %in% OPENGL_TIPABLE_CLASSES) own <- list(public = c(OPENGL_TIPABLE_METHODS$public, own$public))
    opengl_add_members(gen, ancestry, signatures, own)
    # A constructor takes the arguments of its initializer when it is built.
    if (!is.null(own$public$initialize)) assign(name, build_constructor(gen), envir = ns)
  }
  opengl_add_members(OpenGLSurfaceMeshClass, vmobject, vmobject_signatures)
  opengl_add_members(OpenGLTexturedSurfaceClass, own = OPENGL_TEXTURED_SURFACE_METHODS)
  opengl_add_members(OpenGLPMobjectClass, list(OPENGL_MOBJECT_METHODS), list(OPENGL_MOBJECT_SIGNATURES),
                     OPENGL_PMOBJECT_METHODS)
})

#' Base classes for the active renderer
#'
#' `get_mobject_class()`, `get_vectorized_mobject_class()` and
#' `get_point_mobject_class()` return the base classes for the active
#' renderer, as upstream's `manim.mobject.utils`; with manimR's renderer
#' they are [MobjectClass], [VMobjectClass] and [PMobjectClass].
#'
#' @return An R6 class generator.
#' @export
#' @examples
#' get_mobject_class()$classname
#' get_vectorized_mobject_class()$classname
#' get_point_mobject_class()$classname
get_mobject_class <- function() MobjectClass

#' @rdname get_mobject_class
#' @export
get_vectorized_mobject_class <- function() VMobjectClass

#' @rdname get_mobject_class
#' @export
get_point_mobject_class <- function() PMobjectClass
