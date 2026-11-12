# Reference values from Python manim 0.20.1 for ManimColor and HSV.
# Run from an empty directory: python -I data-raw/manim_color_oracle.py OUT.json
import json, sys
from manim import ManimColor, HSV, BLUE, RED, WHITE
from manim.utils.color import ManimColor as MC
c = ManimColor("#FF8000")
o = {}
o["to_integer"] = c.to_integer(); o["to_int_rgb"] = c.to_int_rgb().tolist(); o["to_hex_alpha"] = ManimColor("#FF800080").to_hex(True)
o["to_hsv"] = c.to_hsv().tolist(); o["to_hsl"] = c.to_hsl().tolist()
o["invert"] = c.invert().to_rgba().tolist(); o["darker"] = c.darker().to_rgba().tolist(); o["lighter"] = c.lighter(0.5).to_rgba().tolist()
o["interp"] = c.interpolate(BLUE, 0.3).to_rgba().tolist(); o["contrast"] = c.contrasting().to_hex(); o["contrast_dark"] = ManimColor("#202020").contrasting().to_hex()
o["opacity"] = c.opacity(0.3).to_rgba().tolist()
o["add"] = (c + 0.1).to_rgba().tolist(); o["mul"] = (c * ManimColor("#808080")).to_rgba().tolist(); o["and"] = (c & ManimColor("#00FFFF")).to_hex()
o["from_int"] = ManimColor(0x123456).to_hex(); o["from_ints"] = ManimColor((255, 128, 0)).to_rgba().tolist(); o["from_floats"] = ManimColor((0.2, 0.4, 0.6)).to_rgba().tolist()
o["from_hsv"] = MC.from_hsv((0.5, 1.0, 1.0)).to_hex(); o["from_hsl"] = MC.from_hsl((0.25, 1, 0.5)).to_hex()
o["name"] = ManimColor("blue_c").to_hex(); o["short_hex"] = ManimColor("#F80").to_hex()
h = HSV((0.25, 0.5, 0.75)); o["hsv_hex"] = h.to_hex(); h.hue = 0.6; o["hsv_set_hex"] = h.to_hex()
o["hsv_add"] = (HSV((0.25, 0.5, 0.75)) + 0.1).to_hex()
o["into_hsv"] = list(c.into(HSV)._internal_space)
o["eq"] = ManimColor("#FF8000") == ManimColor((1.0, 128/255, 0.0))
json.dump(o, open(sys.argv[1], "w"), indent=1)
