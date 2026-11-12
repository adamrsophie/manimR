# Logging and console output

`logger` mirrors upstream's `manim.logger`: `logger$info("...")`,
`logger$debug()`, `logger$warning()`, `logger$error()` and
`logger$critical()` print a message when its level is at least the
`verbosity` setting of
[`manim_config()`](https://adamrsophie.github.io/manimR/reference/manim_config.md)
(`"DEBUG"`, `"INFO"`, `"WARNING"`, `"ERROR"` or `"CRITICAL"`; default
`"INFO"`). Messages go through
[`message()`](https://rdrr.io/r/base/message.html), so
[`suppressMessages()`](https://rdrr.io/r/base/message.html) silences
them. `logger$setLevel()` changes `verbosity`. Format arguments work as
in [`sprintf()`](https://rdrr.io/r/base/sprintf.html).

## Usage

``` r
logger

console

error_console

cli_ctx_settings
```

## Format

Lists of functions; `cli_ctx_settings` is a named list.

## Value

`logger`, `console` and `error_console` are lists of functions that
print messages; `cli_ctx_settings` is a named list of settings.

## Details

`console$print()` writes to standard output and `error_console$print()`
to standard error, like upstream's rich consoles.

`cli_ctx_settings` holds upstream's command line help settings (the
`[CLI_CTX]` section of its configuration file).

## Examples

``` r
logger$info("Rendering %d scenes", 2L)
#> INFO Rendering 2 scenes
console$print("Done")
#> Done 
```
