import json, sys
import numpy as np
from manim import *

def r(a): return np.round(np.asarray(a, dtype=float), 8).tolist()
def pts(m): return r(m.points)
c = {}
l = NumberLine(x_range=[-3, 3, 1], length=5, rotation=PI/6, include_tip=True)
c["nl_ticks"] = [r(t.get_center()) for t in l.ticks]
c["nl_tick_range"] = r(l.get_tick_range())
c["nl_n2p"] = r(l.n2p(1.5))
c["nl_points"] = pts(l)
u = UnitInterval()
c["ui_tick_heights"] = [float(t.height) for t in u.ticks]
lg = NumberLine(x_range=[-2, 4, 1], scaling=LogBase(), length=6)
c["log_ticks"] = [r(t.get_center()) for t in lg.ticks]
ax = Axes(x_range=[-2, 6, 1], y_range=[-1, 3, 0.5], x_length=7, y_length=5)
c["ax_c2p"] = r(ax.c2p(1.5, 2.25))
c["ax_c2p_many"] = r(ax.c2p([[0, 0], [1, 1], [6, 3]]))
c["ax_p2c"] = r(ax.p2c([1, 1, 0]))
c["ax_x_ticks"] = [r(t.get_center()) for t in ax.x_axis.ticks]
c["ax_y_ticks"] = [r(t.get_center()) for t in ax.y_axis.ticks]
c["ax_x_points"] = pts(ax.x_axis)
c["ax_tip"] = pts(ax.x_axis.tip)
g = ax.plot(lambda x: x**2 / 4, x_range=[-1, 2, 0.5])
c["plot_points"] = pts(g)
g2 = ax.plot(lambda x: (x**2 - 2) / (x**2 - 4), discontinuities=[2], dt=0.1, x_range=[0, 4, 0.5])
c["plot_disc_points"] = pts(g2)
rects = ax.get_riemann_rectangles(g, x_range=[-1, 2], dx=0.5)
c["riemann"] = [pts(rr) for rr in rects]
c["riemann_colors"] = [rr.get_fill_color().to_hex() for rr in rects]
rects2 = ax.get_riemann_rectangles(ax.plot(lambda x: x - 1), x_range=[0, 2], dx=0.5, input_sample_type="center")
c["riemann_center"] = [pts(rr) for rr in rects2]
c["riemann_center_colors"] = [rr.get_fill_color().to_hex() for rr in rects2]
area = ax.get_area(g, x_range=[0, 1.5])
c["area"] = pts(area)
np_ = NumberPlane(x_range=[-3, 3, 1], y_range=[-2, 2, 1], x_length=6, y_length=3, faded_line_ratio=2)
c["np_bg"] = [r([bl.get_start(), bl.get_end()]) for bl in np_.background_lines]
c["np_faded"] = [r([bl.get_start(), bl.get_end()]) for bl in np_.faded_lines]
t3 = ThreeDAxes()
c["t3_c2p"] = r(t3.c2p(1, 2, 3))
c["t3_z_points"] = r([t3.z_axis.get_start(), t3.z_axis.get_end()])
pp = PolarPlane(size=6)
c["polar_c2p"] = r(pp.pr2pt(2, PI / 3))
c["polar_bg_count"] = len(pp.background_lines)
c["polar_radian_labels"] = [pp.get_radian_label(i).get_tex_string() for i in np.arange(0, 1, 1 / 20)]
bc = BarChart([1, 3, -2], y_range=[-2, 4, 1], y_length=4, x_length=3, y_axis_config={"include_numbers": False})
c["bars"] = [pts(b) for b in bc.bars]
c["bar_colors"] = [b.get_fill_color().to_hex() for b in bc.bars]
bc.change_bar_values([2, -1, 1])
c["bars_changed"] = [pts(b) for b in bc.bars]
ss = SampleSpace()
ss.divide_horizontally([0.3, 0.5])
c["ss_parts"] = [pts(p) for p in ss.horizontal_parts]
sg = ax.get_secant_slope_group(1, g, dx=0.5)
c["secant"] = [pts(m) for m in sg.submobjects]
lgph = ax.plot_line_graph([0, 1, 2], [1, 2, 0])
c["line_graph"] = pts(lgph["line_graph"])
c["polar_graph"] = pts(ax.plot_polar_graph(lambda th: 1 + 0.5 * np.cos(th), theta_range=[0, PI, 0.5]))
c["vline"] = pts(ax.get_vertical_line(ax.c2p(2, 1), line_func=Line))
json.dump(c, open(sys.argv[1], "w"))
