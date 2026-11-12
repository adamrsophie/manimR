# VectorScene and LinearTransformationScene.
# Ported from manim/scene/vector_space_scene.py.

#' @rdname VectorScene
#' @format NULL
#' @export
X_COLOR <- GREEN_C
#' @rdname VectorScene
#' @format NULL
#' @export
Y_COLOR <- RED_C
#' @rdname VectorScene
#' @format NULL
#' @export
Z_COLOR <- BLUE_D

#' @title VectorScene and LinearTransformationScene
#' @description Scenes for linear algebra. `VectorScene` adds helpers to draw
#'   planes, vectors, labels and coordinates. `LinearTransformationScene`
#'   sets up a background plane, a transformable foreground plane and basis
#'   vectors, then animates matrices with `apply_matrix()`,
#'   `apply_transposed_matrix()`, `apply_inverse()` and
#'   `apply_nonlinear_transformation()`.
#'
#' ```r
#' Shear <- R6::R6Class("Shear", inherit = LinearTransformationScene,
#'   public = list(construct = function() {
#'     self$add_unit_square()
#'     self$apply_matrix(matrix(c(1, 0, 1, 1), 2))
#'     self$wait()
#'   }))
#' ```
#' @details `VectorScene$new()` and `LinearTransformationScene$new()` take
#'   `basis_vector_stroke_width`, the stroke width of the basis vectors.
#'   `LinearTransformationScene$new()` also takes
#'   `include_background_plane` and `include_foreground_plane`, which planes
#'   to draw; `background_plane_kwargs` and `foreground_plane_kwargs`, lists of
#'   [NumberPlane()] arguments; `show_coordinates`, to label the background
#'   plane; `show_basis_vectors`, to draw i hat and j hat; `i_hat_color` and
#'   `j_hat_color`, the colors of the basis vectors; and
#'   `leave_ghost_vectors`, to keep faded copies of vectors after each
#'   transformation. Other arguments are passed to [Scene].
#'
#'   `X_COLOR`, `Y_COLOR` and `Z_COLOR` are the default colors of the x, y
#'   and z basis vectors.
#' @return `VectorScene` and `LinearTransformationScene` are R6 class
#'   generators: a scene class inherits from one of them, and `$new()` creates a
#'   scene. `X_COLOR`, `Y_COLOR` and `Z_COLOR` are colors.
#' @name VectorScene
NULL

#' @rdname VectorScene
#' @format NULL
#' @usage NULL
#' @export
VectorScene <- R6::R6Class("VectorScene", inherit = Scene, lock_objects = FALSE,
  public = list(
    basis_vector_stroke_width = 6,
    plane = NULL,
    initialize = function(basis_vector_stroke_width = 6, ...) {
      super$initialize(...)
      self$basis_vector_stroke_width <- basis_vector_stroke_width
    },
    add_plane = function(animate = FALSE, ...) {
      plane <- NumberPlane(...)
      if (animate) self$play(Create(plane, lag_ratio = 0.5))
      self$add(plane)
      plane
    },
    add_axes = function(animate = FALSE, color = "#FFFFFF") {
      axes <- Axes(color = color, axis_config = list(unit_size = 1))
      if (animate) self$play(Create(axes))
      self$add(axes)
      axes
    },
    lock_in_faded_grid = function(dimness = 0.7, axes_dimness = 0.5) {
      plane <- self$add_plane()
      axes <- plane$get_axes()
      plane$fade(dimness)
      axes$set_color("#FFFFFF")
      axes$fade(axes_dimness)
      self$add(axes)
      self$renderer$update_frame(self)
      self$camera$background_image <- self$renderer$get_frame()
      self$clear()
    },
    get_vector = function(numerical_vector, ...) {
      v <- as.numeric(numerical_vector)
      Arrow(self$plane$coords_to_point(0, 0), self$plane$coords_to_point(v[1], v[2]), buff = 0, ...)
    },
    add_vector = function(vector, color = PURE_YELLOW, animate = TRUE, ...) {
      if (!inherits(vector, "Arrow")) vector <- Vector(as_point(vector), color = color, ...)
      if (animate) self$play(GrowArrow(vector))
      self$add(vector)
      vector
    },
    write_vector_coordinates = function(vector, ...) {
      coords <- vector$coordinate_label(...)
      self$play(Write(coords))
      coords
    },
    get_basis_vectors = function(i_hat_color = X_COLOR, j_hat_color = Y_COLOR) {
      VGroup(Vector(c(1, 0), color = i_hat_color, stroke_width = self$basis_vector_stroke_width),
             Vector(c(0, 1), color = j_hat_color, stroke_width = self$basis_vector_stroke_width))
    },
    get_basis_vector_labels = function(...) {
      bv <- self$get_basis_vectors()
      VGroup(self$get_vector_label(bv[1], "\\hat{\\imath}", color = X_COLOR, label_scale_factor = 1, ...),
             self$get_vector_label(bv[2], "\\hat{\\jmath}", color = Y_COLOR, label_scale_factor = 1, ...))
    },
    get_vector_label = function(vector, label, at_tip = FALSE, direction = "left", rotate = FALSE,
                                color = NULL, label_scale_factor = LARGE_BUFF - 0.2) {
      if (is.character(label)) {
        if (nchar(label) == 1) label <- sprintf("\\vec{\\textbf{%s}}", label)
        label <- MathTex(label)
        label$set_color(color %||% vector$get_color())
      }
      label$scale(label_scale_factor)
      label$add_background_rectangle()
      if (at_tip) {
        vect <- vector$get_vector()
        vect <- vect / get_norm(vect)
        label$next_to(vector$get_end(), vect, buff = SMALL_BUFF)
      } else {
        angle <- vector$get_angle()
        if (!rotate) label$rotate(-angle, about_point = ORIGIN)
        if (direction == "left") label$shift(-label$get_bottom() + 0.1 * UP)
        else label$shift(-label$get_top() + 0.1 * DOWN)
        label$rotate(angle, about_point = ORIGIN)
        label$shift((vector$get_end() - vector$get_start()) / 2)
      }
      label
    },
    label_vector = function(vector, label, animate = TRUE, ...) {
      lab <- self$get_vector_label(vector, label, ...)
      if (animate) self$play(Write(lab, run_time = 1))
      self$add(lab)
      lab
    },
    position_x_coordinate = function(x_coord, x_line, vector) {
      x_coord$next_to(x_line, -sign(vector[2]) * UP)
      x_coord$set_color(X_COLOR)
      x_coord
    },
    position_y_coordinate = function(y_coord, y_line, vector) {
      y_coord$next_to(y_line, sign(vector[1]) * RIGHT)
      y_coord$set_color(Y_COLOR)
      y_coord
    },
    coords_to_vector = function(vector, coords_start = 2 * RIGHT + 2 * UP, clean_up = TRUE) {
      starting <- self$mobjects
      array <- Matrix(matrix(vector, ncol = 1))
      array$shift(coords_start)
      arrow <- Vector(vector)
      x_line <- Line(ORIGIN, vector[1] * RIGHT)
      y_line <- Line(x_line$get_end(), arrow$get_end())
      x_line$set_color(X_COLOR)
      y_line$set_color(Y_COLOR)
      mm <- array$get_mob_matrix()
      x_coord <- mm[[1]][[1]]
      y_coord <- mm[[2]][[1]]
      self$play(Write(array, run_time = 1))
      self$wait()
      self$play(ApplyFunction(function(x) self$position_x_coordinate(x, x_line, vector), x_coord))
      self$play(Create(x_line))
      self$play(ApplyFunction(function(y) self$position_y_coordinate(y, y_line, vector), y_coord),
                FadeOut(array$get_brackets()))
      self$play(Create(y_line))
      self$play(Create(arrow))
      self$wait()
      if (clean_up) {
        self$clear()
        self$add(starting)
      }
      invisible(self)
    },
    vector_to_coords = function(vector, integer_labels = TRUE, clean_up = TRUE) {
      starting <- self$mobjects
      show_creation <- FALSE
      if (inherits(vector, "Arrow")) {
        arrow <- vector
        vector <- arrow$get_end()[1:2]
      } else {
        arrow <- Vector(vector)
        show_creation <- TRUE
      }
      array <- arrow$coordinate_label(integer_labels = integer_labels)
      x_line <- Line(ORIGIN, vector[1] * RIGHT)
      y_line <- Line(x_line$get_end(), arrow$get_end())
      x_line$set_color(X_COLOR)
      y_line$set_color(Y_COLOR)
      entries <- array$get_entries()
      x_coord <- entries$submobjects[[1]]
      y_coord <- entries$submobjects[[2]]
      x_start <- self$position_x_coordinate(x_coord$copy(), x_line, vector)
      y_start <- self$position_y_coordinate(y_coord$copy(), y_line, vector)
      brackets <- array$get_brackets()
      if (show_creation) self$play(Create(arrow))
      self$play(Create(x_line), Write(x_start), run_time = 1)
      self$play(Create(y_line), Write(y_start), run_time = 1)
      self$wait()
      self$play(Transform(x_start, x_coord, lag_ratio = 0), Transform(y_start, y_coord, lag_ratio = 0),
                Write(brackets, run_time = 1))
      self$wait()
      self$remove(x_start, y_start, brackets)
      self$add(array)
      if (clean_up) {
        self$clear()
        self$add(starting)
      }
      list(array, x_line, y_line)
    },
    show_ghost_movement = function(vector) {
      v <- if (inherits(vector, "Arrow")) vector$get_end() - vector$get_start() else as_point(vector)
      x_max <- as.integer(frame_x_radius() + abs(v[1]))
      y_max <- as.integer(frame_y_radius() + abs(v[2]))
      dots <- VMobject()
      for (x in (-x_max):(x_max - 1)) for (y in (-y_max):(y_max - 1)) dots$add(Dot(x * RIGHT + y * UP))
      dots$set_fill("#000000", opacity = 0)
      halfway <- dots$copy()$shift(v / 2)$set_fill("#FFFFFF", 1)
      end <- dots$copy()$shift(v)
      self$play(Transform(dots, halfway, rate_func = rush_into))
      self$play(Transform(dots, end, rate_func = rush_from))
      self$remove(dots)
      invisible(self)
    }
  )
)

merge_recursive <- function(default, passed) {
  if (is.null(passed)) return(default)
  for (k in names(passed)) {
    if (is.list(default[[k]]) && is.list(passed[[k]])) default[[k]] <- merge_recursive(default[[k]], passed[[k]])
    else default[k] <- list(passed[[k]])
  }
  default
}

#' @rdname VectorScene
#' @format NULL
#' @usage NULL
#' @export
LinearTransformationScene <- R6::R6Class("LinearTransformationScene", inherit = VectorScene, lock_objects = FALSE,
  public = list(
    include_background_plane = TRUE,
    include_foreground_plane = TRUE,
    show_coordinates = FALSE,
    show_basis_vectors = TRUE,
    i_hat_color = NULL,
    j_hat_color = NULL,
    leave_ghost_vectors = FALSE,
    background_plane_kwargs = NULL,
    foreground_plane_kwargs = NULL,
    ghost_vectors = NULL,
    has_already_setup = FALSE,
    background_mobjects = NULL,
    transformable_mobjects = NULL,
    moving_vectors = NULL,
    transformable_labels = NULL,
    transform_moving_mobjects = NULL,
    background_plane = NULL,
    basis_vectors = NULL,
    i_hat = NULL,
    j_hat = NULL,
    square = NULL,
    title = NULL,
    initialize = function(include_background_plane = TRUE, include_foreground_plane = TRUE,
                          background_plane_kwargs = NULL, foreground_plane_kwargs = NULL,
                          show_coordinates = FALSE, show_basis_vectors = TRUE, basis_vector_stroke_width = 6,
                          i_hat_color = X_COLOR, j_hat_color = Y_COLOR, leave_ghost_vectors = FALSE, ...) {
      super$initialize(basis_vector_stroke_width = basis_vector_stroke_width, ...)
      self$include_background_plane <- include_background_plane
      self$include_foreground_plane <- include_foreground_plane
      self$show_coordinates <- show_coordinates
      self$show_basis_vectors <- show_basis_vectors
      self$i_hat_color <- manim_color(i_hat_color)
      self$j_hat_color <- manim_color(j_hat_color)
      self$leave_ghost_vectors <- leave_ghost_vectors
      self$background_plane_kwargs <- merge_recursive(list(
        color = GREY, axis_config = list(color = GREY),
        background_line_style = list(stroke_color = GREY, stroke_width = 1)
      ), background_plane_kwargs)
      self$ghost_vectors <- VGroup()
      fw <- frame_width()
      self$foreground_plane_kwargs <- merge_recursive(list(
        x_range = c(-fw, fw, 1), y_range = c(-fw, fw, 1), faded_line_ratio = 1
      ), foreground_plane_kwargs)
    },
    # Merges each passed config into its default (named lists), as upstream;
    # R lists are values, so the merged defaults are returned.
    update_default_configs = function(default_configs, passed_configs) {
      Map(function(d, p) if (is.null(p)) d else merge_dicts_recursively(d, p), default_configs, passed_configs)
    },
    setup = function() {
      if (self$has_already_setup) return(invisible(self))
      self$has_already_setup <- TRUE
      self$background_mobjects <- list()
      self$foreground_mobjects <- list()
      self$transformable_mobjects <- list()
      self$moving_vectors <- list()
      self$transformable_labels <- list()
      self$transform_moving_mobjects <- list()
      self$background_plane <- do.call(NumberPlane, self$background_plane_kwargs)
      if (self$show_coordinates) self$background_plane$add_coordinates()
      if (self$include_background_plane) self$add_background_mobject(self$background_plane)
      if (self$include_foreground_plane) {
        self$plane <- do.call(NumberPlane, self$foreground_plane_kwargs)
        self$add_transformable_mobject(self$plane)
      }
      if (self$show_basis_vectors) {
        self$basis_vectors <- self$get_basis_vectors(i_hat_color = self$i_hat_color, j_hat_color = self$j_hat_color)
        self$moving_vectors <- c(self$moving_vectors, self$basis_vectors$submobjects)
        self$i_hat <- self$basis_vectors$submobjects[[1]]
        self$j_hat <- self$basis_vectors$submobjects[[2]]
        self$add(self$basis_vectors)
      }
      invisible(self)
    },
    add_special_mobjects = function(list_name, ...) {
      for (m in flatten_mobjects(list(...))) {
        ids <- vapply(self[[list_name]], function(x) x$mob_id, "")
        if (!m$mob_id %in% ids) {
          self[[list_name]] <- c(self[[list_name]], list(m))
          self$add(m)
        }
      }
      invisible(self)
    },
    add_background_mobject = function(...) self$add_special_mobjects("background_mobjects", ...),
    add_foreground_mobject = function(...) self$add_special_mobjects("foreground_mobjects", ...),
    add_transformable_mobject = function(...) self$add_special_mobjects("transformable_mobjects", ...),
    add_moving_mobject = function(mobject, target_mobject = NULL) {
      mobject$target <- target_mobject
      self$add_special_mobjects("transform_moving_mobjects", mobject)
    },
    get_ghost_vectors = function() self$ghost_vectors,
    get_unit_square = function(color = PURE_YELLOW, opacity = 0.3, stroke_width = 3) {
      sq <- Rectangle(color = color, width = self$plane$get_x_unit_size(), height = self$plane$get_y_unit_size(),
                      stroke_color = color, stroke_width = stroke_width, fill_color = color, fill_opacity = opacity)
      sq$move_to(self$plane$coords_to_point(0, 0), DL)
      self$square <- sq
      sq
    },
    add_unit_square = function(animate = FALSE, ...) {
      sq <- self$get_unit_square(...)
      if (animate) self$play(DrawBorderThenFill(sq), Animation(do.call(Group, self$moving_vectors)))
      self$add_transformable_mobject(sq)
      self$bring_to_front(self$moving_vectors)
      self$square <- sq
      invisible(self)
    },
    add_vector = function(vector, color = PURE_YELLOW, animate = FALSE, ...) {
      v <- super$add_vector(vector, color = color, animate = animate, ...)
      self$moving_vectors <- c(self$moving_vectors, list(v))
      v
    },
    write_vector_coordinates = function(vector, ...) {
      coords <- super$write_vector_coordinates(vector, ...)
      self$add_foreground_mobject(coords)
      coords
    },
    add_transformable_label = function(vector, label, transformation_name = "L", new_label = NULL, ...) {
      lab <- self$label_vector(vector, label, ...)
      lab$target_text <- new_label %||% sprintf("%s(%s)", transformation_name, lab$get_tex_string())
      lab$vector <- vector
      kw <- list(...)
      kw$animate <- NULL
      lab$label_kwargs <- kw
      self$transformable_labels <- c(self$transformable_labels, list(lab))
      lab
    },
    add_title = function(title, scale_factor = 1.5, animate = FALSE) {
      if (!is_mobject(title)) title <- Tex(title)$scale(scale_factor)
      title$to_edge(UP)
      title$add_background_rectangle()
      if (animate) self$play(Write(title))
      self$add_foreground_mobject(title)
      self$title <- title
      invisible(self)
    },
    get_matrix_transformation = function(matrix) self$get_transposed_matrix_transformation(t(as.matrix(matrix))),
    get_transposed_matrix_transformation = function(transposed_matrix) {
      tm <- as.matrix(transposed_matrix)
      if (all(dim(tm) == c(2, 2))) {
        full <- diag(3)
        full[1:2, 1:2] <- tm
        tm <- full
      } else if (!all(dim(tm) == c(3, 3))) {
        stop("Matrix has bad dimensions", call. = FALSE)
      }
      function(point) drop(as_point(point) %*% tm)
    },
    get_piece_movement = function(pieces) {
      vp <- Filter(is_vmobject, pieces)
      start <- VGroup(vp)
      target <- VGroup(lapply(vp, function(m) m$target))
      if (self$leave_ghost_vectors && length(start$submobjects)) {
        ghost <- start$copy()$fade(0.7)
        self$ghost_vectors$add(ghost)
        self$add(ghost)
      }
      Transform(start, target, lag_ratio = 0)
    },
    get_moving_mobject_movement = function(func) {
      for (m in self$transform_moving_mobjects) {
        if (is.null(m$target)) m$target <- m$copy()
        m$target$move_to(func(m$get_center()))
      }
      self$get_piece_movement(self$transform_moving_mobjects)
    },
    get_vector_movement = function(func) {
      for (v in self$moving_vectors) {
        v$target <- Vector(func(v$get_end()), color = v$get_color())
        nrm <- get_norm(v$target$get_end())
        if (nrm < 0.1) v$target$get_tip()$scale(nrm)
      }
      self$get_piece_movement(self$moving_vectors)
    },
    get_transformable_label_movement = function() {
      for (lab in self$transformable_labels) {
        lab$target <- do.call(self$get_vector_label, c(list(lab$vector$target, lab$target_text), lab$label_kwargs))
      }
      self$get_piece_movement(self$transformable_labels)
    },
    apply_matrix = function(matrix, ...) self$apply_transposed_matrix(t(as.matrix(matrix)), ...),
    apply_inverse = function(matrix, ...) self$apply_matrix(solve(as.matrix(matrix)), ...),
    apply_transposed_matrix = function(transposed_matrix, ...) {
      func <- self$get_transposed_matrix_transformation(transposed_matrix)
      kw <- list(...)
      if (is.null(kw$path_arc)) {
        kw$path_arc <- mean(c(angle_of_vector(func(RIGHT)), angle_of_vector(func(UP)) - pi / 2))
      }
      do.call(self$apply_function, c(list(func), kw))
    },
    apply_inverse_transpose = function(t_matrix, ...) {
      t_inv <- t(solve(t(as.matrix(t_matrix))))
      self$apply_transposed_matrix(t_inv, ...)
    },
    apply_nonlinear_transformation = function(fn, ...) {
      self$plane$prepare_for_nonlinear_transform()
      self$apply_function(fn, ...)
    },
    apply_function = function(fn, added_anims = list(), ...) {
      kw <- list(...)
      if (is.null(kw$run_time)) kw$run_time <- 3
      anims <- c(
        lapply(self$transformable_mobjects, function(m) ApplyPointwiseFunction(fn, m)),
        list(self$get_vector_movement(fn), self$get_transformable_label_movement(),
             self$get_moving_mobject_movement(fn)),
        lapply(self$foreground_mobjects, function(m) Animation(m)),
        added_anims
      )
      do.call(self$play, c(anims, kw))
    }
  )
)
