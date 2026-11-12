# Class level default arguments, like Mobject.set_default and
# Animation.set_default in manim.

#' Change default arguments of a mobject or animation class
#'
#' `set_default(Text, font_size = 60)` makes every later `Text()` use
#' `font_size = 60` unless given explicitly. Calling `set_default(Text)` with
#' no further arguments restores the original defaults. Works for arguments
#' accepted by the class, including those passed on to parent classes.
#'
#' @param cls A constructor such as `Text` or an R6 generator such as `TextClass`.
#' @param ... New defaults as named arguments.
#' @return The generator, invisibly.
#' @export
#' @examples
#' set_default(Circle, color = BLUE)
#' Circle()$get_color()
#' set_default(Circle)
set_default <- function(cls, ...) {
  gen <- resolve_generator(cls, deparse(substitute(cls)))
  if (is.null(.manim$default_backup)) .manim$default_backup <- new.env(parent = emptyenv())
  key <- gen$classname
  if (is.null(.manim$default_backup[[key]])) {
    assign(key, list(formals = formals(gen$public_methods$initialize), new = gen$new), envir = .manim$default_backup)
  }
  backup <- .manim$default_backup[[key]]
  new <- list(...)
  init <- gen$public_methods$initialize
  if (length(new) == 0) {
    formals(init) <- backup$formals
    gen$public_methods$initialize <- init
    gen$new <- backup$new
    return(invisible(gen))
  }
  f <- backup$formals
  direct <- intersect(names(new), names(f))
  for (nm in direct) f[nm] <- list(new[[nm]])
  formals(init) <- f
  gen$public_methods$initialize <- init
  # Arguments that reach the initializer through `...` (for example run_time
  # of an animation) are injected when the object is created.
  extra <- new[setdiff(names(new), direct)]
  orig_new <- backup$new
  gen$new <- if (length(extra)) {
    function(...) {
      args <- list(...)
      nm <- names(args) %||% rep("", length(args))
      add <- extra[setdiff(names(extra), nm[nzchar(nm)])]
      do.call(orig_new, c(args, add))
    }
  } else orig_new
  invisible(gen)
}

resolve_generator <- function(cls, label) {
  if (inherits(cls, "R6ClassGenerator")) return(cls)
  ns <- asNamespace("manimR")
  cand <- paste0(label, "Class")
  if (exists(cand, envir = ns, inherits = FALSE)) {
    gen <- get(cand, envir = ns)
    if (inherits(gen, "R6ClassGenerator")) return(gen)
  }
  if (is.function(cls)) {
    body_txt <- paste(deparse(body(cls)), collapse = " ")
    m <- regmatches(body_txt, regexpr("[A-Za-z]+Class\\$new", body_txt))
    if (length(m)) {
      gen <- get(sub("\\$new$", "", m), envir = ns)
      if (inherits(gen, "R6ClassGenerator")) return(gen)
    }
  }
  stop("Could not find the class behind '", label, "'. Pass its generator, for example TextClass.", call. = FALSE)
}
