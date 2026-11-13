"""Dump the exact points of Python manim's boolean operations (skia-pathops)
for manimR's tests. Each point is written as float.hex() so the values
transport without rounding.

Run with a Python that has manim installed:

    python data-raw/boolean_ops_oracle.py tests/testthat/fixtures/boolean_ops_oracle.json
"""

import json
import sys

from manim import (
    BLUE, RED, LEFT, RIGHT, UP, DOWN,
    Circle, Square, Ellipse, Triangle, RegularPolygon, Star, Rectangle,
    Union, Intersection, Difference, Exclusion,
)


def pts(m):
    return [[float(v).hex() for v in p] for p in m.points]


def cases():
    out = {}

    def sq_cr():
        return (Square(color=RED, fill_opacity=1).move_to([-2, 0, 0]),
                Circle(color=BLUE, fill_opacity=1).move_to([-1.3, 0.7, 0]))

    def ellipses():
        e1 = Ellipse(width=4.0, height=5.0).move_to(LEFT)
        return e1, e1.copy().move_to(RIGHT)

    def nested():
        return Square(side_length=4), Circle(radius=1)

    def apart():
        return Circle().shift(2 * LEFT), Circle().shift(2 * RIGHT)

    def poly():
        return RegularPolygon(n=5), Triangle().scale(1.5).shift(0.4 * UP)

    def star():
        return Star(), Circle(radius=0.8).shift(0.3 * RIGHT)

    def offset_square():
        return Square(), Square().shift(0.5 * RIGHT + 0.5 * UP)

    def rect_circle():
        return Rectangle(width=4, height=1), Circle(radius=1.2)

    for cname, make in [("sq_cr", sq_cr), ("ellipses", ellipses), ("nested", nested),
                        ("apart", apart), ("poly", poly), ("star", star),
                        ("offset_square", offset_square), ("rect_circle", rect_circle)]:
        for oname, op in [("union", Union), ("intersection", Intersection),
                          ("difference", Difference), ("exclusion", Exclusion)]:
            a, b = make()
            out[cname + "_" + oname] = pts(op(a, b))
    three = lambda: (Square(), Circle().shift(0.8 * RIGHT), Triangle().shift(0.6 * UP))
    out["three_union"] = pts(Union(*three()))
    out["three_intersection"] = pts(Intersection(*three()))
    return out


json.dump(cases(), open(sys.argv[1], "w"), indent=0)
