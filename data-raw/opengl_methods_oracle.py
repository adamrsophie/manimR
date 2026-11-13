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
# The textured surface takes the surface's opacity.
half = OpenGLSurface(lambda u, v: np.array([u, v, u * v]), u_range=(-1, 1), v_range=(-1, 1), resolution=(3, 3), opacity=0.5)
out["textured_opacity"] = OpenGLTexturedSurface(half, img).get_shader_data()["opacity"][:, 0].tolist()

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
# Image arrays are upscaled with the resampling algorithm before they are
# used as textures.
from PIL.Image import Resampling
src = np.array([[[255, 0, 0, 255], [0, 255, 0, 128], [0, 0, 255, 255]],
                [[255, 255, 0, 255], [0, 255, 255, 64], [40, 80, 120, 255]]], dtype=np.uint8)
up = {}
for name, alg in {"nearest": Resampling.NEAREST, "bilinear": Resampling.BILINEAR, "bicubic": Resampling.BICUBIC,
                  "lanczos": Resampling.LANCZOS, "box": Resampling.BOX, "hamming": Resampling.HAMMING}.items():
    im = np.asarray(OpenGLImageMobject(src, resampling_algorithm=alg).get_image_from_file(src, "RGBA"), dtype=float)
    up[name] = {"dim": list(im.shape), "rows": im[[0, 300, 399]][:, list(range(0, 600, 7)) + [599], :].tolist()}
out["image_upscaled"] = up
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


# The CPU side of the OpenGL renderer: the camera, trees of 3D objects,
# triangulation and matrix lists.
from manim.renderer.opengl_renderer import OpenGLCamera
from manim.renderer.shader import Object3D, filter_attributes
from manim.renderer.vectorized_mobject_rendering import build_matrix_lists, triangulate_mobject
from manim.utils.bezier import get_quadratic_approximation_of_cubic
from manim import Circle, Square, VGroup
from manim.mobject.opengl.opengl_vectorized_mobject import OpenGLVGroup
cam = OpenGLCamera()
cam.set_euler_angles(theta=PI / 4, phi=PI / 3)
turned = OpenGLCamera(euler_angles=[0.2, 0.4, 0.1])
turned.rotate(0.3, RIGHT)
moved = OpenGLCamera(frame_shape=(4, 3), center_point=[1, 2, 0])
moved.set_zoom(2)
moved.increment_phi(3)
out["camera"] = {"rotation": np.asarray(cam.inverse_rotation_matrix).tolist(), "position": cam.get_position().tolist(),
                 "view": cam.unformatted_view_matrix.tolist(), "turned": turned.euler_angles.tolist(),
                 "moved_points": moved.points.tolist(), "moved_shape": list(moved.get_shape()),
                 "moved_phi": float(moved.euler_angles[1]), "focal": moved.get_focal_distance()}
start, end = OpenGLCamera(), OpenGLCamera(euler_angles=[1, 0.5, 0.2])
end.shift([1, 2, 0])
end.scale(0.5)
mid = OpenGLCamera()
mid.interpolate(start, end, 0.25)
out["camera_interpolate"] = {"points": mid.points.tolist(), "angles": mid.euler_angles.tolist(),
                             "rotation": np.asarray(mid.inverse_rotation_matrix).tolist()}
end.to_default_state()
out["camera_default"] = {"points": end.points.tolist(), "angles": end.euler_angles.tolist()}
a, b, c = Object3D(), Object3D(), Object3D()
a.add(b)
b.add(c)
a.model_matrix = np.array([[0, -1, 0, 1], [1, 0, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]], dtype=float)
b.set_position([0, 2, 0])
c.normal_matrix = np.diag([2.0, 3, 4, 1])
out["object3d"] = {"model": c.hierarchical_model_matrix().tolist(), "normal": c.hierarchical_normal_matrix().tolist(),
                   "n_family": len(list(a.copy().get_family()))}
def quadratic(mob):
    p = mob.points
    return get_quadratic_approximation_of_cubic(p[0::4], p[1::4], p[2::4], p[3::4])
tris = {}
for k, cairo in {"square": Square(), "circle": Circle(), "two_squares": VGroup(Square(), Square(0.5)).family_members_with_points()}.items():
    pts = np.vstack([quadratic(m) for m in cairo]) if isinstance(cairo, list) else quadratic(cairo)
    t = triangulate_mobject(OpenGLVMobject().set_points(pts))
    tris[k] = {"in_vert": t["in_vert"].astype(float).tolist(), "texture_mode": t["texture_mode"].tolist()}
    if k == "square":
        f = filter_attributes(t, ["in_vert", "texture_coords"])
        out["filtered"] = {"names": list(f.dtype.names), "n": len(f)}
out["triangulation"] = tris
g = OpenGLVGroup(OpenGLSquare(), OpenGLCircle())
g.submobjects[1].model_matrix = np.diag([2.0, 1, 1, 1])
out["matrix_lists"] = [{"matrix": list(k), "n": len(v)} for k, v in build_matrix_lists(g).items()]

# The renderer's CPU side, with a context that keeps the buffers and
# uniforms instead of drawing them.
from manim import config as _config
from manim.renderer.opengl_renderer import OpenGLRenderer
from manim.renderer import vectorized_mobject_rendering as _vmr
from manim.renderer.opengl_renderer_window import Window as _Window
from manim.mobject.opengl.opengl_geometry import OpenGLCircle as _OGCircle


class _Program(dict):
    pass


class _Context:
    def __init__(self):
        self.buffers = []

    def program(self, **kwargs):
        p = _Program()
        p.ctx = self
        return p

    def buffer(self, data):
        self.buffers.append(data)
        return type("B", (), {"release": lambda s: None})()

    def simple_vertex_array(self, program, vbo, *names):
        self.last_program = program
        return type("V", (), {"render": lambda s: None, "release": lambda s: None})()


class _FBO:
    viewport = (0, 0, 1280, 720)

    def use(self):
        pass


r = OpenGLRenderer()
r.context = _Context()
r.frame_buffer_object = _FBO()
r.camera.set_euler_angles(0.3, 0.6, 0.1)
r.refresh_perspective_uniforms(r.camera)
out["perspective_uniforms"] = {k: np.asarray(v, dtype=float).ravel().tolist() for k, v in r.perspective_uniforms.items()}
r.camera.set_euler_angles(0, 0, 0)
out["pixel_to_space"] = [r.pixel_coords_to_space_coords(100, 200).tolist(),
                         r.pixel_coords_to_space_coords(30, -20, relative=True).tolist(),
                         r.pixel_coords_to_space_coords(100, 200, top_left=True).tolist()]
r.background_color = "#336699"
out["background_color"] = [float(x) for x in r.background_color]
# Quadratic curves of Cairo shapes, as manimR's OpenGL mobjects keep cubic
# points and hand their quadratic halves to the shaders.
from manim import RED as _RED, Circle as _Circle
circle = OpenGLVMobject().set_points(quadratic(_Circle(radius=1.5)))
circle.set_fill(_RED, 0.5)
circle.set_stroke(_RED, 6)
circle.add(OpenGLVMobject().set_points(quadratic(Square(side_length=1))).set_fill(BLUE, 1))
_vmr.render_opengl_vectorized_mobject_fill(r, circle)
fill_dtype = [("in_vert", np.float32, (3,)), ("in_color", np.float32, (4,)), ("texture_coords", np.float32, (2,)),
              ("texture_mode", np.int32)]
fills = [np.frombuffer(b, dtype=fill_dtype) for b in r.context.buffers]
out["fill_buffers"] = [{"n": len(f), "in_vert": f["in_vert"][:6].tolist(), "in_color": f["in_color"][[0, -1]].tolist(),
                        "texture_coords": f["texture_coords"][:6].tolist(), "texture_mode": f["texture_mode"].tolist()}
                       for f in fills]
out["fill_uniforms"] = {k: np.asarray(v, dtype=float).ravel().tolist() for k, v in r.context.last_program.items()}
r.context.buffers = []
_vmr.render_opengl_vectorized_mobject_stroke(r, circle)
stroke_dtype = [("current_curve", np.float32, (3, 3)), ("tile_coordinate", np.float32, (2,)),
                ("in_color", np.float32, (4,)), ("in_width", np.float32)]
strokes = [np.frombuffer(b, dtype=stroke_dtype) for b in r.context.buffers]
out["stroke_buffers"] = [{"n": len(f), "current_curve": f["current_curve"][[0, 1, 3]].tolist(),
                          "tile_coordinate": f["tile_coordinate"][[0, 1, 2, len(f) // 2, len(f) // 2 + 1]].tolist(),
                          "in_color": f["in_color"][0].tolist(), "in_width": f["in_width"][[0, -1]].tolist()}
                         for f in strokes]
out["stroke_uniforms"] = {k: np.asarray(v, dtype=float).ravel().tolist() for k, v in r.context.last_program.items()}
_Monitor = type("M", (), {"x": 10, "y": 20, "width": 1920, "height": 1080})
positions = {}
for pos in ["UR", "OO", "DL", "LEFT", "UP", "ORIGIN", "100,200"]:
    _config.window_position = pos
    positions[pos] = list(_Window.find_initial_position(None, (640, 360), _Monitor))
_config.window_position = "UR"
out["window_positions"] = positions

json.dump(out, open(sys.argv[1], "w"), indent=1)
