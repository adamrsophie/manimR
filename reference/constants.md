# Direction vectors and numeric constants

Unit vectors used to position and move mobjects, plus common numeric
constants. Directions are length 3 numeric vectors `c(x, y, z)`.

## Usage

``` r
ORIGIN

UP

DOWN

RIGHT

LEFT

IN

OUT

X_AXIS

Y_AXIS

Z_AXIS

UL

UR

DL

DR

PI

TAU

DEGREES

SMALL_BUFF

MED_SMALL_BUFF

MED_LARGE_BUFF

LARGE_BUFF

DEFAULT_MOBJECT_TO_EDGE_BUFFER

DEFAULT_MOBJECT_TO_MOBJECT_BUFFER

DEFAULT_STROKE_WIDTH

DEFAULT_FONT_SIZE

DEFAULT_DOT_RADIUS

DEFAULT_SMALL_DOT_RADIUS

DEFAULT_DASH_LENGTH

DEFAULT_ARROW_TIP_LENGTH

DEFAULT_WAIT_TIME

DEFAULT_POINTWISE_FUNCTION_RUN_TIME

SCALE_FACTOR_PER_FONT_POINT

DEFAULT_POINT_DENSITY_1D

DEFAULT_POINT_DENSITY_2D
```

## Value

Numeric vectors of length 3 for the origin and the directions, and
single numbers for the other constants.

## Examples

``` r
Square()$shift(2 * RIGHT + UP)
```
