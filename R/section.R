# Scene sections, ported from manim/scene/section.py.

#' Scene sections
#'
#' A scene is split into sections with its `next_section()` method. Each
#' section records the partial movie files of the plays it contains
#' (`partial_movie_files`, with `NULL` for skipped plays, as upstream) and,
#' when `manim_config(save_sections = TRUE)`, the file name of its own video
#' (`video`, relative to the sections directory), which is joined from those
#' partial movie files.
#'
#' `$is_empty()` tells whether the section has no plays, `$get_dict()`
#' returns the entry written to the sections index (name, type, video and the
#' video's metadata from [get_video_metadata()], unless `metadata` is given).
#'
#' @param type_ Section type, see [DefaultSectionType].
#' @param video File name of the section's video, or `NULL` when the section
#'   is not saved.
#' @param name Section name.
#' @param skip_animations Skip rendering the animations of this section.
#' @return A `Section`, an R6 object that describes one section of a scene's
#'   output. `SectionClass` is its R6 class generator.
#' @name Section
#' @format NULL
#' @usage NULL
#' @examples
#' s <- Section(DefaultSectionType$NORMAL, NULL, "intro", FALSE)
#' s$is_empty()
#' @export
SectionClass <- R6::R6Class("Section", lock_objects = FALSE,
  public = list(
    type_ = NULL,
    video = NULL,
    name = NULL,
    skip_animations = FALSE,
    partial_movie_files = NULL,
    frames = 0,
    initialize = function(type_, video, name, skip_animations) {
      self$type_ <- type_
      self$video <- video
      self$name <- name
      self$skip_animations <- skip_animations
      self$partial_movie_files <- list()
    },
    is_empty = function() length(self$partial_movie_files) == 0,
    get_clean_partial_movie_files = function() {
      as.character(unlist(Filter(Negate(is.null), self$partial_movie_files)))
    },
    get_dict = function(sections_dir, metadata = NULL) {
      if (is.null(self$video)) {
        stop("Section '", self$name, "' cannot be exported as dict, it does not have a video path assigned to it",
             call. = FALSE)
      }
      metadata <- metadata %||% get_video_metadata(file.path(sections_dir, self$video))
      c(list(name = self$name, type = self$type_, video = self$video), metadata)
    },
    print = function(...) {
      cat("<Section '", self$name, "' stored in '", self$video %||% "None", "'>\n", sep = "")
      invisible(self)
    }
  )
)

#' @rdname Section
#' @export
Section <- constructor(SectionClass)

# One JSON object for the sections index; strings are quoted, numbers not.
json_object <- function(x, indent = "    ") {
  vals <- vapply(x, function(v) if (is.character(v)) json_string(v) else format(v, scientific = FALSE), "")
  paste0(indent, "{\n", paste0(indent, "    \"", names(x), "\": ", vals, collapse = ",\n"), "\n", indent, "}")
}
