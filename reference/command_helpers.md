# Run commands and inspect outputs

Ports of `manim.utils.commands`.

## Usage

``` r
capture(command, cwd = NULL, command_input = NULL)

get_dir_layout(dirpath)

get_video_metadata(path_to_video)
```

## Arguments

- command:

  A character vector: the program and its arguments.

- cwd:

  Working directory for the command.

- command_input:

  Text passed to the command's standard input.

- dirpath:

  A directory.

- path_to_video:

  A video file.

## Details

- `capture(command, cwd, command_input)` runs a command (a character
  vector: the program, then its arguments) and returns
  `list(out, err, returncode)`.

- `get_dir_layout(dirpath)` lists the files below a directory, as paths
  relative to it.

- `get_video_metadata(path_to_video)` returns the width, height, number
  of frames, duration, average frame rate, codec and pixel format of the
  first video stream, read with ffprobe (or ffmpeg when ffprobe is not
  installed). As upstream, `nb_frames` and `duration` are strings and
  the frames are counted by decoding when the container does not record
  them.

## Examples

``` r
capture(c("R", "--version"))$returncode
#> [1] 0
```
