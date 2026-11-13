# A GLSL interpreter that runs the vertex and fragment shaders of a Mesh on
# the CPU, for the software OpenGL renderer. A shader runs for many
# vertices or fragments at once: every value is a matrix with one row per
# vertex or fragment and one column per component (a float has one column,
# a mat4 sixteen in column-major order, marked by a "glsl_dim" attribute),
# and branches and loops run under a row mask.
#
# Supported: the scalar, vector and square matrix types; in, out, uniform
# and const globals; user functions (in, out and inout parameters);
# if/else, for and while loops with break and continue; return; discard;
# the arithmetic, comparison, logical and ternary operators with ++ and --;
# swizzles and indexing; constructors, arrays such as vec3[9](...) and the
# common built-in functions; structs, whose value is one matrix of their
# fields side by side (a "glsl_struct" attribute names the struct).
# Geometry shaders run with one row per input primitive: EmitVertex() and
# EndPrimitive() record the outputs of the rows under the mask. A sampler2D
# uniform holds a texture unit, which texture(), textureLod(), texelFetch()
# and textureSize() read as the software context's texture bound there; other
# sampler types, and units with no texture, read (0, 0, 0, 1) as OpenGL's
# default texture. Arrays inside structs raise an error.

glsl_tokenize <- function(code) {
  code <- gsub("/\\*.*?\\*/", " ", code, perl = TRUE)
  code <- gsub("//[^\n]*", "", code)
  code <- gsub("(^|\n)[ \t]*#[^\n]*", "\\1", code)
  pattern <- paste0("(?:\\d+\\.\\d*|\\.\\d+|\\d+)(?:[eE][+-]?\\d+)?[fFuU]?",
                    "|[A-Za-z_][A-Za-z_0-9]*",
                    "|\\+\\+|--|\\+=|-=|\\*=|/=|==|!=|<=|>=|&&|\\|\\||\\^\\^|[-+*/%=<>!?:;,.(){}\\[\\]]")
  regmatches(code, gregexpr(pattern, code, perl = TRUE))[[1]]
}

GLSL_TYPES <- c(float = 1, int = 1, uint = 1, bool = 1, double = 1,
                vec2 = 2, vec3 = 3, vec4 = 4, ivec2 = 2, ivec3 = 3, ivec4 = 4, uvec2 = 2, uvec3 = 3, uvec4 = 4,
                bvec2 = 2, bvec3 = 3, bvec4 = 4, dvec2 = 2, dvec3 = 3, dvec4 = 4,
                mat2 = 4, mat3 = 9, mat4 = 16, mat2x2 = 4, mat3x3 = 9, mat4x4 = 16, sampler2D = 1)
# Sampler types besides sampler2D. Upstream's renderer binds only 2D
# textures, so these read OpenGL's default (incomplete) texture of their
# target, which gives (0, 0, 0, 1).
GLSL_OTHER_SAMPLERS <- c(outer(c("", "i", "u"), c("sampler1D", "sampler3D", "samplerCube", "sampler1DArray",
                                                   "sampler2DArray", "sampler2DRect", "samplerBuffer",
                                                   "sampler2DMS", "sampler2DMSArray", "samplerCubeArray"),
                               paste0),
                         "isampler2D", "usampler2D", "sampler1DShadow", "sampler2DShadow", "samplerCubeShadow",
                         "sampler2DRectShadow", "sampler1DArrayShadow", "sampler2DArrayShadow",
                         "samplerCubeArrayShadow")
GLSL_TYPES[GLSL_OTHER_SAMPLERS] <- 1
GLSL_QUALIFIERS <- c("in", "out", "inout", "uniform", "const", "flat", "smooth", "noperspective", "centroid",
                     "highp", "mediump", "lowp", "attribute", "varying", "invariant")

glsl_type_dim <- function(type) {
  n <- switch(type, mat2 = , mat2x2 = 2, mat3 = , mat3x3 = 3, mat4 = , mat4x4 = 4, NA)
  if (is.na(n)) NULL else c(n, n)
}
glsl_is_int_type <- function(type) type %in% c("int", "uint", "ivec2", "ivec3", "ivec4", "uvec2", "uvec3", "uvec4")

glsl_error <- function(...) stop("GLSL code: ", ..., call. = FALSE)

# Parses tokens into a program: list(globals, functions). Each statement and
# expression is a list.
glsl_parse <- function(tokens) {
  pos <- 1
  peek <- function(k = 0) if (pos + k <= length(tokens)) tokens[pos + k] else ""
  take <- function(expected = NULL) {
    t <- peek()
    if (!is.null(expected) && !identical(t, expected)) {
      glsl_error(sprintf("expected '%s' but found '%s'.", expected, if (nzchar(t)) t else "the end"))
    }
    pos <<- pos + 1
    t
  }
  structs <- list()
  layouts <- character()
  is_type <- function(t) t %in% c(names(GLSL_TYPES), names(structs), "void")
  # struct Name { type field, field; ... }; its fields' column offsets.
  struct_def <- function() {
    take("struct")
    name <- take()
    take("{")
    fields <- list()
    offset <- 0
    while (peek() != "}") {
      qualifiers()
      ftype <- take()
      size <- if (!is.null(structs[[ftype]])) structs[[ftype]]$size else GLSL_TYPES[ftype]
      if (is.na(size)) glsl_error("the type '", ftype, "' is not supported.")
      repeat {
        fname <- take()
        if (peek() == "[") glsl_error("arrays inside structs are not supported by manimR's GLSL interpreter.")
        fields[[fname]] <- list(type = ftype, offset = offset, size = unname(size))
        offset <- offset + size
        if (peek() == ",") take(",") else break
      }
      take(";")
    }
    take("}")
    if (peek() != ";") glsl_error("declare the variables of struct ", name, " in their own statement.")
    take(";")
    structs[[name]] <<- list(fields = fields, size = unname(offset))
  }
  is_number <- function(t) grepl("^(\\d|\\.\\d)", t)
  binary <- list(c("||"), c("^^"), c("&&"), c("==", "!="), c("<", ">", "<=", ">="), c("+", "-"), c("*", "/", "%"))
  expr <- function() assignment()
  assignment <- function() {
    left <- ternary()
    if (peek() %in% c("=", "+=", "-=", "*=", "/=")) {
      op <- take()
      return(list(op = "assign", how = op, args = list(left, assignment())))
    }
    left
  }
  ternary <- function() {
    cond <- binop(1)
    if (peek() == "?") {
      take("?")
      a <- expr()
      take(":")
      b <- ternary()
      return(list(op = "?:", args = list(cond, a, b)))
    }
    cond
  }
  binop <- function(level) {
    if (level > length(binary)) return(unary())
    left <- binop(level + 1)
    while (peek() %in% binary[[level]]) {
      op <- take()
      left <- list(op = op, args = list(left, binop(level + 1)))
    }
    left
  }
  unary <- function() {
    if (peek() %in% c("-", "+", "!")) {
      op <- take()
      return(list(op = paste0("u", op), args = list(unary())))
    }
    if (peek() %in% c("++", "--")) {
      op <- take()
      return(list(op = "assign", how = if (op == "++") "+=" else "-=", args = list(unary(), list(op = "num", value = 1))))
    }
    postfix(primary())
  }
  postfix <- function(e) {
    force(e)
    repeat {
      if (peek() == ".") {
        take(".")
        e <- list(op = "swizzle", args = list(e), name = take())
      } else if (peek() == "[") {
        take("[")
        index <- expr()
        take("]")
        e <- list(op = "index", args = list(e, index))
      } else if (peek() %in% c("++", "--")) {
        op <- take()
        e <- list(op = "postinc", how = if (op == "++") "+=" else "-=", args = list(e))
      } else {
        return(e)
      }
    }
  }
  call_args <- function() {
    take("(")
    args <- list()
    if (peek() == "void") take()
    if (peek() != ")") {
      repeat {
        args[[length(args) + 1]] <- expr()
        if (peek() == ",") take(",") else break
      }
    }
    take(")")
    args
  }
  primary <- function() {
    t <- peek()
    if (t == "(") {
      take("(")
      e <- expr()
      take(")")
      return(e)
    }
    if (is_number(t)) {
      take()
      return(list(op = "num", value = as.numeric(sub("[fFuU]$", "", t))))
    }
    if (t %in% c("true", "false")) {
      take()
      return(list(op = "num", value = as.numeric(t == "true")))
    }
    if (grepl("^[A-Za-z_]", t)) {
      take()
      if (peek() == "[" && is_type(t)) {
        take("[")
        if (peek() != "]") expr()
        take("]")
        return(list(op = "array", args = call_args()))
      }
      if (peek() == "(") return(list(op = "call", name = t, args = call_args()))
      return(list(op = "var", name = t))
    }
    glsl_error(sprintf("unexpected '%s'.", if (nzchar(t)) t else "end"))
  }
  qualifiers <- function() {
    quals <- character()
    repeat {
      if (peek() == "layout") {
        take("layout")
        take("(")
        depth <- 1
        while (depth > 0) {
          t <- take()
          if (t == "(") depth <- depth + 1
          if (t == ")") depth <- depth - 1
          if (depth == 1 && grepl("^[a-z_]+$", t)) layouts <<- c(layouts, t)
        }
      } else if (peek() %in% GLSL_QUALIFIERS) {
        quals <- c(quals, take())
      } else {
        return(quals)
      }
    }
  }
  # One or more declarations after the type: name [array] [= value], ...
  declarations <- function(type, quals) {
    out <- list()
    repeat {
      name <- take()
      size <- NULL
      if (peek() == "[") {
        take("[")
        size <- if (peek() != "]") expr() else NULL
        take("]")
      }
      value <- NULL
      if (peek() == "=") {
        take("=")
        value <- expr()
      }
      out[[length(out) + 1]] <- list(kind = "decl", type = type, quals = quals, name = name, size = size, value = value)
      if (peek() == ",") take(",") else break
    }
    take(";")
    out
  }
  block <- function() {
    if (peek() == "{") {
      take("{")
      out <- list()
      while (peek() != "}") out <- c(out, statement())
      take("}")
      return(out)
    }
    statement()
  }
  # A statement, as a list of statements (declarations can make several).
  statement <- function() {
    t <- peek()
    if (t == ";") {
      take(";")
      return(list())
    }
    if (t == "{") return(list(list(kind = "block", body = block())))
    if (t == "if") {
      take("if")
      take("(")
      cond <- expr()
      take(")")
      yes <- block()
      no <- list()
      if (peek() == "else") {
        take("else")
        no <- block()
      }
      return(list(list(kind = "if", cond = cond, yes = yes, no = no)))
    }
    if (t == "for") {
      take("for")
      take("(")
      init <- if (peek() == ";") {
        take(";")
        list()
      } else {
        statement()
      }
      cond <- if (peek() == ";") list(op = "num", value = 1) else expr()
      take(";")
      step <- if (peek() == ")") NULL else expr()
      take(")")
      return(list(list(kind = "for", init = init, cond = cond, step = step, body = block())))
    }
    if (t == "while") {
      take("while")
      take("(")
      cond <- expr()
      take(")")
      return(list(list(kind = "for", init = list(), cond = cond, step = NULL, body = block())))
    }
    if (t == "do") {
      take("do")
      body <- block()
      take("while")
      take("(")
      cond <- expr()
      take(")")
      take(";")
      return(list(list(kind = "for", init = list(), cond = cond, step = NULL, body = body, first = TRUE)))
    }
    if (t == "return") {
      take("return")
      value <- if (peek() == ";") NULL else expr()
      take(";")
      return(list(list(kind = "return", value = value)))
    }
    if (t %in% c("break", "continue", "discard")) {
      take()
      take(";")
      return(list(list(kind = t)))
    }
    if (t == "struct") {
      struct_def()
      return(list())
    }
    quals <- qualifiers()
    if (is_type(peek()) && grepl("^[A-Za-z_]", peek(1))) {
      type <- take()
      return(declarations(type, quals))
    }
    if (length(quals)) glsl_error(sprintf("unexpected '%s' after a qualifier.", peek()))
    e <- expr()
    take(";")
    list(list(kind = "expr", value = e))
  }
  globals <- list()
  functions <- list()
  while (pos <= length(tokens)) {
    if (peek() == "precision") {
      while (take() != ";") NULL
      next
    }
    if (peek() == "struct") {
      struct_def()
      next
    }
    quals <- qualifiers()
    if (!length(quals) && is_type(peek()) && grepl("^[A-Za-z_]", peek(1)) && peek(2) == "(") {
      type <- take()
      name <- take()
      take("(")
      params <- list()
      if (peek() == "void") take()
      while (peek() != ")") {
        pq <- qualifiers()
        ptype <- take()
        pname <- if (peek() %in% c(",", ")")) "" else take()
        if (peek() == "[") {
          take("[")
          while (take() != "]") NULL
        }
        params[[length(params) + 1]] <- list(type = ptype, name = pname, out = any(pq %in% c("out", "inout")),
                                             inout = "inout" %in% pq)
        if (peek() == ",") take(",")
      }
      take(")")
      if (peek() == ";") {
        take(";")
        next
      }
      functions[[name]] <- c(functions[[name]], list(list(type = type, params = params, body = block())))
      next
    }
    if (length(quals) && peek() == ";") {
      take(";")
      next
    }
    if (!is_type(peek())) glsl_error(sprintf("unexpected '%s'.", peek()))
    type <- take()
    globals <- c(globals, declarations(type, quals))
  }
  list(globals = globals, functions = functions, structs = structs, layouts = layouts)
}

# The number of columns of a type's value, and a value marked as that type.
glsl_size <- function(type, st) {
  s <- st$program$structs[[type]]
  if (!is.null(s)) return(s$size)
  k <- GLSL_TYPES[type]
  if (is.na(k)) glsl_error("the type '", type, "' is not supported.")
  unname(k)
}
glsl_typed <- function(x, type, st) {
  if (is.list(x)) return(x)
  attr(x, "glsl_dim") <- glsl_type_dim(type)
  attr(x, "glsl_struct") <- if (!is.null(st$program$structs[[type]])) type
  attr(x, "glsl_sampler") <- if (grepl("sampler", type, fixed = TRUE)) type
  x
}
# A field of a struct value.
glsl_field <- function(x, sname, name, st) {
  f <- st$program$structs[[sname]]$fields[[name]]
  if (is.null(f)) glsl_error("struct ", sname, " has no field '", name, "'.")
  glsl_typed(x[, f$offset + seq_len(f$size), drop = FALSE], f$type, st)
}

# Rows of a value for n rows: a single row is repeated.
glsl_rows <- function(x, n) {
  if (is.list(x)) return(lapply(x, glsl_rows, n))
  if (nrow(x) == 1 && n != 1) {
    d <- attr(x, "glsl_dim")
    sn <- attr(x, "glsl_struct")
    x <- x[rep(1, n), , drop = FALSE]
    attr(x, "glsl_dim") <- d
    attr(x, "glsl_struct") <- sn
  }
  x
}
glsl_with_dim <- function(x, d) {
  attr(x, "glsl_dim") <- d
  x
}

glsl_swizzle_index <- function(name) {
  for (set in c("xyzw", "rgba", "stpq")) {
    k <- match(strsplit(name, "")[[1]], strsplit(set, "")[[1]])
    if (!anyNA(k)) return(k)
  }
  glsl_error("unknown swizzle '.", name, "'.")
}

# Applies a function of the components elementwise, broadcasting scalars.
glsl_map <- function(f, ...) {
  args <- list(...)
  n <- max(vapply(args, nrow, 1))
  k <- max(vapply(args, ncol, 1))
  d <- NULL
  for (a in args) if (!is.null(attr(a, "glsl_dim")) && ncol(a) == k) d <- attr(a, "glsl_dim")
  args <- lapply(args, function(a) {
    a <- glsl_rows(a, n)
    if (ncol(a) == 1 && k > 1) a[, rep(1, k), drop = FALSE] else a
  })
  glsl_with_dim(matrix(do.call(f, lapply(args, as.vector)), n, k), d)
}

# The product: matrix times vector, vector times matrix, matrix times
# matrix, and componentwise otherwise.
glsl_mul <- function(a, b) {
  da <- attr(a, "glsl_dim")
  db <- attr(b, "glsl_dim")
  n <- max(nrow(a), nrow(b))
  col <- function(m, d, j) glsl_rows(m, n)[, (j - 1) * d[2] + seq_len(d[2]), drop = FALSE]
  if (!is.null(da) && !is.null(db)) {
    out <- do.call(cbind, lapply(seq_len(db[1]), function(j) glsl_mul(a, col(b, db, j))))
    return(glsl_with_dim(out, c(db[1], da[2])))
  }
  if (!is.null(da) && is.null(db) && ncol(b) == da[1] && ncol(b) > 1) {
    b <- glsl_rows(b, n)
    out <- 0
    for (j in seq_len(da[1])) out <- out + col(a, da, j) * b[, j]
    return(out)
  }
  if (is.null(da) && !is.null(db) && ncol(a) == db[2] && ncol(a) > 1) {
    a <- glsl_rows(a, n)
    return(do.call(cbind, lapply(seq_len(db[1]), function(j) rowSums(a * col(b, db, j)))))
  }
  glsl_map(`*`, a, b)
}

glsl_float_to_color <- function(value, min_val, max_val, colormap) {
  alpha <- pmin(pmax((value[, 1] - min_val[, 1]) / (max_val[, 1] - min_val[, 1]), 0), 1)
  disc <- pmin(as.integer(alpha * 8), 7L)
  n <- length(alpha)
  lo <- t(vapply(seq_len(n), function(i) colormap[[disc[i] + 1]][min(i, nrow(colormap[[disc[i] + 1]])), ], numeric(3)))
  hi <- t(vapply(seq_len(n), function(i) colormap[[disc[i] + 2]][min(i, nrow(colormap[[disc[i] + 2]])), ], numeric(3)))
  f <- 8 * alpha - disc
  lo + (hi - lo) * f
}

# A constructor: float, int, bool, vectors and square matrices.
glsl_construct <- function(type, args) {
  k <- GLSL_TYPES[[type]]
  d <- glsl_type_dim(type)
  n <- max(vapply(args, nrow, 1))
  args <- lapply(args, glsl_rows, n)
  conv <- function(x) {
    if (glsl_is_int_type(type)) return(trunc(x))
    if (startsWith(type, "b") || type == "bool") return((x != 0) + 0)
    x
  }
  if (!is.null(d)) {
    if (length(args) == 1 && ncol(args[[1]]) == 1) {
      out <- matrix(0, n, k)
      for (j in seq_len(d[1])) out[, (j - 1) * d[1] + j] <- args[[1]][, 1]
      return(glsl_with_dim(out, d))
    }
    if (length(args) == 1 && !is.null(attr(args[[1]], "glsl_dim"))) {
      src <- args[[1]]
      sd <- attr(src, "glsl_dim")
      out <- glsl_construct(type, list(matrix(1, n, 1)))
      for (j in seq_len(min(d[1], sd[1]))) {
        for (i in seq_len(min(d[2], sd[2]))) out[, (j - 1) * d[2] + i] <- src[, (j - 1) * sd[2] + i]
      }
      return(out)
    }
    out <- do.call(cbind, args)
    if (ncol(out) < k) glsl_error("too few components for ", type, ".")
    return(glsl_with_dim(out[, seq_len(k), drop = FALSE], d))
  }
  if (length(args) == 1 && ncol(args[[1]]) == 1) return(conv(args[[1]][, rep(1, k), drop = FALSE]))
  out <- do.call(cbind, lapply(args, function(a) glsl_with_dim(a, NULL)))
  if (ncol(out) < k) glsl_error("too few components for ", type, ".")
  conv(out[, seq_len(k), drop = FALSE])
}

glsl_inverse <- function(m) {
  d <- attr(m, "glsl_dim")
  out <- t(apply(m, 1, function(r) as.vector(solve(matrix(r, d[2], d[1])))))
  glsl_with_dim(out, d)
}

glsl_builtin <- function(name, args) {
  unary <- list(sin = sin, cos = cos, tan = tan, asin = asin, acos = acos, exp = exp, log = log,
                sinh = sinh, cosh = cosh, tanh = tanh, asinh = asinh, acosh = acosh, atanh = atanh,
                exp2 = function(x) 2^x, log2 = log2, sqrt = sqrt, inversesqrt = function(x) 1 / sqrt(x), abs = abs,
                sign = sign, floor = floor, ceil = ceiling, trunc = trunc, fract = function(x) x - floor(x),
                round = function(x) floor(x + 0.5), roundEven = round,
                radians = function(x) x * pi / 180, degrees = function(x) x * 180 / pi,
                not = function(x) (x == 0) + 0)
  if (name %in% names(unary) && length(args) == 1) return(glsl_map(unary[[name]], args[[1]]))
  n <- max(vapply(args, function(a) if (is.list(a)) 1L else nrow(a), 1L))
  norm <- function(x) sqrt(rowSums(x * x))
  rows <- function(i) glsl_with_dim(glsl_rows(args[[i]], n), NULL)
  cmp <- function(f) glsl_map(function(a, b) f(a, b) + 0, args[[1]], args[[2]])
  switch(name,
    atan = if (length(args) == 2) glsl_map(atan2, args[[1]], args[[2]]) else glsl_map(atan, args[[1]]),
    pow = glsl_map(function(a, b) a^b, args[[1]], args[[2]]),
    mod = glsl_map(function(a, b) a - b * floor(a / b), args[[1]], args[[2]]),
    min = glsl_map(pmin, args[[1]], args[[2]]),
    max = glsl_map(pmax, args[[1]], args[[2]]),
    clamp = glsl_map(function(x, a, b) pmin(pmax(x, a), b), args[[1]], args[[2]], args[[3]]),
    mix = glsl_map(function(a, b, t) a * (1 - t) + b * t, args[[1]], args[[2]], args[[3]]),
    step = glsl_map(function(e, x) as.numeric(x >= e), args[[1]], args[[2]]),
    smoothstep = glsl_map(function(e0, e1, x) {
      t <- pmin(pmax((x - e0) / (e1 - e0), 0), 1)
      t * t * (3 - 2 * t)
    }, args[[1]], args[[2]], args[[3]]),
    length = matrix(norm(rows(1)), ncol = 1),
    distance = matrix(norm(rows(1) - rows(2)), ncol = 1),
    dot = matrix(rowSums(rows(1) * rows(2)), ncol = 1),
    cross = {
      a <- rows(1)
      b <- rows(2)
      cbind(a[, 2] * b[, 3] - a[, 3] * b[, 2], a[, 3] * b[, 1] - a[, 1] * b[, 3], a[, 1] * b[, 2] - a[, 2] * b[, 1])
    },
    normalize = rows(1) / norm(rows(1)),
    reflect = {
      i <- rows(1)
      nn <- rows(2)
      i - 2 * rowSums(nn * i) * nn
    },
    refract = {
      i <- rows(1)
      nn <- rows(2)
      eta <- glsl_rows(args[[3]], n)[, 1]
      d <- rowSums(nn * i)
      k <- 1 - eta^2 * (1 - d^2)
      out <- eta * i - (eta * d + sqrt(pmax(k, 0))) * nn
      out[k < 0, ] <- 0
      out
    },
    faceforward = {
      s <- ifelse(rowSums(rows(3) * rows(2)) < 0, 1, -1)
      rows(1) * s
    },
    lessThan = cmp(`<`), lessThanEqual = cmp(`<=`), greaterThan = cmp(`>`), greaterThanEqual = cmp(`>=`),
    equal = cmp(`==`), notEqual = cmp(`!=`),
    any = matrix((rowSums(rows(1) != 0) > 0) + 0, ncol = 1),
    all = matrix((rowSums(rows(1) == 0) == 0) + 0, ncol = 1),
    matrixCompMult = glsl_map(`*`, args[[1]], args[[2]]),
    transpose = {
      d <- attr(args[[1]], "glsl_dim")
      idx <- as.vector(t(matrix(seq_len(d[1] * d[2]), d[2], d[1])))
      glsl_with_dim(args[[1]][, idx, drop = FALSE], rev(d))
    },
    inverse = glsl_inverse(args[[1]]),
    determinant = {
      d <- attr(args[[1]], "glsl_dim")
      matrix(apply(args[[1]], 1, function(r) det(matrix(r, d[2], d[1]))), ncol = 1)
    },
    float_to_color = glsl_float_to_color(args[[1]], args[[2]], args[[3]], args[[4]]),
    glsl_error("the function '", name, "' is not supported by manimR's GLSL interpreter.")
  )
}

# The state of one shader run: the program, the global variables and the
# row flags of returned, broken, continued and discarded rows.
glsl_new_state <- function(program, n) {
  st <- new.env(parent = emptyenv())
  st$program <- program
  st$n <- n
  st$globals <- new.env(parent = emptyenv())
  st$discarded <- rep(FALSE, n)
  st
}

glsl_lookup_env <- function(name, env) {
  while (!identical(env, emptyenv())) {
    if (exists(name, envir = env, inherits = FALSE)) return(env)
    env <- parent.env(env)
  }
  NULL
}

glsl_eval <- function(e, env, st, mask) {
  ev <- function(x) glsl_eval(x, env, st, mask)
  switch(e$op,
    num = matrix(e$value, 1, 1),
    var = {
      where <- glsl_lookup_env(e$name, env)
      if (is.null(where)) glsl_error("unknown variable '", e$name, "'.")
      get(e$name, envir = where)
    },
    swizzle = {
      x <- ev(e$args[[1]])
      sname <- attr(x, "glsl_struct")
      if (!is.null(sname)) return(glsl_field(x, sname, e$name, st))
      glsl_with_dim(x[, glsl_swizzle_index(e$name), drop = FALSE], NULL)
    },
    index = {
      x <- ev(e$args[[1]])
      i <- glsl_row_index(ev(e$args[[2]]), st, mask)
      pick <- function(i) {
        if (is.list(x)) return(x[[i]])
        d <- attr(x, "glsl_dim")
        if (!is.null(d)) return(x[, (i - 1) * d[2] + seq_len(d[2]), drop = FALSE])
        x[, i, drop = FALSE]
      }
      u <- unique(i[rep_len(mask, length(i))])
      if (length(u) <= 1) return(pick(if (length(u)) u else i[1]))
      # Rows index different elements: each row takes its own.
      parts <- lapply(u, function(k) glsl_rows(pick(k), st$n))
      out <- parts[[1]]
      for (j in seq_along(u)[-1]) {
        rows <- i == u[j]
        out[rows, ] <- parts[[j]][rows, , drop = FALSE]
      }
      out
    },
    array = lapply(e$args, ev),
    call = glsl_call(e$name, e$args, env, st, mask),
    assign = glsl_assign(e$args[[1]], e$how, ev(e$args[[2]]), env, st, mask),
    postinc = {
      old <- ev(e$args[[1]])
      glsl_assign(e$args[[1]], e$how, matrix(1, 1, 1), env, st, mask)
      old
    },
    `u-` = {
      x <- ev(e$args[[1]])
      glsl_with_dim(-x, attr(x, "glsl_dim"))
    },
    `u+` = ev(e$args[[1]]),
    `u!` = (ev(e$args[[1]]) == 0) + 0,
    `?:` = {
      cond <- ev(e$args[[1]])
      glsl_map(function(c, a, b) ifelse(c != 0, a, b), cond, ev(e$args[[2]]), ev(e$args[[3]]))
    },
    {
      a <- ev(e$args[[1]])
      b <- ev(e$args[[2]])
      if (e$op == "*") return(glsl_mul(a, b))
      f <- switch(e$op,
        `+` = `+`, `-` = `-`, `/` = `/`, `%` = function(x, y) x - y * floor(x / y),
        `<` = function(x, y) (x < y) + 0, `>` = function(x, y) (x > y) + 0,
        `<=` = function(x, y) (x <= y) + 0, `>=` = function(x, y) (x >= y) + 0,
        `==` = function(x, y) (x == y) + 0, `!=` = function(x, y) (x != y) + 0,
        `&&` = function(x, y) (x != 0 & y != 0) + 0, `||` = function(x, y) (x != 0 | y != 0) + 0,
        `^^` = function(x, y) xor(x != 0, y != 0) + 0)
      out <- glsl_map(f, a, b)
      # == and != compare whole vectors.
      if (e$op %in% c("==", "!=") && ncol(out) > 1) {
        all_equal <- rowSums(glsl_map(function(x, y) (x == y) + 0, a, b)) == ncol(out)
        out <- matrix(if (e$op == "==") all_equal + 0 else (!all_equal) + 0, ncol = 1)
      }
      if (e$op %in% c("<", ">", "<=", ">=", "==", "!=", "&&", "||", "^^")) out <- glsl_with_dim(out, NULL)
      out
    })
}

# Assigns to a variable, a swizzle, a vector component, a matrix column or
# element, or an array element, in the rows of the mask. Returns the value.
glsl_assign <- function(target, how, value, env, st, mask) {
  force(value)
  # An index that differs between the rows: assign each group of rows with
  # its index written as a number.
  t <- target
  while (t$op %in% c("swizzle", "index")) {
    if (t$op == "index") {
      i <- glsl_row_index(glsl_eval(t$args[[2]], env, st, mask), st, mask)
      m <- rep_len(mask, length(i))
      u <- unique(i[m])
      if (length(u) > 1) {
        for (k in u) {
          fixed <- glsl_replace_index(target, t, k)
          glsl_assign(fixed, how, value, env, st, m & i == k)
        }
        return(value)
      }
    }
    t <- t$args[[1]]
  }
  path <- list()
  t <- target
  while (t$op %in% c("swizzle", "index")) {
    path <- c(list(if (t$op == "swizzle") list(kind = "swizzle", name = t$name)
                   else list(kind = "index", i = glsl_masked_index(glsl_eval(t$args[[2]], env, st, mask), st, mask))), path)
    t <- t$args[[1]]
  }
  if (t$op != "var") glsl_error("cannot assign to this expression.")
  where <- glsl_lookup_env(t$name, env)
  if (is.null(where)) glsl_error("unknown variable '", t$name, "'.")
  whole <- get(t$name, envir = where)
  n <- max(st$n, 1)
  # Arrays: the first index picks the element.
  element <- NULL
  if (is.list(whole)) {
    if (!length(path) || path[[1]]$kind != "index") glsl_error("cannot assign a whole array.")
    element <- path[[1]]$i
    path <- path[-1]
  }
  old <- glsl_rows(if (is.null(element)) whole else whole[[element]], n)
  d <- attr(old, "glsl_dim")
  sname <- attr(old, "glsl_struct")
  cols <- seq_len(ncol(old))
  # Narrow the columns step by step; d and sname describe the selection.
  for (p in path) {
    if (p$kind == "swizzle" && !is.null(sname)) {
      f <- st$program$structs[[sname]]$fields[[p$name]]
      if (is.null(f)) glsl_error("struct ", sname, " has no field '", p$name, "'.")
      cols <- cols[f$offset + seq_len(f$size)]
      d <- glsl_type_dim(f$type)
      sname <- if (!is.null(st$program$structs[[f$type]])) f$type
    } else if (p$kind == "index") {
      cols <- if (!is.null(d)) cols[(p$i - 1) * d[2] + seq_len(d[2])] else cols[p$i]
      d <- NULL
    } else {
      cols <- cols[glsl_swizzle_index(p$name)]
      d <- NULL
    }
  }
  if (how != "=") {
    current <- glsl_with_dim(old[, cols, drop = FALSE], d)
    value <- if (how == "*=") glsl_mul(current, value)
             else glsl_map(switch(how, `+=` = `+`, `-=` = `-`, `/=` = `/`), current, value)
  }
  value <- glsl_rows(value, n)
  if (ncol(value) == 1 && length(cols) > 1) value <- value[, rep(1, length(cols)), drop = FALSE]
  m <- rep_len(mask, n)
  new <- old
  new[m, cols] <- value[m, , drop = FALSE]
  if (is.null(element)) {
    assign(t$name, new, envir = where)
  } else {
    whole[[element]] <- new
    assign(t$name, whole, envir = where)
  }
  value
}

# The 1-based index of each row from an index value.
glsl_row_index <- function(v, st, mask) {
  rep_len(trunc(v[, 1]) + 1, max(st$n, nrow(v)))
}
# The index of the rows under the mask (the same for all of them).
glsl_masked_index <- function(v, st, mask) {
  i <- glsl_row_index(v, st, mask)
  on <- which(rep_len(mask, length(i)))
  i[if (length(on)) on[1] else 1]
}
# The target expression with the index node `node` replaced by a number.
glsl_replace_index <- function(e, node, k) {
  if (identical(e, node)) {
    e$args[[2]] <- list(op = "num", value = k - 1)
    return(e)
  }
  if (!is.null(e$args)) e$args[[1]] <- glsl_replace_index(e$args[[1]], node, k)
  e
}

glsl_call <- function(name, arg_exprs, env, st, mask) {
  fns <- st$program$functions[[name]]
  if (is.null(fns) && name %in% c("EmitVertex", "EndPrimitive") && !is.null(st$emits)) {
    event <- list(mask = rep_len(mask, st$n), end = name == "EndPrimitive")
    if (!event$end) {
      event$values <- lapply(stats::setNames(nm = st$gs_outputs), function(nm) glsl_rows(get(nm, envir = st$globals), st$n))
    }
    st$emits[[length(st$emits) + 1]] <- event
    return(matrix(0, 1, 1))
  }
  if (is.null(fns) && name %in% c("texture", "texture2D", "textureLod", "texelFetch", "textureSize")) {
    sampler <- glsl_eval(arg_exprs[[1]], env, st, mask)
    unit <- sampler[1, 1]
    stype <- attr(sampler, "glsl_sampler") %||% "sampler2D"
    tex <- if (stype == "sampler2D" && unit + 1 <= length(st$textures)) {
      st$textures[[unit + 1]]
    }
    if (name == "textureSize") {
      # The base level's size; 0 for the default texture.
      size <- if (is.null(tex)) c(0, 0) else as.numeric(tex$size)
      return(glsl_typed(matrix(size, 1, 2), "ivec2", st))
    }
    # A texture that is not bound reads as (0, 0, 0, 1), as OpenGL's default
    # texture does.
    if (is.null(tex)) return(glsl_typed(matrix(c(0, 0, 0, 1), st$n, 4, byrow = TRUE), "vec4", st))
    p <- glsl_rows(glsl_eval(arg_exprs[[2]], env, st, mask), st$n)
    if (name == "texelFetch") {
      # The texel at integer coordinates; outside the texture, 0.
      img <- tex$data
      h <- dim(img)[1]; w <- dim(img)[2]; k <- dim(img)[3]
      x <- trunc(p[, 1]); y <- trunc(p[, 2])
      ok <- x >= 0 & x < w & y >= 0 & y < h
      out <- matrix(c(0, 0, 0, 1), st$n, 4, byrow = TRUE)
      out[, seq_len(k)] <- 0
      for (j in seq_len(k)) out[ok, j] <- img[cbind(y[ok] + 1, x[ok] + 1, j)]
      return(glsl_typed(out, "vec4", st))
    }
    # Textures here have no mipmaps, so textureLod() samples the base level.
    return(tex$sample(p[, 1:2, drop = FALSE]))
  }
  if (is.null(fns)) {
    args <- lapply(arg_exprs, glsl_eval, env, st, mask)
    if (name %in% names(GLSL_TYPES)) return(glsl_construct(name, args))
    if (!is.null(st$program$structs[[name]])) {
      n <- max(vapply(args, nrow, 1))
      out <- do.call(cbind, lapply(args, function(a) glsl_with_dim(glsl_rows(a, n), NULL)))
      if (ncol(out) != st$program$structs[[name]]$size) glsl_error("wrong arguments for struct ", name, ".")
      return(glsl_typed(out, name, st))
    }
    return(glsl_builtin(name, args))
  }
  # Overloads: the one with the matching number of parameters.
  fn <- Filter(function(f) length(f$params) == length(arg_exprs), fns)
  if (!length(fn)) glsl_error("no function '", name, "' takes ", length(arg_exprs), " arguments.")
  fn <- fn[[1]]
  local <- new.env(parent = st$globals)
  for (i in seq_along(fn$params)) {
    p <- fn$params[[i]]
    value <- if (p$out && !p$inout) {
      matrix(0, 1, glsl_size(p$type, st))
    } else {
      glsl_eval(arg_exprs[[i]], env, st, mask)
    }
    assign(p$name, glsl_rows(glsl_typed(value, p$type, st), st$n), envir = local)
  }
  saved <- list(ret = st$ret, returned = st$returned)
  st$ret <- if (fn$type == "void") NULL else matrix(0, st$n, glsl_size(fn$type, st))
  st$returned <- rep(FALSE, st$n)
  glsl_exec(fn$body, local, st, rep_len(mask, st$n))
  result <- st$ret
  if (!is.null(result)) result <- glsl_typed(result, fn$type, st)
  st$ret <- saved$ret
  st$returned <- saved$returned
  for (i in seq_along(fn$params)) {
    p <- fn$params[[i]]
    if (p$out) glsl_assign(arg_exprs[[i]], "=", get(p$name, envir = local), env, st, mask)
  }
  result %||% matrix(0, 1, 1)
}

# Runs statements in the rows of the mask; returns the rows still running
# after them (not returned, discarded, broken or continued).
glsl_exec <- function(statements, env, st, mask) {
  for (s in statements) {
    if (!any(mask)) break
    mask <- switch(s$kind,
      expr = {
        glsl_eval(s$value, env, st, mask)
        mask
      },
      block = glsl_exec(s$body, new.env(parent = env), st, mask),
      decl = {
        glsl_declare(s, env, st, mask)
        mask
      },
      `if` = {
        cond <- rep_len(glsl_eval(s$cond, env, st, mask)[, 1] != 0, st$n)
        yes <- if (any(mask & cond)) glsl_exec(s$yes, new.env(parent = env), st, mask & cond) else rep(FALSE, st$n)
        no <- if (any(mask & !cond)) glsl_exec(s$no, new.env(parent = env), st, mask & !cond) else rep(FALSE, st$n)
        yes | no
      },
      `for` = {
        scope <- new.env(parent = env)
        glsl_exec(s$init, scope, st, mask)
        outer <- list(brk = st$brk, cont = st$cont)
        active <- mask
        first <- isTRUE(s$first)
        for (iter in seq_len(100000)) {
          if (!first) active <- active & rep_len(glsl_eval(s$cond, scope, st, active)[, 1] != 0, st$n)
          first <- FALSE
          if (!any(active)) break
          st$brk <- rep(FALSE, st$n)
          st$cont <- rep(FALSE, st$n)
          after <- glsl_exec(s$body, new.env(parent = scope), st, active)
          active <- (after | st$cont) & !st$brk
          if (!is.null(s$step) && any(active)) glsl_eval(s$step, scope, st, active)
        }
        st$brk <- outer$brk
        st$cont <- outer$cont
        mask & !st$returned & !st$discarded
      },
      `return` = {
        if (!is.null(s$value)) {
          value <- glsl_rows(glsl_eval(s$value, env, st, mask), st$n)
          st$ret[mask, ] <- value[mask, , drop = FALSE]
        }
        st$returned <- st$returned | mask
        rep(FALSE, st$n)
      },
      `break` = {
        st$brk <- st$brk | mask
        rep(FALSE, st$n)
      },
      `continue` = {
        st$cont <- st$cont | mask
        rep(FALSE, st$n)
      },
      discard = {
        st$discarded <- st$discarded | mask
        rep(FALSE, st$n)
      })
  }
  mask
}

glsl_declare <- function(s, env, st, mask, value = NULL) {
  k <- glsl_size(s$type, st)
  d <- glsl_type_dim(s$type)
  is_struct <- !is.null(st$program$structs[[s$type]])
  if (is.null(value)) {
    value <- if (!is.null(s$value)) {
      glsl_eval(s$value, env, st, mask)
    } else if (!is.null(s$size)) {
      size <- glsl_eval(s$size, env, st, mask)[1, 1]
      replicate(size, glsl_typed(matrix(0, 1, k), s$type, st), simplify = FALSE)
    } else {
      matrix(0, 1, k)
    }
  }
  if (!is.list(value)) {
    if (ncol(value) == 1 && k > 1 && is.null(d) && !is_struct) value <- value[, rep(1, k), drop = FALSE]
    if (glsl_is_int_type(s$type)) value <- trunc(value)
    value <- glsl_typed(value, s$type, st)
  }
  assign(s$name, value, envir = env)
}

# Runs one shader stage for n rows. `inputs` and `uniforms` are named lists
# of values (a uniform matrix as its column-major numbers); `builtins` sets
# variables such as gl_FragCoord. Returns the state, whose globals hold the
# outputs and whose `discarded` flags the discarded rows. For a geometry
# shader, `inputs` hold lists (one matrix per vertex of the primitive),
# `geometry` the vertices' gl_Position, and the state's `emits` the events
# of EmitVertex() and EndPrimitive().
glsl_run <- function(program, n, inputs = list(), uniforms = list(), builtins = list(), geometry = NULL,
                     textures = NULL) {
  st <- glsl_new_state(program, n)
  st$textures <- textures
  g <- st$globals
  if (!is.null(geometry)) {
    st$program$structs$gl_PerVertex <- list(fields = list(gl_Position = list(type = "vec4", offset = 0, size = 4)),
                                            size = 4)
    assign("gl_in", lapply(geometry, function(p) glsl_typed(as.matrix(p), "gl_PerVertex", st)), envir = g)
    assign("gl_PrimitiveIDIn", matrix(seq_len(n) - 1, n, 1), envir = g)
    st$emits <- list()
    st$gs_outputs <- c("gl_Position", vapply(glsl_outputs(program), function(s) s$name, ""))
  }
  st$returned <- rep(FALSE, n)
  st$brk <- rep(FALSE, n)
  st$cont <- rep(FALSE, n)
  for (name in names(builtins)) assign(name, builtins[[name]], envir = g)
  assign("gl_Position", matrix(0, n, 4), envir = g)
  assign("gl_FragColor", matrix(0, n, 4), envir = g)
  assign("gl_PointSize", matrix(1, 1, 1), envir = g)
  mask <- rep(TRUE, n)
  for (s in program$globals) {
    k <- glsl_size(s$type, st)
    value <- NULL
    if (any(s$quals %in% c("in", "attribute", "varying")) && !"out" %in% s$quals && s$name %in% names(inputs) &&
        is.list(inputs[[s$name]])) {
      value <- lapply(inputs[[s$name]], function(v) glsl_typed(as.matrix(v)[, seq_len(k), drop = FALSE], s$type, st))
    } else if (any(s$quals %in% c("in", "attribute", "varying")) && !"out" %in% s$quals && s$name %in% names(inputs)) {
      v <- as.matrix(inputs[[s$name]])
      if (ncol(v) < k) {
        # Missing components are filled from (0, 0, 0, 1), as OpenGL does.
        full <- matrix(c(0, 0, 0, 1)[seq_len(k)], nrow(v), k, byrow = TRUE)
        full[, seq_len(ncol(v))] <- v
        v <- full
      }
      value <- v[, seq_len(k), drop = FALSE]
    } else if ("uniform" %in% s$quals) {
      u <- glsl_flat_uniform(uniforms[[s$name]], s$type, st)
      value <- if (is.null(u)) matrix(0, 1, k) else matrix(as.numeric(u)[seq_len(k)], 1, k)
      value[is.na(value)] <- 0
    } else if (any(s$quals %in% c("out", "varying"))) {
      value <- matrix(0, n, k)
    }
    glsl_declare(s, g, st, mask, value)
  }
  # OpenGL refuses to draw when samplers of different types share a unit.
  samplers <- Filter(function(s) "uniform" %in% s$quals && grepl("sampler", s$type, fixed = TRUE), program$globals)
  if (length(samplers) > 1) {
    units <- vapply(samplers, function(s) as.numeric(uniforms[[s$name]] %||% 0)[1], 0)
    types <- vapply(samplers, function(s) s$type, "")
    clash <- vapply(split(types, units), function(t) length(unique(t)) > 1, TRUE)
    if (any(clash)) glsl_error("samplers of different types use texture unit ", names(clash)[clash][1],
                               "; OpenGL does not draw then.")
  }
  main <- program$functions$main
  if (is.null(main)) glsl_error("the shader has no main().")
  glsl_exec(main[[1]]$body, new.env(parent = g), st, mask)
  st
}

# A uniform's numbers; a struct uniform is a named list of its fields.
glsl_flat_uniform <- function(u, type, st) {
  s <- st$program$structs[[type]]
  if (is.null(s) || !is.list(u)) return(if (is.null(u)) NULL else as.numeric(unlist(u)))
  unlist(lapply(names(s$fields), function(f) {
    v <- glsl_flat_uniform(u[[f]], s$fields[[f]]$type, st)
    if (is.null(v)) rep(0, s$fields[[f]]$size) else v
  }))
}

glsl_program_cache <- new.env(parent = emptyenv())
glsl_program <- function(code) {
  key <- digest::digest(code)
  program <- glsl_program_cache[[key]]
  if (is.null(program)) {
    program <- glsl_parse(glsl_tokenize(code))
    assign(key, program, envir = glsl_program_cache)
  }
  program
}

# The names and types of a stage's declared outputs.
glsl_outputs <- function(program) {
  Filter(function(s) any(s$quals %in% c("out", "varying")) && !"in" %in% s$quals, program$globals)
}
