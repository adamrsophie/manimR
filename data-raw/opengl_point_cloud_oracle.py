# Reference values from Python manim 0.20.1 for the OpenGL point clouds.
# Run from an empty directory: python -I data-raw/opengl_point_cloud_oracle.py OUT.json
import json, numpy as np
from manim import *
from manim.mobject.opengl.dot_cloud import DotCloud, TrueDot
from manim.mobject.opengl.opengl_point_cloud_mobject import OpenGLPMobject, OpenGLPGroup, OpenGLPMPoint
out = {}
d = DotCloud()
out["dotcloud_n"] = len(d.points); out["dotcloud_first"] = d.points[:5].tolist(); out["dotcloud_last"] = d.points[-3:].tolist()
out["dotcloud_radius"] = d.radius; out["dotcloud_point_radius"] = float(np.array(d.point_radius).ravel()[0]); out["dotcloud_rgbas"] = np.array(d.rgbas).tolist()[:2]
d2 = DotCloud(radius=0.5, density=4)
out["dotcloud2_n"] = len(d2.points); out["dotcloud2"] = d2.points.tolist()
t = TrueDot(center=RIGHT)
out["truedot_points"] = t.points.tolist(); out["truedot_radius"] = t.radius
p = OpenGLPMPoint(location=UP)
out["pmpoint"] = p.points.tolist(); out["pmpoint_sw"] = p.stroke_width; out["pmpoint_pr"] = float(np.array(p.point_radius).ravel()[0])
q = OpenGLPMobject(); q.add_points([[0,0,0],[1,1,0]], color=RED)
out["pm_points"] = q.points.tolist(); out["pm_rgbas"] = np.array(q.rgbas).tolist()
g = OpenGLPGroup(OpenGLPMPoint(), OpenGLPMPoint(location=RIGHT))
out["group_n"] = len(g.submobjects)
import sys; json.dump(out, open(sys.argv[1], "w"))

