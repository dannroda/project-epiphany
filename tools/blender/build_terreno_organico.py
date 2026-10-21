# Terreno del overworld con bordes orgánicos y lomas (12.15, la variante 6 de 12.14): lee tools/terreno_overworld.json
# (lo escribe tools/export_terreno_overworld.gd desde el GridMap) y publica assets/epiphany/terreno_organico.glb.
# Terrazas (7.10): cada columna tiene un nivel (0 a 2 se caminan, 3 es montaña) a TOP m por nivel; entre niveles, cara de
# risco; arriba de cada borde, una baranda invisible salvo en los saltos (v) y en la boca de las escalinatas (S).
# Cerca de los puntos fijos (lo jugable, la decoración, las piezas que quedan en el GridMap) los bordes siguen la grilla
# y el piso queda plano; en los pasos de una celda la roca solo se mete, no se come el paso.
# blender -b -P tools/blender/build_terreno_organico.py
import bisect
import json
import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, geometry, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

DATA = json.load(open(os.path.join(epi.ROOT, "tools", "terreno_overworld.json")))
GRID = DATA["rows"]
LEVELS = [[int(ch) for ch in row] for row in DATA["levels"]]
MOUNTAIN = 3
## Grupo de la baranda (Targeting.WALK_GUARD): solo frena al que camina; lo pone epi_scene_import.
WALK_GUARD = "walk_guard"
## Alto de la baranda invisible sobre el borde de cada terraza (m).
RAIL = 1.6
## Sin baranda a esta distancia (m) de un poste del gancho.
POST_GAP = 1.2
X0, Z0 = DATA["origin"]
CELL = DATA["cell"]
POSTS = [(x, -z) for x, z in DATA.get("posts", [])]
# Sin decoración delante de cada ojo (largo, medio ancho en m): la flecha vuela recta a 1 m y una planta la frena.
EYES = [(Vector((e["x"], -e["z"])), Vector((e["dx"], -e["dz"])).normalized()) for e in DATA.get("eyes", [])]
FIRE_LINE = (16.0, 1.0)
# Los caminos de las terrazas, sobre la tapa: si el contorno del camino toca el borde, la tapa no le abre el agujero.
PATH_LIFT = 0.02
GW, GH = len(GRID[0]), len(GRID)
TOP = 2.6
CAP = 0.15
DEPTH = -3.0
## Fondo del agua baja (ShallowWater) y ancho de su orilla en pendiente (m).
SHALLOW = -0.35
BANK = 0.9
## Cuánto ondula (m) el borde del agua baja, para un lado y para el otro.
WATER_AMP = 1.0
AMP = 0.4
LOMAS = 0.3
## Hileras del risco, de abajo arriba: (z desde, z hasta (None: la tapa), cuánto sale, radio del canto). Los bloques del
## medio miden CLIFF_BLOCK de ancho; los ladrillos de abajo parten cada uno en 2 o 3 y el labio de arriba no se corta.
CLIFF_TIERS = ((-0.5, 0.35, (-0.04, 0.02), 0.07), (0.35, TOP - CAP - 0.3, (0.0, 0.08), 0.25), (TOP - CAP - 0.3, None, (0.1, 0.14), 0.1))
CLIFF_BLOCK = (1.3, 2.3)
## Pasadas de relajación del contorno: vuelven diagonales y curvas las escaleras de celdas.
RELAX = 24
## Distancia (m) desde el borde de un punto fijo en la que el terreno pasa de quieto a orgánico.
FADE = 2.0
CHUNK = 16.0
## Ancho (m) de la franja donde un estilo de región se mezcla con el de al lado.
BAND = 4.0
REGIONS = [(r["style"], r["rect"][0], -r["rect"][3], r["rect"][2], -r["rect"][1]) for r in DATA.get("regions", [])]
## Estilo de terreno de cada región (TerrainStyleArea.style): papel → (franja, tono); lo que falta sale de DEFAULT.
DEFAULT = {
	"ground": ("pasto", "MID"), "path": ("tierra", "MID"), "cap": ("pasto", "MID"), "hang": ("pasto", "DARK"),
	"ledge": ("musgo", "MID"), "under": ("acantilado", "DARK"), "base": ("acantilado", "DARK"), "lip": ("acantilado", "LIGHT"),
	"rock": ("acantilado", None), "abyss_top": ("acantilado", "MID"), "abyss_mid": ("gris_4", "MID"), "abyss_low": ("gris_5", "DARK"),
}
STYLES = {
	"necropolis": {"ground": ("tierra", "MID"), "path": ("acantilado", "LIGHT"), "cap": ("tierra", "MID"), "hang": ("acantilado", "DARK"),
		"ledge": ("tierra", "LIGHT"), "lip": ("tierra", "LIGHT")},
	"laguna": {"ground": ("musgo", "MID"), "path": ("tierra", "LOW"), "cap": ("musgo", "MID"), "hang": ("musgo", "DARK"),
		"lip": ("piedra", "LIGHT"), "rock": ("piedra", None), "under": ("piedra", "DARK"), "base": ("piedra", "DARK"),
		"abyss_top": ("piedra", "MID"), "abyss_mid": ("musgo", "DARK"), "abyss_low": ("musgo", "DARK")},
	"cumbre": {"ground": ("cristal", "LIGHT"), "path": ("piedra", "MID"), "cap": ("cristal", "LIGHT"), "hang": ("cristal", "MID"),
		"ledge": ("cristal", "LIGHT"), "under": ("ladrillo", "DARK"), "base": ("ladrillo", "DARK"), "lip": ("piedra", "LIGHT"), "rock": ("ladrillo", None)},
	"explanada": {"path": ("piedra_templo", "LOW")},
	"cardonal": {"ground": ("tierra", "LIGHT"), "path": ("acantilado", "LIGHT"), "cap": ("tierra", "MID"), "hang": ("acantilado", "MID"),
		"ledge": ("tierra", "MID"), "lip": ("tierra", "LIGHT"), "rock": ("roca_naranja", None)},
	"quebrada": {"abyss_top": ("roca_naranja", "MID"), "abyss_mid": ("acantilado", "DARK")},
}
_UNKNOWN = sorted({style for style, *_rect in REGIONS if style not in STYLES})
if _UNKNOWN:
	sys.exit("build_terreno_organico: estilos desconocidos %s (TerrainStyleArea.style; los de STYLES: %s)" % (_UNKNOWN, ", ".join(STYLES)))
STEPS = [((X0 + c) * CELL, (Z0 + r) * CELL, 1.4) for r in range(len(GRID)) for c in range(len(GRID[0])) if GRID[r][c] in "Sv"]
FIXED = np.array([(x, -z, r) for x, z, r in DATA["fixed"] + STEPS]).reshape(-1, 3)
DECOR = np.array([(x, -z, r) for x, z, r in DATA["decor"]]).reshape(-1, 3)
## Delante y dentro de cada boca de cueva el piso queda sin lomas, así no asoma sobre el piso del túnel.
MOUTH_FLAT = np.array([(m["x"] - d * math.sin(m["yaw"]), -m["z"] + d * math.cos(m["yaw"]), 1.4) for m in DATA.get("mouths", []) for d in (-1.5, 0.5, 2.5)]).reshape(-1, 3)
FLAT = np.concatenate([FIXED, DECOR, MOUTH_FLAT])
## Celdas de agua baja: alrededor el piso queda sin lomas, así la superficie del agua no asoma sobre el pasto.
WET = np.array([[(X0 + c) * CELL, -(Z0 + r) * CELL, CELL / 2 + WATER_AMP + 0.6] for r in range(GH) for c in range(GW) if GRID[r][c] == "w"]).reshape(-1, 3)


def corner(c, r):
	return Vector(((X0 + c) * CELL - CELL / 2, -((Z0 + r) * CELL - CELL / 2)))


def cell_center(c, r):
	return Vector(((X0 + c) * CELL, -(Z0 + r) * CELL))


def cell_at(x, y):
	c = math.floor((x + CELL / 2) / CELL) - X0
	r = math.floor((-y + CELL / 2) / CELL) - Z0
	if not (0 <= c < GW and 0 <= r < GH):
		return "H"
	return GRID[r][c]


def level_at(x, y):
	c = math.floor((x + CELL / 2) / CELL) - X0
	r = math.floor((-y + CELL / 2) / CELL) - Z0
	if not (0 <= c < GW and 0 <= r < GH):
		return MOUNTAIN
	return LEVELS[r][c]


def at_level(level, levels=None):
	"""La grilla de letras con lo que no es de ese nivel tapado (X)."""
	levels = levels or LEVELS
	return ["".join(ch if levels[r][c] == level else "X" for c, ch in enumerate(row)) for r, row in enumerate(GRID)]


def at_least(level, levels=None):
	"""H donde el nivel llega a level, . donde no."""
	levels = levels or LEVELS
	return ["".join("H" if levels[r][c] >= level else "." for c in range(GW)) for r in range(GH)]


BOUNDS = (corner(0, GH), corner(GW, 0))


def gap(xy, points):
	"""Distancia de cada punto (N×2) al borde del punto más cercano de points."""
	if not len(points):
		return np.full(len(xy), 1e9)
	return (np.sqrt(((xy[:, None, :] - points[None, :, :2]) ** 2).sum(-1)) - points[None, :, 2]).min(1)


def freedom(xy, points=FIXED):
	"""0 sobre un punto, 1 a FADE de su borde (N×2 → N)."""
	t = np.clip(gap(xy, points) / FADE, 0.0, 1.0)
	return t * t * (3 - 2 * t)


# --- contornos ---

def loops(inside, grid=GRID):
	"""Contornos cerrados de las celdas donde inside(ch), con lo de adentro a la izquierda: [(puntos, ¿pared?)]. Afuera de
	la grilla todo es alto: ahí no hay pared."""
	edges = {}
	sides = (((0, 1), (0, 1), (1, 1)), ((1, 0), (1, 1), (1, 0)), ((0, -1), (1, 0), (0, 0)), ((-1, 0), (0, 0), (0, 1)))
	for r in range(GH):
		for c in range(GW):
			if not inside(grid[r][c]):
				continue
			for (dc, dr), a, b in sides:
				nc, nr = c + dc, r + dr
				in_grid = 0 <= nc < GW and 0 <= nr < GH
				if in_grid and inside(grid[nr][nc]):
					continue
				edges.setdefault((c + a[0], r + a[1]), []).append(((c + b[0], r + b[1]), in_grid))
	result = []
	while edges:
		start = next(iter(edges))
		points, flags = [], []
		at, heading = start, None
		while True:
			options = edges[at]
			if heading and len(options) > 1:
				options.sort(key=lambda e: -_turn(heading, (e[0][0] - at[0], e[0][1] - at[1])))
			end, flag = options.pop(0)
			if not options:
				del edges[at]
			points.append(corner(*at))
			flags.append(flag)
			heading = (end[0] - at[0], end[1] - at[1])
			at = end
			if at == start:
				break
		result.append(_simplify(points, flags))
	return result


def _turn(a, b):
	return a[0] * b[1] - a[1] * b[0]


def _simplify(points, flags):
	n = len(points)
	keep = [i for i in range(n) if flags[i - 1] != flags[i] or (points[i] - points[i - 1]).normalized().dot((points[(i + 1) % n] - points[i]).normalized()) < 0.999]
	return [points[i] for i in keep], [flags[i] for i in keep]


def resample(loop, step):
	points, flags = loop
	out_p, out_f = [], []
	for i, p in enumerate(points):
		q = points[(i + 1) % len(points)]
		k = max(1, math.ceil((q - p).length / step))
		for j in range(k):
			out_p.append(p.lerp(q, j / k))
			out_f.append(flags[i])
	return out_p, out_f


def chaikin(loop, times):
	points, flags = loop
	for _ in range(times):
		out_p, out_f = [], []
		for i, p in enumerate(points):
			q = points[(i + 1) % len(points)]
			out_p += [p.lerp(q, 0.25), p.lerp(q, 0.75)]
			out_f += [flags[i], flags[i]]
		points, flags = out_p, out_f
	return points, flags


def normals(points, sign=1.0):
	"""Normal de cada punto hacia la derecha del recorrido (sign -1: hacia la izquierda)."""
	result = []
	n = len(points)
	for i in range(n):
		d = (points[(i + 1) % n] - points[i - 1]).normalized()
		result.append(Vector((d.y, -d.x)) * sign)
	return result


def _nearest_on(points, square):
	"""Punto más cercano de cada punto sobre el contorno cuadrado."""
	a = np.array([(p.x, p.y) for p in square])
	b = np.roll(a, -1, axis=0)
	q = np.array([(p.x, p.y) for p in points])
	ab = b - a
	t = np.clip(((q[:, None, :] - a) * ab).sum(-1) / np.maximum((ab * ab).sum(-1), 1e-9), 0.0, 1.0)
	near = a + t[..., None] * ab
	pick = ((near - q[:, None, :]) ** 2).sum(-1).argmin(1)
	return near[np.arange(len(q)), pick]


def relax(loop, times=RELAX):
	points, flags = loop
	n = len(points)
	for _ in range(times):
		points = [points[i] if not (flags[i] or flags[i - 1]) else (points[i - 1] + points[i] * 2.0 + points[(i + 1) % n]) / 4.0 for i in range(n)]
	return points, flags


def style(loop, seed, solid, jagged=0.0, amp=AMP, smooth=RELAX):
	"""Contorno orgánico; solid(punto) dice qué es el lado de adentro, para no achicar pasos de una celda."""
	square = resample(loop, 0.4)
	points, flags = relax(resample(chaikin(resample(loop, 1.0), 2), 0.4), smooth)
	nrm = normals(points)
	near_decor = gap(np.array([(p.x, p.y) for p in points]), DECOR) < 1.2
	moved = []
	for i, (p, n) in enumerate(zip(points, nrm)):
		if not (flags[i] or flags[i - 1]):
			moved.append(p)
			continue
		push = amp * noise.noise(Vector((p.x * 0.42, p.y * 0.42, seed)))
		probe = p + n * (CELL * 1.2)
		if push > 0 and (near_decor[i] or solid(probe)):
			push = 0.0
		if jagged:
			push += (random.Random(seed + i).random() - 0.5) * 2 * jagged
		moved.append(p + n * push)
	xy = np.array([(p.x, p.y) for p in moved])
	free = freedom(xy)
	snap = _nearest_on(moved, square[0])
	final = [Vector(tuple(s + (m - s) * f)) for s, m, f in zip(snap, xy, free)]
	return final, flags


def style_at(x, y):
	"""Estilo de la región en (x, y): el borde del rectángulo ondula hasta BAND hacia los dos lados."""
	chosen = ""
	for k, (style, x0, y0, x1, y1) in enumerate(REGIONS):
		depth = min(x - x0, x1 - x, y - y0, y1 - y)
		if depth + BAND * noise.noise(Vector((x * 0.16, y * 0.16, 5.0 + k))) > 0:
			chosen = style
	return chosen


def split_styles(p, faces):
	"""Corta las caras por donde pasa el borde entre estilos, para que no quede escalonado."""
	at = {}
	for f in faces:
		for v in f.verts:
			if v not in at:
				at[v] = style_at(v.co.x, v.co.y)
	cuts = {}
	for e in epi.uniq(e for f in faces for e in f.edges):
		a, b = e.verts
		if a not in at or b not in at or at[a] == at[b]:
			continue
		lo, hi = 0.0, 1.0
		for _ in range(6):
			mid = (lo + hi) / 2
			co = a.co.lerp(b.co, mid)
			lo, hi = (mid, hi) if style_at(co.x, co.y) == at[a] else (lo, mid)
		cuts[e] = (a, (lo + hi) / 2)
	made = {}
	for e, (a, t) in cuts.items():
		_e, v = bmesh.utils.edge_split(e, a, t)
		for f in v.link_faces:
			made.setdefault(f, []).append(v)
	out = list(faces)
	own = set(faces)
	for f, verts in made.items():
		if len(verts) == 2 and f in own:
			try:
				new, _loop = bmesh.utils.face_split(f, verts[0], verts[1])
			except ValueError:
				continue
			out.append(new)
	for f in out:
		f.normal_update()
	p.fixed.update(out)
	return out


def paint_role(p, faces, role, shade=None, z_range=None, vary=0.0):
	"""Pinta cada cara con la franja de su papel en el estilo de la región donde cae."""
	if REGIONS:
		faces = split_styles(p, faces)
	groups = {}
	for f in faces:
		c = f.calc_center_median()
		groups.setdefault(style_at(c.x, c.y), []).append(f)
	for style, group in sorted(groups.items()):
		swatch, style_shade = STYLES.get(style, {}).get(role, DEFAULT[role])
		_paint(p, group, swatch, style_shade or shade or "GRADIENT", z_range, vary)


def _paint(p, faces, swatch, shade, z_range=None, vary=0.0):
	"""p.paint con vary sacado de dónde está cada cara y no del orden: los cortes de bmesh crean las caras en otro orden en
	cada build."""
	if not vary or not faces:
		p.paint(faces, swatch, shade, z_range=z_range)
		return
	zs = [v.co.z for f in faces for v in f.verts]
	z_range = z_range or (min(zs), max(zs))
	rng = p.rng
	for f in faces:
		p.rng = random.Random(hash(tuple(round(c, 3) for c in f.calc_center_median())))
		p.paint([f], swatch, shade, z_range=z_range, vary=vary)
	p.rng = rng


def lomas(x, y):
	return LOMAS * noise.noise(Vector((x * 0.3, y * 0.3, 3.7)))


# --- piezas ---

def _ticks(lo, hi, r, step=0.45):
	"""Cortes de lo a hi, con uno a r de cada punta para que el canto se vea redondo."""
	inner = max(1, math.ceil((hi - lo - 2 * r) / step))
	return [lo, hi] + [lo + r + (hi - lo - 2 * r) * k / inner for k in range(inner + 1)]


def cliff_wall(p, loop, z0=0.0):
	"""Risco de bloques redondeados como en LA, de z0 - 0.5 a la tapa, mirando hacia afuera: ladrillos chicos metidos
	abajo, bloques grandes en el medio y un labio claro arriba."""
	points, flags = loop
	z1 = TOP - CAP
	n_pts = len(points)
	cum = [0.0]
	for i in range(n_pts):
		cum.append(cum[-1] + (points[(i + 1) % n_pts] - points[i]).length)
	length = cum[-1]
	nrm = normals(points)
	main = [p.rng.random() * CLIFF_BLOCK[1]]
	while main[-1] < length + CLIFF_BLOCK[1]:
		main.append(main[-1] + p.rng.uniform(*CLIFF_BLOCK))
	small = []
	for a, b in zip(main, main[1:]):
		parts = p.rng.choice((2, 3))
		small += [a + (b - a) * (k + p.rng.uniform(-0.15, 0.15) * (k > 0)) / parts for k in range(parts)]
	small.append(main[-1])
	tiers = []
	for (lo, hi, depth, r), seams in zip(CLIFF_TIERS, (small, main, None)):
		hi = z1 if hi is None else hi
		count = len(seams) if seams else 2
		tiers.append((lo, hi, r, seams, [p.rng.uniform(*depth) for _ in range(count)], [p.rng.random() < 0.25 for _ in range(count)]))
	cols = sorted({round(t % length, 2) for seams, r in ((small, CLIFF_TIERS[0][3]), (main, CLIFF_TIERS[1][3])) for a, b in zip(seams, seams[1:]) for t in _ticks(a, b, r)})
	rows = sorted({round(t, 3) for lo, hi, r, *_ in tiers for t in _ticks(lo, hi, r)})

	def block(tier, s, z):
		lo, hi, r, seams, depths, variant = tier
		e, j = min(z - lo, hi - z), 0
		if seams:
			s = s if s >= seams[0] else s + length
			j = max(0, min(len(seams) - 2, bisect.bisect_right(seams, s) - 1))
			e = min(e, s - seams[j], seams[j + 1] - s)
		t = min(max(e, 0.0) / r, 1.0)
		return depths[j] + 0.9 * r * math.sqrt(1.0 - (1.0 - t) ** 2), t, variant[j]

	ring, shade, col_flags = [], {}, []
	for s in cols:
		i = max(0, min(n_pts - 1, bisect.bisect_right(cum, s) - 1))
		f = (s - cum[i]) / max(cum[i + 1] - cum[i], 1e-9)
		pt = points[i].lerp(points[(i + 1) % n_pts], f)
		n = nrm[i].lerp(nrm[(i + 1) % n_pts], f).normalized()
		col = []
		for z in rows:
			hits = [block(tier, s, z) for tier in tiers if tier[0] - 1e-6 <= z <= tier[1] + 1e-6]
			out, t, variant = min(hits)
			if z <= -0.5 + 1e-6:
				out = 0.0
			out += 0.03 * noise.noise(Vector((pt.x * 2.3, pt.y * 2.3, z * 2.3)))
			v = p.bm.verts.new((pt.x + n.x * out, pt.y + n.y * out, z))
			shade[v] = (t, variant)
			col.append(v)
		ring.append(col)
		col_flags.append(flags[i])
	faces = []
	for c in range(len(cols)):
		if not col_flags[c]:
			continue
		a, b = ring[c], ring[(c + 1) % len(cols)]
		for k in range(len(rows) - 1):
			for tri in ((a[k], b[k], b[k + 1]), (a[k], b[k + 1], a[k + 1])):
				faces.append(p.bm.faces.new(tri))
	for f in faces:
		f.normal_update()
	groups = {"ledge": [], "under": [], "base": [], "lip": [], "rock": [], "dim": []}
	for f in faces:
		z = f.calc_center_median().z
		groove = sum(shade[v][0] for v in f.verts) / 3 < 0.25
		if f.normal.z > 0.6:
			groups["ledge"].append(f)
		elif f.normal.z < -0.4 or groove:
			groups["under"].append(f)
		elif z < CLIFF_TIERS[0][1]:
			groups["base"].append(f)
		elif z > CLIFF_TIERS[2][0]:
			groups["lip"].append(f)
		else:
			groups["dim" if all(shade[v][1] for v in f.verts) else "rock"].append(f)
	paint_role(p, groups["ledge"], "ledge", vary=0.1)
	paint_role(p, groups["under"], "under")
	paint_role(p, groups["base"], "base", vary=0.12)
	paint_role(p, groups["lip"], "lip", vary=0.06)
	paint_role(p, groups["rock"], "rock", z_range=(CLIFF_TIERS[1][0], CLIFF_TIERS[1][1]), vary=0.08)
	paint_role(p, groups["dim"], "rock", "LOW", vary=0.05)
	p.fixed.update(faces)


def cap(p, high_loops, holes=()):
	"""Tapa de pasto sobre todo lo alto, un poco más ancha que la roca y con el canto liso; holes son los
	pozos, caminos y agua de ese nivel."""
	rims = []
	for points, flags in high_loops:
		rims.append(([pt + n * 0.12 if flags[i] or flags[i - 1] else pt for i, (pt, n) in enumerate(zip(points, normals(points)))], flags))
	top = fill(p, [r[0] for r in rims] + list(holes), TOP, (lambda xy: np.zeros(len(xy))) if REGIONS else None)
	paint_role(p, top, "cap")
	hang = []
	for points, flags in rims:
		for i, a in enumerate(points):
			if not flags[i]:
				continue
			b = points[(i + 1) % len(points)]
			v = [p.bm.verts.new((a.x, a.y, TOP)), p.bm.verts.new((b.x, b.y, TOP)), p.bm.verts.new((b.x, b.y, TOP - CAP)), p.bm.verts.new((a.x, a.y, TOP - CAP))]
			hang.append(p.bm.faces.new((v[0], v[3], v[2], v[1])))
	for f in hang:
		f.normal_update()
	paint_role(p, hang, "hang")
	p.fixed.update(top + hang)


def _contains(outline, point):
	xy = np.array([(q.x, q.y) for q in outline])
	a, b = xy, np.roll(xy, -1, axis=0)
	crosses = (a[:, 1] > point.y) != (b[:, 1] > point.y)
	at = (b[:, 0] - a[:, 0]) * (point.y - a[:, 1]) / np.where(b[:, 1] == a[:, 1], 1e-9, b[:, 1] - a[:, 1]) + a[:, 0]
	return int((crosses & (point.x < at)).sum()) % 2 == 1


def islands(outlines):
	"""Agrupa los contornos en islas: cada uno de profundidad par (cuántos lo rodean) con los de adentro que lo tocan
	directo como agujeros. Así tessellate_polygon no tiende puentes entre contornos separados."""
	probe = [o[0].lerp(o[1], 0.5) for o in outlines]
	inside = [[j for j in range(len(outlines)) if j != i and _contains(outlines[j], probe[i])] for i in range(len(outlines))]
	depth = [len(c) for c in inside]
	groups = {i: [i] for i in range(len(outlines)) if depth[i] % 2 == 0}
	for i in range(len(outlines)):
		if depth[i] % 2 == 1:
			parent = next((j for j in inside[i] if depth[j] == depth[i] - 1), None)
			if parent is not None:
				groups[parent].append(i)
	return list(groups.values())


def _slice(bm, axis, first, last):
	"""Corta bm cada 1 m en ese eje, de first a last - 1, pasándole a cada plano solo las caras que lo cruzan: las que
	empiezan antes y terminan después. Lo que queda a la izquierda de un corte ya no se vuelve a mirar."""
	starts = {}
	for f in bm.faces:
		starts.setdefault(math.floor(min(v.co[axis] for v in f.verts)), []).append(f)
	keys = sorted(starts)
	active, i = [], 0
	for k in range(first, last):
		while i < len(keys) and keys[i] < k:
			active += starts[keys[i]]
			i += 1
		cross = [f for f in active if f.is_valid and max(v.co[axis] for v in f.verts) > k + 1e-6]
		if not cross:
			active = []
			continue
		co, no = Vector((0, 0, 0)), Vector((0, 0, 0))
		co[axis], no[axis] = k, 1
		res = bmesh.ops.bisect_plane(bm, geom=epi.uniq(v for f in cross for v in f.verts) + epi.uniq(e for f in cross for e in f.edges) + cross, plane_co=co, plane_no=no)
		pieces = epi.uniq(cross + [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)])
		active = [f for f in pieces if f.is_valid and max(v.co[axis] for v in f.verts) > k + 1e-6]


def fill(p, outlines, z, height=None):
	"""Tapa plana (con agujeros por paridad) de los contornos; height la deforma después de cortarla en 1 m. Se arma y se
	corta en una malla aparte, así cada corte recorre solo esta tapa, y después se suma a p."""
	bm = bmesh.new()
	faces = []
	for group in islands(outlines):
		flat = [[Vector((pt.x, pt.y, z)) for pt in outlines[i]] for i in group]
		verts = [bm.verts.new(v) for o in flat for v in o]
		for tri in geometry.tessellate_polygon(flat):
			try:
				faces.append(bm.faces.new([verts[i] for i in reversed(tri)]))
			except ValueError:
				pass
	for f in faces:
		f.normal_update()
		if f.normal.z < 0:
			f.normal_flip()
	if height:
		for axis, lo, hi in ((0, BOUNDS[0].x, BOUNDS[1].x), (1, BOUNDS[0].y, BOUNDS[1].y)):
			_slice(bm, axis, int(lo) + 1, int(hi))
		verts = bm.verts[:]
		for v, h in zip(verts, height(np.array([(v.co.x, v.co.y) for v in verts]))):
			v.co.z = z + h
		for f in bm.faces:
			f.normal_update()
	for f in bm.faces:
		f.material_index = 1
	mesh = bpy.data.meshes.new("fill")
	bm.to_mesh(mesh)
	bm.free()
	p.bm.from_mesh(mesh)
	bpy.data.meshes.remove(mesh)
	faces = [f for f in p.bm.faces if f.material_index == 1]
	for f in faces:
		f.material_index = 0
	p.fixed.update(faces)
	return faces


def ground_height(xy):
	return np.array([lomas(x, y) for x, y in xy]) * freedom(xy, FLAT) * freedom(xy, WET)


def abyss(p, loop, z0=0.0):
	"""Paredes del pozo hacia adentro, de la altura del suelo (z0) hasta z0 + DEPTH, y el fondo."""
	points, _flags = loop
	nrm = normals(points, -1.0)
	xy = np.array([(pt.x, pt.y) for pt in points])
	tops = (ground_height(xy) if z0 == 0.0 else np.zeros(len(xy))) + z0
	rows = 7
	ring = []
	for pt, n, top in zip(points, nrm, tops):
		col = []
		for k in range(rows + 1):
			z = top + (z0 + DEPTH - top) * k / rows
			out = 0.0 if k == 0 else (0.06 + 0.24 * (0.5 + 0.5 * noise.noise(Vector((pt.x * 2.6, pt.y * 2.6, z * 1.8)))))
			col.append(p.bm.verts.new((pt.x + n.x * out, pt.y + n.y * out, z)))
		ring.append(col)
	faces = []
	for i in range(len(points)):
		a, b = ring[i], ring[(i + 1) % len(points)]
		for k in range(rows):
			for tri in ((a[k], b[k], b[k + 1]), (a[k], b[k + 1], a[k + 1])):
				faces.append(p.bm.faces.new(tri))
	for f in faces:
		f.normal_update()
	depth = lambda f: f.calc_center_median().z - z0  # noqa: E731
	paint_role(p, [f for f in faces if depth(f) >= DEPTH * 3 / 7], "abyss_top")
	paint_role(p, [f for f in faces if DEPTH * 5 / 7 <= depth(f) < DEPTH * 3 / 7], "abyss_mid")
	paint_role(p, [f for f in faces if depth(f) < DEPTH * 5 / 7], "abyss_low")
	floor = fill(p, [points], z0 + DEPTH)
	p.paint(floor, "gris_5", "DARK")
	p.fixed.update(faces + floor)



def shallow(p, loop):
	"""Agua baja: orilla en pendiente hacia adentro, del suelo a SHALLOW, y el fondo, que se camina."""
	points, _flags = loop
	nrm = normals(points, -1.0)
	tops = ground_height(np.array([(pt.x, pt.y) for pt in points]))
	rows = 3
	ring = []
	for pt, n, top in zip(points, nrm, tops):
		col = []
		for k in range(rows + 1):
			t = k / rows
			z = top + (SHALLOW - top) * t * t * (3 - 2 * t)
			col.append(p.bm.verts.new((pt.x + n.x * BANK * t, pt.y + n.y * BANK * t, z)))
		ring.append(col)
	faces = []
	for i in range(len(points)):
		a, b = ring[i], ring[(i + 1) % len(points)]
		for k in range(rows):
			for tri in ((a[k], b[k], b[k + 1]), (a[k], b[k + 1], a[k + 1])):
				faces.append(p.bm.faces.new(tri))
	for f in faces:
		f.normal_update()
	p.paint(faces, "musgo", "MID")
	floor = fill(p, [[Vector((col[-1].co.x, col[-1].co.y)) for col in ring]], SHALLOW)
	p.paint(floor, "musgo", "DARK")
	p.fixed.update(faces + floor)


# --- decoración ---

NATURE = ["ichu_mata", "ichu_cortado", "flores", "tola", "hongos", "yareta", "piedra_chica_a", "piedra_chica_b", "roca_alta", "roca_grande_b",
	"quenoa_grande", "quenoa_chica", "cardon_a", "cardon_b", "cardon_chico"]
OBJECTS = ["apacheta"]
WINDY = {"ichu_mata", "flores", "tola", "quenoa_grande", "quenoa_chica"}
## Por tipo de lugar: [(pieza, probabilidad)] — hasta dos cosas por celda. "monte": lo alto lejos del borde; "monte_sur":
## lo mismo del lado de la cámara, sin árboles que tapen.
SCATTER = {
	".": [("ichu_mata", 0.4), ("flores", 0.18), ("piedra_chica_a", 0.08), ("piedra_chica_b", 0.06), ("tola", 0.08)],
	":": [("piedra_chica_b", 0.16), ("piedra_chica_a", 0.06), ("ichu_mata", 0.06)],
	"monte": [("quenoa_grande", 0.16), ("quenoa_chica", 0.12), ("ichu_mata", 0.3), ("cardon_a", 0.06)],
	"monte_sur": [("ichu_mata", 0.3), ("flores", 0.1), ("piedra_chica_a", 0.06)],
	"H": [("ichu_mata", 0.25), ("flores", 0.1)],
}
## Lo mismo por estilo de región (lo que no está sale de SCATTER).
STYLE_SCATTER = {
	"necropolis": {
		".": [("piedra_chica_a", 0.2), ("ichu_cortado", 0.2), ("piedra_chica_b", 0.12), ("cardon_chico", 0.05), ("apacheta", 0.03)],
		"H": [("piedra_chica_b", 0.2), ("ichu_cortado", 0.15), ("apacheta", 0.04)],
		"monte": [("ichu_cortado", 0.3), ("roca_grande_b", 0.06), ("apacheta", 0.05), ("cardon_a", 0.04)],
	},
	"laguna": {
		".": [("ichu_mata", 0.55), ("hongos", 0.06), ("flores", 0.1), ("tola", 0.08)],
		"H": [("ichu_mata", 0.4), ("hongos", 0.05)],
		"monte": [("quenoa_chica", 0.1), ("ichu_mata", 0.45), ("tola", 0.1)],
	},
	"cumbre": {
		".": [("yareta", 0.12), ("piedra_chica_a", 0.12), ("roca_alta", 0.03)],
		":": [("piedra_chica_a", 0.18)],
		"H": [("yareta", 0.1), ("piedra_chica_b", 0.1)],
		"monte": [("roca_alta", 0.08), ("roca_grande_b", 0.06), ("yareta", 0.12)],
		"monte_sur": [("yareta", 0.1), ("piedra_chica_a", 0.08)],
	},
	"cardonal": {
		".": [("cardon_chico", 0.12), ("tola", 0.18), ("piedra_chica_b", 0.08), ("cardon_b", 0.04)],
		"H": [("cardon_chico", 0.12), ("tola", 0.12)],
		"monte": [("cardon_a", 0.16), ("cardon_b", 0.1), ("tola", 0.2)],
		"monte_sur": [("cardon_chico", 0.1), ("tola", 0.15)],
	},
}
LAST_LOW = max(r for r in range(GH) if any(ch != "H" for ch in GRID[r]))
## Plantas que se cortan como el pasto: en el piso jugable no van a la malla, van a tools/plantas_overworld.json y
## tools/decorate_levels.gd pone una escena Breakable en cada una. Arriba de los riscos quedan en la malla.
CUTTABLE = {"ichu_mata", "flores", "tola", "hongos", "yareta", "cardon_chico", "cardon_a", "cardon_b", "quenoa_grande", "quenoa_chica"}
WALKABLE = {".", ":", "w"}
PLANTS_OUT = os.path.join(epi.ROOT, "tools", "plantas_overworld.json")


def load_meshes():
	art = os.path.join(epi.ROOT, "art", "blender")
	meshes = {}
	for blend, names in (("naturaleza.blend", NATURE), ("objetos.blend", OBJECTS)):
		with bpy.data.libraries.load(os.path.join(art, blend), link=False) as (src, dst):
			dst.objects = list(names)
		for obj in dst.objects:
			mesh = obj.data
			mesh.materials.clear()
			mesh.materials.append(epi.palette.palette_material())
			meshes[obj.name.split(".")[0]] = mesh
			bpy.data.objects.remove(obj)
	return meshes


def _place(c, r):
	ch = GRID[r][c]
	if ch != "H":
		return ch
	near_low = any(GRID[rr][cc] != "H" for rr in range(max(0, r - 1), min(GH, r + 2)) for cc in range(max(0, c - 1), min(GW, c + 2)))
	if near_low:
		return "H"
	return "monte_sur" if r > LAST_LOW else "monte"


def decor_spots():
	spots = []
	for r in range(GH):
		for c in range(GW):
			kind = _place(c, r)
			rng = random.Random(r * 131 + c * 7 + 12)
			center = cell_center(c, r)
			placed = 0
			style = style_at(center.x, center.y)
			for name, chance in STYLE_SCATTER.get(style, {}).get(kind, SCATTER.get(kind, [])):
				if placed < 2 and rng.random() < chance:
					spot = center + Vector(((rng.random() - 0.5) * 1.2, (rng.random() - 0.5) * 1.2))
					spots.append((name, spot, rng.random() * math.tau, kind))
					placed += 1
	if not spots:
		return spots
	far = gap(np.array([(s[1].x, s[1].y) for s in spots]), FLAT)
	dry = [all(cell_at(s[1].x + dx, s[1].y + dy) != "w" for dx, dy in ((0.7, 0), (-0.7, 0), (0, 0.7), (0, -0.7))) for s in spots]
	return [s for s, d, ok in zip(spots, far, dry) if d > 0.6 and ok and not _in_fire_line(s[1])]


def _in_fire_line(xy):
	for at, ahead in EYES:
		along = (xy - at).dot(ahead)
		if -0.5 < along < FIRE_LINE[0] and abs((xy - at).cross(ahead)) < FIRE_LINE[1]:
			return True
	return False


def decor(meshes, collection):
	"""Las plantas y piedras juntadas en una malla por pedazo de CHUNK m y por material, para pocas llamadas de dibujo."""
	bpy.context.view_layer.update()
	depsgraph = bpy.context.evaluated_depsgraph_get()
	groups = {}
	cuttable = []
	for kind, spot, angle, place in decor_spots():
		hit, location, normal, _i, _obj, _m = bpy.context.scene.ray_cast(depsgraph, Vector((spot.x, spot.y, 20.0)), Vector((0, 0, -1)))
		location = Vector(tuple(round(c, 3) for c in location))
		if not hit or normal.z < 0.85 or location.z < -0.5:
			continue
		if kind in CUTTABLE and place in WALKABLE:
			cuttable.append({"kind": kind, "at": [round(location.x, 3), round(location.z, 3), round(-location.y, 3)], "yaw": round(angle, 4)})
			continue
		key = ("wind" if kind in WINDY else "outdoor", math.floor(spot.x / CHUNK), math.floor(spot.y / CHUNK))
		groups.setdefault(key, []).append((kind, location, angle))
	objects = []
	for (material, gx, gy), items in sorted(groups.items()):
		bm = bmesh.new()
		for kind, location, angle in items:
			part = bmesh.new()
			part.from_mesh(meshes[kind])
			bmesh.ops.rotate(part, verts=part.verts, matrix=Matrix.Rotation(angle, 3, "Z"))
			bmesh.ops.translate(part, verts=part.verts, vec=location)
			mesh = bpy.data.meshes.new("tmp")
			part.to_mesh(mesh)
			part.free()
			bm.from_mesh(mesh)
			bpy.data.meshes.remove(mesh)
		mesh = bpy.data.meshes.new("plantas_%s_%d_%d" % (material, gx, gy))
		bm.to_mesh(mesh)
		bm.free()
		mesh.materials.append(epi.palette.palette_material())
		obj = bpy.data.objects.new(mesh.name, mesh)
		obj["material"] = material
		collection.objects.link(obj)
		objects.append(obj)
	with open(PLANTS_OUT, "w") as f:
		json.dump(cuttable, f, indent=0)
	return objects


def merge(dst, src):
	mesh = bpy.data.meshes.new("tmp")
	src.bm.to_mesh(mesh)
	dst.bm.from_mesh(mesh)
	bpy.data.meshes.remove(mesh)
	src.bm.free()


def rocks(levels, seed, holes=None, rail=None):
	"""Las caras de risco de cada nivel con su tapa, una sobre otra; rail junta la baranda de los bordes que se caminan."""
	p = epi.Piece(seed)
	for level in range(1, MOUNTAIN + 1):
		grid = at_least(level, levels)
		high = [style(lp, 11.0 + level, lambda v, level=level: level_at(v.x, v.y) < level) for lp in loops(lambda ch: ch == "H", grid)]
		part = epi.Piece(seed + level)
		for lp in high:
			cliff_wall(part, lp)
		cap(part, high, (holes or {}).get(level, ()))
		bmesh.ops.translate(part.bm, verts=part.bm.verts[:], vec=(0.0, 0.0, (level - 1) * TOP))
		merge(p, part)
		if rail is not None and level < MOUNTAIN:
			railing(rail, high, level)
	p.fixed = set(p.bm.faces)
	return p


def railing(p, high, level):
	"""Pared invisible sobre el borde de la terraza, salvo donde se baja a propósito: un salto (v) arriba o la boca de una
	escalinata (S) abajo, donde un abismo de una celda separa dos terrazas del mismo nivel (se cruza con la pluma) o junto a un
	poste del gancho, que se apunta desde abajo. Las caras miran a la terraza y no se recalculan: el colisionador solo choca
	de frente."""
	z = level * TOP
	for points, flags in high:
		nrm = normals(points)
		for i, a in enumerate(points):
			if not flags[i]:
				continue
			b = points[(i + 1) % len(points)]
			mid, n = (a + b) / 2, (nrm[i] + nrm[(i + 1) % len(points)]).normalized()
			up, down = mid - n * 0.6, mid + n * 1.0
			if cell_at(up.x, up.y) == "v" or cell_at(down.x, down.y) == "S" or level_at(down.x, down.y) >= level:
				continue
			if any((mid - Vector(post)).length < POST_GAP for post in POSTS):
				continue
			far = mid + n * (CELL + 1.0)
			if cell_at(down.x, down.y) in "~W" and level_at(far.x, far.y) >= level:
				continue
			v = [p.bm.verts.new((q.x, q.y, h)) for q, h in ((a, z - 0.3), (a, z + RAIL), (b, z + RAIL), (b, z - 0.3))]
			p.fixed.add(p.bm.faces.new(v))


ACROSS = 1.7
## Hasta dónde (m, en cuadro alrededor de la pared) se mira al cortar su celda: las caras del risco son chicas.
NEAR_WALL = 6.0


def _to_wall(wall):
	return Matrix.Rotation(-wall["yaw"], 4, "Z") @ Matrix.Translation(Vector((-wall["x"], wall["z"], 0.0)))


def _near_verts(bm, wall, radius=NEAR_WALL):
	x, y = wall["x"], -wall["z"]
	return [v for v in bm.verts if abs(v.co.x - x) < radius and abs(v.co.y - y) < radius]


def _cut(bm, wall, near=None):
	"""Corta bm por los bordes de la celda de la pared (en su marco: ±CELL/2 a lo largo, ±ACROSS de frente) y devuelve
	las caras de adentro. Con near (vértices), corta y busca solo entre las caras que tienen todos sus vértices ahí."""
	to_wall = _to_wall(wall)
	back = to_wall.inverted()
	if near is None:
		faces = bm.faces[:]
	else:
		close = set(near)
		faces = epi.uniq(f for v in near for f in v.link_faces if all(w in close for w in f.verts))
	for axis, limit in ((0, CELL / 2), (1, ACROSS)):
		for sign in (1, -1):
			co, no = Vector((0, 0, 0)), Vector((0, 0, 0))
			co[axis], no[axis] = sign * limit, sign
			edges = epi.uniq(e for f in faces for e in f.edges)
			verts = epi.uniq(v for f in faces for v in f.verts)
			res = bmesh.ops.bisect_plane(bm, geom=verts + edges + faces, plane_co=back @ co, plane_no=(back.to_3x3() @ no).normalized())
			faces = epi.uniq([f for f in faces if f.is_valid] + [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)])
	inside = lambda f: abs((to_wall @ f.calc_center_median()).x) < CELL / 2 and abs((to_wall @ f.calc_center_median()).y) < ACROSS  # noqa: E731
	return [f for f in faces if inside(f)]


def _keep(p, faces):
	keep = set(faces)
	bmesh.ops.delete(p.bm, geom=[f for f in p.bm.faces if f not in keep], context="FACES")
	_compact(p)


def _compact(p):
	"""Copia la malla: después de borrar mucho, Blender sigue recorriendo lo borrado en cada operación."""
	bm = p.bm.copy()
	p.bm.free()
	p.bm, p.uv = bm, bm.loops.layers.uv.verify()
	p.fixed = set(p.bm.faces)


def _cell_of(source, wall, seed):
	"""Lo de source en la celda de la pared, como pieza aparte: primero se recorta lo lejano, así el corte es chico."""
	piece = epi.Piece(seed)
	piece.bm = source.bm.copy()
	x, y = wall["x"], -wall["z"]
	bmesh.ops.delete(piece.bm, geom=[v for v in piece.bm.verts if abs(v.co.x - x) >= NEAR_WALL or abs(v.co.y - y) >= NEAR_WALL], context="VERTS")
	_compact(piece)
	_keep(piece, _cut(piece.bm, wall))
	return piece


def cracked_walls(collection, holes, rail):
	"""Las paredes rompibles salen del terreno con su celda alta: lo de la celda es la pared (con grietas en las dos
	caras, en el marco de la pared), y en su lugar el terreno lleva las jambas del paso abierto, que la pared tapa."""
	walls = DATA["cracked"]
	closed = [list(row) for row in LEVELS]
	for wall in walls:
		c, r = round(wall["x"] / CELL) - X0, round(wall["z"] / CELL) - Z0
		wall["low"] = LEVELS[r][c]
		closed[r][c] = max(LEVELS[rr][cc] for cc, rr in ((c + 1, r), (c - 1, r), (c, r + 1), (c, r - 1)) if 0 <= cc < GW and 0 <= rr < GH)
	terrain = rocks(closed, 11, holes)
	plugs = []
	for wall in walls:
		plug = _cell_of(terrain, wall, 31)
		bmesh.ops.transform(plug.bm, matrix=Matrix.Translation(Vector((0.0, 0.0, -wall["low"] * TOP))) @ _to_wall(wall), verts=plug.bm.verts)
		epi.cracks_both_faces(plug, CELL / 2, (0.0, 1.2), 0.92, 0.05, TOP - CAP - 0.05, "acantilado", "tierra")
		plugs.append(_build(plug, "muro_" + wall["name"], "wall", collection))
		plugs[-1].location.z = -1000.0
		bmesh.ops.delete(terrain.bm, geom=_cut(terrain.bm, wall, _near_verts(terrain.bm, wall)), context="FACES")
	_compact(terrain)
	opened = rocks(LEVELS, 11, holes, rail)
	_unfence_niches(rail, walls)
	for wall in walls:
		jamb = _cell_of(opened, wall, 32)
		mesh = bpy.data.meshes.new("tmp")
		jamb.bm.to_mesh(mesh)
		terrain.bm.from_mesh(mesh)
		bpy.data.meshes.remove(mesh)
		jamb.bm.free()
	terrain.fixed = set(terrain.bm.faces)
	return terrain, plugs + list(niche_lids(walls, closed, collection).values())


## Lo que la tapa de un nicho sale sobre el borde de su hueco (tapa el canto de pasto y su faldón) y cuánto la levanta.
NICHE_LID = (0.12, 0.02)


def _niche(c, r, low):
	"""Las celdas bajas encerradas del otro lado de la pared (c, r): el vecino de su nivel que no da a una zona abierta."""
	for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)):
		start = (c + dc, r + dr)
		seen, todo = {start}, [start]
		while todo and len(seen) <= 4:
			cc, rr = todo.pop()
			if not (0 <= cc < GW and 0 <= rr < GH) or LEVELS[rr][cc] != low:
				seen = set()
				break
			for n in ((cc + 1, rr), (cc - 1, rr), (cc, rr + 1), (cc, rr - 1)):
				if n != (c, r) and n not in seen and 0 <= n[0] < GW and 0 <= n[1] < GH and LEVELS[n[1]][n[0]] == low:
					seen.add(n)
					todo.append(n)
		if seen and len(seen) <= 4:
			return seen
	return set()


def _unfence_niches(rail, walls):
	"""Sin baranda alrededor de los nichos: con la pared entera se camina sobre su tapa; rota, se cae adentro y se sale
	por la pared."""
	grow = NICHE_LID[0] + 0.25
	boxes = []
	for wall in walls:
		c, r = round(wall["x"] / CELL) - X0, round(wall["z"] / CELL) - Z0
		for cc, rr in _niche(c, r, wall["low"]):
			at = cell_center(cc, rr)
			boxes.append((at.x - CELL / 2 - grow, at.x + CELL / 2 + grow, at.y - CELL / 2 - grow, at.y + CELL / 2 + grow))
	inside = lambda q: any(x0 < q.x < x1 and y0 < q.y < y1 for x0, x1, y0, y1 in boxes)  # noqa: E731
	gone = [f for f in rail.bm.faces if inside(f.calc_center_median())]
	rail.fixed -= set(gone)
	bmesh.ops.delete(rail.bm, geom=gone, context="FACES")
	print("baranda: %d caras sacadas de los nichos" % len(gone))


def niche_lids(walls, closed, collection):
	"""Tapa del color de la terraza sobre el nicho que esconde cada pared, en el marco de la pared (11.164): el juego la
	oculta al romperse. Las paredes que dan a una boca o a terreno alto no tienen nicho."""
	grow, lift = NICHE_LID
	lids = {}
	for wall in walls:
		c, r = round(wall["x"] / CELL) - X0, round(wall["z"] / CELL) - Z0
		cells = _niche(c, r, wall["low"])
		if not cells:
			continue
		lid = epi.Piece(33)
		z = closed[r][c] * TOP + lift
		faces = []
		for cc, rr in cells:
			at = cell_center(cc, rr)
			x0, x1, y0, y1 = at.x - CELL / 2, at.x + CELL / 2, at.y - CELL / 2, at.y + CELL / 2
			x0 -= 0 if (cc - 1, rr) in cells else grow
			x1 += 0 if (cc + 1, rr) in cells else grow
			y1 += 0 if (cc, rr - 1) in cells else grow
			y0 -= 0 if (cc, rr + 1) in cells else grow
			v = [lid.bm.verts.new((x, y, z)) for x, y in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
			faces.append(lid.bm.faces.new(v))
		for f in faces:
			f.normal_update()
		paint_role(lid, faces, "cap")
		lid.fixed.update(lid.bm.faces)
		bmesh.ops.transform(lid.bm, matrix=Matrix.Translation(Vector((0.0, 0.0, -wall["low"] * TOP))) @ _to_wall(wall), verts=lid.bm.verts)
		lids[wall["name"]] = _build(lid, "tapa_" + wall["name"], "wall", collection)
		lids[wall["name"]].location.z = -1000.0
	return lids


## Vano de las bocas de cueva, como paso_puerta del templo: medio ancho abajo, medio ancho arriba y alto (m); el marco
## que sale del risco (ancho de jamba, alto del dintel, cuánto sale) y cuánto se mete el túnel detrás de la cara.
MOUTH = (0.75, 0.6, 1.95)
FRAME = (0.28, 0.4, 0.18)
TUNNEL = 1.6


def _half(z, grow=0.0):
	bot, top, h = MOUTH
	return bot + (top - bot) * min(z, h) / h + grow


def cave_mouths(p):
	"""Las bocas de cueva se tallan en el risco: el vano trapezoidal con su túnel oscuro y, alrededor, el mismo risco
	sale como jambas y dintel."""
	bot, top, h = MOUTH
	jamb, lintel, out = FRAME
	for mouth in DATA.get("mouths", []):
		to = Matrix.Translation(Vector((0.0, 0.0, -mouth["y"]))) @ _to_wall(mouth)
		back, turn = to.inverted(), to.to_3x3()
		near = lambda f: (to @ f.calc_center_median()).xy.length < 3.5  # noqa: E731
		pool = epi.uniq(f for v in _near_verts(p.bm, mouth) for f in v.link_faces)
		front = [(to @ f.calc_center_median()).y for f in pool if near(f) and (turn @ f.normal).y < -0.5
			and abs((to @ f.calc_center_median()).x) < 0.4 and 0.3 < (to @ f.calc_center_median()).z < 1.6]
		if not front:
			print("boca", mouth["name"], "sin cara de risco delante")
			continue
		face = sorted(front)[len(front) // 2]
		print("boca", mouth["name"], "cara en y", round(face, 2))
		planes = [(Vector((0, 0, h)), Vector((0, 0, 1))), (Vector((0, 0, h + lintel)), Vector((0, 0, 1)))]
		planes += [(Vector((s * (bot + g), 0, 0)), Vector((s * h, 0, -(top - bot))).normalized()) for g in (0.0, jamb) for s in (1, -1)]
		for co, no in planes:
			faces = [f for f in pool if near(f)]
			edges = epi.uniq(e for f in faces for e in f.edges)
			verts = epi.uniq(v for f in faces for v in f.verts)
			res = bmesh.ops.bisect_plane(p.bm, geom=verts + edges + faces, plane_co=back @ co, plane_no=(back.to_3x3() @ no).normalized())
			pool = epi.uniq([f for f in pool if f.is_valid] + [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)])
		hole, frame = [], []
		for f in pool:
			if not near(f):
				continue
			c, n = to @ f.calc_center_median(), turn @ f.normal
			if abs(c.y - face) > 0.7 or (abs(n.z) > 0.9 and abs(c.z) < 0.1):
				continue
			if c.z < h and abs(c.x) < _half(c.z):
				hole.append(f)
			elif c.z < h + lintel and abs(c.x) < _half(c.z, jamb) and n.y < -0.3:
				frame.append(f)
		bmesh.ops.delete(p.bm, geom=hole, context="FACES")

		def inside(v):
			c = to @ v.co
			return abs(c.y - face) < 0.8 and -0.6 < c.z < h + 0.01 and abs(c.x) < _half(c.z) + 0.01
		rim = [e for e in epi.uniq(e for f in pool if f.is_valid for e in f.edges) if len(e.link_faces) == 1 and all(inside(v) for v in e.verts)]
		ext = bmesh.ops.extrude_edge_only(p.bm, edges=rim)
		for v in ext["geom"]:
			if isinstance(v, bmesh.types.BMVert):
				c = to @ v.co
				v.co = back @ Vector((c.x * 0.9, face + TUNNEL, c.z * 0.95))
		tunnel = [f for f in ext["geom"] if isinstance(f, bmesh.types.BMFace)]
		ext = bmesh.ops.extrude_face_region(p.bm, geom=frame)
		moved = [v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)]
		bmesh.ops.translate(p.bm, verts=moved, vec=back.to_3x3() @ Vector((0.0, -out, 0.0)))
		lit = [f for f in ext["geom"] if isinstance(f, bmesh.types.BMFace)]
		lit_set = set(lit)
		sides = [f for f in epi.uniq(f for v in moved for f in v.link_faces) if f not in lit_set]
		paint_role(p, lit, "lip", vary=0.06)
		paint_role(p, sides, "under")
		far = [p.bm.verts.new(back @ Vector(q)) for q in ((-bot, face + TUNNEL, -0.5), (bot, face + TUNNEL, -0.5), (top, face + TUNNEL, h), (-top, face + TUNNEL, h))]
		floor = [p.bm.verts.new(back @ Vector(q)) for q in ((-bot, face, 0.02), (bot, face, 0.02), (bot, face + TUNNEL, 0.02), (-bot, face + TUNNEL, 0.02))]
		dark = [p.bm.faces.new(far), p.bm.faces.new(floor)]
		for f in tunnel + dark:
			f.normal_update()
			c, n = to @ f.calc_center_median(), turn @ f.normal
			want = Vector((-c.x, -1.0 if f is dark[0] else 0.0, h / 2 - c.z if f is not dark[1] else 1.0))
			if n.dot(want) < 0:
				f.normal_flip()
		_paint(p, tunnel, "noche", "LIGHT", vary=0.05)
		p.paint(dark, "noche", "DARK")
	p.fixed = set(p.bm.faces)


## Franjas de X en que se parte el terreno: cada una sale en su terreno_organico.<k>.glb (ningún archivo pasa los 100 MB
## de GitHub); assets/epiphany/terreno_organico.tscn las junta. Cada franja va en BANDS bloques a lo largo (17.2): la
## cámara ve unos 40 x 18 m y un bloque fuera de ella (o de la sombra) no se dibuja; con la franja entera, sí.
STRIPS = 12
BANDS = 8
## Los cortes caen en n + SEAM_OFFSET m: un rayo vertical justo sobre la costura entre dos bloques pasa por la rendija y
## lo que se apoya en coordenadas redondas (portales, cofres, spawns) quedaría colgado.
SEAM_OFFSET = 0.37


def _cuts(lo, hi, count):
	return [math.floor(lo + (hi - lo) * k / count) + SEAM_OFFSET for k in range(1, count)]


X_CUTS = _cuts(BOUNDS[0].x, BOUNDS[1].x, STRIPS)
Y_CUTS = _cuts(BOUNDS[0].y, BOUNDS[1].y, BANDS)


def strip_of(x):
	return bisect.bisect(X_CUTS, x)


def band_of(y):
	return bisect.bisect(Y_CUTS, y)


def _cut_at(bm, axis, values):
	"""Corta bm en esos valores del eje, solo las caras que los cruzan: una cara larga (el fondo de un abismo) no deja
	un bloque del largo del mapa."""
	for value in values:
		cross = [f for f in bm.faces if min(v.co[axis] for v in f.verts) < value - 1e-4 < value + 1e-4 < max(v.co[axis] for v in f.verts)]
		if not cross:
			continue
		co, no = Vector((0, 0, 0)), Vector((0, 0, 0))
		co[axis], no[axis] = value, 1
		bmesh.ops.bisect_plane(bm, geom=epi.uniq(v for f in cross for v in f.verts) + epi.uniq(e for f in cross for e in f.edges) + cross, plane_co=co, plane_no=no)


def _keep_only(bm, outside):
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if outside(f.calc_center_median())], context="FACES")


def _split(piece, name, material, collection):
	"""Una pieza por bloque con las caras de la pieza cuyo centro cae en él, y su colisión aparte. Las normales se
	orientan en la pieza entera: por bloque, un pedazo suelto puede quedar dado vuelta."""
	_canonical(piece)
	bmesh.ops.recalc_face_normals(piece.bm, faces=[f for f in piece.bm.faces if f not in piece.fixed])
	_cut_at(piece.bm, 0, X_CUTS)
	_cut_at(piece.bm, 1, Y_CUTS)
	objects = []
	for k in range(STRIPS):
		strip = piece.bm.copy()
		_keep_only(strip, lambda c, k=k: strip_of(c.x) != k)
		for j in range(BANDS):
			part = epi.Piece()
			part.bm.free()
			part.bm = strip.copy()
			part.uv = part.bm.loops.layers.uv.verify()
			_keep_only(part.bm, lambda c, j=j: band_of(c.y) != j)
			if not part.bm.faces:
				part.bm.free()
				continue
			part.fixed = set(part.bm.faces)
			visual = _build(part, "%s_%d_%d" % (name, k, j), material, collection)
			objects += [visual, _collision(visual, collection)]
		strip.free()
	return objects


## La colisión de cada bloque (-colonly) se queda con esta fracción de los triángulos de la malla: Jolt arma la colisión
## en el hilo principal al entrar al overworld y con la malla entera tardaba 3,4 s. Antes se funden las caras coplanares
## (pisos y paredes no cambian) y después se simplifica el resto.
COLLISION_RATIO = 0.1


def _triangulate(bm, faces):
	"""Triángulos fijos: BEAUTY (y el exportador con n-gonos) desempata caras iguales según la memoria, y cada build salía
	distinto."""
	return bmesh.ops.triangulate(bm, faces=faces, quad_method="FIXED", ngon_method="EAR_CLIP")["face_map"]


def _collision(visual, collection):
	mesh = visual.data.copy()
	mesh.materials.clear()
	bm = bmesh.new()
	bm.from_mesh(mesh)
	target = sum(len(f.verts) - 2 for f in bm.faces) * COLLISION_RATIO
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
	bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1.0), use_dissolve_boundaries=False, verts=bm.verts, edges=bm.edges)
	_triangulate(bm, bm.faces[:])
	bm.to_mesh(mesh)
	bm.free()
	obj = bpy.data.objects.new(visual.name + "_col-colonly", mesh)
	collection.objects.link(obj)
	if len(mesh.polygons) > target:
		decimate = obj.modifiers.new("decimate", "DECIMATE")
		decimate.ratio = target / len(mesh.polygons)
		simple = bpy.data.meshes.new_from_object(obj.evaluated_get(bpy.context.evaluated_depsgraph_get()))
		obj.modifiers.remove(decimate)
		obj.data = simple
		bpy.data.meshes.remove(mesh)
	return obj


def _part(obj):
	xs = [(obj.matrix_world @ v.co).x for v in obj.data.vertices]
	return str(strip_of(sum(xs) / len(xs)) if xs else 0)


def _sort(seq, key):
	"""seq.sort pide un número por elemento: el puesto de cada uno en el orden de key."""
	rank = {e: i for i, e in enumerate(sorted(seq, key=key))}
	seq.sort(key=rank.__getitem__)


def _canonical(piece):
	"""Vértices, aristas y caras por dónde están: lo que recorre la malla en orden (normales, colisión, exportador) sale
	igual aunque los cortes las hayan creado en otro orden. Ordenar mueve los elementos en memoria y las referencias de
	piece.fixed quedarían en otras caras: viajan en el tag de cada cara."""
	bm = piece.bm
	for f in bm.faces:
		f.tag = f in piece.fixed
	_sort(bm.verts, lambda v: (tuple(round(c, 4) for c in v.co), sorted(tuple(round(c, 4) for c in f.calc_center_median()) for f in v.link_faces)))
	bm.verts.index_update()
	_sort(bm.edges, lambda e: tuple(sorted(v.index for v in e.verts)))
	_sort(bm.faces, lambda f: tuple(sorted(v.index for v in f.verts)))
	piece.fixed = {f for f in bm.faces if f.tag}
	for f in bm.faces:
		f.tag = False


def _build(piece, name, material, collection):
	bmesh.ops.delete(piece.bm, geom=[v for v in piece.bm.verts if not v.link_faces], context="VERTS")
	bmesh.ops.dissolve_degenerate(piece.bm, dist=1e-4, edges=piece.bm.edges[:])
	for new, old in _triangulate(piece.bm, piece.bm.faces[:]).items():
		if old in piece.fixed:
			piece.fixed.add(new)
	_canonical(piece)
	obj = piece.build(name, collection)
	if material:
		obj["material"] = material
	return obj


def main():
	epi.start()
	collection = bpy.data.collections.new("terreno")
	bpy.context.scene.collection.children.link(collection)
	pits, paths, waters, holes = {}, {}, {}, {}
	for level in range(MOUNTAIN):
		grid = at_level(level)
		pits[level] = [style(lp, 16.0, lambda v: cell_at(v.x, v.y) not in "~W") for lp in loops(lambda ch: ch in "~W", grid)]
		paths[level] = [style(lp, 20.0, lambda v: True, jagged=0.08, smooth=RELAX // 3) for lp in loops(lambda ch: ch in ":S", grid)]
		waters[level] = [style(lp, 24.0, lambda v, level=level: cell_at(v.x, v.y) in "H~W" or level_at(v.x, v.y) != level, amp=WATER_AMP, smooth=RELAX // 3) for lp in loops(lambda ch: ch == "w", grid)]
		holes[level] = [pt for pt, _f in pits[level] + paths[level] + waters[level]]
	objects = []
	rail = epi.Piece(40)
	terrain, walls = cracked_walls(collection, holes, rail)
	cave_mouths(terrain)
	objects += _split(terrain, "riscos", "wall", collection)
	guard = _build(rail, "baranda-colonly", None, collection)
	guard["group"] = WALK_GUARD
	objects.append(guard)
	ground = epi.Piece(12)
	outer = [Vector((BOUNDS[0].x, BOUNDS[0].y)), Vector((BOUNDS[1].x, BOUNDS[0].y)), Vector((BOUNDS[1].x, BOUNDS[1].y)), Vector((BOUNDS[0].x, BOUNDS[1].y))]
	paint_role(ground, fill(ground, [outer] + holes[0], 0.0, ground_height), "ground")
	for level in range(MOUNTAIN):
		z = level * TOP
		for lp in pits[level]:
			abyss(ground, lp, z)
		for lp in waters[level]:
			shallow(ground, lp)
		paint_role(ground, fill(ground, [pt for pt, _f in paths[level]], z + (PATH_LIFT if level else 0.0), ground_height if level == 0 else None), "path", vary=0.015)
	objects += _split(ground, "suelo", "outdoor", collection)
	objects += decor(load_meshes(), collection)
	epi.publish("terreno_organico", objects=objects, part=_part)
	for wall in walls:
		wall.location.z = 0.0
	epi.publish("muros_organicos", objects=walls)

main()
