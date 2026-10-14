# Publica assets/epiphany/trampilla.glb (epi.publish): la trampilla de la Chullpa (el piso que se abre al vencer al
# guardián): un marco de piedra que asoma alrededor del hueco de 2 × 2 m y una hoja de losa con media chakana tallada y
# una argolla de cobre. La hoja tiene el origen en la bisagra y va hacia +X; la otra es la misma girada.
# blender -b -P tools/blender/build_trampilla.py
import os
import sys

from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

HALF = 1.0
FRAME = 0.22
STONE = "acantilado"
METAL = "cobre_verde"
GAP = 0.025

kit = epi.start()


def piece(name, seed, fn):
	p = epi.Piece(seed)
	fn(p)
	return p.build(name, kit, smooth=35)


def marco(p):
	"""Cordón de piedra alrededor del hueco, apenas sobre el piso, con un escalón en cada esquina."""
	curbs = []
	out = HALF + FRAME
	for x0, x1, y0, y1 in ((-out, out, HALF, out), (-out, out, -out, -HALF), (-out, -HALF, -HALF, HALF), (HALF, out, -HALF, HALF)):
		curbs += p.rounded_box(x0 + 0.01, x1 - 0.01, y0 + 0.01, y1 - 0.01, -0.1, 0.05, radius=0.03, segments=1)
	p.jitter(curbs, 0.006)
	p.paint(curbs, STONE, "MID", vary=0.05)
	steps = []
	for sx in (-1, 1):
		for sy in (-1, 1):
			s = p.rounded_box(-0.12, 0.12, -0.12, 0.12, 0.05, 0.1, radius=0.02, segments=1)
			p.transform(s, Matrix.Translation((sx * (HALF + FRAME / 2), sy * (HALF + FRAME / 2), 0)))
			steps += s
	p.paint(steps, STONE, "LIGHT", vary=0.03)


def hoja(p):
	"""Media trampilla: losa de la bisagra (x 0) al medio (x HALF), con media chakana tallada junto al medio y una
	argolla de cobre."""
	slab = p.rounded_box(GAP, HALF - GAP, -HALF + GAP, HALF - GAP, -0.12, 0.0, radius=0.03, segments=1)
	p.jitter(slab, 0.004)
	p.paint(slab, STONE, "LOW", vary=0.04)
	carve = []
	for w, h in ((0.12, 0.6), (0.24, 0.36), (0.36, 0.12)):
		carve += p.box(HALF - GAP - w, HALF - GAP - 0.02, -h / 2, h / 2, -0.01, 0.006)
	p.paint(carve, STONE, "DARK", vary=0.02)
	ring = p.lathe([(0.085, -0.012), (0.11, 0.0), (0.085, 0.012), (0.06, 0.0), (0.085, -0.012)], sides=14, caps=False)
	p.transform(ring, Matrix.Translation((HALF * 0.45, 0.0, 0.012)))
	plate = p.cylinder(0.06, 0.0, 0.015, sides=10)
	p.transform(plate, Matrix.Translation((HALF * 0.45, 0.0, 0.0)))
	p.paint(ring + plate, METAL, "MID", vary=0.03)
	under = p.box(0.0, HALF + GAP, -HALF, HALF, -0.14, -0.12)
	p.paint(under, "noche", "DARK")


piece("trampilla_marco", 1, marco)
piece("trampilla_hoja", 2, hoja)
epi.layout(kit, columns=2, spacing=3.0)
epi.publish("trampilla")
