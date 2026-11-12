# Mobjects representing graphs in the graph theory sense (vertices joined by
# edges). Ported from manim/mobject/graph.py. Upstream relies on networkx; here
# the graph structure is kept in plain R lists and the layouts are ports of
# the networkx ones (SageMath's for "tree"), so no graph package is needed.

# Key of the edge (u, v) in the edges list: "u-v" with every "-" and "\" in
# the vertex names escaped by a backslash, so keys never collide (the edge
# c("a-b", "c") is a\-b-c and c("a", "b-c") is a-b\-c).
graph_edge_key <- function(u, v) {
  esc <- function(x) gsub("([-\\\\])", "\\\\\\1", x)
  paste(esc(u), esc(v), sep = "-")
}

# Split an edge config into global settings and per edge entries keyed by
# graph_edge_key(). A name matches an edge by its key or, when that names a
# single edge, by its plain "u-v" label; undirected edges also match "v-u".
# Other names containing "-" match no edge and are dropped, as upstream
# ignores tuple keys of missing edges.
graph_split_edge_config <- function(config, pairs, directed) {
  nm <- names(config) %||% rep("", length(config))
  is_edge <- grepl("-", nm, fixed = TRUE)
  per_edge <- list()
  if (any(is_edge) && length(pairs)) {
    u <- vapply(pairs, `[`, "", 1)
    v <- vapply(pairs, `[`, "", 2)
    keys <- graph_edge_key(u, v)
    label <- function(a, b) paste(a, b, sep = "-")
    # Keys of the edges called `name` by f, trying the reversed edges after.
    find <- function(name, f) {
      hit <- unique(keys[f(u, v) == name])
      if (!length(hit) && !directed) hit <- unique(keys[f(v, u) == name])
      hit
    }
    for (name in nm[is_edge]) {
      hit <- find(name, graph_edge_key)
      if (!length(hit)) hit <- find(name, label)
      if (length(hit) > 1) {
        stop("The edge config name '", name, "' matches several edges; escape each '-' and '\\' ",
             "inside a vertex name with a backslash.", call. = FALSE)
      }
      if (length(hit) == 1) per_edge[[hit]] <- config[[name]]
    }
  }
  list(default = config[!is_edge], per_edge = per_edge)
}

# Call a vertex or edge type, which may be a constructor function or an R6 generator.
graph_construct <- function(type, args) {
  ctor <- if (inherits(type, "R6ClassGenerator")) type$new else type
  do.call(ctor, args)
}

graph_is_dot_type <- function(type) identical(type, Dot) || identical(type, DotClass)

# Normalize edges given as a list of pairs or a two column matrix into a list
# of character pairs.
graph_as_edge_list <- function(edges) {
  if (is.null(edges) || length(edges) == 0) return(list())
  if (is.matrix(edges) || is.data.frame(edges)) {
    edges <- as.matrix(edges)
    return(lapply(seq_len(nrow(edges)), function(i) as.character(edges[i, 1:2])))
  }
  lapply(edges, function(e) {
    e <- as.character(unlist(e))
    if (length(e) != 2) stop("Each edge must be a pair of vertices.", call. = FALSE)
    e
  })
}

graph_split_dots <- function(args) {
  nm <- names(args) %||% rep("", length(args))
  list(unnamed = args[nm == ""], named = args[nm != ""])
}

# networkx.rescale_layout: center, then scale so the largest coordinate is `scale`.
graph_rescale_layout <- function(pos, scale = 1) {
  pos <- sweep(pos, 2, colMeans(pos))
  lim <- max(abs(pos))
  if (lim > 0) pos <- sweep(pos, 2, rep_len(scale, ncol(pos)) / lim, `*`)
  pos
}

# Turn an n x 2 or n x 3 matrix of positions into a named list of 3D points.
graph_pos_list <- function(pos, ids) {
  if (ncol(pos) == 2) pos <- cbind(pos, 0)
  stats::setNames(lapply(seq_along(ids), function(i) as.numeric(pos[i, 1:3])), ids)
}

# Adjacency matrix (symmetrized for directed graphs), rows in vertex order.
graph_adjacency <- function(ids, pairs, symmetric = TRUE) {
  n <- length(ids)
  A <- matrix(0, n, n, dimnames = list(ids, ids))
  for (e in pairs) {
    A[e[1], e[2]] <- 1
    if (symmetric) A[e[2], e[1]] <- 1
  }
  A
}

graph_layout_circular <- function(graph, scale = 2, ...) {
  ids <- graph$vertex_ids()
  n <- length(ids)
  if (n == 0) return(list())
  if (n == 1) return(graph_pos_list(matrix(0, 1, 2), ids))
  theta <- (seq_len(n) - 1) / n * 2 * pi
  graph_pos_list(graph_rescale_layout(cbind(cos(theta), sin(theta)), scale), ids)
}

graph_layout_random <- function(graph, scale = 2, seed = NULL, ...) {
  ids <- graph$vertex_ids()
  pos <- if (is.null(seed)) matrix(stats::runif(2 * length(ids)), ncol = 2)
    else vf_with_seed(seed, matrix(stats::runif(2 * length(ids)), ncol = 2))
  graph_pos_list(2 * scale * (pos - 0.5), ids)
}

graph_layout_shell <- function(graph, scale = 2, nlist = NULL, rotate = NULL, ...) {
  ids <- graph$vertex_ids()
  n <- length(ids)
  if (n == 0) return(list())
  if (n == 1) return(graph_pos_list(matrix(0, 1, 2), ids))
  nlist <- if (is.null(nlist)) list(ids) else lapply(nlist, function(s) as.character(unlist(s)))
  radius_bump <- scale / length(nlist)
  radius <- if (length(nlist[[1]]) == 1) 0 else radius_bump
  if (is.null(rotate)) rotate <- pi / length(nlist)
  first_theta <- rotate
  out <- list()
  for (nodes in nlist) {
    theta <- (seq_along(nodes) - 1) / length(nodes) * 2 * pi + first_theta
    for (k in seq_along(nodes)) out[[nodes[k]]] <- c(radius * cos(theta[k]), radius * sin(theta[k]), 0)
    radius <- radius + radius_bump
    first_theta <- first_theta + rotate
  }
  out
}

graph_layout_spiral <- function(graph, scale = 2, resolution = 0.35, equidistant = FALSE, ...) {
  ids <- graph$vertex_ids()
  n <- length(ids)
  if (n == 0) return(list())
  if (n == 1) return(graph_pos_list(matrix(0, 1, 2), ids))
  if (equidistant) {
    chord <- 1
    step <- 0.5
    theta <- resolution
    theta <- theta + chord / (step * theta)
    pos <- matrix(0, n, 2)
    for (i in seq_len(n)) {
      r <- step * theta
      theta <- theta + chord / r
      pos[i, ] <- c(cos(theta) * r, sin(theta) * r)
    }
  } else {
    dist <- seq_len(n) - 1
    angle <- resolution * dist
    pos <- cbind(dist * cos(angle), dist * sin(angle))
  }
  graph_pos_list(graph_rescale_layout(pos, scale), ids)
}

graph_layout_spectral <- function(graph, scale = 2, ...) {
  ids <- graph$vertex_ids()
  n <- length(ids)
  if (n == 0) return(list())
  if (n == 1) return(graph_pos_list(matrix(0, 1, 2), ids))
  if (n == 2) return(graph_pos_list(matrix(0, 2, 2), ids))
  A <- graph_adjacency(ids, graph$edge_pairs, symmetric = !graph$directed)
  if (graph$directed) A <- A + t(A)
  L <- diag(rowSums(A)) - A
  e <- eigen(L, symmetric = TRUE)
  idx <- order(e$values)[2:3]
  graph_pos_list(graph_rescale_layout(e$vectors[, idx, drop = FALSE], scale), ids)
}

# Fruchterman and Reingold force directed layout, as networkx.spring_layout
# (its dense solver). `pos` optionally gives starting positions (a named
# list); other vertices start at random positions, as upstream.
graph_layout_spring <- function(graph, scale = 2, k = NULL, pos = NULL, iterations = 50, threshold = 1e-4,
                                seed = NULL, ...) {
  ids <- graph$vertex_ids()
  n <- length(ids)
  if (n == 0) return(list())
  if (n == 1) return(graph_pos_list(matrix(0, 1, 2), ids))
  A <- graph_adjacency(ids, graph$edge_pairs, symmetric = !graph$directed)
  start <- pos
  dom_size <- if (is.null(start)) 1 else max(unlist(start))
  if (dom_size == 0) dom_size <- 1
  pos <- if (is.null(seed)) matrix(stats::runif(2 * n), ncol = 2)
    else vf_with_seed(seed, matrix(stats::runif(2 * n), ncol = 2))
  if (!is.null(start)) {
    pos <- pos * dom_size
    for (i in seq_len(n)) if (!is.null(start[[ids[i]]])) pos[i, ] <- as.numeric(start[[ids[i]]])[1:2]
  }
  if (is.null(k)) k <- sqrt(1 / n)
  t <- max(diff(range(pos[, 1])), diff(range(pos[, 2]))) * 0.1
  dt <- t / (iterations + 1)
  for (it in seq_len(iterations)) {
    dx <- outer(pos[, 1], pos[, 1], `-`)
    dy <- outer(pos[, 2], pos[, 2], `-`)
    distance <- pmax(sqrt(dx^2 + dy^2), 0.01)
    w <- k * k / distance^2 - A * distance / k
    disp <- cbind(rowSums(dx * w), rowSums(dy * w))
    len <- pmax(sqrt(rowSums(disp^2)), 0.01)
    delta_pos <- disp * (t / len)
    pos <- pos + delta_pos
    t <- t - dt
    if (sqrt(sum(delta_pos^2)) / n < threshold) break
  }
  graph_pos_list(graph_rescale_layout(pos, scale), ids)
}

# All pairs shortest path lengths in edges (directed for DiGraph); Inf when
# unreachable.
graph_shortest_paths <- function(graph) {
  ids <- graph$vertex_ids()
  n <- length(ids)
  D <- matrix(Inf, n, n, dimnames = list(ids, ids))
  diag(D) <- 0
  for (e in graph$edge_pairs) {
    D[e[1], e[2]] <- min(D[e[1], e[2]], 1)
    if (!graph$directed) D[e[2], e[1]] <- min(D[e[2], e[1]], 1)
  }
  for (k in seq_len(n)) D <- pmin(D, outer(D[, k], D[k, ], `+`))
  D
}

# Kamada and Kawai layout, as networkx.kamada_kawai_layout: minimizes the
# stress against `dist` (named list of named lists of desired distances;
# shortest path lengths by default, 1e6 for missing pairs) with L-BFGS-B,
# starting from the circular layout or `pos`.
graph_layout_kamada_kawai <- function(graph, scale = 2, dist = NULL, pos = NULL, ...) {
  ids <- graph$vertex_ids()
  n <- length(ids)
  if (n == 0) return(list())
  D <- matrix(1e6, n, n, dimnames = list(ids, ids))
  if (is.null(dist)) {
    sp <- graph_shortest_paths(graph)
    D[is.finite(sp)] <- sp[is.finite(sp)]
  } else {
    for (r in intersect(names(dist), ids)) {
      for (cc in intersect(names(dist[[r]]), ids)) D[r, cc] <- as.numeric(dist[[r]][[cc]])
    }
  }
  start <- if (is.null(pos)) graph_layout_circular(graph, scale = 1) else pos
  start <- t(vapply(ids, function(v) as.numeric(start[[v]])[1:2], numeric(2)))
  invdist <- 1 / (D + diag(n) * 1e-3)
  meanwt <- 1e-3
  parts <- function(v) {
    p <- matrix(v, ncol = 2, byrow = TRUE)
    dx <- outer(p[, 1], p[, 1], `-`)
    dy <- outer(p[, 2], p[, 2], `-`)
    sep <- sqrt(dx^2 + dy^2)
    den <- sep + diag(n) * 1e-3
    offset <- sep * invdist - 1
    diag(offset) <- 0
    list(p = p, ux = dx / den, uy = dy / den, offset = offset)
  }
  cost <- function(v) {
    q <- parts(v)
    0.5 * sum(q$offset^2) + 0.5 * meanwt * sum(colSums(q$p)^2)
  }
  grad <- function(v) {
    q <- parts(v)
    w <- invdist * q$offset
    sumpos <- colSums(q$p)
    gx <- rowSums(w * q$ux) - colSums(w * q$ux) + meanwt * sumpos[1]
    gy <- rowSums(w * q$uy) - colSums(w * q$uy) + meanwt * sumpos[2]
    as.vector(rbind(gx, gy))
  }
  # Settings of scipy.optimize.minimize(method = "L-BFGS-B").
  res <- stats::optim(as.vector(t(start)), cost, grad, method = "L-BFGS-B",
                      control = list(maxit = 15000, lmm = 10, factr = 1e7, pgtol = 1e-5))
  graph_pos_list(graph_rescale_layout(matrix(res$par, ncol = 2, byrow = TRUE), scale), ids)
}

# networkx.multipartite_layout with manim's partition handling.
graph_layout_partite <- function(graph, scale = 2, partitions = NULL, align = "vertical", ...) {
  if (is.null(partitions) || length(partitions) == 0) {
    stop("The partite layout requires partitions parameter to contain the partition of the vertices", call. = FALSE)
  }
  ids <- graph$vertex_ids()
  partitions <- lapply(partitions, function(p) as.character(unlist(p)))
  subset <- stats::setNames(rep(length(partitions), length(ids)), ids)
  for (i in seq_along(partitions)) {
    if (!all(partitions[[i]] %in% ids)) stop("The partition must contain arrays of vertices in the graph", call. = FALSE)
    subset[partitions[[i]]] <- i - 1
  }
  layers <- split(ids, factor(subset[ids], levels = sort(unique(subset))))
  width <- length(layers)
  nodes <- character()
  pos <- NULL
  for (i in seq_along(layers)) {
    layer <- layers[[i]]
    height <- length(layer)
    layer_pos <- cbind(rep(i - 1, height), seq_len(height) - 1)
    layer_pos <- sweep(layer_pos, 2, c((width - 1) / 2, (height - 1) / 2))
    pos <- rbind(pos, layer_pos)
    nodes <- c(nodes, layer)
  }
  pos <- graph_rescale_layout(pos, scale)
  if (align == "horizontal") pos <- pos[, 2:1, drop = FALSE]
  graph_pos_list(pos, nodes)
}

# SageMath's tree layout, as used by manim. Depths index the obstruction
# vector (upstream indexes it with negative y values).
graph_layout_tree <- function(graph, scale = 2, root_vertex = NULL, vertex_spacing = NULL,
                              orientation = "down", ...) {
  if (is.null(root_vertex)) stop("The tree layout requires the root_vertex parameter", call. = FALSE)
  if (!graph$is_tree()) stop("The tree layout must be used with trees", call. = FALSE)
  root <- as.character(root_vertex)
  nb <- function(v) graph$neighbors(v)
  children <- list()
  children[[root]] <- nb(root)
  stack <- list(children[[root]])
  stick <- root
  parent <- list()
  for (c in children[[root]]) parent[[c]] <- root
  px <- list()
  pdepth <- list()
  obstruction <- rep(0, length(graph$vertex_ids()) + 1)
  o <- if (orientation == "down") -1 else 1

  slide <- function(v, dx) {
    level <- v
    while (length(level)) {
      nextlevel <- character()
      for (u in level) {
        x <- px[[u]] + dx
        d <- pdepth[[u]]
        obstruction[d + 1] <<- max(x + 1, obstruction[d + 1])
        px[[u]] <<- x
        nextlevel <- c(nextlevel, children[[u]])
      }
      level <- nextlevel
    }
  }

  while (length(stack)) {
    top <- stack[[length(stack)]]
    if (length(top) == 0) {
      p <- stick[length(stick)]
      stick <- stick[-length(stick)]
      stack[[length(stack)]] <- NULL
      cp <- children[[p]]
      depth <- length(stack)
      if (length(cp) == 0) {
        x <- obstruction[depth + 1]
        px[[p]] <- x
        pdepth[[p]] <- depth
      } else {
        x <- mean(vapply(cp, function(cc) px[[cc]], numeric(1)))
        px[[p]] <- x
        pdepth[[p]] <- depth
        ox <- obstruction[depth + 1]
        if (x < ox) {
          slide(p, ox - x)
          x <- ox
        }
      }
      obstruction[depth + 1] <- x + 1
      next
    }
    t <- top[length(top)]
    stack[[length(stack)]] <- top[-length(top)]
    pt <- parent[[t]]
    ct <- setdiff(nb(t), pt)
    for (c in ct) parent[[c]] <- t
    children[[t]] <- ct
    stack[[length(stack) + 1]] <- ct
    stick <- c(stick, t)
  }

  ids <- names(px)
  xs <- vapply(ids, function(v) px[[v]], numeric(1))
  ys <- vapply(ids, function(v) o * pdepth[[v]], numeric(1))
  center <- c((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, 0)
  height <- max(ys) - min(ys)
  width <- max(xs) - min(xs)
  if (is.null(vertex_spacing)) {
    if (length(scale) == 1 && (width > 0 || height > 0)) {
      sf <- 2 * scale / max(width, height)
    } else if (length(scale) > 1) {
      sw <- if (!is.na(scale[1]) && width > 0) 2 * scale[1] / width else 1
      sh <- if (!is.na(scale[2]) && height > 0) 2 * scale[2] / height else 1
      sf <- c(sw, sh, 0)
    } else {
      sf <- 1
    }
  } else {
    sf <- c(vertex_spacing[1], vertex_spacing[2], 0)
  }
  stats::setNames(lapply(ids, function(v) (c(px[[v]], o * pdepth[[v]], 0) - center) * sf), ids)
}

graph_layouts <- function() {
  list(circular = graph_layout_circular, kamada_kawai = graph_layout_kamada_kawai,
       partite = graph_layout_partite, planar = graph_layout_planar, random = graph_layout_random,
       shell = graph_layout_shell, spectral = graph_layout_spectral, spiral = graph_layout_spiral,
       spring = graph_layout_spring, tree = graph_layout_tree)
}

# Resolve a layout (name, named list of positions, or function) to a named
# list mapping vertex ids to 3D points.
graph_determine_layout <- function(graph, layout = "spring", layout_scale = 2, layout_config = NULL) {
  layout_config <- layout_config %||% list()
  as_pos <- function(res) {
    if (is.matrix(res)) res <- graph_pos_list(res, rownames(res) %||% graph$vertex_ids())
    lapply(res, as_point)
  }
  if (is.list(layout)) return(as_pos(layout))
  if (is.character(layout)) {
    f <- graph_layouts()[[layout]]
    if (is.null(f)) {
      stop("The layout '", layout, "' is neither a recognized layout, a layout function, ",
           "nor a vertex placement list.", call. = FALSE)
    }
    return(as_pos(do.call(f, c(list(graph, scale = layout_scale), layout_config))))
  }
  if (is.function(layout)) return(as_pos(do.call(layout, c(list(graph, scale = layout_scale), layout_config))))
  stop("The layout must be a layout name, a layout function, or a vertex placement list.", call. = FALSE)
}

#' @title Graphs
#' @description `Graph()` displays an undirected graph and `DiGraph()` a
#'   directed one: vertices (by default [Dot()]s) joined by edges (by default
#'   [Line()]s). An updater keeps the edges attached to the vertices, so
#'   moving a vertex drags its edges along.
#'
#'   Vertices are identified by their names (numbers are converted to
#'   strings). Look up a vertex with `g$get(1)` or `g$vertices[["1"]]` and an
#'   edge with `g$get(c(1, 2))`. Methods: `add_vertices()`,
#'   `remove_vertices()`, `add_edges()`, `remove_edges()` and
#'   `change_layout()`; `g$animate$change_layout("circular")` animates the
#'   new layout. `g$animate$add_vertices()` and `g$animate$add_edges()`
#'   return [Create()] animations of the new mobjects, and
#'   `g$animate$remove_vertices()` and `g$animate$remove_edges()` return
#'   [Uncreate()] animations of the removed ones; choose another animation
#'   with `g$animate(animation = FadeIn)`.
#' @param vertices Vector or list of vertex names.
#' @param edges List of vertex pairs, such as `list(c(1, 2), c(2, 3))`, or a
#'   two column matrix.
#' @param labels `TRUE` labels vertices with their names via [MathTex()]; a
#'   named list maps vertex names to label mobjects.
#' @param label_fill_color Color of the labels made for `labels = TRUE`.
#' @param layout A layout name (`"spring"`, `"circular"`, `"kamada_kawai"`,
#'   `"planar"`, `"random"`, `"shell"`, `"spectral"`, `"spiral"`, `"tree"`,
#'   `"partite"`), a named list of positions, or a function
#'   `function(graph, scale, ...)` returning such a list. The layouts follow
#'   networkx; `"planar"` draws a planar graph without crossings (an error
#'   for other graphs) and can place vertices differently from networkx,
#'   which picks some vertices in hash order.
#' @param layout_scale Half width of the generated layouts.
#' @param layout_config Named list of extra arguments for the layout, for
#'   example `list(nlist = ...)` for `"shell"`, `list(root_vertex = 1,
#'   vertex_spacing = c(1, 1))` for `"tree"`, `list(dist = ...)` for
#'   `"kamada_kawai"`, or `list(seed = 1)` for `"spring"` and `"random"`.
#' @param vertex_type Constructor (or R6 generator) for vertices.
#' @param vertex_config Named list of arguments for `vertex_type`; entries
#'   named by a vertex are used for that vertex only.
#' @param vertex_mobjects Named list of mobjects used as vertices.
#' @param edge_type Constructor (or R6 generator) for edges.
#' @param partitions Partitions for the `"partite"` layout.
#' @param root_vertex Root for the `"tree"` layout.
#' @param edge_config Named list of arguments for `edge_type`; entries named
#'   `"u-v"` apply to the edge from `u` to `v`. Inside a vertex name,
#'   escape each `-` and each backslash with a backslash when the plain form
#'   would name several edges. For `DiGraph()`, a `tip_config` entry
#'   (globally or per edge) styles the tips.
#' @export
#' @examples
#' \dontrun{
#' g <- Graph(1:4, list(c(1, 2), c(2, 3), c(3, 4), c(1, 3), c(1, 4)), layout = "circular")
#' g$get(1)$move_to(c(1, 1, 0))
#' }
GenericGraphClass <- R6::R6Class("GenericGraph", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    directed = FALSE,
    vertices = NULL,
    edges = NULL,
    edge_pairs = NULL,
    graph_layout = NULL,
    labels = NULL,
    vertex_config = NULL,
    default_vertex_config = NULL,
    edge_config = NULL,
    tip_config = NULL,
    default_edge_config = NULL,
    default_tip_config = NULL,
    initialize = function(vertices, edges, labels = FALSE, label_fill_color = BLACK, layout = "spring",
                          layout_scale = 2, layout_config = NULL, vertex_type = Dot, vertex_config = NULL,
                          vertex_mobjects = NULL, edge_type = Line, partitions = NULL, root_vertex = NULL,
                          edge_config = NULL) {
      super$initialize()
      ids <- as.character(unlist(vertices))
      pairs <- graph_as_edge_list(edges)
      self$vertices <- list()
      self$edges <- list()
      self$edge_pairs <- stats::setNames(pairs, vapply(pairs, function(e) graph_edge_key(e[1], e[2]), ""))

      if (is.list(labels)) {
        self$labels <- labels
      } else if (isTRUE(labels)) {
        self$labels <- stats::setNames(lapply(ids, function(v) MathTex(v, color = label_fill_color)), ids)
      } else {
        self$labels <- list()
      }
      if (length(self$labels) && graph_is_dot_type(vertex_type)) vertex_type <- LabeledDot

      vertex_config <- vertex_config %||% list()
      self$default_vertex_config <- vertex_config[!names(vertex_config) %in% ids]
      self$vertex_config <- stats::setNames(lapply(ids, function(v) vertex_config[[v]] %||% self$default_vertex_config),
                                            ids)
      for (v in names(self$labels)) self$vertex_config[[v]]$label <- self$labels[[v]]
      verts <- lapply(ids, function(v) graph_construct(vertex_type, self$vertex_config[[v]]))
      names(verts) <- ids
      for (v in names(vertex_mobjects)) verts[[v]] <- vertex_mobjects[[v]]
      self$vertices <- verts

      self$change_layout(layout = layout, layout_scale = layout_scale, layout_config = layout_config,
                         partitions = partitions, root_vertex = root_vertex)

      edge_config <- edge_config %||% list()
      keys <- names(self$edge_pairs)
      split <- graph_split_edge_config(edge_config, pairs, self$directed)
      self$default_tip_config <- edge_config$tip_config %||% list()
      self$default_edge_config <- split$default[names(split$default) != "tip_config"]
      self$edge_config <- list()
      self$tip_config <- list()
      for (i in seq_along(keys)) {
        cfg_e <- split$per_edge[[keys[i]]]
        if (!is.null(cfg_e)) {
          self$tip_config[[keys[i]]] <- cfg_e$tip_config %||% self$default_tip_config
          cfg_e$tip_config <- NULL
          self$edge_config[[keys[i]]] <- cfg_e
        } else {
          self$tip_config[[keys[i]]] <- self$default_tip_config
          self$edge_config[[keys[i]]] <- self$default_edge_config
        }
      }
      self$populate_edge_dict(edge_type)
      self$add(unname(self$vertices))
      self$add(unname(self$edges))
      self$add_updater(function(m) m$update_edges(m))
    },
    print = function(...) {
      cat(if (self$directed) "Directed" else "Undirected", " graph on ", length(self$vertices), " vertices and ",
          length(self$edges), " edges\n", sep = "")
      invisible(self)
    },
    vertex_ids = function() names(self$vertices),
    # Vertices adjacent to v (successors for directed graphs), in edge order.
    neighbors = function(v) {
      v <- as.character(v)
      out <- character()
      for (e in self$edge_pairs) {
        if (e[1] == v) out <- c(out, e[2])
        else if (!self$directed && e[2] == v) out <- c(out, e[1])
      }
      unique(out)
    },
    is_tree = function() {
      ids <- self$vertex_ids()
      if (length(ids) == 0 || length(self$edge_pairs) != length(ids) - 1) return(FALSE)
      seen <- ids[1]
      frontier <- ids[1]
      while (length(frontier)) {
        nxt <- character()
        for (e in self$edge_pairs) {
          if (e[1] %in% frontier && !e[2] %in% seen) nxt <- c(nxt, e[2])
          if (e[2] %in% frontier && !e[1] %in% seen) nxt <- c(nxt, e[1])
        }
        nxt <- unique(nxt)
        seen <- c(seen, nxt)
        frontier <- nxt
      }
      length(seen) == length(ids)
    },
    # A vertex (k a single name) or an edge (k a pair of names).
    get = function(k) {
      k <- as.character(unlist(k))
      if (length(k) == 1 && !is.null(self$vertices[[k]])) return(self$vertices[[k]])
      if (length(k) == 2) {
        e <- self$edges[[graph_edge_key(k[1], k[2])]]
        if (!is.null(e)) return(e)
      }
      stop("Could not find ", paste(k, collapse = ", "), " in vertices or edges", call. = FALSE)
    },
    populate_edge_dict = function(edge_type) stop("To be implemented in concrete subclasses", call. = FALSE),
    update_edges = function(graph) stop("To be implemented in concrete subclasses", call. = FALSE),
    # The edge mobject for a new edge (used by add_edges).
    make_edge = function(u, v, edge_type, edge_config, tip_config = list()) {
      graph_construct(edge_type, c(list(start = self$vertices[[u]]$get_center(), end = self$vertices[[v]]$get_center(),
                                        z_index = -1), edge_config))
    },
    change_layout = function(layout = "spring", layout_scale = 2, layout_config = NULL, partitions = NULL,
                             root_vertex = NULL) {
      layout_config <- layout_config %||% list()
      if (!is.null(partitions) && is.null(layout_config$partitions)) layout_config$partitions <- partitions
      if (!is.null(root_vertex) && is.null(layout_config$root_vertex)) layout_config$root_vertex <- root_vertex
      self$graph_layout <- graph_determine_layout(self, layout, layout_scale, layout_config)
      for (v in self$vertex_ids()) {
        if (!is.null(self$graph_layout[[v]])) self$vertices[[v]]$move_to(self$graph_layout[[v]])
      }
      if (length(self$edges)) self$update_edges(self)
      invisible(self)
    },
    create_vertex = function(vertex, position = NULL, label = FALSE, label_fill_color = BLACK, vertex_type = Dot,
                             vertex_config = NULL, vertex_mobject = NULL) {
      vertex <- as.character(vertex)
      position <- if (is.null(position)) self$get_center() else as_point(position)
      if (!is.null(self$vertices[[vertex]])) {
        stop("Vertex identifier '", vertex, "' is already used for a vertex in this graph.", call. = FALSE)
      }
      if (isTRUE(label)) label <- MathTex(vertex, color = label_fill_color)
      else if (!is.null(self$labels[[vertex]])) label <- self$labels[[vertex]]
      else if (!is_mobject(label)) label <- NULL
      config <- self$default_vertex_config
      for (nm in names(vertex_config)) config[[nm]] <- vertex_config[[nm]]
      if (!is.null(label)) {
        config$label <- label
        if (graph_is_dot_type(vertex_type)) vertex_type <- LabeledDot
      }
      if (is.null(vertex_mobject)) vertex_mobject <- graph_construct(vertex_type, config)
      vertex_mobject$move_to(position)
      list(vertex = vertex, position = position, config = config, mobject = vertex_mobject)
    },
    add_created_vertex = function(created) {
      v <- created$vertex
      if (!is.null(self$vertices[[v]])) {
        stop("Vertex identifier '", v, "' is already used for a vertex in this graph.", call. = FALSE)
      }
      self$graph_layout[[v]] <- created$position
      if (!is.null(created$config$label)) self$labels[[v]] <- created$config$label
      self$vertex_config[[v]] <- created$config
      self$vertices[[v]] <- created$mobject
      created$mobject$move_to(created$position)
      self$add(created$mobject)
      created$mobject
    },
    create_vertices = function(vertices, positions = NULL, labels = FALSE, label_fill_color = BLACK,
                               vertex_type = Dot, vertex_config = NULL, vertex_mobjects = NULL) {
      vertices <- as.character(unlist(vertices))
      positions <- positions %||% list()
      vertex_mobjects <- vertex_mobjects %||% list()
      vertex_config <- vertex_config %||% list()
      base_config <- self$default_vertex_config
      for (nm in setdiff(names(vertex_config), vertices)) base_config[[nm]] <- vertex_config[[nm]]
      lapply(vertices, function(v) {
        lab <- if (is.list(labels)) (labels[[v]] %||% FALSE) else labels
        self$create_vertex(v, position = positions[[v]] %||% self$get_center(), label = lab,
                           label_fill_color = label_fill_color, vertex_type = vertex_type,
                           vertex_config = vertex_config[[v]] %||% base_config, vertex_mobject = vertex_mobjects[[v]])
      })
    },
    add_vertices = function(..., positions = NULL, labels = FALSE, label_fill_color = BLACK, vertex_type = Dot,
                            vertex_config = NULL, vertex_mobjects = NULL) {
      created <- self$create_vertices(list(...), positions = positions, labels = labels,
                                      label_fill_color = label_fill_color, vertex_type = vertex_type,
                                      vertex_config = vertex_config, vertex_mobjects = vertex_mobjects)
      lapply(created, self$add_created_vertex)
    },
    remove_vertex = function(vertex) {
      vertex <- as.character(vertex)
      if (is.null(self$vertices[[vertex]])) {
        stop("The graph does not contain a vertex with identifier '", vertex, "'", call. = FALSE)
      }
      self$graph_layout[[vertex]] <- NULL
      self$labels[[vertex]] <- NULL
      self$vertex_config[[vertex]] <- NULL
      keys <- names(Filter(function(e) vertex %in% e, self$edge_pairs))
      to_remove <- unname(self$edges[keys])
      for (k in keys) {
        self$edge_config[[k]] <- NULL
        self$tip_config[[k]] <- NULL
        self$edges[[k]] <- NULL
        self$edge_pairs[[k]] <- NULL
      }
      to_remove[[length(to_remove) + 1]] <- self$vertices[[vertex]]
      self$vertices[[vertex]] <- NULL
      self$remove(to_remove)
      do.call(self$get_group_class(), to_remove)
    },
    remove_vertices = function(...) {
      mobjects <- list()
      for (v in as.character(unlist(list(...)))) mobjects <- c(mobjects, self$remove_vertex(v)$submobjects)
      do.call(self$get_group_class(), mobjects)
    },
    add_edge = function(edge, edge_type = Line, edge_config = NULL) {
      edge <- as.character(unlist(edge))
      added <- list()
      for (v in edge) if (is.null(self$vertices[[v]])) added <- c(added, self$add_vertices(v))
      u <- edge[1]
      v <- edge[2]
      key <- graph_edge_key(u, v)
      config <- self$default_edge_config
      for (nm in names(edge_config)) config[[nm]] <- edge_config[[nm]]
      tip_config <- config$tip_config %||% self$default_tip_config
      config$tip_config <- NULL
      self$edge_pairs[[key]] <- c(u, v)
      self$edge_config[[key]] <- config
      self$tip_config[[key]] <- tip_config
      edge_mobject <- self$make_edge(u, v, edge_type, config, tip_config)
      self$edges[[key]] <- edge_mobject
      self$add(edge_mobject)
      do.call(self$get_group_class(), c(added, list(edge_mobject)))
    },
    add_edges = function(..., edge_type = Line, edge_config = NULL) {
      a <- graph_split_dots(list(...))
      edges <- graph_as_edge_list(a$unnamed)
      keys <- vapply(edges, function(e) graph_edge_key(e[1], e[2]), "")
      ec <- graph_split_edge_config(edge_config %||% list(), edges, self$directed)
      base <- self$default_edge_config
      for (nm in names(ec$default)) base[[nm]] <- ec$default[[nm]]
      new_vertices <- setdiff(unique(unlist(edges)), self$vertex_ids())
      added <- if (length(new_vertices)) do.call(self$add_vertices, c(as.list(new_vertices), a$named)) else list()
      for (i in seq_along(edges)) {
        cfg_e <- base
        for (nm in names(ec$per_edge[[keys[i]]])) cfg_e[[nm]] <- ec$per_edge[[keys[i]]][[nm]]
        added <- c(added, self$add_edge(edges[[i]], edge_type = edge_type, edge_config = cfg_e)$submobjects)
      }
      do.call(self$get_group_class(), added)
    },
    remove_edge = function(edge) {
      edge <- as.character(unlist(edge))
      key <- graph_edge_key(edge[1], edge[2])
      edge_mobject <- self$edges[[key]]
      if (is.null(edge_mobject)) {
        stop("The graph does not contain a edge '(", edge[1], ", ", edge[2], ")'", call. = FALSE)
      }
      self$edges[[key]] <- NULL
      self$edge_pairs[[key]] <- NULL
      self$edge_config[[key]] <- NULL
      self$tip_config[[key]] <- NULL
      self$remove(edge_mobject)
      edge_mobject
    },
    remove_edges = function(...) {
      edges <- graph_as_edge_list(list(...))
      do.call(self$get_group_class(), lapply(edges, self$remove_edge))
    },
    # Animations for g$animate$add_vertices() and friends (upstream's
    # override_animate). `anim_args$animation` picks the animation applied to
    # each new or removed mobject; the other anim_args are passed to it.
    # New vertices join the graph only when the animation ends.
    animate_override_add_vertices = function(..., anim_args = NULL) {
      a <- graph_split_dots(list(...))
      created <- do.call(self$create_vertices, c(list(a$unnamed), a$named))
      on_finish <- function(scene) {
        for (cv in created) {
          scene$remove(cv$mobject)
          self$add_created_vertex(cv)
        }
      }
      graph_animation_group(lapply(created, `[[`, "mobject"), anim_args, Create, group = self, on_finish = on_finish)
    },
    animate_override_remove_vertices = function(..., anim_args = NULL) {
      graph_animation_group(self$remove_vertices(...)$submobjects, anim_args, Uncreate, group = self)
    },
    animate_override_add_edges = function(..., anim_args = NULL) {
      graph_animation_group(self$add_edges(...)$submobjects, anim_args, Create, group = self)
    },
    animate_override_remove_edges = function(..., anim_args = NULL) {
      graph_animation_group(self$remove_edges(...)$submobjects, anim_args, Uncreate)
    }
  )
)

# AnimationGroup applying anim_args$animation (default `default`) to each mobject.
graph_animation_group <- function(mobjects, anim_args, default, ...) {
  anim_args <- anim_args %||% list()
  animation <- anim_args$animation %||% default
  anim_args$animation <- NULL
  anims <- lapply(mobjects, function(m) graph_construct(animation, c(list(m), anim_args)))
  do.call(AnimationGroup, c(anims, list(...)))
}

#' @rdname GenericGraphClass
#' @format NULL
#' @usage NULL
#' @export
GraphClass <- R6::R6Class("Graph", inherit = GenericGraphClass, lock_objects = FALSE,
  public = list(
    populate_edge_dict = function(edge_type) {
      self$edges <- list()
      for (key in names(self$edge_pairs)) {
        e <- self$edge_pairs[[key]]
        self$edges[[key]] <- self$make_edge(e[1], e[2], edge_type, self$edge_config[[key]])
      }
      invisible(self)
    },
    # Upstream reads buff and path_arc from a dict keyed by edges, so they are
    # always 0 here too.
    update_edges = function(graph) {
      for (key in names(graph$edges)) {
        e <- graph$edge_pairs[[key]]
        graph$edges[[key]]$set_points_by_ends(graph$vertices[[e[1]]]$get_center(), graph$vertices[[e[2]]]$get_center(),
                                             buff = 0, path_arc = 0)
      }
      invisible(self)
    }
  )
)

#' @rdname GenericGraphClass
#' @export
Graph <- constructor(GraphClass)
#' @rdname GenericGraphClass
#' @format NULL
#' @usage NULL
#' @export
DiGraphClass <- R6::R6Class("DiGraph", inherit = GenericGraphClass, lock_objects = FALSE,
  public = list(
    directed = TRUE,
    make_edge = function(u, v, edge_type, edge_config, tip_config = list()) {
      edge <- graph_construct(edge_type, c(list(start = self$vertices[[u]], end = self$vertices[[v]], z_index = -1),
                                           edge_config))
      do.call(edge$add_tip, tip_config)
      edge
    },
    populate_edge_dict = function(edge_type) {
      self$edges <- list()
      for (key in names(self$edge_pairs)) {
        e <- self$edge_pairs[[key]]
        self$edges[[key]] <- self$make_edge(e[1], e[2], edge_type, self$edge_config[[key]], self$tip_config[[key]])
      }
      invisible(self)
    },
    # Arrow tips are taken off and put back so they are not deformed; passing
    # the vertex mobjects makes the edges stop at their bounding boxes.
    update_edges = function(graph) {
      for (key in names(graph$edges)) {
        e <- graph$edge_pairs[[key]]
        edge <- graph$edges[[key]]
        tips <- edge$pop_tips()$submobjects
        edge$set_points_by_ends(graph$vertices[[e[1]]], graph$vertices[[e[2]]], buff = 0, path_arc = 0)
        if (length(tips)) edge$add_tip(tip = tips[[1]])
      }
      invisible(self)
    }
  )
)

#' @rdname GenericGraphClass
#' @export
DiGraph <- constructor(DiGraphClass)