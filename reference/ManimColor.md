# Colors as objects

`ManimColor()` is upstream's color class. Colors in manimR are hex
strings, so a `ManimColor` is a hex string that also carries its exact
RGBA value; it works wherever a color is accepted, and it has upstream's
methods through `$`: `to_integer()`, `to_rgb()`, `to_int_rgb()`,
`to_rgba()`, `to_int_rgba()`, `to_rgba_with_alpha(alpha)`,
`to_int_rgba_with_alpha(alpha)`, `to_hex(with_alpha = FALSE)`,
`to_hsv()`, `to_hsl()`, `invert(with_alpha = FALSE)`,
`interpolate(other, alpha)`, `darker(blend = 0.2)`,
`lighter(blend = 0.2)`,
`contrasting(threshold = 0.5, light = NULL, dark = NULL)`,
`opacity(opacity)` and `into(class_type)`. Arithmetic (`+`, `-`, `*`,
`/`, `%/%`, `%%`, `^`) works channel by channel with numbers or other
colors, `==` compares values, `!` inverts, `&` and `|` combine the
integer values, and
[`as.integer()`](https://rdrr.io/r/base/integer.html) gives
`to_integer()`.

## Usage

``` r
ManimColor(value = NULL, alpha = 1)

RGBA(value = NULL, alpha = 1)

HSV(hsv, alpha = 1)

ManimColorDType

ManimColorClass

HSVClass

# S3 method for class 'ManimColor'
x$name

# S3 method for class 'ManimColor'
x$name <- value

# S3 method for class 'ManimColor'
Ops(e1, e2)

# S3 method for class 'ManimColor'
as.integer(x, ...)

# S3 method for class 'ManimColor'
as.character(x, ...)

# S3 method for class 'ManimColor'
print(x, ...)

# S3 method for class 'ManimColor'
format(x, ...)
```

## Arguments

- value:

  A color name, a hex string (with `#` or `0x`), an integer such as
  `0xFF0000`, 3 or 4 numbers (0 to 1, or 0 to 255 when integers or above
  1), or another `ManimColor`. For `$<-`, the new value of an HSV
  property.

- alpha:

  Opacity, used when `value` has none.

- hsv:

  Hue, saturation and value, with an optional fourth alpha.

- x:

  A `ManimColor`.

- name:

  Method or property name.

- e1, e2:

  Operands.

- ...:

  Ignored.

## Value

`ManimColor()`, `RGBA()` and `HSV()` return a color object: a hex string
of class `ManimColor` (and `HSV` for `HSV()`). Its methods return
colors, numeric vectors or character strings, as described above.
`ManimColorClass` and `HSVClass` are the R6 class generators behind the
class methods.

## Details

A mobject stores its colors as plain hex strings, so wrap one to use the
methods: `ManimColor(sq$get_color())$darker()`.

`ManimColorClass` holds upstream's class methods:
`from_rgb(rgb, alpha)`, `from_rgba(rgba)`, `from_hex(hex_str, alpha)`,
`from_hsv(hsv, alpha)`, `from_hsl(hsl, alpha)`, `parse(color, alpha)` (a
list of colors for a vector or list) and `gradient(colors, length)`
(upstream leaves it unimplemented; here it is
[`color_gradient()`](https://adamrsophie.github.io/manimR/reference/interpolate_color.md)
as colors). `RGBA()` is another name for `ManimColor()`, as upstream.

`HSV()` is a color held as hue, saturation and value (0 to 1); `$hue`,
`$saturation` and `$value` (or `$h`, `$s`, `$v`) read and set them, and
arithmetic works on those channels. `HSVClass` has the same class
methods. Upstream drops an HSV color's alpha when converting it; here it
is kept.

`ManimColorDType` names the storage type of color values (`"double"`).

## Examples

``` r
c1 <- ManimColor("#FF0000")
c1$darker()
#> ManimColor('#CC0000')
c1$interpolate(ManimColor(BLUE), 0.5)$to_hex()
#> [1] "#AB626E"
ManimColorClass$from_hsv(c(0.5, 1, 1))
#> ManimColor('#00FFFF')
Square(color = ManimColor(0x00FF00))$get_color()
#> [1] "#00FF00"
h <- HSV(c(0.25, 1, 1))
h$hue <- 0.5
as.character(h)
#> [1] "#00FFFF"
```
