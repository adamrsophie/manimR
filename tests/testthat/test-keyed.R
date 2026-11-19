test_that("update_keyed() keeps each key's object and fades keys in and out", {
  before <- data.frame(id = c("a", "b", "c"), x = 1:3)
  after <- data.frame(id = c("c", "a", "d"), x = c(3, -1, 2))
  dot <- function(r) Dot(c(r$x, 0, 0))
  dots <- keyed_mobjects(before, "id", dot)
  a <- dots[["a"]]
  ticks <- 0
  a$add_updater(function(m, dt) ticks <<- ticks + 1)
  S <- manim_scene(function(self) {
    self$add(dots)
    self$play(update_keyed(dots, after))
    self$wait(0.2)
  })
  suppressMessages(render(S, quality = "l", format = "none"))
  expect_equal(names(dots$submob_dict), c("c", "a", "d"))
  expect_identical(dots[["a"]], a)
  expect_equal(a$get_center(), c(-1, 0, 0), tolerance = 1e-6)
  expect_gt(ticks, 0)
  expect_equal(length(dots$submobjects), 3)
  expect_identical(dots$submobjects[[2]], a)
  expect_equal(dots[["d"]]$get_fill_opacity(), 1)
})

test_that("keyed data with missing or repeated keys is rejected before any change", {
  dots <- keyed_mobjects(data.frame(id = 1:2, x = 1:2), "id", function(r) Dot(c(r$x, 0, 0)))
  expect_error(update_keyed(dots, data.frame(id = c(1, 1), x = 1:2)), "repeats '1'")
  expect_error(update_keyed(dots, data.frame(id = c(1, NA), x = 1:2)), "missing values")
  expect_error(keyed_mobjects(data.frame(x = 1), "id", Dot), "must name a column")
  expect_error(update_keyed(VDict(), data.frame(id = 1)), "keyed_mobjects")
  expect_equal(names(dots$submob_dict), c("1", "2"))
})

test_that("an empty table empties a keyed group", {
  dots <- keyed_mobjects(data.frame(id = 1:2, x = 1:2), "id", function(r) Dot(c(r$x, 0, 0)))
  S <- manim_scene(function(self) {
    self$add(dots)
    self$play(update_keyed(dots, data.frame(id = integer(), x = numeric())))
  })
  suppressMessages(render(S, quality = "l", format = "none"))
  expect_length(dots$submobjects, 0)
  expect_length(dots$submob_dict, 0)
})

test_that("keyed_points() moves points by key in one point cloud", {
  ax <- Axes(x_range = c(0, 4), y_range = c(0, 4))
  before <- data.frame(id = c("a", "b", "c"), x = 1:3, y = c(1, 3, 2))
  after <- data.frame(id = c("c", "a", "d"), x = c(3, 1, 2), y = c(3, 2, 1))
  cloud <- keyed_points(before, "id", "x", "y", axes = ax, color = BLUE)
  expect_s3_class(cloud, "PMobject")
  anim <- update_keyed(cloud, after, color = c(BLUE, BLUE, RED))
  S <- manim_scene(function(self) {
    self$add(cloud)
    self$play(anim)
  })
  suppressMessages(render(S, quality = "l", format = "none"))
  expect_equal(cloud$keys, c("c", "a", "d"))
  expect_equal(cloud$points[cloud$rows_of("a"), ], as_point(ax$c2p(1, 2)), tolerance = 1e-6)
  expect_equal(cloud$rgbas[, 4], c(1, 1, 1))
  expect_equal(cloud$rgbas[3, 1:3], color_to_rgba(RED)[1:3])
  # Halfway, a departing point is half transparent.
  anim2 <- update_keyed(cloud, after[1:2, ])
  anim2$begin()
  anim2$interpolate(0.5)
  expect_equal(nrow(cloud$points), 3)
  expect_equal(cloud$rgbas[3, 4], 0.5, tolerance = 1e-6)
})
