# Moving, multi and zoomed cameras. Ported from manim/camera/moving_camera.py,
# manim/camera/multi_camera.py, manim/scene/moving_camera_scene.py and
# manim/scene/zoomed_scene.py.

#' @title MovingCamera
#' @description A camera that follows and matches the size and position of its
#'   `frame`, a rectangle mobject. Move, scale or animate the frame to pan and
#'   zoom: `self$play(self$camera$frame$animate$scale(0.5)$move_to(dot))`.
#' @param frame Mobject defining the visible region; by default a rectangle
#'   the size of the camera frame.
#' @param fixed_dimension Kept for compatibility with Manim.
#' @param default_frame_stroke_color,default_frame_stroke_width Style of the
#'   default frame, which is invisible by default.
#' @param ... Passed to [CameraClass].
#' @format NULL
#' @usage NULL
#' @export
MovingCameraClass <- R6::R6Class("MovingCamera", inherit = CameraClass, lock_objects = FALSE,
  public = list(
    frame = NULL,
    fixed_dimension = 0,
    default_frame_stroke_color = WHITE,
    default_frame_stroke_width = 0,
    initialize = function(frame = NULL, fixed_dimension = 0, default_frame_stroke_color = WHITE,
                          default_frame_stroke_width = 0, ...) {
      self$fixed_dimension <- fixed_dimension
      self$default_frame_stroke_color <- default_frame_stroke_color
      self$default_frame_stroke_width <- default_frame_stroke_width
      super$initialize(...)
      if (is.null(frame)) {
        frame <- Rectangle(width = self$frame_width, height = self$frame_height)
        frame$set_stroke(default_frame_stroke_color, default_frame_stroke_width)
        frame$move_to(self$frame_center)
      }
      self$frame <- frame
    },
    get_frame_width = function() self$frame$width,
    get_frame_height = function() self$frame$height,
    get_frame_center = function() self$frame$get_center(),
    set_frame_width = function(frame_width) {
      self$frame$stretch_to_fit_width(frame_width)
      invisible(self)
    },
    set_frame_height = function(frame_height) {
      self$frame$stretch_to_fit_height(frame_height)
      invisible(self)
    },
    set_frame_center = function(frame_center) {
      self$frame$move_to(frame_center)
      invisible(self)
    },
    # Mobjects whose movement means every mobject on screen moves.
    get_mobjects_indicating_movement = function() list(self$frame),
    is_in_frame = function(mobject) {
      fc <- self$get_frame_center()
      fh <- self$get_frame_height()
      fw <- self$get_frame_width()
      !(mobject$get_right()[1] < fc[1] - fw / 2 || mobject$get_bottom()[2] > fc[2] + fh / 2 ||
          mobject$get_left()[1] > fc[1] + fw / 2 || mobject$get_top()[2] < fc[2] - fh / 2)
    },
    # Zoom to fit mobjects. Returns an animation builder, or with
    # `animate = FALSE` moves the frame and returns it.
    auto_zoom = function(mobjects, margin = 0, only_mobjects_in_frame = FALSE, animate = TRUE) {
      bb <- self$get_bounding_box(mobjects, only_mobjects_in_frame)
      x <- (bb[1] + bb[2]) / 2
      y <- (bb[3] + bb[4]) / 2
      new_width <- abs(bb[1] - bb[2])
      new_height <- abs(bb[3] - bb[4])
      m_target <- if (animate) self$frame$animate else self$frame
      if (new_width / self$frame$width > new_height / self$frame$height) {
        m_target$set_x(x)$set_y(y)$set(width = new_width + margin)
      } else {
        m_target$set_x(x)$set_y(y)$set(height = new_height + margin)
      }
    },
    # Bounding box c(left, right, up, down) of the mobjects; a single
    # mobject counts as itself plus its submobjects, as iterating it does upstream.
    get_bounding_box = function(mobjects, only_mobjects_in_frame = FALSE) {
      mobs <- if (is_mobject(mobjects)) mobjects$split() else flatten_mobjects(list(mobjects))
      bb <- NULL
      for (m in mobs) {
        if (identical(m$mob_id, self$frame$mob_id) || (only_mobjects_in_frame && !self$is_in_frame(m))) next
        cur <- c(m$get_critical_point(LEFT)[1], m$get_critical_point(RIGHT)[1],
                 m$get_critical_point(UP)[2], m$get_critical_point(DOWN)[2])
        bb <- if (is.null(bb)) cur else c(min(bb[1], cur[1]), max(bb[2], cur[2]), max(bb[3], cur[3]), min(bb[4], cur[4]))
      }
      if (is.null(bb)) stop("Could not determine bounding box of the mobjects given to 'auto_zoom'.", call. = FALSE)
      bb
    }
  )
)

#' @rdname MovingCameraClass
#' @export
MovingCamera <- constructor(MovingCameraClass)
#' @title MovingCameraScene
#' @description A [Scene] whose camera is a [MovingCameraClass]. Animate
#'   `self$camera$frame` to pan and zoom.
#' @format NULL
#' @usage NULL
#' @export
#' @examples
#' \dontrun{
#' Zoom <- R6::R6Class("Zoom", inherit = MovingCameraScene, public = list(
#'   construct = function() {
#'     dot <- Dot(2 * RIGHT)
#'     self$add(Square(), dot)
#'     self$camera$frame$save_state()
#'     self$play(self$camera$frame$animate$scale(0.5)$move_to(dot))
#'     self$play(Restore(self$camera$frame))
#'   }))
#' render(Zoom, quality = "l")
#' }
MovingCameraScene <- R6::R6Class("MovingCameraScene", inherit = Scene, lock_objects = FALSE,
  public = list(
    default_camera_class = function() MovingCameraClass,
    get_moving_mobjects = function(animations) {
      moving <- super$get_moving_mobjects(animations)
      ids <- vapply(extract_mobject_family_members(moving), function(m) m$mob_id, "")
      for (ind in self$camera$get_mobjects_indicating_movement()) {
        # When one of these moves, everything on screen moves.
        if (ind$mob_id %in% ids) return(list_update(self$mobjects, moving))
      }
      moving
    }
  )
)

#' @title MultiCamera
#' @description A [MovingCameraClass] that also draws the views of other
#'   cameras into [ImageMobjectFromCamera()] mobjects. Each view is drawn as
#'   vector graphics clipped to the display rectangle, so it stays sharp.
#' @param image_mobjects_from_cameras List of [ImageMobjectFromCamera()]
#'   mobjects whose cameras' views are drawn.
#' @param allow_cameras_to_capture_their_own_display Let each camera's view
#'   include its own display mobject.
#' @param ... Passed to [MovingCameraClass].
#' @format NULL
#' @usage NULL
#' @export
MultiCameraClass <- R6::R6Class("MultiCamera", inherit = MovingCameraClass, lock_objects = FALSE,
  public = list(
    image_mobjects_from_cameras = NULL,
    allow_cameras_to_capture_their_own_display = FALSE,
    captured_mobjects = NULL,
    initialize = function(image_mobjects_from_cameras = NULL, allow_cameras_to_capture_their_own_display = FALSE, ...) {
      self$image_mobjects_from_cameras <- list()
      for (imfc in image_mobjects_from_cameras) self$add_image_mobject_from_camera(imfc)
      self$allow_cameras_to_capture_their_own_display <- allow_cameras_to_capture_their_own_display
      super$initialize(...)
    },
    add_image_mobject_from_camera = function(image_mobject_from_camera) {
      if (!inherits(image_mobject_from_camera$camera, "MovingCamera")) {
        stop("ImageMobjectFromCamera needs a MovingCamera.", call. = FALSE)
      }
      self$image_mobjects_from_cameras <- c(self$image_mobjects_from_cameras, list(image_mobject_from_camera))
      invisible(self)
    },
    # Give each sub camera the pixel size of its display on screen.
    update_sub_cameras = function() {
      # Edge lengths rather than upstream's bounding box, so strokes in a
      # rotated display keep their width.
      for (imfc in self$image_mobjects_from_cameras) {
        p <- imfc$points
        imfc$camera$pixel_height <- max(1L, as.integer(self$pixel_height * get_norm(p[3, ] - p[1, ]) /
                                                         self$get_frame_height()))
        imfc$camera$pixel_width <- max(1L, as.integer(self$pixel_width * get_norm(p[2, ] - p[1, ]) /
                                                        self$get_frame_width()))
      }
      invisible(self)
    },
    draw_frame = function(mobjects, ...) {
      self$update_sub_cameras()
      self$captured_mobjects <- mobjects
      on.exit(self$captured_mobjects <- NULL, add = TRUE)
      super$draw_frame(mobjects, ...)
    },
    display_mobject = function(m) {
      if (inherits(m, "ImageMobjectFromCamera") &&
          any(vapply(self$image_mobjects_from_cameras, function(i) identical(i$mob_id, m$mob_id), logical(1)))) {
        return(self$display_camera_image(m))
      }
      super$display_mobject(m)
    },
    # Draw what `imfc$camera` sees into the rectangle of `imfc`.
    display_camera_image = function(imfc) {
      cam <- imfc$camera
      # Placed like display_image_mobject (and upstream): center, edge lengths
      # and the angle of the top edge come from the corners UL, UR, DL, so a
      # rotated display stays rotated. As upstream, a mirrored display is
      # drawn rotated, not mirrored.
      corners <- self$project_points(imfc$points, imfc)
      ul <- corners[1, ]
      ur <- corners[2, ]
      dl <- corners[3, ]
      w <- get_norm(ur - ul)
      h <- get_norm(dl - ul)
      if (w <= 0 || h <= 0) return(invisible(self))
      angle <- atan2(ur[2] - ul[2], ur[1] - ul[1]) * 180 / pi
      center <- (ur + dl) / 2
      fw <- cam$get_frame_width()
      fh <- cam$get_frame_height()
      fc <- cam$get_frame_center()
      grid::pushViewport(grid::viewport(x = grid::unit(center[1], "native"), y = grid::unit(center[2], "native"),
                                        width = grid::unit(w, "native"), height = grid::unit(h, "native"),
                                        angle = angle, xscale = fc[1] + c(-fw, fw) / 2, yscale = fc[2] + c(-fh, fh) / 2,
                                        # grid does not clip rotated viewports; a clipping path does.
                                        clip = if (angle == 0) "on" else grid::rectGrob()))
      on.exit(grid::popViewport(), add = TRUE)
      cam$draw_background()
      mobs <- self$captured_mobjects %||% list()
      if (!self$allow_cameras_to_capture_their_own_display) {
        own <- vapply(imfc$get_family(), function(x) x$mob_id, "")
        mobs <- Filter(function(x) !x$mob_id %in% own, extract_mobject_family_members(mobs))
      }
      for (x in cam$get_mobjects_to_display(mobs)) cam$display_mobject(x)
      invisible(self)
    },
    get_mobjects_indicating_movement = function() {
      c(list(self$frame), lapply(self$image_mobjects_from_cameras, function(i) i$camera$frame))
    }
  )
)

#' @rdname MultiCameraClass
#' @export
MultiCamera <- constructor(MultiCameraClass)
#' @title ZoomedScene
#' @description A [MovingCameraScene] with a second camera whose view is shown
#'   in a display in a corner of the screen. Call `activate_zooming()` to show
#'   the zoomed camera frame and its display, then move `self$zoomed_camera$frame`.
#'   The display is drawn as vector graphics clipped to the display
#'   rectangle rather than as a pixel copy of the zoomed camera.
#' @details Initializer arguments (override `initialize()` in a subclass to
#'   change them): `zoomed_display_height`, `zoomed_display_width`,
#'   `zoomed_display_center` (overrides the corner), `zoomed_display_corner`,
#'   `zoomed_display_corner_buff`, `zoomed_camera_config` (list of
#'   [MovingCameraClass] arguments), `zoomed_camera_image_mobject_config`,
#'   `zoomed_camera_frame_starting_position`, `zoom_factor` (zoomed frame size
#'   over display size, 0.15), `image_frame_stroke_width` and `zoom_activated`.
#' @format NULL
#' @usage NULL
#' @export
#' @examples
#' \dontrun{
#' UseZoomedScene <- R6::R6Class("UseZoomedScene", inherit = ZoomedScene, public = list(
#'   construct = function() {
#'     dot <- Dot()$set_color(GREEN)
#'     self$add(dot)
#'     self$wait(1)
#'     self$activate_zooming(animate = FALSE)
#'     self$wait(1)
#'     self$play(dot$animate$shift(LEFT))
#'   }))
#' render(UseZoomedScene, quality = "l")
#' }
ZoomedScene <- R6::R6Class("ZoomedScene", inherit = MovingCameraScene, lock_objects = FALSE,
  public = list(
    zoomed_display_height = 3,
    zoomed_display_width = 3,
    zoomed_display_center = NULL,
    zoomed_display_corner = NULL,
    zoomed_display_corner_buff = DEFAULT_MOBJECT_TO_EDGE_BUFFER,
    zoomed_camera_config = NULL,
    zoomed_camera_image_mobject_config = NULL,
    zoomed_camera_frame_starting_position = NULL,
    zoom_factor = 0.15,
    image_frame_stroke_width = 3,
    zoom_activated = FALSE,
    zoomed_camera = NULL,
    zoomed_display = NULL,
    initialize = function(zoomed_display_height = 3, zoomed_display_width = 3, zoomed_display_center = NULL,
                          zoomed_display_corner = UP + RIGHT, zoomed_display_corner_buff = DEFAULT_MOBJECT_TO_EDGE_BUFFER,
                          zoomed_camera_config = list(default_frame_stroke_width = 2, background_opacity = 1),
                          zoomed_camera_image_mobject_config = list(), zoomed_camera_frame_starting_position = ORIGIN,
                          zoom_factor = 0.15, image_frame_stroke_width = 3, zoom_activated = FALSE, ...) {
      self$zoomed_display_height <- zoomed_display_height
      self$zoomed_display_width <- zoomed_display_width
      self$zoomed_display_center <- zoomed_display_center
      self$zoomed_display_corner <- zoomed_display_corner
      self$zoomed_display_corner_buff <- zoomed_display_corner_buff
      self$zoomed_camera_config <- zoomed_camera_config
      self$zoomed_camera_image_mobject_config <- zoomed_camera_image_mobject_config
      self$zoomed_camera_frame_starting_position <- zoomed_camera_frame_starting_position
      self$zoom_factor <- zoom_factor
      self$image_frame_stroke_width <- image_frame_stroke_width
      self$zoom_activated <- zoom_activated
      super$initialize(...)
    },
    default_camera_class = function() MultiCameraClass,
    setup = function() {
      super$setup()
      zoomed_camera <- do.call(MovingCameraClass$new, self$zoomed_camera_config)
      zoomed_display <- do.call(ImageMobjectFromCameraClass$new,
                                c(list(zoomed_camera), self$zoomed_camera_image_mobject_config))
      zoomed_display$add_display_frame()
      for (mob in list(zoomed_camera$frame, zoomed_display)) {
        mob$stretch_to_fit_height(self$zoomed_display_height)
        mob$stretch_to_fit_width(self$zoomed_display_width)
      }
      zoomed_camera$frame$scale(self$zoom_factor)
      zoomed_camera$frame$move_to(self$zoomed_camera_frame_starting_position)
      if (!is.null(self$zoomed_display_center)) {
        zoomed_display$move_to(self$zoomed_display_center)
      } else {
        zoomed_display$to_corner(self$zoomed_display_corner, buff = self$zoomed_display_corner_buff)
      }
      self$zoomed_camera <- zoomed_camera
      self$zoomed_display <- zoomed_display
      invisible(self)
    },
    activate_zooming = function(animate = FALSE) {
      self$zoom_activated <- TRUE
      self$camera$add_image_mobject_from_camera(self$zoomed_display)
      if (animate) {
        self$play(self$get_zoom_in_animation())
        self$play(self$get_zoomed_display_pop_out_animation())
      }
      self$add_foreground_mobjects(self$zoomed_camera$frame, self$zoomed_display)
      invisible(self)
    },
    get_zoom_in_animation = function(run_time = 2, ...) {
      frame <- self$zoomed_camera$frame
      frame$save_state()
      frame$stretch_to_fit_width(self$camera$get_frame_width())
      frame$stretch_to_fit_height(self$camera$get_frame_height())
      frame$center()
      frame$set_stroke(width = 0)
      ApplyMethod(frame$restore, run_time = run_time, ...)
    },
    get_zoomed_display_pop_out_animation = function(...) {
      display <- self$zoomed_display
      display$save_state()
      display$replace(self$zoomed_camera$frame, stretch = TRUE)
      ApplyMethod(display$restore, ...)
    },
    get_zoom_factor = function() self$zoomed_camera$frame$height / self$zoomed_display$height,
    # The zoomed display redraws the scene, so once zooming is on every
    # mobject is drawn each frame (no cached static background).
    get_moving_mobjects = function(animations) {
      moving <- super$get_moving_mobjects(animations)
      if (self$zoom_activated) return(list_update(self$mobjects, moving))
      moving
    }
  )
)
