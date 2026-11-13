misc_oracle <- function() {
  skip_if_not_installed("jsonlite")
  jsonlite::fromJSON(test_path("fixtures", "utils_misc_oracle.json"), simplifyVector = FALSE)
}

nums <- function(x) as.numeric(unlist(x))

test_that("list helpers match manim.utils.iterables", {
  o <- misc_oracle()
  expect_equal(lapply(adjacent_n_tuples(1:5, 3), as.numeric), lapply(o$adjacent_n_tuples, nums))
  expect_equal(lapply(adjacent_pairs(1:4), as.numeric), lapply(o$adjacent_pairs, nums))
  expect_equal(as.numeric(concatenate_lists(c(1, 2), 3, numeric(), c(4, 5))), nums(o$concatenate_lists))
  expect_equal(list_difference_update(c(1, 2, 3, 4, 2), c(2, 5)), nums(o$list_difference_update))
  expect_equal(list_update(c(1, 2, 3, 4), c(2, 5)), nums(o$list_update))
  expect_equal(listify("abc"), list("abc"))
  expect_equal(listify(c(1, 2)), list(1, 2))
  expect_equal(listify(7), list(7))
  expect_equal(unlist(tuplify(c(3, 4))), nums(o$tuplify))
  expect_equal(lapply(make_even(c(1, 2, 3), c(4, 5, 6, 7, 8)), as.numeric), lapply(o$make_even, nums))
  expect_equal(lapply(make_even_by_cycling(c(1, 2, 3), 1:7), as.numeric), lapply(o$make_even_by_cycling, nums))
  expect_equal(remove_list_redundancies(c(1, 2, 1, 3, 2, 4)), nums(o$remove_list_redundancies))
  expect_equal(remove_nones(list(0, 1, NULL, "", "a", 2, FALSE, TRUE)), o$remove_nones)
  expect_equal(stretch_array_to_length(c(10, 20, 30), 7), nums(o$stretch_array_to_length))
  expect_error(stretch_array_to_length(1:5, 3), "shorter")
})

test_that("list helpers compare mobjects by identity", {
  a <- Square()
  b <- Circle()
  c2 <- Square()
  expect_length(list_update(list(a, b), list(a)), 2)
  expect_identical(list_update(list(a, b), list(a))[[2]], a)
  expect_identical(remove_list_redundancies(list(a, b, a, c2)), list(b, a, c2))
  expect_true(all_elements_are_instances(list(a, c2), "Square"))
  expect_false(all_elements_are_instances(list(a, b), SquareClass))
  expect_length(listify(VGroup(a, b)), 2)
  # As upstream, a mobject without submobjects is false.
  expect_length(remove_nones(list(a, VGroup(b))), 1)
  expect_equal(list_difference_update(list("a", "B"), list("b"), key = tolower), list("a"))
})

test_that("dictionary helpers match manim.utils.config_ops", {
  o <- misc_oracle()
  m <- merge_dicts_recursively(list(a = 1, b = list(x = 1, y = 2), c = 3),
                               list(b = list(y = 20, z = 30), c = list(k = 1)), list(a = 5))
  expect_equal(m, o$merge_dicts)
  env <- list2env(list(a = 1, b = list(x = 1)))
  update_dict_recursively(env, list(b = list(y = 2)))
  expect_equal(env$b, list(x = 1, y = 2))
  expect_equal(update_dict_recursively(list(a = 1), list(a = 2, b = 3)), list(a = 2, b = 3))
  d <- DictAsObject(list(width = 3, name = "x"))
  expect_equal(d$width, 3)
  expect_equal(d$name, "x")
})

test_that("image helpers match manim.utils.images", {
  o <- misc_oracle()
  arr3 <- function(x) {
    a <- simplify2array(lapply(x, function(row) simplify2array(lapply(row, nums))))
    aperm(a, c(3, 2, 1))
  }
  img <- array(c(0, 100, 10, 200, 255, 50), c(1, 2, 3))
  expect_equal(invert_image(img), arr3(o$invert_image))
  expect_equal(change_to_rgba_array(matrix(c(1, 3, 2, 4), 2)), arr3(o$rgba_from_2d))
  expect_equal(change_to_rgba_array(array(c(1, 2, 3), c(1, 1, 3))), arr3(o$rgba_from_rgb))
  frames <- list(matrix(c(0, 0, 5, 0), 2), matrix(c(7, 0, 1, 2), 2), matrix(c(9, 3, 9, 9), 2))
  ref <- lapply(o$drag_pixels, function(f) matrix(nums(f), 2, byrow = TRUE))
  expect_equal(drag_pixels(frames), ref)
})

test_that("path helpers match manim.utils.file_ops", {
  o <- misc_oracle()
  got <- c(add_extension_if_not_present("scene", ".png"), add_extension_if_not_present("scene.png", ".png"),
           add_extension_if_not_present("scene.txt", ".png"), add_extension_if_not_present("dir/a.b", ".svg"))
  expect_equal(got, unlist(o$ext))
  dir <- withr_tempdir()
  writeLines("x", file.path(dir, "logo.png"))
  expect_equal(seek_full_path_from_defaults("logo", dir, c(".jpg", ".png")), file.path(dir, "logo.png"))
  expect_error(seek_full_path_from_defaults("nope", dir, ".png"), "could not find nope")
  old <- manim_config(assets_dir = dir)
  on.exit(manim_config(assets_dir = old$assets_dir), add = TRUE)
  expect_equal(get_full_raster_image_path("logo"), file.path(dir, "logo.png"))
  writeLines("x", file.path(dir, "click.wav"))
  expect_equal(get_full_sound_file_path("click", dir), file.path(dir, "click.wav"))
  sub <- file.path(dir, "a", "b")
  expect_true(dir.exists(guarantee_existence(sub)))
  writeLines("x", file.path(sub, "f.txt"))
  guarantee_empty_existence(sub)
  expect_length(list.files(sub), 0)
  r_exe <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "R.exe" else "R")
  expect_true(ensure_executable(r_exe))
  expect_false(ensure_executable("surely-not-a-program-xyz"))
  f <- file.path(dir, "logo.png")
  mt <- file.mtime(f)
  modify_atime(f)
  expect_equal(file.mtime(f), mt)
  expect_setequal(get_dir_layout(dir), c("logo.png", "click.wav"))
})

test_that("commands and video metadata work", {
  r <- capture(c(file.path(R.home("bin"), "Rscript"), "-e", "cat('hi'); message('err'); quit(status = 3)"))
  expect_equal(r$out, "hi")
  expect_equal(r$err, "err")
  expect_equal(r$returncode, 3L)
  skip_if_not(nzchar(Sys.which("ffmpeg")))
  skip_on_cran()
  dir <- withr_tempdir()
  out <- render(function(self) self$play(FadeIn(Square()), run_time = 0.4), quality = "l", media_dir = dir)
  meta <- get_video_metadata(out)
  expect_equal(meta[c("width", "height", "nb_frames", "avg_frame_rate", "codec_name", "pix_fmt")],
               list(width = 854L, height = 480L, nb_frames = "6", avg_frame_rate = "15/1",
                    codec_name = "h264", pix_fmt = "yuv420p"))
  expect_equal(as.numeric(meta$duration), 0.4, tolerance = 0.01)
})

test_that("clip_value matches upstream clip()", {
  o <- misc_oracle()
  expect_equal(c(clip_value(5, 0, 3), clip_value(-1, 0, 3), clip_value(2, 0, 3)), nums(o$clip))
})

test_that("rate functions round as upstream's float arithmetic does", {
  # Values from manim 0.22.1 with a correctly rounded pow(), as glibc gives.
  expect_identical(ease_in_back(1 / 997), -0x1.cac91d75da5ddp-20)
  expect_identical(ease_in_back(2 / 997), -0x1.ca0dc87159c01p-18)
  expect_identical(ease_in_back(4 / 997), -0x1.c8971e685884ap-16)
  expect_identical(ease_out_cubic(3 / 997), 0x1.26e904582f900p-7)
  expect_identical(ease_out_cubic(6 / 997), 0x1.2605d857cc2a0p-6)
  expect_identical(cr_pow(0.7, 4), 0x1.ebb98c7e2823fp-3)
})
