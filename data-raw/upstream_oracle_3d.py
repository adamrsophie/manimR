"""Dump reference 3D, image and point cloud data from Python manim for
tests/testthat/test-camera-3d.R and tests/testthat/test-image-pointcloud.R.

Run with a Python that has manim installed:

    python data-raw/upstream_oracle_3d.py tests/testthat/fixtures/upstream_oracle_3d.json
"""

import json
import sys

import numpy as np
from manim import (
    BLUE, DEGREES, ORIGIN, OUT, RIGHT, UP, X_AXIS,
    Arrow3D, Cone, Cube, Cylinder, Dodecahedron, Dot3D, ImageMobject, Icosahedron,
    Line3D, Mobject1D, Octahedron, PointCloudDot, Prism, Sphere, Square, Surface,
    Tetrahedron, Torus,
)
from manim.camera.three_d_camera import ThreeDCamera
from manim.mobject.three_d.three_d_utils import (
    get_3d_vmob_end_corner_unit_normal,
    get_3d_vmob_start_corner_unit_normal,
)


def pts(m):
    return np.round(np.asarray(m.points, dtype=float), 10).tolist()


def family_pts(m):
    return [pts(sm) for sm in m.family_members_with_points()]


cases = {}

cases["sphere"] = family_pts(Sphere(center=(1, 0, 0), radius=1.5, resolution=(6, 4)))
cases["cube"] = family_pts(Cube(side_length=3))
cases["prism"] = family_pts(Prism(dimensions=[1, 2, 3]))
cases["surface"] = family_pts(
    Surface(lambda u, v: np.array([u, v, u * v]), u_range=[0, 1], v_range=[0, 2], resolution=(2, 3))
)
cases["torus"] = family_pts(Torus(resolution=(6, 6)))
cases["cone"] = family_pts(Cone(base_radius=1, height=2, direction=np.array([1.0, 1.0, 2.0]), resolution=4))
cases["cylinder"] = family_pts(Cylinder(radius=1, height=2, direction=X_AXIS, resolution=(4, 8)))
cases["line3d"] = family_pts(Line3D(ORIGIN, np.array([2.0, 1.0, 2.0]), resolution=6))
cases["arrow3d"] = family_pts(Arrow3D(ORIGIN, np.array([0.0, 1.0, 2.0]), resolution=6))
cases["dot3d"] = family_pts(Dot3D(np.array([1.0, 2.0, 3.0]), radius=0.1))

for name, cls in [("tetrahedron", Tetrahedron), ("octahedron", Octahedron),
                  ("icosahedron", Icosahedron), ("dodecahedron", Dodecahedron)]:
    p = cls(edge_length=2)
    cases[name] = {"faces": family_pts(p.faces),
                   "vertices": [p.graph[v].get_center().tolist() for v in p.graph.vertices]}

probe = np.array([[1.0, 2.0, 0.0], [0.0, 0.0, 1.0], [-1.5, 0.5, 2.0], [3.0, -1.0, -2.0]])
cams = {
    "default": dict(),
    "angled": dict(phi=75 * DEGREES, theta=30 * DEGREES),
    "full": dict(phi=60 * DEGREES, theta=-45 * DEGREES, gamma=0.3, zoom=2, focal_distance=10,
                 frame_center=np.array([1.0, 2.0, 0.5])),
    "exponential": dict(phi=50 * DEGREES, theta=20 * DEGREES, exponential_projection=True),
}
cases["camera"] = {}
for name, kw in cams.items():
    cam = ThreeDCamera(**kw)
    cam.reset_rotation_matrix()
    cases["camera"][name] = {
        "rotation": np.round(cam.get_rotation_matrix(), 10).tolist(),
        "projected": np.round(cam.project_points(probe.copy()), 10).tolist(),
    }

cam = ThreeDCamera(phi=75 * DEGREES, theta=30 * DEGREES)
sphere = Sphere(resolution=(6, 4))
faces = sphere.family_members_with_points()
order = cam.get_mobjects_to_display([sphere])
cases["sphere_display_order"] = [faces.index(m) for m in order]
cases["sphere_fill_rgbas"] = [np.round(cam.get_fill_rgbas(f), 10).tolist() for f in faces[:6]]
cases["sphere_normals"] = [
    [get_3d_vmob_start_corner_unit_normal(f).tolist(), get_3d_vmob_end_corner_unit_normal(f).tolist()]
    for f in faces
]
sq = Square(shade_in_3d=True).set_fill(BLUE, opacity=1).rotate(0.7, axis=RIGHT).shift(OUT)
cases["square_fill_rgbas"] = np.round(cam.get_fill_rgbas(sq), 10).tolist()

img = ImageMobject(np.uint8([[0, 100, 30, 200], [255, 0, 5, 33]]))
cases["image_points"] = pts(img)
img.height = 7
cases["image_points_h7"] = pts(img)

d = PointCloudDot(radius=1, density=20)
cases["pointcloud_dot"] = {"n": len(d.points), "head": pts(d)[:5], "tail": pts(d)[-3:]}
m = Mobject1D()
m.add_line(np.array([-1.0, 0, 0]), np.array([1.0, 0.5, 0]))
cases["mobject1d_line"] = pts(m)

json.dump(cases, open(sys.argv[1], "w"))
print("wrote", len(cases), "cases")
