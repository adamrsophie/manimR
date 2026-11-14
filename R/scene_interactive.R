# Interactive scenes and Scene helpers, ported from manim/scene/scene.py.
# Upstream's interactive mode needs its OpenGL window; manimR shows the live
# frame in a Shiny gadget instead (the RStudio Viewer, or a browser), which
# sends the same key and mouse events to the scene.

Scene$set("public", "key_to_function_map", NULL)
Scene$set("public", "mouse_press_callbacks", NULL)
Scene$set("public", "meshes", NULL)
Scene$set("public", "pressed_keys", NULL)
Scene$set("public", "quit_interaction", FALSE)
Scene$set("public", "interactive_mode", FALSE)
Scene$set("public", "skip_animation_preview", FALSE)
Scene$set("public", "camera_target", ORIGIN)
Scene$set("public", "camera_default_state", NULL)
Scene$set("public", "mouse_point", NULL)
Scene$set("public", "mouse_drag_point", NULL)

# Values of named fields.
Scene$set("public", "get_attrs", function(...) lapply(c(...), function(k) self[[k]]))

Scene$set("public", "get_restructured_mobject_list", function(mobjects, to_remove) {
  get_restructured_mobject_list(mobjects, to_remove)
})

Scene$set("public", "validate_run_time", function(run_time, method, parameter_name = "run_time") {
  name <- if (is.character(method)) method else paste0(class(self)[1], "$", deparse(substitute(method)), "()")
  validate_run_time(run_time, name, parameter_name)
})

# The times at which frames are drawn for an animation of `run_time`
# seconds: one entry (the end) while skipping, unless overridden.
Scene$set("public", "get_time_progression", function(run_time, description = NULL, n_iterations = NULL,
                                                     override_skip_animations = FALSE) {
  if (isTRUE(self$renderer$skip_animations) && !override_skip_animations) return(run_time)
  step <- 1 / self$camera$frame_rate
  n <- ceiling(run_time / step - 1e-9)
  if (n > 0) (seq_len(n) - 1) * step else numeric()
})

Scene$set("public", "update_meshes", function(dt) {
  for (obj in self$meshes) for (mesh in obj$get_family()) mesh$update(dt)
  invisible(self)
})

Scene$set("public", "set_key_function", function(char, func) {
  self$key_to_function_map[[char]] <- func
  invisible(self)
})

# Saves the camera's view the first time, so "r" can restore it.
Scene$set("public", "remember_camera_state", function() {
  if (!is.null(self$camera_default_state)) return(invisible(self))
  cam <- self$camera
  self$camera_default_state <- if (inherits(cam, "ThreeDCamera")) {
    list(phi = cam$get_phi(), theta = cam$get_theta(), gamma = cam$get_gamma(), zoom = cam$get_zoom(),
         center = cam$get_frame_center())
  } else if (inherits(cam, "MovingCamera")) {
    list(frame = cam$frame$copy())
  } else {
    list(center = cam$frame_center, width = cam$frame_width, height = cam$frame_height)
  }
  invisible(self)
})

Scene$set("public", "camera_to_default_state", function() {
  st <- self$camera_default_state
  if (is.null(st)) return(invisible(self))
  cam <- self$camera
  if (inherits(cam, "ThreeDCamera")) {
    cam$set_phi(st$phi)$set_theta(st$theta)$set_gamma(st$gamma)$set_zoom(st$zoom)
    cam$set_frame_center(st$center)
  } else if (inherits(cam, "MovingCamera")) {
    cam$frame$become(st$frame)
  } else {
    cam$frame_center <- st$center
    cam$frame_width <- st$width
    cam$frame_height <- st$height
  }
  invisible(self)
})

# Moves the view by `shift` frame units.
Scene$set("public", "shift_camera", function(shift) {
  cam <- self$camera
  if (inherits(cam, "ThreeDCamera")) {
    cam$set_frame_center(cam$get_frame_center() + shift)
  } else if (inherits(cam, "MovingCamera")) {
    cam$frame$shift(shift)
  } else {
    cam$frame_center <- cam$frame_center + shift
  }
  invisible(self)
})

# Zooms the view by `factor` (above 1 shows more).
Scene$set("public", "scale_camera", function(factor) {
  cam <- self$camera
  if (inherits(cam, "ThreeDCamera")) {
    cam$set_zoom(cam$get_zoom() / factor)
  } else if (inherits(cam, "MovingCamera")) {
    cam$frame$scale(factor, about_point = self$camera_target)
  } else {
    cam$frame_width <- cam$frame_width * factor
    cam$frame_height <- cam$frame_height * factor
  }
  invisible(self)
})

# "r" restores the starting view, "q" ends the interaction, and other keys
# run the function given to set_key_function().
Scene$set("public", "on_key_press", function(symbol, modifiers = 0) {
  char <- if (is.character(symbol)) symbol else tryCatch(intToUtf8(symbol), error = function(e) NA)
  if (is.na(char)) {
    logger$warning("The value of the pressed key is too large.")
    return(invisible(self))
  }
  if (char == "r") {
    self$camera_to_default_state()
    self$camera_target <- ORIGIN
  } else if (char == "q") {
    self$quit_interaction <- TRUE
  } else if (!is.null(self$key_to_function_map[[char]])) {
    self$key_to_function_map[[char]]()
  }
  invisible(self)
})

Scene$set("public", "on_key_release", function(symbol, modifiers = 0) invisible(self))

Scene$set("public", "on_mouse_press", function(point, button, modifiers = 0) {
  for (f in self$mouse_press_callbacks) f()
  invisible(self)
})

# With Shift held (SHIFT_VALUE in pressed_keys), moving the mouse pans.
Scene$set("public", "on_mouse_motion", function(point, d_point) {
  if (is.null(self$mouse_point)) self$mouse_point <- Point()
  self$mouse_point$move_to(point)
  if (SHIFT_VALUE %in% self$pressed_keys) self$shift_camera(-as_point(d_point))
  invisible(self)
})

# Dragging with the left button (1) orbits a 3D camera; with the right
# button (4) it pans.
Scene$set("public", "on_mouse_drag", function(point, d_point, buttons, modifiers = 0) {
  if (is.null(self$mouse_drag_point)) self$mouse_drag_point <- Point()
  self$mouse_drag_point$move_to(point)
  d <- as_point(d_point)
  if (buttons == 4) self$shift_camera(-d)
  self$mouse_drag_orbit_controls(point, d, buttons, modifiers)
  invisible(self)
})

Scene$set("public", "mouse_drag_orbit_controls", function(point, d_point, buttons, modifiers = 0) {
  cam <- self$camera
  if (buttons == 1 && inherits(cam, "ThreeDCamera")) {
    cam$set_theta(cam$get_theta() - d_point[1])
    cam$set_phi(cam$get_phi() + d_point[2])
  }
  invisible(self)
})

Scene$set("public", "on_mouse_scroll", function(point, offset) {
  self$mouse_scroll_orbit_controls(point, offset)
  invisible(self)
})

Scene$set("public", "mouse_scroll_orbit_controls", function(point, offset) {
  self$scale_camera(1 + atan(-2.1 * as_point(offset)[2]))
  invisible(self)
})

# Upstream needs its OpenGL window; here an interactive R session and the
# shiny and miniUI packages.
Scene$set("public", "check_interactive_embed_is_valid", function() {
  if (isTRUE(self$skip_animation_preview)) {
    logger$warning("Disabling interactive embed as 'skip_animation_preview' is enabled")
    return(FALSE)
  }
  if (!is.null(self$renderer$file_writer$con)) {
    logger$warning("Disabling interactive embed while media output is enabled")
    return(FALSE)
  }
  if (!interactive()) {
    logger$warning("Disabling interactive embed as no window was created")
    return(FALSE)
  }
  if (!requireNamespace("shiny", quietly = TRUE) || !requireNamespace("miniUI", quietly = TRUE)) {
    logger$warning("Disabling interactive embed as the shiny and miniUI packages are not installed")
    return(FALSE)
  }
  TRUE
})

#' Interactive scenes
#'
#' Upstream's interactive mode lets you look around a scene and change it
#' while it runs, in its OpenGL window. In manimR, `scene$interactive_embed()`
#' (or `scene$embed()`, or `scene$interact()`) opens the scene in a Shiny
#' window (the RStudio Viewer, or a browser), live:
#'
#' * time based updaters keep running;
#' * dragging orbits a 3D camera (left button) or pans (right button, or
#'   Shift and move); the mouse wheel zooms;
#' * `r` restores the starting view, `q` closes the window, and other keys
#'   run the functions given to `scene$set_key_function(char, func)`;
#' * the code box runs R code with `self` set to the scene, as upstream's
#'   embedded IPython shell does, and redraws.
#'
#' The same key and mouse handlers (`on_key_press()`, `on_mouse_drag()`,
#' `on_mouse_scroll()`, `on_mouse_motion()`, `on_mouse_press()`) can also be
#' called directly. `check_interactive_embed_is_valid()` tells whether a
#' window can be opened (an interactive session with shiny and miniUI
#' installed, and no video being written).
#'
#' @section Arguments:
#' * `scene`: a scene object.
#' * `fps`: redraws per second.
#' @return The scene, invisibly, when the window closes.
#' @name interactive_scene
#' @examplesIf interactive()
#' sc <- ThreeDScene$new()
#' sc$add(Cube())
#' sc$set_key_function("c", function() sc$add(Sphere(radius = 0.5)))
#' sc$interactive_embed()
NULL

Scene$set("public", "interactive_embed", function(fps = 10) {
  if (!self$check_interactive_embed_is_valid()) return(invisible(self))
  self$interactive_mode <- TRUE
  on.exit(self$interactive_mode <- FALSE, add = TRUE)
  self$rerun_requested <- FALSE
  run_interactive_gadget(self, fps)
  if (isTRUE(self$rerun_requested)) {
    self$rerun_requested <- FALSE
    stop(RerunSceneException())
  }
  invisible(self)
})

Scene$set("public", "embed", function(fps = 10) self$interactive_embed(fps))

Scene$set("public", "interact", function(shell = NULL, keyboard_thread = NULL, fps = 10) {
  self$interactive_embed(fps)
})

interactive_js <- "
(function() {
  var img = null, last = null, down = 0;
  function pos(e) {
    var r = img.getBoundingClientRect();
    return [(e.clientX - r.left) / r.width, (e.clientY - r.top) / r.height];
  }
  function send(name, value) { Shiny.setInputValue(name, value, {priority: 'event'}); }
  document.addEventListener('DOMContentLoaded', function() {
    var wait = setInterval(function() {
      img = document.getElementById('frame');
      if (!img) return;
      clearInterval(wait);
      img.addEventListener('contextmenu', function(e) { e.preventDefault(); });
      img.addEventListener('mousedown', function(e) {
        down = e.button === 2 ? 4 : 1; last = pos(e);
        send('mouse_press', {p: last, button: down});
      });
      window.addEventListener('mouseup', function() { down = 0; });
      img.addEventListener('mousemove', function(e) {
        var p = pos(e), d = last ? [p[0] - last[0], p[1] - last[1]] : [0, 0]; last = p;
        send(down ? 'mouse_drag' : 'mouse_motion', {p: p, d: d, button: down, shift: e.shiftKey});
      });
      img.addEventListener('wheel', function(e) {
        e.preventDefault(); send('mouse_scroll', {p: pos(e), dy: e.deltaY > 0 ? -1 : 1});
      }, {passive: false});
    }, 100);
    document.addEventListener('keydown', function(e) {
      if (e.target.tagName === 'TEXTAREA' || e.target.tagName === 'INPUT') return;
      send('key_press', {key: e.key, shift: e.shiftKey});
    });
  });
})();
"

run_interactive_gadget <- function(scene, fps = 10) {
  viewer <- if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    shiny::paneViewer()
  } else {
    shiny::browserViewer()
  }
  on.exit(scene$renderer$close_device(), add = TRUE)
  shiny::runGadget(interactive_app(scene, fps), viewer = viewer, stopOnCancel = TRUE)
}

# The Shiny app of an interactive scene.
interactive_app <- function(scene, fps = 10) {
  scene$remember_camera_state()
  scene$quit_interaction <- FALSE
  renderer <- scene$renderer
  img_dir <- file.path(tempdir(), "manimR-interactive")
  dir.create(img_dir, showWarnings = FALSE, recursive = TRUE)
  width <- scene$camera$pixel_width
  height <- scene$camera$pixel_height
  # Converts a position on the image (0 to 1) to frame coordinates.
  to_frame <- function(p) {
    cam <- scene$camera
    fc <- cam$get_frame_center()
    c(fc[1] + (p[[1]] - 0.5) * cam$get_frame_width(), fc[2] + (0.5 - p[[2]]) * cam$get_frame_height(), 0)
  }
  to_delta <- function(d, scale) c(d[[1]] * scale[1], -d[[2]] * scale[2], 0)
  ui <- miniUI::miniPage(
    shiny::tags$head(shiny::tags$script(shiny::HTML(interactive_js))),
    miniUI::gadgetTitleBar(paste("Interactive", scene$scene_name()),
                           right = miniUI::miniTitleBarButton("done", "Close", primary = TRUE)),
    miniUI::miniContentPanel(
      shiny::imageOutput("frame", width = "100%", height = "auto"),
      shiny::textAreaInput("code", NULL, placeholder = "R code; self is the scene", width = "100%", rows = 3),
      shiny::actionButton("run", "Run code"),
      shiny::verbatimTextOutput("out")
    )
  )
  server <- function(input, output, session) {
    tick <- shiny::reactiveVal(0)
    last_time <- Sys.time()
    handler <- RerunSceneHandler$new(scene$queue)
    watched <- cfg("input_file")
    if (!is.null(watched) && !nzchar(watched)) watched <- NULL
    watched_time <- if (!is.null(watched) && file.exists(watched)) file.mtime(watched) else Sys.time()
    # isolate(): the timer observer must not depend on the counter it bumps.
    redraw <- function() shiny::isolate(tick(tick() + 1))
    shiny::observe({
      shiny::invalidateLater(round(1000 / fps))
      now <- Sys.time()
      dt <- as.numeric(difftime(now, last_time, units = "secs"))
      last_time <<- now
      # A changed input file queues a rerun, as upstream's file watcher.
      if (!is.null(watched) && file.exists(watched) && file.mtime(watched) > watched_time) {
        watched_time <<- file.mtime(watched)
        handler$on_modified()
      }
      scene$process_queue()
      scene$update_mobjects(dt)
      scene$update_meshes(dt)
      if (isTRUE(scene$quit_interaction)) shiny::stopApp(invisible(scene))
      redraw()
    })
    output$frame <- shiny::renderImage({
      tick()
      renderer$static_image <- NULL
      renderer$update_frame(scene)
      path <- file.path(img_dir, "frame.png")
      png::writePNG(native_raster_to_array(renderer$get_frame()) / 255, path)
      list(src = path, contentType = "image/png", width = "100%", alt = scene$scene_name())
    }, deleteFile = FALSE)
    angle_scale <- c(2 * pi, pi)
    frame_scale <- function() c(scene$camera$get_frame_width(), scene$camera$get_frame_height())
    shiny::observeEvent(input$mouse_press, {
      scene$on_mouse_press(to_frame(input$mouse_press$p), input$mouse_press$button)
    })
    shiny::observeEvent(input$mouse_motion, {
      ev <- input$mouse_motion
      scene$pressed_keys <- if (isTRUE(ev$shift)) SHIFT_VALUE
      scene$on_mouse_motion(to_frame(ev$p), to_delta(ev$d, frame_scale()))
    })
    shiny::observeEvent(input$mouse_drag, {
      ev <- input$mouse_drag
      scale <- if (ev$button == 1 && inherits(scene$camera, "ThreeDCamera")) angle_scale else frame_scale()
      scene$on_mouse_drag(to_frame(ev$p), to_delta(ev$d, scale), ev$button)
    })
    shiny::observeEvent(input$mouse_scroll, {
      scene$on_mouse_scroll(to_frame(input$mouse_scroll$p), c(0, 0.1 * input$mouse_scroll$dy, 0))
    })
    shiny::observeEvent(input$key_press, {
      scene$on_key_press(input$key_press$key)
      if (isTRUE(scene$quit_interaction)) shiny::stopApp(invisible(scene))
    })
    # The code box is the R counterpart of upstream's embedded IPython
    # shell: it runs code the user types into their own local session, so
    # evaluating it is the point.
    shiny::observeEvent(input$run, {
      env <- new.env(parent = globalenv())
      env$self <- scene
      out <- tryCatch(utils::capture.output(print(eval(parse(text = input$code), envir = env))),
                      error = function(e) paste("Error:", conditionMessage(e)))
      output$out <- shiny::renderText(paste(out, collapse = "\n"))
    })
    shiny::observeEvent(input$done, shiny::stopApp(invisible(scene)))
  }
  shiny::shinyApp(ui, server)
}
