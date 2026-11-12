# ManimColor, HSV and RandomColorGenerator, ported from
# manim/utils/color/core.py.
#
# Colors in manimR are hex strings. A ManimColor is such a hex string that
# also carries its exact RGBA value (attribute "rgba"; an HSV color also
# keeps "hsva"), so it works wherever a color is accepted, and has
# upstream's methods through `$`.

# A ManimColor from an RGBA value (0 to 1, possibly outside after
# arithmetic, as upstream allows).
new_manim_color <- function(rgba) {
  rgba <- as.numeric(rgba)
  structure(rgb_hex(rgba[1:3]), rgba = rgba, class = c("ManimColor", "character"))
}

new_hsv_color <- function(hsva) {
  hsva <- as.numeric(hsva)
  rgb <- hsv_to_rgb(hsva[1:3])
  structure(rgb_hex(rgb), rgba = c(rgb, hsva[4]), hsva = hsva, class = c("HSV", "ManimColor", "character"))
}

# Python's colorsys conversions.
rgb_to_hsv_num <- function(rgb) {
  mx <- max(rgb)
  mn <- min(rgb)
  v <- mx
  if (mn == mx) return(c(0, 0, v))
  s <- (mx - mn) / mx
  rc <- (mx - rgb[1]) / (mx - mn)
  gc <- (mx - rgb[2]) / (mx - mn)
  bc <- (mx - rgb[3]) / (mx - mn)
  h <- if (rgb[1] == mx) bc - gc else if (rgb[2] == mx) 2 + rc - bc else 4 + gc - rc
  c((h / 6) %% 1, s, v)
}

hsv_to_rgb <- function(hsv) {
  h <- hsv[1]
  s <- hsv[2]
  v <- hsv[3]
  if (s == 0) return(c(v, v, v))
  i <- floor(h * 6)
  f <- h * 6 - i
  p <- v * (1 - s)
  q <- v * (1 - s * f)
  t <- v * (1 - s * (1 - f))
  switch(as.character(i %% 6), "0" = c(v, t, p), "1" = c(q, v, p), "2" = c(p, v, t), "3" = c(p, q, v),
         "4" = c(t, p, v), "5" = c(v, p, q))
}

rgb_to_hls_num <- function(rgb) {
  mx <- max(rgb)
  mn <- min(rgb)
  l <- (mn + mx) / 2
  if (mn == mx) return(c(0, l, 0))
  s <- if (l <= 0.5) (mx - mn) / (mx + mn) else (mx - mn) / (2 - mx - mn)
  h <- rgb_to_hsv_num(rgb)[1]
  c(h, l, s)
}

hls_to_rgb <- function(h, l, s) {
  if (s == 0) return(c(l, l, l))
  m2 <- if (l <= 0.5) l * (1 + s) else l + s - l * s
  m1 <- 2 * l - m2
  v <- function(hue) {
    hue <- hue %% 1
    if (hue < 1 / 6) return(m1 + (m2 - m1) * hue * 6)
    if (hue < 0.5) return(m2)
    if (hue < 2 / 3) return(m1 + (m2 - m1) * (2 / 3 - hue) * 6)
    m1
  }
  c(v(h + 1 / 3), v(h), v(h - 1 / 3))
}

# The RGBA value of anything ManimColor() accepts.
parse_manim_color_value <- function(value, alpha = 1) {
  if (is.null(value)) return(c(0, 0, 0, alpha))
  if (inherits(value, "ManimColor")) return(attr(value, "rgba"))
  if (is.character(value)) {
    if (length(value) != 1) stop("A color name or hex string must be a single string", call. = FALSE)
    hex <- regmatches(value, regexpr("(?i)(?<=#|0x)[0-9A-F]{3,8}", value, perl = TRUE))
    if (length(hex)) {
      if (nchar(hex) %in% c(3, 4)) hex <- paste(rep(strsplit(hex, "")[[1]], each = 2), collapse = "")
      if (nchar(hex) == 6) {
        hex <- paste0(hex, "FF")
      } else if (nchar(hex) == 8) {
        alpha <- strtoi(substr(hex, 7, 8), 16L) / 255
      } else {
        stop("Hex colors must be specified with either 0x or # as prefix and contain 6 or 8 hexadecimal numbers",
             call. = FALSE)
      }
      ch <- strtoi(substring(hex, c(1, 3, 5), c(2, 4, 6)), 16L) / 255
      return(c(ch, alpha))
    }
    key <- tolower(value)
    tab <- manim_color_table()
    if (!key %in% names(tab)) stop("Color ", value, " not found", call. = FALSE)
    return(c(parse_manim_color_value(tab[[key]])[1:3], alpha))
  }
  if (is.numeric(value) && length(value) == 1) {
    v <- as.numeric(value)
    return(c(c(floor(v / 65536) %% 256, floor(v / 256) %% 256, v %% 256) / 255, alpha))
  }
  if (is.numeric(value) && length(value) %in% c(3, 4)) {
    # Integers (or any value above 1) are 0 to 255, other numbers 0 to 1.
    ints <- is.integer(value) || any(value > 1)
    v <- if (ints) value / 255 else as.numeric(value)
    return(if (length(v) == 3) c(v, alpha) else v)
  }
  stop("ManimColor only accepts a color name, a hex string, an integer, or 3 or 4 numbers", call. = FALSE)
}

#' Colors as objects
#'
#' `ManimColor()` is upstream's color class. Colors in manimR are hex
#' strings, so a `ManimColor` is a hex string that also carries its exact
#' RGBA value; it works wherever a color is accepted, and it has upstream's
#' methods through `$`:
#' `to_integer()`, `to_rgb()`, `to_int_rgb()`, `to_rgba()`, `to_int_rgba()`,
#' `to_rgba_with_alpha(alpha)`, `to_int_rgba_with_alpha(alpha)`,
#' `to_hex(with_alpha = FALSE)`, `to_hsv()`, `to_hsl()`,
#' `invert(with_alpha = FALSE)`, `interpolate(other, alpha)`,
#' `darker(blend = 0.2)`, `lighter(blend = 0.2)`,
#' `contrasting(threshold = 0.5, light = NULL, dark = NULL)`,
#' `opacity(opacity)` and `into(class_type)`. Arithmetic (`+`, `-`, `*`,
#' `/`, `%/%`, `%%`, `^`) works channel by channel with numbers or other
#' colors, `==` compares values, `!` inverts, `&` and `|` combine the integer
#' values, and `as.integer()` gives `to_integer()`.
#'
#' A mobject stores its colors as plain hex strings, so wrap one to use the
#' methods: `ManimColor(sq$get_color())$darker()`.
#'
#' `ManimColorClass` holds upstream's class methods: `from_rgb(rgb, alpha)`,
#' `from_rgba(rgba)`, `from_hex(hex_str, alpha)`, `from_hsv(hsv, alpha)`,
#' `from_hsl(hsl, alpha)`, `parse(color, alpha)` (a list of colors for a
#' vector or list) and `gradient(colors, length)` (upstream leaves it
#' unimplemented; here it is [color_gradient()] as colors). `RGBA()` is
#' another name for `ManimColor()`, as upstream.
#'
#' `HSV()` is a color held as hue, saturation and value (0 to 1); `$hue`,
#' `$saturation` and `$value` (or `$h`, `$s`, `$v`) read and set them, and
#' arithmetic works on those channels. `HSVClass` has the same class methods.
#' Upstream drops an HSV color's alpha when converting it; here it is kept.
#'
#' `ManimColorDType` names the storage type of color values (`"double"`).
#'
#' @param value A color name, a hex string (with `#` or `0x`), an integer
#'   such as `0xFF0000`, 3 or 4 numbers (0 to 1, or 0 to 255 when integers or
#'   above 1), or another `ManimColor`. For `$<-`, the new value of an HSV
#'   property.
#' @param alpha Opacity, used when `value` has none.
#' @param hsv Hue, saturation and value, with an optional fourth alpha.
#' @param x A `ManimColor`.
#' @param name Method or property name.
#' @param e1,e2 Operands.
#' @param ... Ignored.
#' @name ManimColor
#' @examples
#' c1 <- ManimColor("#FF0000")
#' c1$darker()
#' c1$interpolate(ManimColor(BLUE), 0.5)$to_hex()
#' ManimColorClass$from_hsv(c(0.5, 1, 1))
#' Square(color = ManimColor(0x00FF00))$get_color()
#' h <- HSV(c(0.25, 1, 1))
#' h$hue <- 0.5
#' as.character(h)
#' @export
ManimColor <- function(value = NULL, alpha = 1) new_manim_color(parse_manim_color_value(value, alpha))

#' @rdname ManimColor
#' @export
RGBA <- ManimColor

#' @rdname ManimColor
#' @export
HSV <- function(hsv, alpha = 1) {
  if (length(hsv) == 3) hsv <- c(hsv, alpha)
  if (length(hsv) != 4) stop("HSV Color must be an array of 3 values", call. = FALSE)
  new_hsv_color(hsv)
}

#' @rdname ManimColor
#' @export
ManimColorDType <- "double"

color_space <- function(x) if (inherits(x, "HSV")) attr(x, "hsva") else attr(x, "rgba")

construct_from_space <- function(x, space) if (inherits(x, "HSV")) new_hsv_color(space) else new_manim_color(space)

# Builds a color of the class of `x` from an RGBA value.
from_internal <- function(cls, rgba) {
  if (identical(cls, "HSV")) return(new_hsv_color(c(rgb_to_hsv_num(rgba[1:3]), rgba[4])))
  new_manim_color(rgba)
}

class_methods <- function(cls) {
  list(
    from_rgb = function(rgb, alpha = 1) from_internal(cls, parse_manim_color_value(as.numeric(rgb), alpha)),
    from_rgba = function(rgba) from_internal(cls, parse_manim_color_value(as.numeric(rgba))),
    from_hex = function(hex_str, alpha = 1) from_internal(cls, parse_manim_color_value(hex_str, alpha)),
    from_hsv = function(hsv, alpha = 1) from_internal(cls, c(hsv_to_rgb(hsv[1:3]), alpha)),
    from_hsl = function(hsl, alpha = 1) from_internal(cls, c(hls_to_rgb(hsl[1], hsl[3], hsl[2]), alpha)),
    parse = function(color, alpha = 1) {
      if ((is.list(color) && !inherits(color, "ManimColor")) || (is.character(color) && length(color) > 1)) {
        return(lapply(color, function(c1) from_internal(cls, parse_manim_color_value(c1, alpha))))
      }
      from_internal(cls, parse_manim_color_value(color, alpha))
    },
    gradient = function(colors, length) {
      lapply(color_gradient(lapply(colors, as.character), length), function(h) from_internal(cls, parse_manim_color_value(h)))
    },
    classname = cls
  )
}

#' @rdname ManimColor
#' @format NULL
#' @export
ManimColorClass <- class_methods("ManimColor")

#' @rdname ManimColor
#' @format NULL
#' @export
HSVClass <- class_methods("HSV")

manim_color_methods <- list(
  to_integer = function(x) {
    v <- trunc(attr(x, "rgba")[1:3] * 255) %% 256
    sum(v * c(65536, 256, 1))
  },
  to_rgb = function(x) attr(x, "rgba")[1:3],
  to_int_rgb = function(x) as.integer(trunc(attr(x, "rgba")[1:3] * 255)),
  to_rgba = function(x) attr(x, "rgba"),
  to_int_rgba = function(x) as.integer(trunc(attr(x, "rgba") * 255)),
  to_rgba_with_alpha = function(x, alpha) c(attr(x, "rgba")[1:3], alpha),
  to_int_rgba_with_alpha = function(x, alpha) as.integer(trunc(c(attr(x, "rgba")[1:3], alpha) * 255)),
  to_hex = function(x, with_alpha = FALSE) {
    v <- trunc(attr(x, "rgba") * 255)
    out <- sprintf("#%02X%02X%02X", v[1], v[2], v[3])
    if (with_alpha) out <- paste0(out, sprintf("%02X", v[4]))
    out
  },
  to_hsv = function(x) rgb_to_hsv_num(attr(x, "rgba")[1:3]),
  to_hsl = function(x) {
    hls <- rgb_to_hls_num(attr(x, "rgba")[1:3])
    c(hls[1], hls[3], hls[2])
  },
  invert = function(x, with_alpha = FALSE) {
    sp <- color_space(x)
    new <- 1 - sp
    if (!with_alpha) new[4] <- sp[4]
    construct_from_space(x, new)
  },
  interpolate = function(x, other, alpha) {
    construct_from_space(x, color_space(x) * (1 - alpha) + color_space(other) * alpha)
  },
  darker = function(x, blend = 0.2) {
    a <- color_space(x)[4]
    black <- from_internal(class(x)[1], c(0, 0, 0, 1))
    manim_color_methods$opacity(manim_color_methods$interpolate(x, black, blend), a)
  },
  lighter = function(x, blend = 0.2) {
    a <- color_space(x)[4]
    white <- from_internal(class(x)[1], c(1, 1, 1, 1))
    manim_color_methods$opacity(manim_color_methods$interpolate(x, white, blend), a)
  },
  contrasting = function(x, threshold = 0.5, light = NULL, dark = NULL) {
    rgb <- attr(x, "rgba")[1:3]
    luminance <- sum(rgb * c(0.3, 0.59, 0.11))
    if (luminance < threshold) {
      if (!is.null(light)) return(light)
      return(from_internal(class(x)[1], c(1, 1, 1, 1)))
    }
    if (!is.null(dark)) return(dark)
    from_internal(class(x)[1], c(0, 0, 0, 1))
  },
  opacity = function(x, opacity) {
    sp <- color_space(x)
    sp[4] <- opacity
    construct_from_space(x, sp)
  },
  into = function(x, class_type) {
    cls <- if (is.list(class_type)) class_type$classname else class_type
    from_internal(cls, attr(x, "rgba"))
  }
)

#' @rdname ManimColor
#' @export
`$.ManimColor` <- function(x, name) {
  if (inherits(x, "HSV")) {
    idx <- match(name, c("hue", "saturation", "value", "h", "s", "v"))
    if (!is.na(idx)) return(attr(x, "hsva")[(idx - 1) %% 3 + 1])
  }
  f <- manim_color_methods[[name]]
  if (is.null(f)) stop(class(x)[1], " has no method or property '", name, "'", call. = FALSE)
  function(...) f(x, ...)
}

#' @rdname ManimColor
#' @export
`$<-.ManimColor` <- function(x, name, value) {
  idx <- match(name, c("hue", "saturation", "value", "h", "s", "v"))
  if (!inherits(x, "HSV") || is.na(idx)) stop("Cannot set '", name, "' on a ", class(x)[1], call. = FALSE)
  hsva <- attr(x, "hsva")
  hsva[(idx - 1) %% 3 + 1] <- value
  new_hsv_color(hsva)
}

#' @rdname ManimColor
#' @export
Ops.ManimColor <- function(e1, e2) {
  if (.Generic == "!") return(manim_color_methods$invert(e1))
  if (missing(e2)) stop("Unary ", .Generic, " is not defined for colors", call. = FALSE)
  if (.Generic %in% c("==", "!=")) {
    if (!inherits(e1, "ManimColor") || !inherits(e2, "ManimColor")) {
      stop("Cannot compare a ManimColor with something else", call. = FALSE)
    }
    eq <- isTRUE(all.equal(attr(e1, "rgba"), attr(e2, "rgba"), tolerance = 1e-8))
    return(if (.Generic == "==") eq else !eq)
  }
  if (.Generic %in% c("&", "|")) {
    a <- manim_color_methods$to_integer(e1)
    b <- if (inherits(e2, "ManimColor")) manim_color_methods$to_integer(e2) else as.integer(e2)
    v <- if (.Generic == "&") bitwAnd(as.integer(a), as.integer(b)) else bitwOr(as.integer(a), as.integer(b))
    return(construct_from_space(e1, parse_manim_color_value(v)))
  }
  ops <- c("+", "-", "*", "/", "%/%", "%%", "^")
  if (!.Generic %in% ops) stop("Operation ", .Generic, " is not defined for colors", call. = FALSE)
  base <- if (inherits(e1, "ManimColor")) e1 else e2
  a <- if (inherits(e1, "ManimColor")) color_space(e1) else e1
  b <- if (inherits(e2, "ManimColor")) color_space(e2) else e2
  # As upstream, a number on the left gives the same result as on the right.
  if (!inherits(e1, "ManimColor")) {
    tmp <- a
    a <- b
    b <- tmp
  }
  construct_from_space(base, get(.Generic, envir = baseenv())(a, b))
}

#' @rdname ManimColor
#' @export
as.integer.ManimColor <- function(x, ...) as.integer(manim_color_methods$to_integer(x))

#' @rdname ManimColor
#' @export
as.character.ManimColor <- function(x, ...) as.character(unclass(x))

#' @rdname ManimColor
#' @export
print.ManimColor <- function(x, ...) {
  cat(class(x)[1], "('", manim_color_methods$to_hex(x), "')\n", sep = "")
  invisible(x)
}

#' @rdname ManimColor
#' @export
format.ManimColor <- function(x, ...) manim_color_methods$to_hex(x)

#' Random colors from a seed
#'
#' Upstream's `RandomColorGenerator`: `$next()` (or `$next_color()`, since
#' `next` is reserved in R and needs backticks: ``gen$`next`()``) returns a
#' random color from `sample_colors` (by default every manim color). With a
#' `seed`, the generator has its own random stream, which does not touch
#' R's global one and repeats for the same seed; the sequence differs from
#' Python's.
#'
#' @param seed `NULL`, or an integer seed.
#' @param sample_colors Colors to choose from.
#' @name RandomColorGenerator
#' @format NULL
#' @usage NULL
#' @examples
#' gen <- RandomColorGenerator(42)
#' gen$next_color()
#' @export
RandomColorGeneratorClass <- R6::R6Class("RandomColorGenerator", lock_objects = FALSE,
  public = list(
    colors = NULL,
    seed = NULL,
    state = NULL,
    initialize = function(seed = NULL, sample_colors = NULL) {
      self$colors <- sample_colors %||% unname(as.list(manim_color_table()))
      self$seed <- seed
      if (!is.null(seed)) {
        old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv())
        on.exit(restore_random_seed(old), add = TRUE)
        set.seed(seed)
        self$state <- get(".Random.seed", envir = globalenv())
      }
    },
    `next` = function() {
      if (is.null(self$state)) return(ManimColor(self$colors[[sample.int(length(self$colors), 1)]]))
      old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv())
      on.exit(restore_random_seed(old), add = TRUE)
      assign(".Random.seed", self$state, envir = globalenv())
      i <- sample.int(length(self$colors), 1)
      self$state <- get(".Random.seed", envir = globalenv())
      ManimColor(self$colors[[i]])
    },
    next_color = function() self$`next`()
  )
)

restore_random_seed <- function(old) {
  if (is.null(old)) {
    if (exists(".Random.seed", envir = globalenv())) rm(".Random.seed", envir = globalenv())
  } else {
    assign(".Random.seed", old, envir = globalenv())
  }
}

#' @rdname RandomColorGenerator
#' @export
RandomColorGenerator <- constructor(RandomColorGeneratorClass)
