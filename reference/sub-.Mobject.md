# Index submobjects

`mob[i]` returns the i-th submobject (1 based). A vector index returns a
group of the selected submobjects.

## Usage

``` r
# S3 method for class 'Mobject'
x[i, ...]

# S3 method for class 'Mobject'
x[i] <- value

# S3 method for class 'Mobject'
x[[i]] <- value

# S3 method for class 'Mobject'
length(x)

# S3 method for class 'Mobject'
x[[i, ...]]
```

## Arguments

- x:

  A mobject.

- i:

  Index.

- ...:

  Ignored.

- value:

  A mobject to store under key `i` of a
  [VDict](https://adamrsophie.github.io/manimR/reference/VDictClass.md).

## Details

A character key looks up an entry of a
[VDict](https://adamrsophie.github.io/manimR/reference/VDictClass.md)
(`vd["square"]`, or several entries as a group with `vd[c("a", "b")]`)
or a vertex of a
[Graph](https://adamrsophie.github.io/manimR/reference/GenericGraphClass.md)
(`g["a"]`, or `g[c("a", "b")]` for an edge), as upstream's
`vdict["square"]` and `g["a"]` do; an unknown key is an error.
`vd["square"] <- Square()` adds or replaces an entry. With `[[`, a
character key returns the field or method of that name when there is
one, as for any environment, and otherwise the dictionary entry or
vertex.
