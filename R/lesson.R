# A movie, its chapters, captions and transcript as a folder that plays in
# any browser without R or a network.

#' Write a lesson page for a rendered movie
#'
#' `write_lesson()` writes a folder with the movie, its captions as WebVTT,
#' its sections as WebVTT chapters, and an `index.html` page that plays the
#' movie. The page has a button for each chapter, captions, a transcript
#' whose lines jump to their time, and an option to pause at the end of
#' each chapter.
#' It needs no R, no network and no JavaScript library, so the folder can
#' be copied to any computer and opened in a browser. The movie starts
#' paused. Keys: `n` and `p` go to the next and previous chapter; the
#' movie's own controls handle the rest.
#'
#' Chapters are the sections of the scene (see `next_section()`), placed at
#' their first frame from the timeline of [render_report()]. Captions are
#' the scene's subcaptions (see `add_subcaption()`).
#'
#' @param x The value of [render()] for a movie (mp4, webm or mov).
#' @param dir Folder to write; it is created if needed.
#' @param title Title of the page; by default the movie's file name.
#' @param transcript Optional transcript, a character vector of paragraphs,
#'   shown instead of the captions.
#' @return `dir`, invisibly.
#' @export
#' @examples
#' \donttest{
#' if (nzchar(Sys.which("ffmpeg"))) {
#'   out <- render(function(self) {
#'     self$add_subcaption("A square", duration = 1)
#'     self$play(Create(Square()))
#'     self$next_section("Circle")
#'     self$add_subcaption("Now a circle", duration = 1)
#'     self$play(Create(Circle()))
#'   }, quality = "l", media_dir = tempfile())
#'   write_lesson(out, file.path(tempdir(), "lesson"))
#' }
#' }
write_lesson <- function(x, dir, title = NULL, transcript = NULL) {
  report <- render_report(x)
  if (is.null(report)) stop("`x` must be the value of render().", call. = FALSE)
  movie <- unclass(x)
  ext <- tolower(tools::file_ext(movie))
  if (!ext %in% c("mp4", "webm", "mov")) stop("write_lesson() needs a movie (mp4, webm or mov).", call. = FALSE)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  file.copy(movie, file.path(dir, basename(movie)), overwrite = TRUE)
  title <- title %||% tools::file_path_sans_ext(basename(movie))
  fps <- report$frame_rate
  chapters <- report$sections[report$sections$frames > 0, , drop = FALSE]
  # A chapter starts half a frame into its first frame, so a seek shows
  # that frame and not the one before it.
  chapters$seek <- (chapters$start_frame + 0.5) / fps
  chapters$label <- ifelse(chapters$section == "autocreated" | is.na(chapters$section), "Start", chapters$section)
  write_vtt(data.frame(start = chapters$start, end = chapters$end, text = chapters$label), file.path(dir, "chapters.vtt"))
  captions <- report$captions
  if (nrow(captions)) write_vtt(captions, file.path(dir, "captions.vtt"))
  writeLines(lesson_html(title, basename(movie), chapters, captions, transcript), file.path(dir, "index.html"),
             useBytes = TRUE)
  invisible(dir)
}

vtt_time <- function(t) {
  t <- pmax(t, 0)
  sprintf("%02d:%02d:%06.3f", as.integer(t %/% 3600), as.integer((t %% 3600) %/% 60), t %% 60)
}

write_vtt <- function(cues, file) {
  lines <- c("WEBVTT", "", unlist(lapply(seq_len(nrow(cues)), function(i) {
    c(paste(vtt_time(cues$start[i]), "-->", vtt_time(cues$end[i])), vtt_escape(cues$text[i]), "")
  })))
  writeLines(enc2utf8(lines), file, useBytes = TRUE)
  invisible(file)
}

# WebVTT cue text escapes &, < and >; "-->" cannot appear in a cue.
vtt_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE)
}

js_escape <- function(x) {
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub("\"", "\\\"", x, fixed = TRUE)
  x <- gsub("\n", "\\n", x, fixed = TRUE)
  gsub("<", "\\u003c", x, fixed = TRUE)
}

html_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub("\"", "&quot;", x, fixed = TRUE)
}

lesson_html <- function(title, movie, chapters, captions, transcript) {
  buttons <- sprintf('<li><button type="button" data-t="%.6f">%s <span class="time">%s</span></button></li>',
                     chapters$seek, html_escape(chapters$label), substr(vtt_time(chapters$start), 4, 8))
  lines <- if (!is.null(transcript)) sprintf("<p>%s</p>", html_escape(transcript))
           else if (nrow(captions)) sprintf('<p><button type="button" class="cue" data-t="%.6f">%s</button> %s</p>',
                                           captions$start + 1e-3, substr(vtt_time(captions$start), 4, 8),
                                           html_escape(captions$text))
           else "<p>This movie has no captions.</p>"
  # Browsers do not load <track> files next to a page opened from disk, so
  # the page adds the caption cues itself; the .vtt files are for other
  # players.
  cues <- if (nrow(captions)) {
    sprintf("[%.6f, %.6f, \"%s\"]", captions$start, captions$end, js_escape(vtt_escape(captions$text)))
  }
  c('<!doctype html>',
    '<html lang="en">',
    '<head>',
    '<meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    sprintf('<title>%s</title>', html_escape(title)),
    '<style>',
    'body { font-family: system-ui, sans-serif; max-width: 960px; margin: 1rem auto; padding: 0 1rem; color: #111; background: #fff; }',
    'video { width: 100%; background: #000; }',
    'ol { list-style: none; padding: 0; display: flex; flex-wrap: wrap; gap: .5rem; }',
    'button { font: inherit; padding: .3rem .7rem; cursor: pointer; }',
    'button[aria-current="true"] { font-weight: bold; outline: 2px solid #236; }',
    '.time { color: #555; font-size: .85em; }',
    '#transcript p { margin: .4rem 0; }',
    '@media (prefers-color-scheme: dark) { body { color: #eee; background: #111; } .time { color: #aaa; } }',
    '</style>',
    '</head>',
    '<body>',
    sprintf('<h1>%s</h1>', html_escape(title)),
    '<video id="movie" controls preload="metadata">',
    sprintf('    <source src="%s">', html_escape(movie)),
    '</video>',
    '<nav aria-label="Chapters"><h2>Chapters</h2>',
    '<ol id="chapters">', buttons, '</ol>',
    '<label><input type="checkbox" id="pause"> Pause at the end of each chapter</label>',
    '<p class="time">Keys: n next chapter, p previous chapter.</p>',
    '</nav>',
    '<section id="transcript" aria-label="Transcript"><h2>Transcript</h2>', lines, '</section>',
    '<script>',
    'const video = document.getElementById("movie");',
    sprintf('const cues = [%s];', paste(cues, collapse = ", ")),
    'if (cues.length) {',
    '  const track = video.addTextTrack("captions", "Captions", "en");',
    '  cues.forEach(c => track.addCue(new VTTCue(c[0], c[1], c[2])));',
    '  track.mode = "showing";',
    '}',
    'const buttons = Array.from(document.querySelectorAll("#chapters button"));',
    'const starts = buttons.map(b => parseFloat(b.dataset.t));',
    'const chapterAt = t => { let i = 0; starts.forEach((s, k) => { if (t >= s - 0.01) i = k; }); return i; };',
    'const seek = t => { video.currentTime = t; };',
    'document.querySelectorAll("button[data-t]").forEach(b => b.addEventListener("click", () => seek(parseFloat(b.dataset.t))));',
    'let current = 0;',
    'video.addEventListener("timeupdate", () => {',
    '  const i = chapterAt(video.currentTime);',
    '  if (i !== current && document.getElementById("pause").checked && !video.paused && i === current + 1) {',
    '    video.pause(); seek(starts[i]);',
    '  }',
    '  current = i;',
    '  buttons.forEach((b, k) => b.setAttribute("aria-current", k === i ? "true" : "false"));',
    '});',
    'document.addEventListener("keydown", e => {',
    '  if (e.target.tagName === "INPUT" || e.altKey || e.ctrlKey || e.metaKey) return;',
    '  const i = chapterAt(video.currentTime);',
    '  if (e.key === "n" && i + 1 < starts.length) seek(starts[i + 1]);',
    '  if (e.key === "p") seek(starts[Math.max(i - 1, 0)]);',
    '});',
    '</script>',
    '</body>',
    '</html>')
}
