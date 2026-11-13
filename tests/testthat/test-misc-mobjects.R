# Tests for vector fields, boolean operations, graphs, tables, matrices,
# matching transforms, ChangeSpeed, Code, labels and the banner. Reference
# values come from Python manim via data-raw/misc_oracle.py.

misc_oracle <- function() {
  skip_if_not_installed("jsonlite")
  jsonlite::fromJSON(test_path("fixtures", "misc_oracle.json"), simplifyVector = FALSE)
}

misc_mat <- function(x) do.call(rbind, lapply(x, unlist))

misc_bbox <- function(m) c(m$get_left()[1], m$get_right()[1], m$get_bottom()[2], m$get_top()[2])

# Skips without LaTeX; otherwise sends LaTeX output to a temporary media
# directory until the calling test ends.
skip_if_no_latex <- function(env = parent.frame()) {
  skip_if_not(latex_works(), "LaTeX or dvisvgm not available")
  skip_on_cran()
  old <- manim_config(media_dir = file.path(tempdir(), "manimR-test-media"))
  do.call(on.exit, list(substitute(.manim$config <- old, list(old = old)), add = TRUE), envir = env)
}

misc_layout <- function(g, ref) misc_mat(g$graph_layout[names(ref)])

# Boolean operations ----------------------------------------------------------

test_that("boolean operations match upstream bounding boxes and areas", {
  o <- misc_oracle()
  area <- function(m) {
    # Shoelace area of the curves sampled finely, as the oracle samples them.
    tt <- seq(0, 1, length.out = 33)[-33]
    sum(vapply(m$get_subpaths(), function(sp) {
      a <- do.call(rbind, lapply(seq(1, nrow(sp), by = 4), function(k) bezier(sp[k:(k + 3), , drop = FALSE])(tt)))
      b <- a[c(2:nrow(a), 1), , drop = FALSE]
      0.5 * (sum(a[, 1] * b[, 2]) - sum(b[, 1] * a[, 2]))
    }, numeric(1)))
  }
  ops <- list(union = Union, intersection = Intersection, difference = Difference, exclusion = Exclusion)
  for (nm in names(ops)) {
    sq <- Square()$move_to(c(-2, 0, 0))
    cr <- Circle()$move_to(c(-1.3, 0.7, 0))
    res <- ops[[nm]](sq, cr, color = GREEN, fill_opacity = 1)
    ref <- o[[paste0("bool_", nm)]]
    expect_equal(misc_bbox(res), unlist(ref$bbox), tolerance = 1e-6)
    expect_equal(area(res), ref$area, tolerance = 1e-3)
    expect_equal(res$get_fill_opacity(), 1)
  }
  expect_error(Union(Square()), "At least 2")
  expect_error(Intersection(Square()), "At least 2")
  three <- Intersection(Square(), Circle(), Square()$shift(RIGHT * 0.5))
  expect_equal(misc_bbox(three)[1:2], c(-0.5, 1), tolerance = 1e-6)
})

test_that("boolean operations cut the curves where skia-pathops does", {
  skip_if_not_installed("jsonlite")
  o <- jsonlite::fromJSON(test_path("fixtures", "boolean_ops_oracle.json"), simplifyVector = FALSE)
  as_pts <- function(x) if (length(x)) do.call(rbind, lapply(x, function(p) as.numeric(unlist(p)))) else matrix(0, 0, 3)
  # The pieces of an outline, each written from its lower end, in order.
  pieces <- function(m) {
    if (!nrow(m)) return(matrix(0, 0, 8))
    segs <- lapply(seq(1, nrow(m), 4), function(k) m[k:(k + 3), 1:2])
    segs <- Filter(function(s) max(abs(s - s[rep(1, 4), ])) > 1e-9, segs)
    segs <- lapply(segs, function(s) {
      if (s[4, 1] < s[1, 1] - 1e-4 || (abs(s[4, 1] - s[1, 1]) <= 1e-4 && s[4, 2] < s[1, 2])) s <- s[4:1, ]
      c(t(s))
    })
    out <- do.call(rbind, segs)
    out[order(round(out[, 1], 4), round(out[, 2], 4), round(out[, 7], 4), round(out[, 8], 4)), , drop = FALSE]
  }
  # Which points of a grid the outline fills, by the nonzero rule.
  grid <- as.matrix(expand.grid(seq(-3.2, 3.2, length.out = 41) + 0.0123, seq(-3.2, 3.2, length.out = 41) + 0.0071))
  filled <- function(m) {
    if (!nrow(m)) return(logical(nrow(grid)))
    v <- VMobject()
    v$points <- m
    flat <- lapply(v$get_subpaths(), function(sp) do.call(rbind, lapply(seq(1, nrow(sp), 4), function(k)
      bezier(sp[k:(k + 3), , drop = FALSE])(seq(0, 1, length.out = 41)[-41])[, 1:2, drop = FALSE])))
    apply(grid, 1, function(p) manimR:::bool_winding(p, flat) != 0)
  }
  make <- list(
    sq_cr = function() list(Square()$move_to(c(-2, 0, 0)), Circle()$move_to(c(-1.3, 0.7, 0))),
    ellipses = function() { e1 <- Ellipse(width = 4, height = 5)$move_to(LEFT); list(e1, e1$copy()$move_to(RIGHT)) },
    nested = function() list(Square(side_length = 4), Circle(radius = 1)),
    apart = function() list(Circle()$shift(2 * LEFT), Circle()$shift(2 * RIGHT)),
    poly = function() list(RegularPolygon(n = 5), Triangle()$scale(1.5)$shift(0.4 * UP)),
    star = function() list(Star(), Circle(radius = 0.8)$shift(0.3 * RIGHT)),
    offset_square = function() list(Square(), Square()$shift(0.5 * RIGHT + 0.5 * UP)),
    rect_circle = function() list(Rectangle(width = 4, height = 1), Circle(radius = 1.2)),
    corners = function() list(Square(), Circle()$shift(RIGHT)),
    all_corners = function() list(Square(), Circle(radius = sqrt(2))))
  ops <- list(union = Union, intersection = Intersection, difference = Difference, exclusion = Exclusion)
  # Skia computes crossings in single precision, so points agree to about
  # 1e-6. Results whose contours hold an input start match point for point.
  exact <- c("sq_cr_union", "sq_cr_intersection", "sq_cr_exclusion", "ellipses_union",
             "ellipses_intersection", "nested_union", "nested_intersection", "nested_difference",
             "nested_exclusion", "apart_union", "apart_intersection", "apart_difference",
             "apart_exclusion", "poly_difference", "star_union", "offset_square_union",
             "offset_square_intersection", "offset_square_exclusion", "rect_circle_union",
             "rect_circle_intersection", "rect_circle_difference", "corners_union",
             "corners_intersection", "corners_difference", "corners_exclusion", "all_corners_union",
             "all_corners_intersection", "all_corners_difference", "all_corners_exclusion")
  for (cn in names(make)) for (on in names(ops)) {
    key <- paste0(cn, "_", on)
    ab <- make[[cn]]()
    got <- ops[[on]](ab[[1]], ab[[2]])$points
    want <- as_pts(o[[key]])
    if (key %in% exact) expect_lt(max(0, abs(got - want)), 1e-5, label = key)
    expect_identical(filled(got), filled(want), info = key)
    pg <- pieces(got)
    pw <- pieces(want)
    expect_identical(dim(pg), dim(pw), info = key)
    if (identical(dim(pg), dim(pw))) expect_lt(max(c(0, abs(pg - pw))), 1e-5, label = key)
  }
  three <- list(Square(), Circle()$shift(0.8 * RIGHT), Triangle()$shift(0.6 * UP))
  expect_lt(max(abs(do.call(Union, three)$points - as_pts(o$three_union))), 1e-5)
  expect_lt(max(abs(do.call(Intersection, three)$points - as_pts(o$three_intersection))), 1e-5)
})

# ChangeSpeed -----------------------------------------------------------------

test_that("ChangeSpeed matches upstream timing", {
  o <- misc_oracle()
  cs <- ChangeSpeed(Wait(1), speedinfo = c("0.3" = 1, "0.4" = 0.1, "0.6" = 0.1, "1" = 1), rate_func = linear,
                    affects_speed_updaters = FALSE)
  expect_equal(cs$run_time, o$change_speed_run_time)
  expect_equal(vapply(seq(0, 1, length.out = 11), cs$anim$rate_func, numeric(1)),
               unlist(o$change_speed_values), tolerance = 1e-9)
  expect_equal(unname(cs$speedinfo), c(1, 1, 0.1, 0.1, 1))
  cs2 <- ChangeSpeed(Wait(1), speedinfo = c("0.1" = 0.3, "0.35" = 2.7, "0.8" = 0.05, "0.95" = 1.9),
                     affects_speed_updaters = FALSE)
  expect_equal(cs2$anim$rate_func(1), 1)
  expect_equal(cs2$anim$rate_func(0), 0)
})

test_that("ChangeSpeed drives updaters added with change_speed_add_updater", {
  d <- Dot()
  change_speed_add_updater(d, function(m, dt) m$shift(RIGHT * dt))
  cs <- ChangeSpeed(Wait(2), speedinfo = c("1" = 0.5), affects_speed_updaters = TRUE)
  expect_true(change_speed_state$is_changing_dt)
  expect_error(ChangeSpeed(Wait(1), speedinfo = c("1" = 1)), "Only one animation")
  cs$begin()
  cs$interpolate(0.5)
  d$update(1 / 15)
  x_half <- d$get_x()
  expect_equal(x_half, change_speed_state$dt, tolerance = 1e-12)
  expect_gt(x_half, 0)
  cs$finish()
  expect_false(change_speed_state$is_changing_dt)
  # Plain updaters see the real dt again.
  d$update(0.5)
  expect_equal(d$get_x(), x_half + 0.5)
})

test_that("an invalid ChangeSpeed does not keep the updater lock", {
  old <- change_speed_state$is_changing_dt
  on.exit(change_speed_state$is_changing_dt <- old, add = TRUE)
  change_speed_state$is_changing_dt <- FALSE
  expect_error(ChangeSpeed(Wait(1), speedinfo = c(fast = 2)), "numeric nodes")
  expect_error(ChangeSpeed(Wait(1), speedinfo = list("1" = "fast")), "numeric speeds")
  expect_false(change_speed_state$is_changing_dt)
  cs <- ChangeSpeed(Wait(1), speedinfo = c("1" = 1))
  expect_true(change_speed_state$is_changing_dt)
  cs$finish()
  expect_false(change_speed_state$is_changing_dt)
})

# Transform matching ------------------------------------------------------------

test_that("TransformMatchingShapes matches identical shapes", {
  src <- VGroup(Square(), Circle()$shift(RIGHT * 3), Triangle()$shift(LEFT * 3))
  tar <- VGroup(Circle(radius = 2)$shift(UP), Square(side_length = 0.5)$shift(DOWN), RegularPolygon(5))
  anim <- TransformMatchingShapes(src, tar)
  expect_length(anim$animations, 3)
  matched <- anim$animations[[1]]
  expect_length(matched$mobject$submobjects, 2)
  expect_length(anim$animations[[2]]$mobject$submobjects, 1)
  key <- anim$get_mobject_key
  expect_identical(key(Square()), key(Square(side_length = 3)$shift(UR)))
  expect_false(identical(key(Square()), key(Circle())))
  # The key does not move the mobject.
  s <- Square()$shift(RIGHT)
  before <- s$points
  key(s)
  expect_identical(s$points, before)
})

test_that("TransformMatchingTex matches MathTex parts by tex string", {
  skip_if_no_latex()
  eq1 <- MathTex("{{x}}^2", "+", "{{y}}^2")
  eq2 <- MathTex("{{x}}^2", "-", "{{z}}^2")
  anim <- TransformMatchingTex(eq1, eq2)
  # Keys "x" and "^2" are shared; "^2" occurs twice in each and is grouped.
  matched <- anim$animations[[1]]$mobject$submobjects
  expect_length(matched, 2)
  expect_length(matched[[2]]$submobjects, 2)
  expect_error(TransformMatchingTex(Square(), eq2), "MathTex")
})

# Vector fields -----------------------------------------------------------------

test_that("ArrowVectorField matches upstream vectors and colors", {
  o <- misc_oracle()
  func <- function(pos) ((pos[1] * UR + pos[2] * LEFT) - pos) / 3
  vf <- ArrowVectorField(func, x_range = c(-2, 2, 1), y_range = c(-1, 1, 1))
  vecs <- vf$submobjects
  expect_length(vecs, 15)
  expect_equal(t(vapply(vecs, function(v) v$get_start(), numeric(3))), misc_mat(o$avf_starts), tolerance = 1e-9)
  expect_equal(t(vapply(vecs, function(v) v$get_end(), numeric(3))), misc_mat(o$avf_ends), tolerance = 1e-9)
  rgb <- function(cols) t(vapply(cols, color_to_rgb, numeric(3)))
  # Colors agree up to the last bit of the hex code (rounding differs).
  expect_lt(max(abs(rgb(vapply(vecs, function(v) v$get_color(), "")) - rgb(unlist(o$avf_colors)))), 1.5 / 255)
  vf2 <- ArrowVectorField(function(pos) pos - LEFT * 5, x_range = c(-2, 2, 2), y_range = c(-1, 1, 1),
                          min_color_scheme_value = 2, max_color_scheme_value = 10,
                          colors = c(RED, YELLOW, BLUE, DARK_GRAY))
  expect_lt(max(abs(rgb(vapply(vf2$submobjects, function(v) v$get_color(), "")) - rgb(unlist(o$avf_scheme_colors)))),
            1.5 / 255)
})

test_that("StreamLines integrate the field like upstream", {
  o <- misc_oracle()
  func <- function(pos) ((pos[1] * UR + pos[2] * LEFT) - pos) / 3
  sl <- StreamLines(func, color = BLUE, x_range = c(-1, 1, 1), y_range = c(-1, 1, 1), noise_factor = 0,
                    virtual_time = 1, max_anchors_per_line = 5)
  expect_length(sl$stream_lines, length(o$stream_points))
  for (i in seq_along(sl$stream_lines)) {
    expect_equal(sl$stream_lines[[i]]$points, misc_mat(o$stream_points[[i]]), tolerance = 1e-9)
  }
  expect_equal(sl$stream_lines[[1]]$duration, o$stream_duration)
  anim <- sl$create()
  expect_s3_class(anim, "AnimationGroup")
  expect_length(anim$animations, 9)
  expect_error(sl$end_animation(), "start the animation")
  sl$start_animation(warm_up = FALSE)
  expect_length(sl$updaters, 1)
  end <- sl$end_animation()
  expect_length(sl$updaters, 0)
  end$begin()
  end$finish()
  # Every line is fully drawn again at the end.
  for (i in seq_along(sl$stream_lines)) {
    expect_equal(sl$stream_lines[[i]]$points, misc_mat(o$stream_points[[i]]), tolerance = 1e-9)
  }
})

test_that("copies of flowing StreamLines animate their own lines", {
  skip_on_cran() # slow
  func <- function(pos) ((pos[1] * UR + pos[2] * LEFT) - pos) / 3
  sl <- StreamLines(func, x_range = c(-1, 1, 1), y_range = c(-1, 1, 1), noise_factor = 0, virtual_time = 1,
                    max_anchors_per_line = 5)
  set.seed(1)
  sl$start_animation(warm_up = FALSE)
  sl$update(0.1)
  cp <- sl$copy()
  line <- sl$stream_lines[[1]]
  copied <- cp$stream_lines[[1]]
  expect_false(identical(copied$mob_id, line$mob_id))
  expect_identical(copied$anim$mobject$mob_id, copied$mob_id)
  expect_true(copied$mob_id %in% vapply(cp$submobjects, function(m) m$mob_id, ""))
  before <- line$points
  before_copy <- copied$points
  cp$update(0.2)
  expect_false(isTRUE(all.equal(copied$points, before_copy)))
  expect_identical(line$points, before)
})

test_that("VectorField nudges mobjects along the field", {
  vf <- VectorField(function(pos) RIGHT * 2)
  d <- Dot()
  vf$nudge(d, dt = 0.5, substeps = 3)
  expect_equal(d$get_center(), c(1, 0, 0))
  rot <- VectorField(function(pos) c(-pos[2], pos[1], 0))
  d2 <- Dot(c(1, 0, 0))
  rot$nudge(d2, dt = pi / 2, substeps = 50)
  expect_equal(d2$get_center(), c(0, 1, 0), tolerance = 1e-6)
  upd <- vf$get_nudge_updater(speed = 2)
  d3 <- Dot()
  upd(d3, 0.25)
  expect_equal(d3$get_x(), 1)
  f <- vector_field_scale_func(function(p) p, 0.5)
  expect_equal(f(c(2, 4, 0)), c(1, 2, 0))
  g <- vector_field_shift_func(function(p) p, RIGHT)
  expect_equal(g(c(2, 4, 0)), c(1, 4, 0))
  expect_equal(vf_arange(-7, 8, 1), -7:7)
  expect_length(vf_arange(-3, 3.2, 0.2), 31)
  vf$start_submobject_movement()
  expect_length(vf$updaters, 1)
  vf$stop_submobject_movement()
  expect_length(vf$updaters, 0)
})

# Graphs ------------------------------------------------------------------------

test_that("graph layouts match networkx", {
  o <- misc_oracle()
  V <- 1:6
  E <- list(c(1, 2), c(2, 3), c(3, 4), c(4, 5), c(5, 6), c(6, 1), c(5, 1), c(1, 3), c(3, 5))
  expect_equal(misc_layout(Graph(V, E, layout = "circular"), o$layout_circular), misc_mat(o$layout_circular),
               tolerance = 1e-6)
  expect_equal(misc_layout(Graph(V, E, layout = "spiral"), o$layout_spiral), misc_mat(o$layout_spiral),
               tolerance = 1e-9)
  expect_equal(misc_layout(Graph(V, E, layout = "partite", partitions = list(c(1, 2), c(3, 4))), o$layout_partite),
               misc_mat(o$layout_partite), tolerance = 1e-9)
  shell <- Graph(1:9, list(c(1, 2), c(2, 3), c(3, 1), c(4, 1), c(4, 2), c(5, 2), c(6, 2), c(6, 3), c(7, 3),
                           c(8, 3), c(8, 1), c(9, 1)),
                 layout = "shell", layout_config = list(nlist = list(1:3, 4:9)))
  expect_equal(misc_layout(shell, o$layout_shell), misc_mat(o$layout_shell), tolerance = 1e-6)
  start <- lapply(o$layout_spring_start, unlist)
  spring <- Graph(V, E, layout = "spring", layout_config = list(pos = start))
  expect_equal(misc_layout(spring, o$layout_spring), misc_mat(o$layout_spring), tolerance = 1e-7)
  TE <- list(c(1, 2), c(1, 3), c(2, 4), c(2, 5), c(3, 6), c(3, 7))
  expect_equal(misc_layout(Graph(1:7, TE, layout = "tree", root_vertex = 1), o$layout_tree),
               misc_mat(o$layout_tree), tolerance = 1e-9)
  expect_equal(misc_layout(Graph(1:7, TE, layout = "tree", root_vertex = 1,
                                 layout_config = list(vertex_spacing = c(0.5, 1))), o$layout_tree_spacing),
               misc_mat(o$layout_tree_spacing), tolerance = 1e-9)
  expect_equal(misc_layout(Graph(1:7, TE, layout = "tree", layout_scale = c(3, 1),
                                 layout_config = list(root_vertex = 1, orientation = "up")), o$layout_tree_up),
               misc_mat(o$layout_tree_up), tolerance = 1e-9)
  expect_error(Graph(1:3, list(c(1, 2), c(2, 3), c(3, 1)), layout = "tree", root_vertex = 1), "trees")
  # Spectral: eigenvectors are defined up to sign (distinct eigenvalues).
  for (case in c("layout_spectral_path", "layout_spectral_di")) {
    ref <- o[[case]]
    g <- if (case == "layout_spectral_path") Graph(1:5, list(c(1, 2), c(2, 3), c(3, 4), c(4, 5)), layout = "spectral")
      else DiGraph(1:5, list(c(1, 2), c(2, 3), c(3, 4), c(4, 5), c(5, 3)), layout = "spectral")
    a <- misc_layout(g, ref)
    b <- misc_mat(ref)
    for (j in 1:2) if (sum(a[, j] * b[, j]) < 0) a[, j] <- -a[, j]
    expect_equal(a, b, tolerance = 1e-7)
  }
  # With a repeated eigenvalue only the defining properties are fixed.
  sp <- misc_mat(Graph(V, E, layout = "spectral")$graph_layout)
  expect_equal(colMeans(sp), c(0, 0, 0), tolerance = 1e-9)
  expect_equal(max(abs(sp)), 2)
  rnd <- misc_mat(Graph(V, E, layout = "random", layout_config = list(seed = 1))$graph_layout)
  expect_true(all(abs(rnd[, 1:2]) <= 2))
  custom <- Graph(1:3, list(c(1, 2)), layout = function(graph, scale, ...) {
    ids <- graph$vertex_ids()
    stats::setNames(lapply(seq_along(ids), function(i) c(i * scale, 0, 0)), ids)
  }, layout_scale = 1)
  expect_equal(custom$get(3)$get_center(), c(3, 0, 0))
})

test_that("kamada_kawai layout matches networkx", {
  o <- misc_oracle()
  V <- 1:6
  E <- list(c(1, 2), c(2, 3), c(3, 4), c(4, 5), c(5, 6), c(6, 1), c(5, 1), c(1, 3), c(3, 5))
  # Different L-BFGS-B implementations stop at slightly different points.
  expect_equal(misc_layout(Graph(V, E, layout = "kamada_kawai"), o$layout_kamada_kawai),
               misc_mat(o$layout_kamada_kawai), tolerance = 1e-5)
  dist <- list("1" = list("2" = 1), "2" = list("3" = 1), "3" = list("4" = 2), "4" = list("5" = 3),
               "5" = list("6" = 5), "6" = list("1" = 8))
  g <- Graph(V, E[1:6], layout = "kamada_kawai", layout_config = list(dist = dist), layout_scale = 4)
  expect_equal(misc_layout(g, o$layout_kamada_kawai_dist), misc_mat(o$layout_kamada_kawai_dist), tolerance = 1e-5)
  expect_silent(Graph(1:4, list(c(1, 2), c(2, 3), c(3, 4)), layout = "planar"))
})

test_that("planar layout matches networkx and draws no crossings", {
  skip_on_cran() # slow
  skip_if_not_installed("jsonlite")
  cases <- jsonlite::fromJSON(test_path("fixtures", "planar_oracle.json"), simplifyVector = FALSE)
  # Number of pairs of edges without a common vertex whose segments cross.
  crossings <- function(g) {
    seg <- lapply(g$edge_pairs, function(e) rbind(g$get(e[1])$get_center()[1:2], g$get(e[2])$get_center()[1:2]))
    side <- function(a, b, p) (b[1] - a[1]) * (p[2] - a[2]) - (b[2] - a[2]) * (p[1] - a[1])
    n <- 0
    for (i in seq_along(seg)) for (j in seq_along(seg)) {
      if (j <= i || length(intersect(g$edge_pairs[[i]], g$edge_pairs[[j]]))) next
      p <- seg[[i]]
      q <- seg[[j]]
      if (side(q[1, ], q[2, ], p[1, ]) * side(q[1, ], q[2, ], p[2, ]) < 0 &&
          side(p[1, ], p[2, ], q[1, ]) * side(p[1, ], p[2, ], q[2, ]) < 0) n <- n + 1
    }
    n
  }
  for (cs in cases) {
    V <- unlist(cs$vertices)
    E <- lapply(cs$edges, unlist)
    make <- function(layout) (if (cs$directed) DiGraph else Graph)(V, E, layout = layout)
    if (!cs$planar) {
      expect_error(make("planar"), "not planar")
      next
    }
    # The embedding of the planarity test, as clockwise neighbor lists.
    g <- make("circular")
    ids <- g$vertex_ids()
    emb <- planar_embedding(length(ids), planar_lr_adjacency(length(ids), lapply(g$edge_pairs, match, ids),
                                                              g$directed))
    for (k in seq_along(ids)) expect_equal(ids[planar_neighbors_cw(emb, k)], as.character(unlist(cs$cw[[k]])))
    g <- make("planar")
    ref <- stats::setNames(cs$pos, ids)
    expect_equal(misc_layout(g, ref), misc_mat(ref), tolerance = 1e-9)
    expect_equal(crossings(g), 0)
  }
})

test_that("graph edges follow their vertices", {
  o <- misc_oracle()
  g <- Graph(1:3, list(c(1, 2), c(2, 3)), layout = list("1" = c(-1, 0, 0), "2" = c(0, 1, 0), "3" = c(1, 0, 0)))
  g$get(2)$move_to(c(0, -1, 0))
  g$update()
  expect_equal(g$get(c(1, 2))$points, misc_mat(o$graph_edge_after_move), tolerance = 1e-9)
  dg <- DiGraph(1:2, list(c(1, 2)), layout = list("1" = c(-2, 0, 0), "2" = c(2, 0, 0)))
  fam <- dg$get(c(1, 2))$family_members_with_points()
  expect_length(fam, 2)
  for (i in 1:2) expect_equal(fam[[i]]$points, misc_mat(o$digraph_edge[[i]]), tolerance = 1e-9)
  dg$get(2)$shift(UP)
  dg$update()
  expect_length(dg$get(c(1, 2))$get_tips()$submobjects, 1)
  # Edges added later get tips too (upstream adds them without tips), and
  # the updater keeps them attached.
  dg$add_edges(c(2, 3), positions = list("3" = c(2, -2, 0)))
  new_edge <- dg$get(c(2, 3))
  expect_length(new_edge$get_tips()$submobjects, 1)
  dg$get(3)$move_to(c(3, -3, 0))
  dg$update()
  expect_length(new_edge$get_tips()$submobjects, 1)
  expect_lt(get_norm(new_edge$get_tip()$tip_point - dg$get(3)$get_boundary_point(new_edge$get_start() - c(3, -3, 0))),
            0.05)
  # Copies keep their own vertices and edges, and their updater moves them.
  cp <- g$copy()
  expect_identical(cp$vertices[["1"]]$mob_id, cp$submobjects[[1]]$mob_id)
  cp$get(1)$move_to(c(-3, 0, 0))
  cp$update()
  expect_equal(cp$get(c(1, 2))$get_start(), c(-3, 0, 0))
  expect_equal(g$get(c(1, 2))$get_start(), c(-1, 0, 0))
})

test_that("graph vertices and edges can be added and removed", {
  g <- Graph(1:3, list(c(1, 2), c(2, 3)), layout = "circular")
  expect_length(g$submobjects, 5)
  added <- g$add_vertices(4, 5, positions = list("4" = c(2, 2, 0)))
  expect_length(added, 2)
  expect_equal(g$get(4)$get_center(), c(2, 2, 0))
  expect_error(g$add_vertices(4), "already used")
  new <- g$add_edges(c(3, 4), c(4, 6))
  expect_length(new$submobjects, 3)
  expect_true("6" %in% g$vertex_ids())
  expect_length(g$edges, 4)
  removed <- g$remove_vertices(4)
  expect_length(removed$submobjects, 3)
  expect_false("4" %in% g$vertex_ids())
  expect_length(g$edges, 2)
  g$remove_edges(c(1, 2))
  expect_length(g$edges, 1)
  expect_error(g$get(c(1, 2)), "Could not find")
  expect_error(g$remove_edges(c(1, 2)), "does not contain")
  expect_output(print(g), "Undirected graph on 5 vertices and 1 edges")
  g$change_layout("circular", layout_scale = 1)
  expect_equal(g$get("1")$get_center(), c(1, 0, 0), tolerance = 1e-6)
  expect_equal(g$get(c(2, 3))$get_start(), g$get(2)$get_center())
})

test_that("graph configs apply to vertices and edges", {
  g <- Graph(1:3, list(c(1, 2), c(2, 3)), layout = "circular",
             labels = list("1" = Text("a"), "2" = Text("b"), "3" = Text("c")),
             vertex_config = list(radius = 0.3, "2" = list(radius = 0.5, fill_color = RED)),
             edge_config = list(stroke_width = 7, "3-2" = list(stroke_color = BLUE)))
  expect_equal(g$get(1)$width, 0.6, tolerance = 1e-6)
  expect_equal(g$get(2)$width, 1, tolerance = 1e-6)
  expect_length(g$get(1)$submobjects, 1)
  expect_equal(g$get(c(1, 2))$stroke_width, 7)
  expect_equal(g$get(c(2, 3))$get_stroke_color(), BLUE)
  expect_equal(g$get(c(2, 3))$z_index, -1)
})

test_that("edge keys do not collide when vertex names contain dashes", {
  V <- c("a-b", "c", "a", "b-c")
  E <- list(c("a-b", "c"), c("a", "b-c"))
  g <- Graph(V, E, layout = "circular", edge_config = list(stroke_width = 7, "a\\-b-c" = list(stroke_color = BLUE)))
  expect_length(g$edges, 2)
  expect_false(identical(g$get(c("a-b", "c"))$mob_id, g$get(c("a", "b-c"))$mob_id))
  expect_equal(g$get(c("a-b", "c"))$get_stroke_color(), BLUE)
  expect_equal(g$get(c("a", "b-c"))$stroke_width, 7)
  expect_error(Graph(V, E, edge_config = list("a-b-c" = list(stroke_color = BLUE))), "several edges")
  g$remove_edges(c("a", "b-c"))
  expect_length(g$edges, 1)
  expect_equal(g$get(c("a-b", "c"))$get_stroke_color(), BLUE)
  g$add_edges(c("a", "b-c"), edge_config = list("a-b\\-c" = list(stroke_color = RED)))
  expect_equal(g$get(c("a", "b-c"))$get_stroke_color(), RED)
  # Entries for edges that do not exist are not passed to the edge type.
  expect_silent(Graph(1:2, list(c(1, 2)), edge_config = list("1-3" = list(color = RED))))
})

test_that("graph mutations animate like upstream's override_animate", {
  g <- Graph(1:3, list(c(1, 2), c(2, 3)), layout = "circular")
  removed <- character()
  scene <- list(remove = function(m) removed <<- c(removed, m$mob_id))
  anim <- prepare_animation(g$animate(run_time = 2)$add_vertices(4, positions = list("4" = c(2, 2, 0))))
  expect_s3_class(anim, "AnimationGroup")
  expect_identical(anim$mobject, g)
  expect_s3_class(anim$animations[[1]], "Create")
  expect_equal(anim$animations[[1]]$run_time, 2)
  # The vertex joins the graph only when the animation is cleaned up.
  expect_false("4" %in% g$vertex_ids())
  new_vertex <- anim$animations[[1]]$mobject
  anim$begin()
  anim$finish()
  anim$clean_up_from_scene(scene)
  expect_true("4" %in% g$vertex_ids())
  expect_identical(g$get(4)$mob_id, new_vertex$mob_id)
  expect_equal(g$get(4)$get_center(), c(2, 2, 0))
  expect_true(new_vertex$mob_id %in% removed)

  anim <- prepare_animation(g$animate(animation = FadeIn)$add_edges(c(3, 4)))
  expect_s3_class(anim$animations[[1]], "FadeIn")
  expect_length(g$edges, 3)
  anim <- prepare_animation(g$animate$remove_edges(c(1, 2)))
  expect_s3_class(anim$animations[[1]], "Uncreate")
  expect_false(identical(anim$mobject, g))
  expect_length(g$edges, 2)
  anim <- prepare_animation(g$animate$remove_vertices(4))
  expect_identical(anim$mobject, g)
  expect_length(anim$animations, 2)
  expect_false("4" %in% g$vertex_ids())
})

# Tables and matrices -------------------------------------------------------------

test_that("MathTable and IntegerTable match upstream", {
  skip_if_no_latex()
  o <- misc_oracle()
  t <- MathTable(list(list("+", 0, 5), list(0, 0, 5), list(2, 2, 7)), include_outer_lines = TRUE)
  centers <- function(g) t(vapply(g$submobjects, function(e) e$get_center(), numeric(3)))
  expect_equal(centers(t$get_entries()), misc_mat(o$mathtable_entries), tolerance = 1e-6)
  hl <- t$get_horizontal_lines()$submobjects
  vl <- t$get_vertical_lines()$submobjects
  expect_length(hl, length(o$mathtable_hlines))
  for (i in seq_along(hl)) expect_equal(hl[[i]]$points, misc_mat(o$mathtable_hlines[[i]]), tolerance = 1e-6)
  for (i in seq_along(vl)) expect_equal(vl[[i]]$points, misc_mat(o$mathtable_vlines[[i]]), tolerance = 1e-6)
  expect_equal(t$get_cell(c(2, 3))$points, misc_mat(o$mathtable_cell), tolerance = 1e-6)
  skip_if_not(exists("Integer"))
  t2 <- IntegerTable(list(c(0, 30), c(90, 60)), row_labels = list(MathTex("a"), MathTex("b")),
                     col_labels = list(MathTex("c"), MathTex("d")), h_buff = 1)
  expect_equal(centers(t2$get_entries()), misc_mat(o$inttable_entries), tolerance = 1e-6)
  expect_equal(t2$get_entries(c(2, 2))$get_center(), unlist(o$inttable_entry_22), tolerance = 1e-6)
})

test_that("Table organizes Paragraph entries and labels", {
  t <- Table(list(c("First", "Second"), c("Third", "Fourth")), row_labels = list(Text("R1"), Text("R2")),
             col_labels = list(Text("C1"), Text("C2")))
  expect_length(t$get_entries()$submobjects, 8)
  expect_length(t$get_entries_without_labels()$submobjects, 4)
  expect_length(t$get_rows()$submobjects, 3)
  expect_length(t$get_columns()$submobjects, 3)
  expect_length(t$get_labels()$submobjects, 4)
  expect_identical(t$get_entries(c(2, 2))$mob_id, t$get_entries_without_labels(c(1, 1))$mob_id)
  expect_identical(t$get_entries(c(1, 2))$mob_id, t$col_labels[[1]]$mob_id)
  expect_length(t$get_horizontal_lines()$submobjects, 2)
  expect_length(t$get_vertical_lines()$submobjects, 2)
  cell <- t$get_cell(c(2, 2))
  entry <- t$get_entries(c(2, 2))
  expect_equal(cell$get_center()[2], entry$get_center()[2], tolerance = 0.3)
  expect_equal(cell$width, t$get_columns()$submobjects[[2]]$width + t$h_buff, tolerance = 1e-9)
  t$add_highlighted_cell(c(2, 2), color = GREEN)
  expect_s3_class(t$submobjects[[1]], "BackgroundRectangle")
  expect_identical(entry$background_rectangle$mob_id, t$submobjects[[1]]$mob_id)
  anim <- t$create()
  expect_length(anim$animations, 4)
  h <- t$h_buff
  t$scale(0.5)
  expect_equal(t$h_buff, h / 2)
  outer <- Table(list(c("a", "b")), include_outer_lines = TRUE, include_inner_lines = FALSE)
  expect_length(outer$get_horizontal_lines()$submobjects, 2)
  expect_length(outer$get_vertical_lines()$submobjects, 2)
  expect_error(Table(list(c("a", "b"), c("c"))), "same length")
  num <- Table(rbind(c(1, 2), c(3, 4)))
  expect_length(num$get_entries()$submobjects, 4)
  mt <- MobjectTable(list(list(Circle(), Square()), list(Square(), Circle())))
  expect_s3_class(mt$get_entries(c(1, 1)), "Circle")
})

test_that("Matrix layout matches upstream", {
  skip_if_no_latex()
  o <- misc_oracle()
  m <- Matrix(list(list(2, "\\pi"), list(-1, 1)))
  centers <- function(g) t(vapply(g$submobjects, function(e) e$get_center(), numeric(3)))
  expect_equal(centers(m$get_entries()), misc_mat(o$matrix_entries), tolerance = 1e-6)
  for (i in 1:2) expect_equal(misc_bbox(m$get_brackets()$submobjects[[i]]), unlist(o$matrix_brackets[[i]]),
                              tolerance = 1e-6)
  expect_equal(c(m$width, m$height), unlist(o$matrix_size), tolerance = 1e-6)
  expect_length(m$get_rows()$submobjects, 2)
  expect_length(m$get_columns()$submobjects[[1]]$submobjects, 2)
  expect_identical(m$get_mob_matrix()[[2]][[1]]$mob_id, m$get_entries()$submobjects[[3]]$mob_id)
  m$set_column_colors(RED, GREEN)
  expect_equal(m$get_entries()$submobjects[[3]]$get_color(), RED)
  expect_match(matrix_to_tex_string(matrix(1:4, 2)), "\\begin{array}{cc}1 & 3 \\\\ 2 & 4", fixed = TRUE)
  expect_match(matrix_to_tex_string(1:2), "{c}1 \\\\ 2", fixed = TRUE)
  det <- get_det_text(m, determinant = 3)
  expect_length(det$submobjects, 5)
  skip_if_not(exists("Integer"))
  im <- IntegerMatrix(rbind(c(3.7, 2), c(42.2, 12)), left_bracket = "(", right_bracket = ")")
  expect_equal(centers(im$get_entries()), misc_mat(o$intmatrix_entries), tolerance = 1e-6)
  expect_equal(c(im$width, im$height), unlist(o$intmatrix_size), tolerance = 1e-6)
})

# Labels --------------------------------------------------------------------------

test_that("polylabel finds the pole of inaccessibility like upstream", {
  skip_on_cran() # slow
  o <- misc_oracle()
  ring1 <- rbind(c(-3.8, -2.4), c(-2.4, -2.5), c(-1.3, -1.6), c(-0.2, -1.7), c(1.7, -2.5), c(2.9, -2.6),
                 c(3.5, -1.5), c(4.9, -1.4), c(4.5, 0.2), c(4.7, 1.6), c(3.5, 2.4), c(1.1, 2.5), c(-0.1, 0.9),
                 c(-1.2, 0.5), c(-1.6, 0.7), c(-1.4, 1.9), c(-2.6, 2.6), c(-4.4, 1.2), c(-4.9, -0.8), c(-3.8, -2.4))
  ring2 <- rbind(c(0.2, -1.2), c(0.9, -1.2), c(1.4, -2), c(2.1, -1.6), c(2.2, -0.5), c(1.4, 0), c(0.4, -0.2),
                 c(0.2, -1.2))
  ring3 <- rbind(c(-2.7, 1.4), c(-2.3, 1.7), c(-2.8, 1.9), c(-2.7, 1.4))
  cell <- polylabel(list(ring1, ring2, ring3), precision = 0.01)
  expect_equal(cell$c, unlist(o$polylabel$c), tolerance = 1e-9)
  expect_equal(cell$d, o$polylabel$d, tolerance = 1e-9)
  rect <- polylabel(list(rbind(c(0, 0), c(4, 0), c(4, 2), c(0, 2), c(0, 0))))
  expect_equal(rect$d, 1, tolerance = 0.01)
  pg <- LabeledPolygram(cbind(ring1, 0), cbind(ring2, 0), label = Text("Pole"))
  expect_equal(pg$label$get_center(), pg$pole, tolerance = 1e-9)
  expect_gt(pg$radius, 0)
})

test_that("Label, LabeledLine and LabeledArrow place their labels", {
  lab <- Label(Text("hi"), box_config = list(color = BLUE, fill_opacity = 0.75))
  expect_length(lab$submobjects, 3)
  expect_equal(lab$background_rect$get_fill_color(), BLUE)
  expect_equal(lab$frame$width, lab$rendered_label$width + 0.1, tolerance = 1e-9)
  expect_error(Label(42), "Unsupported label")
  # Only text mobjects, as upstream checks isinstance(label, (MathTex, Text, Typst));
  # MarkupText is not a Text upstream.
  expect_error(Label(MarkupText("a")), "Must be MathTex")
  expect_error(LabeledPolygram(rbind(c(0, 0, 0), c(1, 0, 0), c(0, 1, 0)), label = Square()), "Must be MathTex")
  ll <- LabeledLine(Text("x"), label_position = 0.25, start = LEFT * 2, end = RIGHT * 2)
  expect_equal(ll$label$get_center(), c(-1, 0, 0), tolerance = 1e-9)
  skip_if_no_latex()
  o <- misc_oracle()
  ll2 <- LabeledLine("0.5", label_position = 0.8, label_config = list(font_size = 20), start = LEFT + DOWN,
                     end = RIGHT + UP)
  expect_equal(misc_bbox(ll2$label), unlist(o$labeled_line_label), tolerance = 1e-6)
  la <- LabeledArrow("0.5", start = LEFT * 3, end = RIGHT * 3 + UP * 2, label_position = 0.5)
  expect_equal(la$label$get_center(), unlist(o$labeled_arrow_label), tolerance = 1e-6)
})

# Code ------------------------------------------------------------------------------

test_that("the code tokenizer finds R and Python tokens", {
  r <- code_tokenize("f <- function(x = 2L) {\n  # c\n  if (TRUE) 'a' else \"b\\n\"\n}", "r")
  expect_equal(r$kind, c("keyword", "number", "comment", "keyword", "constant", "string", "keyword", "string"))
  py <- code_tokenize("from a import b\ndef f(x):  # hi\n    return x + 1.5e3 if not None else '''s\n'''", "python")
  expect_equal(py$kind, c("namespace", "namespace", "keyword", "comment", "keyword", "number", "keyword",
                          "operator_word", "constant", "keyword", "string"))
  expect_equal(nrow(code_tokenize("x <- 1", "text")), 0)
  expect_equal(code_expand_tabs("a\tb\n\tc", 4), "a   b\n    c")
})

test_that("Code builds colored lines with line numbers and a background", {
  code <- "x <- 1\n\n# done\nif (x) y"
  cm <- Code(code_string = code, language = "r")
  expect_length(cm$code_lines$submobjects, 4)
  expect_length(cm$line_numbers$submobjects, 4)
  expect_identical(cm$submobjects[[1]]$mob_id, cm$background$mob_id)
  first <- cm$code_lines$submobjects[[1]]$submobjects
  # One submobject per character, spaces included, as upstream's Paragraph.
  expect_length(first, 6)
  expect_equal(first[[6]]$get_fill_color(), "#CD00CD")
  expect_equal(first[[1]]$get_fill_color(), "#CCCCCC")
  expect_equal(cm$background$get_fill_color(), "#000000")
  same <- Code(code_string = "x\nx\nx\nx", language = "r")
  ys <- vapply(same$code_lines$submobjects, function(t) t$get_bottom()[2], 0)
  expect_equal(diff(ys), rep(diff(ys)[1], 3), tolerance = 1e-9)
  # Indentation is kept.
  ind <- Code(code_string = "a\n    b", language = "r", add_line_numbers = FALSE)
  l1 <- ind$code_lines$submobjects[[1]]$submobjects[[1]]
  l2 <- ind$code_lines$submobjects[[2]]$submobjects[[1]]
  expect_gt(l2$get_left()[1] - l1$get_left()[1], 3 * l1$width)
  win <- Code(code_string = "x", language = "python", background = "window", formatter_style = "monokai")
  expect_length(win$background$submobjects, 1)
  expect_equal(win$background$get_fill_color(), "#272822")
  expect_error(Code(), "Either a code file")
  expect_error(Code(code_string = "x", formatter_style = "nope"), "Unknown formatter_style")
})

test_that("Code passes paragraph_config text options to every line", {
  args <- list(font = "mono", font_size = 30, weight = "BOLD", slant = "ITALIC")
  cm <- Code(code_string = "x <- 1", language = "r", paragraph_config = args)
  centered <- function(g) g$points - rep(g$get_center(), each = nrow(g$points))
  glyph <- function(txt) do.call(Text, c(list(txt, should_center = FALSE), args))$submobjects[[1]]
  expect_equal(centered(cm$code_lines$submobjects[[1]]$submobjects[[1]]), centered(glyph("x")))
  expect_equal(centered(cm$line_numbers$submobjects[[1]]$submobjects[[1]]), centered(glyph("1")))
})

# Banner ------------------------------------------------------------------------------

test_that("ManimBanner matches upstream geometry and expands", {
  o <- misc_oracle()
  b <- ManimBanner()
  expect_equal(b$M$points, misc_mat(o$banner_M_points), tolerance = 1e-8)
  expect_equal(misc_bbox(b$M), unlist(o$banner_M), tolerance = 1e-8)
  for (i in 1:3) expect_equal(misc_bbox(b$shapes$submobjects[[i]]), unlist(o$banner_shapes[[i]]), tolerance = 1e-8)
  for (i in 1:4) expect_equal(misc_bbox(b$anim$submobjects[[i]]), unlist(o$banner_anim[[i]]), tolerance = 1e-8)
  expect_false(b$anim$mob_id %in% b$submobject_ids())
  b$scale(0.5)
  expect_equal(b$scale_factor, 0.5)
  anim <- b$expand()
  anim$begin()
  anim$finish()
  expect_true(b$anim$mob_id %in% b$submobject_ids())
  expect_error(b$expand(direction = "up"), "direction")
  expect_s3_class(ManimBanner(dark_theme = FALSE)$create(), "AnimationGroup")
})

test_that("OpenGL mobject classes are their Cairo counterparts", {
  c1 <- OpenGLCircle(radius = 2)
  expect_s3_class(c1, "OpenGLCircle")
  expect_s3_class(c1, "Circle")
  expect_equal(c1$width, 4)
  for (n in names(manimR:::OPENGL_MOBJECT_CLASSES)) {
    expect_equal(get(paste0(n, "Class"))$get_inherit()$classname, manimR:::OPENGL_MOBJECT_CLASSES[[n]])
  }
  s <- OpenGLSurface(function(u, v) c(u, v, u * v), u_range = c(-1, 1), v_range = c(-1, 1), resolution = 9)
  expect_length(OpenGLSurfaceMesh(s, resolution = c(5, 5))$submobjects, 10)
  tex <- OpenGLTexturedSurface(s, matrix(c("red", "blue", "green", "white"), 2, 2))
  cols <- vapply(tex$list_of_faces[c(1, 8, 57, 64)], function(f) f$get_fill_color(), "")
  expect_equal(toupper(cols), c("#0000FF", "#FF0000", "#FFFFFF", "#00FF00"))
  expect_identical(get_vectorized_mobject_class(), VMobjectClass)
})

test_that("OpenGLTexturedSurface shows its dark image on faces turned from the light", {
  plane <- OpenGLSurface(function(u, v) c(u, v, 0), u_range = c(-1, 1), v_range = c(-1, 1), resolution = 3)
  tex <- OpenGLTexturedSurface(plane, matrix("red", 2, 2), dark_image_file = matrix("blue", 2, 2))
  colors <- function(camera = NULL) {
    unique(toupper(vapply(tex$list_of_faces, function(f) manimR:::opengl_texture_shade(f, camera)$get_fill_color(), "")))
  }
  # The faces' normal is OUT, toward the light at (-10, 10, 10).
  expect_equal(colors(), "#FF0000")
  tex$rotate(PI, axis = RIGHT)
  expect_equal(colors(), "#0000FF")
  # The light turns with the view, as upstream's light_source_position
  # uniform: a camera looking from below still sees the dark side.
  cam <- ThreeDCamera()
  cam$set_phi(PI)
  cam$reset_rotation_matrix()
  expect_equal(colors(cam), "#0000FF")
  # The camera blends the faces when it draws them: turned back to OUT, the
  # faces show the light image again.
  tex$rotate(PI, axis = RIGHT)
  tex$list_of_faces[[1]]$set_fill(GREEN)
  tex$set_opacity(0.4)
  cap <- ragg::agg_capture(width = 160, height = 90)
  on.exit(grDevices::dev.off())
  Camera(pixel_width = 160, pixel_height = 90)$draw_frame(list(tex))
  expect_equal(toupper(tex$list_of_faces[[1]]$get_fill_color()), "#FF0000")
  expect_equal(tex$list_of_faces[[1]]$get_fill_opacity(), 0.4)
  # One face at the origin with its normal (1, 1, 0) at right angles to the
  # light: smoothstep gives half of each image.
  one <- OpenGLSurface(function(u, v) c(u, v, 0), u_range = c(-1, 1), v_range = c(-1, 1), resolution = 2)
  tex <- OpenGLTexturedSurface(one, matrix("red", 2, 2), dark_image_file = matrix("blue", 2, 2))
  tex$rotate(PI / 2, axis = c(-1, 1, 0), about_point = ORIGIN)
  face <- manimR:::opengl_texture_shade(tex$list_of_faces[[1]])
  expect_lte(max(abs(color_to_rgb(face$get_fill_color()) * 255 - c(127.5, 0, 127.5))), 0.5)
  # A disk around a pole: the faces at the center, whose u edge has no
  # length, face down as the others do, away from the light.
  disk <- OpenGLSurface(function(u, v) c(v * cos(u), v * sin(u), 1), u_range = c(0, 2 * PI), v_range = c(0, 1), resolution = 5)
  tex <- OpenGLTexturedSurface(disk, matrix("red", 2, 2), dark_image_file = matrix("blue", 2, 2))
  at_pole <- vapply(tex$list_of_faces, function(f) f$v1 == 0, NA)
  expect_true(any(at_pole))
  expect_equal(unique(toupper(vapply(tex$list_of_faces, function(f) f$get_fill_color(), ""))), "#0000FF")
  # A 3D camera looking from below sees the same dark faces.
  cam <- ThreeDCamera(pixel_width = 160, pixel_height = 90)
  cam$set_phi(PI)
  cap2 <- ragg::agg_capture(width = 160, height = 90)
  cam$draw_frame(list(tex))
  grDevices::dev.off()
  expect_equal(unique(toupper(vapply(tex$list_of_faces, function(f) f$get_fill_color(), ""))), "#0000FF")
})

test_that("Code reads its defaults from the class attributes", {
  expect_equal(CodeClass$default_paragraph_config$font, "Monospace")
  old <- CodeClass$default_background_config
  on.exit(CodeClass$default_background_config <- old)
  a <- Code(code_string = "x <- 1", language = "r", background = "rectangle")
  CodeClass$default_background_config$buff <- 1
  b <- Code(code_string = "x <- 1", language = "r", background = "rectangle")
  expect_gt(b$background$width, a$background$width + 1)
})
