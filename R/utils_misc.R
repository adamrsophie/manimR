# Helpers ported from manim/utils: iterables.py, file_ops.py, images.py,
# sounds.py, commands.py, config_ops.py and simple_functions.py.

# Python's truth value of one element, as `if x:` tests it. A mobject is
# false when it has no submobjects (Mobject.__len__).
py_truthy <- function(x) {
  if (is.null(x)) return(FALSE)
  if (is_mobject(x)) return(length(x$submobjects) > 0)
  if (is.environment(x) || is.function(x)) return(TRUE)
  if (length(x) == 0) return(FALSE)
  if (length(x) > 1 || is.list(x)) return(TRUE)
  if (is.na(x)) return(TRUE)
  if (is.character(x)) return(nzchar(x))
  if (is.logical(x) || is.numeric(x) || is.complex(x)) return(x != 0)
  TRUE
}

# The elements of a list or vector as a list; a mobject gives itself when it
# has points, then its submobjects, as iterating over it does upstream.
as_items <- function(x) {
  if (is_mobject(x)) return(x$split())
  as.list(x)
}

# Same element, by Python equality: identity for mobjects and other
# environments, value otherwise.
same_item <- function(a, b) {
  if (is.environment(a) || is.environment(b)) return(identical(a, b))
  isTRUE(all.equal(a, b, check.attributes = FALSE)) && identical(class(a), class(b)) ||
    (is.numeric(a) && is.numeric(b) && length(a) == 1 && length(b) == 1 && isTRUE(a == b))
}

item_in <- function(x, pool) {
  for (p in pool) if (same_item(x, p)) return(TRUE)
  FALSE
}

# Atomic inputs give atomic results, as R users expect.
restore_type <- function(out, ...) {
  if (all(vapply(list(...), is.atomic, NA)) && all(vapply(out, function(e) is.atomic(e) && length(e) == 1, NA))) {
    return(unlist(out, use.names = FALSE) %||% vector(typeof(..1), 0))
  }
  out
}

#' List helpers
#'
#' Ports of `manim.utils.iterables`, working on R vectors and lists (atomic
#' input gives atomic output). Elements compare as in Python: mobjects and
#' other environments by identity, everything else by value.
#'
#' * `adjacent_n_tuples(objects, n)`: the `length(objects)` windows of `n`
#'   cyclically consecutive elements; `adjacent_pairs()` uses `n = 2`.
#' * `all_elements_are_instances(iterable, Class)`: whether every element
#'   inherits from `Class` (a class name or an R6 class generator).
#' * `concatenate_lists(...)`: all elements of the arguments, in order.
#' * `list_difference_update(l1, l2, key)`: the elements of `l1` that are not
#'   in `l2`; `list_update(l1, l2, key)` appends `l2` to that, so elements of
#'   `l2` move to the end. With `key`, elements compare by `key(element)`.
#' * `listify(obj)` and `tuplify(obj)`: `obj` as a list; a single string is
#'   one element, a mobject gives its submobjects (R has no tuples, so both
#'   return a list).
#' * `make_even(iterable_1, iterable_2)`: both stretched to the longer
#'   length by repeating elements in place; `make_even_by_cycling()` repeats
#'   them cyclically. Each returns a list of the two results.
#' * `remove_list_redundancies(lst)`: drops repeated elements, keeping the
#'   last occurrence of each.
#' * `remove_nones(sequence)`: drops elements that are false in Python's
#'   sense (`NULL`, `FALSE`, `0`, `""`, empty vectors, and mobjects without
#'   submobjects), as upstream's `if x` filter does.
#' * `stretch_array_to_length(nparray, length)`: a vector, or a matrix by
#'   rows, stretched to `length` entries by repeating them in place; it is an
#'   error to shrink.
#' * `resize_array(nparray, length)`: a vector, or a matrix by rows, cut or
#'   cyclically repeated to `length` entries (as `numpy.resize`).
#'   `resize_preserving_order()` repeats or drops entries in place instead,
#'   and `resize_with_interpolation()` interpolates linearly between
#'   neighboring entries.
#' * `batch_by_property(items, property_func)`: consecutive items with the
#'   same `property_func(item)` grouped; a list of `list(batch, property)`
#'   pairs.
#' * `uniq_chain(...)`: the elements of all arguments in order, without
#'   repeats.
#' * `hash_obj(obj)`: a hash (a string) of a nested list that does not depend
#'   on the order of the entries of named lists.
#' * `flatten_iterable_parameters(args)`: the elements of `args`, with those
#'   that are themselves lists or vectors of several elements spliced in (one
#'   level).
#' * `extract_mobject_family_members(mobject_list, use_z_index,
#'   only_those_with_points)`: every member of the families of the mobjects,
#'   once each, optionally sorted by `z_index` and without the members that
#'   have no points.
#'   `restructure_list_to_exclude_certain_family_members(mobject_list,
#'   to_remove)` drops `to_remove` and their family from the list; a group
#'   that holds one of them is replaced by its remaining members.
#'
#' @param objects,iterable,iterable_1,iterable_2,lst,sequence,l1,l2,obj,items A
#'   vector or list.
#' @param property_func Function giving the property of an item.
#' @param args A list.
#' @param mobject_list,to_remove Lists of mobjects.
#' @param use_z_index Sort the result by `z_index`.
#' @param only_those_with_points Keep only mobjects that have points.
#' @param n Window size.
#' @param Class A class name or R6 class generator.
#' @param key `NULL`, or a function giving the value elements compare by.
#' @param nparray A vector or matrix.
#' @param length Length of the result.
#' @param ... Vectors or lists.
#' @return A list or a vector, as described above for each function.
#'   `all_elements_are_instances()` returns `TRUE` or `FALSE`, and `hash_obj()`
#'   returns a hash string.
#' @name list_helpers
#' @examples
#' adjacent_pairs(1:4)
#' list_update(c(1, 2, 3, 4), c(2, 5))
#' make_even(1:3, 4:8)
#' remove_list_redundancies(c(1, 2, 1, 3, 2, 4))
NULL

#' @rdname list_helpers
#' @export
adjacent_n_tuples <- function(objects, n) {
  items <- as_items(objects)
  m <- length(items)
  out <- lapply(seq_len(m), function(i) items[((i - 1 + seq_len(n) - 1) %% m) + 1])
  if (is.atomic(objects)) lapply(out, unlist, use.names = FALSE) else out
}

#' @rdname list_helpers
#' @export
adjacent_pairs <- function(objects) adjacent_n_tuples(objects, 2)

#' @rdname list_helpers
#' @export
all_elements_are_instances <- function(iterable, Class) {
  cls <- if (inherits(Class, "R6ClassGenerator")) Class$classname else Class
  all(vapply(as_items(iterable), inherits, NA, what = cls))
}

#' @rdname list_helpers
#' @export
concatenate_lists <- function(...) {
  out <- do.call(c, lapply(list(...), as_items))
  restore_type(out %||% list(), ...)
}

#' @rdname list_helpers
#' @export
list_difference_update <- function(l1, l2, key = NULL) {
  a <- as_items(l1)
  b <- as_items(l2)
  if (is.null(key)) {
    keep <- !vapply(a, item_in, NA, pool = b)
  } else {
    kb <- lapply(b, key)
    keep <- !vapply(a, function(e) item_in(key(e), kb), NA)
  }
  restore_type(a[keep], l1)
}

#' @rdname list_helpers
#' @export
list_update <- function(l1, l2, key = NULL) {
  b <- as_items(l2)
  if (!length(b)) return(l1)
  # Scenes call this on mobject lists all the time; compare their ids.
  if (is.null(key) && all(vapply(b, is_mobject, NA)) && all(vapply(as_items(l1), is_mobject, NA))) {
    ids <- vapply(b, function(m) m$mob_id, "")
    return(c(Filter(function(m) !m$mob_id %in% ids, as_items(l1)), b))
  }
  restore_type(c(as_items(list_difference_update(l1, l2, key)), b), l1, l2)
}

#' @rdname list_helpers
#' @export
listify <- function(obj) {
  if (is.character(obj) && length(obj) == 1) return(list(obj))
  if (is_mobject(obj) || is.list(obj) || (is.atomic(obj) && length(obj) != 1)) return(as_items(obj))
  list(obj)
}

#' @rdname list_helpers
#' @export
tuplify <- function(obj) listify(obj)

#' @rdname list_helpers
#' @export
make_even <- function(iterable_1, iterable_2) {
  a <- as_items(iterable_1)
  b <- as_items(iterable_2)
  n <- max(length(a), length(b))
  pick <- function(x) x[((seq_len(n) - 1) * length(x)) %/% n + 1]
  list(restore_type(pick(a), iterable_1), restore_type(pick(b), iterable_2))
}

#' @rdname list_helpers
#' @export
make_even_by_cycling <- function(iterable_1, iterable_2) {
  a <- as_items(iterable_1)
  b <- as_items(iterable_2)
  n <- max(length(a), length(b))
  list(restore_type(rep_len(a, n), iterable_1), restore_type(rep_len(b, n), iterable_2))
}

#' @rdname list_helpers
#' @export
remove_list_redundancies <- function(lst) {
  items <- as_items(lst)
  keep <- logical(length(items))
  seen <- list()
  for (i in rev(seq_along(items))) {
    if (!item_in(items[[i]], seen)) {
      keep[i] <- TRUE
      seen[[length(seen) + 1]] <- items[[i]]
    }
  }
  restore_type(items[keep], lst)
}

#' @rdname list_helpers
#' @export
remove_nones <- function(sequence) {
  items <- as_items(sequence)
  out <- items[vapply(items, py_truthy, NA)]
  if (is.atomic(sequence) && !is.character(sequence)) return(restore_type(out, sequence))
  out
}

# Rows of a matrix, or entries of a vector, picked by index.
take_entries <- function(a, idx) if (is.matrix(a)) a[idx, , drop = FALSE] else a[idx]
n_entries <- function(a) if (is.matrix(a)) nrow(a) else length(a)

#' @rdname list_helpers
#' @export
resize_array <- function(nparray, length) {
  n <- n_entries(nparray)
  if (n == length) return(nparray)
  if (n == 0) return(if (is.matrix(nparray)) matrix(0, length, ncol(nparray)) else numeric(length))
  take_entries(nparray, rep_len(seq_len(n), length))
}

#' @rdname list_helpers
#' @export
resize_preserving_order <- function(nparray, length) {
  n <- n_entries(nparray)
  if (n == 0) return(if (is.matrix(nparray)) matrix(0, length, ncol(nparray)) else numeric(length))
  if (n == length) return(nparray)
  take_entries(nparray, ((seq_len(length) - 1) * n) %/% length + 1)
}

#' @rdname list_helpers
#' @export
resize_with_interpolation <- function(nparray, length) {
  n <- n_entries(nparray)
  if (n == length) return(nparray)
  ci <- seq(0, n - 1, length.out = length)
  a <- ci %% 1
  lo <- take_entries(nparray, floor(ci) + 1)
  hi <- take_entries(nparray, ceiling(ci) + 1)
  (1 - a) * lo + a * hi
}

#' @rdname list_helpers
#' @export
batch_by_property <- function(items, property_func) {
  out <- list()
  batch <- list()
  prop <- NULL
  for (item in as_items(items)) {
    p <- property_func(item)
    if (!length(batch) || !identical(p, prop)) {
      if (length(batch)) out[[length(out) + 1]] <- list(batch, prop)
      prop <- p
      batch <- list(item)
    } else {
      batch[[length(batch) + 1]] <- item
    }
  }
  if (length(batch)) out[[length(out) + 1]] <- list(batch, prop)
  out
}

#' @rdname list_helpers
#' @export
uniq_chain <- function(...) {
  out <- list()
  for (x in unlist(lapply(list(...), as_items), recursive = FALSE)) {
    if (!item_in(x, out)) out[[length(out) + 1]] <- x
  }
  if (...length() == 0) list() else restore_type(out, ...)
}

#' @rdname list_helpers
#' @export
flatten_iterable_parameters <- function(args) {
  out <- list()
  for (a in args) {
    if (is_mobject(a) || is.function(a) || is.environment(a) || (!is.list(a) && length(a) == 1)) out[[length(out) + 1]] <- a
    else out <- c(out, as.list(a))
  }
  out
}

#' @rdname list_helpers
#' @export
restructure_list_to_exclude_certain_family_members <- function(mobject_list, to_remove) {
  get_restructured_mobject_list(mobject_list, extract_mobject_family_members(to_remove))
}

#' @rdname list_helpers
#' @export
hash_obj <- function(obj) {
  if (is.list(obj)) {
    parts <- vapply(obj, hash_obj, "")
    if (is_dict(obj)) parts <- sort(paste(vapply(names(obj), hash_obj, ""), parts))
    return(digest::digest(unname(parts), algo = "xxhash64"))
  }
  digest::digest(obj, algo = "xxhash64")
}

#' Path and file helpers
#'
#' Ports of `manim.utils.file_ops` and the path lookups of
#' `manim.utils.images` and `manim.utils.sounds`.
#'
#' * `add_extension_if_not_present(file_name, extension)` appends
#'   `extension` (such as `".png"`) unless the name already ends with it.
#' * `guarantee_existence(path)` creates the directory if needed;
#'   `guarantee_empty_existence(path)` first deletes it. Both return the
#'   absolute path.
#' * `seek_full_path_from_defaults(file_name, default_dir, extensions)`
#'   returns the first existing path among `file_name` and `file_name` plus
#'   each extension inside `default_dir`, and errors if there is none.
#'   `get_full_raster_image_path()`, `get_full_vector_image_path()` and
#'   `get_full_sound_file_path()` look for images (`.jpg`, `.jpeg`, `.png`,
#'   `.gif`, `.ico`), vector images (`.svg`) and sounds (`.wav`, `.mp3`) in
#'   the `assets_dir` setting (default `"./"`).
#' * `add_version_before_extension(file_name)` inserts the package version
#'   before the extension (`"a.png"` gives `"a_manimR_v<version>.png"`), as
#'   the default names of saved images and GIFs do.
#' * `convert_audio(input_path, output_path, codec_name)` writes the audio
#'   of a file in another codec (such as `"pcm_s16le"` or `"aac"`) with
#'   `ffmpeg`.
#' * `modify_atime(file_path)` sets a file's access time to now, keeping its
#'   modification time.
#' * `open_file(file_path, in_browser)` opens a file with the system viewer,
#'   or shows it in the file browser; the `preview_command` setting replaces
#'   the viewer.
#' * `ensure_executable(path_to_exe)` tells whether a program can be run:
#'   a bare name is looked up on the `PATH`.
#'
#' @param file_name,file_path,path,path_to_exe A path.
#' @param extension A file extension including its dot.
#' @param default_dir Directory to look in.
#' @param extensions Extensions to try, each including its dot.
#' @param in_browser Show the file in the file browser instead of opening it.
#' @param image_file_name,sound_file_name A file name.
#' @param input_path,output_path Audio files to read and to write.
#' @param codec_name Name of an `ffmpeg` audio encoder.
#' @param assets_dir Directory to look in.
#' @return A path (a character string) from the functions that find or change
#'   one; `guarantee_existence()` and `guarantee_empty_existence()` return the
#'   normalized path of the directory. `convert_audio()` returns `output_path`
#'   invisibly, `modify_atime()` and `open_file()` return `NULL` invisibly, and
#'   `ensure_executable()` returns `TRUE` or `FALSE`.
#' @name path_helpers
#' @examples
#' add_extension_if_not_present("scene", ".png")
#' d <- guarantee_existence(file.path(tempdir(), "manimR-example"))
#' dir.exists(d)
NULL

#' @rdname path_helpers
#' @export
add_extension_if_not_present <- function(file_name, extension) {
  ext <- tools::file_ext(file_name)
  suffix <- if (nzchar(ext)) paste0(".", ext) else ""
  if (suffix != extension) paste0(file_name, extension) else file_name
}

#' @rdname path_helpers
#' @export
guarantee_existence <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  normalizePath(path, mustWork = TRUE)
}

#' @rdname path_helpers
#' @export
guarantee_empty_existence <- function(path) {
  if (file.exists(path)) unlink(path, recursive = TRUE)
  guarantee_existence(path)
}

#' @rdname path_helpers
#' @export
seek_full_path_from_defaults <- function(file_name, default_dir, extensions) {
  # As pathlib's default_dir / file_name, an absolute file name ignores
  # default_dir.
  base <- path.expand(file_name)
  if (!grepl("^(/|[A-Za-z]:|\\\\)", base)) base <- file.path(default_dir, file_name)
  candidates <- c(path.expand(file_name), paste0(base, c("", extensions)))
  hit <- candidates[file.exists(candidates)]
  if (length(hit)) return(hit[1])
  stop("From: ", getwd(), ", could not find ", file_name, " at either of these locations: ",
       paste(candidates, collapse = ", "), call. = FALSE)
}

#' @rdname path_helpers
#' @export
get_full_raster_image_path <- function(image_file_name) {
  seek_full_path_from_defaults(image_file_name, cfg("assets_dir") %||% "./", c(".jpg", ".jpeg", ".png", ".gif", ".ico"))
}

#' @rdname path_helpers
#' @export
get_full_vector_image_path <- function(image_file_name) {
  seek_full_path_from_defaults(image_file_name, cfg("assets_dir") %||% "./", ".svg")
}

#' @rdname path_helpers
#' @export
add_version_before_extension <- function(file_name) versioned_path(file_name)

#' @rdname path_helpers
#' @export
convert_audio <- function(input_path, output_path, codec_name) {
  out <- suppressWarnings(system2(ffmpeg_path(), c("-y", "-loglevel", "error", "-i", shQuote(path.expand(input_path)),
                                                   "-vn", "-c:a", codec_name, shQuote(path.expand(output_path))),
                                  stdout = TRUE, stderr = TRUE))
  if (!is.null(attr(out, "status")) || !file.exists(output_path)) {
    stop("Could not convert ", input_path, " to ", codec_name, ": ", paste(out, collapse = "\n"), call. = FALSE)
  }
  invisible(output_path)
}

#' @rdname path_helpers
#' @export
get_full_sound_file_path <- function(sound_file_name, assets_dir = cfg("assets_dir") %||% "./") {
  seek_full_path_from_defaults(sound_file_name, assets_dir, c(".wav", ".mp3"))
}

#' @rdname path_helpers
#' @export
modify_atime <- function(file_path) {
  if (!file.exists(file_path)) stop("File not found: ", file_path, call. = FALSE)
  if (.Platform$OS.type == "unix" && nzchar(Sys.which("touch"))) {
    status <- system2("touch", c("-a", shQuote(file_path)))
    if (status == 0) return(invisible(NULL))
  }
  # Without touch, R can only set both times; keep the modification time.
  Sys.setFileTime(file_path, file.mtime(file_path))
  invisible(NULL)
}

#' @rdname path_helpers
#' @export
open_file <- function(file_path, in_browser = FALSE) {
  sys <- Sys.info()[["sysname"]]
  target <- if (in_browser && sys != "Darwin") dirname(file_path) else file_path
  if (sys == "Windows") {
    shell_exec <- get("shell.exec", envir = baseenv())
    return(invisible(shell_exec(target)))
  }
  cmd <- if (sys == "Darwin") {
    if (in_browser) c("open", "-R") else "open"
  } else if (sys == "Linux") {
    "xdg-open"
  } else if (startsWith(sys, "CYGWIN")) {
    "cygstart"
  } else {
    stop("Unable to identify your operating system...", call. = FALSE)
  }
  if (nzchar(cfg("preview_command") %||% "")) cmd <- cfg("preview_command")
  system2(cmd[1], c(cmd[-1], shQuote(target)), wait = FALSE)
  invisible(NULL)
}

#' @rdname path_helpers
#' @export
ensure_executable <- function(path_to_exe) {
  exe <- path_to_exe
  if (dirname(path_to_exe) == ".") {
    exe <- Sys.which(tools::file_path_sans_ext(basename(path_to_exe)))
    if (!nzchar(exe)) return(FALSE)
  }
  file.access(exe, 1) == 0
}

#' Image array helpers
#'
#' Ports of `manim.utils.images`, on image arrays of values 0 to 255
#' (`height x width x channels`, as [ImageMobject()] stores them).
#'
#' * `change_to_rgba_array(image, dtype)` adds channels so the array is
#'   RGBA: a gray image is repeated into RGB, and a missing alpha channel
#'   becomes 255. Unlike upstream, a gray plus alpha image is also accepted.
#'   `dtype` is accepted for compatibility; R keeps numbers as doubles.
#' * `invert_image(image)` returns `255 - image` for every channel,
#'   alpha included, as upstream.
#' * `drag_pixels(frames)` returns the frames with every pixel that is 0 so
#'   far filled from the next frame where it is not, a trail effect.
#'
#' @param image An image array.
#' @param dtype Ignored.
#' @param frames A list of image arrays of equal size.
#' @return `change_to_rgba_array()` returns an array of height by width by 4
#'   channels, `invert_image()` the image array with its colors inverted, and
#'   `drag_pixels()` a list of frames.
#' @name image_helpers
#' @examples
#' change_to_rgba_array(matrix(c(1, 2, 3, 4), 2))[1, 1, ]
NULL

#' @rdname image_helpers
#' @export
invert_image <- function(image) 255 - image

#' @rdname image_helpers
#' @export
drag_pixels <- function(frames) {
  curr <- frames[[1]]
  lapply(frames, function(frame) {
    curr <<- curr + (curr == 0) * frame
    curr
  })
}

#' Run commands and inspect outputs
#'
#' Ports of `manim.utils.commands`.
#'
#' * `capture(command, cwd, command_input)` runs a command (a character
#'   vector: the program, then its arguments) and returns
#'   `list(out, err, returncode)`.
#' * `get_dir_layout(dirpath)` lists the files below a directory, as paths
#'   relative to it.
#' * `get_video_metadata(path_to_video)` returns the width, height, number
#'   of frames, duration, average frame rate, codec and pixel format of the
#'   first video stream, read with ffprobe (or ffmpeg when ffprobe is not
#'   installed). As upstream, `nb_frames` and `duration` are strings and the
#'   frames are counted by decoding when the container does not record them.
#'
#' @param command A character vector: the program and its arguments.
#' @param cwd Working directory for the command.
#' @param command_input Text passed to the command's standard input.
#' @param dirpath A directory.
#' @param path_to_video A video file.
#' @return `capture()` returns a list with the output `out`, the error output
#'   `err` and the exit status `returncode`. `get_dir_layout()` returns a
#'   character vector of the paths below `dirpath`. `get_video_metadata()`
#'   returns a list with `width`, `height`, `nb_frames`, `duration`,
#'   `avg_frame_rate`, `codec_name` and `pix_fmt`.
#' @name command_helpers
#' @examples
#' capture(c("R", "--version"))$returncode
NULL

#' @rdname command_helpers
#' @export
capture <- function(command, cwd = NULL, command_input = NULL) {
  if (!is.null(cwd)) {
    old <- setwd(cwd)
    on.exit(setwd(old), add = TRUE)
  }
  out_file <- tempfile()
  err_file <- tempfile()
  on.exit(unlink(c(out_file, err_file)), add = TRUE)
  args <- if (length(command) > 1) shQuote(command[-1]) else character()
  code <- suppressWarnings(system2(command[1], args, stdout = out_file, stderr = err_file,
                                   input = command_input))
  read <- function(f) if (file.exists(f)) paste(readLines(f, warn = FALSE), collapse = "\n") else ""
  list(out = read(out_file), err = read(err_file), returncode = as.integer(code))
}

#' @rdname command_helpers
#' @export
get_dir_layout <- function(dirpath) list.files(dirpath, recursive = TRUE, all.files = TRUE, no.. = TRUE)

#' @rdname command_helpers
#' @export
get_video_metadata <- function(path_to_video) {
  if (!file.exists(path_to_video)) stop("Video file not found: ", path_to_video, call. = FALSE)
  probe <- Sys.which("ffprobe")
  fields <- if (nzchar(probe)) {
    out <- suppressWarnings(system2(probe, c("-v", "error", "-select_streams", "v:0", "-show_entries",
                                             "stream=width,height,nb_frames,duration,avg_frame_rate,codec_name,pix_fmt",
                                             "-of", "default=noprint_wrappers=1", shQuote(path_to_video)),
                                    stdout = TRUE, stderr = FALSE))
    kv <- strsplit(out[grepl("=", out)], "=", fixed = TRUE)
    stats::setNames(lapply(kv, `[`, 2), vapply(kv, `[`, "", 1))
  } else {
    ffmpeg_stream_fields(path_to_video)
  }
  rate <- fields$avg_frame_rate
  rp <- as.numeric(strsplit(rate, "/", fixed = TRUE)[[1]])
  rate_num <- if (length(rp) == 2) rp[1] / rp[2] else rp[1]
  frames <- suppressWarnings(as.numeric(fields$nb_frames))
  duration <- suppressWarnings(as.numeric(fields$duration))
  if (is.na(duration) || is.na(frames)) {
    frames <- count_video_frames(path_to_video)
    duration <- frames / rate_num
  }
  list(width = as.integer(fields$width), height = as.integer(fields$height),
       nb_frames = format(frames, scientific = FALSE), duration = sprintf("%.6f", duration),
       avg_frame_rate = rate, codec_name = fields$codec_name, pix_fmt = fields$pix_fmt)
}

# Stream fields read from `ffmpeg -i`, for systems without ffprobe.
ffmpeg_stream_fields <- function(path) {
  out <- suppressWarnings(system2(ffmpeg_path(), c("-hide_banner", "-i", shQuote(path)), stdout = TRUE, stderr = TRUE))
  line <- grep("Stream #0:[0-9]+.*: Video: ", out, value = TRUE)[1]
  if (is.na(line)) stop("No video stream in ", path, call. = FALSE)
  desc <- sub(".*Video: ", "", line)
  codec <- sub("^([A-Za-z0-9_]+).*", "\\1", desc)
  parts <- trimws(strsplit(gsub("\\([^)]*\\)", "", desc), ",")[[1]])
  size <- regmatches(desc, regexpr("[0-9]+x[0-9]+", desc))
  fps <- sub(" fps", "", grep(" fps$", parts, value = TRUE)[1])
  list(width = strsplit(size, "x")[[1]][1], height = strsplit(size, "x")[[1]][2],
       nb_frames = NA, duration = NA, avg_frame_rate = paste0(fps, "/1"), codec_name = codec,
       pix_fmt = parts[2])
}

count_video_frames <- function(path) {
  out <- suppressWarnings(system2(ffmpeg_path(), c("-hide_banner", "-i", shQuote(path), "-map", "0:v:0",
                                                   "-f", "null", "-"), stdout = TRUE, stderr = TRUE))
  hits <- regmatches(out, regexpr("frame= *[0-9]+", out))
  if (!length(hits)) stop("Could not count the frames of ", path, call. = FALSE)
  as.numeric(sub("frame= *", "", hits[length(hits)]))
}

#' Dictionary helpers
#'
#' Ports of `manim.utils.config_ops` for named lists.
#'
#' * `merge_dicts_recursively(...)` merges named lists from left to right;
#'   where two lists hold named lists under the same name, those are merged
#'   too.
#' * `update_dict_recursively(current_dict, ...)` merges the others into
#'   `current_dict`. An environment is updated in place, as upstream updates
#'   its dict; a list cannot be, so the merged list is returned and should be
#'   assigned back.
#' * `DictAsObject(dictin)` returns an environment whose variables are the
#'   entries of `dictin`, so they read as `obj$name`.
#'
#' @param ... Named lists.
#' @param current_dict A named list or an environment.
#' @param dictin A named list.
#' @return `merge_dicts_recursively()` and `update_dict_recursively()` return
#'   the merged list. `DictAsObject()` returns an environment that holds the
#'   entries of the list.
#' @name dict_helpers
#' @examples
#' merge_dicts_recursively(list(a = 1, b = list(x = 1)), list(b = list(y = 2)))
NULL

is_dict <- function(x) is.list(x) && !is.null(names(x)) && all(nzchar(names(x)))

#' @rdname dict_helpers
#' @export
merge_dicts_recursively <- function(...) {
  result <- list()
  for (d in list(...)) {
    if (is.environment(d)) d <- as.list(d, all.names = TRUE)
    for (key in names(d)) {
      value <- d[[key]]
      if (key %in% names(result) && is_dict(result[[key]]) && is_dict(value)) {
        result[[key]] <- merge_dicts_recursively(result[[key]], value)
      } else {
        result[key] <- list(value)
      }
    }
  }
  result
}

#' @rdname dict_helpers
#' @export
update_dict_recursively <- function(current_dict, ...) {
  merged <- merge_dicts_recursively(current_dict, ...)
  if (is.environment(current_dict)) {
    list2env(merged, envir = current_dict)
    return(invisible(current_dict))
  }
  merged
}

#' @rdname dict_helpers
#' @export
DictAsObject <- function(dictin) {
  env <- list2env(as.list(dictin), parent = emptyenv())
  class(env) <- "DictAsObject"
  env
}

#' Clip a value to a range
#'
#' Upstream's `clip(a, min_a, max_a)` from `manim.utils.simple_functions`,
#' named `clip_value()` here because an exported `clip()` would mask
#' `graphics::clip()`. Upstream's `choose(n, k)` needs no port:
#' [base::choose()] computes the same binomial coefficient.
#'
#' @param a A value.
#' @param min_a,max_a The range.
#' @return `min_a` when `a` is below it, `max_a` when above, else `a`.
#' @export
#' @examples
#' clip_value(5, 0, 3)
clip_value <- function(a, min_a, max_a) {
  if (a < min_a) return(min_a)
  if (a > max_a) return(max_a)
  a
}

# Opens the artifact of a finished render, as upstream's open_media_file():
# in the RStudio Viewer or system viewer, or with preview_command, and in
# the file browser.
open_media_file <- function(file_writer, preview, show_in_file_browser) {
  path <- file_writer$final_file_path
  if (is.null(path)) {
    logger$warning("No media artifact is available to open.")
    return(invisible(NULL))
  }
  if (show_in_file_browser) open_file(path, in_browser = TRUE)
  if (preview) {
    if (nzchar(cfg("preview_command") %||% "")) open_file(path) else preview_output(path)
    logger$info("Previewed File at: '%s'", path)
  }
  invisible(path)
}
