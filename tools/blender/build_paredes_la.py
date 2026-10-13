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

from mathutils import Matrix, Vector, noise


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
## Detalle de las caras: relieve (corre la cara hasta RELIEF m, cero en los bordes de la celda para que empalmen) y musgo que cae desde la cresta y junta en el pie.
RELIEF = 0.08
RELIEF_SCALE = 2.2
MOSS = "musgo"
MOSS_TOP = 0.55
MOSS_FOOT = 0.25
## Paredes finitas sueltas dentro de una sala (nichos, rejas): pared baja con borde de hojas en vez de una pared entera.
LOW = 1.3
LOW_HALF = 0.85
LOW_BEVEL = 0.15
## Hileras de hojas de más para que tapen toda la tapa de la pared baja.
LOW_LEAF_ROWS = (1.05,)
top = HEIGHT
kit = epi.start()

## Estilo de las paredes que se están armando: None (roca de LA con borde de hojas), "chullpa" (pirca de piedra de
## campo en hiladas asentadas en barro, cornisa de barro con matas de ichu) o "quenoa" (la madera del tronco por dentro,
## con vetas que bajan, musgo y hojas arriba) y "cueva" (la roca de LA más oscura, sin hojas: la cresta es de piedra
## y cada tanto cuelga una estalactita) y "templo" (sillares de piedra lavanda bien encajados con cornisa clara, sin
## hojas). La chullpa, la queñoa y el templo van sin el bulto de las rocas.
WALL_STYLE = None
PIRCA_ROW = 0.42
PIRCA_JOINT = 0.04
_pirca_rows = {}
## Piedra, junta y cornisa de las paredes de hiladas (chullpa: pirca en barro; templo: sillares lavanda).
COURSES = {"chullpa": ("acantilado", "tierra", "tierra", True), "templo": ("piedra_templo", "gris_5", "piedra_templo", False)}


def pirca(a, z):
	"""Hilada, piedra y distancia a la junta más cercana en la pirca; las juntas de cada hilada caen en el borde de la
	celda para que las piezas empalmen."""
	row = math.floor(z / PIRCA_ROW)
	if row not in _pirca_rows:
		rr = random.Random(row * 7177 + 13)
		while True:
			cuts = [-1.0] + sorted(rr.uniform(-0.75, 0.75) for _ in range(rr.choice((1, 2, 2, 3)))) + [1.0]
			if all(b - a0 > 0.4 for a0, b in zip(cuts, cuts[1:])):
				break
		_pirca_rows[row] = cuts
	cuts = _pirca_rows[row]
	k = min(len(cuts) - 2, max(i for i in range(len(cuts) - 1) if a >= cuts[i] or i == 0))
	return row, k, min(a - cuts[k], cuts[k + 1] - a, z - row * PIRCA_ROW, (row + 1) * PIRCA_ROW - z)


def grain(a, z):
	"""Vetas de la madera de la Queñoa: de -1 (surco) a 1, que bajan casi derechas y se tuercen un poco."""
	n = noise.noise(Vector((a * 2.5, z * 0.35, 7.0)))
	return math.sin(a * 17.0 + n * 5.0 + z * 0.15)


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


def relief(p):
	p.bm.normal_update()
	for v in p.bm.verts:
		x, y, z = v.co
		window = max(0.0, 1.0 - x * x) * max(0.0, 1.0 - y * y) * min(1.0, z / 0.3, (top - z) / 0.3)
		out = Vector((v.normal.x, v.normal.y, 0.0))
		if window <= 0.0 or out.length < 0.5:
			continue
		a = x if abs(v.normal.y) > abs(v.normal.x) else y
		if WALL_STYLE in COURSES:
			bump = min(1.0, pirca(a, z)[2] / 0.1) * 0.08 + noise.noise(Vector((a, z, 5.0)) * 4.0) * 0.015
		elif WALL_STYLE == "quenoa":
			bump = grain(a, z) * 0.025 + noise.noise(Vector((a * 1.5, z * 0.2, 9.0))) * 0.07
		else:
			bump = noise.noise(Vector((a, z * 0.5, 3.0)) * RELIEF_SCALE) * RELIEF
		v.co += out.normalized() * bump * window
	p.bm.normal_update()


def moss(c, seed):
	q = Vector((c.x + c.y + seed, c.z, c.x - c.y)) * 1.8
	n = 0.5 + 0.5 * noise.noise(q)
	return c.z > top - MOSS_TOP * (0.3 + n) or c.z < MOSS_FOOT * (n * 3.0 - 1.4)


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
	return tone + 0.12 * (c.z / top - 0.5)


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
	if WALL_STYLE in COURSES:
		for side in sides:
			for k in range(1, math.ceil(HEIGHT / PIRCA_ROW)):
				for dz in (-PIRCA_JOINT / 2, PIRCA_JOINT / 2, PIRCA_ROW / 2):
					d = RUN[side] * (k * PIRCA_ROW + dz) / HEIGHT
					if 0.0 < d < 2.0:
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


def low(x, y, sides):
	"""Pared baja: llena la celda hasta LOW_HALF del centro por cada lado con piso, con el borde en bisel."""
	d = min([LOW_HALF - 1.0 + dist(x, y, s) for s in sides] + [1.0])
	return LOW * max(0.0, min(1.0, d / LOW_BEVEL))


def piece(kind, code, cut=None):
	global top
	parts = code.split("_")
	sides = [] if parts[0] == "x" else list(parts[0])
	corners = parts[1:]
	p = epi.Piece(sum(map(ord, kind + code)))
	xs, ys = axes(sides, corners, cut)
	top = LOW if kind == "muro" else HEIGHT
	if kind == "muro":
		for s in sides:
			for b in (LOW_HALF, LOW_HALF - 0.01, LOW_HALF - LOW_BEVEL, LOW_HALF - LOW_BEVEL - 0.01):
				(xs if s in "eo" else ys).extend((b, -b))
		xs, ys = sorted(set(xs)), sorted(set(ys))

	def h(x, y):
		if kind == "muro":
			return low(x, y, sides)
		inside = channel(x, y, sides, cut) if cut else None
		if inside:
			return cut_height(inside[0], cut)
		if pillar(x, y, sides, corners, cut):
			return PILLAR
		return height(x, y, sides, corners)

	grid = [[p.bm.verts.new((x, y, h(x, y))) for x in xs] for y in ys]
	faces = [p.bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])) for j in range(len(ys) - 1) for i in range(len(xs) - 1)]
	relief(p)
	seed = sum(map(ord, kind + code)) % 97 * 0.37
	crest = []
	for f in faces:
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
		elif c.z > top:
			shade(p, f, "piedra", course_tone(c))
		elif WALL_STYLE in COURSES:
			stone, joint, cornice, dusty = COURSES[WALL_STYLE]
			a = c.x if abs(f.normal.y) > abs(f.normal.x) else c.y
			row, k, edge = pirca(a, c.z)
			if c.z > top - 0.22:
				shade(p, f, cornice, 0.42 if dusty else 0.7)
			elif edge < PIRCA_JOINT * 0.75:
				shade(p, f, joint, 0.16 if dusty else 0.3)
			elif dusty and c.z < 0.3 * (0.5 + 0.5 * noise.noise(Vector((c.x + c.y, 0.0, 2.0)) * 2.0)):
				p.paint([f], "tierra", "LOW", vary=0.1)
			else:
				tone = 0.32 + 0.33 * random.Random(row * 104729 + k * 7919 + round(a * 0.5)).random()
				shade(p, f, stone, tone + 0.15 * min(1.0, edge / 0.12) - 0.08)
		elif WALL_STYLE == "cueva":
			if c.z < MOSS_FOOT * (0.5 + noise.noise(Vector((c.x + c.y, 0.0, 6.0)) * 2.0)):
				p.paint([f], "tierra", "LOW", vary=0.1)
			else:
				shade(p, f, STONE, rock_tone(c, sides, kind) * 0.55)
		elif WALL_STYLE == "quenoa" and not moss(c, seed):
			a = c.x if abs(f.normal.y) > abs(f.normal.x) else c.y
			g = grain(a, c.z)
			if g < -0.93:
				shade(p, f, "roca_naranja", 0.12)
			else:
				shade(p, f, "roca_naranja", 0.3 + 0.08 * g + 0.12 * noise.noise(Vector((a * 1.2, c.z * 0.25, 4.0))))
		elif moss(c, seed):
			if c.z < 1.0:
				p.paint([f], MOSS, "LOW", vary=0.15)
			else:
				shade(p, f, MOSS, min(0.8, 0.3 + 0.5 * (c.z - top + MOSS_TOP) / MOSS_TOP))
		else:
			shade(p, f, STONE, rock_tone(c, sides, kind))
	crest_swatch = {"chullpa": ("tierra", "MID"), "cueva": ("gris_4", "MID"), "templo": ("piedra_templo", "LIGHT")}.get(WALL_STYLE, (LEAF, "DARK"))
	p.paint(crest, crest_swatch[0], crest_swatch[1], vary=0.08)
	hedge(p, xs, ys, h)
	if cut:
		for side in sides:
			sill(p, side)
	p.build("%s_la_%s" % (kind, code) if WALL_STYLE is None else "%s_%s_la_%s" % (kind, WALL_STYLE, code), kit)


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
			if h(x, y) < top - 0.01:
				continue
			for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				if 0 <= i + di < len(xs) and 0 <= j + dj < len(ys) and h(xs[i + di], ys[j + dj]) < top - (0.3 if top == HEIGHT else 0.02):
					edges.append((x, y, xs[i + di] - x, ys[j + dj] - y))
					break
	taken = set()
	leaves = []
	spots = []
	for x, y, ox, oy in edges:
		length = math.hypot(ox, oy)
		ox, oy = ox / length, oy / length
		for k, back in enumerate(LEAF_ROWS if top == HEIGHT else LEAF_ROWS + LOW_LEAF_ROWS):
			lx, ly = x - ox * back, y - oy * back
			key = (round(lx / LEAF_SIZE), round(ly / LEAF_SIZE), k)
			if key in taken or abs(lx) > 1.15 or abs(ly) > 1.15:
				continue
			taken.add(key)
			z = top + 0.05 - (LEAF_DROOP if back < 0 else 0.0)
			r = LEAF_SIZE * p.rng.uniform(0.85, 1.15)
			leaves += p.blob((lx, ly, z), r, squash=(1.0, 1.0, 0.4), subdiv=1, rough=0.2)
			if k == 0:
				spots.append((lx, ly, ox, oy))
	if WALL_STYLE == "chullpa":
		p.paint(leaves, "tierra", vary=0.12)
		ichu(p, spots)
		return
	if WALL_STYLE == "templo":
		p.paint(leaves, "piedra_templo", "LIGHT", vary=0.05)
		return
	if WALL_STYLE == "cueva":
		p.paint(leaves, "gris_4", vary=0.15)
		stalactites(p, spots, h)
		return
	p.paint(leaves, LEAF, vary=0.25)
	vine = []
	for lx, ly, ox, oy in spots:
		if top < HEIGHT or p.rng.random() > VINE_CHANCE * (2.5 if WALL_STYLE == "quenoa" else 1.0) / 6.0:
			continue
		length = p.rng.uniform(*VINE_LENGTH)
		z = top - LEAF_DROOP - 0.1
		side = 1
		while z > top - length:
			t = 0.0
			while t < 2.0 and h(lx + ox * t, ly + oy * t) >= z:
				t += 0.02
			wx, wy = lx + ox * (t + 0.05), ly + oy * (t + 0.05)
			vine += p.blob((wx - oy * 0.07 * side, wy + ox * 0.07 * side, z), 0.09, squash=(1.0, 1.0, 0.6), subdiv=1, rough=0.2)
			side = -side
			z -= 0.17
	p.paint(vine, LEAF, vary=0.15)


def ichu(p, spots):
	"""Matas de ichu sobre la cornisa de barro de la Chullpa: hojas finas y duras que se abren hacia afuera."""
	blades = []
	for lx, ly, ox, oy in spots:
		if p.rng.random() > 0.3:
			continue
		for i in range(7):
			blade = p.cylinder(0.025, 0.0, p.rng.uniform(0.3, 0.55), sides=4, radius_top=0.0)
			lean = Matrix.Rotation(p.rng.uniform(0.15, 0.6), 4, Vector((math.cos(i * 0.9), math.sin(i * 0.9), 0.0)))
			p.transform(blade, Matrix.Translation((lx - ox * 0.15, ly - oy * 0.15, top - 0.02)) @ lean)
			blades += blade
	p.paint(blades, "paja", vary=0.12)


def stalactites(p, spots, h):
	"""Estalactitas que cuelgan del borde de la cresta de la cueva, pegadas a la cara."""
	drops = []
	for lx, ly, ox, oy in spots:
		if top < HEIGHT or p.rng.random() > 0.2:
			continue
		length = p.rng.uniform(0.35, 0.8)
		t = 0.0
		while t < 2.0 and h(lx + ox * t, ly + oy * t) >= top - length * 0.5:
			t += 0.02
		drop = p.cylinder(p.rng.uniform(0.07, 0.11), 0.0, length, sides=6, radius_top=0.0)
		p.transform(drop, Matrix.Translation((lx + ox * (t + 0.02), ly + oy * (t + 0.02), top - 0.05)) @ Matrix.Rotation(math.pi, 4, "X"))
		drops += drop
	p.paint(drops, STONE, "LOW", vary=0.1)


SHADE_SPAN = 20.0


def shade(p, f, swatch, t):
	c = f.calc_center_median()
	p.paint([f], swatch, z_range=(c.z - t * SHADE_SPAN, c.z + (1 - t) * SHADE_SPAN))


shapes = json.load(open(os.path.join(ROOT, "tools", "paredes_la.json")))
for WALL_STYLE, BULGE, STONE in ((None, 0.7, "acantilado"), ("chullpa", 0.0, "acantilado"), ("quenoa", 0.0, "madera"), ("cueva", 0.7, "acantilado"), ("templo", 0.0, "piedra_templo")):
	PIRCA_ROW = 0.48 if WALL_STYLE == "templo" else 0.42
	_pirca_rows.clear()
	for code in shapes["pared"]:
		piece("pared", code)
	for code in shapes.get("muro", []):
		piece("muro", code)
	for kind in ("paso", "sube", "baja"):
		for code in shapes[kind]:
			piece(kind, code, kind)
## Hojas de puerta del alto de la pared, para el corte del paso (2 HALF de ancho); el frente mira a -Y y el código la
## inclina como la cara de la pared de cada sala.
DOOR_WIDTH = HALF + 0.03
DOOR_THICK = 0.15
DOOR_PLANKS = 4


## Estilo de las hojas que se están armando: None (madera con flejes de hierro), "chullpa" (losas de piedra con un
## escalonado en relieve y herrajes de cobre) o "quenoa" (tablones atados con soga y musgo arriba).
DOOR_STYLE = None
METAL = {None: "hierro", "chullpa": "cobre_verde", "quenoa": "paja", "templo": "dorado"}
## Piedra de las hojas de losa (chullpa y templo).
SLAB = {"chullpa": "acantilado", "templo": "piedra_templo"}


def stone_leaf(p, dark):
	"""Tres losas apiladas de cantos gastados y un escalonado (media chakana) en relieve arriba."""
	slabs = []
	z = 0.0
	for h in (1.15, 1.0, HEIGHT - 2.15):
		slabs += p.rounded_box(-DOOR_WIDTH + 0.01, DOOR_WIDTH - 0.01, -DOOR_THICK, DOOR_THICK, z + 0.015, z + h - 0.015, radius=0.06, segments=2)
		z += h
	p.jitter(slabs, 0.01)
	p.paint(slabs, SLAB[DOOR_STYLE], "LOW" if dark else "MID", vary=0.05)
	steps = []
	for k, (w, h) in enumerate(((0.9, 0.12), (0.62, 0.12), (0.34, 0.12))):
		z0 = 2.32 + k * 0.12
		steps += p.box(-w / 2, w / 2, -DOOR_THICK - 0.035, -DOOR_THICK + 0.01, z0, z0 + h - 0.015)
	p.paint(steps, SLAB[DOOR_STYLE] if DOOR_STYLE == "chullpa" else "dorado", "LIGHT", vary=0.03)


def door_leaf(p, wood, bands=(0.55, 2.45)):
	if DOOR_STYLE in SLAB:
		stone_leaf(p, wood == "madera_oscura")
		return
	planks = []
	w = 2 * DOOR_WIDTH / DOOR_PLANKS
	for k in range(DOOR_PLANKS):
		x0 = -DOOR_WIDTH + k * w
		faces = p.rounded_box(x0 + 0.012, x0 + w - 0.012, -DOOR_THICK, DOOR_THICK, 0.0, HEIGHT - 0.02 * (k % 2), radius=0.03, segments=1)
		p.paint(faces, wood, z_range=(-1.0 - 0.6 * (k % 3), HEIGHT + 1.5), vary=0.03)
		planks += faces
	if DOOR_STYLE == "quenoa":
		rope = []
		for z in bands:
			for dz in (-0.05, 0.05):
				rope += p.rounded_box(-DOOR_WIDTH - 0.01, DOOR_WIDTH + 0.01, -DOOR_THICK - 0.035, -DOOR_THICK + 0.01, z + dz - 0.035, z + dz + 0.035, radius=0.03, segments=1)
		p.paint(rope, "paja", "MID", vary=0.04)
		moss = []
		for k in range(5):
			x = -DOOR_WIDTH + 0.15 + k * (2 * DOOR_WIDTH - 0.3) / 4
			moss += p.blob((x, -DOOR_THICK * 0.5, HEIGHT - 0.02), p.rng.uniform(0.14, 0.2), squash=(1.4, 1.0, 0.6), subdiv=1, rough=0.25)
		p.paint(moss, "musgo", "MID", vary=0.08)
		return
	iron = []
	for z in bands:
		iron += p.rounded_box(-DOOR_WIDTH - 0.01, DOOR_WIDTH + 0.01, -DOOR_THICK - 0.04, -DOOR_THICK + 0.01, z - 0.09, z + 0.09, radius=0.02, segments=1)
		for x in (-DOOR_WIDTH + 0.12, DOOR_WIDTH - 0.12):
			stud = p.cylinder(0.045, 0.0, 0.035, sides=8)
			p.transform(stud, Matrix.Translation((x, -DOOR_THICK - 0.04, z)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
			iron += stud
	p.paint(iron, "hierro", "DARK", vary=0.03)


def lock_plate(p, z, size, metal):
	plate = p.rounded_box(-size * 0.55, size * 0.55, -DOOR_THICK - 0.07, -DOOR_THICK + 0.01, z - size * 0.75, z + size * 0.75, radius=0.04, segments=1)
	p.paint(plate, metal, "MID", vary=0.03)
	hole = p.cylinder(size * 0.17, 0.0, 0.02, sides=12)
	slot = p.box(-size * 0.07, size * 0.07, -0.01, 0.01, -size * 0.45, 0.0)
	p.transform(hole, Matrix.Translation((0, -DOOR_THICK - 0.07, z + size * 0.12)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	p.transform(slot, Matrix.Translation((0, -DOOR_THICK - 0.075, z + size * 0.12)))
	p.paint(hole + slot, "noche", "MID")


def door(name, seed, fn):
	p = epi.Piece(seed)
	fn(p)
	p.build("puerta_%s%s_la" % (name, "_" + DOOR_STYLE if DOOR_STYLE else ""), kit, smooth=35)


def door_switch(p):
	door_leaf(p, "madera_oscura")
	emblem = epi.eye(p, Vector((0, -DOOR_THICK - 0.01, 1.5)), 0.42, depth=0.05, pupil_swatch="noche")
	p.paint(emblem, "sello", "LIGHT")


def door_boss(p):
	door_leaf(p, "madera_oscura", bands=(0.4, 2.6))
	frame = []
	for x0, x1, z0, z1 in ((-DOOR_WIDTH, DOOR_WIDTH, HEIGHT - 0.16, HEIGHT), (-DOOR_WIDTH, -DOOR_WIDTH + 0.14, 0.0, HEIGHT), (DOOR_WIDTH - 0.14, DOOR_WIDTH, 0.0, HEIGHT)):
		frame += p.rounded_box(x0, x1, -DOOR_THICK - 0.06, -DOOR_THICK + 0.01, z0, z1, radius=0.03, segments=1)
	p.paint(frame, "dorado", "MID", vary=0.03)
	emblem = epi.eye(p, Vector((0, -DOOR_THICK - 0.01, 2.05)), 0.4, depth=0.05, pupil_swatch="noche")
	p.paint(emblem, "doom", "MID")
	lock_plate(p, 1.15, 0.6, "dorado")


def door_shutter(p):
	slats = []
	n = 9
	for k in range(n):
		z0 = HEIGHT * k / n
		slats += p.rounded_box(-DOOR_WIDTH, DOOR_WIDTH, -DOOR_THICK - 0.03 * (k % 2), DOOR_THICK, z0 + 0.015, z0 + HEIGHT / n - 0.015, radius=0.03, segments=1)
	p.paint(slats, SLAB.get(DOOR_STYLE, "madera_oscura"), z_range=(-1.0, HEIGHT + 1.0), vary=0.04)
	posts = []
	for x in (-DOOR_WIDTH + 0.1, DOOR_WIDTH - 0.1):
		posts += p.rounded_box(x - 0.06, x + 0.06, -DOOR_THICK - 0.08, -DOOR_THICK, 0.0, HEIGHT, radius=0.02, segments=1)
	p.paint(posts, METAL[DOOR_STYLE], "DARK", vary=0.03)


for DOOR_STYLE in (None, "chullpa", "quenoa", "templo"):
	door("madera", 61, lambda p: door_leaf(p, "madera"))
	door("llave", 62, lambda p: (door_leaf(p, "madera_oscura"), lock_plate(p, 1.3, 0.5, METAL[DOOR_STYLE] if DOOR_STYLE in SLAB else "hierro")))
	door("jefe", 63, door_boss)
	door("interruptor", 64, door_switch)
	door("persiana", 65, door_shutter)

epi.layout(kit, columns=6, spacing=3.0)
epi.publish("paredes_la")
