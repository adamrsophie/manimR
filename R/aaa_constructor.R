# User facing constructors such as `Circle()` are thin wrappers around R6
# generators. `constructor()` marks a wrapper; `.onLoad()` then gives it the
# arguments of the nearest class initializer, so help pages and RStudio
# completion show the real arguments. This happens at load time because
# parent classes may be defined in files collated later.
constructor <- function(generator) {
  f <- function(...) generator$new(...)
  attr(f, "manim_constructor") <- TRUE
  f
}

find_initializer <- function(generator) {
  g <- generator
  for (i in 1:50) {
    if (is.null(g)) return(NULL)
    init <- g$public_methods$initialize
    if (!is.null(init)) return(init)
    g <- g$get_inherit()
  }
  NULL
}

with_formals <- function(f, args) {
  formals(f) <- args
  f
}

build_constructor <- function(generator) {
  init <- find_initializer(generator)
  first <- if (!is.null(init)) names(formals(init))[1] else "mobject"
  if (is.null(first) || first == "...") first <- "mobject"
  # With an initializer, the constructor takes its arguments, so completion
  # and help show them.
  f <- if (is.null(init)) {
    function(...) manim_new(generator, first, ...)
  } else {
    with_formals(function() {
      mc <- match.call(expand.dots = TRUE)
      mc[[1L]] <- function(...) manim_new(generator, first, ...)
      eval(mc, parent.frame())
    }, formals(init))
  }
  attr(f, "generator") <- generator
  f
}

# The class generator behind a generator, a constructor function such as
# ArrowSquareTip, or a class name.
as_generator <- function(x, what = "class") {
  if (inherits(x, "R6ClassGenerator")) return(x)
  if (is.function(x) && inherits(attr(x, "generator"), "R6ClassGenerator")) return(attr(x, "generator"))
  if (is.character(x) && length(x) == 1) {
    ns <- asNamespace("manimR")
    gen <- get0(paste0(x, "Class"), envir = ns) %||% get0(x, envir = ns)
    if (inherits(gen, "R6ClassGenerator")) return(gen)
    if (is.function(gen) && inherits(attr(gen, "generator"), "R6ClassGenerator")) return(attr(gen, "generator"))
  }
  stop("Expected a ", what, " (a class generator such as ArrowSquareTipClass, its constructor ",
       "ArrowSquareTip, or a class name)", call. = FALSE)
}

# Creates an object, unless its first argument (named `first` in the class
# initializer) is a mobject that overrides this class (see
# override_animation()): then, as upstream's Animation.__new__ does, the
# override builds the result instead. `use_override = FALSE` skips it.
manim_new <- function(generator, first, ...) {
  args <- list(...)
  nm <- names(args) %||% rep("", length(args))
  use <- args$use_override %||% TRUE
  args <- args[nm != "use_override"]
  nm <- nm[nm != "use_override"]
  pos <- if (first %in% nm) which(nm == first)[1] else which(nm == "")[1]
  if (isTRUE(use) && !is.na(pos) && is_mobject(args[[pos]])) {
    override <- .subset2(args[[pos]], paste0("animation_override_", generator$classname))
    if (is.function(override)) return(do.call(override, args[-pos]))
  }
  do.call(generator$new, args)
}

# The same check for animation constructors that are plain functions: call
# as animation_override("Create", mobject, match.call(), parent.frame()) at
# the top of the function. Returns NULL when there is no override, else a
# list holding the override's result, called with the other arguments.
animation_override <- function(name, mobject, call, env, mobject_arg = "mobject") {
  if (!is_mobject(mobject)) return(NULL)
  override <- .subset2(mobject, paste0("animation_override_", name))
  if (!is.function(override)) return(NULL)
  args <- as.list(call)[-1]
  nm <- names(args) %||% rep("", length(args))
  if ("use_override" %in% nm && isFALSE(eval(args$use_override, env))) return(NULL)
  args <- args[!nm %in% c(mobject_arg, "use_override")]
  list(value = do.call(override, lapply(args, eval, env)))
}

finalize_constructors <- function(ns) {
  for (nm in ls(ns, all.names = TRUE)) {
    obj <- get(nm, envir = ns, inherits = FALSE)
    if (is.function(obj) && isTRUE(attr(obj, "manim_constructor"))) {
      assign(nm, build_constructor(environment(obj)$generator), envir = ns)
    }
  }
  invisible(NULL)
}

utils::globalVariables(c("self", "super", "private"))

# A shallow clone of a portable R6 object, equivalent to obj$clone(deep = FALSE)
# but several times faster. Each slice of the object (the object itself, then
# one per superclass) holds every inherited method, about 1200 closures for a
# Circle. R6's generic clone tests each of them against every enclosing
# environment; here the method names of each class are cached once, so their
# environments are reset in one pass, and only the remaining bindings (fields,
# and functions stored in fields) are inspected one by one.
# Mobject and Animation copies go through this, so it dominates scene time.
fast_clone <- function(obj, retry = TRUE) {
  if (is.function(.subset2(obj, "finalize"))) return(obj$clone(deep = FALSE))
  old_b <- list(obj)
  old_e <- list(.subset2(obj, ".__enclos_env__"))
  repeat {
    s <- get0("super", envir = old_e[[length(old_e)]], inherits = FALSE)
    if (is.null(s)) break
    old_b[[length(old_b) + 1L]] <- s
    old_e[[length(old_e) + 1L]] <- .subset2(s, ".__enclos_env__")
  }
  n <- length(old_b)
  old_private <- get0("private", envir = old_e[[1]], inherits = FALSE)
  if (!is.null(old_private) && is.function(get0("finalize", envir = old_private, inherits = FALSE))) {
    return(obj$clone(deep = FALSE))
  }
  layout <- clone_layout(obj, old_b, old_e)
  new_b <- lapply(seq_len(n), function(i) new.env(parent = emptyenv(), hash = FALSE))
  new_e <- lapply(old_e, function(e) new.env(parent = parent.env(e), hash = FALSE))
  new_private <- if (!is.null(old_private)) new.env(parent = emptyenv(), hash = FALSE)
  for (i in seq_len(n)) {
    new_e[[i]]$self <- new_b[[1]]
    if (!is.null(new_private)) new_e[[i]]$private <- new_private
    if (i < n) new_e[[i]]$super <- new_b[[i + 1L]]
    assign(".__enclos_env__", new_e[[i]], envir = new_b[[i]])
  }
  remap <- function(vals, from) {
    for (k in seq_along(vals)) {
      f <- vals[[k]]
      if (!is.function(f) || is.primitive(f)) next
      env <- environment(f)
      for (j in from:n) {
        if (identical(env, old_e[[j]])) {
          environment(f) <- new_e[[j]]
          vals[[k]] <- f
          break
        }
      }
    }
    vals
  }
  for (i in seq_len(n)) {
    active <- get0(".__active__", envir = old_e[[i]], inherits = FALSE)
    nms <- names(old_b[[i]])
    meth <- character()
    for (j in names(layout[[i]])) {
      m <- layout[[i]][[j]]
      m <- m[m %in% nms]
      fns <- mget(m, envir = old_b[[i]])
      # The cache is keyed by class name, which a redefined class (or one
      # changed with $set()) shares with its old version, so check that each
      # cached method is still bound where the cache says; if not, rebuild.
      oe <- old_e[[as.integer(j)]]
      for (f in fns) {
        if (!identical(environment(f), oe)) {
          if (!retry) stop("Internal error: inconsistent R6 layout while copying", call. = FALSE)
          forget_class_caches(obj, old_b)
          return(fast_clone(obj, retry = FALSE))
        }
      }
      list2env(lapply(fns, `environment<-`, new_e[[as.integer(j)]]), envir = new_b[[i]])
      meth <- c(meth, m)
    }
    others <- nms[!nms %in% c(meth, names(active), ".__enclos_env__")]
    if (length(others)) list2env(remap(mget(others, envir = old_b[[i]]), i), envir = new_b[[i]])
    if (i == 1L) {
      for (nm in meth) lockBinding(nm, new_b[[1]])
      # Methods added after the layout was cached (Generator$set()) arrive
      # through `others`; keep their locks as R6's clone does.
      for (nm in others) if (bindingIsLocked(nm, old_b[[1]])) lockBinding(nm, new_b[[1]])
    }
    if (length(active)) {
      active <- remap(active, i)
      for (nm in names(active)) makeActiveBinding(nm, active[[nm]], new_b[[i]])
      new_e[[i]]$.__active__ <- active
    }
  }
  if (!is.null(old_private)) {
    pvals <- remap(as.list.environment(old_private, all.names = TRUE), 1L)
    list2env(pvals, envir = new_private)
    for (nm in names(pvals)) {
      f <- pvals[[nm]]
      if (is.function(f) && !is.primitive(f) && any(vapply(new_e, identical, NA, environment(f)))) {
        lockBinding(nm, new_private)
      }
    }
  }
  if (environmentIsLocked(obj)) lockEnvironment(new_b[[1]])
  class(new_b[[1]]) <- class(obj)
  new_b[[1]]
}

# Method names of each slice of an R6 object, cached by class and grouped by
# the slice whose enclosing environment they are bound to (R6 leaves an
# inherited method bound to the superclass level that defined it). In the
# first slice only locked bindings count, since fields may also hold
# closures. A name that later turns out not to be a method is still copied
# correctly, through the generic path, because fast_clone() treats any name
# missing from the cache as an ordinary binding.
clone_layout_key <- function(obj, old_b) {
  # Superclass slices are fixed by the class definition, so their sizes
  # separate classes that share a class vector (anonymous R6 subclasses).
  paste(c(class(obj), vapply(old_b[-1], length, 1L)), collapse = "/")
}

# Drops the cached layouts of obj's class (see fast_clone()).
forget_class_caches <- function(obj, old_b) {
  key <- clone_layout_key(obj, old_b)
  if (!is.null(.manim$clone_layouts) && exists(key, envir = .manim$clone_layouts, inherits = FALSE)) {
    rm(list = key, envir = .manim$clone_layouts)
  }
  nkey <- paste(class(obj), collapse = "/")
  if (!is.null(.manim$nonfield_cache) && exists(nkey, envir = .manim$nonfield_cache, inherits = FALSE)) {
    rm(list = nkey, envir = .manim$nonfield_cache)
  }
}

clone_layout <- function(obj, old_b, old_e) {
  key <- clone_layout_key(obj, old_b)
  cache <- .manim$clone_layouts
  if (is.null(cache)) cache <- .manim$clone_layouts <- new.env(parent = emptyenv())
  lay <- cache[[key]]
  if (!is.null(lay)) return(lay)
  # A new layout may mean a redefined class, whose cached field names
  # (nonfield_names()) are stale too.
  forget_class_caches(obj, old_b)
  n <- length(old_b)
  lay <- lapply(seq_len(n), function(i) {
    active <- names(get0(".__active__", envir = old_e[[i]], inherits = FALSE))
    nms <- setdiff(names(old_b[[i]]), c(".__enclos_env__", active))
    level <- vapply(nms, function(nm) {
      f <- get(nm, envir = old_b[[i]])
      if (!is.function(f) || is.primitive(f)) return(0L)
      if (i == 1L && !bindingIsLocked(nm, old_b[[i]])) return(0L)
      for (j in i:n) if (identical(environment(f), old_e[[j]])) return(j)
      0L
    }, 0L)
    split(nms[level > 0L], level[level > 0L])
  })
  assign(key, lay, envir = cache)
  lay
}
