# Tests for the public utilities ported from manim.utils (bezier, space_ops,
# simple_functions, debug, tex_templates), the 3D VMobject helpers and
# register_font. Reference values come from Python manim via
# data-raw/utils_oracle.py.

util_oracle <- function() {
  skip_if_not_installed("jsonlite")
  jsonlite::fromJSON(test_path("fixtures", "utils_oracle.json"), simplifyVector = FALSE)
}

util_mat <- function(x) {
  if (!length(x)) return(matrix(0, 0, 3))
  do.call(rbind, lapply(x, function(r) as.numeric(unlist(r))))
}

util_skip_if_no_latex <- function(env = parent.frame()) {
  skip_if(Sys.which("latex") == "" || Sys.which("dvisvgm") == "", "LaTeX or dvisvgm not available")
  old <- manim_config(media_dir = file.path(tempdir(), "manimR-test-utilities"))
  do.call(on.exit, list(substitute(.manim$config <- old, list(old = old)), add = TRUE), envir = env)
}

# Bezier ------------------------------------------------------------------------

test_that("split, subdivide and partial Bezier points match upstream", {
  o <- util_oracle()
  for (nm in names(o$curves)) {
    pts <- util_mat(o$curves[[nm]])
    expect_equal(split_bezier(pts, 0.3), util_mat(o$split_bezier[[nm]]), tolerance = 1e-9, info = nm)
    expect_equal(unname(partial_bezier_points(pts, 0.2, 0.7)), util_mat(o$partial_bezier_points[[nm]]),
                 tolerance = 1e-9, info = nm)
    if (nm %in% c("line", "quad", "cubic")) {
      expect_equal(unname(subdivide_bezier(pts, 3)), util_mat(o$subdivide_bezier[[nm]]), tolerance = 1e-9, info = nm)
    }
  }
  # Upstream's fallback for degree 4 and up splits at 1/3 and 1/2 instead of
  # 1/3 and 2/3; manimR splits at i / n as upstream documents.
  quartic <- util_mat(o$curves$quartic)
  pieces <- subdivide_bezier(quartic, 3)
  expect_equal(pieces[c(1, 5, 6, 10, 11, 15), ], bezier(quartic)(c(0, 1, 1, 2, 2, 3) / 3), tolerance = 1e-12)
  expect_equal(bezier_remap(Circle()$points, 13), util_mat(o$bezier_remap_circle), tolerance = 1e-9)
})

test_that("integer_interpolate, mid and is_closed match upstream", {
  o <- util_oracle()
  args <- list(c(0, 10, 0.46), c(0, 10, 1), c(0, 10, 0), c(2, 7, 0.33), c(0, 3, 0.999))
  for (k in seq_along(args)) {
    res <- do.call(integer_interpolate, as.list(args[[k]]))
    expect_identical(res$index, as.integer(o$integer_interpolate[[k]][[1]]))
    expect_equal(res$residue, o$integer_interpolate[[k]][[2]], tolerance = 1e-12)
  }
  expect_equal(mid(1, 4), o$mid[[1]])
  expect_equal(mid(c(1, 2, 3), c(3, 4, 5)), unlist(o$mid[[2]]))
  # manim 0.20.1 (the oracle) compares against a signed tolerance, so a curve
  # starting at a negative coordinate never counts as closed; current
  # upstream, followed here, uses abs(start).
  for (nm in names(o$is_closed)) {
    expected <- if (nm == "negative_start") TRUE else o$is_closed[[nm]]
    expect_identical(is_closed(util_mat(o$is_closed_points[[nm]])), expected, info = nm)
  }
})

test_that("smooth handles match upstream", {
  o <- util_oracle()
  for (nm in names(o$smooth_anchors)) {
    anchors <- util_mat(o$smooth_anchors[[nm]])
    h <- get_smooth_cubic_bezier_handle_points(anchors)
    if (nm == "negative_closed") {
      # The 0.20.1 oracle smooths this closed curve as open (its is_closed
      # bug); closed smoothing is translation invariant, so compare with the
      # same curve moved to positive coordinates.
      shift <- matrix(c(10, 10, 0), nrow(anchors) - 1, 3, byrow = TRUE)
      hs <- get_smooth_cubic_bezier_handle_points(anchors + rbind(shift, shift[1, ]))
      expect_equal(h$h1, hs$h1 - shift, tolerance = 1e-9)
      expect_equal(h$h2, hs$h2 - shift, tolerance = 1e-9)
      next
    }
    expect_equal(unname(h$h1), util_mat(o$smooth_handles[[nm]][[1]]), tolerance = 1e-9, info = nm)
    expect_equal(unname(h$h2), util_mat(o$smooth_handles[[nm]][[2]]), tolerance = 1e-9, info = nm)
  }
})

test_that("points on Bezier curves are found as upstream finds them", {
  o <- util_oracle()
  for (nm in names(o$proportions)) {
    case <- o$proportions[[nm]]
    p <- unlist(case$point)
    ctrl <- util_mat(case$control)
    expect_equal(proportions_along_bezier_curve_for_point(p, ctrl), as.numeric(unlist(case$roots)), info = nm)
    expect_identical(point_lies_on_bezier(p, ctrl), case$lies, info = nm)
  }
  expect_error(proportions_along_bezier_curve_for_point(c(1, 2), util_mat(o$curves$cubic)), "shapes")
})

# Space ops ---------------------------------------------------------------------

test_that("quaternion helpers match upstream", {
  o <- util_oracle()
  q1 <- c(0.5, 0.5, -0.5, 0.5)
  q2 <- c(1, 2, 3, 4)
  q3 <- c(0.1, -0.2, 0.3, 0.9)
  expect_equal(quaternion_mult(q1, q2, q3), unlist(o$quaternion_mult$three))
  expect_equal(quaternion_mult(q2), unlist(o$quaternion_mult$one))
  expect_equal(quaternion_mult(), unlist(o$quaternion_mult$none))
  expect_equal(quaternion_from_angle_axis(PI / 3, c(1, 2, 3)), unlist(o$quaternion_from_angle_axis$normalize))
  expect_equal(quaternion_from_angle_axis(0.7, c(0, 0, 2), axis_normalized = TRUE),
               unlist(o$quaternion_from_angle_axis$normalized))
  for (nm in c("small", "big")) {
    q <- if (nm == "small") quaternion_from_angle_axis(PI / 3, c(1, 2, 3)) else quaternion_from_angle_axis(3 * PI / 2, OUT)
    aa <- angle_axis_from_quaternion(q)
    expect_equal(aa$angle, o$angle_axis_from_quaternion[[nm]][[1]], info = nm)
    # For angles above pi current upstream (followed here) flips the axis,
    # which 0.20.1 forgot, so the result is the same rotation as q.
    sign <- if (nm == "big") -1 else 1
    expect_equal(aa$axis, sign * unlist(o$angle_axis_from_quaternion[[nm]][[2]]), tolerance = 1e-9, info = nm)
  }
  # manim 0.20.1 raises here; newer upstream falls back to the x axis.
  expect_equal(angle_axis_from_quaternion(c(1, 0, 0, 0)), list(angle = 0, axis = c(1, 0, 0)))
  expect_equal(quaternion_conjugate(c(1, 2, 3, 4)), unlist(o$quaternion_conjugate))
})

test_that("small space helpers match upstream", {
  o <- util_oracle()
  as_int <- function(m) `storage.mode<-`(m, "integer")
  expect_identical(thick_diagonal(5), as_int(util_mat(o$thick_diagonal$d5)))
  expect_identical(thick_diagonal(4, 3), as_int(util_mat(o$thick_diagonal$d4t3)))
  expect_equal(center_of_mass(rbind(c(0, 0, 0), c(2, 4, 6), c(1, -1, 3))), unlist(o$center_of_mass))
  expect_equal(center_of_mass(list(c(0, 0, 0), c(2, 4, 6), c(1, -1, 3))), unlist(o$center_of_mass))
  f <- complex_func_to_R3_func(function(z) z^2 + 1i)
  expect_equal(f(c(1, 2, 0)), unlist(o$complex_func_to_R3_func))
  expect_equal(cross2d(c(1, 2), c(3, 4)), o$cross2d$single)
  expect_equal(cross2d(rbind(c(1, 2, 0), c(1, 0, 0)), rbind(c(3, 4, 0), c(0, 1, 0))), unlist(o$cross2d$rows))
  for (nm in names(o$unit_normal_inputs)) {
    v <- o$unit_normal_inputs[[nm]]
    expect_equal(get_unit_normal(unlist(v[[1]]), unlist(v[[2]])), unlist(o$get_unit_normal[[nm]]),
                 tolerance = 1e-9, info = nm)
  }
  expect_equal(perpendicular_bisector(list(c(0, 0, 0), c(2, 2, 0))), util_mat(o$perpendicular_bisector$default))
  expect_equal(perpendicular_bisector(rbind(c(1, 0, 0), c(1, 2, 1)), c(0, 0, 2)),
               util_mat(o$perpendicular_bisector$norm))
  fi <- o$find_intersection
  expect_equal(find_intersection(util_mat(fi$p0s), util_mat(fi$v0s), util_mat(fi$p1s), util_mat(fi$v1s)),
               util_mat(fi$result))
  expect_equal(find_intersection(c(0, 0, 0), c(1, 1, 0), c(2, 0, 0), c(0, 1, 0)), util_mat(fi$result)[1, ])
})

test_that("polygon helpers match upstream", {
  o <- util_oracle()
  v <- Square()$get_vertices()
  expect_equal(get_winding_number(v), o$winding[[1]])
  expect_equal(get_winding_number(sweep(v, 2, 2 * UP, "+")), o$winding[[2]], tolerance = 1e-12)
  expect_equal(get_winding_number(rbind(v, v)), o$winding[[3]])
  tri <- rbind(c(0, 0), c(2, 0), c(1, 3))
  expect_equal(shoelace(tri), o$shoelace$ccw)
  expect_equal(shoelace(tri[3:1, ]), o$shoelace$cw)
  expect_identical(shoelace_direction(tri), o$shoelace$ccw_dir)
  expect_identical(shoelace_direction(tri[3:1, ]), o$shoelace$cw_dir)
  rv5 <- regular_vertices(5, radius = 2)
  expect_equal(rv5$vertices, util_mat(o$regular_vertices$v5), tolerance = 1e-9)
  expect_equal(rv5$start_angle, o$regular_vertices$a5)
  rv6 <- regular_vertices(6, start_angle = 0.3)
  expect_equal(rv6$vertices, util_mat(o$regular_vertices$v6), tolerance = 1e-9)
  expect_equal(rv6$start_angle, o$regular_vertices$a6)
  expect_equal(z_to_vector(c(1, 2, 3)), util_mat(o$z_to_vector$generic), tolerance = 1e-9)
  expect_equal(z_to_vector(c(2, 0, 0)), util_mat(o$z_to_vector$x), tolerance = 1e-9)
})

test_that("earclip_triangulation matches upstream index for index (1 based)", {
  o <- util_oracle()
  for (nm in names(o$earclip)) {
    case <- o$earclip[[nm]]
    tri <- earclip_triangulation(util_mat(case$verts), unlist(case$ring_ends))
    expect_identical(tri, as.integer(unlist(case$indices)) + 1L, info = nm)
  }
  # A bridge to the last vertex of a hole, where manim 0.20.1 gives up.
  outer <- rbind(c(0, 0, 0), c(6, 0, 0), c(6, 4, 0), c(0, 4, 0))
  hole <- rbind(c(1, 1, 0), c(1, 3, 0), c(2, 3, 0), c(2, 1, 0))
  tri <- matrix(earclip_triangulation(rbind(outer, hole[c(2, 3, 4, 1), ]), c(4, 8)), ncol = 3, byrow = TRUE)
  verts <- rbind(outer, hole[c(2, 3, 4, 1), ])
  area <- sum(apply(tri, 1, function(t) abs(cross2d(verts[t[2], ] - verts[t[1], ], verts[t[3], ] - verts[t[1], ])) / 2))
  expect_equal(area, 24 - 2)
})

# simple_functions --------------------------------------------------------------

test_that("binary_search and sigmoid match upstream", {
  o <- util_oracle()
  quad <- function(x) x^2 + 3 * x + 1
  expect_equal(binary_search(quad, 11, 0, 5), o$binary_search$quadratic)
  expect_equal(binary_search(quad, 11, 0, 5, tolerance = 0.01), o$binary_search$quadratic_tol)
  expect_null(binary_search(quad, 71, 0, 5))
  expect_equal(binary_search(function(x) 10 - x, 7.3, 0, 5), o$binary_search$decreasing)
  expect_equal(binary_search(function(x) 2 * x, 0, 0, 5), o$binary_search$exact_lower)
  expect_equal(sigmoid(c(-2, 0, 0.5, 3)), unlist(o$sigmoid))
})

# 3D helpers --------------------------------------------------------------------

test_that("3D VMobject corners and normals match upstream (0 based indices)", {
  o <- util_oracle()
  mobs <- list(
    square = Square(side_length = 2)$rotate(PI / 3, axis = RIGHT)$shift(OUT),
    circle = Circle()$rotate(PI / 4, axis = UP)$shift(LEFT),
    line = Line(LEFT, RIGHT + UP)
  )
  for (nm in names(mobs)) {
    m <- mobs[[nm]]
    ref <- o$three_d[[nm]]
    expect_equal(m$points, util_mat(ref$points), tolerance = 1e-9, info = nm)
    expect_equal(get_3d_vmob_start_corner_index(m), ref$start_index, info = nm)
    expect_equal(get_3d_vmob_end_corner_index(m), ref$end_index, info = nm)
    expect_equal(get_3d_vmob_start_corner(m), unlist(ref$start), tolerance = 1e-9, info = nm)
    expect_equal(get_3d_vmob_end_corner(m), unlist(ref$end), tolerance = 1e-9, info = nm)
    expect_equal(do.call(rbind, get_3d_vmob_gradient_start_and_end_points(m)), util_mat(ref$gradient),
                 tolerance = 1e-9, info = nm)
    expect_equal(get_3d_vmob_start_corner_unit_normal(m), unlist(ref$start_normal), tolerance = 1e-9, info = nm)
    expect_equal(get_3d_vmob_end_corner_unit_normal(m), unlist(ref$end_normal), tolerance = 1e-9, info = nm)
    expect_equal(get_3d_vmob_unit_normal(m, 7), unlist(ref$normal_at_7), tolerance = 1e-9, info = nm)
  }
})

# Debug helpers -----------------------------------------------------------------

test_that("print_family prints the tree with one tab per level", {
  g <- VGroup(Square(), VGroup(Circle(), Dot()))
  out <- capture.output(res <- print_family(g))
  expect_identical(res, g)
  expect_length(out, 5)
  expect_match(out[1], paste0("^ VGroup ", g$mob_id, "$"))
  expect_match(out[3], "^\t VGroup ")
  expect_match(out[5], paste0("^\t\t Dot ", g[2][2]$mob_id, "$"))
})

test_that("index_labels places 1 based labels like upstream", {
  util_skip_if_no_latex()
  o <- util_oracle()
  group <- VGroup(Square(), Circle()$shift(3 * RIGHT), Dot(2 * UP + LEFT), Line(DOWN, 2 * DOWN + RIGHT))
  labels <- index_labels(group)
  expect_length(labels$submobjects, 4)
  expect_equal(vapply(labels$submobjects, function(l) l$get_value(), 0), 1:4)
  expect_equal(do.call(rbind, lapply(labels$submobjects, function(l) l$get_center())),
               util_mat(o$index_labels$centers), tolerance = 1e-9)
  expect_equal(vapply(labels$submobjects, function(l) l$height, 0), unlist(o$index_labels$heights), tolerance = 1e-9)
  bg <- labels[1]$family_members_with_points()[[1]]
  expect_equal(bg$background_stroke_width, o$index_labels$background_stroke_width[[1]])
  expect_equal(toupper(manim_color(rgb_to_color(bg$background_stroke_rgbas[1, 1:3]))),
               toupper(o$index_labels$background_stroke_color[[1]]))
  big <- index_labels(group, label_height = 0.4)
  expect_equal(vapply(big$submobjects, function(l) l$height, 0), unlist(o$index_labels$big_heights), tolerance = 1e-9)
})

# TeX templates -----------------------------------------------------------------

test_that("template libraries reproduce upstream's templates exactly", {
  o <- util_oracle()
  fields <- c("tex_compiler", "output_format", "description", "documentclass", "preamble",
              "placeholder_text", "post_doc_commands")
  for (lib in c("tex_template_library", "tex_font_templates")) {
    tpls <- if (lib == "tex_template_library") TexTemplateLibrary() else TexFontTemplates()
    expect_identical(names(tpls), names(o[[lib]]))
    for (nm in names(tpls)) {
      for (f in fields) expect_identical(tpls[[nm]][[f]], o[[lib]][[nm]][[f]], info = paste(nm, f))
      expect_identical(tpls[[nm]]$body(), o[[lib]][[nm]]$body, info = nm)
    }
  }
  # Every call gives fresh templates, so changing one does not leak.
  TexTemplateLibrary()$simple$add_to_preamble("\\usepackage{xcolor}")
  expect_identical(TexTemplateLibrary()$simple$preamble, o$tex_template_library$simple$preamble)
})

test_that("library templates compile MathTex with the upstream preamble", {
  util_skip_if_no_latex()
  o <- util_oracle()
  for (case in list(c("tex_template_library", "simple"), c("tex_font_templates", "latin_modern_tw"))) {
    tpl <- if (case[1] == "tex_template_library") TexTemplateLibrary()[[case[2]]] else TexFontTemplates()[[case[2]]]
    if (case[2] == "latin_modern_tw") {
      found <- if (nzchar(Sys.which("kpsewhich"))) suppressWarnings(system2("kpsewhich", "mathastext.sty", stdout = TRUE))
      skip_if(!length(found), "mathastext not installed")
    }
    svg <- tex_to_svg_file("x^2", environment = "align*", tex_template = tpl)
    tex <- paste(readLines(sub("\\.svg$", ".tex", svg)), collapse = "\n")
    expect_true(grepl(o[[case[1]]][[case[2]]]$preamble, tex, fixed = TRUE), info = case[2])
    m <- MathTex("x^2", tex_template = tpl)
    expect_gt(length(m$family_members_with_points()), 0)
  }
})

# Fonts -------------------------------------------------------------------------

test_that("register_font makes a font file usable by Text", {
  # Any font file that is not installed system wide; TeX Live ships many.
  files <- Sys.glob(c("/usr/local/texlive/*/texmf-dist/fonts/truetype/public/arvo/Arvo-Regular.ttf",
                      "/usr/local/texlive/*/texmf-dist/fonts/opentype/public/tex-gyre/texgyreadventor-regular.otf"))
  usable <- function(f) {
    fam <- tryCatch(systemfonts::font_info(path = f)$family, error = function(e) "")
    nzchar(fam) && !fam %in% systemfonts::system_fonts()$family
  }
  files <- Filter(usable, files)
  skip_if(!length(files), "no font file outside the system fonts found")
  f <- files[1]
  expect_error(register_font(file.path(tempdir(), "no-such-font.ttf")), "Can't find")
  family <- register_font(f)
  expect_identical(family, systemfonts::font_info(path = f)$family)
  expect_identical(normalizePath(textshaping::shape_text("A", family = family)$shape$font_path), normalizePath(f))
  default <- Text("Ag")
  custom <- Text("Ag", font = family)
  expect_false(isTRUE(all.equal(custom[1]$points, default[1]$points)))
  # A second file of the family takes over only its own style.
  bold <- file.path(dirname(f), "Arvo-Bold.ttf")
  skip_if(basename(f) != "Arvo-Regular.ttf" || !file.exists(bold), "no bold companion file")
  register_font(bold)
  shaped_path <- function(...) normalizePath(textshaping::shape_text("A", family = family, ...)$shape$font_path)
  expect_identical(shaped_path(), normalizePath(f))
  expect_identical(shaped_path(weight = "bold"), normalizePath(bold))
})

test_that("register_font accepts a file of an installed family", {
  fonts <- systemfonts::system_fonts()
  fams <- vapply(fonts$path, function(f) {
    tryCatch(systemfonts::font_info(path = f)$family[1], error = function(e) "")
  }, "", USE.NAMES = FALSE)
  hit <- which(fams %in% fonts$family)
  skip_if(!length(hit), "no installed font whose file reports a listed family")
  expect_identical(register_font(fonts$path[hit[1]]), fams[hit[1]])
})

test_that("utility edge cases follow upstream", {
  expect_equal(get_winding_number(rbind(c(1, 0, 0))), 0)
  expect_equal(get_winding_number(list(c(1, 0, 0), c(0, 1, 0), c(-1, 0, 0), c(0, -1, 0))), 1)
  expect_equal(center_of_mass(data.frame(x = 1:2, y = 3:4, z = 0)), c(x = 1.5, y = 3.5, z = 0))
  expect_equal(nrow(subdivide_bezier(Line()$points, 0)), 0)
  expect_equal(nrow(bezier_remap(Line()$points, 0)), 0)
  q <- quaternion_from_angle_axis(3 * PI / 2, OUT)
  aa <- angle_axis_from_quaternion(q)
  expect_equal(rotate_vector(RIGHT, aa$angle, aa$axis), rotate_vector(RIGHT, 3 * PI / 2, OUT), tolerance = 1e-12)
})
