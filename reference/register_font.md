# Use a font file with Text

Makes the font in `font_file` available to
[`Text()`](https://adamrsophie.github.io/manimR/reference/TextClass.md),
[`MarkupText()`](https://adamrsophie.github.io/manimR/reference/MarkupText.md)
and
[`Paragraph()`](https://adamrsophie.github.io/manimR/reference/Paragraph.md)
under its family name, which is returned. The file is looked up as
given, then in `assets/fonts/` and `fonts/` below the working directory,
as upstream does relative to the scene file.

## Usage

``` r
register_font(font_file)
```

## Arguments

- font_file:

  Path to a font file (for example `.ttf` or `.otf`).

## Value

The font family name, invisibly.

## Details

Upstream's `register_font()` is a context manager that unregisters the
font when the `with` block ends. Here the font stays registered for the
rest of the R session (through
[`systemfonts::register_font()`](https://systemfonts.r-lib.org/reference/register_font.html)),
so `Text("Hi", font = register_font("MyFont.ttf"))` works directly.

The first file registered for a family is used for every style (regular,
bold, italic, bold italic). A later file of the same family replaces
only its own style, so registering a regular and a bold file gives
`weight = "BOLD"` the bold one. A file whose family is already installed
is usable by name, so its family is returned without registering it
(systemfonts does not allow registering an installed family) and the
installed faces are used.

## Examples

``` r
if (FALSE) { # \dontrun{
# Needs a font file of your own.
family <- register_font("fonts/MyFont-Regular.ttf")
Text("Hello", font = family)
} # }
```
