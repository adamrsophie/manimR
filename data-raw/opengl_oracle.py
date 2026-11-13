"""Frames of upstream's OpenGL renderer for the software rasterizer tests.

Needs moderngl and an OpenGL context. Run from the package root with the
cloned upstream on the path:

    PYTHONPATH=documentation/manim python data-raw/opengl_oracle.py tests/testthat/fixtures
"""
import json, os, sys
import numpy as np
from manim import config, tempconfig
from manim.renderer.opengl_renderer import OpenGLRenderer
from manim.scene.scene import Scene
from manim.mobject.opengl.opengl_surface import OpenGLSurface, OpenGLTexturedSurface
from manim.mobject.opengl.dot_cloud import DotCloud
from manim.mobject.opengl.opengl_point_cloud_mobject import OpenGLPMobject
from manim.mobject.opengl.opengl_vectorized_mobject import OpenGLVMobject, OpenGLVGroup
from manim.mobject.geometry.arc import Circle
from manim.mobject.geometry.polygram import Square
from manim.utils.color import RED, GREEN, BLUE, WHITE, YELLOW

out = {}
def frame(name, build):
    with tempconfig({"renderer": "opengl", "pixel_width": 160, "pixel_height": 90, "write_to_movie": False,
                     "preview": False, "disable_caching": True}):
        r = OpenGLRenderer()
        s = Scene(renderer=r)
        for m in build():
            s.add(m)
        r.update_frame(s)
        a = np.frombuffer(r.get_raw_frame_buffer_object_data(), dtype=np.uint8).reshape(90, 160, 4)
        out[name] = a.astype(int).tolist()

def planes():
    near = OpenGLSurface(lambda u, v: np.array([u, v, 1.0]), u_range=(-1, 1), v_range=(-1, 1), resolution=(4, 4), color=RED, gloss=0, shadow=0)
    far = OpenGLSurface(lambda u, v: np.array([u, v, 0.0]), u_range=(-1, 1), v_range=(-1, 1), resolution=(4, 4), color=GREEN, gloss=0, shadow=0)
    return [far, near]
frame("planes", planes)
def tilted():
    return [OpenGLSurface(lambda u, v: np.array([u, v, 0.5 * u]), u_range=(-2, 2), v_range=(-1.5, 1.5), resolution=(5, 5), color=BLUE, gloss=0.8, shadow=0.5)]
frame("tilted", tilted)
def sphere():
    return [OpenGLSurface(lambda u, v: 2 * np.array([np.cos(u) * np.sin(v), np.sin(u) * np.sin(v), -np.cos(v)]),
                          u_range=(0, 2 * np.pi), v_range=(0, np.pi), resolution=(33, 17), color=BLUE)]
frame("sphere", sphere)
def textured():
    img = np.zeros((2, 2, 4), dtype=np.uint8); img[..., 3] = 255
    img[0, 0, 0] = 255; img[0, 1, 1] = 255; img[1, 0, 2] = 255; img[1, 1, :3] = 255
    p = OpenGLSurface(lambda u, v: np.array([u, v, 0.0]), u_range=(-2, 2), v_range=(-2, 2), gloss=0, shadow=0)
    from PIL import Image
    path = os.path.join(sys.argv[1], "opengl_texture.png")
    Image.fromarray(img, "RGBA").save(path)
    return [OpenGLTexturedSurface(p, path)]
frame("textured", textured)
def dots():
    d = OpenGLPMobject(stroke_width=40, color=RED)
    d.add_points(np.array([[0.0, 0, 0]]), color=RED)
    c = DotCloud(radius=1.5, density=3, color=BLUE).make_3d().shift(np.array([3.0, 0, 0]))
    return [d, c]
frame("dots", dots)
# manimR keeps cubic curves (a circle is 8 cubic arcs, as upstream's Cairo
# Circle) and hands each to the shaders as two quadratics, while upstream's
# OpenGL Circle is 9 quadratic arcs. These shapes take manimR's points, so
# the frames compare the shaders alone.
def cubic_circle(radius, center):
    angles = np.linspace(0, 2 * np.pi, 9)
    h = 4 / 3 * np.tan(np.pi / 16)
    pts = []
    for a0, a1 in zip(angles[:-1], angles[1:]):
        p0 = np.array([np.cos(a0), np.sin(a0), 0]); p3 = np.array([np.cos(a1), np.sin(a1), 0])
        t0 = np.array([-np.sin(a0), np.cos(a0), 0]); t1 = np.array([-np.sin(a1), np.cos(a1), 0])
        pts += [p0, p0 + h * t0, p3 - h * t1, p3]
    return radius * np.array(pts) + center
def cubic_polygon(corners):
    pts = []
    for a, b in zip(corners, np.roll(corners, -1, axis=0)):
        pts += [a, a + (b - a) / 3, a + 2 * (b - a) / 3, b]
    return np.array(pts)
def from_cubic(cubic, **kwargs):
    from manim.utils.bezier import get_quadratic_approximation_of_cubic
    m = OpenGLVMobject(**kwargs)
    m.set_points(get_quadratic_approximation_of_cubic(*(cubic[i::4] for i in range(4))))
    return m
def vfill():
    c = from_cubic(cubic_circle(1.5, np.array([-2.0, 0, 0])), color=WHITE, fill_color=RED, fill_opacity=1, stroke_width=4)
    sq = from_cubic(cubic_polygon(np.array([[3.0, 1, 0], [1, 1, 0], [1, -1, 0], [3, -1, 0]])), color=YELLOW,
                    fill_color=BLUE, fill_opacity=0.5, stroke_width=8)
    return [c, sq]
frame("vfill", vfill)
def vstroke():
    zig = OpenGLVMobject(stroke_color=GREEN, stroke_width=10)
    zig.set_points_as_corners(np.array([[-4.0, -1, 0], [-2, 1.5, 0], [0, -1, 0], [2, 1.5, 0], [4, -1, 0]]))
    arc = OpenGLVMobject(stroke_color=WHITE, stroke_width=6)
    arc.set_points(np.array([[-3.0, -2.5, 0], [0, 0.5, 0], [3, -2.5, 0]]))
    return [zig, arc]
frame("vstroke", vstroke)
# Each frame as a PNG, rows as OpenGL reads them (bottom row first).
from PIL import Image
for name, a in out.items():
    Image.fromarray(np.array(a, dtype=np.uint8), "RGBA").save(os.path.join(sys.argv[1], f"opengl_{name}.png"))
print("ok", list(out))
