# Upstream: manim/cli/cfg/group.py, manim/cli/init/commands.py,
# manim/utils/file_ops.py, manim/_config/utils.py.

# Answers prompts in order; records the prompts.
answer_with <- function(answers, env = parent.frame()) {
  state <- new.env()
  state$answers <- answers
  state$prompts <- character()
  testthat::local_mocked_bindings(cli_input = function(prompt = "") {
    state$prompts <- c(state$prompts, prompt)
    if (!length(state$answers)) return("")
    a <- state$answers[[1]]
    state$answers <- state$answers[-1]
    a
  }, .env = env)
  state
}

in_tempdir <- function(env = parent.frame()) {
  d <- withr_tempdir(env)
  old <- setwd(d)
  do.call(on.exit, list(substitute(setwd(old), list(old = old)), add = TRUE), envir = env)
  d
}

test_that("value_from_string reads literals as Python's literal_eval", {
  expect_identical(value_from_string("5"), 5L)
  expect_identical(value_from_string("-1"), -1L)
  expect_identical(value_from_string(" 7"), 7L)
  expect_identical(value_from_string("1_000"), 1000L)
  expect_identical(value_from_string("0x1F"), 31L)
  expect_identical(value_from_string("1.5"), 1.5)
  expect_identical(value_from_string("1e3"), 1000)
  expect_identical(value_from_string("-0.5e-2"), -0.005)
  expect_identical(value_from_string("True"), TRUE)
  expect_null(value_from_string("None"))
  expect_identical(value_from_string("\"x\""), "x")
  expect_equal(value_from_string("0,0"), structure(list(0L, 0L), py_type = "tuple"))
  expect_equal(value_from_string("1,"), structure(list(1L), py_type = "tuple"))
  expect_equal(value_from_string("()"), structure(list(), py_type = "tuple"))
  expect_equal(value_from_string("[1, \"a\"]"), structure(list(1L, "a"), py_type = "list"))
  for (s in c("INFO", "60%", "{media_dir}/logs", "01", "", "a b", "1,,2", ",")) expect_identical(value_from_string(s), s)
  expect_true(is_expected_datatype("True", "60"))
  expect_false(is_expected_datatype("0.5", "1"))
  expect_false(is_expected_datatype("5", "BLACK"))
  expect_true(is_expected_datatype("1,2", "0,0"))
  expect_false(is_expected_datatype("5", "0,0"))
})

test_that("replace_keys swaps underscores and dots", {
  expect_named(replace_keys(list(logging_keyword = 1, log.width = 2, plain = 3)),
               c("logging.keyword", "log_width", "plain"))
})

test_that("make_config_parser merges the library, user and folder files", {
  paths <- config_file_paths()
  expect_named(paths, c("library_wide", "user_wide", "folder_wide"))
  p <- make_config_parser()
  expect_named(p, c("CLI", "CLI_CTX", "logger", "video_encoder", "video_encoder.options", "media", "jupyter"),
               ignore.order = FALSE)
  expect_length(p$CLI, 46)
  expect_identical(p$jupyter$media_width, "60%")
  f <- tempfile(fileext = ".cfg")
  writeLines(c("[CLI]", "frame_rate = 24", "[extra]", "x = 1"), f)
  q <- make_config_parser(f)
  expect_identical(q$CLI$frame_rate, "24")
  expect_identical(q$CLI$pixel_width, "1920")
  expect_identical(q$extra$x, "1")
})

test_that("cfg write asks for every value and writes the merged config", {
  d <- in_tempdir()
  st <- answer_with(c(rep("", 3), "abc", "2"))
  expect_output(path <- manim_cli(c("cfg", "write")), "Invalid value. Try again")
  expect_identical(path, "manim.cfg")
  # The fourth key is zero_pad, an int: "abc" is refused and "2" kept.
  expect_match(st$prompts[4], "Enter the value for zero_pad \\(defaults to 4\\) :")
  expect_match(st$prompts[5], "Enter the value for zero_pad:")
  expect_true(any(grepl("for logging.keyword $", st$prompts)))
  expect_match(st$prompts[length(st$prompts)], "default config for this User")
  back <- read_cfg_file("manim.cfg")
  expect_identical(back$CLI$zero_pad, "2")
  expect_identical(back$jupyter$media_width, "60%")
  expect_true("media_width = 60%%" %in% readLines("manim.cfg"))
  expect_identical(names(back$logger)[1], "logging_keyword")
  # -l user writes the user wide file without asking where.
  user <- file.path(d, "u", "manim.cfg")
  lib <- config_file_paths()[["library_wide"]]
  local_mocked_bindings(config_file_paths = function() c(library_wide = lib, user_wide = user, folder_wide = "manim.cfg"))
  st <- answer_with(character())
  expect_output(manim_cli(c("cfg", "write", "-l", "user")), "has been created with your required changes")
  expect_true(file.exists(user))
  expect_false(any(grepl("default config for this User", st$prompts)))
  expect_error(manim_cli(c("cfg", "write", "-l", "nope")), "is not one of")
})

test_that("cfg show and cfg export follow upstream", {
  d <- in_tempdir()
  writeLines(c("[CLI]", "frame_rate = 24"), "manim.cfg")
  out <- capture.output(manim_cli(c("cfg", "show")))
  expect_identical(out[3], "CONFIG FILES READ")
  expect_true("manim.cfg" %in% out)
  expect_true("frame_rate : 24" %in% out)
  expect_true("media_width : 60%" %in% out)
  answer_with(character())
  expect_output(path <- manim_cli(c("cfg", "export", "--directory", "out")), "Exported final Config")
  expect_identical(normalizePath(path), normalizePath(file.path(d, "out", "manim.cfg")))
  expect_identical(read_cfg_file(path)$CLI$frame_rate, "24")
  answer_with("n")
  expect_output(manim_cli(c("cfg", "export", "-d", normalizePath(d))), "Aborted")
})

test_that("init project and init scene use the templates", {
  in_tempdir()
  expect_setequal(get_template_names(), c("Axes", "Default", "MovingCamera"))
  answer_with(character())
  expect_output(manim_cli(c("init", "project", "p1", "-d")), "copied main.R")
  main <- readLines(file.path("p1", "main.R"))
  expect_identical(main[1], "library(manimR)")
  expect_match(main[2], "^DefaultTemplate <- R6::R6Class")
  cfgp <- read_cfg_file(file.path("p1", "manim.cfg"))$CLI
  expect_identical(cfgp[c("frame_rate", "pixel_height", "pixel_width", "scene_names")],
                   list(frame_rate = "30", pixel_height = "1080", pixel_width = "1920", scene_names = "Default"))
  st <- answer_with(c("axes", "24", "", "", "720p", ""))
  expect_output(manim_cli(c("init", "project", "p2")), "copied manim.cfg")
  cfgp <- read_cfg_file(file.path("p2", "manim.cfg"))$CLI
  expect_identical(cfgp[c("frame_rate", "background_color", "pixel_height", "pixel_width", "scene_names")],
                   list(frame_rate = "24", background_color = "BLACK", pixel_height = "720", pixel_width = "1280",
                        scene_names = "AxesTemplate"))
  expect_match(readLines(file.path("p2", "main.R"))[2], "^AxesTemplate")
  answer_with(c("", "", "", "", "", "n"))
  expect_error(capture.output(manim_cli(c("init", "project", "p3"))), "Aborted")
  answer_with(character())
  expect_output(manim_cli(c("init", "project", "p1", "-d")), "exists. Please type another name")
  answer_with("MovingCamera")
  capture.output(manim_cli(c("init", "scene", "Zoom", "scenes")))
  sc <- readLines("scenes.R")
  expect_identical(sc[1], "library(manimR)")
  expect_true(any(grepl("^Zoom <- R6::R6Class\\(\"Zoom\", inherit = MovingCameraScene", sc)))
  answer_with(character())
  capture.output(manim_cli(c("init", "scene", "Again", "scenes.R")))
  expect_true(any(grepl("^Again <- ", readLines("scenes.R"))))
  expect_identical(select_resolution(), c(480L, 854L))
})

test_that("the templates are scenes that render", {
  for (t in get_template_names()) {
    if (t == "Axes") skip_if_not(latex_works())
    e <- new.env(parent = asNamespace("manimR"))
    eval(parse(file.path(get_template_path(), paste0(t, ".mtp"))), e)
    gen <- get(paste0(t, "Template"), e)
    tempconfig(list(dry_run = TRUE, media_dir = withr_tempdir()), {
      s <- gen$new()
      expect_no_error(suppressMessages(s$render()))
    })
  }
})

test_that("update_cfg and copy_template_files write upstream's files", {
  d <- withr_tempdir()
  copy_template_files(d, "Default") |> capture.output()
  expect_identical(read_cfg_file(file.path(d, "manim.cfg"))$CLI$pixel_width, "854")
  update_cfg(list(frame_rate = 15L, resolution = c(1440L, 2560L)), file.path(d, "manim.cfg"))
  l <- readLines(file.path(d, "manim.cfg"))
  expect_identical(l[1:3], c("[CLI]", "frame_rate = 15", "pixel_height = 1440"))
  expect_identical(l[length(l)], "")
})

test_that("cache clear resolves the resolution and frame rate", {
  d <- in_tempdir()
  writeLines("A <- 1", "scene.R")
  tempconfig(list(media_dir = file.path(d, "media"), pixel_width = 640, pixel_height = 360, frame_rate = 12), {
    dir <- get_dir("partial_movie_dir", module_name = "scene", scene_name = "A")
  })
  dir.create(dir, recursive = TRUE)
  file.create(file.path(dir, c("a.mp4", "b.mp4")))
  expect_output(manim_cli(c("--hide-splash", "cache", "clear", "scene.R", "A", "--media-dir", file.path(d, "media"),
                            "-r", "640,360", "--fps", "12")),
                "Removed 2 cached segment\\(s\\) for A from")
  expect_false(dir.exists(dir))
})

test_that("the splash line shows unless hidden", {
  expect_output(manim_cli("--version"), "^manimR v[0-9.]+")
  expect_output(manim_cli(c("plugins", "-l")), "^manimR v")
  out <- capture.output(manim_cli(c("--hide-splash", "plugins", "-l")))
  expect_false(any(grepl("^manimR v", out)))
})

test_that("the interaction queue runs records as upstream's Scene.interact", {
  sc <- Scene$new()
  hit <- 0
  sc$queue$put(MethodWithArgs(function(a, b = 0) hit <<- a + b, list(1), list(b = 2)))
  sc$queue$put(SceneInteractContinue("keyboard"))
  sc$queue$put(SceneInteractRerun("gui"))
  sc$process_queue()
  expect_equal(hit, 3)
  expect_true(sc$quit_interaction)
  expect_true(sc$queue$empty())
  sc2 <- Scene$new()
  RerunSceneHandler$new(sc2$queue)$on_modified()
  tempconfig(list(), {
    sc2$queue$put(SceneInteractRerun("keyboard", from_animation_number = 2))
    sc2$process_queue()
    expect_true(sc2$rerun_requested)
    expect_equal(sc2$queue$qsize(), 1)
  })
  expect_output(print(SceneInteractRerun("play", from_animation_number = 1)),
                "SceneInteractRerun\\(sender=play, from_animation_number=1\\)")
  expect_error(SceneQueue$new()$get_nowait(), "empty")
  expect_s3_class(EndSceneEarlyException(), "manim_end_scene")
  Tmp <- R6::R6Class("Tmp", inherit = SquareClass)
  MobjectClass$add_animation_override("FadeIn", function(...) NULL, mobject_class = Tmp)
  expect_error(MobjectClass$add_animation_override("FadeIn", function(...) NULL, mobject_class = Tmp),
               class = "MultiAnimationOverrideException")
})

test_that("a rerun renders the scene class again", {
  runs <- 0
  Rerun <- R6::R6Class("Rerun", inherit = Scene, public = list(construct = function() {
    runs <<- runs + 1
    self$add(Circle())
    if (runs == 1) stop(RerunSceneException())
  }))
  out <- render(Rerun, format = "png", media_dir = withr_tempdir(), save_last_frame = TRUE)
  expect_equal(runs, 2)
  expect_true(file.exists(out))
  b <- Square()$animate$shift(RIGHT)$scale(2)
  st <- attr(b, "state")
  expect_s3_class(st$methods[[1]], "MethodWithArgs")
  expect_identical(attr(st$methods[[2]], "name"), "scale")
  expect_equal(st$methods[[2]]$args, list(2))
})
