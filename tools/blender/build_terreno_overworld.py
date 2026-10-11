# Arma assets/epiphany/terreno_overworld.blend: piezas de una celda de 2 × 2 m para el GridMap del overworld.
# blender -b -P tools/blender/build_terreno_overworld.py
import math
import os
import sys

import bmesh
from mathutils import Matrix, Vector, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

TOP = 2.6
CAP = 0.15

kit = epi.start()


def ground(p, swatch="pasto"):
	faces = p.box(-1, 1, -1, 1, -0.5, 0)
	p.paint([f for f in faces if f.normal.z <= 0.5], "tierra", z_range=(-0.5, 0.0))
	p.paint([f for f in faces if f.normal.z > 0.5], swatch, "MID")


def flower(p, x, y, color):
	"""Ramito de 3–5 flores."""
	stems, heads = [], []
	for _ in range(p.rng.randint(3, 5)):
		fx, fy = x + p.rng.uniform(-0.1, 0.1), y + p.rng.uniform(-0.1, 0.1)
		h = 0.18 + p.rng.random() * 0.14
		stems += p.box(fx - 0.018, fx + 0.018, fy - 0.018, fy + 0.018, 0, h)
		heads += p.blob((fx, fy, h + 0.04), 0.075, subdiv=1, rough=0.0, squash=(1, 1, 0.55))
	p.paint(stems, "follaje", "DARK")
	p.paint(heads, color, "LIGHT", vary=0.1)


def small_rock(p, x, y, size):
	p.paint(p.blob((x, y, 0.0), size, squash=(1.3, 1.0, 0.55), subdiv=1, rough=0.3, flat_bottom=0.0), "piedra", vary=0.12)


def ichu(p, x, y, height=0.55, blades=9, swatch="paja"):
	"""Mata de paja brava: hojas finas de tres caras que se abren desde el centro."""
	faces = []
	for i in range(blades):
		a = 2 * math.pi * i / blades + p.rng.random() * 0.6
		lean = 0.25 + p.rng.random() * 0.35
		h = height * (0.65 + p.rng.random() * 0.45)
		blade = p.cylinder(0.035, 0.0, h, sides=3, radius_top=0.0, cap_bottom=False, phase=p.rng.random() * 3)
		tilt = Matrix.Rotation(lean, 4, Vector((-math.sin(a), math.cos(a), 0)))
		p.transform(blade, Matrix.Translation((x + math.cos(a) * 0.05, y + math.sin(a) * 0.05, 0)) @ tilt)
		faces += blade
	p.paint(faces, swatch, z_range=(0.0, height))
	return faces


def jagged(p, a, b, steps, amount):
	"""Puntos de a a b con el medio corrido al azar (los extremos quedan fijos, así las piezas empalman)."""
	pts = []
	for i in range(steps + 1):
		t = i / steps
		x = a[0] + (b[0] - a[0]) * t
		y = a[1] + (b[1] - a[1]) * t
		if 0 < i < steps:
			nx, ny = -(b[1] - a[1]), b[0] - a[0]
			n = math.hypot(nx, ny)
			d = (p.rng.random() - 0.5) * 2 * amount
			x += nx / n * d
			y += ny / n * d
		pts.append((x, y))
	return pts


def dirt_patch(p, points):
	p.paint(p.polygon(points, 0.0, 0.012), "tierra", "MID", vary=0.0)


def slabs(p, grid=3, z0=-0.035, z1=0.0, gap=0.035, skip=(), half=1.0):
	"""Lajas irregulares: una grilla con los puntos de adentro corridos; los del borde quedan en el borde."""
	n = grid
	pts = [[None] * (n + 1) for _ in range(n + 1)]
	for i in range(n + 1):
		for j in range(n + 1):
			x = (-1 + 2 * i / n) * half
			y = (-1 + 2 * j / n) * half
			if 0 < i < n:
				x += (p.rng.random() - 0.5) * 0.3
			if 0 < j < n:
				y += (p.rng.random() - 0.5) * 0.3
			pts[i][j] = (x, y)
	stones = []
	for i in range(n):
		for j in range(n):
			if (i, j) in skip:
				continue
			quad = [pts[i][j], pts[i + 1][j], pts[i + 1][j + 1], pts[i][j + 1]]
			cx = sum(q[0] for q in quad) / 4
			cy = sum(q[1] for q in quad) / 4
			shrunk = [(qx + (cx - qx) * gap * 2.2, qy + (cy - qy) * gap * 2.2) for qx, qy in quad]
			top = z1 - p.rng.random() * 0.012
			stones += p.polygon(shrunk, z0, top)
	p.paint(stones, "piedra", "MID", vary=0.14)
	return stones


def flagstones(p, grid=3, z0=-0.035, z1=0.0, gap=0.035, skip=(), grass=False):
	slabs(p, grid, z0, z1, gap, skip)
	base = p.box(-1, 1, -1, 1, -0.5, z0)
	p.paint([f for f in base if f.normal.z <= 0.5], "tierra", z_range=(-0.5, 0.0))
	p.paint([f for f in base if f.normal.z > 0.5], "pasto" if grass else "tierra", "DARK" if not grass else "MID")


def piece(name, seed, fn):
	p = epi.Piece(seed)
	fn(p)
	p.build(name, kit)


# --- piso ---

piece("pasto", 1, lambda p: ground(p))


def pasto_flores(p):
	ground(p)
	for x, y in ((-0.5, 0.45), (0.45, 0.2), (-0.15, -0.5), (0.6, -0.6)):
		flower(p, x + p.rng.uniform(-0.1, 0.1), y + p.rng.uniform(-0.1, 0.1), p.rng.choice(["flor_amarilla", "flor_rosa", "blanco"]))


def pasto_piedras(p):
	ground(p)
	for x, y in ((-0.45, 0.4), (0.5, 0.3), (0.0, -0.45)):
		small_rock(p, x, y, p.rng.uniform(0.16, 0.28))
	small_rock(p, 0.6, -0.6, 0.1)


def pasto_ichu(p):
	ground(p)
	ichu(p, -0.4, 0.3, 0.5)
	ichu(p, 0.45, -0.35, 0.4, blades=7)


piece("pasto_flores", 2, pasto_flores)
piece("pasto_piedras", 3, pasto_piedras)
piece("pasto_ichu", 4, pasto_ichu)


def tierra_piedras(p):
	ground(p, "tierra")
	for x, y in ((-0.4, 0.35), (0.45, -0.3)):
		small_rock(p, x, y, p.rng.uniform(0.1, 0.16))


def tierra_borde(p):
	ground(p)
	edge = jagged(p, (0.0, 1.0), (0.0, -1.0), 6, 0.12)
	dirt_patch(p, [(-1.0, 1.0), (-1.0, -1.0), *edge[::-1]])


def tierra_esquina(p):
	ground(p)
	edge = jagged(p, (0.0, -1.0), (-1.0, 0.0), 6, 0.1)
	dirt_patch(p, [(-1.0, -1.0), *edge])


def tierra_esquina_int(p):
	ground(p)
	edge = jagged(p, (1.0, 0.0), (0.0, 1.0), 6, 0.1)
	dirt_patch(p, [(-1.0, -1.0), (1.0, -1.0), *edge, (-1.0, 1.0)])


piece("tierra", 5, lambda p: ground(p, "tierra"))
piece("tierra_piedras", 20, tierra_piedras)
piece("tierra_borde", 6, tierra_borde)
piece("tierra_esquina", 7, tierra_esquina)
piece("tierra_esquina_int", 8, tierra_esquina_int)

piece("lajas", 9, lambda p: flagstones(p))
piece("lajas_rotas", 10, lambda p: flagstones(p, skip={(0, 2), (1, 1), (2, 0)}))
piece("lajas_pasto", 11, lambda p: flagstones(p, skip={(2, 2), (0, 1)}, grass=True))


# --- muros y desniveles ---

def anden(p):
	epi.stone_wall(p, -0.5, TOP - CAP)
	epi.grass_cap(p, TOP - CAP, TOP)


def risco(p):
	"""Roca natural: caja subdividida empujada hacia afuera con ruido; el borde de arriba queda recto para la tapa."""
	faces = p.box(-1, 1, -1, 1, -0.5, TOP - CAP)
	edges = list({e for f in faces for e in f.edges})
	bmesh.ops.subdivide_edges(p.bm, edges=edges, cuts=3, use_grid_fill=True)
	off = Vector((p.rng.random() * 40, p.rng.random() * 40, 0))
	side = [v for v in p.bm.verts if v.co.z < TOP - CAP - 0.01 and v.co.z > -0.49]
	for v in side:
		n = Vector((v.co.x, v.co.y, 0))
		outward = Vector((1 if v.co.x > 0.99 else -1 if v.co.x < -0.99 else 0, 1 if v.co.y > 0.99 else -1 if v.co.y < -0.99 else 0, 0))
		if outward.length == 0:
			continue
		k = 0.5 + 0.5 * noise.noise(v.co * 1.7 + off)
		v.co += outward.normalized() * (0.04 + 0.16 * k)
		v.co.z += (p.rng.random() - 0.5) * 0.12
	bmesh.ops.triangulate(p.bm, faces=list(p.bm.faces))
	p.paint(list(p.bm.faces), "acantilado", z_range=(-0.5, TOP - CAP), vary=0.1)
	epi.grass_cap(p, TOP - CAP, TOP)


def escalon(p):
	epi.stone_wall(p, -0.5, 0.6 - 0.04, depth=0.05)
	p.paint(p.box(-0.97, 0.97, -0.97, 0.97, 0.5, 0.575), "tierra", "DARK")
	slabs(p, 2, 0.5, 0.6, gap=0.03, half=0.99)


def escalinata(p):
	"""Ocupa dos celdas hacia +Y (la de origen y la de atrás) y sube de 0 a TOP en 8 escalones, con muros a los lados."""
	steps = 8
	run = 4.0 / steps
	rise = TOP / steps
	treads = []
	for i in range(steps):
		y0 = -1 + i * run
		treads += p.box(-0.8, 0.8, y0, 3.0, -0.5, (i + 1) * rise)
	p.paint(treads, "piedra", z_range=(0, TOP), vary=0.1)
	for x in (-1.0, 0.8):
		wall = p.box(x, x + 0.2, -1.0, 3.0, -0.5, TOP + 0.25)
		p.paint(wall, "acantilado", z_range=(-0.5, TOP + 0.25), vary=0.08)


piece("anden", 12, anden)
piece("risco", 13, risco)
piece("escalon", 14, escalon)
piece("escalinata", 15, escalinata)


# --- pircas (muro bajo de piedra seca, a lo largo de X por el centro de la celda) ---

def pirca_run(p, x0, x1, height=0.85, missing=0.0):
	"""Piedra seca: hiladas de lajas planas, cada una corrida y torcida un poco, más angostas arriba."""
	stones = []
	z = 0.0
	course = 0
	while z < height - 0.05:
		h = 0.13 + p.rng.random() * 0.1
		depth = 0.5 - 0.1 * z / height
		x = x0 - (0.12 if course % 2 else 0.0)
		while x < x1 - 0.05:
			w = 0.28 + p.rng.random() * 0.26
			left, right = max(x, x0), min(x + w, x1)
			if right - left > 0.08 and p.rng.random() >= missing:
				s = p.box(left + 0.015, right - 0.015, -depth / 2, depth / 2, z, z + h - 0.015, taper=0.03)
				p.jitter(s, 0.025)
				stones += s
			x += w
		z += h
		course += 1
	p.paint(stones, "piedra", z_range=(0, height), vary=0.2)


def pirca(p):
	ground(p)
	pirca_run(p, -1.0, 1.0)


def pirca_esquina(p):
	ground(p)
	pirca_run(p, -0.25, 1.0)
	q = epi.Piece(p.rng.randint(0, 999))
	pirca_run(q, -0.25, 1.0)
	q.transform(list(q.bm.faces), Matrix.Rotation(math.pi / 2, 4, "Z"))
	p.merge(q)


def pirca_final(p):
	ground(p)
	pirca_run(p, -1.0, 0.65)
	post = p.box(0.55, 0.92, -0.28, 0.28, 0.0, 1.05, taper=0.04)
	p.jitter(post, 0.03)
	p.paint(post, "acantilado", vary=0.1)


def pirca_poste(p):
	ground(p)
	post = p.box(-0.22, 0.22, -0.22, 0.22, 0.0, 1.05, taper=0.05)
	p.jitter(post, 0.03)
	p.paint(post, "acantilado", vary=0.1)
	cap = p.box(-0.27, 0.27, -0.27, 0.27, 1.05, 1.15, taper=0.03)
	p.jitter(cap, 0.02)
	p.paint(cap, "piedra", vary=0.1)
	for _ in range(2):
		small_rock(p, p.rng.uniform(-0.5, 0.5), p.rng.choice([-0.45, 0.45]), p.rng.uniform(0.08, 0.13))


def pirca_rota(p):
	ground(p)
	pirca_run(p, -1.0, 1.0, height=0.5, missing=0.3)
	for _ in range(3):
		small_rock(p, p.rng.uniform(-0.8, 0.8), p.rng.choice([-0.45, 0.45]), p.rng.uniform(0.1, 0.16))


piece("pirca", 16, pirca)
piece("pirca_esquina", 17, pirca_esquina)
piece("pirca_final", 18, pirca_final)
piece("pirca_rota", 19, pirca_rota)
piece("pirca_poste", 21, pirca_poste)

# --- abismo (lados: 0 = -X, 1 = -Y, 2 = +X, 3 = +Y; las variantes giran en vary_overworld.gd) ---

DEPTH = -3.0


def abyss_wall(p, side):
	"""Pared de roca del lado side, de 0 a DEPTH: los bordes en X quedan rectos para empalmar con la vecina. Siete filas
	(cuts=6); los colores cambian en el borde de una fila para que el corte no salga en serrucho."""
	before = set(p.bm.faces)
	faces = p.box(-1, 1, 0.88, 1, DEPTH, 0)
	bmesh.ops.subdivide_edges(p.bm, edges=list({e for f in faces for e in f.edges}), cuts=6, use_grid_fill=True)
	off = p.rng.random() * 40
	for v in {v for f in p.bm.faces if f not in before for v in f.verts}:
		if v.co.y < 0.89:
			taper = max(0.0, math.sin((v.co.x + 1) / 2 * math.pi)) ** 0.6
			k = 0.5 + 0.5 * noise.noise(Vector((v.co.x * 2.6, v.co.z * 1.8, off))) + (p.rng.random() - 0.5) * 0.3
			v.co.y -= taper * (0.06 + 0.24 * k)
	bmesh.ops.triangulate(p.bm, faces=[f for f in p.bm.faces if f not in before])
	faces = [f for f in p.bm.faces if f not in before]
	p.paint([f for f in faces if f.normal.z > 0.5 and f.calc_center_median().z > -0.01], "pasto", "MID")
	p.paint_bands([f for f in faces if not (f.normal.z > 0.5 and f.calc_center_median().z > -0.01)],
		[(DEPTH * 3 / 7, 0.1, "acantilado", "MID"), (DEPTH * 5 / 7, DEPTH * 3 / 7, "gris_4", "MID"), (DEPTH - 1, DEPTH * 5 / 7, "gris_5", "DARK")])
	p.transform(faces, Matrix.Rotation((side + 1) * math.pi / 2, 4, "Z"))


def abismo(sides):
	def build(p):
		p.paint(p.box(-1, 1, -1, 1, DEPTH - 0.1, DEPTH), "gris_5", "DARK")
		for side in sides:
			abyss_wall(p, side)
	return build


piece("abismo", 40, abismo(()))
piece("abismo_borde", 41, abismo((0,)))
piece("abismo_esquina", 42, abismo((0, 1)))
piece("abismo_pasillo", 43, abismo((0, 2)))
piece("abismo_punta", 44, abismo((0, 1, 2)))
piece("abismo_pozo", 45, abismo((0, 1, 2, 3)))

ORDER = ["pasto", "tierra", "lajas", "anden", "pirca", "abismo"]
epi.layout(kit, columns=6, row_of=lambda n: next((i for i, k in enumerate(ORDER) if n.startswith(k)), 3 if n in ("risco", "escalon", "escalinata") else 9))
epi.save("terreno_overworld")
