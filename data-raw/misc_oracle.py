"""Dump reference values from Python manim for manimR's tests of vector
fields, boolean operations, graphs, tables, matrices, labels, ChangeSpeed and
the banner.

Run with a Python that has manim installed:

    python data-raw/misc_oracle.py tests/testthat/fixtures/misc_oracle.json
"""

import json
import sys

import numpy as np
from manim import (
    DOWN, LEFT, ORIGIN, RIGHT, UP, UR, BLUE, RED, YELLOW, DARK_GRAY,
    ArrowVectorField, StreamLines, Circle, Square, Union, Intersection, Difference, Exclusion,
    Graph, DiGraph, Matrix, IntegerMatrix, MathTable, IntegerTable, MathTex, LabeledLine, LabeledArrow,
    ManimBanner, ChangeSpeed, Wait, VMobject,
)
from manim.mobject.graph import _tree_layout
from manim.utils.polylabel import polylabel
from manim.utils.rate_functions import linear
import networkx as nx


def r(x):
    return np.round(np.asarray(x, dtype=float), 10).tolist()


def pts(m):
    return r(m.points)


def bbox(m):
    return r([m.get_left()[0], m.get_right()[0], m.get_bottom()[1], m.get_top()[1]])


def area(vm):
    # Signed shoelace area of finely sampled subpaths (holes count negative).
    total = 0.0
    for sp in vm.get_subpaths():
        t = np.linspace(0, 1, 64)[:-1]
        samples = []
        for i in range(0, len(sp) - 3, 4):
            p0, p1, p2, p3 = sp[i:i + 4]
            for s in t:
                samples.append((1 - s) ** 3 * p0 + 3 * (1 - s) ** 2 * s * p1 + 3 * (1 - s) * s ** 2 * p2 + s ** 3 * p3)
        a = np.array(samples)
        x, y = a[:, 0], a[:, 1]
        total += 0.5 * (np.dot(x, np.roll(y, -1)) - np.dot(np.roll(x, -1), y))
    return float(total)


cases = {}

# Vector fields -------------------------------------------------------------
func = lambda pos: ((pos[0] * UR + pos[1] * LEFT) - pos) / 3
vf = ArrowVectorField(func, x_range=[-2, 2, 1], y_range=[-1, 1, 1])
cases["avf_starts"] = r([v.get_start() for v in vf])
cases["avf_ends"] = r([v.get_end() for v in vf])
cases["avf_colors"] = [v.get_color().to_hex() for v in vf]
func2 = lambda pos: pos - LEFT * 5
vf2 = ArrowVectorField(func2, x_range=[-2, 2, 2], y_range=[-1, 1, 1], min_color_scheme_value=2,
                       max_color_scheme_value=10, colors=[RED, YELLOW, BLUE, DARK_GRAY])
cases["avf_scheme_colors"] = [v.get_color().to_hex() for v in vf2]
sl = StreamLines(func, color=BLUE, x_range=[-1, 1, 1], y_range=[-1, 1, 1], noise_factor=0, virtual_time=1,
                 max_anchors_per_line=5)
cases["stream_points"] = [pts(line) for line in sl.stream_lines]
cases["stream_duration"] = float(sl.stream_lines[0].duration)

# Boolean operations ----------------------------------------------------------
def shapes():
    sq = Square(color=RED, fill_opacity=1).move_to([-2, 0, 0])
    cr = Circle(color=BLUE, fill_opacity=1).move_to([-1.3, 0.7, 0])
    return sq, cr

for name, op in [("union", Union), ("intersection", Intersection), ("difference", Difference),
                 ("exclusion", Exclusion)]:
    sq, cr = shapes()
    res = op(sq, cr)
    cases["bool_" + name] = {"bbox": bbox(res), "area": area(res)}

# Graph layouts ---------------------------------------------------------------
V = [1, 2, 3, 4, 5, 6]
E = [(1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 1), (5, 1), (1, 3), (3, 5)]
def layout(g):
    return {str(k): r(v) for k, v in g._layout.items()}
cases["layout_circular"] = layout(Graph(V, E, layout="circular"))
cases["layout_partite"] = layout(Graph(V, E, layout="partite", partitions=[[1, 2], [3, 4]]))
cases["layout_spiral"] = layout(Graph(V, E, layout="spiral"))
cases["layout_spectral"] = layout(Graph(V, E, layout="spectral"))
cases["layout_spectral_path"] = layout(Graph([1, 2, 3, 4, 5], [(1, 2), (2, 3), (3, 4), (4, 5)], layout="spectral"))
cases["layout_spectral_di"] = layout(DiGraph([1, 2, 3, 4, 5], [(1, 2), (2, 3), (3, 4), (4, 5), (5, 3)],
                                             layout="spectral"))
cases["layout_shell"] = layout(Graph(list(range(1, 10)),
    [(1, 2), (2, 3), (3, 1), (4, 1), (4, 2), (5, 2), (6, 2), (6, 3), (7, 3), (8, 3), (8, 1), (9, 1)],
    layout="shell", layout_config={"nlist": [[1, 2, 3], [4, 5, 6, 7, 8, 9]]}))
cases["layout_kamada_kawai"] = layout(Graph(V, E, layout="kamada_kawai"))
kk_dist = {1: {2: 1}, 2: {3: 1}, 3: {4: 2}, 4: {5: 3}, 5: {6: 5}, 6: {1: 8}}
cases["layout_kamada_kawai_dist"] = layout(Graph(V, [(1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 1)],
                                                 layout="kamada_kawai", layout_config={"dist": kk_dist},
                                                 layout_scale=4))
start = {v: np.array([np.cos(v), np.sin(2 * v)]) for v in V}
cases["layout_spring_start"] = {str(k): r(v) for k, v in start.items()}
cases["layout_spring"] = layout(Graph(V, E, layout="spring", layout_config={"pos": start}))
TE = [(1, 2), (1, 3), (2, 4), (2, 5), (3, 6), (3, 7)]
cases["layout_tree"] = layout(Graph(list(range(1, 8)), TE, layout="tree", root_vertex=1))
cases["layout_tree_spacing"] = layout(Graph(list(range(1, 8)), TE, layout="tree", root_vertex=1,
                                            layout_config={"vertex_spacing": (0.5, 1)}))
cases["layout_tree_up"] = layout(Graph(list(range(1, 8)), TE, layout="tree",
                                       layout_config={"root_vertex": 1, "orientation": "up"}, layout_scale=(3, 1)))
g = Graph([1, 2, 3], [(1, 2), (2, 3)], layout={1: [-1, 0, 0], 2: [0, 1, 0], 3: [1, 0, 0]})
g[2].move_to([0, -1, 0])
g.update()
cases["graph_edge_after_move"] = pts(g.edges[(1, 2)])
dg = DiGraph([1, 2], [(1, 2)], layout={1: [-2, 0, 0], 2: [2, 0, 0]})
cases["digraph_edge"] = [pts(m) for m in dg.edges[(1, 2)].family_members_with_points()]

# Matrices and tables ---------------------------------------------------------
m = Matrix([[2, "\\pi"], [-1, 1]])
cases["matrix_entries"] = r([e.get_center() for e in m.get_entries()])
cases["matrix_brackets"] = [bbox(b) for b in m.get_brackets()]
cases["matrix_size"] = r([m.width, m.height])
im = IntegerMatrix([[3.7, 2], [42.2, 12]], left_bracket="(", right_bracket=")")
cases["intmatrix_entries"] = r([e.get_center() for e in im.get_entries()])
cases["intmatrix_size"] = r([im.width, im.height])
t = MathTable([["+", 0, 5], [0, 0, 5], [2, 2, 7]], include_outer_lines=True)
cases["mathtable_entries"] = r([e.get_center() for e in t.get_entries()])
cases["mathtable_hlines"] = [pts(l) for l in t.get_horizontal_lines()]
cases["mathtable_vlines"] = [pts(l) for l in t.get_vertical_lines()]
cases["mathtable_cell"] = pts(t.get_cell((2, 3)))
t2 = IntegerTable([[0, 30], [90, 60]], row_labels=[MathTex("a"), MathTex("b")],
                  col_labels=[MathTex("c"), MathTex("d")], h_buff=1)
cases["inttable_entries"] = r([e.get_center() for e in t2.get_entries()])
cases["inttable_entry_22"] = r(t2.get_entries((2, 2)).get_center())

# Labels ----------------------------------------------------------------------
ll = LabeledLine(label="0.5", label_position=0.8, label_config={"font_size": 20}, start=LEFT + DOWN, end=RIGHT + UP)
cases["labeled_line_label"] = bbox(ll.label)
la = LabeledArrow("0.5", start=LEFT * 3, end=RIGHT * 3 + UP * 2, label_position=0.5)
cases["labeled_arrow_label"] = r(la.label.get_center())
ring1 = [[-3.8, -2.4, 0], [-2.4, -2.5, 0], [-1.3, -1.6, 0], [-0.2, -1.7, 0], [1.7, -2.5, 0], [2.9, -2.6, 0],
         [3.5, -1.5, 0], [4.9, -1.4, 0], [4.5, 0.2, 0], [4.7, 1.6, 0], [3.5, 2.4, 0], [1.1, 2.5, 0], [-0.1, 0.9, 0],
         [-1.2, 0.5, 0], [-1.6, 0.7, 0], [-1.4, 1.9, 0], [-2.6, 2.6, 0], [-4.4, 1.2, 0], [-4.9, -0.8, 0],
         [-3.8, -2.4, 0]]
ring2 = [[0.2, -1.2, 0], [0.9, -1.2, 0], [1.4, -2.0, 0], [2.1, -1.6, 0], [2.2, -0.5, 0], [1.4, 0.0, 0],
         [0.4, -0.2, 0], [0.2, -1.2, 0]]
ring3 = [[-2.7, 1.4, 0], [-2.3, 1.7, 0], [-2.8, 1.9, 0], [-2.7, 1.4, 0]]
cell = polylabel([ring1, ring2, ring3], precision=0.01)
cases["polylabel"] = {"c": r(cell.c), "d": float(cell.d)}

# ChangeSpeed -----------------------------------------------------------------
cs = ChangeSpeed(Wait(1), speedinfo={0.3: 1, 0.4: 0.1, 0.6: 0.1, 1: 1}, rate_func=linear,
                 affects_speed_updaters=False)
ts = np.linspace(0, 1, 11)
cases["change_speed_run_time"] = float(cs.run_time)
cases["change_speed_values"] = r([float(cs.anim.rate_func(t)) for t in ts])

# Banner ----------------------------------------------------------------------
b = ManimBanner()
cases["banner_M"] = bbox(b.M)
cases["banner_shapes"] = [bbox(s) for s in b.shapes]
cases["banner_anim"] = [bbox(s) for s in b.anim]
cases["banner_M_points"] = pts(b.M)

with open(sys.argv[1], "w") as f:
    json.dump(cases, f)
print("wrote", len(cases), "cases")
