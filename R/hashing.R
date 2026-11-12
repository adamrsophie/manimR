# Hashes of play calls for the partial movie cache, the counterpart of
# manim/utils/hashing.py. A play is identified by the renderer, the segment
# encoder settings, the camera, its animations and the scene's mobjects;
# when a partial movie file with that hash exists, the play is not rendered
# again.

# Upstream warns when a hash has to visit this many objects.
HASH_THRESHOLD_WARNING <- 170000
HASH_ALREADY_PROCESSED <- "<already processed>"

# A memo of the objects a hash has visited, as upstream's _Memoizer: an
# object seen a second time becomes a placeholder, which also ends cycles.
hash_memo <- function() {
  memo <- new.env(parent = emptyenv())
  memo$seen <- new.env(parent = emptyenv())
  memo$count <- 0
  memo
}

# TRUE the first time `key` is visited.
memo_visit <- function(memo, key) {
  if (is.null(memo) || is.null(key)) return(TRUE)
  if (!is.null(memo$seen[[key]])) return(FALSE)
  memo$count <- memo$count + 1
  if (memo$count == HASH_THRESHOLD_WARNING && !isTRUE(cfg("disable_caching_warning"))) {
    logger$warning(paste("It looks like the scene contains a lot of sub-mobjects. Caching is sometimes not suited",
                         "to handle such large scenes, you might consider disabling caching with",
                         "disable_caching = TRUE to potentially speed up the rendering process."))
    logger$warning("You can disable this warning by setting disable_caching_warning to TRUE in your config file.")
  }
  assign(key, TRUE, envir = memo$seen)
  TRUE
}

env_key <- function(env) sub("^<environment: (.*)>$", "\\1", utils::capture.output(print.default(env))[1])

# A plain, serializable description of a value: numbers, strings and
# matrices as they are; mobjects and animations by their state; functions by
# their code and the values they use from their environments (upstream's
# inspect.getclosurevars globals and nonlocals); other environments are left
# out.
hash_snapshot <- function(x, depth = 0, memo = NULL) {
  if (depth > 12 || is.null(x)) return(NULL)
  if (is_mobject(x)) return(snapshot_mobject(x, depth, memo))
  if (inherits(x, "Animation")) return(snapshot_animation(x, depth, memo))
  if (is.function(x)) return(snapshot_function(x, depth, memo))
  if (is.environment(x)) return(NULL)
  if (is.atomic(x)) return(x)
  if (is.list(x)) return(lapply(x, hash_snapshot, depth = depth + 1, memo = memo))
  NULL
}

# Environments whose bindings are not values captured by a function: the
# global environment's parents (packages, namespaces, base) and the
# enclosing environments of R6 methods.
closure_boundary <- function(env) {
  identical(env, emptyenv()) || identical(env, baseenv()) || isNamespace(env) ||
    startsWith(environmentName(env), "package:") ||
    !is.null(get0("self", envir = env, inherits = FALSE)) ||
    !is.null(get0(".__enclos_env__", envir = env, inherits = FALSE))
}

# The values a function uses from its environments, by name.
closure_values <- function(f) {
  env <- environment(f)
  if (is.null(env)) return(list())
  used <- unique(c(all.names(body(f)), unlist(lapply(formals(f), function(d) if (is.language(d)) all.names(d)))))
  out <- list()
  for (nm in used) {
    e <- env
    while (!closure_boundary(e)) {
      if (exists(nm, envir = e, inherits = FALSE)) {
        out[nm] <- list(get(nm, envir = e, inherits = FALSE))
        break
      }
      if (identical(e, globalenv())) break
      e <- parent.env(e)
    }
  }
  if (!length(out)) return(out)
  out[order(names(out))]
}

snapshot_function <- function(f, depth, memo = NULL) {
  if (is.primitive(f)) return(deparse(f))
  env <- environment(f)
  key <- paste0("fun:", env_key(env), ":", paste(deparse(f), collapse = "\n"))
  if (!memo_visit(memo, key)) return(HASH_ALREADY_PROCESSED)
  vals <- closure_values(f)
  list(code = deparse(f), nonlocals = lapply(vals, hash_snapshot, depth = depth + 1, memo = memo))
}

# Fields of an R6 object that hold data rather than methods. R6 locks the
# bindings of methods, so a function stored in a field (a rate function, an
# updater) counts as data. Private fields count too: they hold settings
# such as a transform's path_arc.
data_fields <- function(obj, skip = character()) {
  active <- names(get0(".__active__", envir = .subset2(obj, ".__enclos_env__"), inherits = FALSE))
  nms <- setdiff(names(obj), c(".__enclos_env__", ".__active__", active, skip))
  nms <- nms[!vapply(nms, bindingIsLocked, NA, env = obj)]
  vals <- mget(nms, envir = obj)
  vals <- vals[!vapply(vals, function(v) {
    is.function(v) && !is.primitive(v) && !is.null(get0("self", envir = environment(v), inherits = FALSE))
  }, NA)]
  priv <- get0("private", envir = .subset2(obj, ".__enclos_env__"), inherits = FALSE)
  if (is.environment(priv)) {
    pn <- setdiff(ls(priv, all.names = TRUE), skip)
    pn <- pn[!vapply(pn, bindingIsLocked, NA, env = priv)]
    pv <- mget(pn, envir = priv)
    names(pv) <- paste0("private.", names(pv))
    vals <- c(vals, pv)
  }
  if (!length(vals)) return(vals)
  vals[order(names(vals))]
}

snapshot_mobject <- function(m, depth, memo = NULL) {
  if (!memo_visit(memo, paste0("mob:", m$mob_id))) return(HASH_ALREADY_PROCESSED)
  fields <- data_fields(m, skip = c("submobjects", "mob_id", "saved_state", "target", "updaters", "name",
                                    "z_index_group", "manager"))
  plain <- fields[vapply(fields, function(v) is.atomic(v) || (is.list(v) && !length(Filter(is.environment, v))), NA)]
  list(class = class(m)[1], fields = lapply(plain, hash_snapshot, depth = depth + 1, memo = memo),
       updaters = lapply(m$updaters, hash_snapshot, depth = depth + 1, memo = memo),
       submobjects = lapply(m$submobjects, snapshot_mobject, depth = depth + 1, memo = memo))
}

snapshot_animation <- function(a, depth, memo = NULL) {
  key <- if (!is.null(a$anim_id)) paste0("anim:", a$anim_id) else NULL
  if (!memo_visit(memo, key)) return(HASH_ALREADY_PROCESSED)
  fields <- data_fields(a, skip = c("starting_mobject", "anim_id"))
  list(class = class(a)[1], fields = lapply(fields, hash_snapshot, depth = depth + 1, memo = memo))
}

snapshot_camera <- function(cam, memo = NULL) {
  fields <- data_fields(cam, skip = c("pixel_array", "background", "background_colored_vmobject_displayer"))
  list(class = class(cam)[1], fields = lapply(fields, hash_snapshot, depth = 1, memo = memo))
}

# The cache key of one play call, as upstream's get_hash_from_play_call(): a
# SHA-256 digest of the renderer backend, the segment encoder fingerprint,
# the camera, the animations (in a stable order), the mobjects and any extra
# renderer state.
get_hash_from_play_call <- function(scene, camera, animations, mobjects, backend = "cairo",
                                    encoder_fingerprint = "none", renderer_state = list()) {
  if (!backend %in% c("cairo", "opengl")) stop("Unsupported cache backend: ", backend, call. = FALSE)
  if (!nzchar(encoder_fingerprint)) stop("An encoder fingerprint is required for cache identity.", call. = FALSE)
  memo <- hash_memo()
  camera_json <- digest::digest(snapshot_camera(camera, memo), algo = "sha256")
  anim_order <- order(vapply(animations, function(a) class(a)[1], ""), method = "radix")
  anims <- vapply(animations[anim_order], function(a) digest::digest(hash_snapshot(a, memo = memo), algo = "sha256"), "")
  mobs <- vapply(mobjects, function(m) digest::digest(hash_snapshot(m, memo = memo), algo = "sha256"), "")
  state <- digest::digest(hash_snapshot(renderer_state, memo = memo), algo = "sha256")
  parts <- list(backend = backend, encoder = encoder_fingerprint, camera = camera_json, animations = anims,
                mobjects = mobs, renderer = state)
  feed <- unlist(lapply(names(parts), function(n) c(n, length(parts[[n]]), parts[[n]])))
  digest::digest(paste(nchar(feed, type = "bytes"), feed, sep = ":", collapse = "|"), algo = "sha256",
                 serialize = FALSE)
}
