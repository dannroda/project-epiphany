# Publica assets/epiphany/huaca.glb (epi.publish): las piezas de la Huaca de los guerreros (11.26), aparte de lugares.glb
# para no rearmar las demás. El frente mira a -Y, origen en la base.
# blender -b --factory-startup -P tools/blender/build_huaca.py
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

kit = epi.start()


def piece(name, seed, fn, smooth=None):
	p = epi.Piece(seed)
	fn(p)
	return p.build(name, kit, smooth=smooth)


def tarima_huaca(p):
	"""Tarima de 4 × 2 × 0.6 m de la Huaca de los guerreros (11.26), para los arqueros: dos hiladas de pirca en barro
	como las paredes de la chullpa, lajas arriba y el ojo del logo al frente; se sube saltando con la pluma."""
	core = p.box(-1.96, 1.96, -0.96, 0.96, 0.0, 0.56)
	p.paint(core, "tierra", "DARK")
	stones = []
	for row, (z0, z1) in enumerate(((0.0, 0.29), (0.29, 0.56))):
		for side in range(4):
			length = 4.0 if side % 2 == 0 else 2.0
			count = (5 if side % 2 == 0 else 3) + row % 2
			edges = sorted([-length / 2, length / 2] + [-length / 2 + length * (k + p.rng.uniform(0.35, 0.65)) / count for k in range(count - 1)])
			for a, b in zip(edges, edges[1:]):
				stone = p.box(a + 0.03, b - 0.03, -0.12, 0.0, z0 + 0.02, z1 - 0.02, taper=0.02)
				p.jitter(stone, 0.015)
				if side % 2 == 0:
					p.transform(stone, Matrix.Translation((0, -1.0 if side == 0 else 1.0, 0)) @ Matrix.Rotation(0 if side == 0 else math.pi, 4, "Z"))
				else:
					p.transform(stone, Matrix.Translation((2.0 if side == 1 else -2.0, 0, 0)) @ Matrix.Rotation(math.pi / 2 if side == 1 else -math.pi / 2, 4, "Z"))
				stones += stone
	p.paint(stones, "acantilado", z_range=(-0.2, 0.9), vary=0.08)
	flag_floor_top = []
	for c in range(4):
		for r in range(2):
			x0, y0 = -2.0 + c, -1.0 + r
			slab = p.box(x0 + 0.04, x0 + 0.96, y0 + 0.04, y0 + 0.96, 0.56, 0.6 + p.rng.uniform(-0.01, 0.01), taper=0.015)
			p.jitter(slab, 0.01, keep_z=True)
			flag_floor_top += slab
	p.paint(flag_floor_top, "acantilado", "LIGHT", vary=0.08)
	epi.logo_eye(p, Vector((0, -1.12, 0.3)), 0.6, depth=0.03, iris=("cobre_verde", "MID"))


piece("tarima_huaca", 1, tarima_huaca)


def huaca_hundida(p):
	"""Entrada de la Huaca en la Necrópolis: la corona de una chullpa grande enterrada (radio 2 m), que asoma 0.7 m del
	suelo en hiladas de pirca con cornisa, abierta al sur (-Y) donde baja una escalera al negro."""
	gap = 0.42
	stones, mortar = [], []
	for row, (z0, z1, r) in enumerate(((0.0, 0.34, 2.0), (0.34, 0.62, 2.04))):
		count = 22
		for k in range(count):
			a0 = (k + (0.5 if row else 0.0)) / count * 2 * math.pi
			a1 = a0 + 2 * math.pi / count
			mid = (a0 + a1) / 2
			if abs(math.atan2(math.sin(mid + math.pi / 2), math.cos(mid + math.pi / 2))) < gap:
				continue
			pts = []
			for a in (a0 + 0.02, a1 - 0.02):
				pts.append((math.cos(a) * (r - 0.38), math.sin(a) * (r - 0.38)))
			outer = [(math.cos(a) * r, math.sin(a) * r) for a in (a1 - 0.02, a0 + 0.02)]
			stone = p.polygon(list(reversed(pts + outer)), z0 + 0.015, z1 - 0.015)
			p.jitter(stone, 0.02)
			stones += stone
	for k in range(26):
		a0 = k / 26 * 2 * math.pi
		a1 = a0 + 2 * math.pi / 26
		if abs(math.atan2(math.sin((a0 + a1) / 2 + math.pi / 2), math.cos((a0 + a1) / 2 + math.pi / 2))) < gap:
			continue
		pts = [(math.cos(a0) * 1.58, math.sin(a0) * 1.58), (math.cos(a1) * 1.58, math.sin(a1) * 1.58), (math.cos(a1) * 2.14, math.sin(a1) * 2.14), (math.cos(a0) * 2.14, math.sin(a0) * 2.14)]
		mortar += p.polygon(list(reversed(pts)), 0.62, 0.7)
	p.paint(stones, "acantilado", z_range=(-0.3, 1.0), vary=0.08)
	p.paint(mortar, "tierra", "MID", vary=0.05)
	inside = p.cylinder(1.62, 0.0, 0.03, sides=24)
	p.paint(inside, "noche", "DARK")
	for i, (y, shade) in enumerate(((-1.75, "MID"), (-1.4, "LOW"), (-1.05, "DARK"))):
		step = p.box(-0.62, 0.62, y - 0.17, y + 0.17, 0.0, 0.2 - i * 0.07)
		p.paint(step, "acantilado", shade, vary=0.04)


piece("huaca_hundida", 2, huaca_hundida)

epi.layout(kit, columns=2, spacing=5.0)
epi.publish("huaca")
