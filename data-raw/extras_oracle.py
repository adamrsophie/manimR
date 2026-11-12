"""Reference values from the upstream source (Manim 0.22.1) for
tests/testthat/test-upstream-extras.R: helpers of manim.utils that
`from manim import *` does not export, and argument defaults.

Run from an empty directory with the upstream clone on the path:

    PYTHONPATH=documentation/manim python data-raw/extras_oracle.py tests/testthat/fixtures/extras_oracle.json
"""
import json
import os
import sys
import tempfile

import numpy as np

from manim import *
from manim.utils import opengl as gl
from manim.utils.bezier import (
    get_quadratic_approximation_of_cubic,
    get_smooth_closed_cubic_bezier_handle_points,
    get_smooth_open_cubic_bezier_handle_points,
)
from manim.utils.iterables import (
    batch_by_property,
    resize_array,
    resize_preserving_order,
    resize_with_interpolation,
    uniq_chain,
)
from manim.utils.space_ops import (
    norm_squared,
    normalize_along_axis,
    rotation_matrix_from_quaternion,
    rotation_matrix_transpose,
    rotation_matrix_transpose_from_quaternion,
)


def r(a):
    return np.round(np.asarray(a, dtype=float), 10).tolist()


out = {}

# space_ops
q = quaternion_from_angle_axis(0.7, np.array([1.0, 2.0, 3.0]))
out["space_ops"] = {
    "rotation_matrix_homogeneous": r(rotation_matrix(0.7, np.array([1.0, 2.0, 3.0]), homogeneous=True)),
    "rotation_matrix": r(rotation_matrix(0.7, np.array([1.0, 2.0, 3.0]))),
    "rotation_matrix_transpose": r(rotation_matrix_transpose(0.7, np.array([1.0, 2.0, 3.0]))),
    "rotation_matrix_transpose_z": r(rotation_matrix_transpose(0.7, np.array([0.0, 0.0, -2.0]))),
    "quat": r(q),
    "rotation_matrix_from_quaternion": r(rotation_matrix_from_quaternion(q)),
    "rotation_matrix_transpose_from_quaternion": r(rotation_matrix_transpose_from_quaternion(q)),
    "norm_squared": float(norm_squared(np.array([1.0, 2.0, 3.0]))),
    "normalize_along_axis": r(normalize_along_axis(np.array([[3.0, 4.0, 0.0], [0.0, 0.0, 0.0], [1.0, 2.0, 2.0]]), 1)),
    "midpoint": r(midpoint([0, 2, 0], [4, 0, 2])),
    "complex_to_R3": r(complex_to_R3(2 - 3j)),
    "normalize": r(normalize(np.array([3.0, 4.0, 0.0]))),
    "normalize_zero_fall_back": r(normalize(np.zeros(3), fall_back=np.array([0.0, 1.0, 0.0]))),
}

# iterables
m = np.arange(12, dtype=float).reshape(4, 3)
v = np.array([1.0, 2.0, 4.0, 8.0])
out["iterables"] = {
    "m": r(m),
    "v": r(v),
    "resize_array_grow": r(resize_array(m, 7)),
    "resize_array_shrink": r(resize_array(m, 2)),
    "resize_array_vector": r(resize_array(v, 6)),
    "resize_preserving_order_grow": r(resize_preserving_order(m, 7)),
    "resize_preserving_order_shrink": r(resize_preserving_order(m, 3)),
    "resize_preserving_order_empty": r(resize_preserving_order(np.zeros((0, 3)), 2)),
    "resize_with_interpolation_grow": r(resize_with_interpolation(m, 6)),
    "resize_with_interpolation_shrink": r(resize_with_interpolation(m, 3)),
    "resize_with_interpolation_vector": r(resize_with_interpolation(v, 7)),
    "batch_by_property": [[b, p] for b, p in batch_by_property([1, 3, 5, 2, 4, 7, 6], lambda x: x % 2)],
    "uniq_chain": list(uniq_chain([1, 2, 3], [3, 4, 1], [5])),
}

# bezier
closed = {
    "n3": [[0, 0, 0], [1, 1, 0], [0, 0, 0]],
    "n4": [[-1, 0, 0], [0, 1, 0], [1, 0, 0], [-1, 0, 0]],
    "n6": [[0, 0, 0], [2, 1, 0], [3, 3, 1], [1, 4, 0], [-1, 2, 0], [0, 0, 0]],
}
opened = {
    "n3": [[0, 0, 0], [1, 1, 0], [2, 0, 0]],
    "n5": [[0, 0, 0], [1, 2, 0], [2, 0, 1], [3, 2, 0], [5, 1, 0]],
}
out["bezier"] = {
    "closed_anchors": closed,
    "open_anchors": opened,
    "closed": {k: [r(h) for h in get_smooth_closed_cubic_bezier_handle_points(np.array(a, dtype=float))] for k, a in closed.items()},
    "open": {k: [r(h) for h in get_smooth_open_cubic_bezier_handle_points(np.array(a, dtype=float))] for k, a in opened.items()},
    "quadratic_single": r(get_quadratic_approximation_of_cubic([0, 0, 0], [1, 2, 0], [3, 2, 0], [4, 0, 0])),
    "quadratic_many": r(get_quadratic_approximation_of_cubic(
        np.array([[0.0, 0, 0], [4, 0, 0]]), np.array([[1.0, 2, 0], [5, -2, 0]]),
        np.array([[3.0, 2, 0], [7, -2, 1]]), np.array([[4.0, 0, 0], [8, 0, 0]]))),
}

# utils.opengl matrices
p = np.array([1.0, -2.0, 0.5])
out["opengl"] = {
    "orthographic_flat": r(gl.orthographic_projection_matrix()),
    "orthographic": r(gl.orthographic_projection_matrix(width=10, height=4, near=2, far=30, format_=False)),
    "perspective_flat": r(gl.perspective_projection_matrix()),
    "perspective": r(gl.perspective_projection_matrix(width=3, height=2, near=1, far=40, format_=False)),
    "translation": r(gl.translation_matrix(1, 2, 3)),
    "x_rotation": r(gl.x_rotation_matrix(0.3)),
    "y_rotation": r(gl.y_rotation_matrix(0.4)),
    "z_rotation": r(gl.z_rotation_matrix(0.5)),
    "rotation": r(gl.rotation_matrix(0.3, 0.4, 0.5)),
    "rotate_in_place": r(gl.rotate_in_place_matrix(p, 0.3, 0.4, 0.5)),
    "scale": r(gl.scale_matrix(2.5)),
    "view_default": r(gl.view_matrix()),
    "view": r(gl.view_matrix(translation=np.array([1.0, 2.0, 9.0]), x_rotation=0.3, y_rotation=0.4, z_rotation=0.5)),
    "matrix_to_shader_input": r(gl.matrix_to_shader_input(np.arange(16, dtype=float).reshape(4, 4))),
}

# colors
half = ManimColor("#FF000080")
out["colors"] = {
    "color_to_rgba_hex_alpha": r(color_to_rgba("#FF000080")),
    "color_to_rgba_alpha": r(color_to_rgba("#FF000080", 0.3)),
    "interpolate_alpha": r(interpolate_color(ManimColor([0.0, 0.0, 0.0, 0.0]), WHITE, 0.5).to_rgba()),
    "color_to_rgba_interpolated": r(color_to_rgba(interpolate_color(ManimColor([0.0, 0.0, 0.0, 0.0]), WHITE, 0.5))),
    "hex_to_rgb": r(hex_to_rgb("#336699")),
}

# ImplicitFunction: the adaptive isoline tracer of the isosurfaces package.
def implicit(f, **kw):
    m = ImplicitFunction(f, **kw)
    return {"n": len(m.points), "sum": r(m.points.sum(axis=0)), "abs": float(np.round(np.abs(m.points).sum(), 8)),
            "min": r(m.points.min(axis=0)), "max": r(m.points.max(axis=0))}


small = dict(x_range=[-2, 2], y_range=[-2, 2], min_depth=3, max_quads=100)
out["implicit"] = {
    "circle_points": r(ImplicitFunction(lambda x, y: x ** 2 + y ** 2 - 2, use_smoothing=False, **small).points),
    "circle_smooth_points": r(ImplicitFunction(lambda x, y: x ** 2 + y ** 2 - 2, **small).points),
    "circle": implicit(lambda x, y: x ** 2 + y ** 2 - 2),
    "hyperbola": implicit(lambda x, y: 1 / (x * y) - 1 if x * y != 0 else float("nan"), x_range=[-3, 3], y_range=[-3, 3]),
    "two_curves": implicit(lambda x, y: (x ** 2 + y ** 2 - 1) * ((x - 3) ** 2 + y ** 2 - 0.5)),
    "lemniscate": implicit(lambda x, y: (x ** 2 + y ** 2) ** 2 - 4 * (x ** 2 - y ** 2), min_depth=6, max_quads=3000),
    "line_open": implicit(lambda x, y: y - 0.3 * x - 0.1, use_smoothing=False),
}

# Convex hulls. Upstream orders facets and vertices by hash, so compare sets.
def face_set(h):
    return sorted(sorted(np.round(np.asarray(h.vertex_coords)[f], 8).tolist()) for f in h.faces_list)


rng = np.random.default_rng(7)
cloud = np.round(rng.uniform(-2, 2, size=(14, 3)), 3)
flat = np.round(rng.uniform(-2, 2, size=(12, 2)), 3)
cube = [[x, y, z] for x in (0, 1) for y in (0, 1) for z in (0, 1)]
cube_hull = ConvexHull3D(*cube, [0.5, 0.5, 0.5])
hull2 = ConvexHull(*[[x, y, 0] for x, y in flat.tolist()], [0, 0, 0])
out["hulls"] = {
    "cloud": cloud.tolist(),
    "cloud_faces": face_set(ConvexHull3D(*cloud.tolist())),
    "cube_n_faces": len(cube_hull.faces_list),
    "cube_face_sizes": sorted(len(f) for f in cube_hull.faces_list),
    "cube_n_vertices": len(cube_hull.vertex_coords),
    "flat": flat.tolist(),
    "flat_vertices": sorted(np.round(hull2.get_vertices(), 8).tolist()),
    # A point 1e-6 inside an edge is no vertex with the default tolerance.
    "near_edge_vertices": sorted(np.round(ConvexHull([0, 0, 0], [2, 0, 0], [1, -1e-6, 0], [1, 2, 0]).get_vertices(), 8).tolist()),
}

# SVG import: the styles and the path conversion of svgelements.
SVG_CASES = {
    'arcs_degenerate': '<path d="M 0 0 A 0 0 0 0 1 10 0 L 10 10"/><path d="M 20 0 L 30 0 A 5 5 0 0 1 30 0 l 5 5 Z"/><path d="M 50 50 A 10 10 0 1 0 50 50.0001"/><path d="M 60 10 A 10 10 0 0 0 80 10 A 10 10 0 0 0 60 10 Z"/>',
    'arcs_half': '<path d="M 10 50 A 20 20 0 0 1 50 50"/><path d="M 10 50 A 20 20 0 0 0 50 50"/><path d="M 60 50 A 10 20 0 1 1 80 50 Z"/><path d="M 20 80 A 30 10 30 0 1 70 80"/><path d="M 20 20 A 5 5 0 0 1 25 25"/><path d="M 20 20 A 1 1 0 0 1 60 20"/>',
    'arcs_rel': '<path d="M 10 10 a 10 10 0 1 0 20 0 a 10 10 0 1 0 -20 0 z"/><path d="M 50 50 a 25 12 -40 1 1 30 10 l 5 5 q 5 -10 10 0 t 10 0 s 3 3 6 0 h -5 v 8 Z"/>',
    'current_color': '<g color="green"><rect x="1" y="1" width="10" height="10" fill="currentColor" stroke="currentColor" stroke-width="1"/></g><rect x="20" y="1" width="10" height="10" fill="hsl(120, 50%, 50%)" stroke="rgb(10%, 20%, 30%)"/>',
    'fill_none': '<rect x="10" y="10" width="30" height="30" fill="none" stroke="red"/><circle cx="60" cy="25" r="10" fill="none"/><path d="M 70 5 L 90 5 L 80 20 Z" fill="none" stroke="#00f" stroke-width="2"/>',
    'fill_opacity': '<rect x="10" y="10" width="30" height="30" fill="rgba(255,0,0,0.5)" fill-opacity="0.3"/><rect x="50" y="10" width="30" height="30" fill="#ff000080"/><rect x="10" y="50" width="30" height="30" fill="red" fill-opacity="0.7" stroke="blue" stroke-opacity="0.25" stroke-width="3"/>',
    'odd_paint': '<defs><linearGradient id="g"><stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient></defs><rect x="1" y="1" width="10" height="10" fill="url(#g)"/><rect x="20" y="1" width="10" height="10" fill="transparent" stroke="transparent" stroke-width="2"/><rect x="40" y="1" width="10" height="10" fill="notacolor" stroke="#abc"/><rect x="60" y="1" width="10" height="10" fill="red" fill-opacity="50%" stroke-opacity="0.5"/><rect x="1" y="20" width="10" height="10" fill="hsl(200, 0%, 33%)"/><rect x="20" y="20" width="10" height="10" fill="hsl(30, 100%, 25%)" stroke="hsl(310, 40%, 80%)"/>',
    'opacity_attr': '<rect x="10" y="10" width="30" height="30" fill="red" opacity="0.5"/><g opacity="0.5"><circle cx="50" cy="50" r="10" fill="blue" stroke="green" stroke-width="2"/></g>',
    'rounded': '<rect x="10" y="10" width="40" height="20" rx="5"/><rect x="10" y="50" width="40" height="20" rx="5" ry="8"/><rect x="60" y="10" width="20" height="20" rx="30"/>',
    'stroke_width': '<rect x="1" y="1" width="10" height="10" stroke="red"/><rect x="20" y="1" width="10" height="10" stroke="red" stroke-width="0.5"/><g stroke="blue" stroke-width="3" transform="scale(2)"><rect x="1" y="20" width="10" height="10"/></g>',
    'style_attr': '<rect x="1" y="1" width="10" height="10" style="fill:#0f0;stroke:#00f;stroke-width:2;fill-opacity:.4"/><g style="fill:orange"><rect x="20" y="1" width="10" height="10"/><rect x="40" y="1" width="10" height="10" fill="teal"/></g>',
    'transforms': '<g transform="translate(10,20) rotate(30)"><rect width="20" height="10" fill="red"/><path d="M 0 0 A 10 5 0 0 1 20 0" transform="scale(2,1)"/></g><circle r="5" transform="matrix(1 0.5 0 1 50 50)"/><ellipse rx="8" ry="4" cx="70" cy="70" transform="skewX(20)"/>',
    'unset_stroke': '<rect x="10" y="10" width="30" height="30"/><circle cx="60" cy="25" r="10"/><ellipse cx="25" cy="70" rx="15" ry="8"/><polygon points="50,50 80,50 65,80"/><polyline points="5,95 20,85 35,95"/><line x1="60" y1="90" x2="90" y2="95"/><path d="M 70 5 L 90 5 L 80 20 Z"/>',
    'use_defs': '<defs><rect id="r" width="10" height="10"/></defs><use href="#r" x="5" y="5" fill="red"/><use href="#r" x="30" y="5" stroke="blue"/>',
}


def svg_case(body):
    text = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">' + body + "</svg>"
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "case.svg")
        with open(path, "w") as f:
            f.write(text)
        m = SVGMobject(path, use_svg_cache=False)
    return {
        "svg": text,
        "width": float(np.round(m.width, 8)),
        "members": [{
            "n": len(x.points), "sum": r(x.points.sum(axis=0)), "abs": float(np.round(np.abs(x.points).sum(), 8)),
            "fill": ManimColor(x.fill_rgbas[0][:3]).to_hex(), "fill_opacity": float(np.round(x.fill_rgbas[0][3], 8)),
            "stroke": ManimColor(x.stroke_rgbas[0][:3]).to_hex(), "stroke_opacity": float(np.round(x.stroke_rgbas[0][3], 8)),
            "stroke_width": float(np.round(x.get_stroke_width(), 8)),
        } for x in m.submobjects],
    }


out["svg"] = {name: svg_case(body) for name, body in SVG_CASES.items()}
with tempfile.TemporaryDirectory() as d:
    path = os.path.join(d, "case.svg")
    with open(path, "w") as f:
        f.write('<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10" fill="#FFFF00"/></svg>')
    def own(m):
        return {"fill": ManimColor(m.fill_rgbas[0][:3]).to_hex(), "stroke": ManimColor(m.stroke_rgbas[0][:3]).to_hex(),
                "stroke_width": float(m.get_stroke_width()), "child_fill": m.submobjects[0].get_fill_color().to_hex()}
    out["svg_container"] = {
        "plain": own(SVGMobject(path, use_svg_cache=False)),
        "color": own(SVGMobject(path, color=RED, use_svg_cache=False)),
        "fill_color": own(SVGMobject(path, fill_color=BLUE, use_svg_cache=False)),
    }

with open(sys.argv[1], "w") as f:
    json.dump(out, f)
print("wrote", sys.argv[1])
