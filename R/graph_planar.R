# The "planar" graph layout, ported from networkx: the left right planarity
# test of networkx/algorithms/planarity.py (its recursive variant), which also
# builds a combinatorial embedding, and the Chrobak and Payne straight line
# drawing of networkx/algorithms/planar_drawing.py. Vertices are the indices
# 1..n of graph$vertex_ids(); an edge of the planarity test is an integer id.
#
# Where networkx takes an element of a Python set (the next vertex of the
# canonical ordering, and one vertex per connected component), the vertex
# that comes first in vertex order is taken here, so positions can differ
# from networkx; the drawing is crossing free either way.

# networkx.planar_layout: straight line drawing without crossings, rescaled.
graph_layout_planar <- function(graph, scale = 2, ...) {
  ids <- graph$vertex_ids()
  n <- length(ids)
  if (n == 0) return(list())
  pairs <- lapply(graph$edge_pairs, function(e) match(e, ids))
  emb <- planar_embedding(n, planar_lr_adjacency(n, pairs, graph$directed))
  if (is.null(emb)) stop("The planar layout needs a planar graph; this graph is not planar.", call. = FALSE)
  graph_pos_list(graph_rescale_layout(planar_embedding_to_pos(emb), scale), ids)
}

# Adjacency lists of the undirected graph LRPlanarity builds: manim fills a
# networkx graph with the vertices and then the edges, and LRPlanarity copies
# it edge by edge (in G.edges order) without self loops.
planar_lr_adjacency <- function(n, pairs, directed) {
  add <- function(adj, u, v) {
    if (!v %in% adj[[u]]) adj[[u]] <- c(adj[[u]], v)
    adj
  }
  adj <- replicate(n, integer(), simplify = FALSE)
  for (e in pairs) {
    adj <- add(adj, e[1], e[2])
    if (!directed) adj <- add(adj, e[2], e[1])
  }
  lr <- replicate(n, integer(), simplify = FALSE)
  for (u in seq_len(n)) {
    for (v in adj[[u]]) {
      if (u == v || (!directed && v < u)) next
      lr <- add(add(lr, u, v), v, u)
    }
  }
  lr
}

# LRPlanarity.lr_planarity: a planar embedding (see planar_embedding_new())
# or NULL when the graph is not planar.
# ponytail: recursive like networkx's *_recursive methods, so the depth grows
# with the longest DFS path; use the iterative variants for huge graphs.
planar_embedding <- function(n, adj) {
  if (n > 2 && sum(lengths(adj)) / 2 > 3 * n - 6) return(NULL)
  height <- rep(NA_integer_, n)
  parent_edge <- rep(NA_integer_, n)
  eid <- matrix(0L, n, n)
  from <- integer()
  to <- integer()
  lowpt <- integer()
  lowpt2 <- integer()
  nesting <- integer()
  dg <- replicate(n, integer(), simplify = FALSE)
  roots <- integer()

  # Orientation by DFS: lowpoints and nesting depths.
  orient <- function(v) {
    e <- parent_edge[v]
    for (w in adj[[v]]) {
      if (eid[v, w] > 0 || eid[w, v] > 0) next
      id <- length(from) + 1L
      from[id] <<- v
      to[id] <<- w
      eid[v, w] <<- id
      dg[[v]] <<- c(dg[[v]], w)
      lowpt[id] <<- height[v]
      lowpt2[id] <<- height[v]
      if (is.na(height[w])) {
        parent_edge[w] <<- id
        height[w] <<- height[v] + 1L
        orient(w)
      } else {
        lowpt[id] <<- height[w]
      }
      nesting[id] <<- 2L * lowpt[id] + (lowpt2[id] < height[v])
      if (!is.na(e)) {
        if (lowpt[id] < lowpt[e]) {
          lowpt2[e] <<- min(lowpt[e], lowpt2[id])
          lowpt[e] <<- lowpt[id]
        } else if (lowpt[id] > lowpt[e]) {
          lowpt2[e] <<- min(lowpt2[e], lowpt[id])
        } else {
          lowpt2[e] <<- min(lowpt2[e], lowpt2[id])
        }
      }
    }
  }
  for (v in seq_len(n)) {
    if (is.na(height[v])) {
      height[v] <- 0L
      roots <- c(roots, v)
      orient(v)
    }
  }

  ne <- length(from)
  ref <- rep(NA_integer_, ne)
  side <- rep(1L, ne)
  lowpt_edge <- rep(NA_integer_, ne)
  stack_bottom <- vector("list", ne)
  # networkx also writes ref[None]; nothing reads it.
  set_ref <- function(e, value) if (!is.na(e)) ref[e] <<- value
  # Intervals and conflict pairs are mutable objects compared by identity.
  interval <- function(low = NA_integer_, high = NA_integer_) {
    iv <- new.env(parent = emptyenv())
    iv$low <- low
    iv$high <- high
    iv
  }
  is_empty <- function(iv) is.na(iv$low) && is.na(iv$high)
  conflicting <- function(iv, b) !is_empty(iv) && lowpt[iv$high] > lowpt[b]
  conflict_pair <- function(left = interval(), right = interval()) {
    p <- new.env(parent = emptyenv())
    p$left <- left
    p$right <- right
    p
  }
  swap <- function(p) {
    tmp <- p$left
    p$left <- p$right
    p$right <- tmp
  }
  lowest <- function(p) {
    if (is_empty(p$left)) return(lowpt[p$right$low])
    if (is_empty(p$right)) return(lowpt[p$left$low])
    min(lowpt[p$left$low], lowpt[p$right$low])
  }
  S <- list()
  top <- function() if (length(S)) S[[length(S)]] else NULL
  push <- function(p) S[[length(S) + 1L]] <<- p
  pop <- function() {
    p <- S[[length(S)]]
    S[[length(S)]] <<- NULL
    p
  }

  add_constraints <- function(ei, e) {
    P <- conflict_pair()
    # Merge return edges of ei into P$right.
    repeat {
      Q <- pop()
      if (!is_empty(Q$left)) swap(Q)
      if (!is_empty(Q$left)) return(FALSE)
      if (lowpt[Q$right$low] > lowpt[e]) {
        if (is_empty(P$right)) P$right <- interval(Q$right$low, Q$right$high) else set_ref(P$right$low, Q$right$high)
        P$right$low <- Q$right$low
      } else {
        set_ref(Q$right$low, lowpt_edge[e])
      }
      if (identical(top(), stack_bottom[[ei]])) break
    }
    # Merge conflicting return edges of the earlier edges into P$left.
    while (conflicting(top()$left, ei) || conflicting(top()$right, ei)) {
      Q <- pop()
      if (conflicting(Q$right, ei)) swap(Q)
      if (conflicting(Q$right, ei)) return(FALSE)
      set_ref(P$right$low, Q$right$high)
      if (!is.na(Q$right$low)) P$right$low <- Q$right$low
      if (is_empty(P$left)) P$left <- interval(Q$left$low, Q$left$high) else set_ref(P$left$low, Q$left$high)
      P$left$low <- Q$left$low
    }
    if (!(is_empty(P$left) && is_empty(P$right))) push(P)
    TRUE
  }

  remove_back_edges <- function(e) {
    u <- from[e]
    # Drop entire conflict pairs ending at u.
    while (length(S) && lowest(top()) == height[u]) {
      P <- pop()
      if (!is.na(P$left$low)) side[P$left$low] <<- -1L
    }
    if (length(S)) {
      P <- pop()
      while (!is.na(P$left$high) && to[P$left$high] == u) P$left$high <- ref[P$left$high]
      if (is.na(P$left$high) && !is.na(P$left$low)) {
        set_ref(P$left$low, P$right$low)
        side[P$left$low] <<- -1L
        P$left$low <- NA_integer_
      }
      while (!is.na(P$right$high) && to[P$right$high] == u) P$right$high <- ref[P$right$high]
      if (is.na(P$right$high) && !is.na(P$right$low)) {
        set_ref(P$right$low, P$left$low)
        side[P$right$low] <<- -1L
        P$right$low <- NA_integer_
      }
      push(P)
    }
    # The side of e is the side of a highest return edge.
    if (lowpt[e] < height[u]) {
      hl <- top()$left$high
      hr <- top()$right$high
      ref[e] <<- if (!is.na(hl) && (is.na(hr) || lowpt[hl] > lowpt[hr])) hl else hr
    }
  }

  ordered <- lapply(seq_len(n), function(v) dg[[v]][order(nesting[eid[v, dg[[v]]]])])
  lr_test <- function(v) {
    e <- parent_edge[v]
    oa <- ordered[[v]]
    for (w in oa) {
      ei <- eid[v, w]
      stack_bottom[ei] <<- list(top())
      if (isTRUE(parent_edge[w] == ei)) {
        if (!lr_test(w)) return(FALSE)
      } else {
        lowpt_edge[ei] <<- ei
        push(conflict_pair(right = interval(ei, ei)))
      }
      if (lowpt[ei] < height[v]) {
        if (w == oa[1]) {
          lowpt_edge[e] <<- lowpt_edge[ei]
        } else if (!add_constraints(ei, e)) {
          return(FALSE)
        }
      }
    }
    if (!is.na(e)) remove_back_edges(e)
    TRUE
  }
  for (v in roots) if (!lr_test(v)) return(NULL)

  # Resolve relative sides into absolute ones.
  sign_of <- function(e) {
    if (!is.na(ref[e])) {
      side[e] <<- side[e] * sign_of(ref[e])
      ref[e] <<- NA_integer_
    }
    side[e]
  }
  for (v in seq_len(n)) {
    for (w in dg[[v]]) {
      id <- eid[v, w]
      nesting[id] <- sign_of(id) * nesting[id]
    }
  }

  emb <- planar_embedding_new(n)
  for (v in seq_len(n)) {
    ordered[[v]] <- dg[[v]][order(nesting[eid[v, dg[[v]]]])]
    previous <- NA_integer_
    for (w in ordered[[v]]) {
      planar_add_half_edge(emb, v, w, ccw = previous)
      previous <- w
    }
  }
  left_ref <- rep(NA_integer_, n)
  right_ref <- rep(NA_integer_, n)
  lr_embed <- function(v) {
    for (w in ordered[[v]]) {
      ei <- eid[v, w]
      if (isTRUE(parent_edge[w] == ei)) {
        planar_add_half_edge_first(emb, w, v)
        left_ref[v] <<- w
        right_ref[v] <<- w
        lr_embed(w)
      } else if (side[ei] == 1L) {
        planar_add_half_edge(emb, w, v, ccw = right_ref[w])
      } else {
        planar_add_half_edge(emb, w, v, cw = left_ref[w])
        left_ref[w] <<- v
      }
    }
  }
  for (v in roots) lr_embed(v)
  emb
}

# networkx.PlanarEmbedding as an environment: nbrs[[v]] lists the neighbors
# of v in the insertion order of networkx's successor dict (its last entry is
# the leftmost neighbor), and cw[v, w] and ccw[v, w] are the neighbors of v
# after and before w in clockwise order.
planar_embedding_new <- function(n) {
  emb <- new.env(parent = emptyenv())
  emb$nbrs <- replicate(n, integer(), simplify = FALSE)
  emb$cw <- matrix(NA_integer_, n, n)
  emb$ccw <- matrix(NA_integer_, n, n)
  emb
}

planar_set_half_edge <- function(emb, s, t, cw, ccw) {
  if (!t %in% emb$nbrs[[s]]) emb$nbrs[[s]] <- c(emb$nbrs[[s]], t)
  emb$cw[s, t] <- cw
  emb$ccw[s, t] <- ccw
}

# PlanarEmbedding.add_half_edge: insert t counterclockwise of `cw` or
# clockwise of `ccw` among the neighbors of s.
planar_add_half_edge <- function(emb, s, t, cw = NA_integer_, ccw = NA_integer_) {
  succs <- emb$nbrs[[s]]
  if (!length(succs)) return(planar_set_half_edge(emb, s, t, t, t))
  leftmost <- succs[length(succs)]
  if (!is.na(cw)) {
    ref_ccw <- emb$ccw[s, cw]
    planar_set_half_edge(emb, s, t, cw, ref_ccw)
    emb$cw[s, ref_ccw] <- t
    emb$ccw[s, cw] <- t
    move <- cw != leftmost
  } else if (!is.na(ccw)) {
    ref_cw <- emb$cw[s, ccw]
    planar_set_half_edge(emb, s, t, ref_cw, ccw)
    emb$ccw[s, ref_cw] <- t
    emb$cw[s, ccw] <- t
    move <- TRUE
  } else {
    stop("Node already has out-half-edge(s), either cw or ccw reference node required.", call. = FALSE)
  }
  # Keep the leftmost neighbor last.
  if (move) emb$nbrs[[s]] <- c(setdiff(emb$nbrs[[s]], leftmost), leftmost)
}

planar_add_half_edge_first <- function(emb, s, t) {
  succs <- emb$nbrs[[s]]
  planar_add_half_edge(emb, s, t, cw = if (length(succs)) succs[length(succs)] else NA_integer_)
}

planar_neighbors_cw <- function(emb, v) {
  s <- emb$nbrs[[v]]
  if (!length(s)) return(integer())
  out <- start <- s[length(s)]
  cur <- emb$cw[v, start]
  while (cur != start) {
    out <- c(out, cur)
    cur <- emb$cw[v, cur]
  }
  out
}

# The half edge after (v, w) on the face to its right.
planar_next_face_half_edge <- function(emb, v, w) c(w, emb$ccw[w, v])

# networkx.combinatorial_embedding_to_pos (Chrobak and Payne): integer grid
# positions, an n x 2 matrix. Triangulates `emb` in place.
planar_embedding_to_pos <- function(emb) {
  n <- length(emb$nbrs)
  if (n < 4) return(rbind(c(0, 0), c(2, 0), c(1, 1))[seq_len(n), , drop = FALSE])
  node_list <- planar_canonical_ordering(emb, planar_triangulate(emb))
  node <- function(k) node_list[[k]][[1]]
  left <- rep(NA_integer_, n)
  right <- rep(NA_integer_, n)
  delta_x <- numeric(n)
  y <- numeric(n)
  v1 <- node(1)
  v2 <- node(2)
  v3 <- node(3)
  delta_x[c(v1, v2, v3)] <- c(0, 1, 1)
  y[c(v1, v2, v3)] <- c(0, 0, 1)
  right[v1] <- v3
  right[v3] <- v2
  for (k in 4:n) {
    vk <- node(k)
    contour <- node_list[[k]][[2]]
    m <- length(contour)
    wp <- contour[1]
    wp1 <- contour[2]
    wq <- contour[m]
    wq1 <- contour[m - 1]
    # Stretch gaps, then adjust offsets.
    delta_x[wp1] <- delta_x[wp1] + 1
    delta_x[wq] <- delta_x[wq] + 1
    d <- sum(delta_x[contour[-1]])
    delta_x[vk] <- (-y[wp] + d + y[wq]) %/% 2
    y[vk] <- (y[wp] + d + y[wq]) %/% 2
    delta_x[wq] <- d - delta_x[vk]
    if (m > 2) delta_x[wp1] <- delta_x[wp1] - delta_x[vk]
    # Install vk.
    right[wp] <- vk
    right[vk] <- wq
    if (m > 2) {
      left[vk] <- wp1
      right[wq1] <- NA_integer_
    } else {
      left[vk] <- NA_integer_
    }
  }
  pos <- matrix(NA_real_, n, 2)
  pos[v1, ] <- c(0, y[v1])
  remaining <- v1
  while (length(remaining)) {
    parent <- remaining[length(remaining)]
    remaining <- remaining[-length(remaining)]
    for (child in c(left[parent], right[parent])) {
      if (is.na(child)) next
      pos[child, ] <- c(pos[parent, 1] + delta_x[child], y[child])
      remaining <- c(remaining, child)
    }
  }
  pos
}

# networkx triangulate_embedding(fully_triangulate = FALSE): connects the
# components, makes every face 2-connected and triangulates all faces but a
# largest one, which it returns as the outer face.
planar_triangulate <- function(emb) {
  n <- length(emb$nbrs)
  seen <- logical(n)
  reps <- integer()
  for (v in seq_len(n)) {
    if (seen[v]) next
    reps <- c(reps, v)
    frontier <- v
    seen[v] <- TRUE
    while (length(frontier)) {
      nxt <- setdiff(unlist(emb$nbrs[frontier]), which(seen))
      seen[nxt] <- TRUE
      frontier <- nxt
    }
  }
  for (i in seq_len(length(reps) - 1)) {
    for (pair in list(reps[c(i, i + 1)], reps[c(i + 1, i)])) {
      s <- emb$nbrs[[pair[1]]]
      planar_add_half_edge(emb, pair[1], pair[2], cw = if (length(s)) s[length(s)] else NA_integer_)
    }
  }
  emb$visited <- matrix(FALSE, n, n)
  faces <- list()
  outer <- 0
  for (v in seq_len(n)) {
    s <- emb$nbrs[[v]]
    if (!length(s)) next
    # Follows the clockwise order live, as networkx's generator does.
    start <- w <- s[length(s)]
    repeat {
      face <- planar_make_bi_connected(emb, v, w)
      if (length(face)) {
        faces[[length(faces) + 1]] <- face
        if (outer == 0 || length(face) > length(faces[[outer]])) outer <- length(faces)
      }
      w <- emb$cw[v, w]
      if (w == start) break
    }
  }
  for (i in seq_along(faces)) if (i != outer) planar_triangulate_face(emb, faces[[i]][1], faces[[i]][2])
  faces[[outer]]
}

planar_triangulate_face <- function(emb, v1, v2) {
  v3 <- planar_next_face_half_edge(emb, v1, v2)[2]
  v4 <- planar_next_face_half_edge(emb, v2, v3)[2]
  if (v1 == v2 || v1 == v3) return(invisible())
  while (v1 != v4) {
    if (v3 %in% emb$nbrs[[v1]]) {
      v1 <- v2
    } else {
      planar_add_half_edge(emb, v1, v3, ccw = v2)
      planar_add_half_edge(emb, v3, v1, cw = v2)
    }
    v2 <- v3
    v3 <- v4
    v4 <- planar_next_face_half_edge(emb, v2, v3)[2]
  }
}

# networkx make_bi_connected: the nodes around the face of the half edge
# (start, out), adding edges where a node repeats; empty if already visited.
planar_make_bi_connected <- function(emb, start, out) {
  if (emb$visited[start, out]) return(integer())
  emb$visited[start, out] <- TRUE
  v1 <- start
  v2 <- out
  face <- start
  v3 <- planar_next_face_half_edge(emb, v1, v2)[2]
  while (v2 != start || v3 != out) {
    if (v1 == v2) stop("Invalid half-edge", call. = FALSE)
    if (v2 %in% face) {
      planar_add_half_edge(emb, v1, v3, ccw = v2)
      planar_add_half_edge(emb, v3, v1, cw = v2)
      emb$visited[v2, v3] <- TRUE
      emb$visited[v3, v1] <- TRUE
      v2 <- v1
    } else {
      face <- c(face, v2)
    }
    v1 <- v2
    nxt <- planar_next_face_half_edge(emb, v2, v3)
    v2 <- nxt[1]
    v3 <- nxt[2]
    emb$visited[v1, v2] <- TRUE
  }
  face
}

# networkx get_canonical_ordering: list of list(vk, contour) where contour
# is the outer face of G_k between the neighbors wp and wq of vk.
planar_canonical_ordering <- function(emb, outer_face) {
  n <- length(emb$nbrs)
  k_out <- length(outer_face)
  v1 <- outer_face[1]
  v2 <- outer_face[2]
  chords <- integer(n)
  marked <- logical(n)
  ready <- logical(n)
  ready[outer_face] <- TRUE
  ccw_nbr <- rep(NA_integer_, n)
  cw_nbr <- rep(NA_integer_, n)
  prev <- v2
  for (idx in seq_len(k_out)[-(1:2)]) {
    ccw_nbr[prev] <- outer_face[idx]
    prev <- outer_face[idx]
  }
  ccw_nbr[prev] <- v1
  prev <- v1
  for (idx in rev(seq_len(k_out)[-1])) {
    cw_nbr[prev] <- outer_face[idx]
    prev <- outer_face[idx]
  }
  is_outer_face_nbr <- function(x, y) {
    if (is.na(ccw_nbr[x])) return(cw_nbr[x] == y)
    if (is.na(cw_nbr[x])) return(ccw_nbr[x] == y)
    ccw_nbr[x] == y || cw_nbr[x] == y
  }
  is_on_outer_face <- function(x) !marked[x] && (!is.na(ccw_nbr[x]) || x == v1)
  for (v in outer_face) {
    for (nbr in planar_neighbors_cw(emb, v)) {
      if (is_on_outer_face(nbr) && !is_outer_face_nbr(v, nbr)) {
        chords[v] <- chords[v] + 1L
        ready[v] <- FALSE
      }
    }
  }
  ordering <- vector("list", n)
  ordering[[1]] <- list(v1, integer())
  ordering[[2]] <- list(v2, integer())
  ready[c(v1, v2)] <- FALSE
  for (k in seq(n, 3)) {
    v <- which(ready)[1]
    ready[v] <- FALSE
    marked[v] <- TRUE
    wp <- NA_integer_
    wq <- NA_integer_
    for (nbr in planar_neighbors_cw(emb, v)) {
      if (marked[nbr]) next
      if (is_on_outer_face(nbr)) {
        if (nbr == v1) {
          wp <- v1
        } else if (nbr == v2) {
          wq <- v2
        } else if (cw_nbr[nbr] == v) {
          wp <- nbr
        } else {
          wq <- nbr
        }
      }
      if (!is.na(wp) && !is.na(wq)) break
    }
    wp_wq <- nbr <- wp
    while (nbr != wq) {
      next_nbr <- emb$ccw[v, nbr]
      wp_wq <- c(wp_wq, next_nbr)
      cw_nbr[nbr] <- next_nbr
      ccw_nbr[next_nbr] <- nbr
      nbr <- next_nbr
    }
    if (length(wp_wq) == 2) {
      for (x in c(wp, wq)) {
        chords[x] <- chords[x] - 1L
        if (chords[x] == 0) ready[x] <- TRUE
      }
    } else {
      new_face_nodes <- unique(wp_wq[-c(1, length(wp_wq))])
      for (w in new_face_nodes) {
        ready[w] <- TRUE
        for (nbr in planar_neighbors_cw(emb, w)) {
          if (is_on_outer_face(nbr) && !is_outer_face_nbr(w, nbr)) {
            chords[w] <- chords[w] + 1L
            ready[w] <- FALSE
            if (!nbr %in% new_face_nodes) {
              chords[nbr] <- chords[nbr] + 1L
              ready[nbr] <- FALSE
            }
          }
        }
      }
    }
    ordering[[k]] <- list(v, wp_wq)
  }
  ordering
}
