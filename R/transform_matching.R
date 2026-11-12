# Transformations that keep track of matching parts.
# Ported from manim/animation/transform_matching_parts.py.

#' Transform matching parts
#'
#' These animations map the parts of `mobject` and `target_mobject` to keys
#' and transform parts with equal keys into each other.
#' `TransformMatchingShapes()` matches submobjects by shape (their points
#' after moving to the origin, scaling to height 1 and rounding to three
#' decimals); `TransformMatchingTex()` matches the parts of [MathTex()]
#' objects by their TeX strings.
#'
#' Unless `transform_mismatches` or `fade_transform_mismatches` is `TRUE`,
#' unmatched parts of the source fade out toward the unmatched target parts,
#' and unmatched target parts fade in from there.
#'
#' @param mobject The starting mobject.
#' @param target_mobject The target mobject.
#' @param ... Named arguments: `transform_mismatches`, to transform unmatched
#'   parts into each other with [Transform()]; `fade_transform_mismatches`, to
#'   transform them with [FadeTransformPieces()]; `key_map`, an optional named
#'   character vector or list mapping keys of source parts to keys of target
#'   parts that should be transformed into each other although they differ
#'   (useful with `TransformMatchingTex()`); and arguments passed to the part
#'   animations, for example `path_arc` or `run_time`.
#' @name transform_matching
#' @examples
#' \dontrun{
#' Anagram <- manim_scene(function(self) {
#'   src <- Text("the morse code")
#'   tar <- Text("here come dots")
#'   self$play(Write(src))
#'   self$wait(0.5)
#'   self$play(TransformMatchingShapes(src, tar, path_arc = PI / 2))
#'   self$wait(0.5)
#' })
#' }
NULL

#' @rdname transform_matching
#' @format NULL
#' @usage NULL
#' @export
TransformMatchingAbstractBaseClass <- R6::R6Class("TransformMatchingAbstractBase", inherit = AnimationGroupClass,
  lock_objects = FALSE,
  public = list(
    to_remove = NULL,
    to_add = NULL,
    initialize = function(mobject, target_mobject, transform_mismatches = FALSE, fade_transform_mismatches = FALSE,
                          key_map = NULL, ...) {
      kwargs <- list(...)
      group_type <- if (is_vmobject(mobject)) VGroup else Group
      source_map <- self$get_shape_map(mobject)
      target_map <- self$get_shape_map(target_mobject)
      key_map <- as.list(key_map %||% list())

      # Two groups whose submobjects all match each other.
      transform_source <- group_type()
      transform_target <- group_type()
      for (key in intersect(names(source_map), names(target_map))) {
        transform_source$add(source_map[[key]])
        transform_target$add(target_map[[key]])
      }
      anims <- list(do.call(Transform, c(list(transform_source, transform_target), kwargs)))

      # Parts the user asked to transform into each other despite their keys.
      key_mapped_source <- group_type()
      key_mapped_target <- group_type()
      for (key1 in names(key_map)) {
        key2 <- as.character(key_map[[key1]])
        if (!is.null(source_map[[key1]]) && !is.null(target_map[[key2]])) {
          key_mapped_source$add(source_map[[key1]])
          key_mapped_target$add(target_map[[key2]])
          source_map[[key1]] <- NULL
          target_map[[key2]] <- NULL
        }
      }
      if (length(key_mapped_source$submobjects) > 0) {
        anims[[length(anims) + 1]] <- do.call(FadeTransformPieces, c(list(key_mapped_source, key_mapped_target), kwargs))
      }

      fade_source <- group_type()
      fade_target <- group_type()
      for (key in setdiff(names(source_map), names(target_map))) fade_source$add(source_map[[key]])
      for (key in setdiff(names(target_map), names(source_map))) fade_target$add(target_map[[key]])
      fade_target_copy <- fade_target$copy()

      if (transform_mismatches) {
        if (is.null(kwargs$replace_mobject_with_target_in_scene)) kwargs$replace_mobject_with_target_in_scene <- TRUE
        anims[[length(anims) + 1]] <- do.call(Transform, c(list(fade_source, fade_target), kwargs))
      } else if (fade_transform_mismatches) {
        anims[[length(anims) + 1]] <- do.call(FadeTransformPieces, c(list(fade_source, fade_target), kwargs))
      } else {
        anims[[length(anims) + 1]] <- do.call(FadeOut, c(list(fade_source, target_position = fade_target), kwargs))
        anims[[length(anims) + 1]] <- do.call(FadeIn, c(list(fade_target_copy, target_position = fade_target), kwargs))
      }

      do.call(super$initialize, anims)
      self$to_remove <- list(mobject, fade_target_copy)
      self$to_add <- target_mobject
    },
    # Named list mapping keys to VGroups of the parts with that key, in the
    # order the keys first appear.
    get_shape_map = function(mobject) {
      shape_map <- list()
      for (sm in self$get_mobject_parts(mobject)) {
        key <- self$get_mobject_key(sm)
        if (is.null(shape_map[[key]])) shape_map[[key]] <- VGroup()
        shape_map[[key]]$add(sm)
      }
      shape_map
    },
    clean_up_from_scene = function(scene) {
      # Interpolate all animations back to 0 so the source mobjects stay unchanged.
      for (anim in self$animations) anim$interpolate(0)
      scene$remove(self$mobject)
      scene$remove(self$to_remove)
      scene$add(self$to_add)
      invisible(NULL)
    },
    get_mobject_parts = function(mobject) stop("To be implemented in subclass.", call. = FALSE),
    get_mobject_key = function(mobject) stop("To be implemented in subclass.", call. = FALSE)
  )
)

#' @rdname transform_matching
#' @format NULL
#' @usage NULL
#' @export
TransformMatchingShapesClass <- R6::R6Class("TransformMatchingShapes", inherit = TransformMatchingAbstractBaseClass,
  lock_objects = FALSE,
  public = list(
    get_mobject_parts = function(mobject) mobject$family_members_with_points(),
    get_mobject_key = function(mobject) {
      # Same normalization as upstream (center, then height 1, then round to
      # three decimals), computed without modifying the mobject.
      pts <- mobject$points
      ctr <- mobject$get_center()
      h <- mobject$height
      pts <- pts - rep(ctr, each = nrow(pts))
      if (h != 0) pts <- pts / h
      digest::digest(round(pts, 3) + 0, algo = "md5")
    }
  )
)

#' @rdname transform_matching
#' @export
TransformMatchingShapes <- function(mobject, target_mobject, ...) {
  ov <- animation_override("TransformMatchingShapes", mobject, match.call(), parent.frame())
  if (!is.null(ov)) return(ov$value)
  TransformMatchingShapesClass$new(mobject, target_mobject, ...)
}

#' @rdname transform_matching
#' @format NULL
#' @usage NULL
#' @export
TransformMatchingTexClass <- R6::R6Class("TransformMatchingTex", inherit = TransformMatchingAbstractBaseClass,
  lock_objects = FALSE,
  public = list(
    get_mobject_parts = function(mobject) {
      if (inherits(mobject, c("Group", "VGroup"))) {
        return(unlist(lapply(mobject$submobjects, self$get_mobject_parts), recursive = FALSE))
      }
      if (is.null(mobject$tex_string)) {
        stop("TransformMatchingTex needs MathTex or Tex mobjects (or groups of them).", call. = FALSE)
      }
      mobject$submobjects
    },
    get_mobject_key = function(mobject) {
      key <- mobject$tex_string
      if (is.null(key)) stop("TransformMatchingTex expects MathTex parts with a tex_string.", call. = FALSE)
      key
    }
  )
)

#' @rdname transform_matching
#' @export
TransformMatchingTex <- function(mobject, target_mobject, ...) {
  TransformMatchingTexClass$new(mobject, target_mobject, ...)
}
