# Arma assets/epiphany/palette.png: 8 × 4 franjas de 128 × 256 px, cada una un degradé de claro (arriba) a oscuro (abajo),
# palette_emission.png (negra salvo las franjas de EMISSIVE) y el par de cada paleta de VARIANTS.
# blender -b -P tools/blender/make_palette.py
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from epiphany_palette import COLS, EMISSIVE, ROWS, SWATCHES, VARIANTS, rgb  # noqa: E402

W, H = 1024 // COLS, 1024 // ROWS
folder = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "assets", "epiphany")
size_x, size_y = COLS * W, ROWS * H


def write(name, only=None, swaps=None):
	img = bpy.data.images.new(name, size_x, size_y, alpha=False)
	px = [0.0] * (size_x * size_y * 4)
	for i, (swatch, top, bottom) in enumerate(SWATCHES):
		col, row = i % COLS, i // COLS
		top, bottom = (swaps or {}).get(swatch, (top, bottom))
		a, b = rgb(top), rgb(bottom)
		if only is not None and swatch not in only:
			a = b = (0.0, 0.0, 0.0)
		for y in range(H):
			t = y / (H - 1)
			c = [b[k] + (a[k] - b[k]) * t for k in range(3)]
			py = (ROWS - 1 - row) * H + y
			for x in range(W):
				o = (py * size_x + col * W + x) * 4
				px[o:o + 4] = (c[0], c[1], c[2], 1.0)
	img.pixels.foreach_set(px)
	img.filepath_raw = os.path.join(folder, name + ".png")
	img.file_format = "PNG"
	img.save()
	print("palette:", img.filepath_raw)


write("palette")
write("palette_emission", EMISSIVE)
for variant, swaps in VARIANTS.items():
	write(f"palette_{variant}", swaps=swaps)
	write(f"palette_{variant}_emission", EMISSIVE, swaps)
