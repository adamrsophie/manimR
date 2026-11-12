# Typst rendering: Typst and MathTypst.
# Ported from manim/mobject/text/typst_mobject.py and
# manim/utils/typst_file_writing.py. Upstream calls the `typst` Python
# bindings; manimR runs the `typst` command line compiler instead. Its path
# comes from `manim_config(typst = ...)`, falling back to `typst` on the PATH.

# Use 10pt instead of Typst's 11pt default so that the post import scaling
# based on Manim's font_size property matches Tex and MathTex closely.
TYPST_COMPILATION_FONT_SIZE <- 10

TYPST_TEMPLATE <- "#set page(width: auto, height: auto, margin: 0pt, fill: none)\n#set text(size: %spt)\n%s\n%s\n"

# Empirical correction so Typst authored SVG strokes (fraction bars,
# underlines) visually match the weight of TeX derived geometry after
# import into Manim's pixel based stroke model.
TYPST_SVG_STROKE_WIDTH_SCALE <- 0.5
TYPST_DUPLICATE_LABEL_SUFFIX <- "__manim_typst_dup_"
TYPST_LABEL_RE <- "(?s)^(.*)\\s*:\\s*([a-zA-Z_][a-zA-Z0-9_-]*)\\s*$"
TYPST_SVG_LEAF_TAGS <- c("circle", "ellipse", "image", "line", "path", "polygon", "polyline", "rect", "text", "use")

# Typst sources and SVGs are cached in the tex directory, as upstream does.
typst_dir <- function() tex_dir()

typst_hash <- function(content) {
  substr(digest::digest(enc2utf8(content), algo = "sha256", serialize = FALSE), 1, 16)
}

# Path of the typst compiler, or "" when it cannot be found.
typst_executable <- function() unname(Sys.which(path.expand(cfg("typst") %||% "typst")))

#' Compile Typst to SVG
#'
#' Writes the markup into a minimal Typst document (auto sized page, no
#' margin, 10pt text) and compiles it with the `typst` command line
#' compiler. The `.typ` source and the `.svg` result are cached in
#' the `tex_dir` setting (`media/Tex`) under a hash of the full source. Set the compiler path with
#' `manim_config(typst = "/path/to/typst")` when it is not on the `PATH`.
#'
#' @param typst_code Body of the Typst document.
#' @param preamble Typst code inserted between the `#set` rules and the body,
#'   for `#import`, `#set` or `#show` rules.
#' @param text_size Font size in Typst points used during compilation.
#' @param font_paths Optional character vector of extra font directories.
#' @return Path to the SVG file.
#' @export
typst_to_svg_file <- function(typst_code, preamble = "", text_size = TYPST_COMPILATION_FONT_SIZE,
                              font_paths = NULL) {
  full_source <- sprintf(TYPST_TEMPLATE, format(text_size), preamble, typst_code)
  dir <- typst_dir()
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  base <- file.path(dir, typst_hash(full_source))
  typ_file <- paste0(base, ".typ")
  svg_file <- paste0(base, ".svg")
  if (file.exists(svg_file)) return(svg_file)
  writeBin(charToRaw(enc2utf8(full_source)), typ_file)
  exe <- typst_executable()
  if (!nzchar(exe)) {
    stop("The typst compiler was not found. Install it from https://github.com/typst/typst/releases ",
         "and put it on the PATH, or set manim_config(typst = \"/path/to/typst\").", call. = FALSE)
  }
  fonts <- as.vector(rbind(rep("--font-path", length(font_paths)), path.expand(as.character(font_paths))))
  out <- suppressWarnings(system2(exe, shQuote(c("compile", fonts, typ_file, svg_file)), stdout = TRUE, stderr = TRUE))
  if (!is.null(attr(out, "status")) || !file.exists(svg_file)) {
    unlink(svg_file)
    stop("Typst compilation of ", typ_file, " failed:\n", paste(out, collapse = "\n"), call. = FALSE)
  }
  svg_file
}

# Layout transparent capture helper. The final render uses `none` as the
# target and returns every group body unchanged; probe renders hide one
# label at a time with Typst's layout preserving `hide`.
typst_manimgrp_preamble <- function(target = NULL) {
  target_value <- if (is.null(target)) "none" else paste0("\"", target, "\"")
  paste0("#let manimgrp(lbl, body) = if lbl == ", target_value, " { hide(body) } else { body }")
}

# Rendered SVG leaves in drawing order, each with its effective transform
# (3 x 3, column vector convention as in svg.R). Nothing inside <defs> counts.
typst_svg_leaves <- function(parent, M = svg_identity()) {
  out <- list()
  for (el in xml2::xml_children(parent)) {
    tag <- xml2::xml_name(el)
    if (tag == "defs") next
    Me <- M %*% parse_svg_transform(xml2::xml_attr(el, "transform"))
    if (tag %in% TYPST_SVG_LEAF_TAGS) out[[length(out) + 1L]] <- list(node = el, matrix = Me)
    out <- c(out, typst_svg_leaves(el, Me))
  }
  out
}

# Stable signatures (tag, attributes, text, effective transform) for the
# rendered SVG leaves in drawing order.
typst_svg_leaf_signatures <- function(svg_file) {
  doc <- xml2::read_xml(svg_file, options = "HUGE")
  vapply(typst_svg_leaves(xml2::xml_root(doc)), function(leaf) {
    a <- xml2::xml_attrs(leaf$node)
    a <- a[names(a) != "transform"]
    a <- a[sort(names(a), method = "radix", index.return = TRUE)$ix]
    m <- round(c(leaf$matrix[1:2, ]), 12) + 0
    paste(xml2::xml_name(leaf$node), paste(names(a), a, sep = "=", collapse = "\037"),
          xml2::xml_text(leaf$node), paste(sprintf("%.12f", m), collapse = ","), sep = "\036")
  }, "")
}

# Visible leaf indices (1 based) removed from a layout preserving probe. A
# valid `hide` probe is the final leaf sequence with entries deleted, so it
# is matched as a subsequence, which keeps repeated glyphs in order.
typst_hidden_leaf_indices <- function(visible, probe) {
  hidden <- integer()
  j <- 1L
  for (i in seq_along(visible)) {
    if (j <= length(probe) && identical(visible[[i]], probe[[j]])) j <- j + 1L else hidden <- c(hidden, i)
  }
  if (j != length(probe) + 1L) {
    stop("The MathTypst grouping probe changed visible SVG geometry instead of only hiding captured leaves. ",
         "A custom Typst show rule for `hide` may be interfering with subexpression selection.", call. = FALSE)
  }
  hidden
}

# Replace `{{ ... }}` groups with `manimgrp(...)` calls. Returns the
# processed expression and the group labels in source opening order.
typst_preprocess_groups <- function(math_expr) {
  labels <- character()
  auto_index <- 0L
  process <- function(chars) {
    result <- character()
    i <- 1L
    n <- length(chars)
    in_string <- FALSE
    bracket_depth <- 0L
    while (i <= n) {
      ch <- chars[i]
      if (in_string) {
        result <- c(result, ch)
        if (ch == "\\" && i + 1L <= n) {
          result <- c(result, chars[i + 1L])
          i <- i + 2L
          next
        }
        if (ch == "\"") in_string <- FALSE
        i <- i + 1L
        next
      }
      if (ch == "\"") {
        in_string <- TRUE
        result <- c(result, ch)
        i <- i + 1L
        next
      }
      if (ch == "[") {
        bracket_depth <- bracket_depth + 1L
        result <- c(result, ch)
        i <- i + 1L
        next
      }
      if (ch == "]" && bracket_depth > 0L) {
        bracket_depth <- bracket_depth - 1L
        result <- c(result, ch)
        i <- i + 1L
        next
      }
      if (bracket_depth > 0L || i + 1L > n || ch != "{" || chars[i + 1L] != "{") {
        result <- c(result, ch)
        i <- i + 1L
        next
      }
      group_start <- i
      i <- i + 2L
      content_start <- i
      depth <- 1L
      g_string <- FALSE
      g_bracket <- 0L
      content <- NULL
      while (i <= n && depth > 0L) {
        ch <- chars[i]
        if (g_string) {
          if (ch == "\\" && i + 1L <= n) {
            i <- i + 2L
            next
          }
          if (ch == "\"") g_string <- FALSE
          i <- i + 1L
          next
        }
        if (ch == "\"") {
          g_string <- TRUE
        } else if (ch == "[") {
          g_bracket <- g_bracket + 1L
        } else if (ch == "]" && g_bracket > 0L) {
          g_bracket <- g_bracket - 1L
        } else if (g_bracket == 0L && i + 1L <= n && paste0(ch, chars[i + 1L]) %in% c("{{", "}}")) {
          depth <- depth + (if (ch == "{") 1L else -1L)
          if (depth == 0L) content <- paste(chars[seq_len(i - content_start) + content_start - 1L], collapse = "")
          i <- i + 2L
          next
        }
        i <- i + 1L
      }
      if (is.null(content)) {
        # Unterminated group: keep the rest verbatim.
        return(paste(c(result, chars[group_start:n]), collapse = ""))
      }
      m <- regmatches(content, regexec(TYPST_LABEL_RE, content, perl = TRUE))[[1]]
      if (length(m)) {
        body <- trimws(m[2], whitespace = "\\s")
        label <- m[3]
      } else {
        body <- trimws(content, whitespace = "\\s")
        label <- paste0("_grp-", auto_index)
        auto_index <<- auto_index + 1L
      }
      # Record the outer capture before processing its body, preserving
      # source opening order for nested groups.
      labels <<- c(labels, label)
      result <- c(result, paste0("manimgrp(\"", label, "\", ", process(strsplit(body, "")[[1]]), ")"))
    }
    paste(result, collapse = "")
  }
  processed <- process(strsplit(enc2utf8(math_expr), "")[[1]])
  list(processed = processed, labels = labels)
}

svg_matrix_rank <- function(X) {
  s <- svd(X, 0, 0)$d
  sum(s > max(s) * max(dim(X)) * .Machine$double.eps)
}

#' @title Typst and MathTypst
#' @description Text and formulas typeset by the [Typst](https://typst.app)
#'   compiler and imported as vectorized mobjects. `Typst()` takes general
#'   Typst markup; `MathTypst()` wraps its input in display math
#'   (`$ ... $`). The `typst` command line compiler must be installed (see
#'   [typst_to_svg_file()]).
#' @details Typst renders in black; black parts take `color` while explicitly
#'   colored parts keep their color. Stroked parts drawn by Typst (fraction
#'   bars, underlines) keep a stroke width proportional to their size when
#'   `stroke_width` is `NULL`.
#'
#'   Parts can be selected with `$select(key)`, which returns a [VGroup()] of
#'   the submobjects (not copies). Labels come from ordinary Typst labels
#'   (`#box[body] <label>`) or, in `MathTypst()`, from the `{{ ... }}`
#'   shorthand: `{{ content : label }}` names a group and `{{ content }}` is
#'   numbered automatically, so `$select(1)` is the first unnamed group
#'   (internally labeled `_grp-0`). Groups may be nested. Unlike upstream
#'   Manim, numeric keys are 1 based.
#'
#'   With `track_baselines = TRUE`, `$baseline_frames` lists the current
#'   `(orig, right, up)` points of each imported element's reference frame
#'   and `$get_baseline_frame(submobject)` returns one of them; both follow
#'   later affine transformations. As in upstream Manim, the reference frame
#'   is the SVG page frame (origin at the top left corner, one Typst point
#'   per unit).
#' @param typst_code Typst markup placed verbatim into the document body.
#' @param math_expression Typst math without the `$` delimiters; may contain
#'   `{{ ... }}` groups.
#' @param font_size Font size (48 by default), applied by scaling after import.
#' @param typst_preamble Extra Typst code inserted before the body.
#' @param color Color for the parts Typst draws in black (white by default).
#' @param stroke_width Stroke width override; `NULL` keeps Typst's strokes.
#' @param font_paths Optional extra font directories for the compiler.
#' @param track_baselines Keep per element baseline frames.
#' @param should_center Center the result at the origin.
#' @param height,width Optional target size; `height` overrides `font_size`.
#' @param ... Passed to [SVGMobject()] (style overrides such as `opacity`).
#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @name typst
#' @examples
#' \dontrun{
#' # Needs the typst compiler.
#' Typst("*Hello* from _Typst!_", font_size = 72)
#' eq <- MathTypst("{{ a^2 + b^2 : lhs }} = {{ c^2 }}")
#' eq$select("lhs")$set_color(BLUE)
#' eq$select(1)$set_color(YELLOW)
#' }
NULL

#' @rdname typst
#' @format NULL
#' @usage NULL
#' @export
TypstClass <- R6::R6Class("Typst", inherit = SVGMobjectClass, lock_objects = FALSE,
  public = list(
    typst_code = NULL,
    typst_preamble = "",
    track_baselines = FALSE,
    initial_height = NULL,
    preserve_svg_stroke_widths = TRUE,
    stroke_width_tracked = NULL,
    baseline_tracked = NULL,
    label_aliases = NULL,
    svg_leaf_labels = NULL,
    initialize = function(typst_code, font_size = DEFAULT_FONT_SIZE, typst_preamble = "", color = NULL,
                          stroke_width = NULL, font_paths = NULL, track_baselines = FALSE,
                          should_center = TRUE, height = NULL, width = NULL, ...) {
      self$typst_code <- typst_code
      self$typst_preamble <- typst_preamble
      self$track_baselines <- track_baselines
      self$preserve_svg_stroke_widths <- is.null(stroke_width)
      self$stroke_width_tracked <- list()
      self$baseline_tracked <- list()
      self$label_aliases <- list()
      self$svg_leaf_labels <- self$svg_leaf_labels %||% list()
      file <- typst_to_svg_file(typst_code, preamble = typst_preamble, font_paths = font_paths)
      super$initialize(file_name = file, should_center = should_center, height = NULL, width = NULL,
                       stroke_width = stroke_width, color = NULL, ...)
      if (!is.null(height)) self$height <- height
      if (!is.null(width)) self$width <- width
      self$rebuild_label_aliases()
      self$refresh_svg_stroke_widths()
      self$color <- manim_color(color %||% "#FFFFFF")
      self$init_colors()
      self$initial_height <- self$height
      if (is.null(height)) self$font_size <- font_size
    },
    hash_seed = function() c(super$hash_seed(), list(self$track_baselines)),
    print = function(...) {
      cat(class(self)[1], "(", encodeString(self$typst_code, quote = "'"), ")\n", sep = "")
      invisible(self)
    },
    # Edit the Typst SVG before parsing (upstream modify_xml_tree): wrap
    # MathTypst capture leaves in identified groups and promote
    # data-typst-label attributes to ids. The result is written next to the
    # Typst output under a hash of its content.
    init_svg_mobject = function(file_name = self$file_name, use_svg_cache = TRUE) {
      doc <- xml2::read_xml(file_name, options = "HUGE")
      counts <- list()
      next_svg_id <- function(label) {
        k <- counts[[label]] %||% 0L
        counts[[label]] <<- k + 1L
        if (k == 0L) label else paste0(label, TYPST_DUPLICATE_LABEL_SUFFIX, k)
      }
      leaves <- typst_svg_leaves(xml2::xml_root(doc))
      for (i in seq_along(leaves)) {
        node <- leaves[[i]]$node
        for (label in rev(self$svg_leaf_labels[[as.character(i)]])) {
          xml2::xml_add_parent(node, "g", id = next_svg_id(label))
          node <- xml2::xml_parent(node)
        }
      }
      labeled <- xml2::xml_find_all(doc, "//*[@data-typst-label]")
      for (el in labeled) {
        xml2::xml_attr(el, "id") <- next_svg_id(xml2::xml_attr(el, "data-typst-label"))
        xml2::xml_attr(el, "data-typst-label") <- NULL
      }
      file <- file_name
      if (length(self$svg_leaf_labels) || length(labeled)) {
        txt <- as.character(doc)
        file <- file.path(dirname(file_name), paste0(typst_hash(txt), ".manim.svg"))
        if (!file.exists(file)) writeBin(charToRaw(enc2utf8(txt)), file)
      }
      super$init_svg_mobject(file, use_svg_cache = use_svg_cache)
      self$track_svg_submobjects()
      invisible(self)
    },
    # Record reference data on the freshly imported (flipped, not yet
    # centered or scaled) submobjects, as upstream get_mob_from_shape_element.
    track_svg_submobjects = function() {
      for (sm in self$submobjects) {
        if (!self$preserve_svg_stroke_widths || !sm$has_points() || sm$get_stroke_width() <= 0) next
        ref <- max(sm$width, sm$height)
        if (ref <= 0) next
        sm$typst_reference_size <- ref
        sm$typst_source_stroke_width <- sm$get_stroke_width()
        self$stroke_width_tracked[[length(self$stroke_width_tracked) + 1L]] <- sm
      }
      if (!self$track_baselines) return(invisible(self))
      # Upstream's svgelements parse bakes every transform into the path data,
      # so each element's reference frame is the SVG page frame (0, 0), (1, 0),
      # (0, 1). The import flipped y about the center: map the frame likewise.
      cy <- self$get_center()[2]
      frame <- cbind(c(0, 1, 0), 2 * cy - c(0, 0, 1), 0)
      for (sm in self$submobjects) {
        if (!sm$has_points()) next
        p <- sm$points
        if (svg_matrix_rank(cbind(p[, 1], p[, 2], 1)) < 3) next
        sm$typst_reference_points <- p
        sm$typst_reference_baseline_frame <- frame
        self$baseline_tracked[[length(self$baseline_tracked) + 1L]] <- sm
      }
      invisible(self)
    },
    scale = function(scale_factor, scale_stroke = FALSE, about_point = NULL, about_edge = NULL, ...) {
      super$scale(scale_factor, scale_stroke = scale_stroke, about_point = about_point, about_edge = about_edge, ...)
      self$refresh_svg_stroke_widths()
      invisible(self)
    },
    # SVG stroke widths are in SVG units while Manim stroke widths are pixel
    # based; rescale Typst authored strokes with the geometry they belong to.
    refresh_svg_stroke_widths = function() {
      if (!self$preserve_svg_stroke_widths) return(invisible(self))
      pixels_per_unit <- cfg("pixel_width") / frame_width()
      for (sm in self$stroke_width_tracked) {
        ref <- sm$typst_reference_size
        if (is.null(ref) || ref <= 0) next
        current <- sm$typst_source_stroke_width * max(sm$width, sm$height) / ref
        sm$set_stroke(width = current * pixels_per_unit * TYPST_SVG_STROKE_WIDTH_SCALE, family = FALSE)
      }
      invisible(self)
    },
    get_baseline_frame = function(submobject) {
      ref <- submobject$typst_reference_points
      frame <- submobject$typst_reference_baseline_frame
      if (is.null(ref) || is.null(frame)) {
        stop("No tracked Typst baseline frame is available for this submobject. ",
             "Construct the Typst mobject with track_baselines = TRUE.", call. = FALSE)
      }
      X <- cbind(ref[, 1], ref[, 2], 1)
      if (svg_matrix_rank(X) < 3) {
        stop("The stored Typst reference geometry is degenerate, so its baseline frame cannot be recovered.",
             call. = FALSE)
      }
      tr <- qr.coef(qr(X), submobject$points)
      cur <- cbind(frame[, 1], frame[, 2], 1) %*% tr
      list(orig = unname(cur[1, ]), right = unname(cur[2, ]), up = unname(cur[3, ]))
    },
    rebuild_label_aliases = function() {
      aliases <- list()
      for (key in names(self$id_to_vgroup_dict)) {
        if (key == "root" || startsWith(key, "numbered_group_") || grepl("^g[0-9A-Fa-f]+$", key)) next
        pos <- regexpr(TYPST_DUPLICATE_LABEL_SUFFIX, key, fixed = TRUE)
        base <- if (pos > 0) substr(key, 1, pos - 1) else key
        aliases[[base]] <- c(aliases[[base]], key)
      }
      self$label_aliases <- aliases
      invisible(self)
    },
    user_label_keys = function() names(self$label_aliases) %||% character(),
    select = function(key) {
      if (is.numeric(key)) {
        label <- paste0("_grp-", key - 1)
        if (!label %in% self$user_label_keys()) {
          stop("Group index ", key, " out of range. Available labels: ",
               paste(self$user_label_keys(), collapse = ", "), call. = FALSE)
        }
        key <- label
      }
      if (!key %in% self$user_label_keys()) {
        stop("No group with label '", key, "' found. Available labels: ",
             paste(self$user_label_keys(), collapse = ", "), call. = FALSE)
      }
      result <- VGroup()
      seen <- character()
      for (group_id in self$label_aliases[[key]]) {
        for (sm in self$id_to_vgroup_dict[[group_id]]$submobjects) {
          if (sm$mob_id %in% seen) next
          seen <- c(seen, sm$mob_id)
          result$add(sm)
        }
      }
      result
    },
    # Typst renders in black: recolor black submobjects to self$color and
    # keep explicitly colored ones.
    init_colors = function(propagate_colors = TRUE) {
      if (length(self$submobjects) == 0) return(super$init_colors(propagate_colors))
      for (sm in self$submobjects) {
        if (toupper(sm$get_color()) != "#000000") next
        sm$set_color(self$color)
        sm$init_colors(propagate_colors)
      }
      invisible(self)
    }
  ),
  active = list(
    font_size = function(value) {
      cur <- if (is.null(self$initial_height) || self$initial_height == 0) 0
        else self$height / self$initial_height / SCALE_FACTOR_PER_FONT_POINT
      if (missing(value)) return(cur)
      if (value <= 0) stop("font_size must be greater than 0.", call. = FALSE)
      if (self$height > 0) self$scale(value / cur)
    },
    baseline_frames = function(value) {
      if (!missing(value)) stop("baseline_frames is read only.", call. = FALSE)
      if (!self$track_baselines) return(list())
      lapply(self$baseline_tracked, self$get_baseline_frame)
    }
  )
)

#' @rdname typst
#' @export
Typst <- constructor(TypstClass)

#' @rdname typst
#' @format NULL
#' @usage NULL
#' @export
MathTypstClass <- R6::R6Class("MathTypst", inherit = TypstClass, lock_objects = FALSE,
  public = list(
    group_labels = NULL,
    initialize = function(math_expression, typst_preamble = "", font_paths = NULL, ...) {
      pre <- typst_preprocess_groups(math_expression)
      self$group_labels <- pre$labels
      typst_code <- paste0("$ ", pre$processed, " $")
      distinct_labels <- unique(pre$labels)
      with_user <- function(p) if (nzchar(typst_preamble)) paste0(p, "\n", typst_preamble) else p
      if (length(distinct_labels)) {
        final_preamble <- with_user(typst_manimgrp_preamble(NULL))
        final_svg <- typst_to_svg_file(typst_code, preamble = final_preamble, font_paths = font_paths)
        visible <- typst_svg_leaf_signatures(final_svg)
        leaf_labels <- list()
        for (label in distinct_labels) {
          probe_svg <- typst_to_svg_file(typst_code, preamble = with_user(typst_manimgrp_preamble(label)),
                                         font_paths = font_paths)
          hidden <- tryCatch(
            typst_hidden_leaf_indices(visible, typst_svg_leaf_signatures(probe_svg)),
            error = function(e) {
              stop("Could not map MathTypst group '", label, "' to SVG leaves. ", conditionMessage(e), call. = FALSE)
            }
          )
          for (i in hidden) leaf_labels[[as.character(i)]] <- c(leaf_labels[[as.character(i)]], label)
        }
        self$svg_leaf_labels <- leaf_labels
        typst_preamble <- final_preamble
      }
      super$initialize(typst_code, typst_preamble = typst_preamble, font_paths = font_paths, ...)
      for (label in setdiff(distinct_labels, self$user_label_keys())) self$label_aliases[label] <- list(character())
    }
  )
)

#' @rdname typst
#' @export
MathTypst <- constructor(MathTypstClass)
