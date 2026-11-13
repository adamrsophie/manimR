# SVG import. Replaces manim's svgelements based parser
# (manim/mobject/svg/svg_mobject.py) with an xml2 based one.

# Affine transforms are 3 x 3 matrices acting on column vectors (x, y, 1).
svg_identity <- function() diag(3)
svg_matrix <- function(a, b, c, d, e, f) matrix(c(a, b, 0, c, d, 0, e, f, 1), 3, 3)

svg_numbers <- function(s) {
  if (is.null(s) || is.na(s) || !nzchar(s)) return(numeric())
  m <- regmatches(s, gregexpr("[-+]?(?:\\d*\\.\\d+|\\d+\\.?)(?:[eE][-+]?\\d+)?", s, perl = TRUE))[[1]]
  as.numeric(m)
}

parse_svg_transform <- function(s) {
  M <- svg_identity()
  if (is.null(s) || is.na(s) || !nzchar(s)) return(M)
  parts <- regmatches(s, gregexpr("[A-Za-z]+\\s*\\([^)]*\\)", s))[[1]]
  for (p in parts) {
    name <- tolower(sub("\\s*\\(.*", "", p))
    v <- svg_numbers(sub("^[^(]*\\(", "", p))
    T <- switch(name,
      matrix = svg_matrix(v[1], v[2], v[3], v[4], v[5], v[6]),
      translate = svg_matrix(1, 0, 0, 1, v[1], if (length(v) > 1) v[2] else 0),
      scale = svg_matrix(v[1], 0, 0, if (length(v) > 1) v[2] else v[1], 0, 0),
      rotate = {
        a <- v[1] * pi / 180
        R <- svg_matrix(cos(a), sin(a), -sin(a), cos(a), 0, 0)
        if (length(v) >= 3) svg_matrix(1, 0, 0, 1, v[2], v[3]) %*% R %*% svg_matrix(1, 0, 0, 1, -v[2], -v[3]) else R
      },
      skewx = svg_matrix(1, 0, tan(v[1] * pi / 180), 1, 0, 0),
      skewy = svg_matrix(1, tan(v[1] * pi / 180), 0, 1, 0, 0),
      svg_identity()
    )
    M <- M %*% T
  }
  M
}

svg_length_px <- function(s, ref = 1) {
  if (is.null(s) || is.na(s) || !nzchar(s)) return(NA_real_)
  s <- trimws(s)
  tok <- regmatches(s, regexpr("^[-+]?(?:\\d*\\.\\d+|\\d+\\.?)(?:[eE][-+]?\\d+)?", s, perl = TRUE))
  if (!length(tok)) return(NA_real_)
  num <- as.numeric(tok)
  unit <- tolower(substring(s, nchar(tok) + 1))
  mult <- switch(unit, "px" = 1, "pt" = 4 / 3, "pc" = 16, "mm" = 96 / 25.4, "cm" = 96 / 2.54, "in" = 96,
                 "em" = 16, "ex" = 8, "%" = ref / 100, 1)
  num * mult
}

# Parse an SVG path data string into cubic points (4k x 3) in path
# coordinates, following VMobjectFromSVGPath.handle_commands.
svg_path_to_points <- function(d, quadratic = FALSE, long_lines = FALSE) {
  tokens <- regmatches(d, gregexpr("[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\\d*\\.\\d+|\\d+\\.?)(?:[eE][-+]?\\d+)?", d, perl = TRUE))[[1]]
  n <- length(tokens)
  out <- vector("list", 64)
  k <- 0L
  push <- function(a, b, c, e) {
    k <<- k + 1L
    if (k > length(out)) length(out) <<- 2 * length(out)
    out[[k]] <<- c(a, b, c, e)
  }
  add_cubic <- function(s, c1, c2, e) push(s, c1, c2, e)
  add_line <- function(s, e) add_cubic(s, (2 * s + e) / 3, (s + 2 * e) / 3, e)
  add_quad <- function(s, c, e) add_cubic(s, (s + 2 * c) / 3, (2 * c + e) / 3, e)
  if (quadratic) {
    # Upstream's handle_commands with 3 points per curve (the OpenGL
    # renderer): a cubic as two quadratics, a line or a quadratic as one,
    # each stored raised to a cubic.
    raise <- function(s, c, e) push(s, (s + 2 * c) / 3, (2 * c + e) / 3, e)
    add_quad <- function(s, c, e) raise(s, c, e)
    add_cubic <- function(s, c1, c2, e) {
      q <- get_quadratic_approximation_of_cubic(rbind(s), rbind(c1), rbind(c2), rbind(e))
      raise(q[1, ], q[2, ], q[3, ])
      raise(q[4, ], q[5, ], q[6, ])
    }
    add_line <- function(s, e) {
      if (long_lines) {
        mid <- (s + e) / 2
        add_quad(s, (s + mid) / 2, mid)
        s <- mid
      }
      add_quad(s, (s + e) / 2, e)
    }
  }
  i <- 1L
  cmd <- ""
  cur <- c(0, 0)
  start <- c(0, 0)
  last_c2 <- NULL
  last_q <- NULL
  # Upstream draws from its pen, which an arc with no pieces does not move,
  # while the path's current point does move.
  pen <- NULL
  from <- function() {
    s <- pen %||% cur
    pen <<- NULL
    s
  }
  is_cmd <- function(t) grepl("^[A-Za-z]$", t)
  num <- function() {
    v <- as.numeric(tokens[i])
    i <<- i + 1L
    v
  }
  flag <- function() {
    t <- tokens[i]
    if (nchar(t) > 1 && grepl("^[01]", t)) {
      tokens[i] <<- substr(t, 2, nchar(t))
      return(as.numeric(substr(t, 1, 1)))
    }
    i <<- i + 1L
    as.numeric(t)
  }
  while (i <= n) {
    if (is_cmd(tokens[i])) {
      cmd <- tokens[i]
      i <- i + 1L
      if (cmd %in% c("Z", "z")) {
        s <- from()
        if (sqrt(sum((s - start)^2)) > 1e-4) add_line(s, start)
        cur <- start
        last_c2 <- NULL
        last_q <- NULL
        next
      }
    }
    if (i > n || is_cmd(tokens[i])) next
    rel <- cmd == tolower(cmd)
    base <- if (rel) cur else c(0, 0)
    up <- toupper(cmd)
    if (up == "M") {
      p <- base + c(num(), num())
      cur <- p
      start <- p
      pen <- NULL
      cmd <- if (rel) "l" else "L"
      last_c2 <- NULL; last_q <- NULL
    } else if (up == "L") {
      p <- base + c(num(), num())
      add_line(from(), p); cur <- p
      last_c2 <- NULL; last_q <- NULL
    } else if (up == "H") {
      x <- num() + (if (rel) cur[1] else 0)
      p <- c(x, cur[2]); add_line(from(), p); cur <- p
      last_c2 <- NULL; last_q <- NULL
    } else if (up == "V") {
      y <- num() + (if (rel) cur[2] else 0)
      p <- c(cur[1], y); add_line(from(), p); cur <- p
      last_c2 <- NULL; last_q <- NULL
    } else if (up == "C") {
      c1 <- base + c(num(), num()); c2 <- base + c(num(), num()); p <- base + c(num(), num())
      add_cubic(from(), c1, c2, p); cur <- p; last_c2 <- c2; last_q <- NULL
    } else if (up == "S") {
      # As svgelements: the control point of the last curve is reflected,
      # whether that curve was cubic or quadratic.
      ctrl <- last_c2 %||% last_q
      c1 <- if (is.null(ctrl)) cur else 2 * cur - ctrl
      c2 <- base + c(num(), num()); p <- base + c(num(), num())
      add_cubic(from(), c1, c2, p); cur <- p; last_c2 <- c2; last_q <- NULL
    } else if (up == "Q") {
      q <- base + c(num(), num()); p <- base + c(num(), num())
      add_quad(from(), q, p); cur <- p; last_q <- q; last_c2 <- NULL
    } else if (up == "T") {
      ctrl <- last_q %||% last_c2
      q <- if (is.null(ctrl)) cur else 2 * cur - ctrl
      p <- base + c(num(), num())
      add_quad(from(), q, p); cur <- p; last_q <- q; last_c2 <- NULL
    } else if (up == "A") {
      rx <- num(); ry <- num(); phi <- num(); fa <- flag(); fs <- flag()
      p <- base + c(num(), num())
      pieces <- svg_arc_to_cubics(cur, rx, ry, phi, fa, fs, p)
      if (length(pieces)) {
        pieces[[1]][[1]] <- from()
        for (cb in pieces) add_cubic(cb[[1]], cb[[2]], cb[[3]], cb[[4]])
      } else {
        pen <- pen %||% cur
      }
      cur <- p; last_c2 <- NULL; last_q <- NULL
    } else {
      i <- i + 1L
    }
  }
  if (k == 0) return(matrix(0, 0, 3))
  m <- matrix(unlist(out[seq_len(k)]), ncol = 2, byrow = TRUE)
  cbind(m, 0)
}

# Endpoint parameterized elliptical arc to cubic Bezier segments, as
# svgelements' Arc (the SVG implementation notes) followed by
# Path.approximate_arcs_with_quads(): one quadratic piece for every tenth of
# a turn, raised to a cubic. An arc with a zero radius or equal end points
# has no pieces.
svg_arc_to_cubics <- function(p0, rx, ry, phi_deg, fa, fs, p1) {
  if (rx == 0 || ry == 0 || all(p0 == p1)) return(list())
  rx <- abs(rx); ry <- abs(ry)
  phi <- phi_deg * pi / 180
  cp <- cos(phi); sp <- sin(phi)
  dx <- (p0[1] - p1[1]) / 2; dy <- (p0[2] - p1[2]) / 2
  x1 <- cp * dx + sp * dy; y1 <- -sp * dx + cp * dy
  lam <- x1^2 / rx^2 + y1^2 / ry^2
  if (lam > 1) { rx <- rx * sqrt(lam); ry <- ry * sqrt(lam) }
  t1 <- rx^2 * y1^2; t2 <- ry^2 * x1^2
  co <- sqrt(abs((rx^2 * ry^2 - t1 - t2) / (t1 + t2))) * (if (fa == fs) -1 else 1)
  cxp <- co * rx * y1 / ry; cyp <- -co * ry * x1 / rx
  cx <- cp * cxp - sp * cyp + (p0[1] + p1[1]) / 2
  cy <- sp * cxp + cp * cyp + (p0[2] + p1[2]) / 2
  ux <- (x1 - cxp) / rx; uy <- (y1 - cyp) / ry
  vx <- (-x1 - cxp) / rx; vy <- (-y1 - cyp) / ry
  d <- min(1, max(-1, (ux * vx + uy * vy) / sqrt((ux^2 + uy^2) * (vx^2 + vy^2))))
  delta <- acos(d) * (180 / pi)
  if (ux * vy - uy * vx < 0) delta <- -delta
  delta <- delta %% 360
  if (!fs) delta <- delta - 360
  sweep <- 2 * pi * delta / 360
  nseg <- ceiling(abs(sweep) / (2 * pi * 0.1))
  if (nseg == 0) return(list())
  step <- sweep / nseg
  alpha <- (4 - cos(step)) / 3
  pt <- function(t, k = 1) {
    c(cx + k * (rx * cos(t) * cp - ry * sin(t) * sp), cy + k * (rx * cos(t) * sp + ry * sin(t) * cp))
  }
  t <- atan2(uy, ux)
  s <- p0
  out <- vector("list", nseg)
  for (j in seq_len(nseg)) {
    e <- if (j == nseg) p1 else pt(t + step)
    q <- pt(t + step / 2, alpha)
    out[[j]] <- list(s, (s + 2 * q) / 3, (2 * q + e) / 3, e)
    s <- e
    t <- t + step
  }
  out
}

svg_style_props <- c("fill", "fill-opacity", "stroke", "stroke-opacity", "stroke-width", "color",
                     "display", "visibility")

svg_node_style <- function(node, inherited) {
  st <- inherited
  a <- xml2::xml_attrs(node)
  for (nm in intersect(names(a), svg_style_props)) st[[nm]] <- a[[nm]]
  if ("style" %in% names(a)) {
    decls <- strsplit(a[["style"]], ";", fixed = TRUE)[[1]]
    for (dcl in decls) {
      kv <- strsplit(dcl, ":", fixed = TRUE)[[1]]
      if (length(kv) == 2) {
        key <- trimws(kv[1])
        if (key %in% svg_style_props) st[[key]] <- trimws(kv[2])
      }
    }
  }
  st
}

# CSS colors that R's X11 color table lacks or defines differently.
CSS_COLOR_OVERRIDES <- c(
  aqua = "#00FFFF", crimson = "#DC143C", fuchsia = "#FF00FF", indigo = "#4B0082", lime = "#00FF00",
  olive = "#808000", silver = "#C0C0C0", teal = "#008080", rebeccapurple = "#663399",
  gray = "#808080", grey = "#808080", green = "#008000", maroon = "#800000", purple = "#800080"
)

# Parse a CSS color. Returns list(color = "#RRGGBB", alpha = a), NA for
# "none" or "transparent", or NULL when the value cannot be parsed.
css_color <- function(value, current_color = NULL) {
  v <- trimws(value)
  lv <- tolower(v)
  if (lv %in% c("none", "transparent") || grepl("^url\\(", lv)) return(NA)
  if (lv == "currentcolor") return(css_color(current_color %||% "#000000"))
  hex <- function(r, g, b) sprintf("#%02X%02X%02X", as.integer(round(r)), as.integer(round(g)), as.integer(round(b)))
  if (grepl("^rgba?\\(", lv)) {
    parts <- trimws(strsplit(sub("^rgba?\\(([^)]*)\\).*$", "\\1", lv), "[,/ ]+")[[1]])
    parts <- parts[nzchar(parts)]
    ch <- vapply(parts[1:3], function(p) if (grepl("%", p)) as.numeric(sub("%", "", p)) * 2.55 else as.numeric(p), 0)
    a <- if (length(parts) >= 4) { p <- parts[4]; if (grepl("%", p)) as.numeric(sub("%", "", p)) / 100 else as.numeric(p) } else 1
    return(list(color = hex(ch[1], ch[2], ch[3]), alpha = a))
  }
  if (grepl("^hsla?\\(", lv)) {
    parts <- trimws(strsplit(sub("^hsla?\\(([^)]*)\\).*$", "\\1", lv), "[,/ ]+")[[1]])
    parts <- parts[nzchar(parts)]
    h <- (as.numeric(sub("deg", "", parts[1])) %% 360) / 360
    sat <- as.numeric(sub("%", "", parts[2])) / 100
    l <- as.numeric(sub("%", "", parts[3])) / 100
    a <- if (length(parts) >= 4) { p <- parts[4]; if (grepl("%", p)) as.numeric(sub("%", "", p)) / 100 else as.numeric(p) } else 1
    q <- if (l < 0.5) l * (1 + sat) else l + sat - l * sat
    pp <- 2 * l - q
    # As svgelements: the channels are truncated.
    f <- function(t) {
      if (t < 0) t <- t + 1
      if (t > 1) t <- t - 1
      if (6 * t < 1) pp + (q - pp) * 6 * t else if (2 * t < 1) q else if (3 * t < 2) pp + (q - pp) * (2 / 3 - t) * 6 else pp
    }
    ch <- if (sat == 0) rep(255 * l, 3) else 255 * c(f(h + 1 / 3), f(h), f(h - 1 / 3))
    return(list(color = hex(trunc(ch[1]), trunc(ch[2]), trunc(ch[3])), alpha = a))
  }
  if (grepl("^#[0-9a-f]{3,4}$", lv)) {
    ch <- strsplit(substring(lv, 2), "")[[1]]
    lv <- paste0("#", paste0(ch, ch, collapse = ""))
  }
  if (grepl("^#[0-9a-f]{6}([0-9a-f]{2})?$", lv)) {
    a <- if (nchar(lv) == 9) strtoi(substring(lv, 8, 9), 16L) / 255 else 1
    return(list(color = toupper(substring(lv, 1, 7)), alpha = a))
  }
  key <- gsub("[ _-]", "", lv)
  if (key %in% names(CSS_COLOR_OVERRIDES)) return(list(color = CSS_COLOR_OVERRIDES[[key]], alpha = 1))
  rgb <- tryCatch(grDevices::col2rgb(key), error = function(e) NULL)
  if (is.null(rgb)) return(NULL)
  list(color = hex(rgb[1], rgb[2], rgb[3]), alpha = 1)
}

# A paint as svgelements reads it: NA for "none", black for anything it
# cannot parse, and transparent as black with no opacity.
svg_paint <- function(value, current_color) {
  if (is.null(value)) return(NULL)
  lv <- tolower(trimws(value))
  if (lv == "transparent") return(list(color = "#000000", alpha = 0))
  if (grepl("^url\\(", lv)) return(list(color = "#000000", alpha = 1))
  css_color(value, current_color) %||% list(color = "#000000", alpha = 1)
}

# Opacities have 8 bits in svgelements. An opacity property replaces the
# alpha of its color.
svg_alpha <- function(paint, opacity) {
  o <- suppressWarnings(as.numeric(opacity %||% NA))
  if (is.na(o)) o <- paint$alpha
  round(min(1, max(0, o)) * 255) / 255
}

# As SVGMobject.apply_style_to_mobject: a paint of "none" leaves the color
# and the opacity of the converted mobject as they are. The opacity property
# is not read, as upstream.
apply_svg_style <- function(mob, st, M = svg_identity()) {
  # Exact names: `$` would match "stroke" to "stroke-width".
  fill <- svg_paint(st[["fill"]] %||% "#000000", st[["color"]])
  stroke <- svg_paint(st[["stroke"]] %||% "none", st[["color"]])
  # svgelements scales stroke widths with the element transform.
  sw <- svg_length_px(st[["stroke-width"]] %||% "1") * sqrt(abs(det(M[1:2, 1:2])))
  no_fill <- identical(fill, NA)
  no_stroke <- identical(stroke, NA)
  mob$set_style(
    fill_color = if (no_fill) NULL else fill$color,
    fill_opacity = if (no_fill) NULL else svg_alpha(fill, st[["fill-opacity"]]),
    stroke_color = if (no_stroke) NULL else stroke$color,
    stroke_opacity = if (no_stroke) NULL else svg_alpha(stroke, st[["stroke-opacity"]]),
    stroke_width = if (no_stroke) 0 else sw
  )
  mob
}

apply_svg_transform <- function(mob, M) {
  if (nrow(mob$points) == 0) return(mob)
  p <- mob$points
  xy <- M %*% rbind(p[, 1], p[, 2], 1)
  p[, 1] <- xy[1, ]
  p[, 2] <- xy[2, ]
  mob$points <- p
  mob
}

svg_shape_to_mobject <- function(node) {
  tag <- tolower(xml2::xml_name(node))
  a <- function(n, default = 0) {
    v <- xml2::xml_attr(node, n)
    if (is.na(v)) default else svg_length_px(v)
  }
  mob <- switch(tag,
    path = {
      d <- xml2::xml_attr(node, "d")
      if (is.na(d)) return(NULL)
      v <- VMobjectClass$new()
      v$points <- svg_path_to_points(d)
      v
    },
    line = Line(c(a("x1"), a("y1"), 0), c(a("x2"), a("y2"), 0)),
    rect = {
      w <- a("width"); h <- a("height")
      if (w <= 0 || h <= 0) return(NULL)
      rx <- a("rx", NA); ry <- a("ry", NA)
      if (is.na(rx) && !is.na(ry)) rx <- ry
      if (is.na(ry) && !is.na(rx)) ry <- rx
      m <- if (is.na(rx) || rx == 0 || ry == 0) Rectangle(width = w, height = h)
        else RoundedRectangle(width = w, height = h * rx / ry, corner_radius = rx)$stretch_to_fit_height(h)
      m$shift(c(a("x") + w / 2, a("y") + h / 2, 0))
    },
    circle = {
      r <- a("r")
      if (r <= 0) return(NULL)
      Circle(radius = r)$shift(c(a("cx"), a("cy"), 0))
    },
    ellipse = {
      rx <- a("rx"); ry <- a("ry")
      if (rx <= 0 || ry <= 0) return(NULL)
      m <- Circle(radius = rx)
      if (rx != ry) m$stretch_to_fit_height(2 * ry)
      m$shift(c(a("cx"), a("cy"), 0))
    },
    polygon = ,
    polyline = {
      v <- svg_numbers(xml2::xml_attr(node, "points"))
      if (length(v) < 4) return(NULL)
      pts <- cbind(matrix(v[seq_len(2 * (length(v) %/% 2))], ncol = 2, byrow = TRUE), 0)
      if (tag == "polygon") Polygon(pts) else VMobject()$set_points_as_corners(pts)
    },
    NULL
  )
  if (is.null(mob) || !mob$has_points()) return(NULL)
  mob
}

# Simple CSS support for <style> blocks: type, .class and #id selectors
# (comma separated), applied with selector specificity order.
parse_svg_css <- function(doc) {
  styles <- xml2::xml_find_all(doc, "//style")
  if (!length(styles)) return(list())
  css <- paste(xml2::xml_text(styles), collapse = "\n")
  css <- gsub("/\\*.*?\\*/", "", css, perl = TRUE)
  blocks <- regmatches(css, gregexpr("[^{}]+\\{[^{}]*\\}", css))[[1]]
  rules <- list()
  for (b in blocks) {
    sel <- trimws(strsplit(sub("\\{.*$", "", b), ",", fixed = TRUE)[[1]])
    body <- sub("^[^{]*\\{([^}]*)\\}$", "\\1", b)
    decls <- list()
    for (d in strsplit(body, ";", fixed = TRUE)[[1]]) {
      kv <- strsplit(d, ":", fixed = TRUE)[[1]]
      if (length(kv) == 2 && trimws(kv[1]) %in% svg_style_props) decls[[trimws(kv[1])]] <- trimws(kv[2])
    }
    for (s1 in sel) rules[[length(rules) + 1]] <- list(selector = s1, decls = decls)
  }
  rules
}

svg_apply_css <- function(node, st, rules) {
  if (!length(rules)) return(st)
  tag <- tolower(xml2::xml_name(node))
  classes <- strsplit(xml2::xml_attr(node, "class") %|na|% "", "\\s+")[[1]]
  id <- xml2::xml_attr(node, "id") %|na|% ""
  inline <- svg_node_style(node, list())
  spec <- function(sel) if (startsWith(sel, "#")) 3 else if (startsWith(sel, ".")) 2 else 1
  hits <- Filter(function(r) {
    sel <- r$selector
    (startsWith(sel, ".") && substring(sel, 2) %in% classes) ||
      (startsWith(sel, "#") && substring(sel, 2) == id) || tolower(sel) == tag || sel == "*"
  }, rules)
  hits <- hits[order(vapply(hits, function(r) spec(r$selector), 0))]
  for (r in hits) for (k in names(r$decls)) st[[k]] <- r$decls[[k]]
  # Presentation attributes and inline styles on the element itself win.
  for (k in intersect(names(inline), svg_style_props)) st[[k]] <- inline[[k]]
  st
}

`%|na|%` <- function(a, b) if (is.null(a) || is.na(a)) b else a

#' @title SVGMobject
#' @description Import an SVG file as vectorized mobjects. Paths, rectangles,
#'   circles, ellipses, lines, polylines, polygons, groups, `<use>`
#'   references, transforms, CSS and fill/stroke styles are supported; text
#'   elements are skipped with a warning, as upstream does (convert them to
#'   paths first). Styles are read as upstream's parser reads them: a shape
#'   with no stroke keeps the stroke color of its class with a width of 0, a
#'   `fill-opacity` or `stroke-opacity` replaces the alpha of its color, and
#'   the `opacity` property is not read.
#'
#'   The import follows upstream's steps, each a method:
#'   `get_file_path()` finds the file (also in the `assets_dir` setting, with
#'   `.svg` added); `modify_xml_tree(doc)` wraps the content in groups carrying
#'   the `svg_default` style and the root element's style;
#'   `get_mobjects_from(doc)` walks the elements and turns each shape (a list
#'   of its `node`, resolved `style` and `transform` matrix) into a mobject
#'   with `get_mob_from_shape_element(shape)`, which calls `path_to_mobject()`,
#'   `line_to_mobject()`, `rect_to_mobject()`, `ellipse_to_mobject()`,
#'   `polygon_to_mobject()`, `polyline_to_mobject()` or `text_to_mobject()`,
#'   then `apply_style_to_mobject()` and `handle_transform()`;
#'   `generate_mobject()` runs these, and `init_svg_mobject()` caches the
#'   result under `hash_seed()`. `move_into_position()` centers and sizes it.
#' @param file_name Path to an `.svg` file.
#' @param should_center Center the result at the origin.
#' @param height,width Target size; `height = 2` by default like Manim.
#' @param color,opacity,fill_color,fill_opacity,stroke_color,stroke_opacity,stroke_width
#'   Style overrides applied after import.
#' @param svg_default Default style for elements that do not set their own: a
#'   list with `color`, `opacity`, `fill_color`, `fill_opacity`,
#'   `stroke_width`, `stroke_color` and `stroke_opacity`.
#' @param path_string_config Arguments for [VMobjectFromSVGPath()].
#' @param use_svg_cache Reuse earlier imports of the same file.
#' @param ... Passed to [VMobject()].
#' @export
#' @examples
#' file <- tempfile(fileext = ".svg")
#' writeLines(c(
#'   '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">',
#'   '<circle cx="5" cy="5" r="4" fill="#58C4DD"/>',
#'   '<path d="M 2 5 L 8 5" stroke="#FFFFFF"/>',
#'   '</svg>'), file)
#' SVGMobject(file)
SVGMobjectClass <- R6::R6Class("SVGMobject", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    file_name = NULL,
    id_to_vgroup_dict = NULL,
    should_center = TRUE,
    svg_height = 2,
    svg_width = NULL,
    svg_default = NULL,
    path_string_config = NULL,
    initialize = function(file_name = NULL, should_center = TRUE, height = 2, width = NULL, color = NULL,
                          opacity = NULL, fill_color = NULL, fill_opacity = NULL, stroke_color = NULL,
                          stroke_opacity = NULL, stroke_width = NULL, svg_default = NULL, path_string_config = NULL,
                          use_svg_cache = TRUE, ...) {
      super$initialize(...)
      self$file_name <- file_name
      self$should_center <- should_center
      self$svg_height <- height
      self$svg_width <- width
      self$svg_default <- svg_default %||% list(color = NULL, opacity = NULL, fill_color = NULL, fill_opacity = NULL,
                                                stroke_width = 0, stroke_color = NULL, stroke_opacity = NULL)
      self$path_string_config <- path_string_config %||% list()
      # As upstream, color (black when not given) styles this mobject before
      # the shapes are imported: they keep their own style unless fill_color,
      # stroke_color and so on are given.
      self$set_color(color %||% BLACK)
      self$opacity <- opacity
      self$stroke_width <- stroke_width %||% 0
      if (!is.null(file_name)) self$init_svg_mobject(file_name, use_svg_cache = use_svg_cache)
      self$set_style(fill_color = fill_color, fill_opacity = fill_opacity, stroke_color = stroke_color,
                     stroke_opacity = stroke_opacity, stroke_width = stroke_width)
      self$move_into_position()
    },
    hash_seed = function() {
      list(class(self)[1], self$svg_default, self$path_string_config, self$file_name, cfg("renderer"))
    },
    # Imports the file, or copies an earlier import of it.
    init_svg_mobject = function(file_name = self$file_name, use_svg_cache = TRUE) {
      if (is.logical(file_name)) {
        use_svg_cache <- file_name
        file_name <- self$file_name
      }
      path <- self$get_file_path(file_name)
      key <- NULL
      if (use_svg_cache) {
        key <- digest::digest(list(self$hash_seed(), normalizePath(path), file.info(path)$mtime))
        if (is.null(.manim$svg_cache)) .manim$svg_cache <- new.env(parent = emptyenv())
        cached <- .manim$svg_cache[[key]]
        if (!is.null(cached)) {
          cp <- cached$copy()
          self$add(cp$submobjects)
          self$id_to_vgroup_dict <- cp$id_to_vgroup_dict
          return(invisible(self))
        }
      }
      self$generate_mobject(path)
      if (use_svg_cache) {
        snap <- VGroup(self$submobjects)
        snap$id_to_vgroup_dict <- self$id_to_vgroup_dict
        assign(key, snap$copy(), envir = .manim$svg_cache)
      }
      invisible(self)
    },
    generate_mobject = function(file_name = NULL) {
      path <- file_name %||% self$get_file_path()
      doc <- xml2::read_xml(path, options = "HUGE")
      xml2::xml_ns_strip(doc)
      doc <- self$modify_xml_tree(doc)
      res <- self$get_mobjects_from(doc)
      self$add(res$mobjects)
      self$id_to_vgroup_dict <- res$groups
      self$flip(RIGHT)
      invisible(self)
    },
    get_file_path = function(file_name = self$file_name) {
      if (is.null(file_name)) stop("Must specify file for SVGMobject", call. = FALSE)
      if (file.exists(file_name)) return(file_name)
      seek_full_path_from_defaults(file_name, cfg("assets_dir") %||% "./", ".svg")
    },
    # Wraps the content in a group with the svg_default style and a group
    # with the root element's style; the root's size and viewBox are dropped,
    # so coordinates are used as written.
    modify_xml_tree = function(element_tree) {
      root <- xml2::xml_root(element_tree)
      attrs <- xml2::xml_attrs(root)
      root_style <- attrs[names(attrs) %in% c("fill", "fill-opacity", "stroke", "stroke-opacity", "stroke-width", "style")]
      new <- xml2::xml_new_root("svg")
      g1 <- xml2::xml_add_child(new, "g")
      cfg_style <- self$generate_config_style_dict()
      if (length(cfg_style)) xml2::xml_set_attrs(g1, cfg_style)
      g2 <- xml2::xml_add_child(g1, "g")
      if (length(root_style)) xml2::xml_set_attrs(g2, root_style)
      for (ch in xml2::xml_children(root)) xml2::xml_add_child(g2, ch)
      new
    },
    generate_config_style_dict = function() {
      keys <- list(fill = c("color", "fill_color"), `fill-opacity` = c("opacity", "fill_opacity"),
                   stroke = c("color", "stroke_color"), `stroke-opacity` = c("opacity", "stroke_opacity"),
                   `stroke-width` = "stroke_width")
      out <- character()
      for (svg_key in names(keys)) {
        for (k in keys[[svg_key]]) {
          v <- self$svg_default[[k]]
          if (!is.null(v)) out[[svg_key]] <- as.character(v)
        }
      }
      out
    },
    # Walks the document: list(mobjects, groups), where groups maps element
    # ids (and "root") to VGroups of the shapes they contain.
    get_mobjects_from = function(svg) {
      doc <- svg
      root <- xml2::xml_root(doc)
      ids <- xml2::xml_find_all(doc, "//*[@id]")
      by_id <- list()
      for (n in ids) by_id[[xml2::xml_attr(n, "id")]] <- n
      css_rules <- parse_svg_css(doc)
      groups <- list(root = VGroup())
      mobs <- list()
      counter <- 0L
      skip <- c("defs", "clippath", "mask", "title", "desc", "metadata", "style", "symbol", "lineargradient",
                "radialgradient", "pattern", "marker", "filter", "script", "font", "font-face")
      walk <- function(node, M, style, stack, depth = 0L) {
        if (depth > 100) return(invisible(NULL))
        tag <- tolower(xml2::xml_name(node))
        if (tag %in% skip) return(invisible(NULL))
        id <- xml2::xml_attr(node, "id")
        if (is.na(id)) {
          id <- paste0("numbered_group_", counter)
          counter <<- counter + 1L
        }
        groups[[id]] <<- groups[[id]] %||% VGroup()
        Mn <- M %*% parse_svg_transform(xml2::xml_attr(node, "transform"))
        st <- svg_node_style(node, style)
        # Elements with display: none are not rendered, with their children;
        # display is not inherited.
        disp <- svg_apply_css(node, st, css_rules)$display
        if (identical(tolower(trimws(disp %||% "")), "none")) return(invisible(NULL))
        st$display <- NULL
        if (tag %in% c("g", "svg", "a", "switch")) {
          if (tag == "svg" && depth > 0) {
            Mn <- Mn %*% svg_matrix(1, 0, 0, 1, svg_length_px(xml2::xml_attr(node, "x") %|na|% "0"),
                                    svg_length_px(xml2::xml_attr(node, "y") %|na|% "0"))
          }
          for (ch in xml2::xml_children(node)) walk(ch, Mn, st, c(stack, id), depth + 1L)
        } else if (tag == "use") {
          attrs <- xml2::xml_attrs(node)
          href <- attrs[grepl("href$", names(attrs))]
          ref <- if (length(href)) sub("^#", "", href[[1]]) else NA
          target <- if (!is.na(ref)) by_id[[ref]] else NULL
          if (!is.null(target)) {
            tx <- svg_length_px(xml2::xml_attr(node, "x") %|na|% "0")
            ty <- svg_length_px(xml2::xml_attr(node, "y") %|na|% "0")
            Mu <- Mn %*% svg_matrix(1, 0, 0, 1, tx, ty)
            if (tolower(xml2::xml_name(target)) == "symbol") {
              for (ch in xml2::xml_children(target)) walk(ch, Mu, st, c(stack, id), depth + 1L)
            } else {
              walk(target, Mu, st, c(stack, id), depth + 1L)
            }
          }
        } else {
          shape <- list(node = node, style = svg_apply_css(node, st, css_rules), transform = Mn)
          # Hidden shapes (visibility is inherited) are not drawn.
          vis <- tolower(trimws(shape$style$visibility %||% "visible"))
          mob <- if (vis %in% c("hidden", "collapse")) NULL else self$get_mob_from_shape_element(shape)
          if (!is.null(mob)) {
            mobs[[length(mobs) + 1L]] <<- mob
            for (g in stack) groups[[g]]$add(mob)
          }
        }
        invisible(NULL)
      }
      for (ch in xml2::xml_children(root)) walk(ch, svg_identity(), svg_node_style(root, list()), "root")
      list(mobjects = mobs, groups = groups)
    },
    get_mob_from_shape_element = function(shape) {
      tag <- tolower(xml2::xml_name(shape$node))
      mob <- switch(tag,
        path = self$path_to_mobject(shape),
        line = self$line_to_mobject(shape),
        rect = self$rect_to_mobject(shape),
        circle = ,
        ellipse = self$ellipse_to_mobject(shape),
        polygon = self$polygon_to_mobject(shape),
        polyline = self$polyline_to_mobject(shape),
        text = self$text_to_mobject(shape),
        {
          logger$warning("Unsupported element type: %s", tag)
          NULL
        }
      )
      if (is.null(mob) || !mob$has_points()) return(NULL)
      self$apply_style_to_mobject(mob, shape)
      self$handle_transform(mob, shape$transform)
      mob
    },
    # The SVG transform matrix (3 x 3) applied to the points.
    handle_transform = function(mob, matrix) apply_svg_transform(mob, matrix),
    apply_style_to_mobject = function(mob, shape) apply_svg_style(mob, shape$style, shape$transform),
    path_to_mobject = function(path) {
      d <- xml2::xml_attr(path$node, "d")
      if (is.na(d)) return(NULL)
      do.call(VMobjectFromSVGPath, c(list(d), self$path_string_config))
    },
    line_to_mobject = function(line) svg_shape_to_mobject(line$node),
    rect_to_mobject = function(rect) svg_shape_to_mobject(rect$node),
    ellipse_to_mobject = function(ellipse) svg_shape_to_mobject(ellipse$node),
    polygon_to_mobject = function(polygon) svg_shape_to_mobject(polygon$node),
    polyline_to_mobject = function(polyline) svg_shape_to_mobject(polyline$node),
    text_to_mobject = function(text) {
      logger$warning("Unsupported element type: text")
      NULL
    },
    move_into_position = function() {
      if (isTRUE(self$should_center)) self$center()
      if (!is.null(self$svg_height)) self$height <- self$svg_height
      if (!is.null(self$svg_width)) self$width <- self$svg_width
      invisible(self)
    }
  )
)

#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @rdname SVGMobjectClass
#' @export
SVGMobject <- constructor(SVGMobjectClass)

#' @rdname SVGMobjectClass
#' @param path_string SVG path data, as in the `d` attribute of a `<path>`.
#' @param long_lines,should_subdivide_sharp_curves,should_remove_null_curves
#'   Upstream's options for the OpenGL renderer: under
#'   `manim_config(renderer = "opengl")` the path's quadratic curves are
#'   split where they turn more than 30 degrees, or curves of length 0
#'   dropped, when asked. `long_lines` is kept for compatibility.
#' @format NULL
#' @export
VMobjectFromSVGPathClass <- R6::R6Class("VMobjectFromSVGPath", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    path_string = NULL,
    long_lines = FALSE,
    should_subdivide_sharp_curves = FALSE,
    should_remove_null_curves = FALSE,
    initialize = function(path_string, long_lines = FALSE, should_subdivide_sharp_curves = FALSE,
                          should_remove_null_curves = FALSE, ...) {
      self$path_string <- path_string
      self$long_lines <- long_lines
      self$should_subdivide_sharp_curves <- should_subdivide_sharp_curves
      self$should_remove_null_curves <- should_remove_null_curves
      super$initialize(...)
    },
    generate_points = function() {
      self$handle_commands()
      # Under the OpenGL renderer upstream subdivides sharp curves and drops
      # null ones on its quadratic curves when asked.
      if (isTRUE(self$opengl_quadratic) && (self$should_subdivide_sharp_curves || self$should_remove_null_curves)) {
        q <- opengl_quadratic_points(self)
        tuples <- lapply(seq_len(nrow(q) %/% 3), function(i) q[3 * i - 2:0, , drop = FALSE])
        if (self$should_subdivide_sharp_curves) {
          tuples <- unlist(lapply(tuples, function(tup) {
            angle <- angle_between_vectors(tup[2, ] - tup[1, ], tup[3, ] - tup[2, ])
            if (angle <= 30 * DEGREES) return(list(tup))
            alphas <- seq(0, 1, length.out = ceiling(angle / (30 * DEGREES)) + 1)
            lapply(seq_len(length(alphas) - 1), function(i) partial_bezier_points(tup, alphas[i], alphas[i + 1]))
          }), recursive = FALSE)
        }
        if (self$should_remove_null_curves) {
          tuples <- Filter(function(tup) any(abs(tup[2:3, ] - tup[c(1, 1), ]) > 1e-9), tuples)
        }
        self$points <- opengl_cubic_from_quadratic(do.call(rbind, c(list(matrix(0, 0, 3)), tuples)))
      }
      invisible(self)
    },
    init_points = function() self$generate_points(),
    # Turns the path commands into cubic Bezier points: lines and quadratic
    # curves become cubics, and a closing command adds a line back to the
    # start unless the path already ends there.
    handle_commands = function() {
      self$points <- if (is.null(self$path_string)) matrix(0, 0, 3)
                     else svg_path_to_points(self$path_string, quadratic = isTRUE(self$opengl_quadratic),
                                             long_lines = isTRUE(self$long_lines))
      invisible(self)
    }
  )
)

#' @rdname SVGMobjectClass
#' @export
VMobjectFromSVGPath <- constructor(VMobjectFromSVGPathClass)
