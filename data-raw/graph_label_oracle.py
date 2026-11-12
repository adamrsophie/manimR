import json, sys
import numpy as np
from manim import *
def r(a): return np.round(np.asarray(a, dtype=float), 6).tolist()
def cw(m): return r(list(m.get_center()) + [m.width, m.height])
c = {}
c["polar_dnc"] = PolarPlane().x_axis.decimal_number_config
c["bar_dnc"] = BarChart([8, 4]).y_axis.decimal_number_config
c["np_smooth"] = NumberPlane().make_smooth_after_applying_functions
l = NumberLine(x_range=[-2, 2, 1], include_numbers=True)
c["nl_numbers"] = [cw(n) for n in l.numbers]
ax = Axes(x_range=[-3, 3, 1], y_range=[-2, 2, 1]).add_coordinates()
c["ax_x_numbers"] = [cw(n) for n in ax.x_axis.numbers]
c["ax_y_numbers"] = [cw(n) for n in ax.y_axis.numbers]
labs = ax.get_axis_labels()
c["axis_labels"] = [cw(m) for m in labs]
g = ax.plot(np.sin)
c["graph_label"] = cw(ax.get_graph_label(g, r"\sin x", x_val=1))
c["graph_label_default"] = cw(ax.get_graph_label(g))
bc = BarChart([3, -1, 2], bar_names=["a", "bb", "c"])
c["bar_x_labels"] = [cw(m) for m in bc.x_axis.labels]
c["bar_labels"] = [cw(m) for m in bc.get_bar_labels()]
c["bar_y_numbers"] = [cw(m) for m in bc.y_axis.numbers]
pp = PolarPlane(size=6).add_coordinates()
c["polar_r"] = [cw(m) for m in pp.coordinate_labels[0]]
c["polar_a"] = [cw(m) for m in pp.coordinate_labels[1]][:6]
cp = ComplexPlane(x_range=[-2, 2, 1], y_range=[-2, 2, 1]).add_coordinates()
c["complex"] = [cw(m) for m in cp.coordinate_labels]
lg = NumberLine(x_range=[0, 2, 1], scaling=LogBase(), include_numbers=True)
c["log_labels"] = [cw(m) for m in lg.labels]
json.dump(c, open(sys.argv[1], "w"))
