# Package level state.
.manim <- new.env(parent = emptyenv())
.manim$id_counter <- 0

# Mobject ids: a token for this R session (process id and start time, so
# no random numbers are drawn) and a counter, so mobjects read back with
# readRDS() or made in parallel workers never share an id with new ones.
next_mob_id <- function() {
  .manim$id_counter <- .manim$id_counter + 1
  if (is.null(.manim$id_token)) {
    .manim$id_token <- paste0(format(as.hexmode(Sys.getpid())), format(as.hexmode(as.integer(Sys.time()) %% 2^30)),
                              format(as.hexmode(as.integer((proc.time()[["elapsed"]] * 1e6) %% 2^30))))
  }
  paste0(.manim$id_token, "-", .manim$id_counter)
}

.onLoad <- function(libname, pkgname) {
  .manim$config <- default_config()
  .manim$color_table <- NULL
  register_knitr_engine()
  finalize_constructors(asNamespace(pkgname))
  assign("SHADER_FOLDER", system.file("shaders", package = pkgname, lib.loc = libname), envir = asNamespace(pkgname))
  digest_startup_config_files()
  invisible()
}
