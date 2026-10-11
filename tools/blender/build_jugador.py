# Jugador estilo Megaman ZX (12.12): 1,55 m, ~4,5 cabezas, traje oscuro, armadura facetada de bordes nítidos.
# Cada pieza es un loft de secciones superelípticas y se pinta con un degradé de su tira de la paleta (claro arriba,
# oscuro abajo) para imitar las texturas pintadas; la cara son calcomanías proyectadas sobre la cabeza.
# blender -b -P tools/blender/build_jugador.py
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402
from toon import apply_mod, skin_mesh  # noqa: E402
from mathutils.kdtree import KDTree  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEXTURE = os.path.join(ROOT, "assets", "epiphany", "jugador_colores.png")
# tira → (claro, oscuro); la textura del personaje tiene una columna por tira con su degradé
COLORS = {
	"rojo": ("ff4d5e", "9c0f2c"), "traje": ("5e5880", "221d36"), "blanco": ("ffffff", "c4c0d0"), "oro": ("ffe27a", "dc7f12"),
	"neon": ("e6ffff", "2cc8f0"), "piel": ("ffe4cf", "e6a585"), "pelo": ("5068a8", "17204a"), "cobre": ("90f2cc", "1e8a72"),
	"iris": ("a8ffc8", "0e7a52"), "negro": ("2a2236", "120e1a"), "suela": ("4c3e60", "1e1828"), "boca": ("c86a6a", "9c4a50"),
}
NAMES = list(COLORS)


def build_texture():
	w, h = 16 * len(NAMES), 64
	img = bpy.data.images.new("jugador_colores", w, h)
	px = [0.0] * (w * h * 4)
	for i, k in enumerate(NAMES):
		a, b = (tuple(int(c[j:j + 2], 16) / 255 for j in (0, 2, 4)) for c in COLORS[k])
		for y in range(h):
			t = y / (h - 1)
			col = [b[j] + (a[j] - b[j]) * t for j in range(3)]
			lin = [((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92 for c in col]
			for x in range(i * 16, (i + 1) * 16):
				o = (y * w + x) * 4
				px[o:o + 4] = lin + [1.0]
	img.pixels = px
	img.filepath_raw = TEXTURE
	img.file_format = "PNG"
	img.save()
	return img


def palette_uv(name, t):
	return ((NAMES.index(name) + 0.5) / len(NAMES), 0.04 + 0.92 * t)


def material(img):
	m = bpy.data.materials.new("jugador")
	m.use_nodes = True
	nt = m.node_tree
	tex = nt.nodes.new("ShaderNodeTexImage")
	tex.image = img
	tex.interpolation = "Closest"
	nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
	return m

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
FRONT = Vector((0, -1, 0))

ROJO = ("rojo", 0.45, 0.95)
ROJO_OSC = ("rojo", 0.05, 0.35)
TRAJE = ("traje", 0.3, 0.85)
BLANCO = ("blanco", 0.45, 1.0)
ORO = ("oro", 0.3, 0.95)
NEON = ("neon", 0.55, 0.95)
PIEL = ("piel", 0.55, 1.0)
PELO = ("pelo", 0.1, 0.7)
COBRE = ("cobre", 0.3, 0.9)
NEGRO = ("negro", 0.0, 0.0)
OJO = ("blanco", 1.0, 1.0)
IRIS = ("iris", 0.0, 1.0)
SUELA = ("suela", 0.2, 0.8)

parts = []


# --- geometría ---

def sec(c, ru, rf, rb=None):
	return (Vector(c), ru, rf, rb if rb is not None else rf)


def loft(name, sections, u, w, color, sides=12, p=2.0, arc=None, caps=(True, True), sharp=None, solidify=0.0, subsurf=0):
	"""Tubo por secciones (centro, radio en u, radio hacia +w, radio hacia -w); p > 2 lo vuelve más cuadrado."""
	bm = bmesh.new()
	n = sides if arc is None else sides + 1
	rings = []
	for c, ru, rf, rb in sections:
		ring = []
		for i in range(n):
			a = 2 * math.pi * i / sides if arc is None else arc[0] + (arc[1] - arc[0]) * i / sides
			ca, sa = math.cos(a), math.sin(a)
			pp = (p[0] if sa > 0 else p[1]) if isinstance(p, tuple) else p
			x = math.copysign(abs(ca) ** (2 / pp), ca)
			y = math.copysign(abs(sa) ** (2 / pp), sa)
			ring.append(bm.verts.new(c + u * ru * x + w * (rf if y > 0 else rb) * y))
		rings.append(ring)
	m = sides if arc is None else sides
	for ra, rb_ in zip(rings, rings[1:]):
		for i in range(m):
			j = (i + 1) % n
			bm.faces.new((ra[i], ra[j], rb_[j], rb_[i]))
	if arc is None:
		for k, ring in ((0, rings[0]), (1, rings[-1])):
			if caps[k] and len({v.co.to_tuple(4) for v in ring}) > 1:
				ctr = bm.verts.new(sum((v.co for v in ring), Vector()) / len(ring))
				for i in range(n):
					f = (ring[i], ring[(i + 1) % n], ctr) if k == 0 else (ring[(i + 1) % n], ring[i], ctr)
					bm.faces.new(f[::-1])
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return finish(name, bm, color, sharp, solidify, subsurf)


def finish(name, bm, color, sharp=None, solidify=0.0, subsurf=0):
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	ob = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(ob)
	if solidify:
		apply_mod(ob, "SOLIDIFY", thickness=solidify, offset=0.0)
	if subsurf:
		apply_mod(ob, "SUBSURF", levels=subsurf)
	for poly in mesh.polygons:
		poly.use_smooth = True
	if sharp is not None:
		apply_mod(ob, "BEVEL", width=0.0025, segments=1, limit_method="ANGLE", angle_limit=math.radians(sharp))
		mesh.set_sharp_from_angle(angle=math.radians(sharp))
	paint(ob, color)
	parts.append(ob)
	return ob


def paint(ob, color):
	"""color: (tira, t abajo, t arriba) o una función centro → color; degradé vertical según la altura de la pieza."""
	mesh = ob.data
	layer = mesh.uv_layers.get("paleta") or mesh.uv_layers.new(name="paleta")
	zs = [v.co.z for v in mesh.vertices]
	z0, z1 = min(zs), max(zs)
	for poly in mesh.polygons:
		swatch, lo, hi = color(poly.center) if callable(color) else color
		for li in poly.loop_indices:
			z = mesh.vertices[mesh.loops[li].vertex_index].co.z
			t = 0.5 if z1 - z0 < 1e-6 else (z - z0) / (z1 - z0)
			layer.data[li].uv = palette_uv(swatch, lo + (hi - lo) * t)


def plate(name, rows, color, thickness=0.01, sharp=30):
	"""Tira de filas de puntos (cada fila izquierda→derecha), con espesor."""
	bm = bmesh.new()
	vs = [[bm.verts.new(p) for p in row] for row in rows]
	for ra, rb in zip(vs, vs[1:]):
		for i in range(len(ra) - 1):
			bm.faces.new((ra[i], ra[i + 1], rb[i + 1], rb[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return finish(name, bm, color, sharp, thickness)


def prism(name, pts, origin, a, b, normal, depth, color, sharp=30):
	"""Polígono pts en el plano (a, b) desde origin, extruido depth a lo largo de normal."""
	bm = bmesh.new()
	f = [bm.verts.new(origin + a * x + b * y) for x, y in pts]
	k = [bm.verts.new(v.co + normal * depth) for v in f]
	bm.faces.new(f)
	bm.faces.new(k[::-1])
	for i in range(len(f)):
		j = (i + 1) % len(f)
		bm.faces.new((f[j], f[i], k[i], k[j]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return finish(name, bm, color, sharp)


def chakana(size):
	s = size / 6
	q = [(1, 3), (1, 2), (2, 2), (2, 1), (3, 1)]
	pts = []
	for sx, sz in ((1, 1), (1, -1), (-1, -1), (-1, 1)):
		pts += [(x * s * sx, z * s * sz) for x, z in (q if sx * sz > 0 else q[::-1])]
	return pts


def mirror_x(vs):
	return [Vector((-v.x, v.y, v.z)) for v in vs]


# --- cuerpo (traje) ---

def body():
	nodes = {
		"pelvis": ((0, 0, 0.86), 0.1, 0.08), "waist": ((0, 0, 0.97), 0.066, 0.054), "chest": ((0, 0, 1.07), 0.098, 0.072),
		"neck0": ((0, 0, 1.16), 0.05, 0.045), "neck1": ((0, -0.01, 1.24), 0.032, 0.032),
	}
	edges = [("pelvis", "waist"), ("waist", "chest"), ("chest", "neck0"), ("neck0", "neck1")]
	for s, k in ((1, "l"), (-1, "r")):
		nodes.update({
			"hip" + k: ((s * 0.08, 0, 0.8), 0.082, 0.078), "thigh" + k: ((s * 0.09, -0.003, 0.67), 0.074, 0.07),
			"knee" + k: ((s * 0.098, -0.008, 0.52), 0.05, 0.05), "shin" + k: ((s * 0.106, 0, 0.35), 0.047, 0.047),
			"ankle" + k: ((s * 0.116, 0, 0.14), 0.036, 0.036), "sh" + k: ((s * 0.12, 0, 1.11), 0.05, 0.05),
			"el" + k: ((s * 0.294, 0, 1.11), 0.037, 0.037), "wr" + k: ((s * 0.48, 0, 1.118), 0.03, 0.03),
			"hand" + k: ((s * 0.535, -0.005, 1.115), 0.024, 0.044), "tip" + k: ((s * 0.62, -0.006, 1.1), 0.016, 0.036),
		})
		edges += [("pelvis", "hip" + k), ("hip" + k, "thigh" + k), ("thigh" + k, "knee" + k), ("knee" + k, "shin" + k), ("shin" + k, "ankle" + k),
			("chest", "sh" + k), ("sh" + k, "el" + k), ("el" + k, "wr" + k), ("wr" + k, "hand" + k), ("hand" + k, "tip" + k)]
	ob = skin_mesh("cuerpo", nodes, edges, "pelvis", subsurf=2)
	paint(ob, TRAJE)
	parts.append(ob)
	for s in (1, -1):
		loft("pulgar", [
			sec((s * 0.5, -0.03, 1.105), 0.014, 0.013, 0.013), sec((s * 0.53, -0.058, 1.092), 0.012, 0.011, 0.011),
			sec((s * 0.548, -0.072, 1.086), 0.007, 0.007, 0.007)], X, Z, TRAJE, sides=8)


# --- cabeza ---

# z, medio ancho, y del frente, y de la nuca: frente casi plano, pómulos anchos y mandíbula en V hasta un mentón chico
HEAD = [(1.176, 0.012, -0.104, -0.08), (1.19, 0.05, -0.11, -0.02), (1.21, 0.07, -0.118, 0.03), (1.23, 0.079, -0.122, 0.06),
	(1.25, 0.086, -0.123, 0.08), (1.275, 0.092, -0.124, 0.095), (1.3, 0.096, -0.126, 0.102), (1.33, 0.098, -0.126, 0.106),
	(1.36, 0.097, -0.123, 0.106), (1.39, 0.09, -0.114, 0.101), (1.42, 0.078, -0.1, 0.09), (1.45, 0.056, -0.076, 0.066),
	(1.47, 0.026, -0.04, 0.034), (1.476, 0.006, -0.012, 0.008)]
BROW = 1.335
HEAD_BVH = []
HELMET_BVH = []


def head():
	ob = loft("cabeza", [sec((0, (f + b) / 2, z), hx, (b - f) / 2) for z, hx, f, b in HEAD], X, FRONT, PIEL, sides=24, p=(2.6, 2.0), subsurf=1)
	HEAD_BVH.append(BVHTree.FromObject(ob, bpy.context.evaluated_depsgraph_get()))
	return ob


def head_front(x, z):
	hit = HEAD_BVH[0].ray_cast(Vector((x, -1.0, z)), Y)[0]
	return hit.y if hit else -0.12


def on_helmet(origin, direction):
	hit = HELMET_BVH[0].ray_cast(origin, direction)[0]
	return hit


def helmet():
	src = HEAD_BVH and next(o for o in parts if o.name.startswith("cabeza"))
	bm = bmesh.new()
	bm.from_mesh(src.data)

	for co, no in (((0, 0, 1.245), Z), ((0, 0, BROW), Z), ((0.088, 0, 0), X), ((-0.088, 0, 0), X)):
		geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
		bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no)

	def covered(c):
		return c.z > 1.245 and not (c.z < BROW and abs(c.x) < 0.088 and c.y < -0.03)
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if not covered(f.calc_center_median())], context="FACES")
	bm.normal_update()
	for v in bm.verts:
		v.co += v.normal * 0.008
	rim = KDTree(len(bm.verts))
	for i, v in enumerate(bm.verts):
		rim.insert(v.co if v.is_boundary else Vector((9, 9, 9)), i)
	rim.balance()

	def color(c):
		return ORO if rim.find(c)[2] < 0.011 else ROJO
	mesh = bpy.data.meshes.new("casco")
	bm.to_mesh(mesh)
	bm.free()
	ob = bpy.data.objects.new("casco", mesh)
	bpy.context.scene.collection.objects.link(ob)
	apply_mod(ob, "SOLIDIFY", thickness=0.013, offset=1.0)
	for poly in mesh.polygons:
		poly.use_smooth = True
	apply_mod(ob, "BEVEL", width=0.002, segments=1, limit_method="ANGLE", angle_limit=math.radians(50))
	mesh.set_sharp_from_angle(angle=math.radians(50))
	paint(ob, color)
	parts.append(ob)
	HELMET_BVH.append(BVHTree.FromObject(ob, bpy.context.evaluated_depsgraph_get()))
	center = Vector((0, -0.01, 1.32))
	# lomo central de adelante hacia la nuca
	rows = []
	for k in range(12):
		a = math.radians(-62 + 150 * k / 11)
		d = Vector((0, -math.cos(a), math.sin(a)))
		row = []
		for x in (-0.016, 0.0, 0.016):
			hit = on_helmet(center + X * x + d * 0.5, -d)
			row.append(hit + d * (0.012 if x == 0 else 0.002))
		rows.append(row)
	plate("casco_lomo", rows, ROJO_OSC, thickness=0.006, sharp=30)
	hit = on_helmet(Vector((0, -1, 1.395)), Y)
	prism("casco_chakana", chakana(0.075), hit - Y * 0.014, X, Z, Y, 0.016, ORO)
	prism("gema", [(0, 0.018), (0.013, 0), (0, -0.018), (-0.013, 0)], hit - Y * 0.019, X, Z, Y, 0.012, NEON)
	for s in (1, -1):
		side = Vector((s, 0, 0))
		hit = on_helmet(Vector((s * 1.0, 0.005, 1.29)), -side)
		c = hit + side * 0.008
		loft("oreja", [sec(c - side * 0.012, 0.042, 0.042), sec(c + side * 0.008, 0.042, 0.042), sec(c + side * 0.016, 0.032, 0.032)], Y, Z, COBRE, sides=14, p=2.0, sharp=35)
		loft("oreja_luz", [sec(c + side * 0.014, 0.018, 0.018), sec(c + side * 0.021, 0.015, 0.015)], Y, Z, NEON, sides=10)
		rows = []
		last = None
		for y, z0, z1 in ((-0.02, 1.335, 1.355), (0.02, 1.33, 1.38), (0.07, 1.335, 1.405), (0.12, 1.35, 1.425), (0.18, 1.38, 1.445), (0.24, 1.42, 1.455), (0.29, 1.455, 1.465)):
			zm = (z0 + z1) / 2
			hit = on_helmet(Vector((s * 1.0, y, zm)), -side)
			x = hit.x if hit else last
			last = x
			rows.append([Vector((x, y, z0)), Vector((x + s * 0.01, y, zm)), Vector((x, y, z1))])
		plate("aleta", rows, ROJO, thickness=0.012, sharp=30)


def face():
	head_ob = next(o for o in parts if o.name.startswith("cabeza"))
	dg = bpy.context.evaluated_depsgraph_get()
	bvh = BVHTree.FromObject(head_ob, dg)

	def on_face(x, z, off):
		hit = bvh.ray_cast(Vector((x, -1.0, z)), Y)[0]
		return (hit if hit else Vector((x, -0.12, z))) + FRONT * off

	def decal(name, pts, off, color):
		bm = bmesh.new()
		cx = sum(p[0] for p in pts) / len(pts)
		cz = sum(p[1] for p in pts) / len(pts)
		ctr = bm.verts.new(on_face(cx, cz, off))
		ring = [bm.verts.new(on_face(x, z, off)) for x, z in pts]
		for i in range(len(ring)):
			bm.faces.new((ctr, ring[i], ring[(i + 1) % len(ring)]))
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
		return finish(name, bm, color)

	def strip(name, top, bottom, off, color):
		bm = bmesh.new()
		a = [bm.verts.new(on_face(x, z, off)) for x, z in top]
		b = [bm.verts.new(on_face(x, z, off)) for x, z in bottom]
		for i in range(len(a) - 1):
			bm.faces.new((a[i], a[i + 1], b[i + 1], b[i]))
		return finish(name, bm, color)

	for s in (1, -1):
		ex, ez = s * 0.05, 1.268
		eye = [(ex - s * 0.024, ez + 0.006), (ex - s * 0.012, ez + 0.02), (ex + s * 0.012, ez + 0.022), (ex + s * 0.026, ez + 0.012),
			(ex + s * 0.022, ez - 0.012), (ex + s * 0.004, ez - 0.022), (ex - s * 0.014, ez - 0.016)]
		decal("ojo", eye, 0.002, OJO)
		iris = [(ex - s * 0.002 + 0.0125 * math.cos(a), ez - 0.002 + 0.019 * math.sin(a)) for a in [2 * math.pi * k / 14 for k in range(14)]]
		decal("iris", iris, 0.0035, IRIS)
		pupil = [(ex - s * 0.002 + 0.006 * math.cos(a), ez - 0.003 + 0.01 * math.sin(a)) for a in [2 * math.pi * k / 10 for k in range(10)]]
		decal("pupila", pupil, 0.0045, NEGRO)
		shine = [(ex + s * 0.005 + 0.004 * math.cos(a), ez + 0.008 + 0.004 * math.sin(a)) for a in [2 * math.pi * k / 8 for k in range(8)]]
		decal("brillo", shine, 0.0055, OJO)
		top = [(ex - s * 0.028, ez + 0.004), (ex - s * 0.014, ez + 0.021), (ex + s * 0.012, ez + 0.024), (ex + s * 0.03, ez + 0.012)]
		bot = [(ex - s * 0.024, ez + 0.0), (ex - s * 0.012, ez + 0.016), (ex + s * 0.012, ez + 0.019), (ex + s * 0.026, ez + 0.009)]
		strip("parpado", top, bot, 0.006, NEGRO)
		brow_t = [(ex - s * 0.022, ez + 0.036), (ex + s * 0.0, ez + 0.042), (ex + s * 0.028, ez + 0.04)]
		brow_b = [(ex - s * 0.022, ez + 0.032), (ex + s * 0.0, ez + 0.037), (ex + s * 0.028, ez + 0.036)]
		strip("ceja", brow_t, brow_b, 0.003, NEGRO)
	strip("boca", [(-0.009, 1.208), (0.009, 1.208)], [(-0.009, 1.205), (0.009, 1.205)], 0.003, ("boca", 0.5, 0.5))


def hair():
	for k, (x0, w, tip) in enumerate([(-0.075, 0.032, 1.285), (-0.04, 0.034, 1.295), (-0.005, 0.034, 1.288), (0.032, 0.034, 1.297), (0.066, 0.032, 1.287)]):
		zs = [BROW + 0.008, BROW - 0.014, tip - 0.006]
		rows = []
		for i, z in enumerate(zs):
			half = w / 2 * (1 - i / 2) + 0.001
			cx = x0 + w / 2 + (0.006 if x0 > 0 else -0.006) * i
			rows.append([Vector((cx + dx, head_front(cx + dx, z) - 0.004 - 0.003 * (1 - i / 2), z)) for dx in (-half, 0, half)])
			rows[-1][1].y -= 0.006
		plate("flequillo", rows, PELO, thickness=0.008, sharp=25)
	for s in (1, -1):
		rows = []
		for i, z in enumerate((1.33, 1.28, 1.23, 1.19)):
			half = 0.014 * (1 - i / 3.4)
			x = s * (0.088 - 0.006 * i)
			rows.append([Vector((x, -0.06 + dy, z)) for dy in (-half, 0.0, half)])
		plate("mecha", rows, PELO, thickness=0.012, sharp=25)
	pts = []
	for k in range(13):
		t = k / 12
		pts.append((Vector((0.0, 0.12 + 0.07 * math.sin(t * 1.6), 1.36 - 0.52 * t)), (0.032 - 0.014 * t) * (0.78 + 0.22 * abs(math.sin(math.pi * 5 * t)))))
	loft("trenza", [sec(p, r, r * 0.85) for p, r in pts], X, FRONT, PELO, sides=10, sharp=40)
	for t in (0.08, 0.9):
		p = Vector((0.0, 0.12 + 0.07 * math.sin(t * 1.6), 1.36 - 0.52 * t))
		r = (0.032 - 0.014 * t) + 0.004
		loft("trenza_anillo", [sec(p + Z * 0.008, r, r * 0.88), sec(p - Z * 0.008, r, r * 0.88)], X, FRONT, NEON, sides=10)
	end = Vector((0.0, 0.12 + 0.07 * math.sin(1.6), 0.84))
	loft("borla", [sec(end, 0.016, 0.016), sec(end - Z * 0.02, 0.024, 0.024), sec(end - Z * 0.09, 0.012, 0.012)], X, FRONT, ROJO, sides=8)


# --- armadura ---

def armor():
	torso = X
	# peto con banda de neón y chakana, cuello dorado
	loft("peto", [sec((0, 0, 0.99), 0.082, 0.078, 0.066), sec((0, 0, 1.03), 0.095, 0.09, 0.072), sec((0, 0, 1.09), 0.113, 0.095, 0.078),
		sec((0, 0, 1.14), 0.11, 0.085, 0.075), sec((0, 0, 1.175), 0.075, 0.064, 0.06)], torso, FRONT, ROJO, sides=20, p=2.5, caps=(False, False), sharp=32, solidify=0.01)
	loft("peto_luz", [sec((0, 0, 1.022), 0.094, 0.091, 0.073), sec((0, 0, 1.036), 0.098, 0.094, 0.075)], torso, FRONT, NEON, sides=20, p=2.5, caps=(False, False), solidify=0.008)
	prism("peto_chakana", chakana(0.07), Vector((0, -0.1, 1.1)), X, Z, Y, 0.012, ORO)
	prism("peto_gema", [(0, 0.014), (0.01, 0), (0, -0.014), (-0.01, 0)], Vector((0, -0.105, 1.1)), X, Z, Y, 0.01, NEON)
	loft("cuello", [sec((0, 0, 1.16), 0.07, 0.062, 0.062), sec((0, -0.003, 1.2), 0.052, 0.052, 0.05), sec((0, -0.005, 1.22), 0.05, 0.05, 0.048)],
		X, FRONT, ORO, sides=16, p=2.2, caps=(False, False), sharp=35, solidify=0.008)
	for s in (1, -1):
		# hombrera: cúpula facetada sobre el hombro
		loft("hombrera", [sec((s * 0.07, 0, 1.13), 0.05, 0.04, 0.0), sec((s * 0.12, 0, 1.13), 0.085, 0.085, 0.0), sec((s * 0.19, 0, 1.125), 0.09, 0.09, 0.0),
			sec((s * 0.24, 0, 1.115), 0.075, 0.07, 0.0), sec((s * 0.26, 0, 1.11), 0.05, 0.045, 0.0)], Y, Z, ROJO, sides=14, p=2.6, arc=(-0.25, math.pi + 0.25), caps=(False, False), sharp=32, solidify=0.012)
		loft("hombrera_borde", [sec((s * 0.12, 0, 1.11), 0.088, 0.02, 0.0), sec((s * 0.24, 0, 1.1), 0.078, 0.02, 0.0)], Y, Z, ORO, sides=14, p=2.6, arc=(-0.35, math.pi + 0.35), caps=(False, False), sharp=32, solidify=0.008)
		# brazal: se ensancha hacia la muñeca, anillo de neón y borde dorado
		loft("brazal", [sec((s * 0.3, 0, 1.112), 0.046, 0.045, 0.043), sec((s * 0.36, 0, 1.113), 0.058, 0.056, 0.052),
			sec((s * 0.44, 0, 1.115), 0.072, 0.07, 0.064), sec((s * 0.475, 0, 1.116), 0.075, 0.072, 0.066)], Y, Z, ROJO, sides=12, p=2.8, sharp=32)
		loft("brazal_luz", [sec((s * 0.42, 0, 1.115), 0.071, 0.069, 0.063), sec((s * 0.435, 0, 1.115), 0.073, 0.071, 0.065)], Y, Z, NEON, sides=12, p=2.8)
		loft("brazal_borde", [sec((s * 0.47, 0, 1.116), 0.08, 0.077, 0.07), sec((s * 0.495, 0, 1.117), 0.078, 0.075, 0.068), sec((s * 0.5, 0, 1.117), 0.055, 0.05, 0.047)],
			Y, Z, ORO, sides=12, p=2.8, sharp=32)
		# bota: caña que se afina hacia el tobillo, aro dorado arriba; pie redondeado con suela y línea de neón
		x = s * 0.112
		loft("bota", [sec((x, 0.0, 0.5), 0.07, 0.084, 0.07), sec((x, 0.0, 0.46), 0.068, 0.078, 0.066), sec((x, 0.0, 0.36), 0.063, 0.068, 0.061),
			sec((x, 0.0, 0.24), 0.058, 0.062, 0.058), sec((x, 0.0, 0.12), 0.06, 0.064, 0.062)], X, FRONT, ROJO, sides=16, p=2.2, caps=(True, False), subsurf=1, sharp=50)
		loft("bota_aro", [sec((x, 0.0, 0.505), 0.077, 0.09, 0.076), sec((x, 0.0, 0.47), 0.074, 0.086, 0.073)], X, FRONT, ORO, sides=16, p=2.2, caps=(False, False), sharp=40, solidify=0.006)
		foot = [sec((x, y, z), ru, up, down) for y, z, ru, up, down in (
			(0.085, 0.075, 0.05, 0.045, 0.055), (0.05, 0.085, 0.066, 0.07, 0.065), (-0.01, 0.08, 0.074, 0.06, 0.06), (-0.08, 0.06, 0.072, 0.04, 0.042),
			(-0.14, 0.05, 0.064, 0.03, 0.032), (-0.185, 0.045, 0.048, 0.022, 0.026), (-0.205, 0.042, 0.024, 0.012, 0.02))]
		ob = loft("pie", foot, X, Z, ROJO, sides=16, p=2.3, subsurf=1)
		for v in ob.data.vertices:
			v.co.z = max(v.co.z, 0.024)
		ob.data.set_sharp_from_angle(angle=math.radians(55))
		sole = [sec((x, y, 0.013), ru, 0.012, 0.012) for y, ru in ((0.092, 0.05), (0.05, 0.068), (-0.03, 0.078), (-0.12, 0.07), (-0.18, 0.054), (-0.212, 0.026))]
		loft("suela", sole, X, Z, SUELA, sides=14, p=(3.5, 3.5), sharp=40)
		loft("suela_luz", [sec((x, 0.06, 0.027), 0.06, 0.003, 0.003), sec((x, -0.14, 0.027), 0.068, 0.003, 0.003), sec((x, -0.19, 0.027), 0.05, 0.003, 0.003)],
			X, Z, NEON, sides=14, p=3.0, caps=(False, False))
	# cinturón dorado con hebilla y faldones rojos adelante y atrás
	loft("cinturon", [sec((0, 0, 0.87), 0.112, 0.09, 0.085), sec((0, 0, 0.92), 0.098, 0.074, 0.07)], X, FRONT, ORO, sides=18, p=2.4, sharp=32)
	for side in (1, -1):
		y = -0.092 if side > 0 else 0.088
		pts = [(-0.06, 0.0), (0.06, 0.0), (0.05, -0.17), (0.0, -0.2), (-0.05, -0.17)]
		prism("faldon", pts, Vector((0, y, 0.885)), X, Z, Y * (1 if side > 0 else -1), 0.014, ROJO)
		prism("faldon_luz", [(-0.047, -0.14), (0.047, -0.14), (0.042, -0.155), (-0.042, -0.155)], Vector((0, y - side * 0.003, 0.885)), X, Z, Y * (1 if side > 0 else -1), 0.016, NEON)
	prism("hebilla", chakana(0.05), Vector((0, -0.1, 0.895)), X, Z, Y, 0.012, NEON)


def front_y_body(z):
	return -0.09


def main():
	epi.start()
	for ob in list(bpy.context.scene.objects):
		bpy.data.objects.remove(ob)
	img = build_texture()
	body()
	head()
	helmet()
	face()
	hair()
	armor()
	tris = 0
	for ob in parts:
		ob.data.calc_loop_triangles()
		tris += len(ob.data.loop_triangles)
	print("jugador:", len(parts), "piezas,", tris, "triángulos")
	bpy.ops.object.select_all(action="DESELECT")
	for ob in parts:
		ob.select_set(True)
	bpy.context.view_layer.objects.active = parts[0]
	bpy.ops.object.join()
	ob = parts[0]
	ob.name = ob.data.name = "jugador"
	ob.data.materials.clear()
	ob.data.materials.append(material(img))
	path = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else None
	if path:
		bpy.ops.wm.save_as_mainfile(filepath=path)


main()
