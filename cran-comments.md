## Test environments

* local: macOS 27.2 (aarch64), R 4.6.0
* GitHub Actions: ubuntu-latest (R devel, release and oldrel-1),
  windows-latest (R release), macos-latest (R release)

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.
* Possibly misspelled words in DESCRIPTION: Bezier is a proper name;
  mobjects, updaters and addins are terms of the library and of 'RStudio'.

## Notes for the reviewers

* manimR is a port to R of the Python library 'Manim Community' (MIT
  license), with smaller parts ported from 'NetworkX', 'earcut.hpp' and
  'isosurfaces'. The `Copyright` field points to `inst/COPYRIGHTS`, which
  names the copyright holders of the ported code and reproduces their
  license notices.
* Examples inside `\dontrun{}` need software that a check cannot rely on:
  LaTeX with 'dvisvgm', the 'typst' compiler, 'ffmpeg', or a font file of the
  user. Each of these blocks starts with a comment that says what it needs.
  Examples that open a window or a 'shiny' application run in interactive
  sessions only.
* `render()` writes a video below the folder `media` of the working
  directory by default, as the Python library does, and only when the user
  calls it. No example, test or vignette uses this default: they write below
  `tempdir()`.
* Tests that call external programs (LaTeX, 'dvisvgm', 'ffmpeg', 'typst') and
  the ten slowest tests are skipped on CRAN. The vignette chunks that call
  LaTeX or 'ffmpeg' are not evaluated on CRAN.
* Only the introduction is shipped as a vignette. The eleven longer articles
  render many scenes and are published on the package website, to keep the
  check time and the size of the package small.
