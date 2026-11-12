# Show scenes in Shiny apps

`manimOutput()` and `renderManim()` are a Shiny output pair, like
`plotOutput()` and `renderPlot()`: the expression of `renderManim()`
returns a
[Scene](https://adamrsophie.github.io/manimR/reference/Scene.md) class,
a construct function (as
[`render()`](https://adamrsophie.github.io/manimR/reference/render.md)
takes) or the path of a rendered file, and the output shows the video
(or image). The expression is reactive, so a scene built from inputs
renders again when they change. Renders go to a temporary media
directory and reuse its partial movie cache; each output of each session
is shown its own copy of the file, served from a folder that is removed
when the session ends.

## Usage

``` r
manimOutput(outputId, width = "100%")

renderManim(expr, env = parent.frame(), quoted = FALSE, ...)
```

## Arguments

- outputId:

  Output name.

- width:

  CSS width of the player.

- expr:

  An expression returning a scene or a file path.

- env, quoted:

  The environment of `expr`, and whether it is quoted.

- ...:

  [`render()`](https://adamrsophie.github.io/manimR/reference/render.md)
  arguments for the scene, such as `quality = "l"` (the default) or
  `format = "gif"`.

## Value

`manimOutput()` returns UI; `renderManim()` a render function.

## Examples

``` r
if (FALSE) { # \dontrun{
ui <- shiny::fluidPage(
  shiny::sliderInput("n", "Sides", 3, 10, 5),
  manimOutput("scene")
)
server <- function(input, output) {
  output$scene <- renderManim({
    n <- input$n
    function(self) self$play(Create(RegularPolygon(n = n)))
  })
}
shiny::shinyApp(ui, server)
} # }
```
