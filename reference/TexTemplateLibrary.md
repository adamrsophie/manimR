# Libraries of LaTeX templates

Ready made
[`TexTemplate()`](https://adamrsophie.github.io/manimR/reference/TexTemplateClass.md)
objects, ported from manim's `TexTemplateLibrary` and
`TexFontTemplates`. Pass one as `tex_template` to
[`Tex()`](https://adamrsophie.github.io/manimR/reference/tex.md) or
[`MathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md), or
make it the default with `manim_config(tex_template = ...)`.

## Usage

``` r
TexTemplateLibrary()

TexFontTemplates()
```

## Value

A named list of
[`TexTemplate()`](https://adamrsophie.github.io/manimR/reference/TexTemplateClass.md)
objects.

## Details

Upstream exposes these as class attributes holding shared template
objects. A TexTemplate is a mutable R6 object here, so a shared one
would let `add_to_preamble()` on one use leak into every other use. Both
libraries are therefore functions returning a named list of fresh
templates on every call: write `TexTemplateLibrary()$ctex` where
upstream writes `TexTemplateLibrary.ctex`.

`TexTemplateLibrary()` holds `default` and `threeb1b` (the 3b1b
preamble), `ctex` (the same with the `ctex` package, compiled with
`xelatex`) and `simple` (only the AMS packages).

`TexFontTemplates()` holds font templates; many need extra LaTeX
packages or system fonts, and some need `xelatex` or `lualatex`. See
[http://jf.burnol.free.fr/showcase.html](http://jf.burnol.free.fr/showcase.md)
for samples. The templates are:

- `american_typewriter`: American Typewriter

- `antykwa`: Antykwa Poltawskiego (TX Fonts for Greek and math symbols)

- `apple_chancery`: Apple Chancery

- `auriocus_kalligraphicus`: Auriocus Kalligraphicus (Symbol Greek)

- `baskervald_adf_fourier`: Baskervald ADF with Fourier

- `baskerville_it`: Baskerville (Italic)

- `biolinum`: Biolinum

- `brushscriptx`: BrushScriptX-Italic (PX math and Greek)

- `chalkboard_se`: Chalkboard SE

- `chalkduster`: Chalkduster

- `comfortaa`: Comfortaa

- `comic_sans`: Comic Sans MS

- `droid_sans`: Droid Sans

- `droid_sans_it`: Droid Sans (Italic)

- `droid_serif`: Droid Serif

- `droid_serif_px_it`: Droid Serif (PX math symbols) (Italic)

- `ecf_augie`: ECF Augie (Euler Greek)

- `ecf_jd`: ECF JD (with TX fonts)

- `ecf_skeetch`: ECF Skeetch (CM Greek)

- `ecf_tall_paul`: ECF Tall Paul (with Symbol font)

- `ecf_webster`: ECF Webster (with TX fonts)

- `electrum_adf`: Electrum ADF (CM Greek)

- `epigrafica`: Epigrafica

- `fourier_utopia`: Fourier Utopia (Fourier upright Greek)

- `french_cursive`: French Cursive (Euler Greek)

- `gfs_bodoni`: GFS Bodoni

- `gfs_didot`: GFS Didot (Italic)

- `gfs_neoHellenic`: GFS NeoHellenic

- `gnu_freesans_tx`: GNU FreeSerif (and TX fonts symbols)

- `gnu_freeserif_freesans`: GNU FreeSerif and FreeSans

- `helvetica_fourier_it`: Helvetica with Fourier (Italic)

- `latin_modern_tw_it`: Latin Modern Typewriter Proportional (CM Greek)
  (Italic)

- `latin_modern_tw`: Latin Modern Typewriter Proportional

- `libertine`: Libertine

- `libris_adf_fourier`: Libris ADF with Fourier

- `minion_pro_myriad_pro`: Minion Pro and Myriad Pro (and TX fonts
  symbols)

- `minion_pro_tx`: Minion Pro (and TX fonts symbols)

- `new_century_schoolbook`: New Century Schoolbook (Symbol Greek)

- `new_century_schoolbook_px`: New Century Schoolbook (Symbol Greek, PX
  math symbols)

- `noteworthy_light`: Noteworthy Light

- `palatino`: Palatino (Symbol Greek)

- `papyrus`: Papyrus

- `romande_adf_fourier_it`: Romande ADF with Fourier (Italic)

- `slitex`: SliTeX (Euler Greek)

- `times_fourier_it`: Times with Fourier (Italic)

- `urw_avant_garde`: URW Avant Garde (Symbol Greek)

- `urw_zapf_chancery`: URW Zapf Chancery (CM Greek)

- `venturis_adf_fourier_it`: Venturis ADF with Fourier (Italic)

- `verdana_it`: Verdana (Italic)

- `vollkorn_fourier_it`: Vollkorn with Fourier (Italic)

- `vollkorn`: Vollkorn (TX fonts for Greek and math symbols)

- `zapf_chancery`: Zapf Chancery

## Examples

``` r
names(TexTemplateLibrary())
#> [1] "default"  "threeb1b" "ctex"     "simple"  
tpl <- TexFontTemplates()$french_cursive
tpl$description
#> [1] "French Cursive (Euler Greek)"
if (FALSE) { # \dontrun{
MathTex("x^2 + y^2 = 1", tex_template = TexFontTemplates()$latin_modern_tw)
} # }
```
