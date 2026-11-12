# Text rendered from system fonts. Glyphs are shaped with textshaping and
# outlined with systemfonts, replacing manim's Pango + SVG pipeline
# (manim/mobject/text/text_mobject.py).

TEXT_MOB_SCALE_FACTOR <- 0.05
TEXT2SVG_ADJUSTMENT_FACTOR <- 4.8
DEFAULT_LINE_SPACING_SCALE <- 0.3
GLYPH_SHAPE_SIZE <- 100
GLYPH_TOLERANCE <- 0.1

no_ligatures <- function() structure(list(c("liga", "clig"), c(0L, 0L)), class = "font_feature")

weight_name <- function(w) {
  w <- tolower(as.character(w %||% "normal"))
  map <- c(normal = "normal", thin = "thin", ultralight = "ultralight", light = "light", semilight = "light",
           book = "normal", medium = "medium", semibold = "semibold", bold = "bold", ultrabold = "ultrabold",
           heavy = "heavy", ultraheavy = "heavy")
  if (w %in% names(map)) map[[w]] else "normal"
}

is_italic <- function(slant) toupper(as.character(slant %||% "NORMAL")) %in% c("ITALIC", "OBLIQUE")

# Outline of one glyph at GLYPH_SHAPE_SIZE points as a 4k x 3 cubic point
# matrix (straight segments), cached per font and glyph.
glyph_points <- function(index, path, font_index) {
  key <- paste(path, font_index, index, sep = "|")
  if (is.null(.manim$glyph_cache)) .manim$glyph_cache <- new.env(parent = emptyenv())
  hit <- .manim$glyph_cache[[key]]
  if (!is.null(hit)) return(hit)
  o <- systemfonts::glyph_outline(index, path, font_index, size = GLYPH_SHAPE_SIZE, tolerance = GLYPH_TOLERANCE)
  pts <- matrix(0, 0, 3)
  if (nrow(o)) {
    parts <- lapply(split(o, o$contour), function(cn) {
      p <- cbind(cn$x, cn$y, 0)
      n <- nrow(p)
      if (n > 1 && all(abs(p[1, ] - p[n, ]) < 1e-9)) p <- p[-n, , drop = FALSE]
      if (nrow(p) < 2) return(NULL)
      a1 <- p
      a2 <- p[c(2:nrow(p), 1), , drop = FALSE]
      interleave_curves(a1, interpolate(a1, a2, 1 / 3), interpolate(a1, a2, 2 / 3), a2)
    })
    pts <- do.call(rbind, parts)
  }
  assign(key, pts, envir = .manim$glyph_cache)
  pts
}

# Shape styled runs into glyph VMobjects. `runs` is a list of lists with
# fields text, family, weight, italic, color (or NULL). Returns a list of
# glyph mobjects with fields char_index (1 based in the full string) and char.
shape_runs <- function(runs, line_pitch = 97.5, disable_ligatures = TRUE, tab_width = 4) {
  # Split runs at newlines so each line is shaped on its own and baselines
  # sit exactly `line_pitch` shaping units apart, like Pango's line spacing.
  pieces <- list()
  line <- 1L
  pos <- 0L
  for (r in runs) {
    txt <- gsub("\t", strrep(" ", tab_width), r$text, fixed = TRUE)
    parts <- strsplit(txt, "\n", fixed = TRUE)[[1]]
    if (endsWith(txt, "\n")) parts <- c(parts, "")
    if (!length(parts)) parts <- ""
    for (k in seq_along(parts)) {
      if (k > 1) {
        line <- line + 1L
        pos <- pos + 1L
      }
      if (nzchar(parts[k])) pieces[[length(pieces) + 1]] <- c(r, list(piece = parts[k], line = line, start = pos))
      pos <- pos + nchar(parts[k])
    }
  }
  feats <- if (disable_ligatures) no_ligatures() else systemfonts::font_feature()
  glyphs <- list()
  for (ln in unique(vapply(pieces, `[[`, 1L, "line"))) {
    lp <- Filter(function(p) p$line == ln, pieces)
    strings <- vapply(lp, `[[`, "", "piece")
    fams <- vapply(lp, function(r) r$family %||% "", "")
    fams[fams == ""] <- "sans"
    weights <- vapply(lp, function(r) weight_name(r$weight), "")
    italics <- vapply(lp, function(r) isTRUE(r$italic), logical(1))
    sizes <- vapply(lp, function(r) (r$size_scale %||% 1) * GLYPH_SHAPE_SIZE, 0)
    sh <- textshaping::shape_text(strings, id = rep(1L, length(strings)), family = fams, italic = italics,
                                  weight = weights, size = sizes, res = 72, features = feats)$shape
    # textshaping's glyph column indexes the concatenated strings of a line.
    line_text <- paste(strings, collapse = "")
    for (i in seq_len(nrow(sh))) {
      row <- sh[i, ]
      pts <- glyph_points(row$index, row$font_path, row$font_index)
      if (nrow(pts) == 0) next
      pts <- pts * (row$font_size / GLYPH_SHAPE_SIZE)
      run <- lp[[row$string_id]]
      pts[, 1] <- pts[, 1] + row$x_offset
      pts[, 2] <- pts[, 2] - (ln - 1) * line_pitch + (run$baseline_shift %||% 0) * GLYPH_SHAPE_SIZE
      v <- VMobjectClass$new()
      v$points <- pts
      v$char_index <- lp[[1]]$start + row$glyph
      v$char <- substr(line_text, row$glyph, row$glyph)
      v$line_index <- ln
      v$run_color <- run$color
      v$run_opacity <- run$opacity
      v$run_underline <- isTRUE(run$underline)
      v$run_strike <- isTRUE(run$strike)
      v$run_gradient <- run$gradient
      v$run_gradient_id <- run$gradient_id
      v$baseline_y <- -(ln - 1) * line_pitch
      glyphs[[length(glyphs) + 1]] <- v
    }
  }
  glyphs
}

# Positions of all occurrences of `pattern` (fixed) or a "[a:b]" slice in text.
find_text_ranges <- function(text, key) {
  m <- regmatches(key, regexec("^\\[(-?\\d*):(-?\\d*)\\]$", key))[[1]]
  n <- nchar(text)
  if (length(m)) {
    a <- if (nzchar(m[2])) as.integer(m[2]) else 0L
    b <- if (nzchar(m[3])) as.integer(m[3]) else n
    if (a < 0) a <- n + a
    if (b < 0) b <- n + b
    a <- max(0L, min(a, n))
    b <- max(0L, min(b, n))
    if (b <= a) return(list())
    return(list(c(a + 1L, b)))
  }
  hits <- gregexpr(key, text, fixed = TRUE)[[1]]
  if (hits[1] == -1) return(list())
  lapply(hits, function(h) c(h, h + nchar(key) - 1L))
}

#' @title Text
#' @description Text rendered from system fonts as vectorized glyphs. Each
#'   glyph is a submobject, so `text[1]` is the first visible character and
#'   [Write()] or [AddTextLetterByLetter()] animate letter by letter.
#' @param text The string. Newlines start new lines.
#' @param fill_opacity,stroke_width Style; text is filled by default.
#' @param color Color.
#' @param font_size Font size; 48 matches Manim's default.
#' @param line_spacing Line height multiplier.
#' @param font Font family, for example `"serif"`, `"mono"` or an installed font name.
#' @param slant `"NORMAL"`, `"ITALIC"` or `"OBLIQUE"`.
#' @param weight `"NORMAL"`, `"BOLD"` and so on.
#' @param t2c,t2f,t2s,t2w,t2g Named lists mapping substrings (or slices like
#'   `"[1:4]"`, 0 based as in Manim) to colors, fonts, slants, weights, or
#'   gradients.
#' @param gradient Colors for a gradient across the glyphs.
#' @param tab_width Spaces per tab.
#' @param height,width Optional target size.
#' @param should_center Center the text at the origin.
#' @param disable_ligatures Keep one glyph per character (default `TRUE`).
#' @param markup Parse `text` as Pango style markup, as [MarkupText()] does.
#' @param ... Passed to [VMobject()].
#' @export
#' @examples
#' Text("Hello manimR", color = BLUE)
TextClass <- R6::R6Class("Text", inherit = VMobjectClass, lock_objects = FALSE,
  public = list(
    text = NULL,
    original_text = NULL,
    initial_font_size = DEFAULT_FONT_SIZE,
    initial_height = NULL,
    font = "",
    initialize = function(text, fill_opacity = 1, stroke_width = 0, color = "#FFFFFF", font_size = DEFAULT_FONT_SIZE,
                          line_spacing = -1, font = "", slant = "NORMAL", weight = "NORMAL", t2c = NULL, t2f = NULL,
                          t2g = NULL, t2s = NULL, t2w = NULL, gradient = NULL, tab_width = 4, height = NULL,
                          width = NULL, should_center = TRUE, disable_ligatures = TRUE, markup = FALSE, ...) {
      text <- paste(text, collapse = "")
      self$original_text <- text
      self$font <- font
      self$initial_font_size <- font_size
      super$initialize(color = color, fill_opacity = fill_opacity, stroke_width = stroke_width, ...)
      if (markup) {
        runs <- parse_markup(text, font, weight, slant, font_size)
        for (k in seq_along(runs)) runs[[k]]$text <- gsub("\t", strrep(" ", tab_width), runs[[k]]$text, fixed = TRUE)
        text <- paste(vapply(runs, `[[`, "", "text"), collapse = "")
      } else {
        # Expand tabs before shaping so glyph indices match self$text.
        text <- gsub("\t", strrep(" ", tab_width), text, fixed = TRUE)
        runs <- self$build_runs(text, font, slant, weight, t2f, t2s, t2w)
      }
      self$text <- text
      # Upstream sets the baseline pitch to (1 + line_spacing) * font_size / 96
      # scene units (line_spacing defaults to 0.3); in shaping units that is
      # (1 + line_spacing) * 75 at GLYPH_SHAPE_SIZE.
      ls <- if (line_spacing == -1) DEFAULT_LINE_SPACING_SCALE else line_spacing
      glyphs <- shape_runs(runs, line_pitch = (1 + ls) * GLYPH_SHAPE_SIZE * 72 / 96,
                           disable_ligatures = disable_ligatures, tab_width = tab_width)
      # manimpango renders points that svgelements reads at 96 ppi, so one em
      # is font_size / 72 scene units, matching upstream Text sizes.
      glyphs <- c(glyphs, text_decorations(glyphs))
      em <- font_size / 72
      for (g in glyphs) {
        g$points <- g$points * (em / GLYPH_SHAPE_SIZE)
        g$set_style(fill_color = g$run_color %||% color, fill_opacity = (g$run_opacity %||% 1) * fill_opacity,
                    stroke_color = g$run_color %||% color, stroke_width = stroke_width)
      }
      self$add(glyphs)
      if (!is.null(gradient)) self$set_color_by_gradient(gradient)
      gids <- unique(unlist(lapply(glyphs, function(g) g$run_gradient_id)))
      for (gid in gids) {
        members <- Filter(function(g) identical(g$run_gradient_id, gid), glyphs)
        do.call(VGroup, members)$set_color_by_gradient(members[[1]]$run_gradient)
      }
      self$apply_t2c(t2c)
      self$apply_t2g(t2g)
      if (should_center && length(glyphs)) self$center()
      if (!is.null(height)) self$scale_to_fit_height(height)
      if (!is.null(width)) self$scale_to_fit_width(width)
      self$initial_height <- self$height
    },
    build_runs = function(text, font, slant, weight, t2f, t2s, t2w) {
      n <- nchar(text)
      if (n == 0) return(list(list(text = "", family = font, weight = weight, italic = is_italic(slant))))
      fam <- rep(font, n); wt <- rep(as.character(weight), n); it <- rep(is_italic(slant), n)
      for (k in names(t2f)) for (r in find_text_ranges(text, k)) fam[r[1]:r[2]] <- t2f[[k]]
      for (k in names(t2s)) for (r in find_text_ranges(text, k)) it[r[1]:r[2]] <- is_italic(t2s[[k]])
      for (k in names(t2w)) for (r in find_text_ranges(text, k)) wt[r[1]:r[2]] <- as.character(t2w[[k]])
      key <- paste(fam, wt, it)
      starts <- c(1, which(key[-1] != key[-n]) + 1)
      ends <- c(starts[-1] - 1, n)
      lapply(seq_along(starts), function(i) {
        list(text = substr(text, starts[i], ends[i]), family = fam[starts[i]], weight = wt[starts[i]],
             italic = it[starts[i]])
      })
    },
    glyphs_for_range = function(a, b) {
      Filter(function(g) !is.null(g$char_index) && g$char_index >= a && g$char_index <= b, self$submobjects)
    },
    apply_t2c = function(t2c) {
      for (k in names(t2c)) {
        for (r in find_text_ranges(self$text, k)) {
          for (g in self$glyphs_for_range(r[1], r[2])) g$set_color(t2c[[k]])
        }
      }
      invisible(self)
    },
    apply_t2g = function(t2g) {
      for (k in names(t2g)) {
        for (r in find_text_ranges(self$text, k)) {
          gl <- self$glyphs_for_range(r[1], r[2])
          if (length(gl)) do.call(VGroup, gl)$set_color_by_gradient(t2g[[k]])
        }
      }
      invisible(self)
    },
    get_part_by_text = function(substring) {
      r <- find_text_ranges(self$text, substring)
      if (!length(r)) return(NULL)
      do.call(VGroup, self$glyphs_for_range(r[[1]][1], r[[1]][2]))
    }
  ),
  active = list(
    font_size = function(value) {
      cur <- if (is.null(self$initial_height) || self$initial_height == 0) self$initial_font_size
        else self$height / self$initial_height * self$initial_font_size
      if (missing(value)) return(cur)
      if (value <= 0) stop("font_size must be greater than 0.", call. = FALSE)
      self$scale(value / cur)
    }
  )
)

#' @rdname TextClass
#' @export
Text <- constructor(TextClass)
# Parse a Pango style markup subset into styled runs.
PANGO_SIZE_KEYWORDS <- c(`xx-small` = 1 / 1.2^3, `x-small` = 1 / 1.2^2, small = 1 / 1.2, medium = 1,
                         large = 1.2, `x-large` = 1.2^2, `xx-large` = 1.2^3)

parse_markup <- function(markup, font, weight, slant, font_size = DEFAULT_FONT_SIZE) {
  doc <- xml2::read_xml(paste0("<markup>", markup, "</markup>"), options = "HUGE")
  runs <- list()
  group_id <- 0L
  # manimpango renders at font_size / 4.8 points, so Pango sizes in 1/1024
  # points are relative to that.
  base_pt <- font_size / TEXT2SVG_ADJUSTMENT_FACTOR
  walk <- function(node, style) {
    for (ch in xml2::xml_contents(node)) {
      if (xml2::xml_type(ch) == "text") {
        txt <- xml2::xml_text(ch)
        if (nzchar(txt)) runs[[length(runs) + 1]] <<- c(list(text = txt), style)
        next
      }
      s <- style
      tag <- tolower(xml2::xml_name(ch))
      a <- xml2::xml_attrs(ch)
      if (tag %in% c("b", "strong")) s$weight <- "BOLD"
      if (tag %in% c("i", "em")) s$italic <- TRUE
      if (tag == "tt") s$family <- "mono"
      if (tag == "u") s$underline <- TRUE
      if (tag == "s") s$strike <- TRUE
      if (tag == "big") s$size_scale <- (s$size_scale %||% 1) * 1.2
      if (tag == "small") s$size_scale <- (s$size_scale %||% 1) / 1.2
      if (tag == "sup") { s$size_scale <- (s$size_scale %||% 1) * 0.6; s$baseline_shift <- (s$baseline_shift %||% 0) + 0.35 }
      if (tag == "sub") { s$size_scale <- (s$size_scale %||% 1) * 0.6; s$baseline_shift <- (s$baseline_shift %||% 0) - 0.15 }
      # Manim's legacy tags take Manim color names.
      if (tag == "color" && !is.null(a[["col"]])) s$color <- manim_color(a[["col"]])
      if (tag == "gradient") {
        group_id <<- group_id + 1L
        s$gradient <- c(manim_color(a[["from"]] %||% "#FFFFFF"), manim_color(a[["to"]] %||% "#FFFFFF"))
        s$gradient_id <- group_id
      }
      for (nm in names(a)) {
        v <- a[[nm]]
        if (nm %in% c("foreground", "fgcolor") || (nm == "color" && tag != "color")) {
          cc <- css_color(v)
          if (is.list(cc)) s$color <- cc$color
        }
        if (nm %in% c("font", "font_family", "face")) s$family <- v
        if (nm %in% c("weight", "font_weight")) s$weight <- v
        if (nm %in% c("style", "font_style")) s$italic <- is_italic(v)
        if (nm %in% c("fgalpha", "alpha")) s$opacity <- as.numeric(sub("%", "", v)) / (if (grepl("%", v)) 100 else 65535)
        if (nm %in% c("underline")) s$underline <- !identical(v, "none")
        if (nm %in% c("strikethrough")) s$strike <- identical(v, "true")
        if (nm %in% c("size", "font_size")) {
          if (v %in% names(PANGO_SIZE_KEYWORDS)) s$size_scale <- PANGO_SIZE_KEYWORDS[[v]]
          else if (v == "larger") s$size_scale <- (s$size_scale %||% 1) * 1.2
          else if (v == "smaller") s$size_scale <- (s$size_scale %||% 1) / 1.2
          else if (grepl("pt$", v)) s$size_scale <- as.numeric(sub("pt$", "", v)) / base_pt
          else if (!is.na(suppressWarnings(as.numeric(v)))) s$size_scale <- as.numeric(v) / 1024 / base_pt
        }
      }
      walk(ch, s)
    }
  }
  walk(xml2::xml_root(doc), list(family = font, weight = weight, italic = is_italic(slant)))
  runs
}

# Underline and strikethrough bars for glyphs whose run asked for them,
# in shaping units (before scaling to scene units).
text_decorations <- function(glyphs) {
  out <- list()
  for (kind in c("underline", "strike")) {
    flag <- if (kind == "underline") "run_underline" else "run_strike"
    sel <- Filter(function(g) isTRUE(g[[flag]]), glyphs)
    if (!length(sel)) next
    ord <- order(vapply(sel, function(g) g$char_index, 0))
    sel <- sel[ord]
    groups <- list()
    cur <- list(sel[[1]])
    if (length(sel) > 1) {
      for (k in 2:length(sel)) {
        prev <- cur[[length(cur)]]
        g <- sel[[k]]
        if (identical(g$line_index, prev$line_index) && g$char_index - prev$char_index <= 2) cur[[length(cur) + 1]] <- g
        else { groups[[length(groups) + 1]] <- cur; cur <- list(g) }
      }
    }
    groups[[length(groups) + 1]] <- cur
    for (grp in groups) {
      pts <- do.call(rbind, lapply(grp, function(g) g$points))
      x0 <- min(pts[, 1]); x1 <- max(pts[, 1])
      y_ref <- min(vapply(grp, function(g) g$baseline_y %||% 0, 0))
      thick <- 0.05 * GLYPH_SHAPE_SIZE
      y <- if (kind == "underline") y_ref - 0.1 * GLYPH_SHAPE_SIZE else y_ref + 0.28 * GLYPH_SHAPE_SIZE
      bar <- VMobjectClass$new()
      bar$set_points_as_corners(rbind(c(x0, y, 0), c(x1, y, 0), c(x1, y - thick, 0), c(x0, y - thick, 0), c(x0, y, 0)))
      bar$run_color <- grp[[1]]$run_color
      bar$run_opacity <- grp[[1]]$run_opacity
      out[[length(out) + 1]] <- bar
    }
  }
  out
}

#' @title MarkupText
#' @description Text with inline Pango style markup. Supported tags: `<b>`,
#'   `<i>`, `<tt>`, `<big>`, `<small>`, `<sup>`, `<sub>`, and `<span>` with
#'   `foreground`/`color`, `font`/`font_family`, `weight`, `style`, `fgalpha`.
#' @param text Markup string.
#' @param ... Passed to [Text()].
#' @export
#' @examples
#' MarkupText("<b>bold</b> and <span foreground='red'>red</span>")
MarkupText <- constructor(MarkupTextClass)

#' @rdname MarkupText
#' @format NULL
#' @usage NULL
#' @export
MarkupTextClass <- R6::R6Class("MarkupText", inherit = TextClass, lock_objects = FALSE,
  public = list(
    initialize = function(text, ...) super$initialize(text, markup = TRUE, ...)
  )
)

#' @title Paragraph
#' @description Several lines of text, each a [Text()] in a VGroup.
#' @param ... Strings, one per line, then named arguments for [Text()].
#' @param line_spacing Line spacing multiplier.
#' @param alignment `"left"`, `"center"` or `"right"`.
#' @export
#' @examples
#' Paragraph("first line", "second line", alignment = "center")
Paragraph <- function(..., line_spacing = -1, alignment = NULL) {
  args <- list(...)
  nm <- names(args) %||% rep("", length(args))
  lines_str <- paste(unlist(args[nm == ""]), collapse = "\n")
  kw <- args[nm != ""]
  lines_text <- do.call(Text, c(list(lines_str, line_spacing = line_spacing), kw))
  n_lines <- length(strsplit(lines_str, "\n", fixed = TRUE)[[1]]) + endsWith(lines_str, "\n")
  n_lines <- max(n_lines, 1)
  g <- VGroup()
  class(g) <- c("Paragraph", class(g))
  for (ln in seq_len(n_lines)) {
    g$add(VGroup(Filter(function(m) identical(m$line_index, ln), lines_text$submobjects)))
  }
  g$lines_text <- lines_text
  g$lines_alignments <- rep(list(alignment), n_lines)
  g$move_to(ORIGIN)
  if (!is.null(alignment)) {
    alignment <- match.arg(alignment, c("left", "center", "right"))
    for (ln in seq_len(n_lines)) paragraph_align_line(g, alignment, ln)
  }
  g
}

paragraph_align_line <- function(g, alignment, line_no) {
  line <- g$submobjects[[line_no]]
  if (!line$has_points() && !length(line$family_members_with_points())) return(invisible(g))
  y <- line$get_center()[2]
  x <- switch(alignment,
    center = g$get_center()[1],
    right = g$get_right()[1] - line$width / 2,
    left = g$get_left()[1] + line$width / 2
  )
  line$move_to(c(x, y, 0))
  invisible(g)
}
