# Hashes of play calls for the partial movie cache, the counterpart of
# manim/utils/hashing.py. A play is identified by the camera, its animations
# and the scene's mobjects; when a partial movie file with that hash exists,
# the play is not rendered again.

# A plain, serializable description of a value: numbers, strings and
# matrices as they are; mobjects by their drawing state; functions by their
# code and the plain values they capture (like upstream's use of
# inspect.getclosurevars); other environments are left out.
hash_snapshot <- function(x, depth = 0) {
  if (depth > 6 || is.null(x)) return(NULL)
  if (is_mobject(x)) return(snapshot_mobject(x, depth))
  if (inherits(x, "Animation")) return(snapshot_animation(x, depth))
  if (is.function(x)) return(snapshot_function(x, depth))
  if (is.environment(x)) return(NULL)
  if (is.atomic(x)) return(x)
  if (is.list(x)) return(lapply(x, hash_snapshot, depth = depth + 1))
  NULL
}

snapshot_function <- function(f, depth) {
  if (is.primitive(f)) return(deparse(f))
  env <- environment(f)
  captured <- NULL
  if (!is.null(env) && !isNamespace(env) && !identical(env, globalenv()) && !identical(env, baseenv()) &&
      !identical(env, emptyenv()) && is.null(get0(".__enclos_env__", envir = env, inherits = FALSE)) &&
      is.null(get0("self", envir = env, inherits = FALSE))) {
    vals <- mget(ls(env, all.names = TRUE), envir = env)
    captured <- lapply(vals[!vapply(vals, is.environment, NA)], hash_snapshot, depth = depth + 1)
  }
  list(code = deparse(f), captured = captured)
}

# Fields of an R6 object that hold data rather than methods. R6 locks the
# bindings of methods, so a function stored in a field (a rate function, an
# updater) counts as data.
data_fields <- function(obj, skip = character()) {
  active <- names(get0(".__active__", envir = .subset2(obj, ".__enclos_env__"), inherits = FALSE))
  nms <- setdiff(names(obj), c(".__enclos_env__", ".__active__", active, skip))
  nms <- nms[!vapply(nms, bindingIsLocked, NA, env = obj)]
  vals <- mget(nms, envir = obj)
  vals[!vapply(vals, function(v) is.function(v) && !is.null(get0("self", envir = environment(v), inherits = FALSE)),
               NA)]
}

snapshot_mobject <- function(m, depth) {
  fields <- data_fields(m, skip = c("submobjects", "mob_id", "saved_state", "target", "updaters", "name",
                                    "z_index_group", "manager"))
  plain <- fields[vapply(fields, function(v) is.atomic(v) || (is.list(v) && !length(Filter(is.environment, v))), NA)]
  list(class = class(m)[1], fields = lapply(plain, hash_snapshot, depth = depth + 1),
       updaters = lapply(m$updaters, hash_snapshot, depth = depth + 1),
       submobjects = lapply(m$submobjects, snapshot_mobject, depth = depth + 1))
}

snapshot_animation <- function(a, depth) {
  fields <- data_fields(a, skip = c("starting_mobject", "anim_id"))
  list(class = class(a)[1], fields = lapply(fields, hash_snapshot, depth = depth + 1))
}

snapshot_camera <- function(cam) {
  fields <- data_fields(cam, skip = c("pixel_array", "background", "background_colored_vmobject_displayer"))
  list(class = class(cam)[1], fields = lapply(fields, hash_snapshot, depth = 1))
}

# The hash of a play call: of the camera, the animations and the mobjects.
get_hash_from_play_call <- function(scene, camera, animations, mobjects) {
  parts <- c(digest::digest(snapshot_camera(camera), algo = "xxhash32"),
             digest::digest(lapply(animations, hash_snapshot), algo = "xxhash32"),
             digest::digest(lapply(mobjects, hash_snapshot), algo = "xxhash32"))
  paste(parts, collapse = "_")
}
