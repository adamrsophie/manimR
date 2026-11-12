"""Dump reference values from Python manim for manimR's tests of the public
utilities: Bezier helpers, space operations, binary_search, sigmoid, the 3D
VMobject helpers, index_labels and the TeX template libraries.

Run with a Python that has manim installed (index_labels needs LaTeX):

    python data-raw/utils_oracle.py tests/testthat/fixtures/utils_oracle.json
"""

import json
import sys

import numpy as np
from manim import (
    DOWN, LEFT, OUT, PI, RIGHT, UP, Circle, Dot, Line, Square, VGroup,
)
from manim.mobject.three_d.three_d_utils import (
    get_3d_vmob_end_corner, get_3d_vmob_end_corner_index,
    get_3d_vmob_end_corner_unit_normal, get_3d_vmob_gradient_start_and_end_points,
    get_3d_vmob_start_corner, get_3d_vmob_start_corner_index,
    get_3d_vmob_start_corner_unit_normal, get_3d_vmob_unit_normal,
)
from manim.utils.bezier import (
    bezier_remap, get_smooth_cubic_bezier_handle_points, integer_interpolate, is_closed,
    mid, partial_bezier_points, point_lies_on_bezier,
    proportions_along_bezier_curve_for_point, split_bezier, subdivide_bezier,
)
from manim.utils.debug import index_labels
from manim.utils.simple_functions import binary_search, sigmoid
from manim.utils.space_ops import (
    angle_axis_from_quaternion, center_of_mass, complex_func_to_R3_func, cross2d,
    earclip_triangulation, find_intersection, get_unit_normal, get_winding_number,
    perpendicular_bisector, quaternion_conjugate, quaternion_from_angle_axis,
    quaternion_mult, regular_vertices, shoelace, shoelace_direction, thick_diagonal,
    z_to_vector,
)
from manim.utils.tex_templates import TexFontTemplates, TexTemplateLibrary


def r(x):
    return np.round(np.asarray(x, dtype=float), 10).tolist()


cases = {}

# Bezier ----------------------------------------------------------------------
curves = {
    "deg0": [[1, 2, 3]],
    "line": [[0, 0, 0], [2, 1, 0]],
    "quad": [[0, 0, 0], [1, 2, 0], [3, 0, 0]],
    "cubic": [[0, 0, 0], [1, 2, 0], [3, -1, 1], [4, 1, 0]],
    "quartic": [[0, 0, 0], [1, 2, 0], [2, -1, 0], [3, 3, 1], [4, 0, 0]],
}
cases["curves"] = curves
cases["split_bezier"] = {k: r(split_bezier(np.array(v, dtype=float), 0.3)) for k, v in curves.items()}
cases["subdivide_bezier"] = {
    k: r(subdivide_bezier(np.array(v, dtype=float), 3)) for k, v in curves.items() if k != "deg0"
}
cases["partial_bezier_points"] = {
    k: r(partial_bezier_points(np.array(v, dtype=float), 0.2, 0.7)) for k, v in curves.items()
}
circ = Circle().points
cases["bezier_remap_circle"] = r(bezier_remap(circ.reshape(-1, 4, 3), 13).reshape(-1, 3))
cases["integer_interpolate"] = [
    list(integer_interpolate(*a)) for a in [(0, 10, 0.46), (0, 10, 1), (0, 10, 0), (2, 7, 0.33), (0, 3, 0.999)]
]
cases["mid"] = [mid(1, 4), r(mid(np.array([1, 2, 3]), np.array([3, 4, 5])))]
closed_cases = {
    "exact": [[0, 0, 0], [1, 2, 3], [3, 2, 1], [0, 0, 0]],
    "tiny": [[0, 0, 0], [1, 2, 3], [3, 2, 1], [1e-10, 1e-10, 1e-10]],
    "open": [[0, 0, 0], [1, 2, 3], [3, 2, 1], [1e-2, 1e-2, 1e-2]],
    "negative_start": [[-1, -1, 0], [1, 1, 0], [-1, -1, 0]],
    "relative": [[1, 1, 1], [2, 0, 0], [1 + 5e-6, 1, 1]],
}
cases["is_closed_points"] = closed_cases
cases["is_closed"] = {k: bool(is_closed(np.array(v, dtype=float))) for k, v in closed_cases.items()}
anchor_sets = {
    "open": [[0, 0, 0], [1, 1, 0], [2, 0, 0], [3, 2, 0]],
    "closed": [[0, 0, 0], [1, 1, 0], [2, 0, 0], [0, 0, 0]],
    "negative_closed": [[-1, 0, 0], [0, 1, 0], [1, 0, 0], [-1, 0, 0]],
    "two": [[0, 0, 0], [3, 3, 0]],
}
cases["smooth_anchors"] = anchor_sets
cases["smooth_handles"] = {}
for k, v in anchor_sets.items():
    h1, h2 = get_smooth_cubic_bezier_handle_points(np.array(v, dtype=float))
    cases["smooth_handles"][k] = [r(np.reshape(h1, (-1, 3))), r(np.reshape(h2, (-1, 3)))]

cubic = np.array(curves["cubic"], dtype=float)
flat = np.array([[0, 0, 0], [1, 2, 0], [3, -1, 0], [4, 1, 0]], dtype=float)


def cubic_at(p, t):
    return (1 - t) ** 3 * p[0] + 3 * (1 - t) ** 2 * t * p[1] + 3 * (1 - t) * t ** 2 * p[2] + t ** 3 * p[3]


queries = {
    "cubic_t025": (cubic_at(cubic, 0.25), cubic),
    "cubic_t05": (cubic_at(cubic, 0.5), cubic),
    "cubic_start": (cubic[0], cubic),
    "cubic_end": (cubic[3], cubic),
    "cubic_off": (np.array([1.0, 1.0, 0.0]), cubic),
    "flat_t075": (cubic_at(flat, 0.75), flat),
    "flat_off": (np.array([2.0, 5.0, 0.0]), flat),
}
cases["proportions"] = {}
for k, (p, c) in queries.items():
    cases["proportions"][k] = {
        "point": r(p),
        "control": r(c),
        "roots": r(proportions_along_bezier_curve_for_point(p, c)),
        "lies": bool(point_lies_on_bezier(p, c)),
    }

# Space ops -------------------------------------------------------------------
q1 = [0.5, 0.5, -0.5, 0.5]
q2 = [1, 2, 3, 4]
q3 = [0.1, -0.2, 0.3, 0.9]
cases["quaternion_mult"] = {
    "three": r(quaternion_mult(q1, q2, q3)),
    "one": r(quaternion_mult(q2)),
    "none": r(quaternion_mult()),
}
cases["quaternion_from_angle_axis"] = {
    "normalize": r(quaternion_from_angle_axis(PI / 3, np.array([1, 2, 3]))),
    "normalized": r(quaternion_from_angle_axis(0.7, np.array([0, 0, 2]), axis_normalized=True)),
}
aa = angle_axis_from_quaternion(quaternion_from_angle_axis(PI / 3, np.array([1, 2, 3])))
aa_big = angle_axis_from_quaternion(quaternion_from_angle_axis(3 * PI / 2, np.array([0, 0, 1])))
cases["angle_axis_from_quaternion"] = {
    "small": [float(aa[0]), r(aa[1])],
    # An angle above PI: TAU - angle about the flipped axis (0.20.1 did not flip it).
    "big": [float(aa_big[0]), r(aa_big[1])],
}
cases["quaternion_conjugate"] = r(quaternion_conjugate([1, 2, 3, 4]))
cases["thick_diagonal"] = {"d5": thick_diagonal(5).tolist(), "d4t3": thick_diagonal(4, 3).tolist()}
cases["center_of_mass"] = r(center_of_mass([[0, 0, 0], [2, 4, 6], [1, -1, 3]]))
cases["complex_func_to_R3_func"] = r(complex_func_to_R3_func(lambda z: z ** 2 + 1j)(np.array([1.0, 2.0, 0.0])))
cases["cross2d"] = {
    "single": float(cross2d(np.array([1, 2]), np.array([3, 4]))),
    "rows": r(cross2d(np.array([[1, 2, 0], [1, 0, 0]]), np.array([[3, 4, 0], [0, 1, 0]]))),
}
normal_cases = {
    "generic": ([1, 2, 0.5], [-1, 0.3, 2]),
    "aligned": ([1, 2, 3], [2, 4, 6]),
    "v1_zero": ([0, 0, 0], [1, 1, 1]),
    "v2_zero": ([3, 0, 4], [0, 0, 0]),
    "both_zero": ([0, 0, 0], [0, 0, 0]),
    "z_aligned": ([0, 0, 1], [0, 0, 3]),
}
cases["unit_normal_inputs"] = normal_cases
cases["get_unit_normal"] = {k: r(get_unit_normal(np.array(a, dtype=float), np.array(b, dtype=float))) for k, (a, b) in normal_cases.items()}
cases["perpendicular_bisector"] = {
    "default": r(perpendicular_bisector([np.array([0.0, 0, 0]), np.array([2.0, 2, 0])])),
    "norm": r(perpendicular_bisector([np.array([1.0, 0, 0]), np.array([1.0, 2, 1])], np.array([0, 0, 2.0]))),
}
p0s = np.array([[0.0, 0, 0], [1, 1, 0]])
v0s = np.array([[1.0, 1, 0], [1, 0, 0]])
p1s = np.array([[2.0, 0, 0], [3, 0, 1]])
v1s = np.array([[0.0, 1, 0], [0, 1, 0]])
cases["find_intersection"] = {"p0s": r(p0s), "v0s": r(v0s), "p1s": r(p1s), "v1s": r(v1s),
                              "result": r(find_intersection(p0s, v0s, p1s, v1s))}
sq = Square()
cases["winding"] = [float(get_winding_number(sq.get_vertices())),
                    float(get_winding_number(sq.copy().shift(2 * UP).get_vertices())),
                    float(get_winding_number(np.vstack([sq.get_vertices(), sq.get_vertices()])))]
tri = np.array([[0.0, 0], [2, 0], [1, 3]])
cases["shoelace"] = {"ccw": float(shoelace(tri)), "cw": float(shoelace(tri[::-1])),
                     "ccw_dir": shoelace_direction(tri), "cw_dir": shoelace_direction(tri[::-1])}
v5, a5 = regular_vertices(5, radius=2)
v6, a6 = regular_vertices(6, start_angle=0.3)
cases["regular_vertices"] = {"v5": r(v5), "a5": float(a5), "v6": r(v6), "a6": float(a6)}
cases["z_to_vector"] = {"generic": r(z_to_vector(np.array([1.0, 2, 3]))), "x": r(z_to_vector(np.array([2.0, 0, 0])))}

# Earclip triangulation (indices are 0 based here).
th = np.linspace(0, 2 * np.pi, 101)[:-1]
wavy = np.c_[(1 + 0.3 * np.sin(7 * th)) * np.cos(th), (1 + 0.3 * np.sin(7 * th)) * np.sin(th), np.zeros(100)]
star_th = np.linspace(0, 2 * np.pi, 11)[:-1]
star_r = np.where(np.arange(10) % 2 == 0, 2.0, 0.8)
star = np.c_[star_r * np.cos(star_th), star_r * np.sin(star_th), np.zeros(10)]
outer = np.array([[0.0, 0, 0], [6, 0, 0], [6, 4, 0], [0, 4, 0]])
hole1 = np.array([[1.0, 1, 0], [1, 3, 0], [2, 3, 0], [2, 1, 0]])
# Hole orders are chosen so that 0.20.1's ring lookup, which skips the last
# vertex of each ring, finds the ring to attach.
hole2 = np.array([[5.0, 1, 0], [4, 1, 0], [4, 2, 0], [5, 2.5, 0]])
polys = {
    "convex": (np.array([[0.0, 0, 0], [2, 0, 0], [2, 1, 0], [0.5, 1.5, 0], [0, 1, 0]]), [5]),
    "star": (star, [10]),
    "wavy": (wavy, [100]),
    "one_hole": (np.vstack([outer, hole1]), [4, 8]),
    "two_holes": (np.vstack([outer, hole1, hole2]), [4, 8, 12]),
}
cases["earclip"] = {
    k: {"verts": r(v), "ring_ends": e, "indices": [int(i) for i in earclip_triangulation(v, e)]}
    for k, (v, e) in polys.items()
}

# simple_functions ------------------------------------------------------------
cases["binary_search"] = {
    "quadratic": binary_search(lambda x: x ** 2 + 3 * x + 1, 11, 0, 5),
    "quadratic_tol": binary_search(lambda x: x ** 2 + 3 * x + 1, 11, 0, 5, tolerance=0.01),
    "none": binary_search(lambda x: x ** 2 + 3 * x + 1, 71, 0, 5),
    "decreasing": binary_search(lambda x: 10 - x, 7.3, 0, 5),
    "exact_lower": binary_search(lambda x: 2 * x, 0, 0, 5),
}
cases["sigmoid"] = [float(sigmoid(x)) for x in (-2, 0, 0.5, 3)]

# 3D helpers ------------------------------------------------------------------
vmobs = {
    "square": Square(side_length=2).rotate(PI / 3, axis=RIGHT).shift(OUT),
    "circle": Circle().rotate(PI / 4, axis=UP).shift(LEFT),
    "line": Line(LEFT, RIGHT + UP),
}
cases["three_d"] = {}
for k, m in vmobs.items():
    g = get_3d_vmob_gradient_start_and_end_points(m)
    cases["three_d"][k] = {
        "points": r(m.points),
        "start_index": int(get_3d_vmob_start_corner_index(m)),
        "end_index": int(get_3d_vmob_end_corner_index(m)),
        "start": r(get_3d_vmob_start_corner(m)),
        "end": r(get_3d_vmob_end_corner(m)),
        "gradient": r(np.array(g)),
        "start_normal": r(get_3d_vmob_start_corner_unit_normal(m)),
        "end_normal": r(get_3d_vmob_end_corner_unit_normal(m)),
        "normal_at_7": r(get_3d_vmob_unit_normal(m, 7)),
    }

# index_labels ----------------------------------------------------------------
group = VGroup(Square(), Circle().shift(3 * RIGHT), Dot(2 * UP + LEFT), Line(DOWN, 2 * DOWN + RIGHT))
labels = index_labels(group)
cases["index_labels"] = {
    "centers": r([lab.get_center() for lab in labels]),
    "heights": [float(lab.height) for lab in labels],
    "background_stroke_width": [float(lab.get_stroke_width(background=True)) for lab in labels],
    "background_stroke_color": [lab.get_stroke_color(background=True).to_hex() for lab in labels],
    "big_heights": [float(lab.height) for lab in index_labels(group, label_height=0.4)],
}

# TeX templates ---------------------------------------------------------------
def dump_templates(cls):
    out = {}
    for name in [n for n in vars(cls) if not n.startswith("_")]:
        t = getattr(cls, name)
        out[name] = {
            "tex_compiler": t.tex_compiler,
            "output_format": t.output_format,
            "description": t.description,
            "documentclass": t.documentclass,
            "preamble": t.preamble,
            "placeholder_text": t.placeholder_text,
            "post_doc_commands": t.post_doc_commands,
            "body": t.body,
        }
    return out


cases["tex_template_library"] = dump_templates(TexTemplateLibrary)
cases["tex_font_templates"] = dump_templates(TexFontTemplates)

with open(sys.argv[1], "w") as fh:
    json.dump(cases, fh, indent=1)
