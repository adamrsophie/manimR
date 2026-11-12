# Package level state.
.manim <- new.env(parent = emptyenv())
.manim$id_counter <- 0

next_mob_id <- function() {
  .manim$id_counter <- .manim$id_counter + 1
  as.character(.manim$id_counter)
}

.onLoad <- function(libname, pkgname) {
  .manim$config <- default_config()
  .manim$color_table <- NULL
  register_knitr_engine()
  finalize_constructors(asNamespace(pkgname))
  invisible()
}
