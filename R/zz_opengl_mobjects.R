# Mobject classes of upstream's OpenGL renderer (manim/mobject/opengl/).
# manimR draws everything with grid, so each one is a subclass of its Cairo
# counterpart with the same arguments; OpenGLSurfaceMesh and
# OpenGLTexturedSurface, which have no counterpart, are ported here.

#' OpenGL mobject classes
#'
#' Upstream's OpenGL renderer has its own mobject classes, such as
#' `OpenGLCircle` or `OpenGLVGroup`. manimR draws every mobject with grid, so
#' each of them is a subclass of its Cairo counterpart that takes the same
#' arguments: `OpenGLCircle()` is a [Circle()] and `inherits(x,
#' "OpenGLCircle")` is `TRUE`. Code written for the OpenGL renderer runs
#' unchanged; the GPU pipeline itself (shaders, the OpenGL camera and window)
#' is not part of manimR.
#'
#' Two classes have no Cairo counterpart:
#'
#' * `OpenGLSurfaceMesh(uv_surface)` is a [VGroup()] of curves along the
#'   grid lines of a surface (`resolution` lines in each direction, 21 by
#'   default), lifted `normal_nudge` along the surface normal so they show
#'   on top of it.
#' * `OpenGLTexturedSurface(uv_surface, image_file)` is a copy of a surface
#'   whose faces take the color of the image at their center: `u` runs
#'   along the image from left to right and `v` from bottom to top, as
#'   upstream's texture coordinates. Upstream's shader shows
#'   `dark_image_file` on the side facing away from the light; manimR keeps
#'   it in `dark_image` but draws the light image on both sides.
#'
#' `get_mobject_class()`, `get_vectorized_mobject_class()` and
#' `get_point_mobject_class()` return the base classes for the active
#' renderer, as upstream's `manim.mobject.utils`; with manimR's renderer
#' they are [MobjectClass], [VMobjectClass] and [PMobjectClass].
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
#' @name opengl_mobjects
#' @aliases OpenGLMobject OpenGLGroup OpenGLPoint OpenGLVMobject OpenGLVGroup OpenGLVectorizedPoint
#' @aliases OpenGLCurvesAsSubmobjects OpenGLDashedVMobject OpenGLTipableVMobject OpenGLArc
#' @aliases OpenGLArcBetweenPoints OpenGLCurvedArrow OpenGLCurvedDoubleArrow OpenGLCircle OpenGLDot
#' @aliases OpenGLEllipse OpenGLAnnularSector OpenGLSector OpenGLAnnulus OpenGLLine OpenGLDashedLine
#' @aliases OpenGLTangentLine OpenGLElbow OpenGLArrow OpenGLVector OpenGLDoubleArrow OpenGLCubicBezier
#' @aliases OpenGLPolygon OpenGLRegularPolygon OpenGLTriangle OpenGLArrowTip OpenGLImageMobject
#' @aliases OpenGLSurface OpenGLSurfaceMesh OpenGLTexturedSurface
#' @aliases OpenGLMobjectClass OpenGLGroupClass OpenGLPointClass OpenGLVMobjectClass OpenGLVGroupClass
#' @aliases OpenGLVectorizedPointClass OpenGLCurvesAsSubmobjectsClass OpenGLDashedVMobjectClass
#' @aliases OpenGLTipableVMobjectClass OpenGLArcClass OpenGLArcBetweenPointsClass OpenGLCurvedArrowClass
#' @aliases OpenGLCurvedDoubleArrowClass OpenGLCircleClass OpenGLDotClass OpenGLEllipseClass
#' @aliases OpenGLAnnularSectorClass OpenGLSectorClass OpenGLAnnulusClass OpenGLLineClass
#' @aliases OpenGLDashedLineClass OpenGLTangentLineClass OpenGLElbowClass OpenGLArrowClass
#' @aliases OpenGLVectorClass OpenGLDoubleArrowClass OpenGLCubicBezierClass OpenGLPolygonClass
#' @aliases OpenGLRegularPolygonClass OpenGLTriangleClass OpenGLArrowTipClass OpenGLImageMobjectClass
#' @aliases OpenGLSurfaceClass OpenGLSurfaceMeshClass OpenGLTexturedSurfaceClass
#' @aliases get_mobject_class get_vectorized_mobject_class get_point_mobject_class
#' @usage NULL
#' @format NULL
#' @rawNamespace export(OpenGLMobject, OpenGLGroup, OpenGLPoint, OpenGLVMobject, OpenGLVGroup)
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
#' @rawNamespace export(get_mobject_class, get_vectorized_mobject_class, get_point_mobject_class)
#' @examples
#' c1 <- OpenGLCircle(radius = 2)
#' inherits(c1, "Circle")
#' s <- OpenGLSurface(function(u, v) c(u, v, u * v), u_range = c(-1, 1), v_range = c(-1, 1),
#'                    resolution = 8)
#' mesh <- OpenGLSurfaceMesh(s, resolution = c(5, 5))
#' length(mesh$submobjects)
#' img <- matrix(c("red", "blue", "green", "white"), 2, 2)
#' tex <- OpenGLTexturedSurface(s, img)
NULL

# Class name and Cairo counterpart.
OPENGL_MOBJECT_CLASSES <- c(
  OpenGLMobject = "Mobject", OpenGLGroup = "Group", OpenGLPoint = "Point", OpenGLVMobject = "VMobject",
  OpenGLVGroup = "VGroup", OpenGLVectorizedPoint = "VectorizedPoint",
  OpenGLCurvesAsSubmobjects = "CurvesAsSubmobjects", OpenGLDashedVMobject = "DashedVMobject",
  OpenGLTipableVMobject = "TipableVMobject", OpenGLArc = "Arc", OpenGLArcBetweenPoints = "ArcBetweenPoints",
  OpenGLCurvedArrow = "CurvedArrow", OpenGLCurvedDoubleArrow = "CurvedDoubleArrow", OpenGLCircle = "Circle",
  OpenGLDot = "Dot", OpenGLEllipse = "Ellipse", OpenGLAnnularSector = "AnnularSector",
  OpenGLSector = "Sector", OpenGLAnnulus = "Annulus", OpenGLLine = "Line", OpenGLDashedLine = "DashedLine",
  OpenGLTangentLine = "TangentLine", OpenGLElbow = "Elbow", OpenGLArrow = "Arrow", OpenGLVector = "Vector",
  OpenGLDoubleArrow = "DoubleArrow", OpenGLCubicBezier = "CubicBezier", OpenGLPolygon = "Polygon",
  OpenGLRegularPolygon = "RegularPolygon", OpenGLTriangle = "Triangle", OpenGLArrowTip = "ArrowTip",
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
      super$initialize(func = uv_surface$uv_func, u_range = uv_surface$u_range, v_range = uv_surface$v_range,
                       resolution = uv_surface$resolution, ...)
      # The faces take the surface's current shape, then the image's colors.
      for (k in seq_along(self$list_of_faces)) {
        if (k <= length(uv_surface$list_of_faces)) {
          self$list_of_faces[[k]]$points <- uv_surface$list_of_faces[[k]]$points
        }
      }
      self$apply_texture()
      invisible(self)
    },
    # Fills each face with the image's color at the face's center: u from
    # left to right, v from the bottom of the image to its top.
    apply_texture = function() {
      img <- self$image
      ih <- dim(img)[1]
      iw <- dim(img)[2]
      ur <- self$u_range
      vr <- self$v_range
      for (f in self$list_of_faces) {
        un <- ((f$u1 + f$u2) / 2 - ur[1]) / (ur[2] - ur[1])
        vn <- ((f$v1 + f$v2) / 2 - vr[1]) / (vr[2] - vr[1])
        rgba <- sample_image(img, min(max(un, 0), 1) * iw, min(max(1 - vn, 0), 1) * ih, "bilinear")
        f$set_fill(color = grDevices::rgb(rgba[1], rgba[2], rgba[3], maxColorValue = 255),
                   opacity = rgba[4] / 255 * (self$fill_opacity %||% 1))
      }
      invisible(self)
    }
  )
)

OpenGLSurfaceMesh <- build_constructor(OpenGLSurfaceMeshClass)
OpenGLTexturedSurface <- build_constructor(OpenGLTexturedSurfaceClass)

get_mobject_class <- function() MobjectClass
get_vectorized_mobject_class <- function() VMobjectClass
get_point_mobject_class <- function() PMobjectClass
