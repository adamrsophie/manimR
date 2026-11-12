test_that("no export masks a function from base R's packages", {
  exports <- getNamespaceExports("manimR")
  pkgs <- c("base", "stats", "utils", "graphics", "grDevices", "methods", "datasets", "grid", "tools")
  clashes <- unlist(lapply(pkgs, function(p) intersect(exports, getNamespaceExports(p))))
  expect_equal(clashes, character())
})
