# Reference values from Python manim 0.22.1 for the methods of the OpenGL
# mobject classes, read by tests/testthat/test-opengl-methods.R.
# Run from documentation/manim:
#   PYTHONPATH=. python ../../data-raw/opengl_methods_oracle.py ../../tests/testthat/fixtures/opengl_methods_oracle.json
import json, sys, tempfile
from pathlib import Path
import numpy as np
from PIL import Image
from manim import LEFT, ORIGIN, RIGHT, PI
from manim.mobject.opengl.opengl_geometry import (
    OpenGLArc, OpenGLArrowTip, OpenGLCircle, OpenGLDashedLine, OpenGLSquare,
)
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

json.dump(out, open(sys.argv[1], "w"), indent=1)
