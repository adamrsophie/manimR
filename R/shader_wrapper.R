# The CPU side of upstream's shader wrapper (manim/renderer/shader_wrapper.py):
# vertex data, uniforms and the GLSL source of an OpenGL draw call. manimR has
# no OpenGL context; the wrappers describe what upstream would send to the
# GPU, and the GLSL files are shipped in inst/shaders.

# Shader data: one row per vertex, a numeric matrix for each attribute of a
# shader dtype (a named vector of attribute widths). It is an environment, so
# that methods fill it in place as upstream fills its structured array.
shader_data <- function(dtype, n) {
  env <- new.env(parent = emptyenv())
  for (name in names(dtype)) assign(name, matrix(0, n, dtype[[name]]), envir = env)
  structure(env, class = "manim_shader_data", dtype = dtype)
}

#' @export
names.manim_shader_data <- function(x) names(attr(x, "dtype"))

#' @export
length.manim_shader_data <- function(x) {
  nm <- names(x)
  if (length(nm)) nrow(get(nm[1], envir = x)) else 0L
}

#' @export
print.manim_shader_data <- function(x, ...) {
  cat("<shader data: ", length(x), " vertices; ", paste(names(x), collapse = ", "), ">\n", sep = "")
  invisible(x)
}

shader_data_combine <- function(datas) {
  first <- datas[[1]]
  dtype <- attr(first, "dtype")
  out <- shader_data(dtype, 0)
  for (name in names(dtype)) {
    assign(name, do.call(rbind, lapply(datas, function(d) get(name, envir = d))), envir = out)
  }
  out
}

#' @rdname ShaderWrapper
#' @export
get_shader_dir <- function() system.file("shaders", package = "manimR")

#' @rdname ShaderWrapper
#' @param file_name A file name or path.
#' @param directories Folders searched in turn.
#' @export
find_file <- function(file_name, directories) {
  if (file.exists(file_name)) return(file_name)
  for (d in directories) {
    path <- file.path(d, file_name)
    if (file.exists(path)) return(path)
  }
  stop(file_name, " not Found", call. = FALSE)
}

#' @rdname ShaderWrapper
#' @param filename A GLSL file, relative to [get_shader_dir()].
#' @export
get_shader_code_from_file <- function(filename) {
  key <- as.character(filename)
  if (!is.null(filename_to_code_map[[key]])) return(filename_to_code_map[[key]])
  path <- tryCatch(find_file(key, c(get_shader_dir(), "/")), error = function(e) NULL)
  if (is.null(path) || dir.exists(path)) return(NULL)
  # As Python's text mode, which upstream reads with: "\r\n" and "\r" end lines
  # as "\n" (a checkout on Windows can have CRLF line ends).
  result <- gsub("\r\n?", "\n", rawToChar(readBin(path, "raw", file.size(path))))
  for (line in regmatches(result, gregexpr("(?m)^#include \\.\\./include/.*\\.glsl$", result, perl = TRUE))[[1]]) {
    inserted <- get_shader_code_from_file(file.path("include", sub("#include ../include/", "", line, fixed = TRUE)))
    if (is.null(inserted)) return(NULL)
    result <- gsub(line, inserted, result, fixed = TRUE)
  }
  assign(key, result, envir = filename_to_code_map)
  result
}

#' @rdname ShaderWrapper
#' @param rgb_list A matrix (or list) of RGB rows.
#' @export
get_colormap_code <- function(rgb_list) {
  rows <- if (is.matrix(rgb_list)) lapply(seq_len(nrow(rgb_list)), function(i) rgb_list[i, ]) else rgb_list
  data <- paste(vapply(rows, function(r) sprintf("vec3(%s, %s, %s)", r[1], r[2], r[3]), ""), collapse = ",")
  sprintf("vec3[%d](%s)", length(rows), data)
}

#' Shader wrappers
#'
#' The CPU side of upstream's OpenGL draw calls: a `ShaderWrapper` holds the
#' vertex data, vertex indices, uniforms and GLSL source of one draw call.
#' manimR draws with grid and has no OpenGL context, so nothing sends these
#' to a GPU; they describe what upstream's renderer would draw, and the GLSL
#' files of upstream ship in the package (`get_shader_dir()`). The CPU side
#' of the renderer itself is in [opengl_renderer].
#'
#' `get_shader_code_from_file()` reads a GLSL file and inlines its
#' `#include ../include/...` lines; `find_file()` looks a file up in a list
#' of folders; `get_colormap_code()` writes a GLSL array of colors.
#'
#' @param vert_data Shader data, as returned by an OpenGL mobject's
#'   `get_shader_data()`.
#' @param vert_indices Vertex indices (0 based, as upstream), or `NULL`.
#' @param shader_folder Folder of the GLSL files under [get_shader_dir()].
#' @param uniforms Named list of uniforms.
#' @param texture_paths Named list of textures.
#' @param depth_test Whether the draw call tests depth.
#' @param render_primitive moderngl primitive number, which upstream stores
#'   as a string: 0 points, 1 lines, 2 line loop, 3 line strip, 4 triangles,
#'   5 triangle strip (the default) or 6 triangle fan.
#' @return `ShaderWrapper()` returns an R6 object. `get_shader_dir()` and
#'   `find_file()` return paths, `get_shader_code_from_file()` the GLSL code
#'   or `NULL`, and `get_colormap_code()` a string.
#' @rdname ShaderWrapper
#' @format NULL
#' @usage NULL
#' @export
#' @examples
#' w <- ShaderWrapper(OpenGLMobject()$get_shader_data(), shader_folder = "surface")
#' nchar(w$program_code$vertex_shader)
ShaderWrapperClass <- R6::R6Class("ShaderWrapper", lock_objects = FALSE,
  public = list(
    vert_data = NULL,
    vert_indices = NULL,
    vert_attributes = NULL,
    shader_folder = "",
    uniforms = NULL,
    texture_paths = NULL,
    depth_test = FALSE,
    render_primitive = "5",
    program_code = NULL,
    program_id = NULL,
    id = NULL,
    initialize = function(vert_data = NULL, vert_indices = NULL, shader_folder = NULL, uniforms = NULL,
                          texture_paths = NULL, depth_test = FALSE, render_primitive = 5L) {
      self$vert_data <- vert_data
      self$vert_indices <- vert_indices
      self$vert_attributes <- if (!is.null(vert_data)) names(vert_data)
      self$shader_folder <- shader_folder %||% ""
      self$uniforms <- uniforms %||% list()
      self$texture_paths <- texture_paths %||% list()
      self$depth_test <- depth_test
      self$render_primitive <- as.character(render_primitive)
      self$init_program_code()
      self$refresh_id()
    },
    copy = function() {
      result <- self$clone()
      if (!is.null(self$vert_data)) result$vert_data <- shader_data_combine(list(self$vert_data))
      result
    },
    is_valid = function() {
      !is.null(self$vert_data) && !is.null(self$program_code$vertex_shader) && !is.null(self$program_code$fragment_shader)
    },
    get_id = function() self$id,
    get_program_id = function() self$program_id,
    create_id = function() {
      paste(c(self$program_id, paste(deparse(self$uniforms), collapse = ""), paste(deparse(self$texture_paths), collapse = ""),
              self$depth_test, self$render_primitive), collapse = "|")
    },
    refresh_id = function() {
      self$program_id <- self$create_program_id()
      self$id <- self$create_id()
      invisible(NULL)
    },
    create_program_id = function() {
      code <- paste(vapply(c("vertex", "geometry", "fragment"), function(n) {
        self$program_code[[paste0(n, "_shader")]] %||% ""
      }, ""), collapse = "")
      digest::digest(code, algo = "xxhash64", serialize = FALSE)
    },
    init_program_code = function() {
      get_code <- function(name) {
        if (!nzchar(self$shader_folder)) return(NULL)
        get_shader_code_from_file(file.path(self$shader_folder, paste0(name, ".glsl")))
      }
      self$program_code <- list(vertex_shader = get_code("vert"), geometry_shader = get_code("geom"),
                                fragment_shader = get_code("frag"))
      invisible(NULL)
    },
    get_program_code = function() self$program_code,
    replace_code = function(old, new) {
      for (name in names(self$program_code)) {
        code <- self$program_code[[name]]
        if (!is.null(code) && nzchar(code)) self$program_code[[name]] <- gsub(old, new, code, perl = TRUE)
      }
      self$refresh_id()
    },
    combine_with = function(...) {
      wrappers <- list(...)
      if (!length(wrappers)) return(invisible(self))
      if (!is.null(self$vert_indices)) {
        num_verts <- length(self$vert_data)
        indices <- list(self$vert_indices)
        for (sw in wrappers) {
          indices[[length(indices) + 1]] <- sw$vert_indices + num_verts
          num_verts <- num_verts + length(sw$vert_data)
        }
        self$vert_indices <- unlist(indices)
      }
      self$vert_data <- shader_data_combine(c(list(self$vert_data), lapply(wrappers, function(sw) sw$vert_data)))
      invisible(self)
    }
  )
)

#' @rdname ShaderWrapper
#' @export
ShaderWrapper <- build_constructor(ShaderWrapperClass)
