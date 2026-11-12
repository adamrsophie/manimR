# Plugins

Upstream finds plugins through Python entry points. A manimR plugin is
an installed R package whose `DESCRIPTION` has the field
`Config/manimR/plugin: true`. `get_plugins()` returns their namespaces,
named by package (loading them), and `list_plugins()` prints their
names.

## Usage

``` r
get_plugins()

list_plugins()
```

## Value

`get_plugins()` returns a named list of namespaces; `list_plugins()`
returns the names invisibly.

## Examples

``` r
list_plugins()
#> Plugins: 
```
