# Package index

## Scenes

Scene classes and the scene manager.

- [`Scene`](https://adamrsophie.github.io/manimR/reference/Scene.md) :
  Scene
- [`MovingCameraScene`](https://adamrsophie.github.io/manimR/reference/MovingCameraScene.md)
  : MovingCameraScene
- [`ZoomedScene`](https://adamrsophie.github.io/manimR/reference/ZoomedScene.md)
  : ZoomedScene
- [`ThreeDScene`](https://adamrsophie.github.io/manimR/reference/ThreeDScene.md)
  [`SpecialThreeDScene`](https://adamrsophie.github.io/manimR/reference/ThreeDScene.md)
  : ThreeDScene
- [`X_COLOR`](https://adamrsophie.github.io/manimR/reference/VectorScene.md)
  [`Y_COLOR`](https://adamrsophie.github.io/manimR/reference/VectorScene.md)
  [`Z_COLOR`](https://adamrsophie.github.io/manimR/reference/VectorScene.md)
  : VectorScene and LinearTransformationScene
- [`interactive_scene`](https://adamrsophie.github.io/manimR/reference/interactive_scene.md)
  : Interactive scenes
- [`Manager()`](https://adamrsophie.github.io/manimR/reference/Manager.md)
  : Render manager
- [`Section()`](https://adamrsophie.github.io/manimR/reference/Section.md)
  : Scene sections
- [`DefaultSectionType`](https://adamrsophie.github.io/manimR/reference/DefaultSectionType.md)
  : Section types
- [`manim_scene()`](https://adamrsophie.github.io/manimR/reference/manim_scene.md)
  : Define a scene from a function

## Rendering and output

Render scenes to video, GIF and images, from R or the command line.

- [`render()`](https://adamrsophie.github.io/manimR/reference/render.md)
  : Render a scene
- [`render_file()`](https://adamrsophie.github.io/manimR/reference/render_file.md)
  : Render scenes from a script
- [`find_scenes()`](https://adamrsophie.github.io/manimR/reference/find_scenes.md)
  : Find scenes defined in a file or environment
- [`manim_cli()`](https://adamrsophie.github.io/manimR/reference/manim_cli.md)
  : Command line entry point
- [`preview_output()`](https://adamrsophie.github.io/manimR/reference/preview_output.md)
  : Preview a rendered file
- [`manim_check()`](https://adamrsophie.github.io/manimR/reference/manim_check.md)
  : Check system requirements
- [`get_dir()`](https://adamrsophie.github.io/manimR/reference/get_dir.md)
  : Resolve a directory setting
- [`digest_config_file()`](https://adamrsophie.github.io/manimR/reference/digest_config_file.md)
  [`config_file_paths()`](https://adamrsophie.github.io/manimR/reference/digest_config_file.md)
  : Read a manim.cfg file
- [`plot(`*`<Mobject>`*`)`](https://adamrsophie.github.io/manimR/reference/plot.Mobject.md)
  : Plot a mobject
- [`SceneFileWriter()`](https://adamrsophie.github.io/manimR/reference/CairoRenderer.md)
  [`CairoRenderer()`](https://adamrsophie.github.io/manimR/reference/CairoRenderer.md)
  : Cairo style renderer and scene file writer

## Configuration and logging

- [`config`](https://adamrsophie.github.io/manimR/reference/config.md)
  [`` `$`( ``*`<manim_config_object>`*`)`](https://adamrsophie.github.io/manimR/reference/config.md)
  [`` `[[`( ``*`<manim_config_object>`*`)`](https://adamrsophie.github.io/manimR/reference/config.md)
  [`` `$<-`( ``*`<manim_config_object>`*`)`](https://adamrsophie.github.io/manimR/reference/config.md)
  [`` `[[<-`( ``*`<manim_config_object>`*`)`](https://adamrsophie.github.io/manimR/reference/config.md)
  [`names(`*`<manim_config_object>`*`)`](https://adamrsophie.github.io/manimR/reference/config.md)
  [`print(`*`<manim_config_object>`*`)`](https://adamrsophie.github.io/manimR/reference/config.md)
  [`manim_frame`](https://adamrsophie.github.io/manimR/reference/config.md)
  [`` `$`( ``*`<manim_frame_object>`*`)`](https://adamrsophie.github.io/manimR/reference/config.md)
  [`` `[[`( ``*`<manim_frame_object>`*`)`](https://adamrsophie.github.io/manimR/reference/config.md)
  [`` `$<-`( ``*`<manim_frame_object>`*`)`](https://adamrsophie.github.io/manimR/reference/config.md)
  [`` `[[<-`( ``*`<manim_frame_object>`*`)`](https://adamrsophie.github.io/manimR/reference/config.md)
  [`names(`*`<manim_frame_object>`*`)`](https://adamrsophie.github.io/manimR/reference/config.md)
  [`print(`*`<manim_frame_object>`*`)`](https://adamrsophie.github.io/manimR/reference/config.md)
  [`tempconfig()`](https://adamrsophie.github.io/manimR/reference/config.md)
  : The global configuration object
- [`manim_config()`](https://adamrsophie.github.io/manimR/reference/manim_config.md)
  : Get or set the manimR configuration
- [`with_manim_config()`](https://adamrsophie.github.io/manimR/reference/with_manim_config.md)
  : Run code with a temporary configuration
- [`QUALITIES`](https://adamrsophie.github.io/manimR/reference/QUALITIES.md)
  [`DEFAULT_QUALITY`](https://adamrsophie.github.io/manimR/reference/QUALITIES.md)
  : Render qualities
- [`RESAMPLING_ALGORITHMS`](https://adamrsophie.github.io/manimR/reference/RESAMPLING_ALGORITHMS.md)
  : Resampling algorithms for images
- [`logger`](https://adamrsophie.github.io/manimR/reference/logger.md)
  [`console`](https://adamrsophie.github.io/manimR/reference/logger.md)
  [`error_console`](https://adamrsophie.github.io/manimR/reference/logger.md)
  [`cli_ctx_settings`](https://adamrsophie.github.io/manimR/reference/logger.md)
  : Logging and console output

## Mobjects

The base classes, groups and indexing.

- [`Mobject()`](https://adamrsophie.github.io/manimR/reference/MobjectClass.md)
  : Mobject
- [`VMobject()`](https://adamrsophie.github.io/manimR/reference/VMobjectClass.md)
  : VMobject
- [`Group()`](https://adamrsophie.github.io/manimR/reference/GroupClass.md)
  : Group of mobjects
- [`VGroup()`](https://adamrsophie.github.io/manimR/reference/VGroupClass.md)
  : VGroup
- [`VDict()`](https://adamrsophie.github.io/manimR/reference/VDictClass.md)
  : VDict
- [`VectorizedPoint()`](https://adamrsophie.github.io/manimR/reference/VectorizedPointClass.md)
  : VectorizedPoint
- [`` `[`( ``*`<Mobject>`*`)`](https://adamrsophie.github.io/manimR/reference/sub-.Mobject.md)
  [`` `[<-`( ``*`<Mobject>`*`)`](https://adamrsophie.github.io/manimR/reference/sub-.Mobject.md)
  [`` `[[<-`( ``*`<Mobject>`*`)`](https://adamrsophie.github.io/manimR/reference/sub-.Mobject.md)
  [`length(`*`<Mobject>`*`)`](https://adamrsophie.github.io/manimR/reference/sub-.Mobject.md)
  [`` `[[`( ``*`<Mobject>`*`)`](https://adamrsophie.github.io/manimR/reference/sub-.Mobject.md)
  : Index submobjects
- [`print_family()`](https://adamrsophie.github.io/manimR/reference/print_family.md)
  [`index_labels()`](https://adamrsophie.github.io/manimR/reference/print_family.md)
  : Debugging helpers
- [`set_default()`](https://adamrsophie.github.io/manimR/reference/set_default.md)
  : Change default arguments of a mobject or animation class
- [`class_methods`](https://adamrsophie.github.io/manimR/reference/class_methods.md)
  : Class methods
- [`factory_classes`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`AddTextWordByWordClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`AnnotationDotClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`ApplyComplexFunctionClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`ApplyPointwiseFunctionClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`ApplyWaveClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`ArcBraceClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`ArcPolygonClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`ArcPolygonFromArcsClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`BlinkClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`BraceBetweenPointsClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`BraceTextClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`BroadcastClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`ChangeDecimalToValueClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`CircumscribeClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`ClockwiseTransformClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`ComplexHomotopyClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`ConvexHullClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`ConvexHull3DClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`CounterclockwiseTransformClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`CrossClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`CubicBezierClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`CurvedArrowClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`CurvedDoubleArrowClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`CutoutClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`DashedVMobjectClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`DecimalMatrixClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`DecimalTableClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`DodecahedronClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`DoubleArrowClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`ElbowClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`FadeToColorClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`FullScreenRectangleClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`GrowFromCenterClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`GrowFromEdgeClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`IcosahedronClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`IntegerMatrixClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`IntegerTableClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`LabeledDotClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`LaggedStartClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`LaggedStartMapClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`MathTableClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`MobjectMatrixClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`MobjectTableClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`OctahedronClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`ParagraphClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`RemoveTextLetterByLetterClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`ReplacementTransformClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`RestoreClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`RightAngleClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`ScaleInPlaceClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`SectorClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`ShowPassingFlashWithThinningStrokeWidthClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`ShrinkToCenterClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`SpinInFromNothingClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`StarClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`SwapClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`TangentLineClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`TangentialArcClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`TetrahedronClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`UncreateClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`UnderlineClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`UntypeWithCursorClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`UnwriteClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  [`VariableClass`](https://adamrsophie.github.io/manimR/reference/factory_classes.md)
  : Generators of classes built by constructor functions
- [`as_mobject()`](https://adamrsophie.github.io/manimR/reference/as_mobject.md)
  : Turn R plots into mobjects

## Geometry

- [`Arc()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`ArcBetweenPoints()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`CurvedArrow()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`CurvedDoubleArrow()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`Circle()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`circle_from_three_points()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`Dot()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`AnnotationDot()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`LabeledDot()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`Ellipse()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`AnnularSector()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`Sector()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`Annulus()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`CubicBezier()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`ArcPolygon()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`ArcPolygonFromArcs()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`Line()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`DashedLine()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`TangentLine()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`Elbow()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`Arrow()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`Vector()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`DoubleArrow()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`Angle()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`angle_from_three_points()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`RightAngle()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`Polygram()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`Polygon()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`RegularPolygram()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`RegularPolygon()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`Triangle()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`Star()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`Rectangle()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`Square()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`RoundedRectangle()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`Cutout()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`ConvexHull()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`SurroundingRectangle()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`BackgroundRectangle()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`Cross()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`Underline()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`TangentialArc()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`TipableVMobject()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`ArrowTip()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`ArrowTriangleTip()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`ArrowTriangleFilledTip()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`ArrowCircleTip()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`ArrowCircleFilledTip()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`ArrowSquareTip()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`ArrowSquareFilledTip()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  [`StealthTip()`](https://adamrsophie.github.io/manimR/reference/geometry.md)
  : Geometry mobjects
- [`Union()`](https://adamrsophie.github.io/manimR/reference/boolean_ops.md)
  [`Intersection()`](https://adamrsophie.github.io/manimR/reference/boolean_ops.md)
  [`Difference()`](https://adamrsophie.github.io/manimR/reference/boolean_ops.md)
  [`Exclusion()`](https://adamrsophie.github.io/manimR/reference/boolean_ops.md)
  : Boolean operations on VMobjects
- [`Brace()`](https://adamrsophie.github.io/manimR/reference/BraceClass.md)
  [`BraceLabel()`](https://adamrsophie.github.io/manimR/reference/BraceClass.md)
  [`BraceText()`](https://adamrsophie.github.io/manimR/reference/BraceClass.md)
  [`BraceBetweenPoints()`](https://adamrsophie.github.io/manimR/reference/BraceClass.md)
  [`ArcBrace()`](https://adamrsophie.github.io/manimR/reference/BraceClass.md)
  : Brace
- [`Label()`](https://adamrsophie.github.io/manimR/reference/LabelClass.md)
  [`LabeledLine()`](https://adamrsophie.github.io/manimR/reference/LabelClass.md)
  [`LabeledArrow()`](https://adamrsophie.github.io/manimR/reference/LabelClass.md)
  [`LabeledPolygram()`](https://adamrsophie.github.io/manimR/reference/LabelClass.md)
  : Labels
- [`DashedVMobject()`](https://adamrsophie.github.io/manimR/reference/DashedVMobject.md)
  : DashedVMobject
- [`CurvesAsSubmobjects()`](https://adamrsophie.github.io/manimR/reference/CurvesAsSubmobjects.md)
  : CurvesAsSubmobjects
- [`ScreenRectangle()`](https://adamrsophie.github.io/manimR/reference/ScreenRectangleClass.md)
  [`FullScreenRectangle()`](https://adamrsophie.github.io/manimR/reference/ScreenRectangleClass.md)
  : ScreenRectangle and FullScreenRectangle
- [`ManimBanner()`](https://adamrsophie.github.io/manimR/reference/ManimBannerClass.md)
  : ManimBanner

## Text, math and tables

- [`Text()`](https://adamrsophie.github.io/manimR/reference/TextClass.md)
  : Text
- [`MarkupText()`](https://adamrsophie.github.io/manimR/reference/MarkupText.md)
  : MarkupText
- [`Paragraph()`](https://adamrsophie.github.io/manimR/reference/Paragraph.md)
  : Paragraph
- [`BulletedList()`](https://adamrsophie.github.io/manimR/reference/BulletedList.md)
  [`Title()`](https://adamrsophie.github.io/manimR/reference/BulletedList.md)
  : BulletedList and Title
- [`register_font()`](https://adamrsophie.github.io/manimR/reference/register_font.md)
  : Use a font file with Text
- [`remove_invisible_chars()`](https://adamrsophie.github.io/manimR/reference/remove_invisible_chars.md)
  : Remove the invisible characters of a text mobject
- [`NORMAL`](https://adamrsophie.github.io/manimR/reference/font_constants.md)
  [`ITALIC`](https://adamrsophie.github.io/manimR/reference/font_constants.md)
  [`OBLIQUE`](https://adamrsophie.github.io/manimR/reference/font_constants.md)
  [`BOLD`](https://adamrsophie.github.io/manimR/reference/font_constants.md)
  [`THIN`](https://adamrsophie.github.io/manimR/reference/font_constants.md)
  [`ULTRALIGHT`](https://adamrsophie.github.io/manimR/reference/font_constants.md)
  [`LIGHT`](https://adamrsophie.github.io/manimR/reference/font_constants.md)
  [`SEMILIGHT`](https://adamrsophie.github.io/manimR/reference/font_constants.md)
  [`BOOK`](https://adamrsophie.github.io/manimR/reference/font_constants.md)
  [`MEDIUM`](https://adamrsophie.github.io/manimR/reference/font_constants.md)
  [`SEMIBOLD`](https://adamrsophie.github.io/manimR/reference/font_constants.md)
  [`ULTRABOLD`](https://adamrsophie.github.io/manimR/reference/font_constants.md)
  [`HEAVY`](https://adamrsophie.github.io/manimR/reference/font_constants.md)
  [`ULTRAHEAVY`](https://adamrsophie.github.io/manimR/reference/font_constants.md)
  [`LineJointType`](https://adamrsophie.github.io/manimR/reference/font_constants.md)
  [`CapStyleType`](https://adamrsophie.github.io/manimR/reference/font_constants.md)
  : Font styles, weights and stroke styles
- [`SingleStringMathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md)
  [`MathTex()`](https://adamrsophie.github.io/manimR/reference/tex.md)
  [`Tex()`](https://adamrsophie.github.io/manimR/reference/tex.md) :
  MathTex and Tex
- [`TexTemplate()`](https://adamrsophie.github.io/manimR/reference/TexTemplateClass.md)
  : TexTemplate
- [`TexTemplateLibrary()`](https://adamrsophie.github.io/manimR/reference/TexTemplateLibrary.md)
  [`TexFontTemplates()`](https://adamrsophie.github.io/manimR/reference/TexTemplateLibrary.md)
  : Libraries of LaTeX templates
- [`tex_to_svg_file()`](https://adamrsophie.github.io/manimR/reference/tex_to_svg_file.md)
  : Compile LaTeX to SVG
- [`Typst()`](https://adamrsophie.github.io/manimR/reference/typst.md)
  [`MathTypst()`](https://adamrsophie.github.io/manimR/reference/typst.md)
  : Typst and MathTypst
- [`typst_to_svg_file()`](https://adamrsophie.github.io/manimR/reference/typst_to_svg_file.md)
  : Compile Typst to SVG
- [`Code()`](https://adamrsophie.github.io/manimR/reference/CodeClass.md)
  : Code
- [`DecimalNumber()`](https://adamrsophie.github.io/manimR/reference/DecimalNumberClass.md)
  [`Integer()`](https://adamrsophie.github.io/manimR/reference/DecimalNumberClass.md)
  [`Variable()`](https://adamrsophie.github.io/manimR/reference/DecimalNumberClass.md)
  : DecimalNumber, Integer and Variable
- [`Matrix()`](https://adamrsophie.github.io/manimR/reference/MatrixClass.md)
  [`DecimalMatrix()`](https://adamrsophie.github.io/manimR/reference/MatrixClass.md)
  [`IntegerMatrix()`](https://adamrsophie.github.io/manimR/reference/MatrixClass.md)
  [`MobjectMatrix()`](https://adamrsophie.github.io/manimR/reference/MatrixClass.md)
  : Matrix
- [`matrix_to_tex_string()`](https://adamrsophie.github.io/manimR/reference/matrix_to_tex_string.md)
  [`matrix_to_mobject()`](https://adamrsophie.github.io/manimR/reference/matrix_to_tex_string.md)
  : Matrix helpers
- [`get_det_text()`](https://adamrsophie.github.io/manimR/reference/get_det_text.md)
  : Determinant label
- [`Table()`](https://adamrsophie.github.io/manimR/reference/TableClass.md)
  [`MathTable()`](https://adamrsophie.github.io/manimR/reference/TableClass.md)
  [`MobjectTable()`](https://adamrsophie.github.io/manimR/reference/TableClass.md)
  [`IntegerTable()`](https://adamrsophie.github.io/manimR/reference/TableClass.md)
  [`DecimalTable()`](https://adamrsophie.github.io/manimR/reference/TableClass.md)
  : Table

## Graphing

- [`Axes()`](https://adamrsophie.github.io/manimR/reference/coordinate_systems.md)
  [`ThreeDAxes()`](https://adamrsophie.github.io/manimR/reference/coordinate_systems.md)
  [`NumberPlane()`](https://adamrsophie.github.io/manimR/reference/coordinate_systems.md)
  [`PolarPlane()`](https://adamrsophie.github.io/manimR/reference/coordinate_systems.md)
  [`ComplexPlane()`](https://adamrsophie.github.io/manimR/reference/coordinate_systems.md)
  [`CoordinateSystem()`](https://adamrsophie.github.io/manimR/reference/coordinate_systems.md)
  : Coordinate systems
- [`NumberLine()`](https://adamrsophie.github.io/manimR/reference/NumberLine.md)
  [`UnitInterval()`](https://adamrsophie.github.io/manimR/reference/NumberLine.md)
  : Number lines
- [`ParametricFunction()`](https://adamrsophie.github.io/manimR/reference/function_graphs.md)
  [`FunctionGraph()`](https://adamrsophie.github.io/manimR/reference/function_graphs.md)
  [`ImplicitFunction()`](https://adamrsophie.github.io/manimR/reference/function_graphs.md)
  : Function graphs
- [`LinearBase()`](https://adamrsophie.github.io/manimR/reference/graph_scale.md)
  [`LogBase()`](https://adamrsophie.github.io/manimR/reference/graph_scale.md)
  : Axis scalings
- [`SampleSpace()`](https://adamrsophie.github.io/manimR/reference/probability.md)
  [`` `[`( ``*`<SampleSpace>`*`)`](https://adamrsophie.github.io/manimR/reference/probability.md)
  [`BarChart()`](https://adamrsophie.github.io/manimR/reference/probability.md)
  : Sample spaces and bar charts
- [`Graph()`](https://adamrsophie.github.io/manimR/reference/GenericGraphClass.md)
  [`DiGraph()`](https://adamrsophie.github.io/manimR/reference/GenericGraphClass.md)
  : Graphs
- [`DEFAULT_SCALAR_FIELD_COLORS`](https://adamrsophie.github.io/manimR/reference/VectorFieldClass.md)
  [`VectorField()`](https://adamrsophie.github.io/manimR/reference/VectorFieldClass.md)
  [`vector_field_shift_func()`](https://adamrsophie.github.io/manimR/reference/VectorFieldClass.md)
  [`vector_field_scale_func()`](https://adamrsophie.github.io/manimR/reference/VectorFieldClass.md)
  [`ArrowVectorField()`](https://adamrsophie.github.io/manimR/reference/VectorFieldClass.md)
  [`StreamLines()`](https://adamrsophie.github.io/manimR/reference/VectorFieldClass.md)
  : Vector fields

## Three dimensions

- [`ThreeDVMobject()`](https://adamrsophie.github.io/manimR/reference/three_dimensions.md)
  [`Surface()`](https://adamrsophie.github.io/manimR/reference/three_dimensions.md)
  [`Sphere()`](https://adamrsophie.github.io/manimR/reference/three_dimensions.md)
  [`Dot3D()`](https://adamrsophie.github.io/manimR/reference/three_dimensions.md)
  [`Cube()`](https://adamrsophie.github.io/manimR/reference/three_dimensions.md)
  [`Prism()`](https://adamrsophie.github.io/manimR/reference/three_dimensions.md)
  [`Cone()`](https://adamrsophie.github.io/manimR/reference/three_dimensions.md)
  [`Cylinder()`](https://adamrsophie.github.io/manimR/reference/three_dimensions.md)
  [`Line3D()`](https://adamrsophie.github.io/manimR/reference/three_dimensions.md)
  [`Line3D_parallel_to()`](https://adamrsophie.github.io/manimR/reference/three_dimensions.md)
  [`Line3D_perpendicular_to()`](https://adamrsophie.github.io/manimR/reference/three_dimensions.md)
  [`Arrow3D()`](https://adamrsophie.github.io/manimR/reference/three_dimensions.md)
  [`Torus()`](https://adamrsophie.github.io/manimR/reference/three_dimensions.md)
  : Three dimensional mobjects
- [`Polyhedron()`](https://adamrsophie.github.io/manimR/reference/polyhedra.md)
  [`Tetrahedron()`](https://adamrsophie.github.io/manimR/reference/polyhedra.md)
  [`Octahedron()`](https://adamrsophie.github.io/manimR/reference/polyhedra.md)
  [`Icosahedron()`](https://adamrsophie.github.io/manimR/reference/polyhedra.md)
  [`Dodecahedron()`](https://adamrsophie.github.io/manimR/reference/polyhedra.md)
  [`ConvexHull3D()`](https://adamrsophie.github.io/manimR/reference/polyhedra.md)
  : Polyhedra
- [`get_3d_vmob_start_corner_index()`](https://adamrsophie.github.io/manimR/reference/get_3d_vmob_start_corner_index.md)
  [`get_3d_vmob_end_corner_index()`](https://adamrsophie.github.io/manimR/reference/get_3d_vmob_start_corner_index.md)
  [`get_3d_vmob_start_corner()`](https://adamrsophie.github.io/manimR/reference/get_3d_vmob_start_corner_index.md)
  [`get_3d_vmob_end_corner()`](https://adamrsophie.github.io/manimR/reference/get_3d_vmob_start_corner_index.md)
  [`get_3d_vmob_gradient_start_and_end_points()`](https://adamrsophie.github.io/manimR/reference/get_3d_vmob_start_corner_index.md)
  [`get_3d_vmob_unit_normal()`](https://adamrsophie.github.io/manimR/reference/get_3d_vmob_start_corner_index.md)
  [`get_3d_vmob_start_corner_unit_normal()`](https://adamrsophie.github.io/manimR/reference/get_3d_vmob_start_corner_index.md)
  [`get_3d_vmob_end_corner_unit_normal()`](https://adamrsophie.github.io/manimR/reference/get_3d_vmob_start_corner_index.md)
  : Corners and normals of 3D VMobjects
- [`get_shaded_rgb()`](https://adamrsophie.github.io/manimR/reference/get_shaded_rgb.md)
  : Shade a color by its orientation to a light

## Images, SVG and point clouds

- [`ImageMobject()`](https://adamrsophie.github.io/manimR/reference/image_mobject.md)
  [`ImageMobjectFromCamera()`](https://adamrsophie.github.io/manimR/reference/image_mobject.md)
  [`AbstractImageMobject()`](https://adamrsophie.github.io/manimR/reference/image_mobject.md)
  : Image mobjects
- [`SVGMobject()`](https://adamrsophie.github.io/manimR/reference/SVGMobjectClass.md)
  [`VMobjectFromSVGPath()`](https://adamrsophie.github.io/manimR/reference/SVGMobjectClass.md)
  : SVGMobject
- [`PMobject()`](https://adamrsophie.github.io/manimR/reference/point_cloud.md)
  [`Mobject1D()`](https://adamrsophie.github.io/manimR/reference/point_cloud.md)
  [`Mobject2D()`](https://adamrsophie.github.io/manimR/reference/point_cloud.md)
  [`PGroup()`](https://adamrsophie.github.io/manimR/reference/point_cloud.md)
  [`PointCloudDot()`](https://adamrsophie.github.io/manimR/reference/point_cloud.md)
  [`Point()`](https://adamrsophie.github.io/manimR/reference/point_cloud.md)
  : Point cloud mobjects
- [`OpenGLPMobject()`](https://adamrsophie.github.io/manimR/reference/opengl_point_cloud.md)
  [`OpenGLPGroup()`](https://adamrsophie.github.io/manimR/reference/opengl_point_cloud.md)
  [`OpenGLPMPoint()`](https://adamrsophie.github.io/manimR/reference/opengl_point_cloud.md)
  [`DotCloud()`](https://adamrsophie.github.io/manimR/reference/opengl_point_cloud.md)
  [`TrueDot()`](https://adamrsophie.github.io/manimR/reference/opengl_point_cloud.md)
  : OpenGL point clouds
- [`opengl_mobjects`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLMobject`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLGroup`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLPoint`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLVMobject`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLVGroup`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLVectorizedPoint`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLCurvesAsSubmobjects`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLDashedVMobject`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLTipableVMobject`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLArc`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLArcBetweenPoints`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLCurvedArrow`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLCurvedDoubleArrow`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLCircle`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLDot`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLEllipse`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLAnnularSector`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLSector`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLAnnulus`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLLine`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLDashedLine`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLTangentLine`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLElbow`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLArrow`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLVector`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLDoubleArrow`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLCubicBezier`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLPolygon`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLRegularPolygon`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLTriangle`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLArrowTip`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLImageMobject`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLSurface`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLSurfaceMesh`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLTexturedSurface`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLSurfaceGroup`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLRectangle`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLSquare`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLRoundedRectangle`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLRectangleClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLSquareClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLRoundedRectangleClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLSurfaceGroupClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLMobjectClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLGroupClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLPointClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLVMobjectClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLVGroupClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLVectorizedPointClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLCurvesAsSubmobjectsClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLDashedVMobjectClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLTipableVMobjectClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLArcClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLArcBetweenPointsClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLCurvedArrowClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLCurvedDoubleArrowClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLCircleClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLDotClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLEllipseClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLAnnularSectorClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLSectorClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLAnnulusClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLLineClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLDashedLineClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLTangentLineClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLElbowClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLArrowClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLVectorClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLDoubleArrowClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLCubicBezierClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLPolygonClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLRegularPolygonClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLTriangleClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLArrowTipClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLImageMobjectClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLSurfaceClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLSurfaceMeshClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  [`OpenGLTexturedSurfaceClass`](https://adamrsophie.github.io/manimR/reference/opengl_mobjects.md)
  : OpenGL mobject classes
- [`get_mobject_class()`](https://adamrsophie.github.io/manimR/reference/get_mobject_class.md)
  [`get_vectorized_mobject_class()`](https://adamrsophie.github.io/manimR/reference/get_mobject_class.md)
  [`get_point_mobject_class()`](https://adamrsophie.github.io/manimR/reference/get_mobject_class.md)
  : Base classes for the active renderer
- [`change_to_rgba_array()`](https://adamrsophie.github.io/manimR/reference/image_helpers.md)
  [`invert_image()`](https://adamrsophie.github.io/manimR/reference/image_helpers.md)
  [`drag_pixels()`](https://adamrsophie.github.io/manimR/reference/image_helpers.md)
  : Image array helpers

## Animations

- [`Animation()`](https://adamrsophie.github.io/manimR/reference/AnimationClass.md)
  : Animation
- [`Create()`](https://adamrsophie.github.io/manimR/reference/creation.md)
  [`Uncreate()`](https://adamrsophie.github.io/manimR/reference/creation.md)
  [`DrawBorderThenFill()`](https://adamrsophie.github.io/manimR/reference/creation.md)
  [`Write()`](https://adamrsophie.github.io/manimR/reference/creation.md)
  [`Unwrite()`](https://adamrsophie.github.io/manimR/reference/creation.md)
  [`SpiralIn()`](https://adamrsophie.github.io/manimR/reference/creation.md)
  [`ShowIncreasingSubsets()`](https://adamrsophie.github.io/manimR/reference/creation.md)
  [`AddTextLetterByLetter()`](https://adamrsophie.github.io/manimR/reference/creation.md)
  [`RemoveTextLetterByLetter()`](https://adamrsophie.github.io/manimR/reference/creation.md)
  [`ShowSubmobjectsOneByOne()`](https://adamrsophie.github.io/manimR/reference/creation.md)
  [`AddTextWordByWord()`](https://adamrsophie.github.io/manimR/reference/creation.md)
  [`TypeWithCursor()`](https://adamrsophie.github.io/manimR/reference/creation.md)
  [`UntypeWithCursor()`](https://adamrsophie.github.io/manimR/reference/creation.md)
  [`ShowPartial()`](https://adamrsophie.github.io/manimR/reference/creation.md)
  : Creation animations
- [`FadeIn()`](https://adamrsophie.github.io/manimR/reference/fading.md)
  [`FadeOut()`](https://adamrsophie.github.io/manimR/reference/fading.md)
  : Fading animations
- [`GrowFromPoint()`](https://adamrsophie.github.io/manimR/reference/growing.md)
  [`GrowFromCenter()`](https://adamrsophie.github.io/manimR/reference/growing.md)
  [`GrowFromEdge()`](https://adamrsophie.github.io/manimR/reference/growing.md)
  [`GrowArrow()`](https://adamrsophie.github.io/manimR/reference/growing.md)
  [`SpinInFromNothing()`](https://adamrsophie.github.io/manimR/reference/growing.md)
  : Growing animations
- [`FocusOn()`](https://adamrsophie.github.io/manimR/reference/indication.md)
  [`Indicate()`](https://adamrsophie.github.io/manimR/reference/indication.md)
  [`ShowPassingFlash()`](https://adamrsophie.github.io/manimR/reference/indication.md)
  [`Flash()`](https://adamrsophie.github.io/manimR/reference/indication.md)
  [`ShowPassingFlashWithThinningStrokeWidth()`](https://adamrsophie.github.io/manimR/reference/indication.md)
  [`ApplyWave()`](https://adamrsophie.github.io/manimR/reference/indication.md)
  [`Wiggle()`](https://adamrsophie.github.io/manimR/reference/indication.md)
  [`Circumscribe()`](https://adamrsophie.github.io/manimR/reference/indication.md)
  [`Blink()`](https://adamrsophie.github.io/manimR/reference/indication.md)
  : Indication animations
- [`Homotopy()`](https://adamrsophie.github.io/manimR/reference/movement.md)
  [`SmoothedVectorizedHomotopy()`](https://adamrsophie.github.io/manimR/reference/movement.md)
  [`ComplexHomotopy()`](https://adamrsophie.github.io/manimR/reference/movement.md)
  [`PhaseFlow()`](https://adamrsophie.github.io/manimR/reference/movement.md)
  [`MoveAlongPath()`](https://adamrsophie.github.io/manimR/reference/movement.md)
  : Movement animations
- [`Rotating()`](https://adamrsophie.github.io/manimR/reference/rotation.md)
  [`Rotate()`](https://adamrsophie.github.io/manimR/reference/rotation.md)
  : Rotation animations
- [`Transform()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`ReplacementTransform()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`TransformFromCopy()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`ClockwiseTransform()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`CounterclockwiseTransform()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`MoveToTarget()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`ApplyMethod()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`ApplyPointwiseFunction()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`ApplyPointwiseFunctionToCenter()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`FadeToColor()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`ScaleInPlace()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`ShrinkToCenter()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`Restore()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`ApplyFunction()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`ApplyMatrix()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`ApplyComplexFunction()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`CyclicReplace()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`Swap()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`FadeTransform()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`FadeTransformPieces()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  [`TransformAnimations()`](https://adamrsophie.github.io/manimR/reference/transform.md)
  : Transform animations
- [`TransformMatchingShapes()`](https://adamrsophie.github.io/manimR/reference/transform_matching.md)
  [`TransformMatchingTex()`](https://adamrsophie.github.io/manimR/reference/transform_matching.md)
  : Transform matching parts
- [`AnimationGroup()`](https://adamrsophie.github.io/manimR/reference/composition.md)
  [`Succession()`](https://adamrsophie.github.io/manimR/reference/composition.md)
  [`LaggedStart()`](https://adamrsophie.github.io/manimR/reference/composition.md)
  [`LaggedStartMap()`](https://adamrsophie.github.io/manimR/reference/composition.md)
  : Composing animations
- [`ChangingDecimal()`](https://adamrsophie.github.io/manimR/reference/number_animations.md)
  [`ChangeDecimalToValue()`](https://adamrsophie.github.io/manimR/reference/number_animations.md)
  : Number animations
- [`UpdateFromFunc()`](https://adamrsophie.github.io/manimR/reference/update_animations.md)
  [`UpdateFromAlphaFunc()`](https://adamrsophie.github.io/manimR/reference/update_animations.md)
  [`MaintainPositionRelativeTo()`](https://adamrsophie.github.io/manimR/reference/update_animations.md)
  : Updater animations
- [`AnimatedBoundary()`](https://adamrsophie.github.io/manimR/reference/AnimatedBoundaryClass.md)
  [`TracedPath()`](https://adamrsophie.github.io/manimR/reference/AnimatedBoundaryClass.md)
  : AnimatedBoundary and TracedPath
- [`ChangeSpeed()`](https://adamrsophie.github.io/manimR/reference/ChangeSpeedClass.md)
  : ChangeSpeed
- [`change_speed_add_updater()`](https://adamrsophie.github.io/manimR/reference/change_speed_add_updater.md)
  : Updaters that follow ChangeSpeed
- [`Wait()`](https://adamrsophie.github.io/manimR/reference/WaitClass.md)
  : Wait
- [`Add()`](https://adamrsophie.github.io/manimR/reference/Add.md) : Add
- [`Broadcast()`](https://adamrsophie.github.io/manimR/reference/Broadcast.md)
  : Broadcast
- [`prepare_animation()`](https://adamrsophie.github.io/manimR/reference/prepare_animation.md)
  : Convert to an animation
- [`override_animation()`](https://adamrsophie.github.io/manimR/reference/override_animation.md)
  [`override_animate()`](https://adamrsophie.github.io/manimR/reference/override_animation.md)
  : Override animations for a mobject class

## Updaters and value trackers

- [`ValueTracker()`](https://adamrsophie.github.io/manimR/reference/ValueTrackerClass.md)
  [`ComplexValueTracker()`](https://adamrsophie.github.io/manimR/reference/ValueTrackerClass.md)
  : Value trackers
- [`always_redraw()`](https://adamrsophie.github.io/manimR/reference/updater_helpers.md)
  [`always()`](https://adamrsophie.github.io/manimR/reference/updater_helpers.md)
  [`f_always()`](https://adamrsophie.github.io/manimR/reference/updater_helpers.md)
  [`always_shift()`](https://adamrsophie.github.io/manimR/reference/updater_helpers.md)
  [`always_rotate()`](https://adamrsophie.github.io/manimR/reference/updater_helpers.md)
  [`turn_animation_into_updater()`](https://adamrsophie.github.io/manimR/reference/updater_helpers.md)
  [`cycle_animation()`](https://adamrsophie.github.io/manimR/reference/updater_helpers.md)
  : Updater helpers

## Rate functions and paths

- [`linear()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`smooth_rate()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`smoothstep()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`smootherstep()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`smoothererstep()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`rush_into()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`rush_from()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`slow_into()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`double_smooth()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`there_and_back()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`there_and_back_with_pause()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`running_start()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`not_quite_there()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`wiggle()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`squish_rate_func()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`lingering()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`exponential_decay()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_sine()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_out_sine()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_out_sine()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_quad()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_out_quad()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_out_quad()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_cubic()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_out_cubic()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_out_cubic()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_quart()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_out_quart()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_out_quart()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_quint()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_out_quint()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_out_quint()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_expo()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_out_expo()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_out_expo()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_circ()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_out_circ()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_out_circ()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_back()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_out_back()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_out_back()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_elastic()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_out_elastic()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_out_elastic()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_out_bounce()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_bounce()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  [`ease_in_out_bounce()`](https://adamrsophie.github.io/manimR/reference/rate_funcs.md)
  : Rate functions
- [`unit_interval()`](https://adamrsophie.github.io/manimR/reference/unit_interval.md)
  [`zero()`](https://adamrsophie.github.io/manimR/reference/unit_interval.md)
  : Rate function decorators
- [`straight_path()`](https://adamrsophie.github.io/manimR/reference/paths.md)
  [`path_along_arc()`](https://adamrsophie.github.io/manimR/reference/paths.md)
  [`path_along_circles()`](https://adamrsophie.github.io/manimR/reference/paths.md)
  [`clockwise_path()`](https://adamrsophie.github.io/manimR/reference/paths.md)
  [`counterclockwise_path()`](https://adamrsophie.github.io/manimR/reference/paths.md)
  [`spiral_path()`](https://adamrsophie.github.io/manimR/reference/paths.md)
  : Path functions

## Cameras

- [`Camera()`](https://adamrsophie.github.io/manimR/reference/CameraClass.md)
  : Camera
- [`MovingCamera()`](https://adamrsophie.github.io/manimR/reference/MovingCameraClass.md)
  : MovingCamera
- [`MultiCamera()`](https://adamrsophie.github.io/manimR/reference/MultiCameraClass.md)
  : MultiCamera
- [`MappingCamera()`](https://adamrsophie.github.io/manimR/reference/MappingCameraClass.md)
  [`OldMultiCamera()`](https://adamrsophie.github.io/manimR/reference/MappingCameraClass.md)
  [`SplitScreenCamera()`](https://adamrsophie.github.io/manimR/reference/MappingCameraClass.md)
  : MappingCamera, OldMultiCamera and SplitScreenCamera
- [`ThreeDCamera()`](https://adamrsophie.github.io/manimR/reference/ThreeDCameraClass.md)
  : ThreeDCamera
- [`BackgroundColoredVMobjectDisplayer()`](https://adamrsophie.github.io/manimR/reference/BackgroundColoredVMobjectDisplayer.md)
  : Display vectorized mobjects colored by a background image

## Colors

- [`WHITE`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GRAY_A`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GREY_A`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GRAY_B`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GREY_B`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GRAY_C`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GREY_C`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GRAY_D`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GREY_D`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GRAY_E`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GREY_E`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`BLACK`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`LIGHTER_GRAY`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`LIGHTER_GREY`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`LIGHT_GRAY`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`LIGHT_GREY`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GRAY`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GREY`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`DARK_GRAY`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`DARK_GREY`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`DARKER_GRAY`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`DARKER_GREY`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`PURE_RED`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`PURE_GREEN`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`PURE_BLUE`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`PURE_CYAN`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`PURE_MAGENTA`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`PURE_YELLOW`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`BLUE_A`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`BLUE_B`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`BLUE_C`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`BLUE_D`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`BLUE_E`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`BLUE`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`DARK_BLUE`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`TEAL_A`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`TEAL_B`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`TEAL_C`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`TEAL_D`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`TEAL_E`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`TEAL`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GREEN_A`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GREEN_B`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GREEN_C`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GREEN_D`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GREEN_E`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GREEN`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`YELLOW_A`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`YELLOW_B`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`YELLOW_C`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`YELLOW_D`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`YELLOW_E`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`YELLOW`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GOLD_A`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GOLD_B`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GOLD_C`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GOLD_D`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GOLD_E`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GOLD`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`RED_A`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`RED_B`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`RED_C`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`RED_D`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`RED_E`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`RED`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`MAROON_A`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`MAROON_B`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`MAROON_C`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`MAROON_D`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`MAROON_E`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`MAROON`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`PURPLE_A`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`PURPLE_B`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`PURPLE_C`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`PURPLE_D`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`PURPLE_E`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`PURPLE`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`PINK`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`LIGHT_PINK`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`ORANGE`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`LIGHT_BROWN`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`DARK_BROWN`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GRAY_BROWN`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`GREY_BROWN`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`LOGO_WHITE`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`LOGO_GREEN`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`LOGO_BLUE`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`LOGO_RED`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  [`LOGO_BLACK`](https://adamrsophie.github.io/manimR/reference/manim_colors.md)
  : Manim color constants
- [`X11_COLORS`](https://adamrsophie.github.io/manimR/reference/color_palettes.md)
  [`XKCD`](https://adamrsophie.github.io/manimR/reference/color_palettes.md)
  [`SVGNAMES`](https://adamrsophie.github.io/manimR/reference/color_palettes.md)
  [`DVIPSNAMES`](https://adamrsophie.github.io/manimR/reference/color_palettes.md)
  [`AS2700`](https://adamrsophie.github.io/manimR/reference/color_palettes.md)
  [`BS381`](https://adamrsophie.github.io/manimR/reference/color_palettes.md)
  : Named color palettes
- [`ManimColor()`](https://adamrsophie.github.io/manimR/reference/ManimColor.md)
  [`RGBA()`](https://adamrsophie.github.io/manimR/reference/ManimColor.md)
  [`HSV()`](https://adamrsophie.github.io/manimR/reference/ManimColor.md)
  [`ManimColorDType`](https://adamrsophie.github.io/manimR/reference/ManimColor.md)
  [`ManimColorClass`](https://adamrsophie.github.io/manimR/reference/ManimColor.md)
  [`HSVClass`](https://adamrsophie.github.io/manimR/reference/ManimColor.md)
  [`` `$`( ``*`<ManimColor>`*`)`](https://adamrsophie.github.io/manimR/reference/ManimColor.md)
  [`` `$<-`( ``*`<ManimColor>`*`)`](https://adamrsophie.github.io/manimR/reference/ManimColor.md)
  [`Ops(`*`<ManimColor>`*`)`](https://adamrsophie.github.io/manimR/reference/ManimColor.md)
  [`as.integer(`*`<ManimColor>`*`)`](https://adamrsophie.github.io/manimR/reference/ManimColor.md)
  [`as.character(`*`<ManimColor>`*`)`](https://adamrsophie.github.io/manimR/reference/ManimColor.md)
  [`print(`*`<ManimColor>`*`)`](https://adamrsophie.github.io/manimR/reference/ManimColor.md)
  [`format(`*`<ManimColor>`*`)`](https://adamrsophie.github.io/manimR/reference/ManimColor.md)
  : Colors as objects
- [`manim_color()`](https://adamrsophie.github.io/manimR/reference/manim_color.md)
  [`color_to_rgb()`](https://adamrsophie.github.io/manimR/reference/manim_color.md)
  [`color_to_rgba()`](https://adamrsophie.github.io/manimR/reference/manim_color.md)
  [`rgb_to_color()`](https://adamrsophie.github.io/manimR/reference/manim_color.md)
  [`rgba_to_color()`](https://adamrsophie.github.io/manimR/reference/manim_color.md)
  : Parse a color
- [`color_to_int_rgb()`](https://adamrsophie.github.io/manimR/reference/color_conversions.md)
  [`color_to_int_rgba()`](https://adamrsophie.github.io/manimR/reference/color_conversions.md)
  [`rgb_to_hex()`](https://adamrsophie.github.io/manimR/reference/color_conversions.md)
  [`hex_to_rgb()`](https://adamrsophie.github.io/manimR/reference/color_conversions.md)
  [`color_to_hsv()`](https://adamrsophie.github.io/manimR/reference/color_conversions.md)
  [`color_from_hsv()`](https://adamrsophie.github.io/manimR/reference/color_conversions.md)
  : More color conversions
- [`interpolate_color()`](https://adamrsophie.github.io/manimR/reference/interpolate_color.md)
  [`color_gradient()`](https://adamrsophie.github.io/manimR/reference/interpolate_color.md)
  [`average_color()`](https://adamrsophie.github.io/manimR/reference/interpolate_color.md)
  [`invert_color()`](https://adamrsophie.github.io/manimR/reference/interpolate_color.md)
  [`lighter_color()`](https://adamrsophie.github.io/manimR/reference/interpolate_color.md)
  [`darker_color()`](https://adamrsophie.github.io/manimR/reference/interpolate_color.md)
  [`random_color()`](https://adamrsophie.github.io/manimR/reference/interpolate_color.md)
  [`random_bright_color()`](https://adamrsophie.github.io/manimR/reference/interpolate_color.md)
  : Color arithmetic
- [`RandomColorGenerator()`](https://adamrsophie.github.io/manimR/reference/RandomColorGenerator.md)
  : Random colors from a seed

## Constants and units

- [`ORIGIN`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`UP`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`DOWN`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`RIGHT`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`LEFT`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`IN`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`OUT`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`X_AXIS`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`Y_AXIS`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`Z_AXIS`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`UL`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`UR`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`DL`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`DR`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`PI`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`TAU`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`DEGREES`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`SMALL_BUFF`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`MED_SMALL_BUFF`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`MED_LARGE_BUFF`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`LARGE_BUFF`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`DEFAULT_MOBJECT_TO_EDGE_BUFFER`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`DEFAULT_MOBJECT_TO_MOBJECT_BUFFER`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`DEFAULT_STROKE_WIDTH`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`DEFAULT_FONT_SIZE`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`DEFAULT_DOT_RADIUS`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`DEFAULT_SMALL_DOT_RADIUS`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`DEFAULT_DASH_LENGTH`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`DEFAULT_ARROW_TIP_LENGTH`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`DEFAULT_WAIT_TIME`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`DEFAULT_POINTWISE_FUNCTION_RUN_TIME`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`SCALE_FACTOR_PER_FONT_POINT`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`DEFAULT_POINT_DENSITY_1D`](https://adamrsophie.github.io/manimR/reference/constants.md)
  [`DEFAULT_POINT_DENSITY_2D`](https://adamrsophie.github.io/manimR/reference/constants.md)
  : Direction vectors and numeric constants
- [`Pixels`](https://adamrsophie.github.io/manimR/reference/units.md)
  [`Percent()`](https://adamrsophie.github.io/manimR/reference/units.md)
  [`Degrees`](https://adamrsophie.github.io/manimR/reference/units.md)
  [`Munits`](https://adamrsophie.github.io/manimR/reference/units.md) :
  Units
- [`SCENE_NOT_FOUND_MESSAGE`](https://adamrsophie.github.io/manimR/reference/interface_constants.md)
  [`CHOOSE_NUMBER_MESSAGE`](https://adamrsophie.github.io/manimR/reference/interface_constants.md)
  [`INVALID_NUMBER_MESSAGE`](https://adamrsophie.github.io/manimR/reference/interface_constants.md)
  [`NO_SCENE_MESSAGE`](https://adamrsophie.github.io/manimR/reference/interface_constants.md)
  [`EPILOG`](https://adamrsophie.github.io/manimR/reference/interface_constants.md)
  [`CONTEXT_SETTINGS`](https://adamrsophie.github.io/manimR/reference/interface_constants.md)
  [`SHIFT_VALUE`](https://adamrsophie.github.io/manimR/reference/interface_constants.md)
  [`CTRL_VALUE`](https://adamrsophie.github.io/manimR/reference/interface_constants.md)
  [`START_X`](https://adamrsophie.github.io/manimR/reference/interface_constants.md)
  [`START_Y`](https://adamrsophie.github.io/manimR/reference/interface_constants.md)
  [`RendererType`](https://adamrsophie.github.io/manimR/reference/interface_constants.md)
  : Interface constants
- [`rate_functions`](https://adamrsophie.github.io/manimR/reference/upstream_modules.md)
  [`color`](https://adamrsophie.github.io/manimR/reference/upstream_modules.md)
  : Upstream module objects

## Math utilities

- [`get_norm()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`normalize()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`cross()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`rotation_matrix()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`rotation_matrix_transpose()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`rotation_matrix_transpose_from_quaternion()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`rotation_matrix_from_quaternion()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`norm_squared()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`normalize_along_axis()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`rotation_about_z()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`rotate_vector()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`angle_of_vector()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`angle_between_vectors()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`z_to_vector()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`compass_directions()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`regular_vertices()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`complex_to_R3()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`R3_to_complex()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`midpoint()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`line_intersection()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`find_intersection()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`shoelace()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`shoelace_direction()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`cartesian_to_spherical()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`spherical_to_cartesian()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`get_winding_number()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`get_unit_normal()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`center_of_mass()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`complex_func_to_R3_func()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`cross2d()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`perpendicular_bisector()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  [`thick_diagonal()`](https://adamrsophie.github.io/manimR/reference/space_ops.md)
  : Space operations
- [`bezier()`](https://adamrsophie.github.io/manimR/reference/bezier.md)
  : Evaluate a Bezier curve
- [`partial_bezier_points()`](https://adamrsophie.github.io/manimR/reference/partial_bezier_points.md)
  [`split_bezier()`](https://adamrsophie.github.io/manimR/reference/partial_bezier_points.md)
  [`subdivide_bezier()`](https://adamrsophie.github.io/manimR/reference/partial_bezier_points.md)
  [`bezier_remap()`](https://adamrsophie.github.io/manimR/reference/partial_bezier_points.md)
  : Split, trim and remap Bezier curves
- [`proportions_along_bezier_curve_for_point()`](https://adamrsophie.github.io/manimR/reference/proportions_along_bezier_curve_for_point.md)
  [`point_lies_on_bezier()`](https://adamrsophie.github.io/manimR/reference/proportions_along_bezier_curve_for_point.md)
  : Does a point lie on a Bezier curve?
- [`get_smooth_cubic_bezier_handle_points()`](https://adamrsophie.github.io/manimR/reference/get_smooth_cubic_bezier_handle_points.md)
  [`get_smooth_closed_cubic_bezier_handle_points()`](https://adamrsophie.github.io/manimR/reference/get_smooth_cubic_bezier_handle_points.md)
  [`get_smooth_open_cubic_bezier_handle_points()`](https://adamrsophie.github.io/manimR/reference/get_smooth_cubic_bezier_handle_points.md)
  : Smooth cubic Bezier handles
- [`get_quadratic_approximation_of_cubic()`](https://adamrsophie.github.io/manimR/reference/get_quadratic_approximation_of_cubic.md)
  : Quadratic approximation of cubic Bezier curves
- [`matrix_to_shader_input()`](https://adamrsophie.github.io/manimR/reference/opengl_matrices.md)
  [`orthographic_projection_matrix()`](https://adamrsophie.github.io/manimR/reference/opengl_matrices.md)
  [`perspective_projection_matrix()`](https://adamrsophie.github.io/manimR/reference/opengl_matrices.md)
  [`translation_matrix()`](https://adamrsophie.github.io/manimR/reference/opengl_matrices.md)
  [`x_rotation_matrix()`](https://adamrsophie.github.io/manimR/reference/opengl_matrices.md)
  [`y_rotation_matrix()`](https://adamrsophie.github.io/manimR/reference/opengl_matrices.md)
  [`z_rotation_matrix()`](https://adamrsophie.github.io/manimR/reference/opengl_matrices.md)
  [`opengl_rotation_matrix()`](https://adamrsophie.github.io/manimR/reference/opengl_matrices.md)
  [`rotate_in_place_matrix()`](https://adamrsophie.github.io/manimR/reference/opengl_matrices.md)
  [`scale_matrix()`](https://adamrsophie.github.io/manimR/reference/opengl_matrices.md)
  [`view_matrix()`](https://adamrsophie.github.io/manimR/reference/opengl_matrices.md)
  : Projection, view and transformation matrices
- [`is_closed()`](https://adamrsophie.github.io/manimR/reference/is_closed.md)
  : Is a spline closed?
- [`interpolate()`](https://adamrsophie.github.io/manimR/reference/interpolate.md)
  [`inverse_interpolate()`](https://adamrsophie.github.io/manimR/reference/interpolate.md)
  [`match_interpolate()`](https://adamrsophie.github.io/manimR/reference/interpolate.md)
  [`integer_interpolate()`](https://adamrsophie.github.io/manimR/reference/interpolate.md)
  [`mid()`](https://adamrsophie.github.io/manimR/reference/interpolate.md)
  : Interpolation helpers
- [`binary_search()`](https://adamrsophie.github.io/manimR/reference/sigmoid.md)
  [`sigmoid()`](https://adamrsophie.github.io/manimR/reference/sigmoid.md)
  : Numerical helpers
- [`quaternion_mult()`](https://adamrsophie.github.io/manimR/reference/quaternion_mult.md)
  [`quaternion_from_angle_axis()`](https://adamrsophie.github.io/manimR/reference/quaternion_mult.md)
  [`angle_axis_from_quaternion()`](https://adamrsophie.github.io/manimR/reference/quaternion_mult.md)
  [`quaternion_conjugate()`](https://adamrsophie.github.io/manimR/reference/quaternion_mult.md)
  : Quaternions
- [`earclip_triangulation()`](https://adamrsophie.github.io/manimR/reference/earclip_triangulation.md)
  : Triangulate a polygon with holes
- [`polylabel()`](https://adamrsophie.github.io/manimR/reference/polylabel.md)
  : Pole of inaccessibility
- [`clip_value()`](https://adamrsophie.github.io/manimR/reference/clip_value.md)
  : Clip a value to a range

## Programming utilities

- [`extract_mobject_family_members()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`stretch_array_to_length()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`adjacent_n_tuples()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`adjacent_pairs()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`all_elements_are_instances()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`concatenate_lists()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`list_difference_update()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`list_update()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`listify()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`tuplify()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`make_even()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`make_even_by_cycling()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`remove_list_redundancies()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`remove_nones()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`resize_array()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`resize_preserving_order()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`resize_with_interpolation()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`batch_by_property()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`uniq_chain()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`flatten_iterable_parameters()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`restructure_list_to_exclude_certain_family_members()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  [`hash_obj()`](https://adamrsophie.github.io/manimR/reference/list_helpers.md)
  : List helpers
- [`merge_dicts_recursively()`](https://adamrsophie.github.io/manimR/reference/dict_helpers.md)
  [`update_dict_recursively()`](https://adamrsophie.github.io/manimR/reference/dict_helpers.md)
  [`DictAsObject()`](https://adamrsophie.github.io/manimR/reference/dict_helpers.md)
  : Dictionary helpers
- [`add_extension_if_not_present()`](https://adamrsophie.github.io/manimR/reference/path_helpers.md)
  [`guarantee_existence()`](https://adamrsophie.github.io/manimR/reference/path_helpers.md)
  [`guarantee_empty_existence()`](https://adamrsophie.github.io/manimR/reference/path_helpers.md)
  [`seek_full_path_from_defaults()`](https://adamrsophie.github.io/manimR/reference/path_helpers.md)
  [`get_full_raster_image_path()`](https://adamrsophie.github.io/manimR/reference/path_helpers.md)
  [`get_full_vector_image_path()`](https://adamrsophie.github.io/manimR/reference/path_helpers.md)
  [`add_version_before_extension()`](https://adamrsophie.github.io/manimR/reference/path_helpers.md)
  [`convert_audio()`](https://adamrsophie.github.io/manimR/reference/path_helpers.md)
  [`get_full_sound_file_path()`](https://adamrsophie.github.io/manimR/reference/path_helpers.md)
  [`modify_atime()`](https://adamrsophie.github.io/manimR/reference/path_helpers.md)
  [`open_file()`](https://adamrsophie.github.io/manimR/reference/path_helpers.md)
  [`ensure_executable()`](https://adamrsophie.github.io/manimR/reference/path_helpers.md)
  : Path and file helpers
- [`capture()`](https://adamrsophie.github.io/manimR/reference/command_helpers.md)
  [`get_dir_layout()`](https://adamrsophie.github.io/manimR/reference/command_helpers.md)
  [`get_video_metadata()`](https://adamrsophie.github.io/manimR/reference/command_helpers.md)
  : Run commands and inspect outputs
- [`assert_is_mobject_method()`](https://adamrsophie.github.io/manimR/reference/assert_is_mobject_method.md)
  : Check that a function is a mobject method
- [`get_plugins()`](https://adamrsophie.github.io/manimR/reference/get_plugins.md)
  [`list_plugins()`](https://adamrsophie.github.io/manimR/reference/get_plugins.md)
  : Plugins

## RStudio, knitr, Shiny and testing

- [`addin_render_scene()`](https://adamrsophie.github.io/manimR/reference/rstudio_addins.md)
  [`addin_render_background()`](https://adamrsophie.github.io/manimR/reference/rstudio_addins.md)
  [`addin_render_all()`](https://adamrsophie.github.io/manimR/reference/rstudio_addins.md)
  [`addin_last_frame()`](https://adamrsophie.github.io/manimR/reference/rstudio_addins.md)
  [`addin_insert_template()`](https://adamrsophie.github.io/manimR/reference/rstudio_addins.md)
  [`manim_gadget()`](https://adamrsophie.github.io/manimR/reference/rstudio_addins.md)
  : RStudio addins
- [`knitr_manim_engine()`](https://adamrsophie.github.io/manimR/reference/knitr_manim_engine.md)
  : knitr engine for manimR scenes
- [`manimOutput()`](https://adamrsophie.github.io/manimR/reference/manimOutput.md)
  [`renderManim()`](https://adamrsophie.github.io/manimR/reference/manimOutput.md)
  : Show scenes in Shiny apps
- [`scene_frame()`](https://adamrsophie.github.io/manimR/reference/scene_frame.md)
  [`expect_snapshot_frame()`](https://adamrsophie.github.io/manimR/reference/scene_frame.md)
  : Render one frame of a scene
