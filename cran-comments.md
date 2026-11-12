## Test environments

* local: macOS 27.2 (aarch64), R 4.6.0, `R CMD check --as-cran`
* GitHub Actions: ubuntu-latest (R devel, release and oldrel-1) and
  windows-latest (R release)

## R CMD check results

Local `--as-cran` check: 0 errors | 0 warnings | 2 notes

* This is a new submission.
* Seven examples took more than 5 s elapsed time while the machine ran
  other jobs; the CPU time of every example was under 2.1 s, and the
  GitHub Actions checks did not list any example.
* Installed size (INFO): 8.1 Mb, of which 7.0 Mb is the `R` directory. The
  package is pure R code ported from a large library; it has no compiled
  code and no data files.
* Should the spelling check list Bezier, mobjects, updaters or addins in
  DESCRIPTION: Bezier is a proper name; mobjects, updaters and addins are
  terms of the library and of 'RStudio'.

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
* No function writes to the working directory or the home filespace by
  default. The media folder, which holds rendered videos, images and the
  LaTeX cache of `MathTex()`, is a folder below `tempdir()` unless the user
  sets `media_dir` (for example `manim_config(media_dir = "media")`).
  `manim_cli()`, the command line front end that a user runs on a script
  from a shell (`Rscript -e "manimR::manim_cli()" render file.R`), renders
  into `tools::R_user_dir("manimR", "cache")` instead, because the temporary
  directory of that process is deleted when it ends. The tests that call it
  set the media folder or `R_USER_CACHE_DIR` to a directory below
  `tempdir()`.
* Tests that call external programs (LaTeX, 'dvisvgm', 'ffmpeg', 'typst') and
  the ten slowest tests are skipped on CRAN. The vignette chunks that call
  LaTeX or 'ffmpeg' are not evaluated on CRAN. `Code()` highlights with
  Python's 'Pygments' when Python with that module is found and with a
  built in highlighter otherwise; its tests pass both ways.
* Only the introduction is shipped as a vignette. The eleven longer articles
  render many scenes and are published on the package website, to keep the
  check time and the size of the package small.
