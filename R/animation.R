# Animation base class. Ported from manim/animation/animation.py.

DEFAULT_ANIMATION_RUN_TIME <- 1
DEFAULT_ANIMATION_LAG_RATIO <- 0

#' @title Animation
#' @description Base class for animations. An animation changes its
#'   `mobject` over `run_time` seconds, mapping time through `rate_func`.
#'   `lag_ratio` staggers submobjects: 0 animates them together, 1 one after
#'   another.
#' @param mobject The mobject to animate.
#' @param lag_ratio Stagger between submobjects.
#' @param run_time Duration in seconds.
#' @param rate_func A [rate function][rate_funcs].
#' @param reverse_rate_function Run the rate function backwards.
#' @param name Name used in progress messages.
#' @param remover Remove the mobject from the scene when done.
#' @param suspend_mobject_updating Pause the mobject's updaters while running.
#' @param introducer Add the mobject to the scene when the animation starts.
#' @param on_finish Optional function called with the scene when the
#'   animation is cleaned up from it.
#' @param ... Ignored.
#' @export
AnimationClass <- R6::R6Class("Animation", lock_objects = FALSE,
  public = list(
    mobject = NULL,
    starting_mobject = NULL,
    run_time = DEFAULT_ANIMATION_RUN_TIME,
    rate_func = NULL,
    reverse_rate_function = FALSE,
    name = NULL,
    remover = FALSE,
    introducer = FALSE,
    suspend_mobject_updating = TRUE,
    lag_ratio = DEFAULT_ANIMATION_LAG_RATIO,
    on_finish = NULL,
    initialize = function(mobject = NULL, lag_ratio = DEFAULT_ANIMATION_LAG_RATIO,
                          run_time = DEFAULT_ANIMATION_RUN_TIME, rate_func = smooth_rate,
                          reverse_rate_function = FALSE, name = NULL, remover = FALSE,
                          suspend_mobject_updating = TRUE, introducer = FALSE, on_finish = NULL, ...) {
      if (!is.null(mobject) && !is_mobject(mobject)) stop("Animation only works on Mobjects", call. = FALSE)
      if (run_time < 0) stop("The run_time of ", class(self)[1], " cannot be negative.", call. = FALSE)
      self$run_time <- run_time
      self$rate_func <- rate_func
      self$reverse_rate_function <- reverse_rate_function
      self$name <- name
      self$remover <- remover
      self$introducer <- introducer
      self$suspend_mobject_updating <- suspend_mobject_updating
      self$lag_ratio <- lag_ratio
      self$on_finish <- on_finish
      self$starting_mobject <- MobjectClass$new()
      self$mobject <- mobject %||% MobjectClass$new()
    },
    print = function(...) {
      cat("<", class(self)[1], "> ", self$label(), "\n", sep = "")
      invisible(self)
    },
    label = function() self$name %||% paste0(class(self)[1], "(", class(self$mobject)[1], ")"),
    begin = function() {
      self$starting_mobject <- self$create_starting_mobject()
      if (self$suspend_mobject_updating) self$mobject$suspend_updating()
      self$interpolate(0)
    },
    finish = function() {
      self$interpolate(1)
      if (self$suspend_mobject_updating && !is.null(self$mobject)) self$mobject$resume_updating()
    },
    clean_up_from_scene = function(scene) {
      if (!is.null(self$on_finish)) self$on_finish(scene)
      if (self$is_remover()) scene$remove(self$mobject)
    },
    setup_scene = function(scene) {
      if (is.null(scene)) return(invisible(NULL))
      if (self$is_introducer()) {
        ids <- vapply(scene$get_mobject_family_members(), function(m) m$mob_id, "")
        if (!self$mobject$mob_id %in% ids) scene$add(self$mobject)
      }
    },
    create_starting_mobject = function() self$mobject$copy(),
    get_all_mobjects = function() list(self$mobject, self$starting_mobject),
    get_all_families_zipped = function() {
      fams <- lapply(self$get_all_mobjects(), function(m) m$family_members_with_points())
      n <- min(lengths(fams))
      lapply(seq_len(n), function(i) lapply(fams, `[[`, i))
    },
    update_mobjects = function(dt) {
      for (m in self$get_all_mobjects_to_update()) m$update(dt)
    },
    get_all_mobjects_to_update = function() {
      Filter(function(m) !identical(m$mob_id, self$mobject$mob_id), self$get_all_mobjects())
    },
    anim_id = NULL,
    copy = function(.memo = NULL) {
      if (is.null(.memo)) .memo <- new.env(parent = emptyenv())
      if (is.null(self$anim_id)) self$anim_id <- paste0("anim", next_mob_id())
      if (!is.null(.memo[[self$anim_id]])) return(.memo[[self$anim_id]])
      new <- fast_clone(self)
      new$anim_id <- paste0("anim", next_mob_id())
      assign(self$anim_id, new, envir = .memo)
      for (nm in mobject_fields(self)) {
        v <- self[[nm]]
        if (is_mobject(v) || inherits(v, "Animation") || (is.list(v) && length(v) && !is.data.frame(v))) {
          new[[nm]] <- copy_nested(v, .memo)
        }
      }
      copy_private_nested(self, new, .memo)
      new
    },
    interpolate = function(alpha) self$interpolate_mobject(alpha),
    interpolate_mobject = function(alpha) {
      families <- self$get_all_families_zipped()
      n <- length(families)
      for (i in seq_len(n)) {
        sub_alpha <- self$get_sub_alpha(alpha, i - 1, n)
        do.call(self$interpolate_submobject, c(families[[i]], list(sub_alpha)))
      }
    },
    interpolate_submobject = function(submobject, starting_submobject, ...) invisible(self),
    get_sub_alpha = function(alpha, index, num_submobjects) {
      lag <- self$lag_ratio
      full <- (num_submobjects - 1) * lag + 1
      value <- alpha * full
      lower <- index * lag
      if (self$reverse_rate_function) self$rate_func(1 - (value - lower)) else self$rate_func(value - lower)
    },
    set_run_time = function(run_time) {
      self$run_time <- run_time
      invisible(self)
    },
    get_run_time = function() self$run_time,
    set_rate_func = function(rate_func) {
      self$rate_func <- rate_func
      invisible(self)
    },
    get_rate_func = function() self$rate_func,
    set_name = function(name) {
      self$name <- name
      invisible(self)
    },
    is_remover = function() isTRUE(self$remover),
    is_introducer = function() isTRUE(self$introducer)
  )
)

#' @rdname AnimationClass
#' @export
Animation <- constructor(AnimationClass)
#' Convert to an animation
#'
#' Turns `mob$animate` builders into animations; animations pass through.
#'
#' @param anim An animation or animation builder.
#' @export
prepare_animation <- function(anim) {
  if (inherits(anim, "manim_animation_builder")) return(build_animation(anim))
  if (inherits(anim, "Animation")) return(anim)
  stop("Object of class ", class(anim)[1], " cannot be converted to an animation", call. = FALSE)
}

#' @title Wait
#' @description An animation that does nothing for `run_time` seconds.
#' @param run_time Duration.
#' @param stop_condition Function returning `TRUE` to stop early.
#' @param frozen_frame Whether the frame is static.
#' @param rate_func Rate function.
#' @param ... Passed to [Animation()].
#' @export
WaitClass <- R6::R6Class("Wait", inherit = AnimationClass, lock_objects = FALSE,
  public = list(
    duration = 1,
    stop_condition = NULL,
    is_static_wait = NULL,
    initialize = function(run_time = 1, stop_condition = NULL, frozen_frame = NULL, rate_func = linear, ...) {
      if (!is.null(stop_condition) && isTRUE(frozen_frame)) {
        stop("A static Wait animation cannot have a stop condition.", call. = FALSE)
      }
      self$duration <- run_time
      self$stop_condition <- stop_condition
      self$is_static_wait <- frozen_frame
      super$initialize(NULL, run_time = run_time, rate_func = rate_func, ...)
    },
    begin = function() invisible(NULL),
    finish = function() invisible(NULL),
    clean_up_from_scene = function(scene) invisible(NULL),
    update_mobjects = function(dt) invisible(NULL),
    interpolate = function(alpha) invisible(NULL)
  )
)

#' @rdname WaitClass
#' @export
Wait <- constructor(WaitClass)
#' @title Add
#' @description Adds mobjects to the scene instantly, useful inside
#'   [Succession()].
#' @param ... Mobjects, then named arguments passed to [Animation()].
#' @param run_time Duration in seconds; zero adds the mobjects instantly.
#' @param use_override `FALSE` ignores an override of `Add` set with
#'   [override_animation()] on the first mobject's class.
#' @export
Add <- function(..., run_time = 0, use_override = TRUE) {
  args <- list(...)
  nm <- names(args) %||% rep("", length(args))
  mobs <- args[nm == ""]
  # As upstream's Animation.__new__, an override of Add on the first
  # mobject's class builds the animation instead.
  if (isTRUE(use_override) && length(mobs) && is_mobject(mobs[[1]])) {
    override <- .subset2(mobs[[1]], "animation_override_Add")
    if (is.function(override)) {
      return(do.call(override, c(mobs[-1], list(run_time = run_time), args[nm != ""])))
    }
  }
  mob <- if (length(mobs) == 1) mobs[[1]] else do.call(Group, mobs)
  do.call(AddClass$new, c(list(mob, run_time = run_time, introducer = TRUE), args[nm != ""]))
}

AddClass <- R6::R6Class("Add", inherit = AnimationClass, lock_objects = FALSE,
  public = list(
    begin = function() invisible(NULL),
    finish = function() invisible(NULL),
    clean_up_from_scene = function(scene) invisible(NULL),
    update_mobjects = function(dt) invisible(NULL),
    interpolate = function(alpha) invisible(NULL)
  )
)

# Animation builder for mob$animate ------------------------------------------

animation_builder <- function(mobject) {
  state <- new.env(parent = emptyenv())
  state$mobject <- mobject
  mobject$generate_target()
  state$methods <- list()
  state$anim_args <- list()
  state$cannot_pass_args <- FALSE
  b <- function(...) {
    if (state$cannot_pass_args) {
      stop("Animation arguments must be passed before accessing methods and can only be passed once", call. = FALSE)
    }
    state$anim_args <- list(...)
    state$cannot_pass_args <- TRUE
    b
  }
  attr(b, "state") <- state
  class(b) <- "manim_animation_builder"
  b
}

#' @export
`$.manim_animation_builder` <- function(x, name) {
  state <- attr(x, "state")
  # Mobjects can supply their own animation for a method, like upstream's
  # override_animate (for example Graph$animate$add_vertices).
  override <- state$mobject[[paste0("animate_override_", name)]]
  if (is.function(override)) {
    return(function(...) do.call(override, c(list(...), list(anim_args = state$anim_args))))
  }
  target <- state$mobject$target
  method <- target[[name]]
  if (!is.function(method)) stop("Mobject has no method '", name, "'", call. = FALSE)
  state$cannot_pass_args <- TRUE
  function(...) {
    state$methods[[length(state$methods) + 1]] <- list(name = name, args = list(...))
    method(...)
    x
  }
}

#' @export
print.manim_animation_builder <- function(x, ...) {
  state <- attr(x, "state")
  cat("<animation builder> ", class(state$mobject)[1], ": ",
      paste(vapply(state$methods, `[[`, "", "name"), collapse = " -> "), "\n", sep = "")
  invisible(x)
}

build_animation <- function(builder) {
  state <- attr(builder, "state")
  anim <- MethodAnimationClass$new(state$mobject, state$methods)
  for (k in names(state$anim_args)) anim[[k]] <- state$anim_args[[k]]
  anim
}

updater_builder <- function(mobject) {
  structure(list(mobject = mobject), class = "manim_updater_builder")
}

#' @export
`$.manim_updater_builder` <- function(x, name) {
  mob <- .subset2(x, "mobject")
  function(...) {
    args <- list(...)
    mob$add_updater(function(m) do.call(m[[name]], args), call_updater = TRUE)
    x
  }
}

#' Override animations for a mobject class
#'
#' `override_animation()` makes an animation constructor build something else
#' for one mobject class, like upstream's `@override_animation` decorator:
#' after `override_animation(MyMobClass, "FadeIn", function(...) ...)`,
#' `FadeIn(my_mob, ...)` calls the function as a method of `my_mob` (so it
#' can use `self`) with the remaining arguments, and returns its result.
#' Pass `use_override = FALSE` to the constructor to get the normal
#' animation. Only the package's constructor functions (such as `FadeIn()`)
#' check for overrides, not `FadeInClass$new()`.
#'
#' `override_animate()` customizes `mob$animate$method(...)`, like upstream's
#' `@override_animate`: the function is called as a method of the mobject
#' with the method's arguments plus `anim_args`, the list of arguments given
#' to `animate` (such as `run_time`), and returns an animation.
#'
#' Both change the class generator in place (with `$set()`), so they apply
#' to objects created afterwards, including objects of subclasses.
#'
#' @param mobject_class A mobject class generator, such as `SquareClass` or
#'   your own R6 class.
#' @param animation An animation class name, such as `"FadeIn"`, or its
#'   generator (`FadeInClass`).
#' @param method Name of the mobject method to customize under `$animate`.
#' @param fn The override function.
#' @return The class generator, invisibly.
#' @export
#' @examples
#' Pulse <- R6::R6Class("Pulse", inherit = CircleClass, lock_objects = FALSE)
#' override_animation(Pulse, "FadeIn", function(...) GrowFromCenter(self, ...))
#' class(FadeIn(Pulse$new()))[1]
override_animation <- function(mobject_class, animation, fn) {
  name <- if (inherits(animation, "R6ClassGenerator")) animation$classname else animation
  mobject_class$set("public", paste0("animation_override_", name), fn, overwrite = TRUE)
  invisible(mobject_class)
}

#' @rdname override_animation
#' @export
override_animate <- function(mobject_class, method, fn) {
  mobject_class$set("public", paste0("animate_override_", method), fn, overwrite = TRUE)
  invisible(mobject_class)
}

#' Check that a function is a mobject method
#'
#' Errors unless `method` is a method of a mobject, such as `sq$shift`.
#'
#' @param method A function.
#' @return `method`, invisibly.
#' @export
assert_is_mobject_method <- function(method) {
  self <- if (is.function(method)) get0("self", envir = environment(method), inherits = FALSE)
  if (!is_mobject(self)) stop("Expected a method of a mobject, such as sq$shift", call. = FALSE)
  invisible(method)
}
