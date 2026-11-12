# Function graphs

`ParametricFunction()` traces a curve `t -> c(x(t), y(t), z(t))`.
`FunctionGraph()` plots `y = f(x)` in scene coordinates across the
frame. `ImplicitFunction()` draws the zero set of `f(x, y)`.

## Usage

``` r
ParametricFunction(
  func,
  t_range = c(0, 1),
  scaling = LinearBase(),
  dt = 1e-08,
  discontinuities = NULL,
  use_smoothing = TRUE,
  use_vectorized = FALSE,
  ...
)

FunctionGraph(func, x_range = NULL, color = PURE_YELLOW, ...)

ImplicitFunction(
  func,
  x_range = NULL,
  y_range = NULL,
  min_depth = 5,
  max_quads = 1500,
  use_smoothing = TRUE,
  ...
)
```

## Arguments

- func:

  For `ParametricFunction()`, a function of `t` returning 2 or 3
  coordinates. For `ImplicitFunction()`, a function of `x` and `y`.

- t_range:

  `c(t_min, t_max, t_step)`; the step defaults to 0.01.

- scaling:

  Scale applied to the sampled `t` values; see
  [`LinearBase()`](https://adamrsophie.github.io/manimR/reference/graph_scale.md).

- dt:

  Gap left on each side of a discontinuity.

- discontinuities:

  Values of `t` where the curve is broken.

- use_smoothing:

  Whether to smooth the sampled polyline.

- use_vectorized:

  Whether `func` accepts a vector of `t` values. Like upstream, it must
  then return coordinate rows: a 2 x n or 3 x n matrix such as
  `rbind(cos(t), sin(t), 0)`, or `list(x, y)` or `list(x, y, z)`. A
  matrix with one point per row is accepted only when its shape cannot
  be read as coordinate rows.

- ...:

  Passed to
  [`VMobject()`](https://adamrsophie.github.io/manimR/reference/VMobjectClass.md).

- x_range, y_range:

  Ranges of the variables.

- color:

  Color.

- min_depth, max_quads:

  The implicit curve is traced on a grid of cells that are split
  `min_depth` times everywhere and then further where the function
  changes sign, up to `max_quads` cells (the adaptive method of the
  `isosurfaces` Python package, as upstream).

## Value

A mobject.

## Details

The point function of a graph is stored in the field `func` (upstream
calls it `function`, a reserved word in R); `get_function()` returns it.

## Examples

``` r
ParametricFunction(function(t) c(sin(2 * t), sin(3 * t), 0), t_range = c(0, TAU))
#> <ParametricFunction> 2516 points, 0 submobjects
FunctionGraph(cos, color = RED)
#> <FunctionGraph> 5692 points, 0 submobjects
ImplicitFunction(function(x, y) x^2 + y^2 - 4)
#> <ImplicitFunction> 2784 points, 0 submobjects
```
