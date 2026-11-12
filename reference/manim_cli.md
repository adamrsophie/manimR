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

## Value

The result of the subcommand, invisibly.

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
both. Unless `--media_dir` or a config file sets it, the media folder is
`media` in `tools::R_user_dir("manimR", "cache")`, since the temporary
directory of an `Rscript` process is deleted when it ends;
`--media_dir media` writes to `./media` as upstream's command line does.
The OpenGL window options are accepted; asking for a live preview is an
error, as with upstream's Cairo renderer. Options can also be written
`--name=value`, and `render` may come first, as in `manim render`.

The other subcommands of `manim`:

- `checkhealth` reports the programs manimR uses
  ([`manim_check()`](https://adamrsophie.github.io/manimR/reference/manim_check.md)).

- `cfg show` prints the config files read and every setting of
  [`make_config_parser()`](https://adamrsophie.github.io/manimR/reference/make_config_parser.md).
  `cfg write [-l user|cwd] [-o]` asks for each value (Enter keeps it)
  and writes the user wide file or `manim.cfg` in the working directory;
  `-o` opens the file instead of asking. `cfg export [-d DIR]` runs
  `cfg write` and copies its file into `DIR`.

- `init project [NAME] [-d]` asks for a template, the frame rate,
  background and resolution (`-d` takes upstream's defaults: 1920 x 1080
  at 30 fps) and creates `NAME` with `main.R` and `manim.cfg`.
  `init scene NAME [FILE]` asks for a template and appends it to `FILE`
  (`main.R`). See
  [`get_template_names()`](https://adamrsophie.github.io/manimR/reference/get_template_path.md).

- `plugins -l` lists installed plugins
  ([`list_plugins()`](https://adamrsophie.github.io/manimR/reference/get_plugins.md)).

- `cache clear FILE SCENE ...` deletes the partial movie files of those
  scenes, for the quality (`-q`), resolution (`-r W,H`), frame rate
  (`--fps`), media directory (`--media-dir`) and config file (`-c`)
  given.

- `--version` prints the version; every command starts with the same
  splash line unless `--hide-splash` is given.

Outside an interactive session every prompt takes its default.
