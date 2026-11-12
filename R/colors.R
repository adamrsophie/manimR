# Color helpers ported from manim/utils/color/core.py. Colors are hex strings.

manim_color_table <- function() {
  if (is.null(.manim$color_table)) {
    ns <- asNamespace("manimR")
    nms <- grep("^[A-Z][A-Z_]*$", ls(ns), value = TRUE)
    vals <- mget(nms, envir = ns)
    keep <- vapply(vals, function(v) is.character(v) && length(v) == 1 && grepl("^#[0-9A-F]{6}$", v), logical(1))
    tab <- unlist(vals[keep])
    names(tab) <- tolower(names(tab))
    .manim$color_table <- tab
  }
  .manim$color_table
}

#' Parse a color
#'
#' Accepts manim color names (case insensitive, e.g. `"blue_d"`), hex strings
#' with or without alpha, and any color R understands.
#'
#' @param color A color.
#' @return `manim_color()` returns an uppercase hex string. `color_to_rgb()`
#'   returns a numeric vector in `[0, 1]`; `color_to_rgba()` includes alpha.
#'   `rgb_to_color()` and `rgba_to_color()` return a [ManimColor()], which
#'   keeps the exact channel values (and alpha) and works as a hex string.
#' @export
#' @examples
#' manim_color("red")
#' color_to_rgb(BLUE)
manim_color <- function(color) {
  rgb_hex(color_to_rgba(color)[1:3])
}

#' @rdname manim_color
#' @export
color_to_rgb <- function(color) color_to_rgba(color)[1:3]

#' @rdname manim_color
#' @param alpha Opacity.
#' @export
color_to_rgba <- function(color, alpha = NULL) {
  if (inherits(color, "ManimColor")) {
    v <- attr(color, "rgba")
  } else if (is.numeric(color)) {
    v <- if (max(color) > 1) color / 255 else color
    if (length(v) == 3) v <- c(v, 1)
  } else {
    if (is.null(color) || length(color) == 0 || is.na(color)) color <- "#000000"
    # Hex written as 0xRRGGBB, as upstream's ManimColor accepts.
    if (grepl("^0[xX][0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$", color)) color <- sub("^0[xX]", "#", color)
    key <- tolower(color)
    tab <- manim_color_table()
    if (key %in% names(tab)) color <- tab[[key]]
    v <- as.numeric(grDevices::col2rgb(color, alpha = TRUE)) / 255
  }
  if (!is.null(alpha)) v[4] <- alpha
  v
}

#' @rdname manim_color
#' @param rgb,rgba Numeric vectors in `[0, 1]`.
#' @export
rgb_to_color <- function(rgb) new_manim_color(c(rgb[1:3], 1))

#' @rdname manim_color
#' @export
rgba_to_color <- function(rgba) new_manim_color(if (length(rgba) == 3) c(rgba, 1) else rgba[1:4])

# The hex string of RGB values in [0, 1], as ManimColor.to_hex(): it
# truncates int(x * 255); the epsilon keeps exact channel values such as
# 88 / 255 from dropping to 87.
rgb_hex <- function(rgb) {
  rgb <- pmin(pmax(rgb[1:3], 0), 1)
  v <- floor(rgb * 255 + 1e-6)
  sprintf("#%02X%02X%02X", v[1], v[2], v[3])
}

#' Color arithmetic
#'
#' @param color1,color2,color Colors.
#' @param alpha Interpolation parameter.
#' @export
#' @examples
#' interpolate_color(RED, BLUE, 0.5)
#' color_gradient(c(RED, YELLOW, GREEN), 5)
interpolate_color <- function(color1, color2, alpha) {
  # All four channels, as upstream's ManimColor.interpolate().
  new_manim_color(interpolate(color_to_rgba(color1), color_to_rgba(color2), alpha))
}

#' @rdname interpolate_color
#' @param reference_colors Colors to pass through.
#' @param length_of_output Number of colors to return.
#' @export
color_gradient <- function(reference_colors, length_of_output) {
  reference_colors <- unlist(reference_colors)
  if (length_of_output == 0) return(character())
  if (length(reference_colors) == 1) return(rep(manim_color(reference_colors), length_of_output))
  rgbs <- t(vapply(reference_colors, color_to_rgb, numeric(3)))
  alphas <- seq(0, length(reference_colors) - 1, length.out = length_of_output)
  floors <- floor(alphas)
  mod1 <- alphas %% 1
  mod1[length_of_output] <- 1
  floors[length_of_output] <- length(reference_colors) - 2
  vapply(seq_len(length_of_output), function(k) {
    i <- floors[k] + 1
    rgb_to_color(rgbs[i, ] * (1 - mod1[k]) + rgbs[i + 1, ] * mod1[k])
  }, character(1))
}

#' @rdname interpolate_color
#' @param ... Colors.
#' @export
average_color <- function(...) {
  cols <- unlist(list(...))
  rgb_to_color(colMeans(t(vapply(cols, color_to_rgb, numeric(3)))))
}

#' @rdname interpolate_color
#' @export
invert_color <- function(color) rgb_to_color(1 - color_to_rgb(color))

#' @rdname interpolate_color
#' @param blend Amount to blend toward white (`lighter_color`) or black (`darker_color`).
#' @export
lighter_color <- function(color, blend = 0.2) interpolate_color(color, "#FFFFFF", blend)

#' @rdname interpolate_color
#' @export
darker_color <- function(color, blend = 0.2) interpolate_color(color, "#000000", blend)

#' @rdname interpolate_color
#' @export
random_color <- function() {
  tab <- manim_color_table()
  unname(tab[sample.int(length(tab), 1)])
}

#' @rdname interpolate_color
#' @export
random_bright_color <- function() interpolate_color(random_color(), "#FFFFFF", 0.5)

# k x 4 matrix of rgba rows from colors and opacities, recycled to equal length.
rgbas_from <- function(color, opacity) {
  cols <- if (is.null(color)) list(NULL) else as.list(unlist(color))
  ops <- if (is.null(opacity)) list(NULL) else as.list(unlist(opacity))
  n <- max(length(cols), length(ops))
  cols <- rep_len(cols, n)
  ops <- rep_len(ops, n)
  out <- matrix(0, n, 4)
  for (i in seq_len(n)) {
    out[i, ] <- c(if (is.null(cols[[i]])) c(0, 0, 0) else color_to_rgb(cols[[i]]),
                  if (is.null(ops[[i]])) 0 else ops[[i]])
  }
  out
}

# Stretch rows of a matrix to a new length, like manim's stretch_array_to_length.
stretch_rows <- function(m, n) {
  cur <- nrow(m)
  if (cur == n) return(m)
  idx <- pmin(floor((0:(n - 1)) * cur / n) + 1, cur)
  m[idx, , drop = FALSE]
}

# Stretch a list or vector to length n by index repetition.
stretch_list <- function(x, n) {
  cur <- length(x)
  if (cur == n) return(x)
  x[pmin(floor((0:(n - 1)) * cur / n) + 1, cur)]
}

#' More color conversions
#'
#' Ports of the remaining helpers in `manim.utils.color.core`:
#' integer RGB(A) values, hex conversion and HSV conversion. Surface
#' shading is [get_shaded_rgb()].
#'
#' @param color A color.
#' @param alpha Opacity.
#' @param rgb A numeric vector in `[0, 1]`.
#' @param hex A hex string.
#' @param h,s,v Hue, saturation and value in `[0, 1]`.
#' @name color_conversions
#' @examples
#' color_to_int_rgb(BLUE)
#' color_from_hsv(0.5, 1, 1)
NULL

#' @rdname color_conversions
#' @export
color_to_int_rgb <- function(color) as.integer(floor(color_to_rgb(color) * 255 + 1e-6))

#' @rdname color_conversions
#' @export
color_to_int_rgba <- function(color, alpha = 1) c(color_to_int_rgb(color), as.integer(floor(alpha * 255 + 1e-6)))

#' @rdname color_conversions
#' @export
rgb_to_hex <- function(rgb) rgb_to_color(rgb)

#' @rdname color_conversions
#' @export
hex_to_rgb <- function(hex) color_to_rgb(hex)

#' @rdname color_conversions
#' @export
color_to_hsv <- function(color) {
  hsv <- grDevices::rgb2hsv(color_to_rgb(color) * 255)
  stats::setNames(as.numeric(hsv), c("h", "s", "v"))
}

#' @rdname color_conversions
#' @export
color_from_hsv <- function(h, s, v) rgb_to_color(as.numeric(grDevices::col2rgb(grDevices::hsv(h, s, v))) / 255)
