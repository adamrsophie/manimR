# Temporary directory removed when the calling test finishes.
withr_tempdir <- function(env = parent.frame()) {
  d <- tempfile("manimR-test-")
  dir.create(d)
  do.call(on.exit, list(substitute(unlink(d, recursive = TRUE), list(d = d)), add = TRUE), envir = env)
  d
}

# Keep LaTeX caches and renders out of the package directory during tests.
manim_config(media_dir = file.path(tempdir(), "manimR-tests"))

# TRUE when LaTeX and dvisvgm are installed and compile the default template;
# an installation can have both programs and lack the template's packages.
# Always FALSE on CRAN, where no external program is run.
latex_works <- local({
  ok <- NULL
  function() {
    if (is.null(ok)) {
      ok <<- identical(Sys.getenv("NOT_CRAN"), "true") &&
        nzchar(Sys.which("latex")) && nzchar(Sys.which("dvisvgm")) &&
        tryCatch({
          MathTex("x")
          TRUE
        }, error = function(e) FALSE)
    }
    ok
  }
})
