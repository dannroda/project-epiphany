# Librería para armar kits por script: primitivas low poly, pintado con la paleta y guardado del .blend.
# Los scripts build_*.py la usan; corren con: blender -b -P tools/blender/build_<kit>.py
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import epiphany_palette as palette  # noqa: E402

NAMES = [s[0] for s in palette.SWATCHES]
SHADES = {"LIGHT": 0.85, "MID": 0.5, "LOW": 0.32, "DARK": 0.15}


def start():
	"""Abre la plantilla (material, referencias) y deja una colección 'kit' para las piezas."""
	bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "plantilla.blend"))
	kit = bpy.data.collections.new("kit")
	bpy.context.scene.collection.children.link(kit)
	return kit


def save(name):
	path = os.path.join(ROOT, "assets", "epiphany", name + ".blend")
	bpy.ops.wm.save_as_mainfile(filepath=path)
	bpy.ops.file.make_paths_relative()
	bpy.ops.wm.save_mainfile()
	backup = path + "1"
	if os.path.exists(backup):
		os.remove(backup)
	print("guardado:", path, len(bpy.data.collections["kit"].objects), "piezas")


class Piece:
	"""Una malla en construcción. Todas las funciones devuelven las caras que crean, para pintarlas."""

	def __init__(self, seed=0):
		self.bm = bmesh.new()
		self.uv = self.bm.loops.layers.uv.verify()
		self.rng = random.Random(seed)

	# --- primitivas ---

	def box(self, x0, x1, y0, y1, z0, z1, taper=0.0):
		"""Caja alineada; taper achica la cara de arriba hacia adentro (piedras, ladrillos)."""
		r = bmesh.ops.create_cube(self.bm, size=1.0)
		for v in r["verts"]:
			top = v.co.z > 0
			v.co.x = (x1 - taper if top else x1) if v.co.x > 0 else (x0 + taper if top else x0)
			v.co.y = (y1 - taper if top else y1) if v.co.y > 0 else (y0 + taper if top else y0)
			v.co.z = z1 if top else z0
		return self._faces(r["verts"])

	def rounded_box(self, x0, x1, y0, y1, z0, z1, radius=0.1, segments=2):
		"""Caja con los cantos biselados (cabezas, almohadones)."""
		before = set(self.bm.faces)
		faces = self.box(x0, x1, y0, y1, z0, z1)
		bmesh.ops.bevel(self.bm, geom=list({e for f in faces for e in f.edges}), offset=radius, segments=segments, affect="EDGES", profile=0.6)
		return [f for f in self.bm.faces if f not in before]

	def stone(self, center, width, height, depth, facing, inset=0.0):
		"""Piedra labrada: la base apoyada en center (el plano del muro) y el frente, achicado en inset, hacia facing."""
		faces = self.box(-width / 2, width / 2, -height / 2, height / 2, 0.0, depth, taper=inset)
		up = Vector((0, 0, 1)) if abs(facing.z) < 0.9 else Vector((0, 1, 0))
		right = up.cross(facing).normalized()
		basis = Matrix((right, up, facing)).transposed().to_4x4()
		self.transform(faces, Matrix.Translation(center) @ basis)
		return faces

	def cylinder(self, radius, z0, z1, sides=8, radius_top=None, center=(0.0, 0.0), cap_top=True, cap_bottom=True, phase=0.0):
		rt = radius if radius_top is None else radius_top
		cx, cy = center
		bottom = [self.bm.verts.new((cx + radius * math.cos(phase + a), cy + radius * math.sin(phase + a), z0)) for a in _angles(sides)]
		top = [self.bm.verts.new((cx + rt * math.cos(phase + a), cy + rt * math.sin(phase + a), z1)) for a in _angles(sides)]
		faces = [self.bm.faces.new((bottom[i], bottom[(i + 1) % sides], top[(i + 1) % sides], top[i])) for i in range(sides)]
		if cap_top and rt > 0:
			faces.append(self.bm.faces.new(top))
		if cap_bottom:
			faces.append(self.bm.faces.new(list(reversed(bottom))))
		return faces

	def lathe(self, profile, sides=10, center=(0.0, 0.0), phase=0.0, caps=True):
		"""Sólido de revolución: profile es [(radio, z)] de abajo arriba; radio 0 cierra la punta. caps=False para aros."""
		cx, cy = center
		rings = []
		for r, z in profile:
			if r <= 1e-6:
				rings.append([self.bm.verts.new((cx, cy, z))])
			else:
				rings.append([self.bm.verts.new((cx + r * math.cos(phase + a), cy + r * math.sin(phase + a), z)) for a in _angles(sides)])
		faces = []
		for a, b in zip(rings, rings[1:]):
			for i in range(sides):
				if len(a) == 1 and len(b) == 1:
					continue
				if len(a) == 1:
					faces.append(self.bm.faces.new((a[0], b[(i + 1) % sides], b[i])[::-1]))
				elif len(b) == 1:
					faces.append(self.bm.faces.new((a[i], a[(i + 1) % sides], b[0])))
				else:
					faces.append(self.bm.faces.new((a[i], a[(i + 1) % sides], b[(i + 1) % sides], b[i])))
		if caps and len(rings[0]) > 1:
			faces.append(self.bm.faces.new(list(reversed(rings[0]))))
		if caps and len(rings[-1]) > 1:
			faces.append(self.bm.faces.new(rings[-1]))
		return faces

	def blob(self, center, radius, squash=(1.0, 1.0, 1.0), subdiv=1, rough=0.15, flat_bottom=None):
		"""Icosfera deformada con ruido: rocas, copas de árbol, matas."""
		r = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=radius)
		off = Vector((self.rng.random() * 50, self.rng.random() * 50, self.rng.random() * 50))
		for v in r["verts"]:
			n = noise.noise(v.co * (2.2 / radius) + off)
			v.co *= 1.0 + rough * n
			v.co = Vector((v.co.x * squash[0], v.co.y * squash[1], v.co.z * squash[2]))
			if flat_bottom is not None:
				v.co.z = max(v.co.z, flat_bottom - center[2])
		bmesh.ops.translate(self.bm, vec=Vector(center), verts=r["verts"])
		return self._faces(r["verts"])

	def polygon(self, points, z0, z1):
		"""Prisma de una planta poligonal (xy, en sentido antihorario) entre z0 y z1."""
		bottom = [self.bm.verts.new((x, y, z0)) for x, y in points]
		top = [self.bm.verts.new((x, y, z1)) for x, y in points]
		n = len(points)
		faces = [self.bm.faces.new((bottom[i], bottom[(i + 1) % n], top[(i + 1) % n], top[i])) for i in range(n)]
		faces.append(self.bm.faces.new(top))
		faces.append(self.bm.faces.new(list(reversed(bottom))))
		return faces

	# --- edición ---

	def jitter(self, faces, amount, keep_z=False, seed_axis=(1, 1, 1)):
		for v in {v for f in faces for v in f.verts}:
			v.co.x += (self.rng.random() - 0.5) * 2 * amount * seed_axis[0]
			v.co.y += (self.rng.random() - 0.5) * 2 * amount * seed_axis[1]
			if not keep_z:
				v.co.z += (self.rng.random() - 0.5) * 2 * amount * seed_axis[2]

	def transform(self, faces, matrix):
		bmesh.ops.transform(self.bm, matrix=matrix, verts=list({v for f in faces for v in f.verts}))

	def merge(self, other):
		"""Suma la geometría de otra pieza (con sus UV) a esta."""
		mesh = bpy.data.meshes.new("_merge")
		other.bm.to_mesh(mesh)
		other.bm.free()
		self.bm.from_mesh(mesh)
		bpy.data.meshes.remove(mesh)
		self.uv = self.bm.loops.layers.uv.verify()

	def _faces(self, verts):
		return list({f for v in verts for f in v.link_faces})

	# --- pintado ---

	def paint(self, faces, swatch, shade="GRADIENT", z_range=None, vary=0.0):
		"""Pone las UV de las caras en la franja swatch. GRADIENT: claro arriba, según z_range (o la altura de las caras).
		vary corre cada cara un poco dentro del degradé, para que no se vea plano."""
		i = NAMES.index(swatch)
		col, row = i % palette.COLS, i // palette.COLS
		u = (col + 0.5) / palette.COLS
		lo = (palette.ROWS - 1 - row + palette.MARGIN) / palette.ROWS
		hi = (palette.ROWS - row - palette.MARGIN) / palette.ROWS
		zs = [v.co.z for f in faces for v in f.verts]
		if not zs:
			return
		z0, z1 = z_range or (min(zs), max(zs))
		for f in faces:
			shift = (self.rng.random() - 0.5) * 2 * vary
			for loop in f.loops:
				if shade in SHADES:
					t = SHADES[shade]
				else:
					t = 0.5 if z1 - z0 < 1e-5 else (loop.vert.co.z - z0) / (z1 - z0)
				t = min(1.0, max(0.0, t + shift))
				loop[self.uv].uv = (u, lo + (hi - lo) * t)

	def paint_bands(self, faces, bands, default=None):
		"""Pinta cada cara según en qué franja de altura cae su centro: bands = [(z0, z1, swatch, shade)]."""
		groups = {}
		for f in faces:
			z = f.calc_center_median().z
			band = next((b for b in bands if b[0] <= z < b[1]), default)
			if band:
				groups.setdefault((band[2], band[3]), []).append(f)
		for (swatch, shade), group in groups.items():
			self.paint(group, swatch, shade)

	# --- salida ---

	def build(self, name, kit, location=(0.0, 0.0, 0.0)):
		bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
		mesh = bpy.data.meshes.new(name)
		self.bm.to_mesh(mesh)
		self.bm.free()
		mesh.materials.append(palette.palette_material())
		obj = bpy.data.objects.new(name, mesh)
		obj.location = location
		kit.objects.link(obj)
		return obj


def _angles(sides):
	return [2 * math.pi * i / sides for i in range(sides)]


def layout(kit, columns=8, spacing=3.0, row_of=None):
	"""Reparte las piezas en una grilla para verlas en Blender. Godot toma las mallas sin la posición."""
	rows = {}
	for obj in sorted(kit.objects, key=lambda o: o.name):
		group = row_of(obj.name) if row_of else 0
		rows.setdefault(group, []).append(obj)
	y = 0.0
	for group in sorted(rows):
		objs = rows[group]
		for i, obj in enumerate(objs):
			obj.location = ((i % columns) * spacing, y - (i // columns) * spacing, 0.0)
		y -= ((len(objs) - 1) // columns + 1) * spacing + spacing * 0.5


# --- partes compartidas entre kits ---

SIDES = [Vector((1, 0, 0)), Vector((-1, 0, 0)), Vector((0, 1, 0)), Vector((0, -1, 0))]


def stone_wall(p, z0, z1, half=1.0, swatch="acantilado", depth=0.08, sides=None, rows=(0.32, 0.22), widths=(0.38, 0.45), mortar="tierra", vary=0.12, size=None):
	"""Muro de piedra encastrada (estilo andén): hileras de alto variable y piedras de ancho variable en cada lado.
	rows y widths son (mínimo, variación) del alto de hilera y del ancho de piedra; size=(hx, hy) para plantas rectangulares."""
	sides = SIDES if sides is None else sides
	hx, hy = size or (half, half)
	core = p.box(-hx, hx, -hy, hy, z0, z1)
	p.paint(core, mortar, "DARK")
	stones = []
	for facing in sides:
		right = Vector((0, 0, 1)).cross(facing)
		plane = hx if abs(facing.x) > 0.5 else hy
		half = hy if abs(facing.x) > 0.5 else hx
		z = z0
		while z < z1 - 0.12:
			h = min(z1 - z, rows[0] + p.rng.random() * rows[1])
			if z1 - (z + h) < 0.2:
				h = z1 - z
			u = -half
			while u < half - 0.1:
				w = min(half - u, widths[0] + p.rng.random() * widths[1])
				if half - (u + w) < 0.22:
					w = half - u
				center = facing * plane + right * (u + w / 2) + Vector((0, 0, z + h / 2))
				d = depth * (0.6 + p.rng.random() * 0.8)
				s = p.stone(center, w - 0.035, h - 0.035, d, facing, inset=0.025 + p.rng.random() * 0.02)
				p.jitter(s, 0.012)
				stones += s
				u += w
			z += h
	p.paint(stones, swatch, z_range=(z0, z1), vary=vary)
	return stones


def grass_cap(p, z0, z1, half=1.0):
	cap = p.box(-half, half, -half, half, z0, z1)
	p.paint([f for f in cap if f.normal.z > 0.5], "pasto", "MID")
	p.paint([f for f in cap if f.normal.z <= 0.5], "pasto", "DARK")


def eye(p, center, size, depth=0.03, pupil_swatch=None):
	"""Ojo en relieve: la almendra (dos arcos) y la pupila, sobre el plano que mira a -Y."""
	pts = []
	for i in range(12):
		t = math.pi * i / 11
		pts.append((math.cos(t) * size, math.sin(t) * size * 0.45))
	for i in range(1, 11):
		t = math.pi * i / 11
		pts.append((-math.cos(t) * size, -math.sin(t) * size * 0.45))
	almond = p.polygon(pts, 0.0, depth)
	pupil = p.cylinder(size * 0.3, 0.0, depth * 1.8, sides=10)
	rot = Matrix.Rotation(math.pi / 2, 4, "X")
	for f in (almond, pupil):
		p.transform(f, Matrix.Translation(center) @ rot)
	if pupil_swatch:
		p.paint(pupil, pupil_swatch, "MID")
		return almond
	return almond + pupil


def chakana_plate(p, center, size, swatch):
	"""Placa escalonada (cruz andina) que mira a -Y."""
	faces = []
	for w, h in ((size, size * 0.34), (size * 0.67, size * 0.67), (size * 0.34, size)):
		faces += p.box(-w / 2, w / 2, -0.02, 0.0, -h / 2, h / 2)
	p.transform(faces, Matrix.Translation(center))
	hole = p.box(-size * 0.06, size * 0.06, -0.03, -0.02, -size * 0.12, size * 0.06)
	p.transform(hole, Matrix.Translation(center))
	p.paint(faces, swatch, "LIGHT", vary=0.05)
	p.paint(hole, "noche", "MID")
