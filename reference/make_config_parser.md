# Config parser of the library, user and folder files

`make_config_parser()` reads upstream's library wide `default.cfg`
(shipped with manimR), then the user wide file and the folder wide
`manim.cfg` (or `custom_file`), each overriding the keys it sets, as
upstream's `make_config_parser()` does. The result has one element per
section, each a named list of strings, with `%%` read as `%`.

## Usage

``` r
make_config_parser(custom_file = NULL)
```

## Arguments

- custom_file:

  A `.cfg` file read instead of the folder wide one.

## Value

A named list of sections.

## Examples

``` r
p <- make_config_parser()
names(p)
#> [1] "CLI"                   "CLI_CTX"               "logger"               
#> [4] "video_encoder"         "video_encoder.options" "media"                
#> [7] "jupyter"              
p$CLI$frame_rate
#> [1] "60"
```
