# Arma assets/epiphany/palette.png: 8 × 4 franjas de 128 × 256 px, cada una un degradé de claro (arriba) a oscuro (abajo).
# blender -b -P tools/blender/make_palette.py
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from epiphany_palette import COLS, ROWS, SWATCHES, rgb  # noqa: E402

W, H = 1024 // COLS, 1024 // ROWS
out = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "assets", "epiphany", "palette.png")
size_x, size_y = COLS * W, ROWS * H
img = bpy.data.images.new("palette", size_x, size_y, alpha=False)
px = [0.0] * (size_x * size_y * 4)
for i, (_name, top, bottom) in enumerate(SWATCHES):
	col, row = i % COLS, i // COLS
	a, b = rgb(top), rgb(bottom)
	for y in range(H):
		t = y / (H - 1)
		c = [b[k] + (a[k] - b[k]) * t for k in range(3)]
		py = (ROWS - 1 - row) * H + y
		for x in range(W):
			o = (py * size_x + col * W + x) * 4
			px[o:o + 4] = (c[0], c[1], c[2], 1.0)
img.pixels.foreach_set(px)
img.filepath_raw = out
img.file_format = "PNG"
img.save()
print("palette:", out)
