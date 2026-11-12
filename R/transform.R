# Transform animations. Ported from manim/animation/transform.py.

#' Transform animations
#'
#' `Transform(a, b)` morphs `a` into the shape and style of `b`, keeping `a`
#' in the scene. `ReplacementTransform()` swaps `a` for `b` in the scene when
#' done. See Manim's documentation for the remaining variants.
#'
#' @param mobject The mobject to transform.
#' @param target_mobject The target.
#' @param path_func A [path function][paths].
#' @param path_arc Angle of the arc points travel along.
#' @param path_arc_axis Axis of that arc.
#' @param path_arc_centers Centers of the arcs.
#' @param replace_mobject_with_target_in_scene Replace `mobject` by the target at the end.
#' @param ... Passed to [Animation()].
#' @name transform
NULL

#' @rdname transform
#' @format NULL
#' @usage NULL
#' @export
TransformClass <- R6::R6Class("Transform", inherit = AnimationClass, lock_objects = FALSE,
  public = list(
    path_arc_axis = NULL,
    path_arc_centers = NULL,
    replace_mobject_with_target_in_scene = FALSE,
    target_mobject = NULL,
    target_copy = NULL,
    initialize = function(mobject, target_mobject = NULL, path_func = NULL, path_arc = 0, path_arc_axis = OUT,
                          path_arc_centers = NULL, replace_mobject_with_target_in_scene = FALSE, ...) {
      self$path_arc_axis <- path_arc_axis
      self$path_arc_centers <- path_arc_centers
      self$path_arc <- path_arc
      if (!is.null(path_func)) {
        self$path_func <- path_func
      } else if (!is.null(path_arc_centers)) {
        self$path_func <- path_along_circles(path_arc, path_arc_centers, path_arc_axis)
      }
      self$replace_mobject_with_target_in_scene <- replace_mobject_with_target_in_scene
      self$target_mobject <- target_mobject %||% MobjectClass$new()
      super$initialize(mobject, ...)
    },
    begin = function() {
      self$target_mobject <- self$create_target()
      self$target_copy <- self$target_mobject$copy()
      self$mobject$align_data(self$target_copy)
      super$begin()
    },
    create_target = function() self$target_mobject,
    clean_up_from_scene = function(scene) {
      super$clean_up_from_scene(scene)
      if (self$replace_mobject_with_target_in_scene) scene$replace(self$mobject, self$target_mobject)
    },
    get_all_mobjects = function() list(self$mobject, self$starting_mobject, self$target_mobject, self$target_copy),
    get_all_families_zipped = function() {
      fams <- lapply(list(self$mobject, self$starting_mobject, self$target_copy), function(m) m$family_members_with_points())
      n <- min(lengths(fams))
      lapply(seq_len(n), function(i) lapply(fams, `[[`, i))
    },
    interpolate_submobject = function(submobject, starting_submobject, target_copy, alpha) {
      submobject$interpolate(starting_submobject, target_copy, alpha, private$.path_func)
      invisible(self)
    }
  ),
  private = list(.path_arc = 0, .path_func = NULL),
  active = list(
    path_arc = function(value) {
      if (missing(value)) return(private$.path_arc)
      private$.path_arc <- value
      private$.path_func <- path_along_arc(value, self$path_arc_axis %||% OUT)
    },
    path_func = function(value) {
      if (missing(value)) return(private$.path_func)
      if (!is.null(value)) private$.path_func <- value
    }
  )
)

#' @rdname transform
#' @export
Transform <- constructor(TransformClass)
#' @rdname transform
#' @export
ReplacementTransform <- function(mobject, target_mobject, ...) {
  a <- TransformClass$new(mobject, target_mobject, replace_mobject_with_target_in_scene = TRUE, ...)
  class(a) <- c("ReplacementTransform", class(a))
  a
}

#' @rdname transform
#' @format NULL
#' @usage NULL
#' @export
TransformFromCopyClass <- R6::R6Class("TransformFromCopy", inherit = TransformClass, lock_objects = FALSE,
  public = list(
    initialize = function(mobject, target_mobject, ...) super$initialize(target_mobject, mobject, ...),
    interpolate = function(alpha) super$interpolate(1 - alpha)
  )
)

#' @rdname transform
#' @export
TransformFromCopy <- constructor(TransformFromCopyClass)
#' @rdname transform
#' @export
ClockwiseTransform <- function(mobject, target_mobject, path_arc = -pi, ...) {
  TransformClass$new(mobject, target_mobject, path_arc = path_arc, ...)
}

#' @rdname transform
#' @export
CounterclockwiseTransform <- function(mobject, target_mobject, path_arc = pi, ...) {
  TransformClass$new(mobject, target_mobject, path_arc = path_arc, ...)
}

#' @rdname transform
#' @format NULL
#' @usage NULL
#' @export
MoveToTargetClass <- R6::R6Class("MoveToTarget", inherit = TransformClass, lock_objects = FALSE,
  public = list(
    initialize = function(mobject, ...) {
      self$check_validity_of_input(mobject)
      super$initialize(mobject, mobject$target, ...)
    },
    check_validity_of_input = function(mobject) {
      if (is.null(mobject$target)) stop("MoveToTarget called on mobject without attribute 'target'", call. = FALSE)
      invisible(TRUE)
    }
  )
)

#' @rdname transform
#' @export
MoveToTarget <- function(mobject, ...) {
  ov <- animation_override("MoveToTarget", mobject, match.call(), parent.frame())
  if (!is.null(ov)) return(ov$value)
  MoveToTargetClass$new(mobject, ...)
}

MethodAnimationClass <- R6::R6Class("MethodAnimation", inherit = TransformClass, lock_objects = FALSE,
  public = list(
    methods = NULL,
    initialize = function(mobject, methods, ...) {
      self$methods <- methods
      super$initialize(mobject, mobject$target, ...)
    },
    finish = function() {
      for (m in self$methods) do.call(self$mobject[[m$name]], m$args)
      super$finish()
    }
  )
)

#' @rdname transform
#' @format NULL
#' @usage NULL
#' @export
ApplyMethodClass <- R6::R6Class("ApplyMethod", inherit = TransformClass, lock_objects = FALSE,
  public = list(
    method_name = NULL,
    check_validity_of_input = function(method) {
      mob <- if (is.function(method)) get0("self", envir = environment(method), inherits = FALSE)
      if (!is_mobject(mob)) {
        stop("Whoops, looks like you accidentally invoked the method you want to animate; ",
             "pass the method itself, such as mob$scale", call. = FALSE)
      }
      invisible(TRUE)
    },
    method_args = NULL,
    initialize = function(method, ..., method_mobject = NULL) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      anim_names <- names(formals(TransformClass$public_methods$initialize))
      anim_names <- c(anim_names, names(formals(AnimationClass$public_methods$initialize)))
      is_anim <- nm %in% setdiff(anim_names, c("...", "mobject"))
      self$method_args <- args[!is_anim]
      if (is.function(method)) {
        self$check_validity_of_input(method)
        mob <- environment(method)$self
        self$method_name <- find_method_name(mob, method)
      } else {
        mob <- method_mobject
        self$method_name <- method
      }
      do.call(super$initialize, c(list(mob), args[is_anim]))
    },
    create_target = function() {
      target <- self$mobject$copy()
      do.call(target[[self$method_name]], self$method_args)
      target
    }
  )
)

find_method_name <- function(mob, method) {
  for (n in ls(mob)) {
    if (!bindingIsActive(n, mob) && identical(get(n, envir = mob), method)) return(n)
  }
  stop("Could not identify the mobject method", call. = FALSE)
}

#' @rdname transform
#' @param method A mobject method such as `mob$shift`, followed by its arguments.
#' @param method_mobject Mobject to call `method` on when `method` is given
#'   as a method name rather than a bound method.
#' @export
ApplyMethod <- constructor(ApplyMethodClass)
#' @rdname transform
#' @param fn A function of a point.
#' @export
ApplyPointwiseFunction <- function(fn, mobject, run_time = DEFAULT_POINTWISE_FUNCTION_RUN_TIME, ...) {
  ApplyMethodClass$new("apply_function", fn, method_mobject = mobject, run_time = run_time, ...)
}

#' @rdname transform
#' @export
ApplyPointwiseFunctionToCenter <- function(fn, mobject, ...) {
  ApplyPointwiseFunctionToCenterClass$new(fn, mobject, ...)
}

ApplyPointwiseFunctionToCenterClass <- R6::R6Class("ApplyPointwiseFunctionToCenter", inherit = ApplyMethodClass,
  lock_objects = FALSE,
  public = list(
    fn = NULL,
    initialize = function(fn, mobject, ...) {
      self$fn <- fn
      super$initialize("move_to", ORIGIN, method_mobject = mobject, ...)
    },
    begin = function() {
      self$method_args <- list(self$fn(self$mobject$get_center()))
      super$begin()
    }
  )
)

#' @rdname transform
#' @param color A color.
#' @export
FadeToColor <- function(mobject, color, ...) ApplyMethodClass$new("set_color", color, method_mobject = mobject, ...)

#' @rdname transform
#' @param scale_factor Scale factor.
#' @export
ScaleInPlace <- function(mobject, scale_factor, ...) ApplyMethodClass$new("scale", scale_factor, method_mobject = mobject, ...)

#' @rdname transform
#' @export
ShrinkToCenter <- function(mobject, ...) ScaleInPlace(mobject, 0, ...)

#' @rdname transform
#' @export
Restore <- function(mobject, ...) ApplyMethodClass$new("restore", method_mobject = mobject, ...)

#' @rdname transform
#' @format NULL
#' @usage NULL
#' @export
ApplyFunctionClass <- R6::R6Class("ApplyFunction", inherit = TransformClass, lock_objects = FALSE,
  public = list(
    fn = NULL,
    initialize = function(fn, mobject, ...) {
      self$fn <- fn
      super$initialize(mobject, ...)
    },
    create_target = function() {
      target <- self$fn(self$mobject$copy())
      if (!is_mobject(target)) stop("Functions passed to ApplyFunction must return a Mobject", call. = FALSE)
      target
    }
  )
)

#' @rdname transform
#' @export
ApplyFunction <- constructor(ApplyFunctionClass)
#' @rdname transform
#' @format NULL
#' @usage NULL
#' @export
ApplyMatrixClass <- R6::R6Class("ApplyMatrix", inherit = ApplyMethodClass, lock_objects = FALSE,
  public = list(
    matrix = NULL,
    initialize = function(matrix, mobject, about_point = ORIGIN, run_time = DEFAULT_POINTWISE_FUNCTION_RUN_TIME, ...) {
      m <- self$initialize_matrix(matrix)
      self$matrix <- m
      ap <- as_point(about_point)
      fn <- function(p) drop(m %*% (p - ap)) + ap
      super$initialize("apply_function", fn, method_mobject = mobject, run_time = run_time, ...)
    },
    # A 2 x 2 matrix acts on x and y only.
    initialize_matrix = function(matrix) {
      m <- as.matrix(matrix)
      if (all(dim(m) == c(2, 2))) {
        full <- diag(3)
        full[1:2, 1:2] <- m
        m <- full
      } else if (!all(dim(m) == c(3, 3))) {
        stop("Matrix has bad dimensions", call. = FALSE)
      }
      m
    }
  )
)

#' @rdname transform
#' @param matrix A 2 x 2 or 3 x 3 matrix.
#' @param about_point Fixed point of the transformation.
#' @export
ApplyMatrix <- function(matrix, mobject, about_point = ORIGIN, ...) ApplyMatrixClass$new(matrix, mobject, about_point, ...)

#' @rdname transform
#' @export
ApplyComplexFunction <- function(fn, mobject, ...) {
  a <- ApplyMethodClass$new("apply_complex_function", fn, method_mobject = mobject, ...)
  a$path_arc <- Im(log(fn(complex(real = 1, imaginary = 0))))
  a
}

#' @rdname transform
#' @format NULL
#' @usage NULL
#' @export
CyclicReplaceClass <- R6::R6Class("CyclicReplace", inherit = TransformClass, lock_objects = FALSE,
  public = list(
    group = NULL,
    initialize = function(..., path_arc = 90 * DEGREES) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      mobs <- args[nm == ""]
      self$group <- if (length(mobs) == 1 && inherits(mobs[[1]], c("Group", "VGroup"))) mobs[[1]] else do.call(Group, mobs)
      do.call(super$initialize, c(list(self$group, path_arc = path_arc), args[nm != ""]))
    },
    create_target = function() {
      target <- self$group$copy()
      ts <- target$submobjects
      n <- length(ts)
      cycled <- c(ts[n], ts[-n])
      for (i in seq_len(n)) cycled[[i]]$move_to(self$group$submobjects[[i]])
      target
    }
  )
)

#' @rdname transform
#' @export
CyclicReplace <- constructor(CyclicReplaceClass)
#' @rdname transform
#' @export
Swap <- constructor(CyclicReplaceClass)
#' @rdname transform
#' @format NULL
#' @usage NULL
#' @export
FadeTransformClass <- R6::R6Class("FadeTransform", inherit = TransformClass, lock_objects = FALSE,
  public = list(
    to_add_on_completion = NULL,
    stretch = TRUE,
    dim_to_match = 2,
    ending_mobject = NULL,
    initialize = function(mobject, target_mobject, stretch = TRUE, dim_to_match = 2, ...) {
      self$to_add_on_completion <- target_mobject
      self$stretch <- stretch
      self$dim_to_match <- dim_to_match
      mobject$save_state()
      super$initialize(Group(mobject, target_mobject$copy()), ...)
    },
    begin = function() {
      self$ending_mobject <- self$mobject$copy()
      self$starting_mobject <- self$create_starting_mobject()
      if (self$suspend_mobject_updating) self$mobject$suspend_updating()
      self$interpolate(0)
      s <- self$starting_mobject$submobjects
      e <- self$ending_mobject$submobjects
      self$ghost_to(s[[2]], s[[1]])
      self$ghost_to(e[[1]], e[[2]])
    },
    ghost_to = function(source, target) {
      if (target$get_num_points() || length(target$submobjects)) {
        source$replace(target, stretch = self$stretch, dim_to_match = self$dim_to_match)
      }
      source$set_opacity(0)
    },
    get_all_mobjects = function() list(self$mobject, self$starting_mobject, self$ending_mobject),
    get_all_families_zipped = function() {
      fams <- lapply(self$get_all_mobjects(), function(m) m$family_members_with_points())
      n <- min(lengths(fams))
      lapply(seq_len(n), function(i) lapply(fams, `[[`, i))
    },
    clean_up_from_scene = function(scene) {
      if (!is.null(self$on_finish)) self$on_finish(scene)
      if (self$is_remover()) scene$remove(self$mobject)
      scene$remove(self$mobject)
      self$mobject$submobjects[[1]]$restore()
      scene$add(self$to_add_on_completion)
    }
  )
)

#' @rdname transform
#' @param stretch Stretch the ghosts to match.
#' @param dim_to_match Dimension (1 = x, 2 = y) to match when not stretching.
#' @export
FadeTransform <- constructor(FadeTransformClass)
#' @rdname transform
#' @format NULL
#' @usage NULL
#' @export
FadeTransformPiecesClass <- R6::R6Class("FadeTransformPieces", inherit = FadeTransformClass, lock_objects = FALSE,
  public = list(
    begin = function() {
      self$mobject$submobjects[[1]]$align_submobjects(self$mobject$submobjects[[2]])
      super$begin()
    },
    ghost_to = function(source, target) {
      f1 <- source$get_family()
      f2 <- target$get_family()
      for (i in seq_len(min(length(f1), length(f2)))) super$ghost_to(f1[[i]], f2[[i]])
    }
  )
)

#' @rdname transform
#' @export
FadeTransformPieces <- constructor(FadeTransformPiecesClass)
#' @rdname transform
#' @format NULL
#' @usage NULL
#' @export
TransformAnimationsClass <- R6::R6Class("TransformAnimations", inherit = TransformClass, lock_objects = FALSE,
  public = list(
    start_anim = NULL,
    end_anim = NULL,
    initialize = function(start_anim, end_anim, rate_func = squish_rate_func(smooth_rate), run_time = NULL, ...) {
      self$start_anim <- start_anim
      self$end_anim <- end_anim
      run_time <- run_time %||% max(start_anim$run_time, end_anim$run_time)
      for (a in list(start_anim, end_anim)) a$set_run_time(run_time)
      s1 <- start_anim$starting_mobject
      s2 <- end_anim$starting_mobject
      if (!is.null(s1) && !is.null(s2) && s1$get_num_points() != s2$get_num_points()) {
        s1$align_data(s2)
        for (a in list(start_anim, end_anim)) {
          if (inherits(a, "Transform") && !is.null(a$starting_mobject)) a$starting_mobject$align_data(a$target_mobject)
        }
      }
      super$initialize(start_anim$mobject, end_anim$mobject, rate_func = rate_func, run_time = run_time, ...)
      start_anim$mobject <- self$starting_mobject
      end_anim$mobject <- self$target_mobject
    },
    interpolate = function(alpha) {
      self$start_anim$interpolate(alpha)
      self$end_anim$interpolate(alpha)
      super$interpolate(alpha)
    }
  )
)

#' @rdname transform
#' @param start_anim,end_anim Animations to blend between.
#' @param run_time Duration in seconds; for `TransformAnimations()` the
#'   default is the longer of the two animations.
#' @param rate_func Rate function.
#' @export
TransformAnimations <- constructor(TransformAnimationsClass)