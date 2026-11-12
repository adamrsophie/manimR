"""Dump reference geometry from Python manim for manimR's fidelity tests.

Run with a Python that has manim installed:

    python data-raw/upstream_oracle.py tests/testthat/fixtures/upstream_oracle.json

Each case stores point matrices (and a few scalars) produced by upstream
manim, which tests/testthat/test-upstream-oracle.R compares against manimR.
"""

import json
import sys

import numpy as np
from manim import (
    DOWN, LEFT, ORIGIN, OUT, PI, RIGHT, TAU, UP,
    Arc, ArcBetweenPoints, Arrow, Circle, Dot, Ellipse, Line, MathTex,
    Polygon, Rectangle, RegularPolygon, RoundedRectangle, Square, Star,
    Transform, VGroup, VMobject, Annulus, AnnularSector, DashedLine, Brace,
    config, BLUE,
)
from manim.utils.bezier import bezier_remap, partial_bezier_points
from manim.utils.paths import path_along_arc


def pts(m):
    return np.round(np.asarray(m.points, dtype=float), 10).tolist()


def family_pts(m):
    return [pts(sm) for sm in m.family_members_with_points()]


cases = {}

cases["circle"] = pts(Circle())
cases["circle_r2"] = pts(Circle(radius=2).shift(LEFT))
cases["square"] = pts(Square())
cases["arc"] = pts(Arc(radius=1.5, start_angle=0.3, angle=2.0))
cases["arc_between"] = pts(ArcBetweenPoints(LEFT, RIGHT + UP, angle=PI / 3))
cases["ellipse"] = pts(Ellipse(width=3, height=1))
cases["star"] = pts(Star())
cases["hexagon"] = pts(RegularPolygon(6))
cases["rounded_rect"] = pts(RoundedRectangle(corner_radius=0.3, width=3, height=2))
cases["line_buff"] = pts(Line(LEFT * 2, RIGHT * 2 + UP, buff=0.3))
cases["arrow"] = family_pts(Arrow(LEFT, RIGHT + UP))
cases["annulus"] = pts(Annulus())
cases["annular_sector"] = pts(AnnularSector())
cases["dashed_line"] = family_pts(DashedLine(LEFT * 2, RIGHT * 2))

# Smooth curves.
v = VMobject()
v.set_points_smoothly([LEFT * 2, UP, RIGHT, DOWN * 0.5 + RIGHT * 2])
cases["smooth_open"] = pts(v)
v = VMobject()
v.set_points_smoothly([LEFT, UP, RIGHT, DOWN, LEFT])
cases["smooth_closed"] = pts(v)

# Alignment and transform.
sq = Square().rotate(PI / 4)
c = Circle()
a, b = sq.copy(), c.copy()
a.align_data(b)
cases["align_square_circle"] = {"a": pts(a), "b": pts(b)}
g1 = VGroup(Square(), Circle().shift(RIGHT * 2))
g2 = VGroup(Star(), Square().shift(UP), Dot(LEFT * 2))
a, b = g1.copy(), g2.copy()
a.align_data(b)
cases["align_groups"] = {"a": family_pts(a), "b": family_pts(b)}

t = Transform(Square().rotate(PI / 4), Circle())
t.begin()
t.interpolate(0.37)
cases["transform_037"] = pts(t.mobject)
t = Transform(Square(), Circle().shift(RIGHT), path_arc=PI / 2)
t.begin()
t.interpolate(0.5)
cases["transform_arc_05"] = pts(t.mobject)

p = Circle().copy()
p.pointwise_become_partial(Circle(), 0.2, 0.7)
cases["partial_02_07"] = pts(p)
p = Square().copy()
p.pointwise_become_partial(Square(), 0.0, 0.33)
cases["partial_square"] = pts(p)

cases["bezier_remap"] = np.round(
    bezier_remap(np.asarray(Square().points).reshape(-1, 4, 3), 7), 10
).reshape(-1, 3).tolist()
cases["partial_bezier"] = np.round(
    partial_bezier_points(np.asarray(Circle().points[:4]), 0.25, 0.8), 10
).tolist()

# Positioning.
s = Square().next_to(Circle(), RIGHT, buff=0.5)
cases["next_to"] = s.get_center().tolist()
s = Square(side_length=1).to_corner(UP + LEFT)
cases["to_corner"] = s.get_center().tolist()
g = VGroup(*[Square(side_length=0.5) for _ in range(7)]).arrange_in_grid()
cases["arrange_in_grid"] = [m.get_center().tolist() for m in g]

# LaTeX (same latex and dvisvgm on this machine).
m = MathTex(r"e^{i\pi} + 1 = 0")
cases["mathtex_size"] = [m.width, m.height]
cases["mathtex_points"] = family_pts(m)
m = MathTex("a^2", "+", "b^2")
cases["mathtex_parts"] = [len(m), [len(part) for part in m]]

b = Brace(Square(), DOWN)
cases["brace"] = pts(b)

# Rate functions.
from manim.utils import rate_functions as rf
ts = [0, 0.1, 0.25, 0.5, 0.73, 0.9, 1]
names = ["linear", "smooth", "rush_into", "rush_from", "slow_into", "double_smooth", "there_and_back",
         "there_and_back_with_pause", "running_start", "wiggle", "lingering", "exponential_decay",
         "ease_in_sine", "ease_out_bounce", "ease_in_out_elastic", "ease_in_out_back", "smootherstep"]
cases["rate_functions"] = {n: [float(getattr(rf, n)(t)) for t in ts] for n in names}

# Animations at intermediate alphas.
from manim import (Create, Uncreate, Write, DrawBorderThenFill, FadeIn, FadeOut, GrowFromCenter,
                   GrowArrow, Rotate, Indicate, ShowPassingFlash, AnimationGroup, LaggedStart,
                   Succession, SpinInFromNothing, ReplacementTransform, Wiggle, ApplyWave)


def anim_state(anim, alpha):
    anim.begin()
    anim.interpolate(alpha)
    return family_pts(anim.mobject)


cases["create_04"] = anim_state(Create(VGroup(Square(), Circle().shift(RIGHT))), 0.4)
cases["dbtf_03"] = anim_state(DrawBorderThenFill(Square().set_fill(BLUE, 1)), 0.3)
cases["dbtf_07"] = anim_state(DrawBorderThenFill(Square().set_fill(BLUE, 1)), 0.7)
cases["fadein_shift_05"] = anim_state(FadeIn(Square(), shift=UP, scale=0.5), 0.5)
cases["fadeout_05"] = anim_state(FadeOut(Circle(), target_position=RIGHT * 2), 0.5)
cases["grow_center_03"] = anim_state(GrowFromCenter(Star()), 0.3)
cases["grow_arrow_05"] = anim_state(GrowArrow(Arrow(LEFT, RIGHT)), 0.5)
cases["rotate_05"] = anim_state(Rotate(Square(), PI / 3), 0.5)
cases["indicate_05"] = anim_state(Indicate(Square()), 0.5)
cases["flash_04"] = anim_state(ShowPassingFlash(Circle(), time_width=0.3), 0.4)
cases["spin_05"] = anim_state(SpinInFromNothing(Square()), 0.5)
cases["wiggle_03"] = anim_state(Wiggle(Square()), 0.3)
cases["wave_04"] = anim_state(ApplyWave(Line(LEFT * 2, RIGHT * 2)), 0.4)
g = VGroup(*[Square(side_length=0.5).shift(RIGHT * i) for i in range(4)])
cases["lagged_05"] = anim_state(LaggedStart(*[FadeIn(m) for m in g], lag_ratio=0.5), 0.5)
cases["write_text_05"] = anim_state(Write(MathTex("abc")), 0.5)
style = []
w = Write(MathTex("abc"))
w.begin()
w.interpolate(0.5)
cases["write_text_05_style"] = [[sm.get_stroke_width(), sm.get_fill_opacity()] for sm in w.mobject.family_members_with_points()]
ag = AnimationGroup(FadeIn(Square()), Create(Circle(), run_time=2), lag_ratio=0.5)
cases["group_timing"] = [ag.run_time, list(map(float, ag.anims_with_timings["start"])), list(map(float, ag.anims_with_timings["end"]))]

json.dump(cases, open(sys.argv[1], "w"))
print("wrote", len(cases), "cases")
