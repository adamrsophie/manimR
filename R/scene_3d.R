# Scenes for three dimensional content. Ported from manim/scene/three_d_scene.py.

#' @title ThreeDScene
#' @description A [Scene] with a [ThreeDCameraClass]. Set the view with
#'   `set_camera_orientation(phi, theta, gamma, zoom, focal_distance,
#'   frame_center)`, animate it with `move_camera()`, and spin it with
#'   `begin_ambient_camera_rotation(rate, about)`. Mobjects passed to
#'   `add_fixed_in_frame_mobjects()` ignore the camera (titles, labels);
#'   those passed to `add_fixed_orientation_mobjects()` keep facing the
#'   viewer while their center follows the 3D projection.
#'
#'   `SpecialThreeDScene` adds default sphere and camera settings.
#'
#'   Initializer arguments: `ambient_camera_rotation` (kept for
#'   compatibility), `default_angled_camera_orientation_kwargs` (angles for
#'   `set_to_default_angled_camera_orientation()`); the rest go to [Scene]
#'   and on to the camera, for example `should_apply_shading = FALSE`.
#'   `SpecialThreeDScene` also takes `camera_config`, `three_d_axes_config`,
#'   `sphere_config`, `default_angled_camera_position` and
#'   `low_quality_config` (used when rendering at low quality).
#' @format NULL
#' @usage NULL
#' @export
#' @examples
#' Spin <- R6::R6Class("Spin", inherit = ThreeDScene, public = list(
#'   construct = function() {
#'     self$set_camera_orientation(phi = 75 * DEGREES, theta = 30 * DEGREES)
#'     self$add(Sphere(radius = 1.5)$shift(LEFT * 2), Cube()$shift(RIGHT * 2))
#'     self$begin_ambient_camera_rotation(rate = 0.5)
#'     self$wait(2)
#'   }))
#' \dontrun{
#' # A video in the media folder (by default in the session's temporary
#' # directory); this needs ffmpeg.
#' render(Spin, quality = "l")
#' }
ThreeDScene <- R6::R6Class("ThreeDScene", inherit = Scene, lock_objects = FALSE,
  public = list(
    ambient_camera_rotation = NULL,
    default_angled_camera_orientation_kwargs = NULL,
    initialize = function(camera_class = NULL, ambient_camera_rotation = NULL,
                          default_angled_camera_orientation_kwargs = NULL, ...) {
      self$ambient_camera_rotation <- ambient_camera_rotation
      self$default_angled_camera_orientation_kwargs <- default_angled_camera_orientation_kwargs %||%
        list(phi = 70 * DEGREES, theta = -135 * DEGREES)
      super$initialize(camera_class = camera_class, ...)
    },
    default_camera_class = function() ThreeDCameraClass,
    set_camera_orientation = function(phi = NULL, theta = NULL, gamma = NULL, zoom = NULL, focal_distance = NULL,
                                      frame_center = NULL, ...) {
      cam <- self$camera
      if (!is.null(phi)) cam$set_phi(phi)
      if (!is.null(theta)) cam$set_theta(theta)
      if (!is.null(focal_distance)) cam$set_focal_distance(focal_distance)
      if (!is.null(gamma)) cam$set_gamma(gamma)
      if (!is.null(zoom)) cam$set_zoom(zoom)
      if (!is.null(frame_center)) cam$set_frame_center(frame_center)
      invisible(self)
    },
    camera_tracker = function(about) {
      about <- tolower(about)
      trackers <- list(theta = self$camera$theta_tracker, phi = self$camera$phi_tracker,
                       gamma = self$camera$gamma_tracker)
      if (!about %in% names(trackers)) stop("Invalid ambient rotation angle.", call. = FALSE)
      trackers[[about]]
    },
    # The tracker gets a time based updater and joins the scene, so every
    # frame (waits included) redraws with the new angle.
    begin_ambient_camera_rotation = function(rate = 0.02, about = "theta") {
      x <- self$camera_tracker(about)
      x$add_updater(function(m, dt) m$increment_value(rate * dt))
      self$add(x)
      invisible(self)
    },
    stop_ambient_camera_rotation = function(about = "theta") {
      x <- self$camera_tracker(about)
      x$clear_updaters()
      self$remove(x)
      invisible(self)
    },
    begin_3dillusion_camera_rotation = function(rate = 1, origin_phi = NULL, origin_theta = NULL) {
      cam <- self$camera
      origin_theta <- origin_theta %||% cam$theta_tracker$get_value()
      origin_phi <- origin_phi %||% cam$phi_tracker$get_value()
      val_tracker_theta <- ValueTracker(0)
      update_theta <- function(m, dt) {
        val_tracker_theta$increment_value(dt * rate)
        m$set_value(origin_theta + 0.2 * sin(val_tracker_theta$get_value()))
      }
      cam$theta_tracker$add_updater(update_theta)
      self$add(cam$theta_tracker)
      val_tracker_phi <- ValueTracker(0)
      update_phi <- function(m, dt) {
        val_tracker_phi$increment_value(dt * rate)
        m$set_value(origin_phi + 0.1 * cos(val_tracker_phi$get_value()) - 0.1)
      }
      cam$phi_tracker$add_updater(update_phi)
      self$add(cam$phi_tracker)
      invisible(self)
    },
    stop_3dillusion_camera_rotation = function() {
      for (x in list(self$camera$theta_tracker, self$camera$phi_tracker)) {
        x$clear_updaters()
        self$remove(x)
      }
      invisible(self)
    },
    move_camera = function(phi = NULL, theta = NULL, gamma = NULL, zoom = NULL, focal_distance = NULL,
                           frame_center = NULL, added_anims = list(), ...) {
      cam <- self$camera
      anims <- list()
      pairs <- list(list(phi, cam$phi_tracker), list(theta, cam$theta_tracker),
                    list(focal_distance, cam$focal_distance_tracker), list(gamma, cam$gamma_tracker),
                    list(zoom, cam$zoom_tracker))
      for (p in pairs) {
        if (!is.null(p[[1]])) anims[[length(anims) + 1]] <- p[[2]]$animate$set_value(p[[1]])
      }
      if (!is.null(frame_center)) anims[[length(anims) + 1]] <- cam$frame_center_mob$animate$move_to(frame_center)
      self$play(anims, added_anims, ...)
      # The frame center mobject only joins the scene so that everything
      # redraws while it moves; drop it again afterwards.
      if (!is.null(frame_center)) self$remove(cam$frame_center_mob)
      invisible(self)
    },
    get_moving_mobjects = function(...) {
      moving <- super$get_moving_mobjects(...)
      cam_ids <- vapply(c(self$camera$get_value_trackers(), list(self$camera$frame_center_mob)),
                        function(m) m$mob_id, "")
      ids <- vapply(moving, function(m) m$mob_id, "")
      if (any(cam_ids %in% ids)) return(self$mobjects)
      moving
    },
    add_fixed_orientation_mobjects = function(..., use_static_center_func = FALSE, center_func = NULL) {
      self$add(...)
      self$camera$add_fixed_orientation_mobjects(..., use_static_center_func = use_static_center_func,
                                                 center_func = center_func)
      invisible(self)
    },
    add_fixed_in_frame_mobjects = function(...) {
      # Under the OpenGL renderer, upstream marks each mobject's family with
      # fix_in_frame() for the shaders instead.
      if (inherits(self$renderer, "OpenGLRenderer")) {
        for (mob in list(...)) {
          for (m in mob$get_family()) m$is_fixed_in_frame <- 1
          self$add(mob)
        }
        return(invisible(self))
      }
      self$add(...)
      self$camera$add_fixed_in_frame_mobjects(...)
      invisible(self)
    },
    remove_fixed_orientation_mobjects = function(...) {
      self$camera$remove_fixed_orientation_mobjects(...)
      invisible(self)
    },
    remove_fixed_in_frame_mobjects = function(...) {
      if (inherits(self$renderer, "OpenGLRenderer")) {
        for (mob in list(...)) {
          for (m in mob$get_family()) m$is_fixed_in_frame <- 0
          self$remove(mob)
        }
        return(invisible(self))
      }
      self$camera$remove_fixed_in_frame_mobjects(...)
      invisible(self)
    },
    set_to_default_angled_camera_orientation = function(...) {
      config <- utils::modifyList(self$default_angled_camera_orientation_kwargs, list(...))
      do.call(self$set_camera_orientation, config)
    }
  )
)

#' @return R6 class generators. A scene class inherits from one of them, and
#'   `$new()` creates a scene.
#' @rdname ThreeDScene
#' @format NULL
#' @usage NULL
#' @export
SpecialThreeDScene <- R6::R6Class("SpecialThreeDScene", inherit = ThreeDScene, lock_objects = FALSE,
  public = list(
    cut_axes_at_radius = TRUE,
    camera_config = NULL,
    three_d_axes_config = NULL,
    sphere_config = NULL,
    default_angled_camera_position = NULL,
    low_quality_config = NULL,
    initialize = function(cut_axes_at_radius = TRUE,
                          camera_config = list(should_apply_shading = TRUE, exponential_projection = TRUE),
                          three_d_axes_config = list(), sphere_config = list(radius = 2, resolution = c(24, 48)),
                          default_angled_camera_position = list(phi = 70 * DEGREES, theta = -110 * DEGREES),
                          low_quality_config = list(camera_config = list(should_apply_shading = FALSE),
                                                    sphere_config = list(resolution = c(12, 24))),
                          ...) {
      if (cfg("pixel_width") <= QUALITIES$low_quality$pixel_width) {
        camera_config <- utils::modifyList(camera_config, low_quality_config$camera_config %||% list())
        sphere_config <- utils::modifyList(sphere_config, low_quality_config$sphere_config %||% list())
      }
      self$cut_axes_at_radius <- cut_axes_at_radius
      self$camera_config <- camera_config
      self$three_d_axes_config <- three_d_axes_config
      self$sphere_config <- sphere_config
      self$default_angled_camera_position <- default_angled_camera_position
      self$low_quality_config <- low_quality_config
      do.call(super$initialize, utils::modifyList(camera_config, list(...)))
    },
    # Upstream also cuts the axes into pieces; that relies on an older
    # NumberLine layout, so plain ThreeDAxes are returned.
    get_axes = function() do.call(ThreeDAxes, self$three_d_axes_config),
    get_sphere = function(...) do.call(Sphere, utils::modifyList(self$sphere_config, list(...))),
    get_default_camera_position = function() self$default_angled_camera_position,
    set_camera_to_default_position = function() {
      do.call(self$set_camera_orientation, self$default_angled_camera_position)
    }
  )
)
