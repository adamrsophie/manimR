# Command line entry point

Mirrors `manim render` for use with `Rscript`:
`Rscript -e 'manimR::manim_cli()' scenes.R SceneName -ql -p`. FILE is an
R script (or a `.cfg` file whose `input_file` names the script),
followed by scene names; with no scene names a script with one scene
renders it and a script with several asks which to render (`-a` renders
all).

## Usage

``` r
manim_cli(args = commandArgs(trailingOnly = TRUE))
```

## Arguments

- args:

  Character vector of arguments; defaults to the trailing command line
  arguments.

## Details

It takes upstream's options: `-c`/`--config_file`, `--disable_caching`,
`--tex_template`, `-v`/`--verbosity`, `--notify_outdated_version` and
`--silent`, `--enable_gui`, `--gui_location`, `--fullscreen`,
`--enable_wireframe`, `--dry_run`, `--no_latex_cleanup`,
`--preview_command`, `--seed`, `-o`/`--output_file`, `-0`/`--zero_pad`,
`--media_dir`, `--log_dir`, `--log_to_file`, `-n N[,M]` (render
animations N through M, counted from 0), `-a`/`--write_all`, `--format`,
`-s`/`--save_last_frame`, `-q`/`--quality` (also `-ql`, `-qm`, `-qh`,
`-qp`, `-qk`), `-r`/`--resolution W,H`, `--fps`/`--frame_rate`,
`--video-codec`, `--pixel-format`, `--encoder-option KEY=VALUE`
(repeatable), `--max-inflight-encoders`, `--encoder-queue-size`,
`--renderer`, `--save_sections`, `-t`/`--transparent`,
`--use_projection_fill_shaders`, `--use_projection_stroke_shaders`,
`--progress_bar`, `-p`/`--preview`, `-l`/`--live-preview`,
`--show_in_file_browser`, plus manimR's `--flush_cache`. Short flags can
be combined (`-pql`). A `manim.cfg` in the working directory is read
first unless `-c` names another file, and the command line wins over
both. The OpenGL window options are accepted; asking for a live preview
is an error, as with upstream's Cairo renderer. Options can also be
written `--name=value`, and `render` may come first, as in
`manim render`.

The other subcommands of `manim`:

- `checkhealth` reports the programs manimR uses
  ([`manim_check()`](https://adamrsophie.github.io/manimR/reference/manim_check.md)).

- `cfg show` prints the settings, `cfg write` writes them to `manim.cfg`
  in the working directory and `cfg export --dir DIR` into `DIR`.

- `init project NAME` creates a project folder with `main.R` and a
  `manim.cfg` (upstream's default settings: 1920 x 1080 at 30 fps);
  `init scene NAME [FILE]` appends a scene template to `FILE`
  (`main.R`).

- `plugins -l` lists installed plugins
  ([`list_plugins()`](https://adamrsophie.github.io/manimR/reference/get_plugins.md)).

- `cache clear FILE SCENE ...` deletes the partial movie files of those
  scenes, for the quality given with `-q` and the media directory given
  with `--media-dir`.

- `--version` prints the version.
