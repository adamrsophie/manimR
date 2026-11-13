"""Render ImageMobjects with upstream's Cairo camera for manimR's tests of
image drawing (Pillow's perspective transform and the paste box).

Run with a Python that has manim installed:

    python data-raw/image_frame_oracle.py tests/testthat/fixtures/image_frames.png

The PNG holds the 160 x 90 RGB frames of the cases below side by side.
"""

import sys

import numpy as np
from PIL import Image
from manim import RESAMPLING_ALGORITHMS, RIGHT, UP, Camera, ImageMobject, config

config.pixel_width = 160
config.pixel_height = 90

# A 6 x 9 RGBA image, opaque in its top half; the test builds the same one.
i, j, k = np.meshgrid(np.arange(6), np.arange(9), np.arange(4), indexing="ij")
src = ((i * 37 + j * 91 + k * 53) % 256).astype(np.uint8)
src[:3, :, 3] = 255

CASES = [
    lambda m: None,
    lambda m: m.scale(3.3),
    lambda m: m.scale(2.2).rotate(0.6),
    lambda m: m.scale(2).apply_matrix([[1, 0.4, 0], [0.1, 1, 0], [0, 0, 1]]),
    lambda m: m.scale(1.7).shift(2.3 * RIGHT + 0.7 * UP),
    lambda m: m.scale(30),
    lambda m: m.scale(2.5).set_resampling_algorithm(RESAMPLING_ALGORITHMS["nearest"]),
    lambda m: m.scale(2.5).rotate(0.3).set_resampling_algorithm(RESAMPLING_ALGORITHMS["linear"]),
    lambda m: m.scale(2.5).set_opacity(0.4),
    lambda m: m.scale(0.3),
]

frames = []
for case in CASES:
    m = ImageMobject(src.copy())
    case(m)
    cam = Camera()
    cam.capture_mobject(m)
    frames.append(cam.pixel_array[:, :, :3])
Image.fromarray(np.concatenate(frames, axis=1), "RGB").save(sys.argv[1])
