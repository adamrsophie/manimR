# Fading, growing, movement, rotation and updater animations.
# Ported from manim/animation/{fading,growing,movement,rotation}.py and
# manim/animation/updaters/update.py.

#' Fading animations
#'
#' `FadeIn()` and `FadeOut()` fade mobjects in or out, optionally moving them
#' by `shift`, toward `target_position`, or scaling by `scale`.
#'
#' @param ... Mobjects, then named arguments: `shift`, a vector to move
#'   along while fading; `target_position`, a point or mobject to fade toward
#'   or from; `scale`, the scale factor of the faded state; and any argument
#'   of [Transform()].
#' @name fading
NULL

FadeBaseClass <- R6::R6Class("Fade", inherit = TransformClass, lock_objects = FALSE,
  public = list(
    point_target = FALSE,
    shift_vector = NULL,
    scale_factor = 1,
    initialize = function(..., shift = NULL, target_position = NULL, scale = 1) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      mobs <- args[nm == ""]
      if (length(mobs) == 0) stop("At least one mobject must be passed.", call. = FALSE)
      mobject <- if (length(mobs) == 1) mobs[[1]] else do.call(Group, mobs)
      self$point_target <- FALSE
      if (is.null(shift)) {
        if (!is.null(target_position)) {
          if (is_mobject(target_position)) target_position <- target_position$get_center()
          shift <- as_point(target_position) - mobject$get_center()
          self$point_target <- TRUE
        } else {
          shift <- ORIGIN
        }
      }
      self$shift_vector <- as_point(shift)
      self$scale_factor <- scale
      do.call(super$initialize, c(list(mobject), args[nm != ""]))
    },
    create_faded_mobject = function(fade_in) {
      faded <- self$mobject$copy()
      faded$fade(1)
      dm <- if (fade_in && !self$point_target) -1 else 1
      faded$shift(self$shift_vector * dm)
      faded$scale(self$scale_factor)
      faded
    }
  )
)

#' @rdname fading
#' @format NULL
#' @usage NULL
#' @export
FadeInClass <- R6::R6Class("FadeIn", inherit = FadeBaseClass, lock_objects = FALSE,
  public = list(
    initialize = function(...) super$initialize(..., introducer = TRUE),
    create_target = function() self$mobject,
    create_starting_mobject = function() self$create_faded_mobject(TRUE)
  )
)

#' @rdname fading
#' @export
FadeIn <- constructor(FadeInClass)
#' @rdname fading
#' @format NULL
#' @usage NULL
#' @export
FadeOutClass <- R6::R6Class("FadeOut", inherit = FadeBaseClass, lock_objects = FALSE,
  public = list(
    initialize = function(...) super$initialize(..., remover = TRUE),
    create_target = function() self$create_faded_mobject(FALSE),
    clean_up_from_scene = function(scene) {
      super$clean_up_from_scene(scene)
      self$interpolate(0)
    }
  )
)

#' @rdname fading
#' @export
FadeOut <- constructor(FadeOutClass)
#' Growing animations
#'
#' Grow mobjects from a point, their center, an edge, or (for arrows) their start.
#'
#' @param mobject,arrow The mobject to grow.
#' @param point Point to grow from.
#' @param edge Edge direction to grow from.
#' @param point_color Initial color.
#' @param angle Spin angle for `SpinInFromNothing()`.
#' @param ... Passed to [Transform()].
#' @name growing
NULL

#' @rdname growing
#' @format NULL
#' @usage NULL
#' @export
GrowFromPointClass <- R6::R6Class("GrowFromPoint", inherit = TransformClass, lock_objects = FALSE,
  public = list(
    point = NULL,
    point_color = NULL,
    initialize = function(mobject, point, point_color = NULL, ...) {
      self$point <- if (is_mobject(point)) point$get_center() else as_point(point)
      self$point_color <- point_color
      super$initialize(mobject, introducer = TRUE, ...)
    },
    create_target = function() self$mobject,
    create_starting_mobject = function() {
      start <- super$create_starting_mobject()
      start$scale(0)
      start$move_to(self$point)
      if (!is.null(self$point_color)) start$set_color(self$point_color)
      start
    }
  )
)

#' @rdname growing
#' @export
GrowFromPoint <- constructor(GrowFromPointClass)
#' @rdname growing
#' @export
GrowFromCenter <- function(mobject, ...) {
  ov <- animation_override("GrowFromCenter", mobject, match.call(), parent.frame())
  if (!is.null(ov)) return(ov$value)
  GrowFromPointClass$new(mobject, mobject$get_center(), ...)
}

#' @rdname growing
#' @export
GrowFromEdge <- function(mobject, edge, ...) {
  ov <- animation_override("GrowFromEdge", mobject, match.call(), parent.frame())
  if (!is.null(ov)) return(ov$value)
  GrowFromPointClass$new(mobject, mobject$get_critical_point(edge), ...)
}

#' @rdname growing
#' @format NULL
#' @usage NULL
#' @export
GrowArrowClass <- R6::R6Class("GrowArrow", inherit = GrowFromPointClass, lock_objects = FALSE,
  public = list(
    initialize = function(arrow, point_color = NULL, ...) super$initialize(arrow, arrow$get_start(), point_color = point_color, ...),
    create_starting_mobject = function() {
      start <- self$mobject$copy()
      if (inherits(start, "Arrow")) start$scale(0, scale_tips = TRUE, about_point = self$point)
      else start$scale(0, about_point = self$point)
      if (!is.null(self$point_color)) start$set_color(self$point_color)
      start
    }
  )
)

#' @rdname growing
#' @export
GrowArrow <- constructor(GrowArrowClass)
#' @rdname growing
#' @export
SpinInFromNothing <- function(mobject, angle = PI / 2, point_color = NULL, ...) {
  ov <- animation_override("SpinInFromNothing", mobject, match.call(), parent.frame())
  if (!is.null(ov)) return(ov$value)
  a <- GrowFromPointClass$new(mobject, mobject$get_center(), path_func = spiral_path(angle),
                              point_color = point_color, ...)
  class(a) <- c("SpinInFromNothing", class(a))
  a
}

#' Movement animations
#'
#' @param homotopy A function `(x, y, z, t)` returning a point.
#' @param complex_homotopy A function `(z, t)` of a complex number.
#' @param fn A vector field function of a point (for `PhaseFlow()`).
#' @param mobject The mobject to move.
#' @param path A VMobject path to move along.
#' @param run_time Duration.
#' @param apply_function_kwargs Extra arguments to `apply_function()`.
#' @param virtual_time Virtual time span of the flow.
#' @param suspend_mobject_updating Pause updaters while running.
#' @param rate_func Rate function.
#' @param ... Passed to [Animation()].
#' @name movement
NULL

#' @rdname movement
#' @format NULL
#' @usage NULL
#' @export
HomotopyClass <- R6::R6Class("Homotopy", inherit = AnimationClass, lock_objects = FALSE,
  public = list(
    homotopy = NULL,
    apply_function_kwargs = NULL,
    initialize = function(homotopy, mobject, run_time = 3, apply_function_kwargs = NULL, ...) {
      self$homotopy <- homotopy
      self$apply_function_kwargs <- apply_function_kwargs %||% list()
      super$initialize(mobject, run_time = run_time, ...)
    },
    function_at_time_t = function(t) {
      h <- self$homotopy
      function(p) as_point(h(p[1], p[2], p[3], t))
    },
    interpolate_submobject = function(submobject, starting_submobject, alpha) {
      submobject$points <- starting_submobject$points
      do.call(submobject$apply_function, c(list(self$function_at_time_t(alpha)), self$apply_function_kwargs))
      invisible(self)
    }
  )
)

#' @rdname movement
#' @export
Homotopy <- constructor(HomotopyClass)
#' @rdname movement
#' @format NULL
#' @usage NULL
#' @export
SmoothedVectorizedHomotopyClass <- R6::R6Class("SmoothedVectorizedHomotopy", inherit = HomotopyClass, lock_objects = FALSE,
  public = list(
    interpolate_submobject = function(submobject, starting_submobject, alpha) {
      super$interpolate_submobject(submobject, starting_submobject, alpha)
      submobject$make_smooth()
      invisible(self)
    }
  )
)

#' @rdname movement
#' @export
SmoothedVectorizedHomotopy <- constructor(SmoothedVectorizedHomotopyClass)
#' @rdname movement
#' @export
ComplexHomotopy <- function(complex_homotopy, mobject, ...) {
  ov <- animation_override("ComplexHomotopy", mobject, match.call(), parent.frame())
  if (!is.null(ov)) return(ov$value)
  h <- function(x, y, z, t) {
    cz <- complex_homotopy(complex(real = x, imaginary = y), t)
    c(Re(cz), Im(cz), z)
  }
  HomotopyClass$new(h, mobject, ...)
}

#' @rdname movement
#' @format NULL
#' @usage NULL
#' @export
PhaseFlowClass <- R6::R6Class("PhaseFlow", inherit = AnimationClass, lock_objects = FALSE,
  public = list(
    virtual_time = 1,
    fn = NULL,
    last_alpha = NULL,
    initialize = function(fn, mobject, virtual_time = 1, suspend_mobject_updating = FALSE, rate_func = linear, ...) {
      self$virtual_time <- virtual_time
      self$fn <- fn
      super$initialize(mobject, suspend_mobject_updating = suspend_mobject_updating, rate_func = rate_func, ...)
    },
    interpolate_mobject = function(alpha) {
      if (!is.null(self$last_alpha)) {
        dt <- self$virtual_time * (self$rate_func(alpha) - self$rate_func(self$last_alpha))
        f <- self$fn
        self$mobject$apply_function(function(p) p + dt * as_point(f(p)))
      }
      self$last_alpha <- alpha
    }
  )
)

#' @rdname movement
#' @export
PhaseFlow <- constructor(PhaseFlowClass)
#' @rdname movement
#' @format NULL
#' @usage NULL
#' @export
MoveAlongPathClass <- R6::R6Class("MoveAlongPath", inherit = AnimationClass, lock_objects = FALSE,
  public = list(
    path = NULL,
    initialize = function(mobject, path, suspend_mobject_updating = FALSE, ...) {
      self$path <- path
      super$initialize(mobject, suspend_mobject_updating = suspend_mobject_updating, ...)
    },
    interpolate_mobject = function(alpha) {
      self$mobject$move_to(self$path$point_from_proportion(self$rate_func(alpha)))
    }
  )
)

#' @rdname movement
#' @export
MoveAlongPath <- constructor(MoveAlongPathClass)
#' Rotation animations
#'
#' `Rotate()` turns a mobject by `angle` along an arc path. `Rotating()`
#' spins it continuously with a linear rate by default.
#'
#' @param mobject The mobject.
#' @param angle Angle in radians.
#' @param axis Rotation axis.
#' @param about_point,about_edge Center of rotation.
#' @param run_time Duration.
#' @param rate_func Rate function.
#' @param path_arc,path_arc_axis Arc angle and axis of the path the points
#'   follow in `Rotate()`; default to `angle` and `axis`.
#' @param ... Passed to [Animation()] or [Transform()].
#' @name rotation
NULL

#' @rdname rotation
#' @format NULL
#' @usage NULL
#' @export
RotatingClass <- R6::R6Class("Rotating", inherit = AnimationClass, lock_objects = FALSE,
  public = list(
    angle = TAU,
    axis = OUT,
    about_point = NULL,
    about_edge = NULL,
    initialize = function(mobject, angle = TAU, axis = OUT, about_point = NULL, about_edge = NULL,
                          run_time = 5, rate_func = linear, ...) {
      self$angle <- angle
      self$axis <- axis
      self$about_point <- about_point
      self$about_edge <- about_edge
      super$initialize(mobject, run_time = run_time, rate_func = rate_func, ...)
    },
    interpolate_mobject = function(alpha) {
      self$mobject$become(self$starting_mobject)
      self$mobject$rotate(self$rate_func(alpha) * self$angle, axis = self$axis,
                          about_point = self$about_point, about_edge = self$about_edge)
    }
  )
)

#' @rdname rotation
#' @export
Rotating <- constructor(RotatingClass)
#' @rdname rotation
#' @format NULL
#' @usage NULL
#' @export
RotateClass <- R6::R6Class("Rotate", inherit = TransformClass, lock_objects = FALSE,
  public = list(
    angle = PI,
    axis = OUT,
    about_point = NULL,
    about_edge = NULL,
    initialize = function(mobject, angle = PI, axis = OUT, about_point = NULL, about_edge = NULL,
                          path_arc = NULL, path_arc_axis = NULL, ...) {
      self$angle <- angle
      self$axis <- axis
      self$about_edge <- about_edge
      self$about_point <- about_point %||% mobject$get_center()
      super$initialize(mobject, path_arc = path_arc %||% angle, path_arc_axis = path_arc_axis %||% axis,
                       path_arc_centers = self$about_point, ...)
    },
    create_target = function() {
      target <- self$mobject$copy()
      target$rotate(self$angle, axis = self$axis, about_point = self$about_point, about_edge = self$about_edge)
      target
    }
  )
)

#' @rdname rotation
#' @export
Rotate <- constructor(RotateClass)
#' Updater animations
#'
#' `UpdateFromFunc()` calls `update_function(mobject)` every frame;
#' `UpdateFromAlphaFunc()` calls `update_function(mobject, alpha)`.
#'
#' @param mobject The mobject.
#' @param update_function The function to call.
#' @param tracked_mobject Mobject to follow.
#' @param suspend_mobject_updating Pause other updaters while running.
#' @param ... Passed to [Animation()].
#' @name update_animations
NULL

#' @rdname update_animations
#' @format NULL
#' @usage NULL
#' @export
UpdateFromFuncClass <- R6::R6Class("UpdateFromFunc", inherit = AnimationClass, lock_objects = FALSE,
  public = list(
    update_function = NULL,
    initialize = function(mobject, update_function, suspend_mobject_updating = FALSE, ...) {
      self$update_function <- update_function
      super$initialize(mobject, suspend_mobject_updating = suspend_mobject_updating, ...)
    },
    interpolate_mobject = function(alpha) self$update_function(self$mobject)
  )
)

#' @rdname update_animations
#' @export
UpdateFromFunc <- constructor(UpdateFromFuncClass)
#' @rdname update_animations
#' @format NULL
#' @usage NULL
#' @export
UpdateFromAlphaFuncClass <- R6::R6Class("UpdateFromAlphaFunc", inherit = UpdateFromFuncClass, lock_objects = FALSE,
  public = list(
    interpolate_mobject = function(alpha) self$update_function(self$mobject, self$rate_func(alpha))
  )
)

#' @rdname update_animations
#' @export
UpdateFromAlphaFunc <- constructor(UpdateFromAlphaFuncClass)
#' @rdname update_animations
#' @format NULL
#' @usage NULL
#' @export
MaintainPositionRelativeToClass <- R6::R6Class("MaintainPositionRelativeTo", inherit = AnimationClass, lock_objects = FALSE,
  public = list(
    tracked_mobject = NULL,
    diff = NULL,
    initialize = function(mobject, tracked_mobject, ...) {
      self$tracked_mobject <- tracked_mobject
      self$diff <- mobject$get_center() - tracked_mobject$get_center()
      super$initialize(mobject, ...)
    },
    interpolate_mobject = function(alpha) {
      self$mobject$shift(self$tracked_mobject$get_center() - self$mobject$get_center() + self$diff)
    }
  )
)

#' @rdname update_animations
#' @export
MaintainPositionRelativeTo <- constructor(MaintainPositionRelativeToClass)