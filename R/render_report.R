# What a render ran: render_report().

#' Report on a render
#'
#' Every [render()] keeps a report of what ran: the renderer and where it
#' runs, the output format and size, the time each play took and whether it
#' came from the cache and why, the mobjects and points in the last frame,
#' the ffmpeg and encoder used for video, and the settings that had no
#' effect.
#'
#' @param x The value of [render()].
#' @return A `manim_render_report` list, printed as a summary, or `NULL`
#'   when `x` carries no report.
#' @export
#' @examples
#' \donttest{
#' if (nzchar(Sys.which("ffmpeg"))) {
#'   out <- render(function(self) self$play(Create(Square())), quality = "l", media_dir = tempfile())
#'   render_report(out)
#' }
#' }
render_report <- function(x) attr(x, "report")

# Appends one play to a renderer's log. `hash` is NULL for a play that was
# skipped (skip_animations, or before from_animation_number).
record_play <- function(log, index, hash, cached, started) {
  reason <- if (is.null(hash)) "skipped" else if (startsWith(hash, "uncached_")) "caching disabled"
            else if (cached) "hash found in cache" else "new hash, rendered"
  rbind(log, data.frame(play = index, hash = hash %||% NA_character_, cached = isTRUE(cached), reason = reason,
                        seconds = proc.time()[[3]] - started))
}

render_report_of <- function(scene, settings, seconds, camera_fixed = character()) {
  renderer <- scene$renderer
  fw <- renderer$file_writer
  opengl <- identical(cfg("renderer"), RendererType$OPENGL)
  fam <- if (length(scene$mobjects)) unlist(lapply(scene$mobjects, function(m) m$get_family()), recursive = FALSE) else list()
  points <- sum(vapply(fam, function(m) NROW(m$points), 0))
  enc <- fw$video_encoder
  ffmpeg <- if (!is.null(enc)) ffmpeg_version() else NULL
  no_effect <- character()
  if (!is.null(settings$encoder_queue_size)) no_effect <- c(no_effect, "encoder_queue_size: frames go straight to ffmpeg")
  if ((settings$max_inflight_encoders %||% 1) > 1 && .Platform$OS.type != "unix") {
    no_effect <- c(no_effect, "max_inflight_encoders: Windows encodes one segment at a time")
  }
  if (length(camera_fixed)) no_effect <- c(no_effect, paste0(camera_fixed, ": the scene object keeps its camera"))
  structure(list(
    renderer = if (opengl) "opengl" else "cairo",
    backend = if (opengl) "upstream's GLSL shaders run in software on the CPU" else "Cairo-style drawing through R graphics on the CPU",
    format = fw$output_spec$format,
    size = c(width = as.integer(cfg("pixel_width")), height = as.integer(cfg("pixel_height"))),
    frame_rate = as.numeric(cfg("frame_rate")),
    seconds = seconds,
    plays = renderer$play_log %||% data.frame(play = integer(), hash = character(), cached = logical(),
                                               reason = character(), seconds = numeric()),
    mobjects = length(fam),
    points = points,
    ffmpeg = ffmpeg,
    encoder = enc[c("codec", "pixel_format", "container_format")],
    no_effect = no_effect
  ), class = "manim_render_report")
}

# The first line of `ffmpeg -version`, once per session.
ffmpeg_version <- function() {
  if (is.null(.manim$ffmpeg_version)) {
    path <- tryCatch(ffmpeg_path(), error = function(e) NA_character_)
    line <- if (is.na(path)) NA_character_ else tryCatch(system2(path, "-version", stdout = TRUE, stderr = FALSE)[1],
                                                         error = function(e) NA_character_, warning = function(w) NA_character_)
    .manim$ffmpeg_version <- list(path = path, version = sub(" Copyright.*", "", line))
  }
  .manim$ffmpeg_version
}

#' @export
print.manim_render_report <- function(x, ...) {
  cat("<manimR render report>\n")
  cat("Renderer: ", x$renderer, " (", x$backend, ")\n", sep = "")
  cat("Output:   ", x$format, ", ", x$size[["width"]], "x", x$size[["height"]], " at ", x$frame_rate, " fps\n", sep = "")
  p <- x$plays
  cat("Time:     ", sprintf("%.2f", x$seconds), " s; ", nrow(p), " plays took ", sprintf("%.2f", sum(p$seconds)), " s\n",
      sep = "")
  if (nrow(p)) {
    counts <- table(p$reason)
    cat("Plays:    ", paste(sprintf("%d %s", as.integer(counts), names(counts)), collapse = "; "), "\n", sep = "")
  }
  cat("Scene:    ", x$mobjects, " mobjects, ", x$points, " points in the last frame\n", sep = "")
  if (!is.null(x$ffmpeg)) {
    cat("Encoder:  ", x$encoder$codec, " (", x$encoder$pixel_format, ") in ", x$encoder$container_format, ", ",
        x$ffmpeg$version %|NA|% "ffmpeg version unknown", "\n", sep = "")
  }
  if (length(x$no_effect)) cat("No effect:", paste0("\n  ", x$no_effect), "\n", sep = "")
  invisible(x)
}

`%|NA|%` <- function(a, b) if (is.null(a) || is.na(a)) b else a
