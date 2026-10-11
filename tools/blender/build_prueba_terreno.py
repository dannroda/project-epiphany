# Prueba 12.14: la misma zona (MAP) armada con distintos bordes, para elegir cómo hacer el overworld menos cuadrado.
# Publica assets/epiphany/prueba_terreno_<variante>.glb; levels/pruebas_terreno.tscn las pone una al lado de la otra.
# blender -b -P tools/blender/build_prueba_terreno.py [-- variante ...]
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector, geometry, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

# Filas de norte a sur, celdas de 2 m. # monte (borde), H meseta/peñón, . pasto, : camino, ~ abismo, ^ escalinata
# (sube hacia el norte, dos celdas), T árbol.
MAP = [
	"################",
	"#HHHHHHH..T....#",
	"#HHHHHHH.......#",
	"#HHHHH^H...HH..#",
	"#T....^....HH..#",
	"#.....:.......~#",
	"#..T..::::::.~~#",
	"#.....::....~~~#",
	"#.....::..T..~.#",
	"######::########",
]
CELL = 2.0
PAD, PAD_SOUTH = 3, 4
TOP = 2.6
CAP = 0.15
DEPTH = -3.0
HIGH = "#H"
STRATA = (0.0, 0.12, 0.03, 0.16, 0.06, 0.13, 0.02)

VARIANTS = {
	"cuadrado": {"style": "square"},
	"diagonal": {"style": "chamfer"},
	"curva": {"style": "round"},
	"organico": {"style": "organic", "amp": 0.4},
	"diagonal_organico": {"style": "chamfer", "amp": 0.18},
	"organico_lomas": {"style": "organic", "amp": 0.4, "lomas": 0.3},
	"libre": {"style": "free", "amp": 0.4},
	"libre_mc": {"style": "free_mc", "amp": 0.4},
}

W, H = len(MAP[0]), len(MAP)
GRID = ["#" * (W + 2 * PAD)] * PAD + ["#" * PAD + row + "#" * PAD for row in MAP] + ["#" * PAD + "." * W + "#" * PAD] * PAD_SOUTH
GW, GH = len(GRID[0]), len(GRID)


def corner(c, r):
	return Vector(((c - PAD - W / 2) * CELL, (PAD + H / 2 - r) * CELL))


def cell_center(c, r):
	return (corner(c, r) + corner(c + 1, r + 1)) / 2


def cell_at(x, y):
	c = math.floor(x / CELL + PAD + W / 2)
	r = math.floor(PAD + H / 2 - y / CELL)
	if r >= GH:
		return "."
	if c < 0 or c >= GW or r < 0:
		return "#"
	return GRID[r][c]


BOUNDS = (corner(0, GH), corner(GW, 0))


# --- contornos ---

def loops(inside, wall_against=None):
	"""Contornos cerrados de las celdas donde inside(ch), con lo de adentro a la izquierda: [(puntos, ¿pared?)]. Un lado
	es pared si la vecina no es de adentro según wall_against (por defecto inside); afuera de la grilla, al sur no hay nada."""
	wall_against = wall_against or inside
	edges = {}
	sides = (((0, 1), (0, 1), (1, 1)), ((1, 0), (1, 1), (1, 0)), ((0, -1), (1, 0), (0, 0)), ((-1, 0), (0, 0), (0, 1)))
	for r in range(GH):
		for c in range(GW):
			if not inside(GRID[r][c]):
				continue
			for (dc, dr), a, b in sides:
				nc, nr = c + dc, r + dr
				in_grid = 0 <= nc < GW and 0 <= nr < GH
				if in_grid and inside(GRID[nr][nc]):
					continue
				neighbor = GRID[nr][nc] if in_grid else ("." if nr >= GH else "#")
				edges.setdefault((c + a[0], r + a[1]), []).append(((c + b[0], r + b[1]), not wall_against(neighbor)))
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


def chamfer(loop, cut=1.0, arc=0):
	points, flags = loop
	out_p, out_f = [], []
	n = len(points)
	for i in range(n):
		prev, here, nxt = points[i - 1], points[i], points[(i + 1) % n]
		d_in, d_out = (here - prev).normalized(), (nxt - here).normalized()
		if abs(d_in.dot(d_out)) > 0.99:
			out_p.append(here)
			out_f.append(flags[i])
			continue
		a, b = here - d_in * cut, here + d_out * cut
		joint = flags[i - 1] and flags[i]
		steps = max(1, arc)
		for k in range(steps):
			t = k / steps
			out_p.append(a * (1 - t) ** 2 + here * 2 * (1 - t) * t + b * t * t)
			out_f.append(joint)
		out_p.append(b)
		out_f.append(flags[i])
	return out_p, out_f


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


def wobble(loop, amp, seed):
	points, flags = loop
	moved = [p + nrm * amp * noise.noise(Vector((p.x * 0.42, p.y * 0.42, seed))) if flags[i] or flags[i - 1] else p
		for i, (p, nrm) in enumerate(zip(points, normals(points)))]
	return moved, flags


def style(loop, variant, seed, jagged=0.0):
	kind = variant["style"]
	if kind == "chamfer":
		loop = chamfer(loop)
	elif kind == "round":
		loop = chamfer(loop, arc=5)
	elif kind in ("organic", "free", "free_mc"):
		loop = chaikin(resample(loop, 1.0), 2)
	loop = resample(loop, 0.4)
	if variant.get("amp"):
		loop = wobble(loop, variant["amp"], seed)
	if jagged:
		rng = random.Random(seed)
		loop = ([p + nrm * (rng.random() - 0.5) * 2 * jagged for p, nrm in zip(loop[0], normals(loop[0]))], loop[1])
	return loop


# --- piezas ---

def lomas(variant):
	amount = variant.get("lomas", 0.0)
	return lambda x, y: amount * noise.noise(Vector((x * 0.3, y * 0.3, 3.7))) if amount else 0.0


def cliff_wall(p, loop, ground):
	"""Roca en estratos (como el risco del kit) a lo largo del contorno, de -0.5 a la tapa, mirando hacia afuera."""
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
				z += (p.rng.random() - 0.5) * 0.05
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
	p.paint([f for f in faces if f.normal.z > 0.35], "musgo", "MID", vary=0.1)
	p.paint([f for f in faces if f.normal.z < -0.15], "acantilado", "DARK")
	sides = [f for f in faces if -0.15 <= f.normal.z <= 0.35]
	row = lambda f: int((f.calc_center_median().z + 0.5) / row_height)  # noqa: E731
	p.paint([f for f in sides if row(f) < 2], "acantilado", "DARK", vary=0.12)
	p.paint([f for f in sides if row(f) == 3], "tierra", z_range=(row_height * 2 - 0.5, row_height * 5 - 0.5), vary=0.15)
	p.paint([f for f in sides if row(f) not in (0, 1, 3)], "acantilado", z_range=(-0.5, z1), vary=0.12)
	p.fixed.update(faces)


def cap(p, high_loops):
	"""Tapa de pasto sobre todo lo alto, un poco más ancha que la roca, con el borde que cuelga en puntas."""
	rims = []
	for points, flags in high_loops:
		rims.append(([pt + n * 0.12 if flags[i] or flags[i - 1] else pt for i, (pt, n) in enumerate(zip(points, normals(points)))], flags))
	top = fill(p, [r[0] for r in rims], TOP)
	p.paint(top, "pasto", "MID")
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
			drop = CAP + 0.06 + p.rng.random() * 0.22
			mid = (a + b) / 2 + out * 0.25 * drop
			hang.append(p.bm.faces.new((v[3], p.bm.verts.new((mid.x, mid.y, TOP - drop)), v[2])))
	for f in hang:
		f.normal_update()
	p.paint(hang, "pasto", "DARK")
	p.fixed.update(top + hang)


def fill(p, outlines, z, height=None):
	"""Tapa plana (con agujeros por paridad) de los contornos; height(x, y) la deforma después de cortarla en 1 m."""
	flat = [[Vector((pt.x, pt.y, z)) for pt in o] for o in outlines]
	tris = geometry.tessellate_polygon(flat)
	verts = [p.bm.verts.new(v) for o in flat for v in o]
	faces = []
	for tri in tris:
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
		for v in {v for f in faces for v in f.verts}:
			v.co.z = z + height(v.co.x, v.co.y)
		for f in faces:
			f.normal_update()
	p.fixed.update(faces)
	return faces


def abyss(p, loop, ground):
	"""Paredes del pozo hacia adentro, de la altura del suelo hasta DEPTH, y el fondo."""
	points, flags = loop
	nrm = normals(points, -1.0)
	rows = 7
	ring = []
	for pt, n in zip(points, nrm):
		top = ground(pt.x, pt.y)
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
	p.paint_bands(faces, [(DEPTH * 3 / 7, 1.0, "acantilado", "MID"), (DEPTH * 5 / 7, DEPTH * 3 / 7, "gris_4", "MID"), (DEPTH - 1, DEPTH * 5 / 7, "gris_5", "DARK")])
	floor = fill(p, [points], DEPTH)
	p.paint(floor, "gris_5", "DARK")
	p.fixed.update(faces + floor)


def blocker(p, loop):
	"""Baranda invisible al borde del pozo (los dos lados, para que no se pase de ninguno)."""
	points, _flags = loop
	nrm = normals(points)
	for i, pt in enumerate(points):
		q = points[(i + 1) % len(points)]
		a, b = pt + nrm[i] * 0.15, q + nrm[(i + 1) % len(points)] * 0.15
		v = [p.bm.verts.new((a.x, a.y, -0.2)), p.bm.verts.new((b.x, b.y, -0.2)), p.bm.verts.new((b.x, b.y, 1.5)), p.bm.verts.new((a.x, a.y, 1.5))]
		p.fixed.add(p.bm.faces.new(v))
		p.fixed.add(p.bm.faces.new(list(reversed([p.bm.verts.new(x.co) for x in v]))))


# --- terreno libre ---

def signed_distance(points, outlines):
	"""Distancia de cada punto (N×2) al contorno más cercano, positiva adentro (paridad de todos los contornos)."""
	import numpy as np
	seg_a = np.array([(pt.x, pt.y) for o in outlines for pt in o])
	seg_b = np.array([(o[(i + 1) % len(o)].x, o[(i + 1) % len(o)].y) for o in outlines for i in range(len(o))])
	result = np.empty(len(points))
	for start in range(0, len(points), 1500):
		q = points[start:start + 1500, None, :]
		ab = seg_b - seg_a
		t = np.clip(((q - seg_a) * ab).sum(-1) / np.maximum((ab * ab).sum(-1), 1e-9), 0.0, 1.0)
		dist = np.sqrt((((seg_a + t[..., None] * ab) - q) ** 2).sum(-1)).min(1)
		qy, qx = q[..., 1], q[..., 0]
		crosses = ((seg_a[:, 1] > qy) != (seg_b[:, 1] > qy)) & (qx < (seg_b[:, 0] - seg_a[:, 0]) * (qy - seg_a[:, 1]) / np.where(seg_b[:, 1] == seg_a[:, 1], 1e-9, seg_b[:, 1] - seg_a[:, 1]) + seg_a[:, 0])
		inside = crosses.sum(1) % 2 == 1
		result[start:start + 1500] = np.where(inside, dist, -dist)
	return result


def free_terrain(variant, paths, high, pits):
	"""Un solo campo de alturas sobre los mismos contornos orgánicos: laderas en vez de paredes, la escalinata es rampa."""
	import numpy as np
	step = 0.3
	x0, y0 = BOUNDS[0]
	nx, ny = int((BOUNDS[1].x - x0) / step) + 1, int((BOUNDS[1].y - y0) / step) + 1
	xs, ys = np.meshgrid(x0 + np.arange(nx) * step, y0 + np.arange(ny) * step)
	pts = np.stack([xs.ravel(), ys.ravel()], 1)
	smooth = lambda d, w: np.clip(0.5 + d / (2 * w), 0.0, 1.0) ** 2 * (3 - 2 * np.clip(0.5 + d / (2 * w), 0.0, 1.0))  # noqa: E731
	s_high = smooth(signed_distance(pts, [o for o, _f in high]), 0.7)
	s_pit = smooth(signed_distance(pts, [o for o, _f in pits]), 0.5)
	n = lambda x, y, f, z: noise.noise(Vector((x * f, y * f, z)))  # noqa: E731
	base = np.array([0.3 * n(x, y, 0.3, 3.7) for x, y in pts])
	ramp_c = next((c, r) for r in range(GH) for c in range(GW) if GRID[r][c] == "^" and GRID[r + 1][c] != "^")
	ramp_y0 = corner(*ramp_c).y - CELL
	ramp = np.array([TOP * min(1.0, max(0.0, (y - ramp_y0) / (2 * CELL))) if cell_at(x, y) == "^" else 0.0 for x, y in pts])
	h = base + (TOP - base) * s_high
	h = np.maximum(h, ramp)
	h = h + (DEPTH - h) * s_pit
	h = h.reshape(ny, nx)
	ground, rocks = epi.Piece(71), epi.Piece(72)
	for j in range(ny - 1):
		for i in range(nx - 1):
			quad = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
			corners = [Vector((x0 + a * step, y0 + b * step, float(h[b][a]) + 0.03 * noise.noise(Vector((a * 0.6, b * 0.6, 5.0))))) for a, b in quad]
			split_02 = abs(corners[0].z - corners[2].z) < abs(corners[1].z - corners[3].z)
			for tri in ((corners[0], corners[1], corners[2]), (corners[0], corners[2], corners[3])) if split_02 else ((corners[0], corners[1], corners[3]), (corners[1], corners[2], corners[3])):
				normal = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
				center = (tri[0] + tri[1] + tri[2]) / 3
				is_high = center.z > 0.5 or (normal.z < 0.8 and center.z > 0.1)
				piece = rocks if is_high else ground
				face = piece.bm.faces.new([piece.bm.verts.new(v) for v in tri])
				face.normal_update()
				piece.fixed.add(face)
				_paint_free(piece, face, normal, center, paths)
	return ground, rocks


def _paint_free(p, face, normal, center, paths):
	z = center.z
	if normal.z > 0.7 and z < -0.3:
		p.paint([face], "gris_5" if z < DEPTH * 5 / 7 else "gris_4", "DARK")
	elif normal.z > 0.7:
		if z < 0.6 and any(_inside(center, pts) for pts, _f in paths):
			p.paint([face], "tierra", "MID")
		else:
			p.paint([face], "pasto", "MID")
	elif z < 0:
		swatch = "acantilado" if z > DEPTH * 3 / 7 else "gris_4" if z > DEPTH * 5 / 7 else "gris_5"
		p.paint([face], swatch, "MID" if swatch != "gris_5" else "DARK", vary=0.08)
	else:
		row = int((z + 0.5) / ((TOP - CAP + 0.5) / 6))
		if row < 2:
			p.paint([face], "acantilado", "DARK", vary=0.05)
		elif row == 3:
			p.paint([face], "tierra", "MID", vary=0.05)
		else:
			p.paint([face], "acantilado", "MID", vary=0.05)


def _inside(point, polygon):
	inside = False
	for i, a in enumerate(polygon):
		b = polygon[i - 1]
		if (a.y > point.y) != (b.y > point.y) and point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
	return inside


# --- marching cubes ---

CUBE = [(x, y, z) for z in (0, 1) for y in (0, 1) for x in (0, 1)]
CUBE_EDGES = [(a, b) for a in range(8) for b in range(a + 1, 8) if bin(a ^ b).count("1") == 1]
CUBE_FACES = [(0, 2, 6, 4), (1, 3, 7, 5), (0, 1, 5, 4), (2, 3, 7, 6), (0, 1, 3, 2), (4, 5, 7, 6)]


def _mc_table():
	"""Triángulos (en aristas del cubo) de cada uno de los 256 casos: en cada cara se corta lo de adentro (en las caras
	ambiguas cada esquina de adentro por separado, así dos cubos vecinos coinciden), y los cortes se encadenan en
	polígonos que se abren en abanico. La orientación se arregla después con el gradiente."""
	edge_id = {frozenset(e): i for i, e in enumerate(CUBE_EDGES)}
	table = []
	for case in range(256):
		inside = [(case >> c) & 1 for c in range(8)]
		segments = []
		for face in CUBE_FACES:
			sides = [edge_id[frozenset((face[k], face[(k + 1) % 4]))] for k in range(4)]
			cut = [k for k in range(4) if inside[face[k]] != inside[face[(k + 1) % 4]]]
			if len(cut) == 2:
				segments.append((sides[cut[0]], sides[cut[1]]))
			elif len(cut) == 4:
				for k in range(4):
					if inside[face[k]]:
						segments.append((sides[k - 1], sides[k]))
		tris = []
		while segments:
			a, b = segments.pop()
			poly = [a, b]
			while True:
				nxt = next((s for s in segments if poly[-1] in s), None)
				if nxt is None:
					break
				segments.remove(nxt)
				other = nxt[1] if nxt[0] == poly[-1] else nxt[0]
				if other == poly[0]:
					break
				poly.append(other)
			tris += [(poly[0], poly[i], poly[i + 1]) for i in range(1, len(poly) - 1)]
		table.append(tris)
	return table


def volume_terrain(paths, high, pits, ramp):
	"""Un volumen (sólido donde la densidad es positiva) pasado a malla con marching cubes: el suelo con lomas, los
	altos como columnas con estratos que salen y entran (repisas, aleros), el pozo excavado y la rampa."""
	import numpy as np
	voxel = 0.33
	x0, y0 = BOUNDS[0]
	z0 = DEPTH - 0.5
	nx, ny, nz = int((BOUNDS[1].x - x0) / voxel) + 1, int((BOUNDS[1].y - y0) / voxel) + 1, int((TOP + 0.8 - z0) / voxel) + 1
	xs, ys = np.meshgrid(x0 + np.arange(nx) * voxel, y0 + np.arange(ny) * voxel, indexing="ij")
	pts = np.stack([xs.ravel(), ys.ravel()], 1)
	sd_high = signed_distance(pts, [o for o, _f in high]).reshape(nx, ny)
	sd_pit = signed_distance(pts, [o for o, _f in pits]).reshape(nx, ny)
	sd_ramp = signed_distance(pts, [o for o, _f in ramp]).reshape(nx, ny)
	base = np.array([0.3 * noise.noise(Vector((x * 0.3, y * 0.3, 3.7))) for x, y in pts]).reshape(nx, ny)
	ramp_c = next((c, r) for r in range(GH) for c in range(GW) if GRID[r][c] == "^" and GRID[r + 1][c] != "^")
	ramp_y0 = corner(*ramp_c).y - CELL
	ramp_h = np.clip((ys - ramp_y0) / (2 * CELL), 0.0, 1.0) * TOP
	row_height = (TOP - CAP + 0.5) / 6
	density = np.empty((nx, ny, nz))
	for k in range(nz):
		z = z0 + k * voxel
		row = min(6, max(0, round((z + 0.5) / row_height)))
		strata = STRATA[row] + 0.03 if z < TOP - CAP else 0.0
		rough = np.array([noise.noise(Vector((x * 0.9, y * 0.9, z * 0.9))) for x, y in pts]).reshape(nx, ny)
		column = np.minimum(TOP + 0.04 * rough - z, sd_high + strata + 0.12 * rough)
		solid = np.maximum(np.maximum(base - z, column), np.minimum(ramp_h - z, sd_ramp))
		carve = np.minimum(sd_pit + 0.25 * rough + 0.06 * min(0.0, z), z - DEPTH)
		density[:, :, k] = np.minimum(solid, -carve)
	table = _mc_table()
	cases = np.zeros((nx - 1, ny - 1, nz - 1), dtype=np.int32)
	for c, (dx, dy, dz) in enumerate(CUBE):
		cases |= (density[dx:nx - 1 + dx, dy:ny - 1 + dy, dz:nz - 1 + dz] > 0).astype(np.int32) << c
	ground, rocks = epi.Piece(71), epi.Piece(72)
	for i, j, k in zip(*np.nonzero((cases != 0) & (cases != 255))):
		values = [density[i + dx, j + dy, k + dz] for dx, dy, dz in CUBE]
		where = [Vector((x0 + (i + dx) * voxel, y0 + (j + dy) * voxel, z0 + (k + dz) * voxel)) for dx, dy, dz in CUBE]
		grad = Vector((
			sum(values[c] * (1 if CUBE[c][0] else -1) for c in range(8)),
			sum(values[c] * (1 if CUBE[c][1] else -1) for c in range(8)),
			sum(values[c] * (1 if CUBE[c][2] else -1) for c in range(8))))
		points = {}
		for tri in table[cases[i, j, k]]:
			for e in tri:
				if e not in points:
					a, b = CUBE_EDGES[e]
					t = values[a] / (values[a] - values[b])
					points[e] = where[a].lerp(where[b], t)
			v = [points[e] for e in tri]
			normal = (v[1] - v[0]).cross(v[2] - v[0])
			if normal.length < 1e-9:
				continue
			if normal.dot(grad) > 0:
				v = [v[0], v[2], v[1]]
				normal = -normal
			normal.normalize()
			center = (v[0] + v[1] + v[2]) / 3
			piece = rocks if center.z > 0.5 or (normal.z < 0.8 and center.z > 0.1) else ground
			piece.bm.faces.new([piece.bm.verts.new(x) for x in v])
	cuts = [-0.5 + row_height * r for r in range(1, 6)] + [TOP - 0.08, DEPTH * 3 / 7, DEPTH * 5 / 7]
	for piece in (ground, rocks):
		bmesh.ops.remove_doubles(piece.bm, verts=list(piece.bm.verts), dist=0.0005)
		for z in cuts:
			geom = list(piece.bm.verts) + list(piece.bm.edges) + list(piece.bm.faces)
			bmesh.ops.bisect_plane(piece.bm, geom=geom, plane_co=(0, 0, z), plane_no=(0, 0, 1))
		for face in list(piece.bm.faces):
			face.normal_update()
			center = face.calc_center_median()
			if face.normal.z < -0.2:
				piece.paint([face], "acantilado", "DARK")
			elif center.z > TOP - 0.08 and face.normal.z <= 0.7:
				piece.paint([face], "pasto", "DARK")
			else:
				_paint_free(piece, face, face.normal, center, [])
		bmesh.ops.dissolve_limit(piece.bm, angle_limit=math.radians(3), verts=list(piece.bm.verts), edges=list(piece.bm.edges), delimit={"UV"})
		bmesh.ops.triangulate(piece.bm, faces=list(piece.bm.faces))
	for points, _flags in paths:
		ground.paint(fill(ground, [points], 0.05, lambda x, y: 0.3 * noise.noise(Vector((x * 0.3, y * 0.3, 3.7)))), "tierra", "MID")
	for piece in (ground, rocks):
		piece.fixed.update(piece.bm.faces)
		print("marching cubes:", len(piece.bm.faces), "triángulos")
	return ground, rocks


# --- decoración y armado ---

NATURE = ["ichu_mata", "flores", "tola", "piedra_chica_a", "piedra_chica_b", "quenoa_grande", "quenoa_chica", "cardon_a"]
WINDY = {"ichu_mata", "flores", "tola", "quenoa_grande", "quenoa_chica"}
## Por tipo de celda: [(pieza, probabilidad)] — hasta dos cosas por celda.
SCATTER = {
	".": [("ichu_mata", 0.35), ("flores", 0.14), ("piedra_chica_a", 0.08), ("piedra_chica_b", 0.06), ("tola", 0.06)],
	":": [("piedra_chica_b", 0.15)],
	"#": [("quenoa_grande", 0.16), ("quenoa_chica", 0.12), ("ichu_mata", 0.3), ("cardon_a", 0.06)],
	"H": [("ichu_mata", 0.25), ("flores", 0.1)],
	"T": [("quenoa_grande", 1.0)],
}


def load_meshes():
	art = os.path.join(epi.ROOT, "art", "blender")
	meshes = {}
	for blend, names in ((os.path.join(art, "naturaleza.blend"), NATURE), (os.path.join(art, "terreno_overworld.blend"), ["escalinata"])):
		with bpy.data.libraries.load(blend, link=False) as (src, dst):
			dst.objects = [n for n in names]
		for obj in dst.objects:
			mesh = obj.data
			mesh.materials.clear()
			mesh.materials.append(epi.palette.palette_material())
			meshes[obj.name.split(".")[0]] = mesh
			bpy.data.objects.remove(obj)
	return meshes


def decor_spots(seed):
	spots = []
	for r in range(GH):
		for c in range(GW):
			ch = GRID[r][c]
			rng = random.Random(seed * 100003 + r * 131 + c)
			center = cell_center(c, r)
			for name, chance in SCATTER.get(ch, []):
				if rng.random() < chance and len([s for s in spots if s[2] == (c, r)]) < 2:
					jitter = 0.0 if ch == "T" else 0.6
					spots.append((name, center + Vector(((rng.random() - 0.5) * 2 * jitter, (rng.random() - 0.5) * 2 * jitter)), (c, r), rng.random() * math.tau))
	return spots


def build_variant(name, variant, meshes, collection):
	seed = sum(map(ord, name))
	objects = []
	if variant["style"] == "free_mc":
		high = [style(lp, variant, seed) for lp in loops(lambda ch: ch in HIGH)]
		pits = [style(lp, variant, seed + 5) for lp in loops(lambda ch: ch == "~")]
		paths = [style(lp, variant, seed + 9, jagged=0.08) for lp in loops(lambda ch: ch == ":")]
		ramp = [style(lp, {"style": "square"}, seed) for lp in loops(lambda ch: ch == "^")]
		ground, rocks = volume_terrain(paths, high, pits, ramp)
		objects.append(_build(ground, "suelo-col", "outdoor", collection))
		objects.append(_build(rocks, "riscos-col", "wall", collection))
	elif variant["style"] == "free":
		high = [style(lp, variant, seed) for lp in loops(lambda ch: ch in HIGH)]
		pits = [style(lp, variant, seed + 5) for lp in loops(lambda ch: ch == "~")]
		paths = [style(lp, variant, seed + 9, jagged=0.08) for lp in loops(lambda ch: ch == ":")]
		ground, rocks = free_terrain(variant, paths, high, pits)
		objects.append(_build(ground, "suelo-col", "outdoor", collection))
		objects.append(_build(rocks, "riscos-col", "wall", collection))
	else:
		ground_h = lomas(variant)
		high = [style(lp, variant, seed) for lp in loops(lambda ch: ch in HIGH)]
		pits = [style(lp, variant, seed + 5) for lp in loops(lambda ch: ch == "~")]
		paths = [style(lp, variant, seed + 9, jagged=0.08) for lp in loops(lambda ch: ch == ":")]
		rocks = epi.Piece(seed)
		for lp in high:
			cliff_wall(rocks, lp, ground_h)
		cap(rocks, high)
		objects.append(_build(rocks, "riscos-col", "wall", collection))
		ground = epi.Piece(seed + 1)
		outer = [Vector((BOUNDS[0].x, BOUNDS[0].y)), Vector((BOUNDS[1].x, BOUNDS[0].y)), Vector((BOUNDS[1].x, BOUNDS[1].y)), Vector((BOUNDS[0].x, BOUNDS[1].y))]
		ground.paint(fill(ground, [outer] + [pt for pt, _f in pits], 0.0, ground_h if variant.get("lomas") else None), "pasto", "MID")
		for lp in pits:
			abyss(ground, lp, ground_h)
		for points, _flags in paths:
			ground.paint(fill(ground, [points], 0.012, ground_h if variant.get("lomas") else None), "tierra", "MID", vary=0.04)
		objects.append(_build(ground, "suelo-col", "outdoor", collection))
		c, r = next((c, r) for r in range(GH) for c in range(GW) if GRID[r][c] == "^" and GRID[r + 1][c] != "^")
		stairs = bpy.data.objects.new("escalinata-col", meshes["escalinata"])
		stairs.location = (*cell_center(c, r), 0.0)
		stairs["material"] = "outdoor"
		collection.objects.link(stairs)
		objects.append(stairs)
	rail = epi.Piece(seed + 2)
	for lp in pits:
		blocker(rail, lp)
	objects.append(_build(rail, "abismo_tope-colonly", None, collection))
	bpy.context.view_layer.update()
	depsgraph = bpy.context.evaluated_depsgraph_get()
	for kind, spot, _cell, angle in decor_spots(seed):
		hit, location, normal, _i, _obj, _m = bpy.context.scene.ray_cast(depsgraph, Vector((spot.x, spot.y, 20.0)), Vector((0, 0, -1)))
		if not hit or normal.z < 0.85 or location.z < -0.5:
			continue
		obj = bpy.data.objects.new(kind, meshes[kind])
		obj.location = location
		obj.rotation_euler.z = angle
		obj["material"] = "wind" if kind in WINDY else "outdoor"
		collection.objects.link(obj)
		objects.append(obj)
	return objects


def _build(piece, name, material, collection):
	bmesh.ops.delete(piece.bm, geom=[v for v in piece.bm.verts if not v.link_faces], context="VERTS")
	obj = piece.build(name, collection)
	if material:
		obj["material"] = material
	return obj


def main():
	wanted = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(VARIANTS)
	epi.start()
	meshes = load_meshes()
	for name in wanted:
		collection = bpy.data.collections.new(name)
		bpy.context.scene.collection.children.link(collection)
		objects = build_variant(name, VARIANTS[name], meshes, collection)
		epi.publish("prueba_terreno_" + name, objects=objects)
		for obj in list(collection.objects):
			bpy.data.objects.remove(obj)
		bpy.data.collections.remove(collection)


main()
