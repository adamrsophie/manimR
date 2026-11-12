# Reference values from Python manim 0.20.1 for tests/testthat/test-utils-misc.R.
# Run from an empty directory: python -I data-raw/utils_misc_oracle.py OUT.json
import json, sys
from pathlib import Path
import numpy as np
from manim.utils.iterables import (adjacent_n_tuples, adjacent_pairs, concatenate_lists, list_difference_update,
    list_update, listify, make_even, make_even_by_cycling, remove_list_redundancies, remove_nones,
    stretch_array_to_length, tuplify)
from manim.utils.config_ops import merge_dicts_recursively
from manim.utils.images import drag_pixels, invert_image, change_to_rgba_array
from manim.utils.file_ops import add_extension_if_not_present
from manim.utils.simple_functions import clip

o = {}
o["adjacent_n_tuples"] = [list(t) for t in adjacent_n_tuples([1, 2, 3, 4, 5], 3)]
o["adjacent_pairs"] = [list(t) for t in adjacent_pairs([1, 2, 3, 4])]
o["concatenate_lists"] = concatenate_lists([1, 2], [3], [], [4, 5])
o["list_difference_update"] = list_difference_update([1, 2, 3, 4, 2], [2, 5])
o["list_update"] = list_update([1, 2, 3, 4], [2, 5])
o["listify_str"] = listify("abc")
o["listify_list"] = listify((1, 2))
o["listify_scalar"] = listify(7)
o["tuplify"] = list(tuplify([3, 4]))
o["make_even"] = [list(x) for x in make_even([1, 2, 3], [4, 5, 6, 7, 8])]
o["make_even_by_cycling"] = [list(x) for x in make_even_by_cycling([1, 2, 3], [1, 2, 3, 4, 5, 6, 7])]
o["remove_list_redundancies"] = remove_list_redundancies([1, 2, 1, 3, 2, 4])
o["remove_nones"] = remove_nones([0, 1, None, "", "a", 2, False, True])
o["stretch_array_to_length"] = stretch_array_to_length(np.array([10, 20, 30]), 7).tolist()
o["merge_dicts"] = merge_dicts_recursively({"a": 1, "b": {"x": 1, "y": 2}, "c": 3},
                                           {"b": {"y": 20, "z": 30}, "c": {"k": 1}}, {"a": 5})
frames = [np.array([[0, 5], [0, 0]]), np.array([[7, 1], [0, 2]]), np.array([[9, 9], [3, 9]])]
o["drag_pixels"] = [f.tolist() for f in drag_pixels([f.copy() for f in frames])]
img = np.array([[[0, 10, 255], [100, 200, 50]]], dtype=np.uint8)
o["invert_image"] = np.array(invert_image(img)).tolist()
o["rgba_from_2d"] = change_to_rgba_array(np.array([[1, 2], [3, 4]], dtype=np.uint8)).tolist()
o["rgba_from_rgb"] = change_to_rgba_array(np.array([[[1, 2, 3]]], dtype=np.uint8)).tolist()
o["ext"] = [str(add_extension_if_not_present(Path(p), e)) for p, e in
            [("scene", ".png"), ("scene.png", ".png"), ("scene.txt", ".png"), ("dir/a.b", ".svg")]]
o["clip"] = [clip(5, 0, 3), clip(-1, 0, 3), clip(2, 0, 3)]
json.dump(o, open(sys.argv[1], "w"), indent=1)
