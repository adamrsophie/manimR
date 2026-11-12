# Cairo style renderer and scene file writer

`CairoRenderer` is the renderer every
[Scene](https://adamrsophie.github.io/manimR/reference/Scene.md) uses,
the counterpart of upstream's `CairoRenderer`: it draws frames with the
scene's camera on an offscreen device and passes them to a
`SceneFileWriter`, which streams them to ffmpeg and handles sections,
sounds and the last frame image. Both are created by a scene; construct
them yourself only to customize rendering, for example
`MyScene$new(renderer = CairoRenderer(...))`.

## Usage

``` r
SceneFileWriter(settings)

CairoRenderer(
  file_writer_class = SceneFileWriterClass,
  camera_class = CameraClass,
  skip_animations = FALSE,
  ...
)
```

## Arguments

- settings:

  The settings a scene resolves for its file writer: the output plan,
  the video encoder and the cache settings.

- file_writer_class:

  The file writer class generator a renderer creates for each scene.

- camera_class:

  The camera class generator.

- skip_animations:

  Skip rendering animations.

- ...:

  Arguments passed to the camera.
