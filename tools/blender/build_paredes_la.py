# Publica assets/epiphany/paredes_la.glb: paredes de mazmorra a lo Link's Awakening (prueba sobre la Chullpa).
# Cada pieza es una celda de pared que baja en rampa hacia los lados con piso, igual en las cuatro caras de la sala.
# Las formas salen de tools/paredes_la.json (godot ... tools/la_walls.gd -- export): lados con piso (n e s o) y esquinas sueltas.
# Las puertas (paso) son la misma pared con un corte de 1.4 m; las escaleras (sube, baja) un corte ciego con escalones.
# blender -b -P tools/blender/build_paredes_la.py
import json
import math
import os
import random
import sys

from mathutils import Vector


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HEIGHT = 3.0
N = 40
## Como en LA: paredes casi verticales de bloques de roca con la cresta arriba; una sola pared entre dos salas. La
## sur (piso al norte) va tendida: su cara no se ve y así tapa poco piso.
RUN = {"n": 1.4, "s": 0.5, "e": 0.5, "o": 0.5}
## Rocas como en LA: facetadas (frente plano y costados en bisel), de anchos distintos, con una grieta entre cada una.
## Cortes de cada celda a lo largo de la pared (de -1 a 1), distintos por lado para que no se repitan iguales.
SPLITS = {"s": (-1.0, 0.3, 1.0), "e": (-1.0, -0.25, 1.0), "o": (-1.0, 0.15, 1.0)}
BULGE = 0.7
BEVEL = 0.25
## Pilares en las esquinas de la sala y a los lados de las puertas: a ras de la pared, que el borde de hojas los cubre.
PILLAR = HEIGHT
PILLAR_SIZE = 0.6
CORNERS = ("ne", "no", "se", "so")
MARGIN = 2.0
STONE = "acantilado"
kit = epi.start()


def dist(x, y, side):
	return {"n": 1 - y, "s": y + 1, "e": 1 - x, "o": x + 1}[side]


def run(side, x, y):
	if side == "n":
		return RUN[side]
	along = x if side in "ns" else y
	cuts = SPLITS[side]
	k = max(i for i in range(len(cuts) - 1) if along >= cuts[i] or i == 0)
	t = (along - cuts[k]) / (cuts[k + 1] - cuts[k])
	bump = min(1.0, min(t, 1.0 - t) * (cuts[k + 1] - cuts[k]) / BEVEL)
	return RUN[side] * (1.0 + BULGE * 0.5 - BULGE * bump)


def profile(side, d, x=0.0, y=0.0):
	return HEIGHT * max(0.0, min(1.0, d / run(side, x, y)))


def height(x, y, sides, corners):
	"""El más bajo de los perfiles de los lados con piso a menos de MARGIN; las esquinas sueltas son la unión de sus dos
	perfiles. Sin ninguno cerca, el alto."""
	near = [profile(side, dist(x, y, side), x, y) for side in sides if dist(x, y, side) <= MARGIN]
	near += [max(profile(c[0], dist(x, y, c[0]), x, y), profile(c[1], dist(x, y, c[1]), x, y)) for c in corners if c in CORNERS]
	return min(near) if near else HEIGHT


def pillar(x, y, sides, corners, cut):
	for c in corners:
		if c in CORNERS and all(RUN[s] <= dist(x, y, s) <= RUN[s] + PILLAR_SIZE for s in c):
			return True
		if c.startswith("p") and len(sides) == 1 and dist(x, y, c[1]) <= PILLAR_SIZE and dist(x, y, sides[0]) >= RUN[sides[0]]:
			return True
	return cut == "paso" and len(sides) == 1 and dist(x, y, sides[0]) >= RUN[sides[0]]


def pillar_edges(sides, corners, cut):
	edges = []
	for c in corners:
		if c in CORNERS:
			edges += [(s, RUN[s] - 0.01) for s in c] + [(s, RUN[s]) for s in c]
			edges += [(s, RUN[s] + PILLAR_SIZE) for s in c] + [(s, RUN[s] + PILLAR_SIZE + 0.01) for s in c]
		elif c.startswith("p") and len(sides) == 1:
			edges += [(c[1], PILLAR_SIZE), (c[1], PILLAR_SIZE + 0.01), (sides[0], RUN[sides[0]] - 0.01), (sides[0], RUN[sides[0]])]
	if cut == "paso" and len(sides) == 1:
		edges += [(sides[0], RUN[sides[0]] - 0.01), (sides[0], RUN[sides[0]])]
	return edges


def rock_tone(c, sides, kind):
	"""Cada roca de la cara con su tono; la grieta entre rocas, oscura."""
	near = [s for s in sides if s in SPLITS]
	if not near:
		return course_tone(c)
	side = min(near, key=lambda s: dist(c.x, c.y, s))
	along = c.x if side in "ns" else c.y
	cuts = SPLITS[side]
	k = max(i for i in range(len(cuts) - 1) if along >= cuts[i] or i == 0)
	gap = min(along - cuts[k], cuts[k + 1] - along)
	if gap < BEVEL * 0.35:
		return 0.08
	tone = 0.3 + 0.35 * random.Random(sum(map(ord, kind + side)) * 31 + k).random()
	return tone + 0.12 * (c.z / HEIGHT - 0.5)


def course_tone(c):
	"""Hiladas de piedra en la rampa: tono por hilada y por bloque, para que se lea mampostería."""
	row = math.floor(c.z / 0.45)
	along = c.x + c.y + row * 0.37
	block = math.floor(along / 0.7)
	return 0.28 + 0.42 * random.Random(block * 7919 + row * 104729).random()


HALF = 0.7
STEP_START = 0.3
STEP_RUN = 0.35
STEP_RISE = 0.25
STEPS = 4


def coord(side, d):
	return {"n": 1 - d, "s": d - 1, "e": 1 - d, "o": d - 1}[side]


def channel(x, y, sides, cut):
	"""Distancia desde la boca y si el punto cae dentro del corte; None si la pieza no tiene corte o el punto queda afuera."""
	if cut == "paso":
		across = x if "n" in sides or "s" in sides else y
		return (0.0, True) if abs(across) < HALF else None
	side = sides[0]
	across = y if side in "eo" else x
	return (dist(x, y, side), True) if abs(across) < HALF else None


def cut_height(d, cut):
	if cut == "paso" or d < STEP_START:
		return 0.0
	k = min(STEPS, math.floor((d - STEP_START) / STEP_RUN) + 1)
	return STEP_RISE * k * (1 if cut == "sube" else -1)


def across_x(sides, cut):
	return ("n" in sides or "s" in sides) if cut == "paso" else sides[0] in "ns"


def axes(sides, corners, cut):
	base = [0.5 * t + 0.5 * math.sin(t * math.pi / 2) for t in (-1 + 2 * i / N for i in range(N + 1))]
	xs, ys = set(base), set(base)
	for side in sides:
		for c in SPLITS.get(side, ()):
			for b in (c - BEVEL, c, c + BEVEL):
				if -1.0 < b < 1.0:
					(xs if side in "ns" else ys).add(b)
	for side, d in pillar_edges(sides, corners, cut):
		(ys if side in "ns" else xs).add(coord(side, d))
	if cut:
		for b in (-HALF, -HALF + 0.01, HALF - 0.01, HALF):
			(xs if across_x(sides, cut) else ys).add(b)
		if cut != "paso":
			side = sides[0]
			for k in range(STEPS + 1):
				d = STEP_START + k * STEP_RUN
				for b in (d - 0.01, d):
					(ys if side in "ns" else xs).add(coord(side, b))
	return sorted(xs), sorted(ys)


def piece(kind, code, cut=None):
	parts = code.split("_")
	sides = [] if parts[0] == "x" else list(parts[0])
	corners = parts[1:]
	p = epi.Piece(sum(map(ord, kind + code)))
	xs, ys = axes(sides, corners, cut)

	def h(x, y):
		inside = channel(x, y, sides, cut) if cut else None
		if inside:
			return cut_height(inside[0], cut)
		return PILLAR if pillar(x, y, sides, corners, cut) else height(x, y, sides, corners)

	grid = [[p.bm.verts.new((x, y, h(x, y))) for x in xs] for y in ys]
	faces = [p.bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])) for j in range(len(ys) - 1) for i in range(len(xs) - 1)]
	crest = []
	for f in faces:
		f.normal_update()
		c = f.calc_center_median()
		inside = channel(c.x, c.y, sides, cut) if cut else None
		if inside and f.normal.z > 0.9:
			d = inside[0]
			if cut == "paso":
				shade(p, f, "tierra", 0.4)
			elif d > STEP_START + STEPS * STEP_RUN:
				p.paint([f], "noche", "DARK")
			else:
				shade(p, f, "piedra" if cut == "sube" else "gris_4", max(0.06, 0.6 - 0.45 * d / 1.7))
		elif inside and abs(f.normal.x if across_x(sides, cut) else f.normal.y) < 0.5:
			shade(p, f, "piedra" if cut != "baja" else "gris_5", max(0.05, 0.3 - 0.2 * inside[0] / 1.7))
		elif c.z > 0.3 and f.normal.z > 0.95:
			crest.append(f)
		elif c.z > HEIGHT:
			shade(p, f, "piedra", course_tone(c))
		else:
			shade(p, f, STONE, rock_tone(c, sides, kind))
	p.paint(crest, LEAF, "DARK", vary=0.08)
	hedge(p, xs, ys, h)
	if cut:
		for side in sides:
			sill(p, side)
	p.build("%s_la_%s" % (kind, code), kit)


## Umbral de las puertas, como en LA: sobre el piso de la sala, una U de bloques de piedra que rodea la boca del pasillo
## y una losa adentro.
SILL_DEPTH = 1.1
SILL_BLOCK = 0.55
SILL_HEIGHT = 0.15


def sill(p, side):
	sign = 1 if side in "ne" else -1

	def at(along, across):
		return (across, sign * along) if side in "ns" else (sign * along, across)

	def block(a0, a1, c0, c1, z1, round=True):
		(x0, y0), (x1, y1) = at(a0, c0), at(a1, c1)
		box = (min(x0, x1), max(x0, x1), min(y0, y1), max(y0, y1), 0.0, z1)
		faces = p.rounded_box(*box, radius=0.07, segments=2) if round else p.box(*box)
		mid = sum((f.calc_center_median() for f in faces), Vector()) / len(faces)
		for f in faces:
			f.normal_update()
			if f.normal.dot(f.calc_center_median() - mid) < 0:
				f.normal_flip()
		p.fixed.update(faces)
		return faces

	gap = 0.03
	inner = HALF + 0.04
	slab = block(1.0, 1.0 + SILL_DEPTH, -inner, inner, 0.03, round=False)
	for f in slab:
		shade(p, f, STONE, 0.55)
	blocks = []
	rows = round((SILL_DEPTH + SILL_BLOCK) / SILL_BLOCK)
	length = (SILL_DEPTH + SILL_BLOCK) / rows
	for k in range(rows):
		a0 = 1.0 + k * length + gap
		for c0 in (-inner - SILL_BLOCK, inner):
			blocks.append(block(a0, a0 + length - gap * 2, c0 + gap, c0 + SILL_BLOCK - gap, SILL_HEIGHT * p.rng.uniform(0.85, 1.1)))
	across = 2 * inner
	cols = max(1, round(across / SILL_BLOCK))
	width = across / cols
	a0 = 1.0 + SILL_DEPTH + gap
	for k in range(cols):
		c0 = -inner + k * width
		blocks.append(block(a0, a0 + SILL_BLOCK - gap * 2, c0 + gap, c0 + width - gap, SILL_HEIGHT * p.rng.uniform(0.85, 1.1)))
	for faces in blocks:
		t = p.rng.uniform(0.25, 0.4)
		for f in faces:
			shade(p, f, STONE, t if f.normal.z > 0.7 else t - 0.12)


## Borde de hojas como en LA: escamas de hojas que tapan el borde de la cresta y caen un poco sobre la roca, y cada
## tanto una enredadera que cuelga por la cara.
LEAF = "follaje"
LEAF_SIZE = 0.32
LEAF_ROWS = (-0.15, 0.15, 0.45, 0.75)
LEAF_DROOP = 0.22
VINE_CHANCE = 0.4
VINE_LENGTH = (0.9, 1.8)


def hedge(p, xs, ys, h):
	edges = []
	for j, y in enumerate(ys):
		for i, x in enumerate(xs):
			if h(x, y) < HEIGHT - 0.01:
				continue
			for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				if 0 <= i + di < len(xs) and 0 <= j + dj < len(ys) and h(xs[i + di], ys[j + dj]) < HEIGHT - 0.3:
					edges.append((x, y, xs[i + di] - x, ys[j + dj] - y))
					break
	taken = set()
	leaves = []
	spots = []
	for x, y, ox, oy in edges:
		length = math.hypot(ox, oy)
		ox, oy = ox / length, oy / length
		for k, back in enumerate(LEAF_ROWS):
			lx, ly = x - ox * back, y - oy * back
			key = (round(lx / LEAF_SIZE), round(ly / LEAF_SIZE), k)
			if key in taken or abs(lx) > 1.15 or abs(ly) > 1.15:
				continue
			taken.add(key)
			z = HEIGHT + 0.05 - (LEAF_DROOP if back < 0 else 0.0)
			r = LEAF_SIZE * p.rng.uniform(0.85, 1.15)
			leaves += p.blob((lx, ly, z), r, squash=(1.0, 1.0, 0.4), subdiv=1, rough=0.2)
			if k == 0:
				spots.append((lx, ly, ox, oy))
	p.paint(leaves, LEAF, vary=0.25)
	vine = []
	for lx, ly, ox, oy in spots:
		if p.rng.random() > VINE_CHANCE / 6.0:
			continue
		length = p.rng.uniform(*VINE_LENGTH)
		z = HEIGHT - LEAF_DROOP - 0.1
		side = 1
		while z > HEIGHT - length:
			t = 0.0
			while t < 2.0 and h(lx + ox * t, ly + oy * t) >= z:
				t += 0.02
			wx, wy = lx + ox * (t + 0.05), ly + oy * (t + 0.05)
			vine += p.blob((wx - oy * 0.07 * side, wy + ox * 0.07 * side, z), 0.09, squash=(1.0, 1.0, 0.6), subdiv=1, rough=0.2)
			side = -side
			z -= 0.17
	p.paint(vine, LEAF, vary=0.15)


def shade(p, f, swatch, t):
	c = f.calc_center_median()
	p.paint([f], swatch, z_range=(c.z - t * 2.0, c.z + (1 - t) * 2.0))


shapes = json.load(open(os.path.join(ROOT, "tools", "paredes_la.json")))
for code in shapes["pared"]:
	piece("pared", code)
for kind in ("paso", "sube", "baja"):
	for code in shapes[kind]:
		piece(kind, code, kind)
epi.layout(kit, columns=6, spacing=3.0)
epi.publish("paredes_la")
