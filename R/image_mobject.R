# Raster image mobjects. Ported from manim/mobject/types/image_mobject.py.

#' Resampling algorithms for images
#'
#' Names accepted by `ImageMobject$set_resampling_algorithm()`, mapped to
#' their canonical names. Images are drawn with the filters Pillow's
#' perspective transform has: `"nearest"` draws the pixels as blocks,
#' `"bilinear"` interpolates linearly, and `"bicubic"` (the default) uses
#' Pillow's bicubic filter for enlarged, sheared or perspective images. Pillow
#' cannot transform with `"lanczos"`, `"box"` or `"hamming"`, so upstream's
#' camera raises for them; manimR draws them as `"bilinear"`.
#' `OpenGLImageMobject()` upscales image arrays with all six filters, as
#' Pillow's `resize()` does.
#' @return A named character vector of resampling algorithm names.
#' @export
RESAMPLING_ALGORITHMS <- c(
  nearest = "nearest", none = "nearest",
  lanczos = "lanczos", antialias = "lanczos",
  bilinear = "bilinear", linear = "bilinear",
  bicubic = "bicubic", cubic = "bicubic",
  box = "box", hamming = "hamming"
)

# Convert a gray, gray+alpha or RGB array (0 to 255) into an h x w x 4 RGBA array.
#' @rdname image_helpers
#' @export
change_to_rgba_array <- function(image, dtype = "uint8") {
  pa <- image
  if (length(dim(pa)) < 2) stop("An image array needs at least two dimensions.", call. = FALSE)
  if (length(dim(pa)) == 2) pa <- array(pa, c(dim(pa), 1))
  h <- dim(pa)[1]
  w <- dim(pa)[2]
  ch <- dim(pa)[3]
  out <- array(255, c(h, w, 4))
  if (ch == 1 || ch == 2) {
    for (k in 1:3) out[, , k] <- pa[, , 1]
    if (ch == 2) out[, , 4] <- pa[, , 2]
  } else {
    out[, , 1:3] <- pa[, , 1:3]
    if (ch >= 4) out[, , 4] <- pa[, , 4]
  }
  out
}

# PIL's Image.convert(mode) for a 0 to 255 array: "RGBA", "RGB" (drops the
# alpha channel) or "L" (ITU-R 601-2 luma in PIL's fixed point arithmetic).
convert_image_mode <- function(pa, mode) {
  rgba <- change_to_rgba_array(pa)
  switch(mode,
    RGBA = rgba,
    RGB = rgba[, , 1:3, drop = FALSE],
    L = matrix(floor((rgba[, , 1] * 19595 + rgba[, , 2] * 38470 + rgba[, , 3] * 7471 + 32768) / 65536),
               nrow(rgba)),
    stop("image_mode must be \"RGBA\", \"RGB\" or \"L\".", call. = FALSE)
  )
}

# Unpack a nativeRaster (row major packed integers, red in the low byte) into
# an h x w x 4 array.
native_raster_to_array <- function(x) {
  h <- dim(x)[1]
  w <- dim(x)[2]
  v <- as.integer(x)
  channel <- function(shift) matrix(bitwAnd(bitwShiftR(v, shift), 255L), h, w, byrow = TRUE)
  array(c(channel(0L), channel(8L), channel(16L), channel(24L)), c(h, w, 4))
}

# The inverse for an h x w x 4 array of values 0 to 1: a nativeRaster draws
# without the color conversion grid does for arrays.
array_to_native_raster <- function(a) {
  h <- dim(a)[1]
  w <- dim(a)[2]
  byte <- function(k) round(t(a[, , k]) * 255)
  v <- byte(1) + byte(2) * 256 + byte(3) * 65536 + byte(4) * 16777216
  v[v >= 2^31] <- v[v >= 2^31] - 2^32
  structure(as.integer(v), dim = c(h, w), class = "nativeRaster", channels = 4L)
}

#' @title Image mobjects
#' @description `ImageMobject()` displays a raster image from a PNG file or a
#'   numeric array with values from 0 to 255 (a matrix for grayscale, or an
#'   `h x w x 3` or `h x w x 4` array). Its corner points are, in order,
#'   upper left, upper right, lower left and lower right, so it moves, scales
#'   and rotates like any mobject. `get_raster()` returns an array in `[0, 1]`
#'   suitable for [grid::grid.raster()].
#'
#'   `ImageMobjectFromCamera()` shows what a [MovingCameraClass] camera sees;
#'   it is drawn by [MultiCameraClass] (see [ZoomedScene]).
#' @param filename_or_array Path to a PNG file (a single string), a numeric
#'   array, a raster from [grDevices::as.raster()], a `nativeRaster`, or a
#'   character matrix of colors.
#' @param scale_to_resolution Pixel height shown pixel for pixel, so the
#'   image height is `nrow / scale_to_resolution * frame_height`.
#' @param invert Invert the image colors.
#' @param image_mode Mode a PNG file is converted to after reading, as PIL
#'   does: `"RGBA"`, `"RGB"` (drops the alpha channel) or `"L"`
#'   (luminance). Arrays and rasters are used as given. Images are then
#'   stored as RGBA, 0 to 255.
#' @param camera A [MovingCameraClass] camera.
#' @param pixel_array_dtype Type of the stored pixel values; only `"uint8"`
#'   (0 to 255) is used.
#' @param resampling_algorithm How the image is sampled when drawn: a name
#'   in [RESAMPLING_ALGORITHMS], `"bicubic"` by default.
#' @param default_display_frame_config List of style arguments for the frame
#'   added by `add_display_frame()`.
#' @param ... Further arguments for [MobjectClass].
#' @return A mobject: an R6 object of the class named by the function called.
#'   The objects whose names end in `Class` are the R6 class generators that
#'   these functions call.
#' @name image_mobject
#' @examples
#' img <- ImageMobject(matrix(c(0, 100, 30, 200, 255, 0, 5, 33), 2, byrow = TRUE))
#' img$height <- 7
#' img$set_resampling_algorithm("nearest")
NULL

#' @rdname image_mobject
#' @format NULL
#' @usage NULL
#' @export
AbstractImageMobjectClass <- R6::R6Class("AbstractImageMobject", inherit = MobjectClass, lock_objects = FALSE,
  public = list(
    scale_to_resolution = 1080,
    pixel_array_dtype = "uint8",
    resampling_algorithm = "bicubic",
    initialize = function(scale_to_resolution, pixel_array_dtype = "uint8", resampling_algorithm = "bicubic", ...) {
      self$pixel_array_dtype <- pixel_array_dtype
      self$scale_to_resolution <- scale_to_resolution
      self$set_resampling_algorithm(resampling_algorithm)
      super$initialize(...)
    },
    get_pixel_array = function() stop("Not implemented", call. = FALSE),
    # Pixel (height, width) of the image.
    pixel_shape = function() dim(self$get_pixel_array())[1:2],
    set_resampling_algorithm = function(resampling_algorithm) {
      key <- tolower(as.character(resampling_algorithm))
      if (!key %in% c(names(RESAMPLING_ALGORITHMS), RESAMPLING_ALGORITHMS)) {
        stop("resampling_algorithm has to be one of the names in RESAMPLING_ALGORITHMS. ",
             "Available algorithms: 'bicubic' (or 'cubic'), 'nearest' (or 'none'), ",
             "'bilinear' (or 'linear'), 'box', 'hamming', 'lanczos'.", call. = FALSE)
      }
      self$resampling_algorithm <- if (key %in% names(RESAMPLING_ALGORITHMS)) RESAMPLING_ALGORITHMS[[key]] else key
      invisible(self)
    },
    reset_points = function() {
      self$points <- rbind(UP + LEFT, UP + RIGHT, DOWN + LEFT, DOWN + RIGHT)
      self$center()
      hw <- self$pixel_shape()
      height <- if (!as.logical(self$scale_to_resolution)) 3 else {
        hw[1] / self$scale_to_resolution * cfg("frame_height")
      }
      self$stretch_to_fit_height(height)
      self$stretch_to_fit_width(height * hw[2] / hw[1])
      invisible(self)
    }
  )
)

# Reads an image file as an h x w x channels array in [0, 1], like
# png::readPNG(). PNG files are read directly; other formats (JPEG, GIF, BMP,
# TIFF, WebP and so on) are first converted to PNG with ffmpeg, which manimR
# already needs for video output.
read_raster_file <- function(path) {
  if (tolower(tools::file_ext(path)) != "png") {
    tmp <- tempfile(fileext = ".png")
    on.exit(unlink(tmp), add = TRUE)
    status <- system2(ffmpeg_path(), shQuote(c("-y", "-loglevel", "error", "-i", path, "-frames:v", "1", tmp)))
    if (status != 0 || !file.exists(tmp)) stop("Could not read image '", path, "' (ffmpeg failed to convert it)", call. = FALSE)
    path <- tmp
  }
  tryCatch(png::readPNG(path), error = function(e) {
    stop("Could not read image '", path, "': ", conditionMessage(e), call. = FALSE)
  })
}

#' @rdname image_mobject
#' @format NULL
#' @usage NULL
#' @export
ImageMobjectClass <- R6::R6Class("ImageMobject", inherit = AbstractImageMobjectClass, lock_objects = FALSE,
  public = list(
    pixel_array = NULL,
    orig_alpha_pixel_array = NULL,
    fill_opacity = 1,
    stroke_opacity = 1,
    invert_image = FALSE,
    image_mode = "RGBA",
    path = NULL,
    initialize = function(filename_or_array, scale_to_resolution = QUALITIES$high_quality$pixel_height, invert = FALSE,
                          image_mode = "RGBA", ...) {
      self$fill_opacity <- 1
      self$stroke_opacity <- 1
      self$invert_image <- invert
      self$image_mode <- image_mode
      x <- filename_or_array
      if (inherits(x, "nativeRaster")) {
        pa <- native_raster_to_array(x)
      } else if (inherits(x, "raster") || (is.character(x) && !is.null(dim(x)))) {
        m <- as.matrix(grDevices::as.raster(x))
        pa <- array(t(grDevices::col2rgb(m, alpha = TRUE)), c(nrow(m), ncol(m), 4))
      } else if (is.character(x)) {
        if (length(x) != 1) {
          stop("A file name must be a single string; give a matrix of colors its dimensions.", call. = FALSE)
        }
        # Looked up as upstream's get_full_raster_image_path(): as given, then
        # in assets_dir, with the usual image extensions.
        path <- tryCatch(get_full_raster_image_path(x), error = function(e) NA_character_)
        if (is.na(path) || !file.exists(path)) stop("Image file not found: ", x, call. = FALSE)
        arr <- read_raster_file(path)
        # Upstream converts only images read from files to image_mode.
        pa <- convert_image_mode(round(arr * 255), image_mode)
        self$path <- normalizePath(path)
      } else {
        pa <- array(as.numeric(x), dim(x) %||% c(1, length(x)))
      }
      pa <- change_to_rgba_array(pa)
      if (invert) pa[, , 1:3] <- 255 - pa[, , 1:3]
      self$pixel_array <- pa
      self$orig_alpha_pixel_array <- pa[, , 4]
      super$initialize(scale_to_resolution, ...)
    },
    get_pixel_array = function() self$pixel_array,
    # Array in [0, 1] (h x w x 4) that grid::grid.raster() accepts.
    get_raster = function() {
      pa <- self$pixel_array / 255
      pa[pa < 0] <- 0
      pa[pa > 1] <- 1
      pa
    },
    set_color = function(color = YELLOW_C, alpha = NULL, family = TRUE) {
      rgb <- round(color_to_rgb(color) * 255)
      for (k in 1:3) self$pixel_array[, , k] <- rgb[k]
      if (!is.null(alpha)) self$pixel_array[, , 4] <- trunc(255 * alpha)
      for (sm in self$submobjects) sm$set_color(color, family = family)
      self$color <- manim_color(color)
      invisible(self)
    },
    set_opacity = function(alpha) {
      self$pixel_array[, , 4] <- trunc(self$orig_alpha_pixel_array * alpha)
      self$stroke_opacity <- alpha
      invisible(self)
    },
    fade = function(darkness = 0.5, family = TRUE) {
      self$set_opacity(1 - darkness)
      super$fade(darkness, family)
      invisible(self)
    },
    interpolate_color = function(mobject1, mobject2, alpha) {
      if (!identical(dim(mobject1$pixel_array), dim(mobject2$pixel_array))) {
        stop("Mobject pixel array shapes incompatible for interpolation.\n",
             "Mobject 1: ", paste(dim(mobject1$pixel_array), collapse = " x "), "\n",
             "Mobject 2: ", paste(dim(mobject2$pixel_array), collapse = " x "), call. = FALSE)
      }
      self$fill_opacity <- interpolate(mobject1$fill_opacity, mobject2$fill_opacity, alpha)
      self$stroke_opacity <- interpolate(mobject1$stroke_opacity, mobject2$stroke_opacity, alpha)
      self$pixel_array <- trunc(interpolate(mobject1$pixel_array, mobject2$pixel_array, alpha))
      invisible(self)
    },
    get_style = function() list(fill_color = manim_color(self$color), fill_opacity = self$fill_opacity)
  )
)

#' @rdname image_mobject
#' @export
ImageMobject <- constructor(ImageMobjectClass)
#' @rdname image_mobject
#' @format NULL
#' @usage NULL
#' @export
ImageMobjectFromCameraClass <- R6::R6Class("ImageMobjectFromCamera", inherit = AbstractImageMobjectClass,
  lock_objects = FALSE,
  public = list(
    camera = NULL,
    default_display_frame_config = NULL,
    display_frame = NULL,
    initialize = function(camera, default_display_frame_config = NULL, ...) {
      self$camera <- camera
      self$default_display_frame_config <- default_display_frame_config %||%
        list(stroke_width = 3, stroke_color = WHITE, buff = 0)
      super$initialize(scale_to_resolution = FALSE, ...)
    },
    # The camera draws vector graphics straight into this mobject's area, or
    # warps the sub camera's pixels when the area is sheared (see
    # MultiCameraClass$display_camera_image), so there is no stored raster.
    pixel_shape = function() c(self$camera$pixel_height, self$camera$pixel_width),
    get_pixel_array = function() NULL,
    add_display_frame = function(...) {
      config <- utils::modifyList(self$default_display_frame_config, list(...))
      self$display_frame <- do.call(SurroundingRectangle, c(list(self), config))
      self$add(self$display_frame)
      invisible(self)
    },
    interpolate_color = function(mobject1, mobject2, alpha) invisible(self)
  )
)

#' @rdname image_mobject
#' @export
ImageMobjectFromCamera <- constructor(ImageMobjectFromCameraClass)