# Reference values from Python manim 0.22.1 for the methods of the OpenGL
# mobject classes, as checked in tests/testthat/test-opengl-methods.R.
# Run from documentation/manim: PYTHONPATH=. python ../../data-raw/opengl_methods_oracle.py
from pathlib import Path
import numpy as np
from manim import LEFT, ORIGIN, RIGHT, PI
from manim.mobject.opengl.opengl_geometry import (
    OpenGLArc, OpenGLArrowTip, OpenGLCircle, OpenGLDashedLine, OpenGLSquare,
)
from manim.mobject.opengl.opengl_surface import OpenGLSurface, OpenGLTexturedSurface
from manim.mobject.opengl.opengl_vectorized_mobject import OpenGLVMobject
from manim.renderer.shader_wrapper import get_colormap_code, get_shader_code_from_file

np.set_printoptions(precision=6, suppress=True)
tip = OpenGLArrowTip()
print("arrow tip base, tip point, length, angle:", tip.get_base(), tip.get_tip_point(), tip.get_length(), tip.get_angle())
print("arrow tip width 1, length 2, get_length:", OpenGLArrowTip(width=1, length=2).get_length())
print("arc quadratic points:\n", OpenGLArc.create_quadratic_bezier_points(PI / 2, 0, 2))

s = OpenGLSurface(lambda u, v: np.array([u, v, u * v]), u_range=(-1, 1), v_range=(-1, 1), resolution=(3, 3))
print("surface triangle indices:", s.get_triangle_indices().tolist())
d = s.get_shader_data()
print("surface point:\n", d["point"][:4], "\nsurface du_point:\n", d["du_point"][:4])
# A 2 by 2 image file; upstream fails on an array here (get_full_raster_image_path).
import tempfile
from PIL import Image
img = str(Path(tempfile.mkdtemp()) / "img.png")
Image.fromarray(np.array([[[255, 0, 0], [0, 255, 0]], [[0, 0, 255], [255, 255, 255]]], dtype=np.uint8)).save(img)
print("textured im_coords:\n", OpenGLTexturedSurface(s, img).get_shader_data()["im_coords"][:3])

print("shader code lengths:", len(get_shader_code_from_file(Path("surface/vert.glsl"))),
      len(get_shader_code_from_file(Path("quadratic_bezier_fill/frag.glsl"))))
print("colormap code:", get_colormap_code([(1, 0, 0), (0, 0.5, 1)]))

v = OpenGLVMobject()
v.set_anchors_and_handles(np.array([[0, 0, 0]]), np.array([[1, 1, 0]]), np.array([[2, 0, 0]]))
print("quadratic curve at half:", v.point_from_proportion(0.5))

c = OpenGLCircle().surround(OpenGLSquare(side_length=2), buff=0.5)
print("circle surround width, height:", c.width, c.height)
dl = OpenGLDashedLine(LEFT, RIGHT, dash_length=0.1, dashed_ratio=0.5)
print("dashed line calculate_num_dashes:", dl.calculate_num_dashes(0.5),
      OpenGLDashedLine(ORIGIN, 0.1 * RIGHT).calculate_num_dashes(0.5))

s2 = OpenGLSurface(lambda u, v: np.array([u, v, 0]), u_range=(0, 1), v_range=(0, 1), resolution=(5, 5))
# The textured surface keeps its own resolution (default 101 by 101); match the surface.
ts = OpenGLTexturedSurface(s2, img, resolution=(5, 5))
tp = ts.copy()
tp.pointwise_become_partial(ts, 0, 0.5)
print("textured partial im_coords:\n", tp.im_coords[:6])
