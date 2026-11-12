# Color arithmetic

Color arithmetic

## Usage

``` r
interpolate_color(color1, color2, alpha)

color_gradient(reference_colors, length_of_output)

average_color(...)

invert_color(color)

lighter_color(color, blend = 0.2)

darker_color(color, blend = 0.2)

random_color()

random_bright_color()
```

## Arguments

- color1, color2, color:

  Colors.

- alpha:

  Interpolation parameter.

- reference_colors:

  Colors to pass through.

- length_of_output:

  Number of colors to return.

- ...:

  Colors.

- blend:

  Amount to blend toward white (`lighter_color`) or black
  (`darker_color`).

## Value

A color: a hex string, of class `ManimColor` where the function computes
it from other colors. `color_gradient()` returns a character vector of
`length_of_output` colors.

## Examples

``` r
interpolate_color(RED, BLUE, 0.5)
#> ManimColor('#AA9399')
color_gradient(c(RED, YELLOW, GREEN), 5)
#> [1] "#FC6255" "#F99D62" "#F7D96F" "#BDCD6B" "#83C167"
```
