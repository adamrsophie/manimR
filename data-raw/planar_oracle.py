"""Dump reference values from networkx (as used by Python manim) for manimR's
tests of the "planar" graph layout.

Run with a Python that has manim and networkx installed:

    python data-raw/planar_oracle.py tests/testthat/fixtures/planar_oracle.json

The planarity test and its embedding are deterministic and dumped as is.
networkx's drawing takes the next vertex of the canonical ordering, and one
vertex per connected component, from Python sets (hash order); manimR takes
the first one in vertex order instead, so the positions dumped here come from
a copy of networkx patched to do the same.
"""

import inspect
import json
import random
import sys

import networkx as nx
import networkx.algorithms.planar_drawing as pd
import numpy as np
from manim import DiGraph, Graph

# Patch the set choices: min() instead of set.pop() and next(iter(...)).
src = inspect.getsource(pd.get_canonical_ordering)
src = src.replace("v = ready_to_pick.pop()", "v = min(ready_to_pick); ready_to_pick.discard(v)")
assert "min(ready_to_pick)" in src
exec(src, pd.__dict__)
src = inspect.getsource(pd.triangulate_embedding)
src = src.replace("[next(iter(x)) for x in", "[min(x) for x in")
assert "min(x)" in src
exec(src, pd.__dict__)


def r(x):
    return np.round(np.asarray(x, dtype=float), 10).tolist()


def case(vertices, edges, directed=False):
    g = (DiGraph if directed else Graph)(vertices, edges, layout="circular")
    out = {"vertices": vertices, "edges": [list(e) for e in edges], "directed": directed}
    planar, emb = nx.check_planarity(g._graph)
    out["planar"] = planar
    if planar:
        data = emb.get_data()
        out["cw"] = [data.get(v, []) for v in vertices]
        layout = (DiGraph if directed else Graph)(vertices, edges, layout="planar", layout_scale=2)
        out["pos"] = [r(layout[v].get_center()) for v in vertices]
    return out


cases = []
V = list(range(1, 7))
E = [(1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 1), (5, 1), (1, 3), (3, 5)]
cases.append(case(V, E))
cases.append(case(V, list(reversed(E))))
cases.append(case(V, E, directed=True))
cases.append(case([1, 2, 3], [(1, 2), (2, 3)]))
grid = nx.convert_node_labels_to_integers(nx.grid_2d_graph(3, 4), first_label=1)
cases.append(case(list(grid.nodes), list(grid.edges)))
wheel = nx.wheel_graph(7)
cases.append(case(list(wheel.nodes), list(wheel.edges)))
cases.append(case(list(range(1, 8)), [(1, 2), (1, 3), (2, 4), (2, 5), (3, 6), (3, 7)]))
cases.append(case(list(range(1, 9)), [(1, 2), (2, 3), (3, 1), (4, 5), (5, 6), (6, 7), (7, 4), (4, 6)]))
rng = random.Random(1)
for n in (6, 8, 10, 12):
    tri = nx.convert_node_labels_to_integers(nx.triangular_lattice_graph(2, n // 2), first_label=1)
    edges = list(tri.edges)
    rng.shuffle(edges)
    edges = edges[: max(len(tri) - 1, int(len(edges) * 0.8))]
    cases.append(case(sorted(tri.nodes), edges))
cases.append(case(list(range(1, 6)), [(i, j) for i in range(1, 6) for j in range(i + 1, 6)]))
cases.append(case(list(range(1, 7)), [(i, j) for i in (1, 2, 3) for j in (4, 5, 6)]))
petersen = nx.convert_node_labels_to_integers(nx.petersen_graph(), first_label=1)
cases.append(case(list(petersen.nodes), list(petersen.edges)))

with open(sys.argv[1], "w") as f:
    json.dump(cases, f)
print("wrote", len(cases), "cases;", sum(c["planar"] for c in cases), "planar")
