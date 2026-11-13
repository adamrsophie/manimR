# Scene: holds mobjects and plays animations. Ported from manim/scene/scene.py.

#' @title Scene
#' @description The canvas on which animations play. Subclass it and define
#'   `construct()`, then pass the class to [render()]:
#'
#' ```r
#' SquareToCircle <- R6::R6Class("SquareToCircle", inherit = Scene,
#'   public = list(construct = function() {
#'     circle <- Circle()$set_fill(PINK, opacity = 0.5)
#'     square <- Square()$rotate(PI / 4)
#'     self$play(Create(square))
#'     self$play(Transform(square, circle))
#'     self$play(FadeOut(square))
#'   }))
#' render(SquareToCircle, quality = "l")
#' ```
#'
#' Or use the functional form [manim_scene()].
#' @return An R6 class generator. A scene class inherits from it, and `$new()`
#'   creates a scene.
#' @export
Scene <- R6::R6Class("Scene", lock_objects = FALSE,
  public = list(
    renderer = NULL,
    manager = NULL,
    camera = NULL,
    mobjects = NULL,
    foreground_mobjects = NULL,
    moving_mobjects = NULL,
    static_mobjects = NULL,
    animations = NULL,
    updaters = NULL,
    duration = 0,
    last_t = 0,
    stop_condition = NULL,
    always_update_mobjects = FALSE,
    random_seed = NULL,
    camera_class = NULL,
    skip_animations = FALSE,
    session_spec = NULL,
    output_plan = NULL,
    file_writer_settings = NULL,
    initialize = function(renderer = NULL, camera_class = NULL, always_update_mobjects = FALSE,
                          random_seed = NULL, skip_animations = FALSE, ...) {
      self$camera_class <- camera_class %||% self$default_camera_class()
      self$always_update_mobjects <- always_update_mobjects
      self$random_seed <- random_seed %||% cfg("seed")
      self$skip_animations <- skip_animations
      # As upstream, config$renderer = "opengl" draws with the OpenGL
      # renderer; scenes with their own camera class keep the Cairo one,
      # whose cameras they drive.
      if (is.null(renderer) && identical(cfg("renderer"), RendererType$OPENGL) &&
          identical(self$camera_class, CameraClass)) {
        renderer <- OpenGLRendererClass$new(skip_animations = skip_animations)
      }
      self$renderer <- renderer %||% CairoRendererClass$new(camera_class = self$camera_class,
                                                            skip_animations = skip_animations, ...)
      self$camera <- self$renderer$camera
      self$init_output()
      if (!is.null(self$random_seed)) set.seed(self$random_seed)
      self$mobjects <- list()
      self$foreground_mobjects <- list()
      self$moving_mobjects <- list()
      self$static_mobjects <- list()
      self$animations <- list()
      self$updaters <- list()
    },
    default_camera_class = function() CameraClass,
    scene_name_override = NULL,
    scene_name = function() self$scene_name_override %||% class(self)[1],
    print = function(...) {
      cat("<", class(self)[1], "> ", length(self$mobjects), " mobjects\n", sep = "")
      invisible(self)
    },

    # Lifecycle -------------------------------------------------------------
    setup = function() invisible(NULL),
    construct = function() invisible(NULL),
    tear_down = function() invisible(NULL),
    # Resolves what this scene's render writes, from the current settings,
    # as upstream's Scene.__init__ does: the render session, the output
    # paths, the file writer settings and the optional log file.
    # `module_name` and `output_file` override the settings of those names.
    init_output = function(module_name = NULL, output_file = NULL) {
      self$session_spec <- resolve_render_session(self$renderer$capabilities %||% RendererCapabilities(),
                                                  renderer_name = class(self$renderer)[1])
      module <- module_name %||% resolve_module_name()
      wd <- getwd()
      layout <- resolve_media_layout(self$session_spec$output, module, self$scene_name(), wd)
      self$output_plan <- resolve_output_plan(layout, self$session_spec$output, self$scene_name(),
                                              output_file %||% get_dir("output_file"))
      self$file_writer_settings <- scene_file_writer_settings(self$output_plan, self$session_spec$video_encoder, wd)
      log_file <- resolve_file_log_path(layout, module, self$scene_name())
      if (!is.null(log_file)) {
        dir.create(dirname(log_file), recursive = TRUE, showWarnings = FALSE)
        file.create(log_file)
        .manim$log_file <- log_file
        logger$info("Log file will be saved in %s", log_file)
      }
      self$renderer$init_scene(self, self$session_spec, self$file_writer_settings)
      invisible(self)
    },
    # Rendering runs through the scene's Manager (created on first use), as
    # upstream's Scene.render() does. Returns the path of the artifact.
    render = function(preview = FALSE, module_name = NULL, output_file = NULL) {
      if (!is.null(module_name) || !is.null(output_file) || !is.null(self$scene_name_override)) {
        self$init_output(module_name, output_file)
      }
      self$get_manager()$render(preview = preview)
    },
    get_manager = function() self$manager %||% ManagerClass$new(self),

    # Time ------------------------------------------------------------------
    get_time = function() self$renderer$time,

    # Mobject management ----------------------------------------------------
    get_mobject_family_members = function() {
      extract_mobject_family_members(self$mobjects, use_z_index = self$camera$use_z_index)
    },
    add = function(...) {
      mobs <- flatten_mobjects(list(...))
      mobs <- c(mobs, self$foreground_mobjects)
      self$restructure_mobjects(mobs)
      self$mobjects <- c(self$mobjects, mobs)
      if (length(self$moving_mobjects)) {
        self$restructure_mobjects(mobs, "moving_mobjects")
        self$moving_mobjects <- c(self$moving_mobjects, mobs)
      }
      invisible(self)
    },
    add_mobjects_from_animations = function(animations) {
      curr <- vapply(self$get_mobject_family_members(), function(m) m$mob_id, "")
      for (a in animations) {
        if (a$is_introducer()) next
        mob <- a$mobject
        if (!is.null(mob) && !mob$mob_id %in% curr) {
          self$add(mob)
          curr <- c(curr, vapply(mob$get_family(), function(m) m$mob_id, ""))
        }
      }
      invisible(self)
    },
    remove = function(...) {
      mobs <- flatten_mobjects(list(...))
      for (ln in c("mobjects", "foreground_mobjects")) self$restructure_mobjects(mobs, ln, extract_families = FALSE)
      invisible(self)
    },
    replace = function(old_mobject, new_mobject) {
      if (is.null(old_mobject) || is.null(new_mobject)) stop("Specified mobjects cannot be None", call. = FALSE)
      # Replaces in the list `get()` returns and stores the result with
      # `set()`; an earlier reference to the replacement is dropped first.
      replace_in <- function(get, set) {
        lst <- get()
        ids <- vapply(lst, function(m) m$mob_id, "")
        at <- match(new_mobject$mob_id, ids)
        if (!is.na(at)) {
          if (identical(old_mobject$mob_id, new_mobject$mob_id)) {
            logger$warning(paste0("Attempted to replace ", class(old_mobject)[1], " with itself in Scene.mobjects."))
            return(TRUE)
          }
          lst <- lst[-at]
          ids <- ids[-at]
          set(lst)
        }
        at <- match(old_mobject$mob_id, ids)
        if (!is.na(at)) {
          lst[[at]] <- new_mobject
          set(lst)
          return(TRUE)
        }
        for (mob in lst) {
          if (replace_in(function() mob$submobjects, function(v) mob$submobjects <- v)) return(TRUE)
        }
        FALSE
      }
      replaced <- replace_in(function() self$mobjects, function(v) self$mobjects <- v) ||
        replace_in(function() self$foreground_mobjects, function(v) self$foreground_mobjects <- v)
      if (!replaced) stop("Could not find ", class(old_mobject)[1], " in scene", call. = FALSE)
      invisible(self)
    },
    restructure_mobjects = function(to_remove, mobject_list_name = "mobjects", extract_families = TRUE) {
      if (extract_families) to_remove <- extract_mobject_family_members(to_remove, use_z_index = self$camera$use_z_index)
      self[[mobject_list_name]] <- get_restructured_mobject_list(self[[mobject_list_name]], to_remove)
      invisible(self)
    },
    add_foreground_mobjects = function(...) {
      mobs <- flatten_mobjects(list(...))
      self$foreground_mobjects <- list_update(self$foreground_mobjects, mobs)
      self$add(mobs)
    },
    add_foreground_mobject = function(mobject) self$add_foreground_mobjects(mobject),
    remove_foreground_mobjects = function(...) {
      self$restructure_mobjects(flatten_mobjects(list(...)), "foreground_mobjects")
      invisible(self)
    },
    remove_foreground_mobject = function(mobject) self$remove_foreground_mobjects(mobject),
    bring_to_front = function(...) {
      self$add(...)
    },
    bring_to_back = function(...) {
      mobs <- flatten_mobjects(list(...))
      self$restructure_mobjects(mobs)
      self$mobjects <- c(mobs, self$mobjects)
      invisible(self)
    },
    clear = function() {
      self$mobjects <- list()
      self$foreground_mobjects <- list()
      invisible(self)
    },
    get_top_level_mobjects = function() {
      fams <- lapply(self$mobjects, function(m) vapply(m$get_family()[-1], function(x) x$mob_id, ""))
      all_sub <- unlist(fams)
      Filter(function(m) !m$mob_id %in% all_sub, self$mobjects)
    },
    get_mobjects = function() self$mobjects,

    # Updaters -------------------------------------------------------------
    add_updater = function(func) {
      self$updaters <- c(self$updaters, list(func))
      invisible(self)
    },
    remove_updater = function(func) {
      self$updaters <- Filter(function(f) !identical(f, func), self$updaters)
      invisible(self)
    },
    update_mobjects = function(dt) {
      for (m in self$mobjects) m$update(dt)
      invisible(self)
    },
    update_self = function(dt) {
      for (f in self$updaters) f(dt)
      invisible(self)
    },
    should_update_mobjects = function() {
      wait_anim <- self$animations[[1]]
      if (is.null(wait_anim$is_static_wait)) {
        should <- self$always_update_mobjects || length(self$updaters) > 0 ||
          !is.null(wait_anim$stop_condition) ||
          any(vapply(self$get_mobject_family_members(), function(m) m$has_time_based_updater(), logical(1)))
        wait_anim$is_static_wait <- !should
      }
      !isTRUE(wait_anim$is_static_wait)
    },

    # Animations -----------------------------------------------------------
    get_moving_mobjects = function(...) {
      # The animations, given one by one as upstream or as one list.
      animations <- list(...)
      if (length(animations) == 1 && is.list(animations[[1]])) animations <- animations[[1]]
      # Families of every animation's mobject, recursing into animation
      # groups, so a mobject animated inside an AnimationGroup is never
      # frozen into the static frame cache (as upstream).
      collect <- function(anims) {
        ids <- character()
        for (a in anims) {
          ids <- c(ids, vapply(a$mobject$get_family(), function(m) m$mob_id, ""))
          if (inherits(a, "AnimationGroup")) ids <- c(ids, collect(a$animations))
        }
        ids
      }
      anim_ids <- unique(collect(animations))
      fg <- vapply(self$foreground_mobjects, function(m) m$mob_id, "")
      consider_moving <- function(m) {
        m$mob_id %in% anim_ids || length(m$updaters) > 0 || m$mob_id %in% fg ||
          any(vapply(m$submobjects, consider_moving, NA))
      }
      mobs <- self$get_mobject_family_members()
      for (i in seq_along(mobs)) if (consider_moving(mobs[[i]])) return(mobs[i:length(mobs)])
      list()
    },
    get_moving_and_static_mobjects = function(animations) {
      all_fams <- extract_mobject_family_members(list_update(self$mobjects, self$foreground_mobjects),
                                                 use_z_index = self$camera$use_z_index)
      moving <- self$get_moving_mobjects(animations)
      moving_fams <- extract_mobject_family_members(moving, use_z_index = self$camera$use_z_index)
      mids <- vapply(moving_fams, function(m) m$mob_id, "")
      static <- Filter(function(m) !m$mob_id %in% mids, all_fams)
      list(moving = moving_fams, static = static)
    },
    compile_animations = function(...) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      kwargs <- args[nm != ""]
      anims <- lapply(flatten_animation_args(args[nm == ""]), prepare_animation)
      for (a in anims) for (k in names(kwargs)) a[[k]] <- kwargs[[k]]
      anims
    },
    compile_animation_data = function(...) {
      self$animations <- self$compile_animations(...)
      self$add_mobjects_from_animations(self$animations)
      self$last_t <- 0
      self$stop_condition <- NULL
      self$moving_mobjects <- list()
      self$static_mobjects <- list()
      self$duration <- self$get_run_time(self$animations)
      if (length(self$animations) == 1 && inherits(self$animations[[1]], "Wait")) {
        if (self$should_update_mobjects()) {
          self$update_mobjects(dt = 0)
          self$stop_condition <- self$animations[[1]]$stop_condition
        } else {
          self$animations[[1]]$is_static_wait <- TRUE
        }
      }
      invisible(self)
    },
    begin_animations = function() {
      for (a in self$animations) {
        a$setup_scene(self)
        a$begin()
      }
      ms <- self$get_moving_and_static_mobjects(self$animations)
      self$moving_mobjects <- ms$moving
      self$static_mobjects <- ms$static
      invisible(self)
    },
    is_current_animation_frozen_frame = function() {
      length(self$animations) == 1 && inherits(self$animations[[1]], "Wait") &&
        isTRUE(self$animations[[1]]$is_static_wait)
    },
    get_run_time = function(animations) {
      rt <- max(vapply(animations, function(a) a$get_run_time(), numeric(1)), 0)
      validate_run_time(rt, "Scene$play()", "total run_time")
    },
    play = function(..., subcaption = NULL, subcaption_duration = NULL, subcaption_offset = 0) {
      args <- list(...)
      if (length(args) == 0) {
        warning("Called Scene$play with no animations", call. = FALSE)
        return(invisible(self))
      }
      self$get_manager()$play(..., subcaption = subcaption, subcaption_duration = subcaption_duration,
                              subcaption_offset = subcaption_offset)
      invisible(self)
    },
    wait = function(duration = DEFAULT_WAIT_TIME, stop_condition = NULL, frozen_frame = NULL) {
      duration <- validate_run_time(duration, "Scene$wait()", "duration")
      self$play(Wait(run_time = duration, stop_condition = stop_condition, frozen_frame = frozen_frame))
    },
    pause = function(duration = DEFAULT_WAIT_TIME) {
      duration <- validate_run_time(duration, "Scene$pause()", "duration")
      self$wait(duration = duration, frozen_frame = TRUE)
    },
    wait_until = function(stop_condition, max_time = 60) {
      max_time <- validate_run_time(max_time, "Scene$wait_until()", "max_time")
      self$wait(max_time, stop_condition = stop_condition)
    },
    play_internal = function(skip_rendering = FALSE) {
      self$duration <- self$get_run_time(self$animations)
      fps <- self$camera$frame_rate
      # A conditional wait steps through frames even when skipping, so it
      # stops where its condition first holds (upstream's
      # override_skip_animations).
      conditional <- length(self$animations) == 1 && inherits(self$animations[[1]], "Wait") &&
        !is.null(self$stop_condition)
      times <- if (self$renderer$skip_animations && !conditional) self$duration else {
        n <- ceiling(self$duration * fps - 1e-9)
        if (n > 0) (seq_len(n) - 1) / fps else numeric()
      }
      pb <- if (!self$renderer$skip_animations && length(times) > 1 && show_progress_bar()) {
        message(sprintf("Animation %d: %s", self$renderer$num_plays,
                        paste(vapply(self$animations, function(a) class(a)[1], ""), collapse = ", ")))
        utils::txtProgressBar(min = 0, max = length(times), style = 3, file = stderr())
      }
      if (!is.null(pb)) on.exit(close(pb), add = TRUE)
      for (k in seq_along(times)) {
        t <- times[k]
        self$update_to_time(t)
        if (!skip_rendering) self$renderer$render(self, t, self$moving_mobjects)
        if (!is.null(pb)) utils::setTxtProgressBar(pb, k)
        if (!is.null(self$stop_condition) && isTRUE(self$stop_condition())) break
      }
      for (a in self$animations) {
        a$finish()
        a$clean_up_from_scene(self)
      }
      if (!self$renderer$skip_animations) self$update_mobjects(0)
      self$renderer$static_image <- NULL
      invisible(self)
    },
    update_to_time = function(t) {
      dt <- t - self$last_t
      self$last_t <- t
      for (a in self$animations) {
        a$update_mobjects(dt)
        rt <- a$run_time
        a$interpolate(if (rt > 0) t / rt else 1)
      }
      self$update_mobjects(dt)
      self$update_self(dt)
      invisible(self)
    },
    add_subcaption = function(content, duration = 1, offset = 0) {
      self$get_manager()$add_subcaption(content, duration, offset)
      invisible(self)
    },
    # Like upstream, no sound is added while animations are skipped.
    # `gain_to_background` lowers the sounds added earlier by that many
    # decibels while this one plays.
    add_sound = function(sound_file, time_offset = 0, gain = NULL, ...) {
      self$get_manager()$add_sound(sound_file, time_offset, gain, ...)
      invisible(self)
    },
    # Starts a new section; the previous one is finished. With
    # manim_config(save_sections = TRUE) each section is also written to its
    # own video under `sections/` next to the movie, with a JSON index.
    # `skip_animations = TRUE` skips rendering every animation in the section.
    next_section = function(name = "unnamed", section_type = DefaultSectionType$NORMAL, skip_animations = FALSE) {
      self$get_manager()$next_section(name, section_type, skip_animations)
      invisible(self)
    }
  ),
  active = list(
    time = function(value) {
      if (!missing(value)) stop("Scene time is read-only", call. = FALSE)
      self$renderer$time
    }
  )
)

validate_run_time <- function(run_time, method_name, parameter_name = "run_time") {
  if (run_time <= 0) {
    stop(method_name, " has a ", parameter_name, " of ", format(run_time), " <= 0 seconds which manimR cannot render. ",
         "The ", parameter_name, " must be a positive number.", call. = FALSE)
  }
  spf <- 1 / cfg("frame_rate")
  if (run_time < spf) {
    warning("The original ", parameter_name, " of ", method_name, ", ", format(run_time),
            " seconds, is too short for the current frame rate of ", cfg("frame_rate"),
            " FPS. Rendering with the shortest possible ", parameter_name, " of ", format(spf), " seconds instead.",
            call. = FALSE)
    run_time <- spf
  }
  run_time
}

get_restructured_mobject_list <- function(mobjects, to_remove) {
  rm_ids <- vapply(to_remove, function(m) m$mob_id, "")
  out <- list()
  walk <- function(lst, ids) {
    for (m in lst) {
      if (m$mob_id %in% ids) next
      fam <- vapply(m$get_family(), function(x) x$mob_id, "")
      inter <- intersect(ids, fam)
      if (length(inter)) walk(m$submobjects, inter) else out[[length(out) + 1]] <<- m
    }
  }
  walk(mobjects, rm_ids)
  out
}

flatten_animation_args <- function(args) {
  out <- list()
  for (a in args) {
    if (inherits(a, "Animation") || inherits(a, "manim_animation_builder")) out[[length(out) + 1]] <- a
    else if (is.list(a)) out <- c(out, flatten_animation_args(a))
    else stop("Object of class ", class(a)[1], " cannot be converted to an animation", call. = FALSE)
  }
  out
}

#' Define a scene from a function
#'
#' Creates a [Scene] subclass whose `construct()` calls `construct(self)`.
#'
#' @param construct A function of one argument, the scene.
#' @param name Class name, used for the output file name.
#' @param base Scene class to inherit from, such as `MovingCameraScene`.
#' @param setup Optional function of the scene called before `construct`.
#' @return An R6 class generator that can be passed to [render()].
#' @export
#' @examples
#' MyScene <- manim_scene(function(self) {
#'   self$play(Create(Circle()))
#' }, name = "MyScene")
manim_scene <- function(construct, name = "Scene", base = Scene, setup = NULL) {
  force(construct)
  force(setup)
  pub <- list(construct = function() construct(self))
  if (!is.null(setup)) pub$setup <- function() {
    super$setup()
    setup(self)
  }
  R6::R6Class(name, inherit = base, lock_objects = FALSE, public = pub)
}

# A progress bar per animation, as upstream's tqdm bar, in interactive
# sessions and the command line (not while knitting). progress_bar is
# TRUE, "display" or "leave" to show it, FALSE or "none" to hide it.
show_progress_bar <- function() {
  pb <- cfg("progress_bar")
  on <- isTRUE(pb) || (is.character(pb) && pb %in% c("display", "leave"))
  on && !isTRUE(getOption("knitr.in.progress")) && (interactive() || isTRUE(.manim$cli_running))
}
