# Generators of classes built by constructor functions

Some upstream classes only preset the arguments of their parent class,
and manimR builds them with a function. They still have a class
generator, a subclass of the upstream parent: `MathTableClass` inherits
from `TableClass`, `ReplacementTransformClass` from `TransformClass`,
and so on.
[`MathTable()`](https://adamrsophie.github.io/manimR/reference/TableClass.md)
creates an object of `MathTableClass`, so `inherits(x, "MathTable")` is
`TRUE`, a scene can subclass the generator, and
[`set_default()`](https://adamrsophie.github.io/manimR/reference/set_default.md)
changes the defaults of that class alone.

## Examples

``` r
t <- MathTableClass
inherits(t$get_inherit(), "R6ClassGenerator")
#> [1] TRUE
```
