# Typst and MathTypst. Expected sizes and part indices come from Python
# manim (typst_mobject.py) with the typst 0.14 compiler at the default
# 1920 x 1080 configuration.

skip_if_no_typst <- function() {
  skip_if(!nzchar(typst_executable()), "typst compiler not available")
  skip_on_cran()
}

MANIMGRP_LABEL_PREAMBLE <- "#let manimgrp(lbl, body) = [#box(body) #label(lbl)]"

sub_index <- function(mob, part) match(part$submobject_ids(), mob$submobject_ids())

test_that("double brace groups are preprocessed like upstream", {
  cases <- list(
    list("{{ a^2 + b^2 : lhs }} = {{ c^2 }}", "manimgrp(\"lhs\", a^2 + b^2) = manimgrp(\"_grp-0\", c^2)", c("lhs", "_grp-0")),
    list("{{ {{ a }} + b : outer }} = x + {{ x }}",
         "manimgrp(\"outer\", manimgrp(\"_grp-0\", a) + b) = x + manimgrp(\"_grp-1\", x)", c("outer", "_grp-0", "_grp-1")),
    list("\"{{ not }}\" + {{ \"}}\" : s }}", "\"{{ not }}\" + manimgrp(\"s\", \"}}\")", "s"),
    list("[{{ y }}] {{ [}}] z }}", "[{{ y }}] manimgrp(\"_grp-0\", [}}] z)", "_grp-0"),
    list("{{ a + {{ b", "{{ a + {{ b", character()),
    list("{{a:lab-1}} {{ x : 1bad }}", "manimgrp(\"lab-1\", a) manimgrp(\"_grp-0\", x : 1bad)", c("lab-1", "_grp-0")),
    list("{{ a + {{ b : inner }} + c : outer }}", "manimgrp(\"outer\", a + manimgrp(\"inner\", b) + c)", c("outer", "inner"))
  )
  for (cs in cases) {
    p <- typst_preprocess_groups(cs[[1]])
    expect_identical(p$processed, cs[[2]])
    expect_identical(p$labels, cs[[3]])
  }
  p <- typst_preprocess_groups("x =_(\"{{ not a group }}\") z")
  expect_identical(p$labels, character())
  p <- typst_preprocess_groups("[text {{ here }}] {{ real }}")
  expect_identical(p$labels, "_grp-0")
  expect_identical(lengths(regmatches(p$processed, gregexpr("manimgrp", p$processed))), 1L)
})

test_that("hidden leaves are matched as a subsequence", {
  expect_identical(typst_hidden_leaf_indices(c("a", "b", "a", "c"), c("a", "c")), c(2L, 3L))
  expect_identical(typst_hidden_leaf_indices(c("a", "b"), c("a", "b")), integer())
  expect_error(typst_hidden_leaf_indices(c("a", "b"), c("b", "x")), "changed visible SVG geometry")
  expect_identical(typst_manimgrp_preamble(NULL),
                   "#let manimgrp(lbl, body) = if lbl == none { hide(body) } else { body }")
  expect_identical(typst_manimgrp_preamble("lhs"),
                   "#let manimgrp(lbl, body) = if lbl == \"lhs\" { hide(body) } else { body }")
})

test_that("a missing compiler gives a helpful error", {
  d <- withr_tempdir()
  with_manim_config(list(typst = file.path(d, "no-typst-here"), media_dir = d), {
    expect_error(typst_to_svg_file("x"), "typst compiler was not found")
  })
})

test_that("Typst sizes follow font_size like upstream", {
  skip_if_no_typst()
  m <- Typst("*Hello* from _Typst!_", color = YELLOW, font_size = 72)
  expect_equal(c(m$width, m$height), c(5.5485000093, 0.701999998575), tolerance = 1e-5)
  expect_length(m$submobjects, 15)
  expect_equal(m$font_size, 72)
  expect_true(all(vapply(m$submobjects, function(s) s$get_fill_color(), "") == toupper(YELLOW)))
  expect_output(print(m), "Typst('*Hello* from _Typst!_')", fixed = TRUE)

  i <- Typst("$ integral_a^b f(x) dif x $")
  expect_equal(c(i$width, i$height), c(2.348366697, 1.33240001), tolerance = 1e-5)
  expect_equal(i$font_size, 48)
  h <- i$height
  i$font_size <- 96
  expect_equal(i$font_size, 96)
  expect_equal(i$height, 2 * h)
  expect_error(i$font_size <- -1, "font_size must be greater than 0")

  s <- MathTypst("sum_(k=1)^n k = frac(n(n + 1), 2)", font_size = 72)
  expect_equal(s$typst_code, "$ sum_(k=1)^n k = frac(n(n + 1), 2) $")
  expect_equal(c(s$width, s$height), c(5.418499938, 1.931625), tolerance = 1e-5)
  expect_length(s$submobjects, 15)

  fixed <- MathTypst("x^2", height = 1.5)
  expect_equal(c(fixed$width, fixed$height), c(1.604434847, 1.5), tolerance = 1e-5)
  expect_equal(Typst("$ e^(i pi) + 1 = 0 $")$file_name, Typst("$ e^(i pi) + 1 = 0 $")$file_name)
})

test_that("explicit Typst colors survive and black parts take the color", {
  skip_if_no_typst()
  m <- Typst("#text(fill: red)[R] G $x$")
  expect_equal(vapply(m$submobjects, function(s) s$get_fill_color(), ""), c("#FF4136", "#FFFFFF", "#FFFFFF"))
  expect_equal(c(m$width, m$height), c(1.14400000055, 0.33450000065), tolerance = 1e-5)
})

test_that("Typst strokes scale with the geometry", {
  skip_if_no_typst()
  with_manim_config(list(quality = "h"), {
    s <- MathTypst("sum_(k=1)^n k = frac(n(n + 1), 2)", font_size = 72)
    widths <- vapply(s$submobjects, function(x) x$get_stroke_width(), 1)
    expect_equal(widths, c(rep(0, 14), 2.43))
    c2 <- s$copy()
    c2$scale(2)
    expect_equal(c2$submobjects[[15]]$get_stroke_width(), 4.86)
    expect_equal(s$submobjects[[15]]$get_stroke_width(), 2.43)
    f <- MathTypst("frac(a,b)", font_size = 48)
    w <- max(vapply(f$submobjects, function(x) x$get_stroke_width(), 1))
    f$font_size <- 96
    expect_equal(max(vapply(f$submobjects, function(x) x$get_stroke_width(), 1)), 2 * w)
    st <- MathTypst("sqrt(x) + overline(y)", stroke_width = 3)
    expect_true(all(vapply(st$submobjects, function(x) x$get_stroke_width(), 1) == 3))
    expect_true(all(vapply(st$submobjects, function(x) x$get_stroke_opacity(), 1) == 1))
  })
  expect_true(any(vapply(Typst("#underline[abc]")$submobjects, function(x) x$get_stroke_width(), 1) > 0))
})

test_that("MathTypst groups select the same parts as upstream", {
  skip_if_no_typst()
  e <- MathTypst("{{ a^2 + b^2 : lhs }} = {{ c^2 }}", font_size = 72)
  expect_equal(c(e$width, e$height), c(3.906600010125, 0.6831000303), tolerance = 1e-5)
  expect_identical(e$group_labels, c("lhs", "_grp-0"))
  expect_identical(e$user_label_keys(), c("lhs", "_grp-0"))
  expect_equal(sub_index(e, e$select("lhs")), 1:5)
  expect_equal(sub_index(e, e$select(1)), 7:8)
  e$select("lhs")$set_color(BLUE)
  expect_equal(e$submobjects[[1]]$get_fill_color(), toupper(BLUE))
  expect_equal(e$submobjects[[6]]$get_fill_color(), "#FFFFFF")

  n <- MathTypst("{{ a + b : num }} / {{ c : den }} = {{ lambda }} {{ x }}")
  expect_equal(sub_index(n, n$select("num")), 1:3)
  expect_equal(sub_index(n, n$select("den")), 4)
  expect_equal(sub_index(n, n$select(1)), 7)
  expect_equal(sub_index(n, n$select(2)), 8)
  expect_error(n$select(3), "out of range")
  expect_error(n$select("missing"), "No group with label 'missing'")

  nest <- MathTypst("{{ {{ a }} + b : outer }} = x + {{ x }}")
  expect_identical(nest$user_label_keys(), c("outer", "_grp-0", "_grp-1"))
  expect_equal(sub_index(nest, nest$select("outer")), 1:3)
  expect_equal(sub_index(nest, nest$select(1)), 1)
  expect_equal(sub_index(nest, nest$select(2)), 7)

  inner <- MathTypst("{{ a + {{ b : inner }} + c : outer }}")
  expect_length(inner$select("outer")$submobjects, 5)
  expect_length(inner$select("inner")$submobjects, 1)
  expect_true(inner$select("inner")[1]$mob_id %in% inner$select("outer")$submobject_ids())

  dup <- MathTypst("{{ a : picked }} + a + {{ a : picked }}")
  expect_length(unique(dup$select("picked")$submobject_ids()), 2)

  plain <- MathTypst("a + b")
  expect_identical(plain$group_labels, character())
  expect_false(grepl("manimgrp", plain$typst_preamble))
})

test_that("capture groups keep the math layout", {
  skip_if_no_typst()
  plain <- MathTypst("integral_0^infinity e^(-x^2) dif x = sqrt(pi)/2")
  grouped <- MathTypst("{{ integral_0^infinity e^(-x^2) dif x : integral }} = {{ sqrt(pi)/2 : result }}")
  expect_length(plain$submobjects, 15)
  expect_length(grouped$submobjects, 15)
  for (i in 1:15) expect_equal(plain$submobjects[[i]]$points, grouped$submobjects[[i]]$points)
  expect_length(grouped$select("integral")$submobjects, 9)
  expect_length(grouped$select("result")$submobjects, 5)
})

test_that("Typst labels become selectable groups", {
  skip_if_no_typst()
  src <- "
                #box[
                    *Typst* labels also work in regular markup.
                ] <headline>

                #let pick(body) = [#box(body) <picked>]
                We can highlight #pick[multiple] #pick[fragments] at once.
                "
  m <- Typst(src, font_size = 42)
  expect_equal(c(m$width, m$height), c(8.029875014, 1.222374991), tolerance = 1e-5)
  expect_length(m$submobjects, 73)
  expect_identical(m$user_label_keys(), c("headline", "picked"))
  expect_equal(sub_index(m, m$select("headline")), 1:35)
  expect_equal(sub_index(m, m$select("picked")), 50:66)

  f <- Typst("$ #manimgrp(\"numerator\", $a + b$) / #manimgrp(\"denom\", $c - d$) $",
             typst_preamble = MANIMGRP_LABEL_PREAMBLE)
  expect_length(f$id_to_vgroup_dict[["numerator"]]$submobjects, 3)
  expect_length(f$id_to_vgroup_dict[["denom"]]$submobjects, 3)
  p <- Typst("$ #manimgrp(\"picked\", $a$) + #manimgrp(\"picked\", $b$) $", typst_preamble = MANIMGRP_LABEL_PREAMBLE)
  expect_length(p$select("picked")$submobjects, 2)
  g <- Typst("$ #manimgrp(\"gamma\", $a$) $", typst_preamble = MANIMGRP_LABEL_PREAMBLE)
  expect_error(g$select("missing"), "gamma")
  expect_identical(Typst("$ a + b $")$user_label_keys(), character())
})

test_that("baseline frames follow the mobject", {
  skip_if_no_typst()
  expect_identical(Typst("Ggf")$baseline_frames, list())
  expect_error(Typst("Ggf")$get_baseline_frame(Typst("Ggf")[1]), "track_baselines = TRUE")
  m <- Typst("Ggf", track_baselines = TRUE)
  fr <- m$baseline_frames
  expect_length(fr, 3)
  # Upstream's reference frame is the SVG page frame for every element.
  for (f in fr) {
    expect_equal(f$orig[1:2], c(-0.40425, 0.214), tolerance = 1e-6)
    expect_equal(f$right[1:2], c(-0.35425, 0.214), tolerance = 1e-6)
    expect_equal(f$up[1:2], c(-0.40425, 0.164), tolerance = 1e-6)
  }
  m$shift(2 * RIGHT)
  shifted <- m$baseline_frames[[1]]
  for (k in c("orig", "right", "up")) expect_equal(shifted[[k]] - fr[[1]][[k]], c(2, 0, 0), tolerance = 1e-6)
  m$shift(-2 * RIGHT)$scale(2)$shift(UP)
  expect_equal(m$baseline_frames[[3]]$orig[1:2], c(-0.8085, 1.428), tolerance = 1e-6)
  expect_equal(m$baseline_frames[[3]]$up[1:2], c(-0.8085, 1.328), tolerance = 1e-6)
  e <- MathTypst("{{ a^2 + b^2 : lhs }} = c^2", track_baselines = TRUE)
  parts <- e$select("lhs")$submobjects
  expect_length(parts, 5)
  for (sm in parts) expect_equal(e$get_baseline_frame(sm)$orig[1:2], c(-1.3222, 0.2277), tolerance = 1e-6)
})
