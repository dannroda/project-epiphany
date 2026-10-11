# Terreno del overworld con bordes orgánicos y lomas (12.15, la variante 6 de 12.14): lee tools/terreno_overworld.json
# (lo escribe tools/export_terreno_overworld.gd desde el GridMap) y publica assets/epiphany/terreno_organico.glb.
# Cerca de los puntos fijos (lo jugable, la decoración, las piezas que quedan en el GridMap) los bordes siguen la grilla
# y el piso queda plano; en los pasos de una celda la roca solo se mete, no se come el paso.
# blender -b -P tools/blender/build_terreno_organico.py
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
X0, Z0 = DATA["origin"]
CELL = DATA["cell"]
GW, GH = len(GRID[0]), len(GRID)
TOP = 2.6
CAP = 0.15
DEPTH = -3.0
AMP = 0.4
LOMAS = 0.3
STRATA = (0.0, 0.12, 0.03, 0.16, 0.06, 0.13, 0.02)
## Distancia (m) desde el borde de un punto fijo en la que el terreno pasa de quieto a orgánico.
FADE = 2.0
CHUNK = 16.0
## Ancho (m) de la franja donde un estilo de región se mezcla con el de al lado.
BAND = 4.0
REGIONS = [(r["style"], r["rect"][0], -r["rect"][3], r["rect"][2], -r["rect"][1]) for r in DATA.get("regions", [])]
## Estilo de terreno de cada región (AreaZone.terrain_style): papel → (franja, tono); lo que falta sale de DEFAULT.
DEFAULT = {
	"ground": ("pasto", "MID"), "path": ("tierra", "MID"), "cap": ("pasto", "MID"), "hang": ("pasto", "DARK"),
	"ledge": ("musgo", "MID"), "under": ("acantilado", "DARK"), "base": ("acantilado", "DARK"), "band": ("tierra", None),
	"rock": ("acantilado", None), "abyss_top": ("acantilado", "MID"), "abyss_mid": ("gris_4", "MID"), "abyss_low": ("gris_5", "DARK"),
}
STYLES = {
	"necropolis": {"ground": ("tierra", "MID"), "path": ("acantilado", "LIGHT"), "cap": ("tierra", "MID"), "hang": ("acantilado", "DARK"),
		"ledge": ("tierra", "LIGHT"), "band": ("roca_naranja", None)},
	"laguna": {"ground": ("musgo", "MID"), "path": ("tierra", "LOW"), "cap": ("musgo", "MID"), "hang": ("musgo", "DARK"),
		"band": ("piedra", "LOW"), "rock": ("piedra", None), "under": ("piedra", "DARK"), "base": ("piedra", "DARK")},
	"cumbre": {"ground": ("cristal", "LIGHT"), "path": ("piedra", "MID"), "cap": ("cristal", "LIGHT"), "hang": ("cristal", "MID"),
		"ledge": ("cristal", "LIGHT"), "under": ("ladrillo", "DARK"), "base": ("ladrillo", "DARK"), "band": ("piedra", "MID"), "rock": ("ladrillo", None)},
	"explanada": {"path": ("piedra_templo", "LOW")},
	"cardonal": {"ground": ("tierra", "LIGHT"), "path": ("acantilado", "LIGHT"), "cap": ("tierra", "MID"), "hang": ("acantilado", "MID"),
		"ledge": ("tierra", "MID"), "band": ("roca_naranja", None), "rock": ("roca_naranja", None)},
	"quebrada": {"abyss_top": ("roca_naranja", "MID"), "abyss_mid": ("acantilado", "DARK"), "band": ("roca_naranja", None)},
}
FIXED = np.array([(x, -z, r) for x, z, r in DATA["fixed"]]).reshape(-1, 3)
DECOR = np.array([(x, -z, r) for x, z, r in DATA["decor"]]).reshape(-1, 3)
FLAT = np.concatenate([FIXED, DECOR])


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


def style(loop, seed, solid, jagged=0.0):
	"""Contorno orgánico; solid(ch) dice qué es el lado de adentro, para no achicar pasos de una celda."""
	square = resample(loop, 0.4)
	points, flags = resample(chaikin(resample(loop, 1.0), 2), 0.4)
	nrm = normals(points)
	near_decor = gap(np.array([(p.x, p.y) for p in points]), DECOR) < 1.2
	moved = []
	for i, (p, n) in enumerate(zip(points, nrm)):
		if not (flags[i] or flags[i - 1]):
			moved.append(p)
			continue
		push = AMP * noise.noise(Vector((p.x * 0.42, p.y * 0.42, seed)))
		probe = p + n * (CELL * 1.2)
		if push > 0 and (near_decor[i] or solid(cell_at(probe.x, probe.y))):
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
	for e in {e for f in faces for e in f.edges}:
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
	for style, group in groups.items():
		swatch, style_shade = STYLES.get(style, {}).get(role, DEFAULT[role])
		p.paint(group, swatch, style_shade or shade or "GRADIENT", z_range=z_range, vary=vary)


def lomas(x, y):
	return LOMAS * noise.noise(Vector((x * 0.3, y * 0.3, 3.7)))


# --- piezas ---

def cliff_wall(p, loop):
	"""Roca en estratos a lo largo del contorno, de -0.5 a la tapa, mirando hacia afuera."""
	points, flags = loop
	z1 = TOP - CAP
	nrm = normals(points)
	rows = len(STRATA) - 1
	ring = []
	for pt, n in zip(points, nrm):
		col = []
		for k in range(rows + 1):
			z = -0.5 + (z1 + 0.5) * k / rows
			out = 0.0
			if 0 < k < rows:
				out = 0.03 + STRATA[k] + 0.08 * (0.5 + 0.5 * noise.noise(Vector((pt.x * 1.7, pt.y * 1.7, z * 1.7))))
				z += 0.025 * noise.noise(Vector((pt.x * 5.3, pt.y * 5.3, k * 1.9)))
			col.append(p.bm.verts.new((pt.x + n.x * out, pt.y + n.y * out, z)))
		ring.append(col)
	faces = []
	for i in range(len(points)):
		if not flags[i]:
			continue
		a, b = ring[i], ring[(i + 1) % len(points)]
		for k in range(rows):
			for tri in ((a[k], b[k], b[k + 1]), (a[k], b[k + 1], a[k + 1])):
				faces.append(p.bm.faces.new(tri))
	for f in faces:
		f.normal_update()
	row_height = (z1 + 0.5) / 6
	paint_role(p, [f for f in faces if f.normal.z > 0.35], "ledge", vary=0.1)
	paint_role(p, [f for f in faces if f.normal.z < -0.15], "under")
	sides = [f for f in faces if -0.15 <= f.normal.z <= 0.35]
	row = lambda f: int((f.calc_center_median().z + 0.5) / row_height)  # noqa: E731
	paint_role(p, [f for f in sides if row(f) < 2], "base", vary=0.12)
	paint_role(p, [f for f in sides if row(f) == 3], "band", z_range=(row_height * 2 - 0.5, row_height * 5 - 0.5), vary=0.15)
	paint_role(p, [f for f in sides if row(f) not in (0, 1, 3)], "rock", z_range=(-0.5, z1), vary=0.12)
	p.fixed.update(faces)


def cap(p, high_loops):
	"""Tapa de pasto sobre todo lo alto, un poco más ancha que la roca, con el borde que cuelga en puntas."""
	rims = []
	for points, flags in high_loops:
		rims.append(([pt + n * 0.12 if flags[i] or flags[i - 1] else pt for i, (pt, n) in enumerate(zip(points, normals(points)))], flags))
	top = fill(p, [r[0] for r in rims], TOP, (lambda xy: np.zeros(len(xy))) if REGIONS else None)
	paint_role(p, top, "cap")
	hang = []
	for points, flags in rims:
		for i, a in enumerate(points):
			if not flags[i]:
				continue
			b = points[(i + 1) % len(points)]
			d = b - a
			out = Vector((d.y, -d.x)).normalized()
			v = [p.bm.verts.new((a.x, a.y, TOP)), p.bm.verts.new((b.x, b.y, TOP)), p.bm.verts.new((b.x, b.y, TOP - CAP)), p.bm.verts.new((a.x, a.y, TOP - CAP))]
			hang.append(p.bm.faces.new((v[0], v[3], v[2], v[1])))
			drop = CAP + 0.06 + 0.22 * (0.5 + 0.5 * noise.noise(Vector((a.x * 3.1 + b.x, a.y * 3.1 + b.y, 8.0))))
			mid = (a + b) / 2 + out * 0.25 * drop
			hang.append(p.bm.faces.new((v[3], p.bm.verts.new((mid.x, mid.y, TOP - drop)), v[2])))
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


def fill(p, outlines, z, height=None):
	"""Tapa plana (con agujeros por paridad) de los contornos; height la deforma después de cortarla en 1 m."""
	faces = []
	for group in islands(outlines):
		flat = [[Vector((pt.x, pt.y, z)) for pt in outlines[i]] for i in group]
		verts = [p.bm.verts.new(v) for o in flat for v in o]
		for tri in geometry.tessellate_polygon(flat):
			try:
				faces.append(p.bm.faces.new([verts[i] for i in reversed(tri)]))
			except ValueError:
				pass
	for f in faces:
		f.normal_update()
		if f.normal.z < 0:
			f.normal_flip()
	if height:
		geom = list({e for f in faces for e in f.edges}) + faces + list({v for f in faces for v in f.verts})
		for axis, lo, hi in ((0, BOUNDS[0].x, BOUNDS[1].x), (1, BOUNDS[0].y, BOUNDS[1].y)):
			for k in range(int(lo) + 1, int(hi)):
				co, no = Vector((0, 0, 0)), Vector((0, 0, 0))
				co[axis], no[axis] = k, 1
				res = bmesh.ops.bisect_plane(p.bm, geom=geom, plane_co=co, plane_no=no)
				geom = list({g for g in geom if g.is_valid} | set(res["geom"]))
		faces = [g for g in geom if isinstance(g, bmesh.types.BMFace)]
		verts = list({v for f in faces for v in f.verts})
		for v, h in zip(verts, height(np.array([(v.co.x, v.co.y) for v in verts]))):
			v.co.z = z + h
		for f in faces:
			f.normal_update()
	p.fixed.update(faces)
	return faces


def ground_height(xy):
	return np.array([lomas(x, y) for x, y in xy]) * freedom(xy, FLAT)


def abyss(p, loop):
	"""Paredes del pozo hacia adentro, de la altura del suelo hasta DEPTH, y el fondo."""
	points, _flags = loop
	nrm = normals(points, -1.0)
	tops = ground_height(np.array([(pt.x, pt.y) for pt in points]))
	rows = 7
	ring = []
	for pt, n, top in zip(points, nrm, tops):
		col = []
		for k in range(rows + 1):
			z = top + (DEPTH - top) * k / rows
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
	depth = lambda f: f.calc_center_median().z  # noqa: E731
	paint_role(p, [f for f in faces if depth(f) >= DEPTH * 3 / 7], "abyss_top")
	paint_role(p, [f for f in faces if DEPTH * 5 / 7 <= depth(f) < DEPTH * 3 / 7], "abyss_mid")
	paint_role(p, [f for f in faces if depth(f) < DEPTH * 5 / 7], "abyss_low")
	floor = fill(p, [points], DEPTH)
	p.paint(floor, "gris_5", "DARK")
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
					spots.append((name, spot, rng.random() * math.tau))
					placed += 1
	if not spots:
		return spots
	far = gap(np.array([(s[1].x, s[1].y) for s in spots]), FLAT)
	return [s for s, d in zip(spots, far) if d > 0.6]


def decor(meshes, collection):
	"""Las plantas y piedras juntadas en una malla por pedazo de CHUNK m y por material, para pocas llamadas de dibujo."""
	bpy.context.view_layer.update()
	depsgraph = bpy.context.evaluated_depsgraph_get()
	groups = {}
	for kind, spot, angle in decor_spots():
		hit, location, normal, _i, _obj, _m = bpy.context.scene.ray_cast(depsgraph, Vector((spot.x, spot.y, 20.0)), Vector((0, 0, -1)))
		if not hit or normal.z < 0.85 or location.z < -0.5:
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
	return objects


def rocks(grid, seed):
	high = [style(lp, 11.0, lambda ch: ch != "H") for lp in loops(lambda ch: ch == "H", grid)]
	p = epi.Piece(seed)
	for lp in high:
		cliff_wall(p, lp)
	cap(p, high)
	return p


ACROSS = 1.7


def _to_wall(wall):
	return Matrix.Rotation(-wall["yaw"], 4, "Z") @ Matrix.Translation(Vector((-wall["x"], wall["z"], 0.0)))


def _cut(bm, wall):
	"""Corta bm por los bordes de la celda de la pared (en su marco: ±CELL/2 a lo largo, ±ACROSS de frente)."""
	to_wall = _to_wall(wall)
	back = to_wall.inverted()
	for axis, limit in ((0, CELL / 2), (1, ACROSS)):
		for sign in (1, -1):
			co, no = Vector((0, 0, 0)), Vector((0, 0, 0))
			co[axis], no[axis] = sign * limit, sign
			bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=back @ co, plane_no=(back.to_3x3() @ no).normalized())
	inside = lambda f: abs((to_wall @ f.calc_center_median()).x) < CELL / 2 and abs((to_wall @ f.calc_center_median()).y) < ACROSS  # noqa: E731
	return [f for f in bm.faces if inside(f)], [f for f in bm.faces if not inside(f)]


def _keep(p, faces):
	keep = set(faces)
	bmesh.ops.delete(p.bm, geom=[f for f in p.bm.faces if f not in keep], context="FACES")
	p.fixed = set(p.bm.faces)


def cracked_walls(collection):
	"""Las paredes rompibles salen del terreno con su celda alta: lo de la celda es la pared (con grietas en las dos
	caras, en el marco de la pared), y en su lugar el terreno lleva las jambas del paso abierto, que la pared tapa."""
	walls = DATA["cracked"]
	closed = list(GRID)
	for wall in walls:
		c, r = round(wall["x"] / CELL) - X0, round(wall["z"] / CELL) - Z0
		closed[r] = closed[r][:c] + "H" + closed[r][c + 1:]
	terrain = rocks(closed, 11)
	plugs = []
	for wall in walls:
		plug = epi.Piece(31)
		plug.bm = terrain.bm.copy()
		plug.uv = plug.bm.loops.layers.uv.verify()
		inside, _outside = _cut(plug.bm, wall)
		_keep(plug, inside)
		bmesh.ops.transform(plug.bm, matrix=_to_wall(wall), verts=plug.bm.verts)
		epi.cracks_both_faces(plug, CELL / 2, (0.0, 1.2), 0.92, 0.05, TOP - CAP - 0.05, "acantilado", "tierra")
		plugs.append(_build(plug, "muro_" + wall["name"], "wall", collection))
		plugs[-1].location.z = -1000.0
		_inside, outside = _cut(terrain.bm, wall)
		_keep(terrain, outside)
	opened = rocks(GRID, 11)
	for wall in walls:
		jamb = epi.Piece(32)
		jamb.bm = opened.bm.copy()
		jamb.uv = jamb.bm.loops.layers.uv.verify()
		inside, _outside = _cut(jamb.bm, wall)
		_keep(jamb, inside)
		mesh = bpy.data.meshes.new("tmp")
		jamb.bm.to_mesh(mesh)
		terrain.bm.from_mesh(mesh)
		bpy.data.meshes.remove(mesh)
		jamb.bm.free()
	terrain.fixed = set(terrain.bm.faces)
	return terrain, plugs


def _build(piece, name, material, collection):
	bmesh.ops.delete(piece.bm, geom=[v for v in piece.bm.verts if not v.link_faces], context="VERTS")
	obj = piece.build(name, collection)
	if material:
		obj["material"] = material
	return obj


def main():
	epi.start()
	collection = bpy.data.collections.new("terreno")
	bpy.context.scene.collection.children.link(collection)
	pits = [style(lp, 16.0, lambda ch: ch != "~") for lp in loops(lambda ch: ch == "~")]
	paths = [style(lp, 20.0, lambda ch: True, jagged=0.08) for lp in loops(lambda ch: ch == ":")]
	objects = []
	terrain, walls = cracked_walls(collection)
	objects.append(_build(terrain, "riscos-col", "wall", collection))
	ground = epi.Piece(12)
	outer = [Vector((BOUNDS[0].x, BOUNDS[0].y)), Vector((BOUNDS[1].x, BOUNDS[0].y)), Vector((BOUNDS[1].x, BOUNDS[1].y)), Vector((BOUNDS[0].x, BOUNDS[1].y))]
	paint_role(ground, fill(ground, [outer] + [pt for pt, _f in pits] + [pt for pt, _f in paths], 0.0, ground_height), "ground")
	for lp in pits:
		abyss(ground, lp)
	paint_role(ground, fill(ground, [pt for pt, _f in paths], 0.0, ground_height), "path", vary=0.015)
	objects.append(_build(ground, "suelo-col", "outdoor", collection))
	objects += decor(load_meshes(), collection)
	epi.publish("terreno_organico", objects=objects)
	for wall in walls:
		wall.location.z = 0.0
	epi.publish("muros_organicos", objects=walls)


main()
