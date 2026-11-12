# Scene templates

The templates of `manim init` (upstream's `manim/templates`), written in
R: `Default`, `Axes` and `MovingCamera`.

## Usage

``` r
get_template_path()

get_template_names()

add_import_statement(file)

copy_template_files(project_dir, template_name = "Default")
```

## Arguments

- file:

  Path of an R file.

- project_dir:

  Folder to copy into.

- template_name:

  One of `get_template_names()`.

## Value

`get_template_path()` a path; `get_template_names()` a character vector;
the others `NULL`, invisibly.

## Details

- `get_template_path()` is the folder of the templates.

- `get_template_names()` lists them.

- `copy_template_files(project_dir, template_name)` copies the template
  `manim.cfg` and the scene, as `main.R`, into `project_dir`. Unlike
  upstream, `project_dir` has no default, so nothing is written to the
  working directory unless asked.

- `add_import_statement(file)` puts
  [`library(manimR)`](https://adamrsophie.github.io/manimR/) on the
  first line of `file`.

## Examples

``` r
get_template_names()
#> [1] "Axes"         "Default"      "MovingCamera"
d <- tempfile()
dir.create(d)
copy_template_files(d, "Axes")
#> 
#>  copied manim.cfg
#> 
#> 
#>  copied main.R
#> 
readLines(file.path(d, "main.R"))
#>  [1] "library(manimR)"                                               
#>  [2] "AxesTemplate <- R6::R6Class(\"AxesTemplate\", inherit = Scene,"
#>  [3] "  public = list("                                              
#>  [4] "    construct = function() {"                                  
#>  [5] "      graph <- Axes("                                          
#>  [6] "        x_range = c(-1, 10, 1),"                               
#>  [7] "        y_range = c(-1, 10, 1),"                               
#>  [8] "        x_length = 9,"                                         
#>  [9] "        y_length = 6,"                                         
#> [10] "        axis_config = list(include_tip = FALSE)"               
#> [11] "      )"                                                       
#> [12] "      labels <- graph$get_axis_labels()"                       
#> [13] "      self$add(graph, labels)"                                 
#> [14] "    }"                                                         
#> [15] "  )"                                                           
#> [16] ")"                                                             
```
