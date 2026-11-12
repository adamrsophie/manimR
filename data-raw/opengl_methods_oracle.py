# Reference values from Python manim 0.22.1 for the methods of the OpenGL
# mobject classes, read by tests/testthat/test-opengl-methods.R.
# Run from documentation/manim:
#   PYTHONPATH=. python ../../data-raw/opengl_methods_oracle.py ../../tests/testthat/fixtures/opengl_methods_oracle.json
import json, sys, tempfile
from pathlib import Path
import numpy as np
from PIL import Image
from manim import BLUE, DOWN, LEFT, ORIGIN, RIGHT, UP, WHITE, PI
from manim.mobject.opengl.opengl_geometry import (
    OpenGLAnnularSector, OpenGLAnnulus, OpenGLArc, OpenGLArcBetweenPoints, OpenGLArrow, OpenGLArrowTip,
    OpenGLCircle, OpenGLCurvedArrow, OpenGLCurvedDoubleArrow, OpenGLCubicBezier, OpenGLDashedLine, OpenGLDot, OpenGLDoubleArrow, OpenGLEllipse, OpenGLLine,
    OpenGLRectangle, OpenGLRegularPolygon, OpenGLSector, OpenGLSquare, OpenGLVector,
)
from manim.mobject.opengl.opengl_vectorized_mobject import OpenGLDashedVMobject
from manim.mobject.opengl.opengl_mobject import OpenGLPoint
from manim.mobject.opengl.opengl_surface import OpenGLSurface, OpenGLTexturedSurface
from manim.mobject.opengl.opengl_vectorized_mobject import OpenGLVMobject
from manim.renderer.shader_wrapper import get_colormap_code, get_shader_code_from_file

out = {}
tip = OpenGLArrowTip()
out["arrow_tip"] = {"base": tip.get_base().tolist(), "tip_point": tip.get_tip_point().tolist(),
                    "length": tip.get_length(), "angle": tip.get_angle(),
                    "length_width_1": OpenGLArrowTip(width=1, length=2).get_length()}
out["arc_quadratic_points"] = OpenGLArc.create_quadratic_bezier_points(PI / 2, 0, 2).tolist()

s = OpenGLSurface(lambda u, v: np.array([u, v, u * v]), u_range=(-1, 1), v_range=(-1, 1), resolution=(3, 3))
d = s.get_shader_data()
out["surface"] = {"triangle_indices": s.get_triangle_indices().tolist(),
                  "point": d["point"][:4].tolist(), "du_point": d["du_point"][:4].tolist()}
# A 2 by 2 image file; upstream fails on an array here (get_full_raster_image_path).
img = str(Path(tempfile.mkdtemp()) / "img.png")
Image.fromarray(np.array([[[255, 0, 0], [0, 255, 0]], [[0, 0, 255], [255, 255, 255]]], dtype=np.uint8)).save(img)
out["textured_im_coords"] = OpenGLTexturedSurface(s, img).get_shader_data()["im_coords"][:3].tolist()

out["shader_code_lengths"] = [len(get_shader_code_from_file(Path("surface/vert.glsl"))),
                              len(get_shader_code_from_file(Path("quadratic_bezier_fill/frag.glsl")))]
out["colormap_code"] = get_colormap_code([(1, 0, 0), (0, 0.5, 1)])

v = OpenGLVMobject()
v.set_anchors_and_handles(np.array([[0, 0, 0]]), np.array([[1, 1, 0]]), np.array([[2, 0, 0]]))
out["quadratic_at_half"] = v.point_from_proportion(0.5).tolist()

c = OpenGLCircle().surround(OpenGLSquare(side_length=2), buff=0.5)
out["circle_surround"] = [c.width, c.height]
dl = OpenGLDashedLine(LEFT, RIGHT, dash_length=0.1, dashed_ratio=0.5)
out["num_dashes"] = [dl.calculate_num_dashes(0.5), OpenGLDashedLine(ORIGIN, 0.1 * RIGHT).calculate_num_dashes(0.5)]

s2 = OpenGLSurface(lambda u, v: np.array([u, v, 0]), u_range=(0, 1), v_range=(0, 1), resolution=(5, 5))
# The textured surface keeps its own resolution (default 101 by 101); match the surface.
ts = OpenGLTexturedSurface(s2, img, resolution=(5, 5))
tp = ts.copy()
tp.pointwise_become_partial(ts, 0, 0.5)
out["textured_partial_im_coords"] = tp.im_coords[:6].tolist()

# Lines apply buff twice; arrows are filled shapes of quadratic pieces.
lines = {"buff": OpenGLLine(2 * LEFT, 2 * RIGHT, buff=0.5),
         "arc": OpenGLLine(LEFT, RIGHT, path_arc=PI / 3),
         "dashed_buff": OpenGLDashedLine(2 * LEFT, 2 * RIGHT, buff=0.5)}
out["lines"] = {k: {"start": m.get_start().tolist(), "end": m.get_end().tolist(), "n_points": len(m.points)}
                for k, m in lines.items()}
out["lines"]["arc"]["points"] = lines["arc"].points.tolist()
scaled = OpenGLArrow()
scaled.scale(2)
thick = OpenGLArrow()
thick.set_thickness(0.2)
arrows = {"default": OpenGLArrow(), "thick_tilted": OpenGLArrow(LEFT, 2 * UP + RIGHT, thickness=0.1),
          "short": OpenGLArrow(ORIGIN, 0.2 * RIGHT), "arc": OpenGLArrow(ORIGIN, RIGHT, path_arc=PI / 2),
          "negative_arc": OpenGLArrow(ORIGIN, RIGHT, path_arc=-PI / 3), "space": OpenGLArrow(ORIGIN, np.array([1, 1, 1])),
          "vector": OpenGLVector([1, 2]), "scaled": scaled, "thick": thick}
out["arrows"] = {k: {"points": m.points.tolist(), "start": m.get_start().tolist(), "end": m.get_end().tolist()}
                 for k, m in arrows.items()}
d = OpenGLDoubleArrow(LEFT, RIGHT)
out["double_arrow"] = {"points": d.points.tolist(), "start_tip": d.start_tip.points.tolist(), "n_sub": len(d.submobjects)}

# Constructors whose arguments differ from the Cairo classes, and arcs of
# quadratic pieces.
shapes = {"arc": OpenGLArc(0, PI), "arc_args": OpenGLArc(PI / 4, PI / 2, 2, 4, RIGHT),
          "circle": OpenGLCircle(BLUE), "dot": OpenGLDot(RIGHT), "ellipse": OpenGLEllipse(4, 2),
          "arc_between": OpenGLArcBetweenPoints(LEFT, RIGHT), "annular_sector": OpenGLAnnularSector(),
          "sector": OpenGLSector(2), "sector_inner": OpenGLSector(2, 1), "annulus": OpenGLAnnulus(),
          "bezier": OpenGLCubicBezier(LEFT, UP, UP + RIGHT, DOWN), "pentagon": OpenGLRegularPolygon(5),
          "hexagon_turned": OpenGLRegularPolygon(6, PI / 6)}
out["shapes"] = {k: m.points.tolist() for k, m in shapes.items()}
out["circle_color"] = OpenGLCircle(BLUE).get_color().to_hex()
r = OpenGLRectangle(WHITE, 4, 2)
out["rectangle_size"] = [r.width, r.height]
p = OpenGLPoint(RIGHT)
out["point"] = {"location": p.get_location().tolist(), "width": p.get_width(), "height": p.get_height()}

# Dashes split a curve by its parameter.
bent = OpenGLVMobject().set_points_as_corners([LEFT, ORIGIN, 3 * RIGHT])
out["dashed"] = {"open": [m.points.tolist() for m in OpenGLDashedVMobject(bent, 3).submobjects],
                 "closed": [m.points.tolist() for m in OpenGLDashedVMobject(OpenGLSquare(), 4, 0.6).submobjects]}

# Tips of OpenGL tipable classes are OpenGLArrowTips made from tip_config.
tipped = {"line": OpenGLLine(LEFT, 2 * RIGHT).add_tip(),
          "arc_start": OpenGLArc(0, PI).add_tip(at_start=True),
          "config": OpenGLLine(ORIGIN, 2 * UP, tip_config={"width": 0.5}).add_tip(length=0.2),
          "curved": OpenGLCurvedArrow(LEFT, RIGHT), "curved_double": OpenGLCurvedDoubleArrow(LEFT, RIGHT)}
out["tipped"] = {k: {"points": m.points.tolist(), "tips": [t.points.tolist() for t in m.submobjects],
                     "tip_color": m.submobjects[0].get_fill_color().to_hex()} for k, m in tipped.items()}

# Sizes of an OpenGL image of 2 by 4 pixels.
from manim.mobject.opengl.opengl_image_mobject import OpenGLImageMobject
pixels = np.zeros((2, 4, 4), dtype=np.uint8)
sizes = [{}, {"width": 2}, {"height": 3}, {"width": 1, "height": 5}]
out["image_sizes"] = [[m.get_width(), m.get_height()] for m in (OpenGLImageMobject(pixels, **kw) for kw in sizes)]
glossy = OpenGLImageMobject(pixels, gloss=0.2, shadow=0.3)
out["image_gloss"] = [glossy.gloss, glossy.shadow]

# Positional arguments of the base classes.
from manim import BLUE as _BLUE, RED as _RED
from manim.mobject.opengl.opengl_mobject import OpenGLMobject as _OpenGLMobject
m = _OpenGLMobject(_RED, 0.5, 3, 0.2, 0.3, is_fixed_in_frame=True)
out["base_mobject"] = {"color": m.color.to_hex(), "opacity": m.opacity, "gloss": m.gloss, "shadow": m.shadow,
                       "is_fixed_in_frame": m.is_fixed_in_frame}
v = OpenGLVMobject(_BLUE, 0.5, _RED, 0.7, 2, True, long_lines=True)
out["base_vmobject"] = {"fill_color": v.get_fill_color().to_hex(), "fill_opacity": v.get_fill_opacity(),
                        "stroke_color": v.get_stroke_color().to_hex(), "stroke_opacity": v.get_stroke_opacity(),
                        "stroke_width": float(v.get_stroke_width()[0]),
                        "draw_stroke_behind_fill": v.draw_stroke_behind_fill, "long_lines": v.long_lines}

json.dump(out, open(sys.argv[1], "w"), indent=1)
