# Constructors of upstream classes that are mostly used as base classes or
# options, so that Mobject(), Camera() or tip_shape = ArrowSquareTip work as
# in upstream code.

#' @rdname MobjectClass
#' @export
Mobject <- constructor(MobjectClass)

#' @rdname CameraClass
#' @export
Camera <- constructor(CameraClass)

#' @rdname geometry
#' @export
TipableVMobject <- constructor(TipableVMobjectClass)

#' @rdname geometry
#' @export
ArrowTip <- constructor(ArrowTipClass)

#' @rdname geometry
#' @export
ArrowTriangleTip <- constructor(ArrowTriangleTipClass)

#' @rdname geometry
#' @export
ArrowTriangleFilledTip <- constructor(ArrowTriangleFilledTipClass)

#' @rdname geometry
#' @export
ArrowCircleTip <- constructor(ArrowCircleTipClass)

#' @rdname geometry
#' @export
ArrowCircleFilledTip <- constructor(ArrowCircleFilledTipClass)

#' @rdname geometry
#' @export
ArrowSquareTip <- constructor(ArrowSquareTipClass)

#' @rdname geometry
#' @export
ArrowSquareFilledTip <- constructor(ArrowSquareFilledTipClass)

#' @rdname geometry
#' @export
StealthTip <- constructor(StealthTipClass)

#' @rdname MappingCameraClass
#' @export
MappingCamera <- constructor(MappingCameraClass)

#' @rdname MappingCameraClass
#' @export
OldMultiCamera <- constructor(OldMultiCameraClass)

#' @rdname MappingCameraClass
#' @export
SplitScreenCamera <- constructor(SplitScreenCameraClass)

#' @rdname image_mobject
#' @export
AbstractImageMobject <- constructor(AbstractImageMobjectClass)

#' @rdname coordinate_systems
#' @export
CoordinateSystem <- constructor(CoordinateSystemClass)

#' @rdname creation
#' @export
ShowPartial <- constructor(ShowPartialClass)
