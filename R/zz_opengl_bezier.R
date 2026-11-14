# The quadratic_bezier_fill and quadratic_bezier_stroke shaders of upstream's
# OpenGL renderer, run in software on the rasterizer of zz_opengl_software.R.
# The geometry shader stage runs for all curves at once: each function below
# works on rows, one per curve or per fragment.

# Shader data of a VMobject for both shaders, as upstream's
# get_fill_shader_data(), get_stroke_shader_data() and get_triangulation()
# give it. manimR's plain VMobjects (Circle(), Text(), ...) have no shader
# methods of their own (under the OpenGL renderer they get them attached);
# upstream's would be OpenGLVMobjects, so they get the same data with
# OpenGLVMobject's defaults.
software_vmobject_data <- function(m) {
  if (any(startsWith(class(m), "OpenGL"))) {
    fill <- m$get_fill_shader_data()
    stroke <- m$get_stroke_shader_data()
    return(list(
      fill = list(point = get("point", envir = fill), unit_normal = get("unit_normal", envir = fill),
                  color = get("color", envir = fill), vert_index = drop(get("vert_index", envir = fill))),
      stroke = list(point = get("point", envir = stroke), prev_point = get("prev_point", envir = stroke),
                    next_point = get("next_point", envir = stroke), unit_normal = get("unit_normal", envir = stroke),
                    stroke_width = drop(get("stroke_width", envir = stroke)), color = get("color", envir = stroke)),
      tri = software_triangulation(m, opengl_quadratic_points(m), m$get_unit_normal(), m$tolerance_for_point_equality),
      fill_uniforms = m$get_fill_uniforms(), stroke_uniforms = m$get_stroke_uniforms(),
      depth_test = isTRUE(m$depth_test), behind = isTRUE(m$draw_stroke_behind_fill)
    ))
  }
  points <- opengl_quadratic_points(m)
  n <- nrow(points)
  rows <- function(v, k) {
    v <- as.matrix(v)
    if (nrow(v) == 1) v[rep(1, n), , drop = FALSE] else resize_with_interpolation(v, n)
  }
  unit_normal <- software_quadratic_unit_normal(points)
  normal <- matrix(unit_normal, n, 3, byrow = TRUE)
  nppc <- 3
  shift <- function(k) if (n) points[((seq_len(n) - 1 + k) %% n) + 1, , drop = FALSE] else points
  uniforms <- list(is_fixed_in_frame = as.numeric(isTRUE(as.logical(m$is_fixed_in_frame))), is_fixed_orientation = 0,
                   fixed_orientation_center = c(0, 0, 0), gloss = 0, shadow = 0)
  width <- m$get_stroke_width()
  list(
    fill = list(point = points, unit_normal = normal, color = rows(m$get_fill_rgbas()), vert_index = seq_len(n) - 1),
    stroke = list(point = points, prev_point = shift(-nppc), next_point = shift(nppc), unit_normal = normal,
                  stroke_width = drop(rows(matrix(width, ncol = 1))), color = rows(m$get_stroke_rgbas())),
    tri = software_triangulation(m, points, unit_normal, 1e-8),
    fill_uniforms = uniforms,
    stroke_uniforms = c(uniforms, list(joint_type = unname(LINE_JOINT_TYPE_VALUES[tolower(m$joint_type %||% "auto")]),
                                       flat_stroke = 1)),
    depth_test = isTRUE(m$depth_test), behind = isTRUE(m$draw_stroke_behind_fill)
  )
}

# Triangulations by mobject, reused while its points and normal stay the
# same, as upstream keeps one until needs_new_triangulation is set.
software_triangulation_cache <- new.env(parent = emptyenv())
software_triangulation <- function(m, points, normal, atol) {
  hit <- software_triangulation_cache[[m$mob_id]]
  if (!is.null(hit) && identical(hit$points, points) && identical(hit$normal, normal)) return(hit$tri)
  # ponytail: cleared whole when large; an LRU if long scenes thrash it.
  if (length(software_triangulation_cache) > 10000) rm(list = ls(software_triangulation_cache), envir = software_triangulation_cache)
  tri <- opengl_triangulation(points, normal, atol)
  assign(m$mob_id, list(points = points, normal = normal, tri = tri), envir = software_triangulation_cache)
  tri
}

# OpenGLVMobject.get_unit_normal() on quadratic points: the area vector of
# the curves' anchors, or the normal of the first curve when it is zero.
software_quadratic_unit_normal <- function(points) {
  n <- nrow(points)
  if (n < 3) return(OUT)
  p0 <- points[seq(1, n, by = 3), , drop = FALSE]
  p1 <- points[seq(3, n, by = 3), , drop = FALSE]
  area_vect <- 0.5 * c(sum((p0[, 2] + p1[, 2]) * (p1[, 3] - p0[, 3])),
                       sum((p0[, 3] + p1[, 3]) * (p1[, 1] - p0[, 1])),
                       sum((p0[, 1] + p1[, 1]) * (p1[, 2] - p0[, 2])))
  area <- sqrt(sum(area_vect^2))
  if (area > 0) return(area_vect / area)
  get_unit_normal(points[2, ] - points[1, ], points[3, ] - points[2, ])
}

# Row helpers for 3 and 2 vectors.
bz_norm <- function(v) sqrt(rowSums(v * v))
bz_unit <- function(v) v / bz_norm(v)
bz_dot <- function(a, b) rowSums(a * b)
bz_cross <- function(a, b) {
  cbind(a[, 2] * b[, 3] - a[, 3] * b[, 2], a[, 3] * b[, 1] - a[, 1] * b[, 3], a[, 1] * b[, 2] - a[, 2] * b[, 1])
}
bz_cross2d <- function(v, w) v[, 1] * w[, 2] - w[, 1] * v[, 2]
bz_rotate <- function(v, u) if (isTRUE(as.logical(u$is_fixed_in_frame))) v else v %*% t(matrix(u$camera_rotation, 3, 3))

# get_reduced_control_points() for curves p0, p1, p2 (rows): the degree (0,
# 1 or 2) and the control points, a line's middle one at its midpoint.
bz_reduce <- function(p0, p1, p2) {
  v01 <- p1 - p0
  v12 <- p2 - p1
  # A zero vector makes the angle NaN, but then the curve is not
  # quadratic whatever `aligned` is.
  dp <- pmin(pmax(bz_dot(bz_unit(v01), bz_unit(v12)), -1), 1)
  aligned <- !is.na(dp) & acos(dp) < 5e-2
  n_uniques <- (bz_norm(v01) > 1e-6) + (bz_norm(v12) > 1e-6)
  degree <- ifelse(n_uniques == 2 & !aligned, 2, ifelse(n_uniques == 0, 0, 1))
  mid <- p1
  lin <- degree == 1
  mid[lin, ] <- (p0[lin, ] + p2[lin, ]) / 2
  zero <- degree == 0
  mid[zero, ] <- p0[zero, ]
  end <- p2
  end[zero, ] <- p0[zero, ]
  list(degree = degree, p0 = p0, p1 = mid, p2 = end)
}

# get_unit_normal.glsl.
bz_unit_normal <- function(p0, p1, p2) {
  v1 <- bz_unit(p1 - p0)
  v2 <- bz_unit(p2 - p0)
  cp <- bz_cross(v1, v2)
  len <- bz_norm(cp)
  out <- cp / len
  line <- is.na(len) | len < 1e-6
  if (any(line)) {
    k <- matrix(c(0, 0, 1), sum(line), 3, byrow = TRUE)
    w <- v2[line, , drop = FALSE]
    new_cp <- bz_cross(bz_cross(w, k), w)
    new_len <- bz_norm(new_cp)
    alt <- new_cp / new_len
    on_z <- is.na(new_len) | new_len < 1e-6
    if (any(on_z)) alt[on_z, ] <- matrix(c(0, -1, 0), sum(on_z), 3, byrow = TRUE)
    out[line, ] <- alt
  }
  out
}

# finalize_color() for vertex rows (lighting only with gloss or shadow).
bz_finalize <- function(color, point, normal, u) {
  cbind(software_add_light(color[, 1:3, drop = FALSE], point, normal, as.numeric(u$light_source_position),
                           u$gloss %||% 0, u$shadow %||% 0), color[, 4])
}

# quadratic_bezier_distance.glsl: the distance from p (rows, uv space where
# the curve runs from (0, 0) through (1, 0) to b2) to the curve, through
# modify(p, dist, t) at the clamped parameter.
bz_min_dist <- function(p, b2, degree, modify = function(p, dist, t, which) dist) {
  out <- numeric(nrow(p))
  lin <- degree == 1
  if (any(lin)) {
    q <- p[lin, , drop = FALSE]
    c2 <- b2[lin, , drop = FALSE]
    t <- pmin(pmax(q[, 1] / c2[, 1], 0), 1)
    d <- ifelse(t == 0, bz_norm(q), ifelse(t == 1, bz_norm(q - c2), abs(q[, 2])))
    out[lin] <- modify(q, d, t, lin)
  }
  quad <- !lin
  if (any(quad)) {
    q <- p[quad, , drop = FALSE]
    c2 <- b2[quad, , drop = FALSE]
    xm2 <- c2[, 1] - 2
    y <- c2[, 2]
    a <- xm2 * xm2 + y * y
    b <- 3 * xm2 / a
    c <- (-(q[, 1] * xm2 + q[, 2] * y) + 2) / a
    d <- -q[, 1] / a
    pp <- c - b * b / 3
    qq <- b * (2 * b * b - 9 * c) / 27 + d
    p3 <- pp * pp * pp
    disc <- qq * qq + 4 * p3 / 27
    offset <- -b / 3
    cube_root <- function(x) sign(x) * abs(x)^(1 / 3)
    # cubic_solve() leaves roots it does not find unset; they are 0 here.
    r0 <- r1 <- numeric(length(disc))
    nroots <- integer(length(disc))
    one <- !is.na(disc) & disc >= 0
    if (any(one)) {
      z <- sqrt(disc[one])
      r0[one] <- offset[one] + cube_root((-qq[one] + z) / 2) + cube_root((-qq[one] - z) / 2)
      nroots[one] <- 1L
    }
    three <- !one
    if (any(three)) {
      uu <- sqrt(-pp[three] / 3)
      vv <- suppressWarnings(acos(-sqrt(-27 / p3[three]) * qq[three] / 2)) / 3
      m <- cos(vv)
      nn <- sin(vv) * 1.732050808
      all <- cbind(offset[three] + uu * (nn - m), offset[three] - uu * (nn + m), offset[three] + uu * (m + m))
      bb <- b[three]
      cc <- c[three]
      valid <- (3 * all * all + 2 * bb * all + cc) > 0
      valid[is.na(valid)] <- FALSE
      first <- second <- numeric(nrow(all))
      count <- integer(nrow(all))
      for (j in 1:3) {
        take <- valid[, j]
        first[take & count == 0] <- all[take & count == 0, j]
        second[take & count == 1] <- all[take & count == 1, j]
        count <- count + take
      }
      r0[three] <- first
      r1[three] <- second
      nroots[three] <- count
    }
    at <- function(t) {
      t <- pmin(pmax(t, 0), 1)
      pt <- cbind(2 * t * (1 - t) + c2[, 1] * t * t, c2[, 2] * t * t)
      pt[t == 0, ] <- 0
      pt[t == 1, ] <- c2[t == 1, ]
      modify(q, bz_norm(q - pt), t, quad)
    }
    d0 <- at(r0)
    d1 <- at(r1)
    out[quad] <- ifelse(nroots == 1L, d0, pmin(d0, d1))
  }
  out
}

# smoothstep() with edge0 > edge1 as upstream calls it.
bz_smoothstep <- function(e0, e1, x) {
  t <- pmin(pmax((x - e0) / (e1 - e0), 0), 1)
  t * t * (3 - 2 * t)
}

# quadratic_bezier_fill's vertex and geometry stages: each triangle of the
# triangulation whose vertex indices are not consecutive is drawn whole; a
# curve's own triangle becomes a pentagon around the curve. Returns the
# vertices (positions `gl`, `color`, `uv`), the triangles and their values
# for the fragment stage (`prim`, one row per triangle), or NULL.
software_bezier_fill_geometry <- function(data, uniforms) {
  P <- data$fill$point
  tri <- matrix(as.integer(data$tri) + 1L, ncol = 3, byrow = TRUE)
  if (!nrow(P) || !nrow(tri)) return(NULL)
  u <- c(uniforms, data$fill_uniforms)
  bp <- software_frame_points(P, u)
  normal <- bz_rotate(data$fill$unit_normal, u)
  color <- data$fill$color
  vi <- data$fill$vert_index
  aaw <- u$anti_alias_width
  fill_all <- (vi[tri[, 2]] - vi[tri[, 1]]) != 1 | (vi[tri[, 3]] - vi[tri[, 2]]) != 1
  verts <- list()
  tris <- list()
  prims <- list()
  count <- 0
  emit <- function(xyz, j, uv, prim_rows, order, local) {
    k <- nrow(xyz)
    verts[[length(verts) + 1]] <<- list(xyz = xyz, color = bz_finalize(color[j, , drop = FALSE], xyz, normal[j, , drop = FALSE], u),
                                        uv = uv)
    t3 <- local + count
    tris[[length(tris) + 1]] <<- t3
    prims[[length(prims) + 1]] <<- c(prim_rows, list(order = order))
    count <<- count + k
  }
  simple <- which(fill_all)
  if (length(simple)) {
    ids <- as.vector(t(tri[simple, , drop = FALSE]))
    s <- length(simple)
    local <- matrix(seq_len(3 * s), ncol = 3, byrow = TRUE)
    emit(bp[ids, , drop = FALSE], ids, matrix(0, 3 * s, 2), list(fill_all = rep(1, s), orientation = rep(0, s),
         b2 = matrix(0, s, 2), uv_aaw = rep(1, s), degree = rep(2, s)), cbind(simple, 0), local)
  }
  curves <- which(!fill_all)
  if (length(curves)) {
    i0 <- tri[curves, 1]
    i1 <- tri[curves, 2]
    i2 <- tri[curves, 3]
    red <- bz_reduce(bp[i0, , drop = FALSE], bp[i1, , drop = FALSE], bp[i2, , drop = FALSE])
    keep <- red$degree >= 1
    if (any(keep)) {
      i0 <- i0[keep]; i1 <- i1[keep]; i2 <- i2[keep]
      p0 <- red$p0[keep, , drop = FALSE]
      p1 <- red$p1[keep, , drop = FALSE]
      p2 <- red$p2[keep, , drop = FALSE]
      degree <- red$degree[keep]
      local_normal <- bz_unit_normal(p0, p1, p2)
      orientation <- sign(bz_dot(normal[i0, , drop = FALSE], local_normal))
      t01 <- bz_unit(p1 - p0)
      t12 <- bz_unit(p2 - p1)
      p0_perp <- bz_cross(t01, local_normal)
      p2_perp <- bz_cross(t12, local_normal)
      inside <- orientation > 0
      pick <- function(a, b) {
        out <- b
        out[inside, ] <- a[inside, ]
        out
      }
      corners <- list(
        pick(p0 + aaw * p0_perp, p0),
        pick(p0, p0 - aaw * p0_perp),
        pick(p1 + 0.5 * aaw * (p0_perp + p2_perp), p1),
        pick(p2, p2 - aaw * p2_perp),
        pick(p2 + aaw * p2_perp, p2)
      )
      # get_xyz_to_uv(): b0 to (0, 0) and b1 to (1, 0), K the normal.
      sf <- bz_norm(p1 - p0)
      I <- (p1 - p0) / sf
      J <- bz_cross(local_normal, I)
      to_uv <- function(x) cbind(bz_dot(I, x - p0), bz_dot(J, x - p0)) / sf
      k <- length(i0)
      jmap <- list(i0, i0, i1, i2, i2)
      xyz <- do.call(rbind, corners)
      j <- unlist(jmap)
      uv <- do.call(rbind, lapply(corners, to_uv))
      # Corner c of curve q is row q + (c - 1) * k; the strip gives
      # triangles 0 1 2, 1 2 3 and 2 3 4.
      q <- seq_len(k)
      local <- rbind(cbind(q, q + k, q + 2 * k), cbind(q + k, q + 2 * k, q + 3 * k), cbind(q + 2 * k, q + 3 * k, q + 4 * k))
      rep3 <- function(v) if (is.matrix(v)) rbind(v, v, v) else rep(v, 3)
      emit(xyz, j, uv, list(fill_all = rep3(rep(0, k)), orientation = rep3(orientation), b2 = rep3(to_uv(p2)),
                            uv_aaw = rep3(aaw / sf), degree = rep3(degree)),
           cbind(rep(curves[keep], 3), rep(1:3, each = k)), local)
    }
  }
  if (!length(verts)) return(NULL)
  xyz <- do.call(rbind, lapply(verts, `[[`, "xyz"))
  bind <- function(name) {
    parts <- lapply(prims, `[[`, name)
    if (is.matrix(parts[[1]])) do.call(rbind, parts) else unlist(parts)
  }
  order_key <- bind("order")
  o <- order(order_key[, 1], order_key[, 2])
  prim <- lapply(c(fill_all = "fill_all", orientation = "orientation", b2 = "b2", uv_aaw = "uv_aaw",
                   degree = "degree"), function(nm) {
    v <- bind(nm)
    if (is.matrix(v)) v[o, , drop = FALSE] else v[o]
  })
  list(gl = software_gl_position(xyz, u), tri = do.call(rbind, tris)[o, , drop = FALSE],
       vert = list(color = do.call(rbind, lapply(verts, `[[`, "color")), uv = do.call(rbind, lapply(verts, `[[`, "uv"))),
       prim = prim)
}

# quadratic_bezier_fill's fragment stage: a fragment of a curve's pentagon
# fades over anti_alias_width outside the curve; vertices with alpha 0 are
# discarded.
software_bezier_fill_shaders <- function(g) {
  prim <- g$prim
  list(discard = function(at, tri_id) at(g$vert$color[, 4, drop = FALSE])[, 1] == 0,
       shade = function(at, tri_id) {
    rgba <- at(g$vert$color)
    curve <- prim$fill_all[tri_id] != 1
    if (any(curve)) {
      p <- at(g$vert$uv)[curve, , drop = FALSE]
      b2 <- prim$b2[tri_id[curve], , drop = FALSE]
      degree <- prim$degree[tri_id[curve]]
      w <- prim$uv_aaw[tri_id[curve]]
      sgn <- prim$orientation[tri_id[curve]] * sign(b2[, 2])
      ratio <- abs(b2[, 2] / b2[, 1])
      sdf <- abs(p[, 2])
      exact <- degree >= 2 & !(ratio < 0.1 * w)
      if (any(exact)) {
        # to_simple_space = mat2(v2, 0, 2 - u2, 4 v2), columns first.
        x <- b2[exact, 2] * p[exact, 1] + (2 - b2[exact, 1]) * p[exact, 2]
        y <- 4 * b2[exact, 2] * p[exact, 2]
        flat <- ratio[exact] < 0.5 * w[exact]
        inside <- !flat & sgn[exact] * (x * x - y) < 0
        dist <- bz_min_dist(p[exact, , drop = FALSE], b2[exact, , drop = FALSE], degree[exact])
        sdf[exact] <- ifelse(inside, 0, dist)
      }
      rgba[curve, 4] <- rgba[curve, 4] * bz_smoothstep(1, 0, sdf / w)
    }
    rgba
  })
}

# quadratic_bezier_stroke's vertex and geometry stages: each curve becomes a
# quadrilateral (a line) or a pentagon around it, widened by half the stroke
# width plus anti_alias_width and joined to its neighbors. Returns the
# vertices, triangles and per triangle values as
# software_bezier_fill_geometry() does, or NULL.
software_bezier_stroke_geometry <- function(data, uniforms) {
  s <- data$stroke
  n <- nrow(s$point)
  if (n < 3) return(NULL)
  u <- c(uniforms, data$stroke_uniforms)
  aaw <- u$anti_alias_width
  fd <- u$focal_distance
  joint <- u$joint_type %||% 0
  # The points reach the GPU as float32 and the vertex shader moves them
  # into the frame in single precision, which merges points only 1e-16
  # apart (a sphere's pole); in double their tiny differences would give
  # the joints arbitrary angles.
  f32 <- function(m) as_float32(software_frame_points(as_float32(m), u))
  bp <- f32(s$point)
  prev_bp <- f32(s$prev_point)
  next_bp <- f32(s$next_point)
  normal <- bz_rotate(s$unit_normal, u)
  width <- 0.01 * s$stroke_width
  color <- s$color
  k <- n %/% 3
  i0 <- 3 * seq_len(k) - 2
  rows3 <- function(m, j) m[i0 + j, , drop = FALSE]
  ctl <- bz_reduce(rows3(bp, 0), rows3(bp, 1), rows3(bp, 2))
  keep <- which(ctl$degree > 0)
  if (!length(keep)) return(NULL)
  sub <- function(m) m[keep, , drop = FALSE]
  i0 <- i0[keep]
  degree <- ctl$degree[keep]
  C <- list(sub(ctl$p0), sub(ctl$p1), sub(ctl$p2))
  prv <- bz_reduce(rows3(prev_bp, 0), rows3(prev_bp, 1), rows3(prev_bp, 2))
  nxt <- bz_reduce(rows3(next_bp, 0), rows3(next_bp, 1), rows3(next_bp, 2))
  psf <- function(z) pmax(0, fd / (fd - z))
  scaled <- lapply(0:2, function(j) {
    sf <- psf(C[[j + 1]][, 3])
    if (isTRUE(as.logical(u$flat_stroke))) {
      to_cam <- bz_unit(sweep(-C[[j + 1]], 2, c(0, 0, fd), "+"))
      sf <- sf * abs(bz_dot(normal[i0 + j, , drop = FALSE], to_cam))
    }
    width[i0 + j] * sf
  })
  flat <- function(p) p[, 1:2, drop = FALSE] * psf(p[, 3])
  fc <- lapply(C, flat)
  fp <- list(flat(prv$p0), flat(prv$p1), flat(prv$p2))
  fn <- list(flat(nxt$p0), flat(nxt$p1), flat(nxt$p2))
  angle_between <- function(v1, v2) {
    n1 <- bz_norm(v1)
    n2 <- bz_norm(v2)
    dp <- pmin(pmax(bz_dot(v1, v2) / (n1 * n2), -1), 1)
    out <- acos(dp) * sign(bz_cross2d(v1, v2))
    out[n1 == 0 | n2 == 0] <- 0
    out
  }
  has_prev <- as.numeric(bz_norm(fp[[3]] - fc[[1]]) < 1e-6)
  has_next <- as.numeric(bz_norm(fn[[1]] - fc[[3]]) < 1e-6)
  should_bevel <- function(adj) {
    linear_adj <- angle_between(adj[[2]] - adj[[1]], adj[[3]] - adj[[2]]) < 1e-3
    as.numeric((joint == 0 & (degree == 1 | linear_adj)) | joint == 2)
  }
  angle_from_prev <- ifelse(has_prev == 1, angle_between(fc[[1]] - fp[[2]], fc[[2]] - fc[[1]]), 0)
  bevel_start <- ifelse(has_prev == 1, should_bevel(fp), 0)
  angle_to_next <- ifelse(has_next == 1, -angle_between(fc[[3]] - fn[[2]], fc[[2]] - fc[[3]]), 0)
  bevel_end <- ifelse(has_next == 1, should_bevel(fn), 0)
  # get_corners().
  p0 <- fc[[1]]
  p1 <- fc[[2]]
  p2 <- fc[[3]]
  v10 <- bz_unit(p0 - p1)
  v12 <- bz_unit(p2 - p1)
  v01 <- -v10
  v21 <- -v12
  p0_perp <- cbind(-v01[, 2], v01[, 1])
  p2_perp <- cbind(-v12[, 2], v12[, 1])
  buff0 <- 0.5 * scaled[[1]] + aaw
  buff2 <- 0.5 * scaled[[3]] + aaw
  aaw0 <- (1 - has_prev) * aaw
  aaw2 <- (1 - has_next) * aaw
  c0 <- p0 - buff0 * p0_perp + aaw0 * v10
  c1 <- p0 + buff0 * p0_perp + aaw0 * v10
  c2 <- p2 + buff2 * p2_perp + aaw2 * v12
  c3 <- p2 - buff2 * p2_perp + aaw2 * v12
  joint_shift <- function(angle, buff) {
    shift <- if (joint == 3) buff * (-1 - cos(angle)) / sin(angle) else buff * (1 - cos(angle)) / sin(angle)
    shift[abs(angle) < 1e-3] <- 0
    shift
  }
  sp <- ifelse(has_prev > 0, joint_shift(angle_from_prev, buff0), 0)
  c0 <- c0 - sp * v01
  c1 <- c1 + sp * v01
  sn <- ifelse(has_next > 0, joint_shift(angle_to_next, buff2), 0)
  c3 <- c3 - sn * v21
  c2 <- c2 + sn * v21
  m <- length(degree)
  lin <- degree == 1
  orient <- sign(bz_cross2d(v01, v12))
  ccw <- orient > 0
  pick <- function(a, b) {
    out <- b
    out[ccw, ] <- a[ccw, ]
    out
  }
  k0 <- pick(c0, c1)
  k4 <- pick(c3, c2)
  # find_intersection(corners[0], v01, corners[4], v21): unchanged when
  # the lines are parallel.
  det <- -v01[, 1] * v21[, 2] + v21[, 1] * v01[, 2]
  t <- bz_cross2d(k0 - k4, v21) / det
  k2 <- p1
  ok <- !is.na(det) & det != 0
  k2[ok, ] <- k0[ok, ] + v01[ok, ] * t[ok]
  corners <- list(k0, pick(c1, c0), k2, pick(c2, c3), k4)
  # A line takes c0, c1, c3, c2 (its fifth corner unused).
  corners[[1]][lin, ] <- c0[lin, ]
  corners[[2]][lin, ] <- c1[lin, ]
  corners[[3]][lin, ] <- c3[lin, ]
  corners[[4]][lin, ] <- c2[lin, ]
  index_map <- list(rep(0, m), rep(0, m), ifelse(lin, 2, 1), rep(2, m), rep(2, m))
  # get_xy_to_uv().
  sf <- bz_norm(p1 - p0)
  I <- (p1 - p0) / sf
  J <- cbind(-I[, 2], I[, 1])
  to_uv <- function(x) cbind(bz_dot(I, x - p0), bz_dot(J, x - p0)) / sf
  uv_b2 <- to_uv(p2)
  pick_j <- function(lst, j) {
    out <- lst[[1]]
    for (jj in 1:2) out[j == jj] <- lst[[jj + 1]][j == jj]
    out
  }
  pick_jm <- function(lst, j) {
    out <- lst[[1]]
    for (jj in 1:2) out[j == jj, ] <- lst[[jj + 1]][j == jj, , drop = FALSE]
    out
  }
  verts <- lapply(1:5, function(c) {
    j <- index_map[[c]]
    z <- pick_j(list(C[[1]][, 3], C[[2]][, 3], C[[3]][, 3]), j)
    ctrl <- pick_jm(C, j)
    vrow <- i0 + j
    xyz <- cbind(corners[[c]], z)
    list(uv = to_uv(corners[[c]]), w = pick_j(scaled, j) / sf,
         color = bz_finalize(color[vrow, , drop = FALSE], xyz, normal[vrow, , drop = FALSE], u),
         gl = cbind(software_gl_position(cbind(corners[[c]], 0), u)[, 1:2, drop = FALSE],
                    software_gl_position(ctrl, u)[, 3]))
  })
  stack <- function(name) do.call(rbind, lapply(verts, function(v) as.matrix(v[[name]])))
  gl <- stack("gl")
  vuv <- stack("uv")
  vw <- stack("w")
  vcolor <- stack("color")
  q <- seq_len(m)
  # Corner c of curve q is row q + (c - 1) m; the strip's triangles, the
  # third only for a pentagon, ordered by curve.
  t3 <- rbind(cbind(q, q + m, q + 2 * m), cbind(q + m, q + 2 * m, q + 3 * m))
  tc <- c(q, q)
  sub3 <- c(rep(1, m), rep(2, m))
  quad <- which(!lin)
  if (length(quad)) {
    t3 <- rbind(t3, cbind(quad + 2 * m, quad + 3 * m, quad + 4 * m))
    tc <- c(tc, quad)
    sub3 <- c(sub3, rep(3, length(quad)))
  }
  o <- order(tc, sub3)
  t3 <- t3[o, , drop = FALSE]
  curve_of <- tc[o]
  prim <- list(has_prev = has_prev, has_next = has_next, bevel_start = bevel_start, bevel_end = bevel_end,
               angle_from_prev = angle_from_prev, angle_to_next = angle_to_next, degree = degree, b2 = uv_b2,
               uv_aaw = aaw / sf)
  prim <- lapply(prim, function(v) if (is.matrix(v)) v[curve_of, , drop = FALSE] else v[curve_of])
  list(gl = gl, tri = t3, vert = list(uv = vuv, w = vw, color = vcolor), prim = prim)
}

# quadratic_bezier_stroke's fragment stage: a fragment's alpha fades with
# its distance to the curve, the curve's ends cut, beveled or rounded.
software_bezier_stroke_shaders <- function(g) {
  prim <- g$prim
  list(discard = function(at, tri_id) at(g$vert$w)[, 1] == 0,
       shade = function(at, tri_id) {
    p <- at(g$vert$uv)
    w <- at(g$vert$w)[, 1]
    b2 <- prim$b2[tri_id, , drop = FALSE]
    deg <- prim$degree[tri_id]
    uaaw <- prim$uv_aaw[tri_id]
    # modify_distance_for_endpoints(), for the fragments in `which`.
    modify <- function(q, dist, t, which) {
      idx <- tri_id[which]
      buff <- 0.5 * w[which] - uaaw[which]
      out <- dist
      hp <- prim$has_prev[idx]
      start <- t == 0
      cut <- start & hp == 0
      out[cut] <- pmax(dist[cut], -q[cut, 1] + buff[cut])
      bev <- start & hp != 0 & prim$bevel_start[idx] == 1
      if (any(bev)) {
        a <- prim$angle_from_prev[idx][bev]
        x <- q[bev, 1]
        y <- q[bev, 2]
        # rot = mat2(cos a, sin a, -sin a, cos a): (rot p).y = sin(a) x + cos(a) y.
        bevel_d <- pmax(abs(y), abs(sin(a) * x + cos(a) * y))
        out[bev] <- pmax(pmin(dist[bev], bevel_d), dist[bev] / 2)
      }
      end <- t == 1
      if (any(end)) {
        c2 <- b2[which, , drop = FALSE][end, , drop = FALSE]
        dg <- deg[which][end]
        v21 <- cbind(ifelse(dg == 2, 1 - c2[, 1], -1), ifelse(dg == 2, -c2[, 2], 0))
        len <- bz_norm(v21)
        zero <- len == 0
        v21[zero, ] <- -c2[zero, ]
        len[zero] <- bz_norm(v21[zero, , drop = FALSE])
        qe <- q[end, , drop = FALSE]
        perp <- bz_dot(qe - c2, v21) / len
        hn <- prim$has_next[idx][end]
        de <- dist[end]
        res <- de
        cut <- hn == 0
        res[cut] <- pmax(de[cut], -perp[cut] + buff[end][cut])
        bev <- hn != 0 & prim$bevel_end[idx][end] == 1
        if (any(bev)) {
          a <- -prim$angle_to_next[idx][end][bev]
          d <- (qe - c2)[bev, , drop = FALSE]
          vu <- (v21 / bz_norm(v21))[bev, , drop = FALSE]
          rd <- cbind(cos(a) * d[, 1] - sin(a) * d[, 2], sin(a) * d[, 1] + cos(a) * d[, 2])
          bevel_d <- pmax(abs(bz_cross2d(d, vu)), abs(bz_cross2d(rd, vu)))
          res[bev] <- pmax(pmin(de[bev], bevel_d), de[bev] / 2)
        }
        out[end] <- res
      }
      out
    }
    dist <- bz_min_dist(p, b2, deg, modify)
    signed <- abs(dist) - 0.5 * w
    rgba <- at(g$vert$color)
    rgba[, 4] <- rgba[, 4] * bz_smoothstep(0.5, -0.5, signed / uaaw)
    rgba
  })
}

# Joins the geometries of several mobjects into one, as upstream's
# ShaderWrapper.combine_with() joins their vertex data.
software_combine_geometry <- function(gs) {
  gs <- Filter(Negate(is.null), gs)
  if (!length(gs)) return(NULL)
  offset <- cumsum(c(0, vapply(gs, function(g) nrow(g$gl), numeric(1))))
  join <- function(parts) if (is.matrix(parts[[1]])) do.call(rbind, parts) else unlist(parts)
  list(gl = do.call(rbind, lapply(gs, `[[`, "gl")),
       tri = do.call(rbind, Map(function(g, o) g$tri + o, gs, offset[seq_along(gs)])),
       vert = lapply(stats::setNames(nm = names(gs[[1]]$vert)), function(k) join(lapply(gs, function(g) g$vert[[k]]))),
       prim = lapply(stats::setNames(nm = names(gs[[1]]$prim)), function(k) join(lapply(gs, function(g) g$prim[[k]]))))
}

# A VMobject as upstream's OpenGLVMobject.get_shader_wrapper_list() draws
# it: the strokes drawn behind the fill of its family members with points,
# then their fills, then their other strokes, each pass one draw of the
# members' joined data with the first member's depth test. The projection
# shaders, when configured, replace them. Upstream's OpenGLVMobjects hold
# only OpenGLVMobjects; manimR's may hold other mobjects, and its surfaces
# are VMobjects holding their faces. Those submobjects are left out and
# returned for the caller to draw.
software_draw_vmobject <- function(fbo, mobject, uniforms) {
  others <- list()
  vfamily <- list()
  collect <- function(m) {
    vfamily[[length(vfamily) + 1]] <<- m
    for (sm in m$submobjects) {
      if (!is_vmobject(sm) || opengl_is_software_surface(sm)) others[[length(others) + 1]] <<- sm else collect(sm)
    }
  }
  collect(mobject)
  members <- Filter(function(m) NROW(m$points) > 0, vfamily)
  data <- lapply(members, software_vmobject_data)
  has_fill <- vapply(data, function(d) any(d$fill$color[, 4] != 0), logical(1)) &
    !isTRUE(cfg("use_projection_fill_shaders"))
  has_stroke <- vapply(data, function(d) any(d$stroke$stroke_width != 0) && any(d$stroke$color[, 4] != 0), logical(1)) &
    !isTRUE(cfg("use_projection_stroke_shaders"))
  behind <- vapply(data, `[[`, logical(1), "behind")
  pass <- function(which, geometry, shaders) {
    if (!any(which)) return(invisible(NULL))
    g <- software_combine_geometry(lapply(data[which], geometry, uniforms))
    if (is.null(g)) return(invisible(NULL))
    sh <- shaders(g)
    software_rasterize(fbo, g$gl, g$tri, data[which][[1]]$depth_test, sh$shade, sh$discard)
  }
  pass(has_stroke & behind, software_bezier_stroke_geometry, software_bezier_stroke_shaders)
  pass(has_fill, software_bezier_fill_geometry, software_bezier_fill_shaders)
  pass(has_stroke & !behind, software_bezier_stroke_geometry, software_bezier_stroke_shaders)
  others
}
