# Dictionary helpers

Ports of `manim.utils.config_ops` for named lists.

## Usage

``` r
merge_dicts_recursively(...)

update_dict_recursively(current_dict, ...)

DictAsObject(dictin)
```

## Arguments

- ...:

  Named lists.

- current_dict:

  A named list or an environment.

- dictin:

  A named list.

## Details

- `merge_dicts_recursively(...)` merges named lists from left to right;
  where two lists hold named lists under the same name, those are merged
  too.

- `update_dict_recursively(current_dict, ...)` merges the others into
  `current_dict`. An environment is updated in place, as upstream
  updates its dict; a list cannot be, so the merged list is returned and
  should be assigned back.

- `DictAsObject(dictin)` returns an environment whose variables are the
  entries of `dictin`, so they read as `obj$name`.

## Examples

``` r
merge_dicts_recursively(list(a = 1, b = list(x = 1)), list(b = list(y = 2)))
#> $a
#> [1] 1
#> 
#> $b
#> $b$x
#> [1] 1
#> 
#> $b$y
#> [1] 2
#> 
#> 
```
