# Geometry mobjects

Constructors for basic shapes. Each `Foo()` function creates an object
of the R6 class `FooClass`, whose generator is exported for subclassing.
Arguments mirror Manim; unlisted arguments in `...` are passed on to
[`VMobject()`](https://adamrsophie.github.io/manimR/reference/VMobjectClass.md)
(for example `color`, `fill_opacity`, `stroke_width`).

## Usage

``` r
Arc(
  radius = 1,
  start_angle = 0,
  angle = TAU/4,
  num_components = 9,
  arc_center = ORIGIN,
  ...
)

ArcBetweenPoints(start, end, angle = TAU/4, radius = NULL, ...)

CurvedArrow(start_point, end_point, tip_shape = NULL, ...)

CurvedDoubleArrow(
  start_point,
  end_point,
  tip_shape_start = NULL,
  tip_shape_end = NULL,
  ...
)

Circle(radius = NULL, color = "#FC6255", ...)

circle_from_three_points(p1, p2, p3, ...)

Dot(
  point = ORIGIN,
  radius = DEFAULT_DOT_RADIUS,
  stroke_width = 0,
  fill_opacity = 1,
  color = "#FFFFFF",
  ...
)

AnnotationDot(
  radius = DEFAULT_DOT_RADIUS * 1.3,
  stroke_width = 5,
  stroke_color = "#FFFFFF",
  fill_color = BLUE,
  ...
)

LabeledDot(label, radius = NULL, buff = SMALL_BUFF, ...)

Ellipse(width = 2, height = 1, ...)

AnnularSector(
  inner_radius = 1,
  outer_radius = 2,
  angle = TAU/4,
  start_angle = 0,
  fill_opacity = 1,
  stroke_width = 0,
  color = "#FFFFFF",
  ...
)

Sector(radius = 1, ...)

Annulus(
  inner_radius = 1,
  outer_radius = 2,
  fill_opacity = 1,
  stroke_width = 0,
  color = "#FFFFFF",
  mark_paths_closed = FALSE,
  ...
)

CubicBezier(start_anchor, start_handle, end_handle, end_anchor, ...)

ArcPolygon(..., angle = PI/4, radius = NULL, arc_config = NULL)

ArcPolygonFromArcs(...)

Line(start = LEFT, end = RIGHT, buff = 0, path_arc = 0, ...)

DashedLine(..., dash_length = DEFAULT_DASH_LENGTH, dashed_ratio = 0.5)

TangentLine(vmob, alpha, length = 1, d_alpha = 1e-06, ...)

Elbow(width = 0.2, angle = 0, ...)

Arrow(
  ...,
  stroke_width = 6,
  buff = MED_SMALL_BUFF,
  max_tip_length_to_length_ratio = 0.25,
  max_stroke_width_to_length_ratio = 5,
  tip_shape = NULL
)

Vector(direction = RIGHT, buff = 0, ...)

DoubleArrow(..., tip_shape_start = NULL, tip_shape_end = NULL)

Angle(
  line1,
  line2,
  radius = NULL,
  quadrant = c(1, 1),
  other_angle = FALSE,
  dot = FALSE,
  dot_radius = NULL,
  dot_distance = 0.55,
  dot_color = "#FFFFFF",
  elbow = FALSE,
  ...
)

angle_from_three_points(A, B, C, ...)

RightAngle(line1, line2, length = NULL, ...)

Polygram(..., color = BLUE)

Polygon(...)

RegularPolygram(num_vertices, density = 2, radius = 1, start_angle = NULL, ...)

RegularPolygon(n = 6, ...)

Triangle(...)

Star(
  n = 5,
  outer_radius = 1,
  inner_radius = NULL,
  density = 2,
  start_angle = TAU/4,
  ...
)

Rectangle(
  color = "#FFFFFF",
  height = 2,
  width = 4,
  grid_xstep = NULL,
  grid_ystep = NULL,
  mark_paths_closed = TRUE,
  close_new_points = TRUE,
  ...
)

Square(side_length = 2, ...)

RoundedRectangle(corner_radius = 0.5, ...)

Cutout(main_shape, ...)

ConvexHull(..., tolerance = 1e-05)

SurroundingRectangle(
  ...,
  color = PURE_YELLOW,
  buff = SMALL_BUFF,
  corner_radius = 0
)

BackgroundRectangle(
  ...,
  color = NULL,
  stroke_width = 0,
  stroke_opacity = 0,
  fill_opacity = 0.75,
  buff = 0
)

Cross(
  mobject = NULL,
  stroke_color = "#FC6255",
  stroke_width = 6,
  scale_factor = 1,
  ...
)

Underline(mobject, buff = SMALL_BUFF, ...)

TangentialArc(line1, line2, radius, corner = c(1, 1), ...)

TipableVMobject(
  tip_length = DEFAULT_ARROW_TIP_LENGTH,
  normal_vector = OUT,
  tip_style = NULL,
  ...
)

ArrowTip(...)

ArrowTriangleTip(
  fill_opacity = 0,
  stroke_width = 3,
  length = DEFAULT_ARROW_TIP_LENGTH,
  width = DEFAULT_ARROW_TIP_LENGTH,
  start_angle = PI,
  ...
)

ArrowTriangleFilledTip(fill_opacity = 1, stroke_width = 0, ...)

ArrowCircleTip(
  fill_opacity = 0,
  stroke_width = 3,
  length = DEFAULT_ARROW_TIP_LENGTH,
  start_angle = PI,
  ...
)

ArrowCircleFilledTip(fill_opacity = 1, stroke_width = 0, ...)

ArrowSquareTip(
  fill_opacity = 0,
  stroke_width = 3,
  length = DEFAULT_ARROW_TIP_LENGTH,
  start_angle = PI,
  ...
)

ArrowSquareFilledTip(fill_opacity = 1, stroke_width = 0, ...)

StealthTip(
  fill_opacity = 1,
  stroke_width = 3,
  length = DEFAULT_ARROW_TIP_LENGTH/2,
  start_angle = PI,
  ...
)
```

## Arguments

- radius:

  Radius.

- start_angle:

  Starting angle.

- angle:

  Angle.

- num_components:

  Number of anchor points used to approximate an arc.

- arc_center:

  Center of the arc.

- ...:

  Arguments passed to the class initializer.

- start, end:

  Start and end points of a line or arc.

- start_point, end_point:

  Endpoints.

- tip_shape, tip_shape_start, tip_shape_end:

  Tip classes such as `ArrowTriangleTipClass`.

- color, fill_color, fill_opacity, stroke_opacity:

  Color, fill color, fill opacity and stroke opacity of the shape.

- p1, p2, p3:

  Points on the circle.

- point:

  Location of the dot's center.

- stroke_color, stroke_width:

  Stroke style.

- label:

  A string (rendered with
  [`MathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md))
  or a mobject.

- buff:

  Buffer.

- width:

  Width.

- height:

  Height of the shape.

- outer_radius, inner_radius:

  Radii.

- mark_paths_closed, close_new_points:

  Treat the outline as a closed path.

- start_anchor, start_handle, end_handle, end_anchor:

  Bezier control points.

- arc_config:

  List of argument lists, one per arc.

- path_arc:

  Angle of the arc a line bends along; 0 gives a straight line.

- dash_length, dashed_ratio:

  Length of each dash, and the fraction of the line covered by dashes
  rather than gaps.

- vmob:

  A VMobject.

- alpha:

  Proportion along `vmob`.

- length:

  Length.

- d_alpha:

  Step used to estimate the tangent.

- max_tip_length_to_length_ratio, max_stroke_width_to_length_ratio:

  Upper bounds on the tip length and the stroke width relative to the
  arrow length, so short arrows stay well proportioned.

- direction:

  Direction of the vector.

- line1, line2:

  Lines.

- quadrant:

  Pair of `1` or `-1` choosing, for each line, whether the angle is
  measured toward its end (`1`) or its start (`-1`).

- other_angle:

  Draw the reflex angle, going clockwise, instead.

- dot, dot_radius, dot_distance, dot_color:

  Whether to mark the angle with a dot, the dot's radius, its distance
  from the vertex as a fraction of the radius, and its color.

- elbow:

  Draw a right angle elbow instead of an arc.

- A, B, C:

  Points; the angle is at `B`.

- num_vertices:

  Number of vertices of the regular polygram.

- density:

  Density of the star.

- n:

  Number of points.

- grid_xstep, grid_ystep:

  Spacing of optional grid lines drawn inside the rectangle; `NULL`
  draws none.

- side_length:

  Side length of the square.

- corner_radius:

  Radius of the rounded corners.

- main_shape:

  Shape to cut holes into.

- tolerance:

  For `ConvexHull()`: a point closer than this to an edge of the hull is
  not one of its vertices.

- mobject:

  A mobject.

- scale_factor:

  Scale factor.

- corner:

  Which corner between the lines, as `c(1, 1)` and so on.

- tip_length:

  Length of tips added with `add_tip()`.

- normal_vector:

  Normal of the plane tips are drawn in.

- tip_style:

  List of style arguments for added tips.

## Value

A mobject.

## Examples

``` r
Circle(radius = 2, color = BLUE)
#> <Circle> 32 points, 0 submobjects
Square(side_length = 1)$shift(LEFT)
Arrow(LEFT, RIGHT)
#> <Arrow> 4 points, 1 submobjects
Polygon(c(-1, 0, 0), c(1, 0, 0), c(0, 1, 0))
#> <Polygon> 12 points, 0 submobjects
```
