# List helpers

Ports of `manim.utils.iterables`, working on R vectors and lists (atomic
input gives atomic output). Elements compare as in Python: mobjects and
other environments by identity, everything else by value.

## Usage

``` r
extract_mobject_family_members(
  mobjects = mobject_list,
  use_z_index = FALSE,
  only_those_with_points = FALSE,
  mobject_list = NULL
)

stretch_array_to_length(nparray, length)

adjacent_n_tuples(objects, n)

adjacent_pairs(objects)

all_elements_are_instances(iterable, Class)

concatenate_lists(...)

list_difference_update(l1, l2, key = NULL)

list_update(l1, l2, key = NULL)

listify(obj)

tuplify(obj)

make_even(iterable_1, iterable_2)

make_even_by_cycling(iterable_1, iterable_2)

remove_list_redundancies(lst)

remove_nones(sequence)

resize_array(nparray, length)

resize_preserving_order(nparray, length)

resize_with_interpolation(nparray, length)

batch_by_property(items, property_func)

uniq_chain(...)

flatten_iterable_parameters(args)

restructure_list_to_exclude_certain_family_members(mobject_list, to_remove)

hash_obj(obj)
```

## Arguments

- mobjects, mobject_list, to_remove:

  Lists of mobjects.

- use_z_index:

  Sort the result by `z_index`.

- only_those_with_points:

  Keep only mobjects that have points.

- nparray:

  A vector or matrix.

- length:

  Length of the result.

- objects, iterable, iterable_1, iterable_2, lst, sequence, l1, l2, obj,
  items:

  A vector or list.

- n:

  Window size.

- Class:

  A class name or R6 class generator.

- ...:

  Vectors or lists.

- key:

  `NULL`, or a function giving the value elements compare by.

- property_func:

  Function giving the property of an item.

- args:

  A list.

## Value

A list or a vector, as described above for each function.
`all_elements_are_instances()` returns `TRUE` or `FALSE`, and
`hash_obj()` returns a hash string.

## Details

- `adjacent_n_tuples(objects, n)`: the `length(objects)` windows of `n`
  cyclically consecutive elements; `adjacent_pairs()` uses `n = 2`.

- `all_elements_are_instances(iterable, Class)`: whether every element
  inherits from `Class` (a class name or an R6 class generator).

- `concatenate_lists(...)`: all elements of the arguments, in order.

- `list_difference_update(l1, l2, key)`: the elements of `l1` that are
  not in `l2`; `list_update(l1, l2, key)` appends `l2` to that, so
  elements of `l2` move to the end. With `key`, elements compare by
  `key(element)`.

- `listify(obj)` and `tuplify(obj)`: `obj` as a list; a single string is
  one element, a mobject gives its submobjects (R has no tuples, so both
  return a list).

- `make_even(iterable_1, iterable_2)`: both stretched to the longer
  length by repeating elements in place; `make_even_by_cycling()`
  repeats them cyclically. Each returns a list of the two results.

- `remove_list_redundancies(lst)`: drops repeated elements, keeping the
  last occurrence of each.

- `remove_nones(sequence)`: drops elements that are false in Python's
  sense (`NULL`, `FALSE`, `0`, `""`, empty vectors, and mobjects without
  submobjects), as upstream's `if x` filter does.

- `stretch_array_to_length(nparray, length)`: a vector, or a matrix by
  rows, stretched to `length` entries by repeating them in place; it is
  an error to shrink.

- `resize_array(nparray, length)`: a vector, or a matrix by rows, cut or
  cyclically repeated to `length` entries (as `numpy.resize`).
  `resize_preserving_order()` repeats or drops entries in place instead,
  and `resize_with_interpolation()` interpolates linearly between
  neighboring entries.

- `batch_by_property(items, property_func)`: consecutive items with the
  same `property_func(item)` grouped; a list of `list(batch, property)`
  pairs.

- `uniq_chain(...)`: the elements of all arguments in order, without
  repeats.

- `hash_obj(obj)`: a hash (a string) of a nested list that does not
  depend on the order of the entries of named lists.

- `flatten_iterable_parameters(args)`: the elements of `args`, with
  those that are themselves lists or vectors of several elements spliced
  in (one level).

- `extract_mobject_family_members(mobjects, use_z_index, only_those_with_points)`:
  every member of the families of the mobjects, once each, optionally
  sorted by `z_index` and without the members that have no points.
  `mobject_list` (the name in `manim.utils.family_ops`) is accepted for
  `mobjects`.
  `restructure_list_to_exclude_certain_family_members(mobject_list, to_remove)`
  drops `to_remove` and their family from the list; a group that holds
  one of them is replaced by its remaining members.

## Examples

``` r
adjacent_pairs(1:4)
#> [[1]]
#> [1] 1 2
#> 
#> [[2]]
#> [1] 2 3
#> 
#> [[3]]
#> [1] 3 4
#> 
#> [[4]]
#> [1] 4 1
#> 
list_update(c(1, 2, 3, 4), c(2, 5))
#> [1] 1 3 4 2 5
make_even(1:3, 4:8)
#> [[1]]
#> [1] 1 1 2 2 3
#> 
#> [[2]]
#> [1] 4 5 6 7 8
#> 
remove_list_redundancies(c(1, 2, 1, 3, 2, 4))
#> [1] 1 3 2 4
```
