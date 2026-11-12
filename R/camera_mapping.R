# Mapping and multi cameras. Ported from manim/camera/mapping_camera.py.

#' @title MappingCamera, OldMultiCamera and SplitScreenCamera
#' @description `MappingCameraClass` draws every point through
#'   `mapping_func` (curves are subdivided first so the image bends smoothly).
#'   `OldMultiCameraClass` composites several cameras at pixel offsets, and
#'   `SplitScreenCameraClass` puts two cameras side by side. Use them through
#'   a scene's `default_camera_class()` or `Scene$new(camera_class = ...)`.
#' @param mapping_func Function of a point returning a point.
#' @param min_num_curves Minimum number of curves per VMobject before mapping.
#' @param allow_object_intrusion Map the scene's mobjects in place instead of copies.
#' @param ... Passed to [CameraClass].
#' @export
MappingCameraClass <- R6::R6Class("MappingCamera", inherit = CameraClass, lock_objects = FALSE,
  public = list(
    mapping_func = NULL,
    min_num_curves = 50,
    allow_object_intrusion = FALSE,
    initialize = function(mapping_func = function(p) p, min_num_curves = 50, allow_object_intrusion = FALSE, ...) {
      self$mapping_func <- mapping_func
      self$min_num_curves <- min_num_curves
      self$allow_object_intrusion <- allow_object_intrusion
      super$initialize(...)
    },
    project_points = function(points, mobject = NULL) {
      if (nrow(points) == 0) return(points[, 1:2, drop = FALSE])
      mapped <- apply_rowwise(points, self$mapping_func)
      mapped[, 1:2, drop = FALSE]
    },
    draw_frame = function(mobjects, include_submobjects = TRUE, excluded_mobjects = NULL,
                                background_raster = NULL) {
      mobs <- self$get_mobjects_to_display(mobjects, include_submobjects, excluded_mobjects)
      copies <- if (self$allow_object_intrusion) mobs else lapply(mobs, function(m) {
        cp <- m$copy()
        cp$submobjects <- list()
        cp
      })
      for (m in copies) {
        if (is_vmobject(m)) {
          n <- m$get_num_curves()
          if (n > 0 && n < self$min_num_curves) m$insert_n_curves(self$min_num_curves)
        }
      }
      super$draw_frame(copies, include_submobjects = FALSE, excluded_mobjects = NULL,
                             background_raster = background_raster)
    }
  )
)

#' @rdname MappingCameraClass
#' @param cameras_with_start_positions Lists of `list(camera, c(start_y, start_x))` in pixels.
#' @format NULL
#' @usage NULL
#' @export
OldMultiCameraClass <- R6::R6Class("OldMultiCamera", inherit = CameraClass, lock_objects = FALSE,
  public = list(
    shifted_cameras = NULL,
    initialize = function(..., cameras_with_start_positions = NULL) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      cams <- c(cameras_with_start_positions, args[nm == ""])
      self$shifted_cameras <- lapply(cams, function(cs) {
        cam <- cs[[1]]
        pos <- cs[[2]]
        list(camera = cam, start_x = pos[2], start_y = pos[1])
      })
      do.call(super$initialize, args[nm != ""])
    },
    draw_frame = function(mobjects, include_submobjects = TRUE, excluded_mobjects = NULL,
                                background_raster = NULL) {
      if (!is.null(background_raster)) {
        grid::grid.raster(background_raster, width = grid::unit(1, "npc"), height = grid::unit(1, "npc"),
                          interpolate = FALSE)
      } else {
        self$draw_background()
      }
      for (sc in self$shifted_cameras) {
        cam <- sc$camera
        vp <- grid::viewport(x = grid::unit(sc$start_x / self$pixel_width, "npc"),
                             y = grid::unit(1 - sc$start_y / self$pixel_height, "npc"),
                             width = grid::unit(cam$pixel_width / self$pixel_width, "npc"),
                             height = grid::unit(cam$pixel_height / self$pixel_height, "npc"),
                             just = c("left", "top"), clip = "on")
        grid::pushViewport(vp)
        cam$draw_frame(mobjects, include_submobjects = include_submobjects,
                             excluded_mobjects = excluded_mobjects)
        grid::popViewport()
      }
      invisible(self)
    }
  )
)

#' @rdname MappingCameraClass
#' @param left_camera,right_camera Cameras for each half.
#' @format NULL
#' @usage NULL
#' @export
SplitScreenCameraClass <- R6::R6Class("SplitScreenCamera", inherit = OldMultiCameraClass, lock_objects = FALSE,
  public = list(
    left_camera = NULL,
    right_camera = NULL,
    initialize = function(left_camera, right_camera, ...) {
      tmp <- CameraClass$new(...)
      half <- ceiling(tmp$pixel_width / 2)
      # Camera.reset_pixel_shape keeps the frame width and adapts the height.
      for (cam in list(left_camera, right_camera)) {
        fw <- cam$get_frame_width()
        cam$pixel_width <- half
        new_h <- fw * cam$pixel_height / half
        if (!is.null(cam$frame) && is_mobject(cam$frame)) cam$frame$stretch_to_fit_height(new_h)
        else cam$frame_height <- new_h
      }
      self$left_camera <- left_camera
      self$right_camera <- right_camera
      super$initialize(list(left_camera, c(0, 0)), list(right_camera, c(0, half)), ...)
    }
  )
)
