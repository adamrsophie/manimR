# Upstream classes that manimR builds with a function (they mostly preset
# arguments of their parent class). Each gets its own generator, FooClass,
# a subclass of its upstream parent, and Foo() creates objects of it, so
# inherits(x, "Foo"), subclassing FooClass and set_default(Foo, ...) work as
# they do for upstream's classes.

#' Generators of classes built by constructor functions
#'
#' Some upstream classes only preset the arguments of their parent class, and
#' manimR builds them with a function. They still have a class generator, a
#' subclass of the upstream parent: `MathTableClass` inherits from
#' `TableClass`, `ReplacementTransformClass` from `TransformClass`, and so
#' on. `MathTable()` creates an object of `MathTableClass`, so
#' `inherits(x, "MathTable")` is `TRUE`, a scene can subclass the generator,
#' and [set_default()] changes the defaults of that class alone.
#'
#' @name factory_classes
#' @aliases AddTextWordByWordClass AnnotationDotClass ApplyComplexFunctionClass ApplyPointwiseFunctionClass ApplyWaveClass ArcBraceClass
#' @aliases ArcPolygonClass ArcPolygonFromArcsClass BlinkClass BraceBetweenPointsClass BraceTextClass BroadcastClass
#' @aliases ChangeDecimalToValueClass CircumscribeClass ClockwiseTransformClass ComplexHomotopyClass ConvexHullClass ConvexHull3DClass
#' @aliases CounterclockwiseTransformClass CrossClass CubicBezierClass CurvedArrowClass CurvedDoubleArrowClass CutoutClass
#' @aliases DashedVMobjectClass DecimalMatrixClass DecimalTableClass DodecahedronClass DoubleArrowClass ElbowClass
#' @aliases FadeToColorClass FullScreenRectangleClass GrowFromCenterClass GrowFromEdgeClass IcosahedronClass IntegerMatrixClass
#' @aliases IntegerTableClass LabeledDotClass LaggedStartClass LaggedStartMapClass MathTableClass MobjectMatrixClass
#' @aliases MobjectTableClass OctahedronClass ParagraphClass RemoveTextLetterByLetterClass ReplacementTransformClass RestoreClass
#' @aliases RightAngleClass ScaleInPlaceClass SectorClass ShowPassingFlashWithThinningStrokeWidthClass ShrinkToCenterClass SpinInFromNothingClass
#' @aliases StarClass SwapClass TangentLineClass TangentialArcClass TetrahedronClass UncreateClass
#' @aliases UnderlineClass UntypeWithCursorClass UnwriteClass VariableClass
#' @format NULL
#' @usage NULL
#' @examples
#' t <- MathTableClass
#' inherits(t$get_inherit(), "R6ClassGenerator")
#' @rawNamespace export(AddTextWordByWordClass, AnnotationDotClass, ApplyComplexFunctionClass)
#' @rawNamespace export(ApplyPointwiseFunctionClass, ApplyWaveClass, ArcBraceClass, ArcPolygonClass)
#' @rawNamespace export(ArcPolygonFromArcsClass, BlinkClass, BraceBetweenPointsClass, BraceTextClass)
#' @rawNamespace export(BroadcastClass, ChangeDecimalToValueClass, CircumscribeClass, ClockwiseTransformClass)
#' @rawNamespace export(ComplexHomotopyClass, ConvexHullClass, ConvexHull3DClass)
#' @rawNamespace export(CounterclockwiseTransformClass, CrossClass, CubicBezierClass, CurvedArrowClass)
#' @rawNamespace export(CurvedDoubleArrowClass, CutoutClass, DashedVMobjectClass, DecimalMatrixClass)
#' @rawNamespace export(DecimalTableClass, DodecahedronClass, DoubleArrowClass, ElbowClass, FadeToColorClass)
#' @rawNamespace export(FullScreenRectangleClass, GrowFromCenterClass, GrowFromEdgeClass, IcosahedronClass)
#' @rawNamespace export(IntegerMatrixClass, IntegerTableClass, LabeledDotClass, LaggedStartClass)
#' @rawNamespace export(LaggedStartMapClass, MathTableClass, MobjectMatrixClass, MobjectTableClass)
#' @rawNamespace export(OctahedronClass, ParagraphClass, RemoveTextLetterByLetterClass)
#' @rawNamespace export(ReplacementTransformClass, RestoreClass, RightAngleClass, ScaleInPlaceClass)
#' @rawNamespace export(SectorClass, ShowPassingFlashWithThinningStrokeWidthClass, ShrinkToCenterClass)
#' @rawNamespace export(SpinInFromNothingClass, StarClass, SwapClass, TangentLineClass, TangentialArcClass)
#' @rawNamespace export(TetrahedronClass, UncreateClass, UnderlineClass, UntypeWithCursorClass, UnwriteClass)
#' @rawNamespace export(VariableClass)
NULL

# Class name and upstream parent, parents first.
FACTORY_CLASSES <- list(
  c("AnnotationDot", "Dot"), c("LabeledDot", "Dot"), c("ApplyPointwiseFunction", "ApplyMethod"),
  c("ApplyComplexFunction", "ApplyMethod"), c("FadeToColor", "ApplyMethod"), c("Restore", "ApplyMethod"),
  c("ScaleInPlace", "ApplyMethod"), c("ShrinkToCenter", "ScaleInPlace"), c("ApplyWave", "Homotopy"),
  c("ComplexHomotopy", "Homotopy"), c("ArcBrace", "Brace"), c("BraceBetweenPoints", "Brace"),
  c("BraceText", "BraceLabel"), c("ArcPolygon", "VMobject"), c("ArcPolygonFromArcs", "VMobject"),
  c("CubicBezier", "VMobject"), c("Cutout", "VMobject"), c("DashedVMobject", "VMobject"), c("Elbow", "VMobject"),
  c("Variable", "VMobject"), c("Cross", "VGroup"), c("Paragraph", "VGroup"), c("AddTextWordByWord", "Succession"),
  c("Blink", "Succession"), c("Circumscribe", "Succession"), c("LaggedStart", "AnimationGroup"),
  c("LaggedStartMap", "LaggedStart"), c("Broadcast", "LaggedStart"),
  c("ShowPassingFlashWithThinningStrokeWidth", "AnimationGroup"), c("ChangeDecimalToValue", "ChangingDecimal"),
  c("ClockwiseTransform", "Transform"), c("CounterclockwiseTransform", "Transform"),
  c("ReplacementTransform", "Transform"), c("ConvexHull", "Polygram"), c("Star", "Polygon"),
  c("ConvexHull3D", "Polyhedron"), c("Dodecahedron", "Polyhedron"), c("Icosahedron", "Polyhedron"),
  c("Octahedron", "Polyhedron"), c("Tetrahedron", "Polyhedron"), c("CurvedArrow", "ArcBetweenPoints"),
  c("CurvedDoubleArrow", "CurvedArrow"), c("TangentialArc", "ArcBetweenPoints"), c("DoubleArrow", "Arrow"),
  c("DecimalMatrix", "Matrix"), c("IntegerMatrix", "Matrix"), c("MobjectMatrix", "Matrix"),
  c("DecimalTable", "Table"), c("IntegerTable", "Table"), c("MathTable", "Table"), c("MobjectTable", "Table"),
  c("FullScreenRectangle", "ScreenRectangle"), c("GrowFromCenter", "GrowFromPoint"),
  c("GrowFromEdge", "GrowFromPoint"), c("SpinInFromNothing", "GrowFromCenter"),
  c("RemoveTextLetterByLetter", "AddTextLetterByLetter"), c("Sector", "AnnularSector"),
  c("Swap", "CyclicReplace"), c("TangentLine", "Line"), c("Underline", "Line"), c("RightAngle", "Angle"),
  c("Uncreate", "Create"), c("UntypeWithCursor", "TypeWithCursor"), c("Unwrite", "Write")
)

# Moves the state of `built` (an object of a parent class) into `self`.
adopt_object <- function(self, built) {
  copy_fields <- function(from, to) {
    for (nm in ls(from, all.names = TRUE)) {
      if (nm %in% c(".__enclos_env__", ".__active__") || bindingIsLocked(nm, from) || bindingIsActive(nm, from)) next
      has <- exists(nm, envir = to, inherits = FALSE)
      if (has && (bindingIsLocked(nm, to) || bindingIsActive(nm, to))) next
      # A subclass made with lock_objects = TRUE takes only its declared fields.
      if (!has && environmentIsLocked(to)) next
      assign(nm, get(nm, envir = from, inherits = FALSE), envir = to)
    }
  }
  copy_fields(built, self)
  from_private <- .subset2(built, ".__enclos_env__")$private
  to_private <- .subset2(self, ".__enclos_env__")$private
  if (is.environment(from_private) && is.environment(to_private)) copy_fields(from_private, to_private)
  invisible(self)
}

# A generator whose objects are built by `factory` and adopt its result.
# The built object must be of the nearest ancestor that is not itself made
# by a function.
factory_class <- function(classname, parent, factory) {
  required <- parent
  while (paste0(required$classname) %in% vapply(FACTORY_CLASSES, `[`, "", 1)) required <- required$get_inherit()
  fmls <- formals(factory)
  args <- lapply(names(fmls), function(n) if (n == "...") quote(...) else as.name(n))
  names(args) <- ifelse(names(fmls) == "...", "", names(fmls))
  init <- function() NULL
  formals(init) <- fmls
  body(init) <- bquote({
    built <- .(as.call(c(list(factory), args)))
    if (!inherits(built, .(required$classname))) {
      stop(.(classname), "() returned a ", class(built)[1], ", which is not a ", .(required$classname),
           "; call ", .(classname), "() rather than ", .(paste0(classname, "Class$new()")), call. = FALSE)
    }
    adopt_object(self, built)
    invisible(self)
  })
  R6::R6Class(classname, inherit = parent, lock_objects = FALSE, public = list(initialize = init))
}

local({
  ns <- topenv()
  for (entry in FACTORY_CLASSES) {
    name <- entry[1]
    factory <- get(name, envir = ns)
    parent <- get0(paste0(entry[2], "Class"), envir = ns) %||% get(entry[2], envir = ns)
    gen <- factory_class(name, parent, factory)
    assign(paste0(name, "Class"), gen, envir = ns)
    assign(name, build_constructor(gen), envir = ns)
  }
})
