# Compile Typst to SVG

Writes the markup into a minimal Typst document (auto sized page, no
margin, 10pt text) and compiles it with the `typst` command line
compiler. The `.typ` source and the `.svg` result are cached in the
`tex_dir` setting (`media/Tex`) under a hash of the full source. Set the
compiler path with `manim_config(typst = "/path/to/typst")` when it is
not on the `PATH`.

## Usage

``` r
typst_to_svg_file(
  typst_code,
  preamble = "",
  text_size = TYPST_COMPILATION_FONT_SIZE,
  font_paths = NULL
)
```

## Arguments

- typst_code:

  Body of the Typst document.

- preamble:

  Typst code inserted between the `#set` rules and the body, for
  `#import`, `#set` or `#show` rules.

- text_size:

  Font size in Typst points used during compilation.

- font_paths:

  Optional character vector of extra font directories.

## Value

Path to the SVG file.
