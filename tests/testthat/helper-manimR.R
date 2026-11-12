# Temporary directory removed when the calling test finishes.
withr_tempdir <- function(env = parent.frame()) {
  d <- tempfile("manimR-test-")
  dir.create(d)
  do.call(on.exit, list(substitute(unlink(d, recursive = TRUE), list(d = d)), add = TRUE), envir = env)
  d
}

# Keep LaTeX caches and renders out of the package directory during tests.
manim_config(media_dir = file.path(tempdir(), "manimR-tests"))
