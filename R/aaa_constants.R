# Constants ported from manim/constants.py.

#' Direction vectors and numeric constants
#'
#' Unit vectors used to position and move mobjects, plus common numeric
#' constants. Directions are length 3 numeric vectors `c(x, y, z)`.
#'
#' @return Numeric vectors of length 3 for the origin and the directions, and
#'   single numbers for the other constants.
#' @name constants
#' @examples
#' Square()$shift(2 * RIGHT + UP)
NULL

#' @rdname constants
#' @export
ORIGIN <- c(0, 0, 0)
#' @rdname constants
#' @export
UP <- c(0, 1, 0)
#' @rdname constants
#' @export
DOWN <- c(0, -1, 0)
#' @rdname constants
#' @export
RIGHT <- c(1, 0, 0)
#' @rdname constants
#' @export
LEFT <- c(-1, 0, 0)
#' @rdname constants
#' @export
IN <- c(0, 0, -1)
#' @rdname constants
#' @export
OUT <- c(0, 0, 1)
#' @rdname constants
#' @export
X_AXIS <- c(1, 0, 0)
#' @rdname constants
#' @export
Y_AXIS <- c(0, 1, 0)
#' @rdname constants
#' @export
Z_AXIS <- c(0, 0, 1)
#' @rdname constants
#' @export
UL <- UP + LEFT
#' @rdname constants
#' @export
UR <- UP + RIGHT
#' @rdname constants
#' @export
DL <- DOWN + LEFT
#' @rdname constants
#' @export
DR <- DOWN + RIGHT

#' @rdname constants
#' @export
PI <- pi
#' @rdname constants
#' @export
TAU <- 2 * pi
#' @rdname constants
#' @export
DEGREES <- TAU / 360

#' @rdname constants
#' @export
SMALL_BUFF <- 0.1
#' @rdname constants
#' @export
MED_SMALL_BUFF <- 0.25
#' @rdname constants
#' @export
MED_LARGE_BUFF <- 0.5
#' @rdname constants
#' @export
LARGE_BUFF <- 1
#' @rdname constants
#' @export
DEFAULT_MOBJECT_TO_EDGE_BUFFER <- MED_LARGE_BUFF
#' @rdname constants
#' @export
DEFAULT_MOBJECT_TO_MOBJECT_BUFFER <- MED_SMALL_BUFF
#' @rdname constants
#' @export
DEFAULT_STROKE_WIDTH <- 4
#' @rdname constants
#' @export
DEFAULT_FONT_SIZE <- 48
#' @rdname constants
#' @export
DEFAULT_DOT_RADIUS <- 0.08
#' @rdname constants
#' @export
DEFAULT_SMALL_DOT_RADIUS <- 0.04
#' @rdname constants
#' @export
DEFAULT_DASH_LENGTH <- 0.05
#' @rdname constants
#' @export
DEFAULT_ARROW_TIP_LENGTH <- 0.35
#' @rdname constants
#' @export
DEFAULT_ARROW_TIP_WIDTH <- 0.35
#' @rdname constants
#' @export
DEFAULT_WAIT_TIME <- 1
#' @rdname constants
#' @export
DEFAULT_POINTWISE_FUNCTION_RUN_TIME <- 3
#' @rdname constants
#' @export
SCALE_FACTOR_PER_FONT_POINT <- 1 / 960

#' @rdname constants
#' @export
DEFAULT_POINT_DENSITY_1D <- 10
#' @rdname constants
#' @export
DEFAULT_POINT_DENSITY_2D <- 25

#' Section types
#'
#' Upstream's `DefaultSectionType`, for the `section_type` argument of a
#' scene's `next_section()`: `self$next_section("intro", DefaultSectionType$NORMAL)`.
#' Any string works; the type is written to the sections index for tools
#' such as presentation players.
#'
#' @return A named list of section type names.
#' @format A named list of strings.
#' @export
DefaultSectionType <- list(NORMAL = "default.normal")

#' Font styles, weights and stroke styles
#'
#' Upstream's string constants for `Text(slant = , weight = )`, such as
#' `Text("Hi", weight = BOLD)`, and its `LineJointType` and `CapStyleType`
#' enumerations as named lists of the strings `joint_type` and `cap_style`
#' accept: `Square(joint_type = LineJointType$ROUND)`.
#'
#' @return Character strings that name font slants and weights. `LineJointType`
#'   and `CapStyleType` are named lists of stroke styles.
#' @name font_constants
#' @format Character strings, or named lists of character strings.
#' @export
NORMAL <- "NORMAL"
#' @rdname font_constants
#' @export
ITALIC <- "ITALIC"
#' @rdname font_constants
#' @export
OBLIQUE <- "OBLIQUE"
#' @rdname font_constants
#' @export
BOLD <- "BOLD"
#' @rdname font_constants
#' @export
THIN <- "THIN"
#' @rdname font_constants
#' @export
ULTRALIGHT <- "ULTRALIGHT"
#' @rdname font_constants
#' @export
LIGHT <- "LIGHT"
#' @rdname font_constants
#' @export
SEMILIGHT <- "SEMILIGHT"
#' @rdname font_constants
#' @export
BOOK <- "BOOK"
#' @rdname font_constants
#' @export
MEDIUM <- "MEDIUM"
#' @rdname font_constants
#' @export
SEMIBOLD <- "SEMIBOLD"
#' @rdname font_constants
#' @export
ULTRABOLD <- "ULTRABOLD"
#' @rdname font_constants
#' @export
HEAVY <- "HEAVY"
#' @rdname font_constants
#' @export
ULTRAHEAVY <- "ULTRAHEAVY"
#' @rdname font_constants
#' @export
LineJointType <- list(AUTO = "auto", ROUND = "round", BEVEL = "bevel", MITER = "miter")
#' @rdname font_constants
#' @export
CapStyleType <- list(AUTO = "auto", ROUND = "round", BUTT = "butt", SQUARE = "square")

#' Interface constants
#'
#' Upstream's command line messages (`SCENE_NOT_FOUND_MESSAGE` and so on,
#' with `{}` where upstream formats in a scene name), the help epilog and
#' context settings, the key codes of Shift and Ctrl used by interactive
#' scenes, the default window position (`START_X`, `START_Y`), and
#' `RendererType`, the values the `renderer` setting accepts.
#'
#' @return Character strings and numbers used by the command line and the
#'   interactive window. `CONTEXT_SETTINGS` and `RendererType` are named lists.
#' @format Strings, numbers, or named lists.
#' @name interface_constants
#' @export
SCENE_NOT_FOUND_MESSAGE <- "\n   {} is not in the script\n"
#' @rdname interface_constants
#' @export
CHOOSE_NUMBER_MESSAGE <- paste0("\nChoose number corresponding to desired scene/arguments.\n",
                                "(Use comma separated list for multiple entries or use \"*\" to select all scenes.)\n",
                                "Choice(s): ")
#' @rdname interface_constants
#' @export
INVALID_NUMBER_MESSAGE <- "Invalid scene numbers have been specified. Aborting."
#' @rdname interface_constants
#' @export
NO_SCENE_MESSAGE <- "\n   There are no scenes inside that module\n"
#' @rdname interface_constants
#' @export
EPILOG <- "Made with <3 by Manim Community developers."
#' @rdname interface_constants
#' @export
CONTEXT_SETTINGS <- list(align_option_groups = TRUE, align_sections = TRUE, show_constraints = TRUE)
#' @rdname interface_constants
#' @export
SHIFT_VALUE <- 65505
#' @rdname interface_constants
#' @export
CTRL_VALUE <- 65507
#' @rdname interface_constants
#' @export
START_X <- 30
#' @rdname interface_constants
#' @export
START_Y <- 20
#' @rdname interface_constants
#' @export
RendererType <- list(CAIRO = "cairo", OPENGL = "opengl")
