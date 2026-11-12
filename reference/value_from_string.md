# Command line helpers of `manim cfg` and `manim init`

The helpers behind the prompts of `manim cfg write` and `manim init`
([`manim_cli()`](https://adamrsophie.github.io/manimR/reference/manim_cli.md)),
as upstream's `manim.cli.cfg.group` and `manim.cli.init.commands`.

## Usage

``` r
value_from_string(value)

replace_keys(default)

select_resolution()

update_cfg(cfg_dict, project_cfg_path)
```

## Arguments

- value:

  A string.

- default:

  A named list or vector.

- cfg_dict:

  Named list of settings.

- project_cfg_path:

  Path of a `manim.cfg`.

## Value

`value_from_string()` the literal; `replace_keys()` `default` renamed;
`select_resolution()` an integer vector; `update_cfg()` the path,
invisibly.

## Details

- `value_from_string(value)` reads a config value as a Python literal:
  `"5"` is `5L`, `"1.5"` is `1.5`, `"True"` is `TRUE`, `"0,0"` a list of
  two integers; anything else (`"BLACK"`, `"60%"`) stays a string.

- `replace_keys(default)` swaps `_` and `.` in the names, as the logger
  section is shown to the user.

- `select_resolution()` asks for a resolution among the qualities and
  returns `c(height, width)` (default `480p`).

- `update_cfg(cfg_dict, project_cfg_path)` sets `[CLI]` keys of a
  `manim.cfg`; `resolution` sets `pixel_height` and `pixel_width`.

Outside an interactive session every prompt takes its default.

## Examples

``` r
value_from_string("60")
#> [1] 60
value_from_string("0,0")
#> [[1]]
#> [1] 0
#> 
#> [[2]]
#> [1] 0
#> 
#> attr(,"py_type")
#> [1] "tuple"
value_from_string("BLACK")
#> [1] "BLACK"
replace_keys(list(log_width = "-1", logging.keyword = "bold yellow"))
#> $log.width
#> [1] "-1"
#> 
#> $logging_keyword
#> [1] "bold yellow"
#> 
select_resolution()
#> 
#> Select resolution:
#>  (2160p, 1440p, 1080p, 720p, 480p): 
#> [1] 480 854
f <- tempfile(fileext = ".cfg")
writeLines(c("[CLI]", "frame_rate = 60"), f)
update_cfg(list(frame_rate = 30, resolution = c(480, 854)), f)
readLines(f)
#> [1] "[CLI]"              "frame_rate = 30"    "pixel_height = 480"
#> [4] "pixel_width = 854"  ""                  
```
