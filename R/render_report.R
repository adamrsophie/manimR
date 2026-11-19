# What a render ran: render_report().

#' Report on a render
#'
#' Every [render()] keeps a report of what ran: the renderer and where it
#' runs, the output format and size, the time each play took and whether it
#' came from the cache and why, the mobjects and points in the last frame,
#' the ffmpeg and encoder used for video, and the settings that had no
#' effect.
#'
#' The report is also the movie's timeline. Each row of `plays` gives the
#' play's section, its first frame (`start_frame`, counting from 0), its
#' number of `frames`, and its `start` and `end` in seconds of the movie;
#' `sections` sums them by section. Plays that were skipped add no frames.
#' [scene_frame()] at a time `t` shows frame `floor(t * frame_rate)` of the
#' movie, which is the frame a player shows at that time.
#'
#' The report of the latest render is also kept for the session, and
#' `render_report()` with no argument returns it. That covers renders that
#' return nothing (`dry_run`, `format = "none"`) and renders that failed,
#' whose report has `status = "failed"` and the error message.
#'
#' @param x The value of [render()]; leave it out for the latest render.
#' @return A `manim_render_report` list, printed as a summary, or `NULL`
#'   when there is no report.
#' @export
#' @examples
#' \donttest{
#' if (nzchar(Sys.which("ffmpeg"))) {
#'   out <- render(function(self) self$play(Create(Square())), quality = "l", media_dir = tempfile())
#'   render_report(out)
#' }
#' }
render_report <- function(x) if (missing(x)) .manim$last_report else attr(x, "report")

# Appends one play to a renderer's log. `hash` is NULL for a play that was
# skipped (skip_animations, or before from_animation_number), which adds no
# frames to the movie. `frames` is the number of frames the play adds, and
# the play starts at the frame after those of the plays before it.
record_play <- function(log, index, hash, cached, started, frames = 0, fps = 1, section = NA_character_) {
  reason <- if (is.null(hash)) "skipped" else if (startsWith(hash, "uncached_")) "caching disabled"
            else if (cached) "hash found in cache" else "new hash, rendered"
  frames <- if (is.null(hash)) 0L else as.integer(round(frames))
  first <- if (is.null(log) || !nrow(log)) 0L else as.integer(sum(log$frames))
  rbind(log, data.frame(play = index, hash = hash %||% NA_character_, cached = isTRUE(cached), reason = reason,
                        seconds = proc.time()[[3]] - started, section = section %||% NA_character_,
                        start_frame = first, frames = frames, start = first / fps, end = (first + frames) / fps))
}

# Calls the progress function of the render, if any, with the latest play.
notify_progress <- function(log) {
  if (is.function(.manim$progress)) .manim$progress(log[nrow(log), , drop = FALSE])
  invisible(NULL)
}

#' @rdname render_report
#' @param file Path of the JSON file to write.
#' @param inputs Optional named list of the inputs of the scene (data
#'   frames, parameters, file paths); each is recorded as a SHA-256 digest,
#'   not as data.
#' @details `write_render_report()` writes a report as JSON (this needs the
#'   jsonlite package) together with the R and manimR versions, the
#'   platform, a SHA-256 digest of the output file and digests of the given
#'   `inputs`, so a render can be compared with a later one. It writes the
#'   report of a failed render as well.
#' @export
write_render_report <- function(x = render_report(), file, inputs = NULL) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("write_render_report() needs the jsonlite package.", call. = FALSE)
  report <- if (inherits(x, "manim_render_report")) x else render_report(x)
  if (is.null(report)) stop("There is no render report to write.", call. = FALSE)
  output <- if (inherits(x, "manim_output")) unclass(x)
  if (!is.null(inputs) && (!is.list(inputs) || is.null(names(inputs)) || !all(nzchar(names(inputs))))) {
    stop("`inputs` must be a named list.", call. = FALSE)
  }
  out <- c(list(manimR = as.character(utils::packageVersion("manimR")), R = R.version.string,
                platform = R.version$platform, written = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
                output = output,
                output_sha256 = if (!is.null(output) && file.exists(output)) digest::digest(file = output, algo = "sha256"),
                inputs = lapply(inputs, digest::digest, algo = "sha256")),
           unclass(report))
  jsonlite::write_json(out, file, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null", dataframe = "rows",
                       digits = NA)
  invisible(file)
}

# The subcaptions of a scene as a data frame of start and end times (in
# seconds) and text.
captions_table <- function(subcaptions) {
  data.frame(start = vapply(subcaptions, function(s) as.numeric(s$start), 0),
             end = vapply(subcaptions, function(s) as.numeric(s$end), 0),
             text = vapply(subcaptions, function(s) paste(s$content, collapse = "\n"), ""))
}

# The frames and times of each section, from the plays.
sections_timeline <- function(plays) {
  if (!nrow(plays)) return(data.frame(section = character(), start_frame = integer(), frames = integer(),
                                      start = numeric(), end = numeric()))
  run <- cumsum(c(TRUE, plays$section[-1] != plays$section[-nrow(plays)] |
                    is.na(plays$section[-1]) != is.na(plays$section[-nrow(plays)])))
  do.call(rbind, lapply(split(plays, run), function(p) {
    data.frame(section = p$section[1], start_frame = p$start_frame[1], frames = sum(p$frames),
               start = p$start[1], end = p$end[nrow(p)])
  }))
}

render_report_of <- function(scene, settings, seconds, camera_fixed = character(), error = NULL) {
  renderer <- scene$renderer
  # The size and frame rate the scene drew with, which a scene object keeps
  # from when it was created.
  shape <- if (is.function(renderer$get_pixel_shape)) renderer$get_pixel_shape()
           else c(scene$camera$pixel_width, scene$camera$pixel_height)
  fw <- renderer$file_writer
  plays <- renderer$play_log %||% data.frame(play = integer(), hash = character(), cached = logical(),
                                              reason = character(), seconds = numeric(), section = character(),
                                              start_frame = integer(), frames = integer(), start = numeric(),
                                              end = numeric())
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
    status = if (is.null(error)) "completed" else "failed",
    error = error,
    format = fw$output_spec$format,
    size = c(width = as.integer(shape[1]), height = as.integer(shape[2])),
    frame_rate = as.numeric(scene$camera$frame_rate),
    seed = scene$random_seed,
    seconds = seconds,
    plays = plays,
    sections = sections_timeline(plays),
    captions = captions_table(fw$subcaptions),
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
  if (identical(x$status, "failed")) cat("Status:   failed: ", x$error, "\n", sep = "")
  cat("Renderer: ", x$renderer, " (", x$backend, ")\n", sep = "")
  cat("Output:   ", x$format, ", ", x$size[["width"]], "x", x$size[["height"]], " at ", x$frame_rate, " fps\n", sep = "")
  p <- x$plays
  cat("Time:     ", sprintf("%.2f", x$seconds), " s; ", nrow(p), " plays took ", sprintf("%.2f", sum(p$seconds)), " s\n",
      sep = "")
  if (nrow(p)) {
    counts <- table(p$reason)
    cat("Plays:    ", paste(sprintf("%d %s", as.integer(counts), names(counts)), collapse = "; "), "\n", sep = "")
  }
  if (!is.null(x$seed)) cat("Seed:     ", x$seed, "\n", sep = "")
  cat("Scene:    ", x$mobjects, " mobjects, ", x$points, " points in the last frame\n", sep = "")
  if (!is.null(x$ffmpeg)) {
    cat("Encoder:  ", x$encoder$codec, " (", x$encoder$pixel_format, ") in ", x$encoder$container_format, ", ",
        x$ffmpeg$version %|NA|% "ffmpeg version unknown", "\n", sep = "")
  }
  if (length(x$no_effect)) cat("No effect:", paste0("\n  ", x$no_effect), "\n", sep = "")
  invisible(x)
}

`%|NA|%` <- function(a, b) if (is.null(a) || is.na(a)) b else a
