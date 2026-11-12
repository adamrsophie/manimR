# Every public name of `from manim import *` (listed by
# data-raw/upstream_exports.py from the upstream source) must be exported,
# as itself or as its R class generator, unless it is one of these
# documented renames.
API_RENAMES <- c(
  smooth = "smooth_rate",       # stats::smooth
  X11 = "X11_COLORS",           # grDevices::X11
  clip = "clip_value",          # graphics::clip
  frame = "manim_frame",        # graphics::frame
  choose = "base::choose",      # same function in base R
  unit = "Pixels",              # grid::unit; units are exported one by one
  ParsableManimColor = NA       # a Python type annotation
)

test_that("every upstream export has an R equivalent", {
  up <- utils::read.delim(test_path("fixtures", "upstream_exports.txt"), header = FALSE,
                          col.names = c("name", "module"), stringsAsFactors = FALSE)
  ns <- getNamespaceExports("manimR")
  covered <- up$name %in% ns | paste0(up$name, "Class") %in% ns | up$name %in% names(API_RENAMES)
  expect_equal(up$name[!covered], character())
  # The renames exist and are themselves exported.
  targets <- stats::na.omit(API_RENAMES[!startsWith(API_RENAMES, "base::")])
  expect_true(all(targets %in% ns))
  expect_true(all(names(API_RENAMES) %in% up$name))
  # A rename would mask the function it avoids.
  masked <- c(smooth = "stats", X11 = "grDevices", clip = "graphics", frame = "graphics", unit = "grid")
  for (nm in names(masked)) expect_true(exists(nm, envir = asNamespace(masked[[nm]]), inherits = FALSE))
})

# Methods of pycairo drawing contexts. manimR draws with grid on a ragg
# device (Camera$draw_frame(), Camera$draw_on_pixel_array()), so there is
# no Cairo context to create, cache, or set a path or color on.
CAIRO_CONTEXT_METHODS <- c("cache_cairo_context", "get_cached_cairo_context", "get_cairo_context",
                           "set_cairo_context_color", "set_cairo_context_path")

test_that("every public upstream method has an R equivalent", {
  rows <- strsplit(readLines(test_path("fixtures", "upstream_methods.txt")), "\t")
  ns <- asNamespace("manimR")
  members <- function(gen) {
    out <- ls(gen)
    while (!is.null(gen)) {
      out <- c(out, names(gen$public_methods), names(gen$public_fields), names(gen$active))
      gen <- gen$get_inherit()
    }
    out
  }
  missing <- character()
  for (r in rows) {
    cls <- r[1]
    meths <- if (length(r) >= 3 && nzchar(r[3])) strsplit(r[3], ",")[[1]] else character()
    if (!length(meths)) next
    have <- if (cls %in% c("ManimColor", "HSV")) {
      c(names(manimR:::manim_color_methods), names(ManimColorClass), "hue", "saturation", "value", "h", "s", "v")
    } else {
      gen <- get0(paste0(cls, "Class"), envir = ns) %||% get0(cls, envir = ns)
      expect_true(inherits(gen, "R6ClassGenerator"), info = cls)
      members(gen)
    }
    gap <- setdiff(meths, c(have, CAIRO_CONTEXT_METHODS))
    if (length(gap)) missing <- c(missing, paste0(cls, "$", gap))
  }
  expect_equal(missing, character())
})
