# Librería para armar kits por script: primitivas low poly, pintado con la paleta y guardado del .blend.
# Los scripts build_*.py la usan; corren con: blender -b -P tools/blender/build_<kit>.py
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise
from mathutils.bvhtree import BVHTree

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


def publish(name, objects=None, material=None, materials=None, part=None):
	"""Guarda el .blend de trabajo en art/blender/ (Godot no lo ve) y publica assets/epiphany/<name>.glb con las
	custom properties; lo importa addons/epiphany_tools/import/epi_scene_import.gd. Sin objects, exporta la colección 'kit'.
	material (o materials[nombre del objeto]) marca la variante de la paleta: outdoor, wind. Con part (objeto → nombre),
	un <name>.<parte>.glb por parte en lugar de uno solo, para que ningún archivo pase los 100 MB de GitHub; las mallas
	de todas van igual a meshes/<name>/."""
	blend = os.path.join(ROOT, "art", "blender", name + ".blend")
	os.makedirs(os.path.dirname(blend), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=blend)
	bpy.ops.file.make_paths_relative()
	bpy.ops.wm.save_mainfile()
	if os.path.exists(blend + "1"):
		os.remove(blend + "1")
	objects = list(objects or bpy.data.collections["kit"].all_objects)
	for obj in objects:
		tag = (materials or {}).get(obj.name, material)
		if tag:
			obj["material"] = tag
	groups = {}
	for obj in objects:
		groups.setdefault(part(obj) if part else None, []).append(obj)
	for key, group in sorted(groups.items(), key=lambda item: str(item[0])):
		for obj in bpy.context.scene.objects:
			obj.select_set(obj in group)
		glb = os.path.join(ROOT, "assets", "epiphany", name + ("." + key if key else "") + ".glb")
		bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True, export_extras=True, export_image_format="NONE", export_animation_mode="ACTIONS")
		print("publicado:", glb, len(group), "objetos")


class Piece:
	"""Una malla en construcción. Todas las funciones devuelven las caras que crean, para pintarlas."""

	def __init__(self, seed=0):
		self.bm = bmesh.new()
		self.uv = self.bm.loops.layers.uv.verify()
		self.rng = random.Random(seed)
		self.fixed = set()

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

	def build(self, name, kit, location=(0.0, 0.0, 0.0), smooth=None):
		"""smooth: ángulo en grados hasta el que las caras vecinas se sombrean suave (curvas lisas, cantos marcados)."""
		bmesh.ops.recalc_face_normals(self.bm, faces=[f for f in self.bm.faces if f not in self.fixed])
		mesh = bpy.data.meshes.new(name)
		self.bm.to_mesh(mesh)
		self.bm.free()
		if smooth:
			mesh.shade_smooth()
			mesh.set_sharp_from_angle(angle=math.radians(smooth))
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


def grass_cap(p, z0, z1, half=1.0, lip=True):
	"""Tapa de pasto; lip le cambia los costados por un borde inclinado que cuelga en puntas (contra una pared vecina
	queda adentro de ella; las puntas de los extremos son fijas, así empalman)."""
	cap = p.box(-half, half, -half, half, z0, z1)
	p.paint([f for f in cap if f.normal.z > 0.5], "pasto", "MID")
	p.paint([f for f in cap if f.normal.z <= 0.5], "pasto", "DARK")
	if lip:
		bmesh.ops.delete(p.bm, geom=[f for f in cap if abs(f.normal.z) < 0.5], context="FACES_ONLY")
		for facing in SIDES:
			grass_lip(p, facing, z1, half, z1 - z0 + 0.03)


def grass_lip(p, facing, z1, half, shallow, segments=9):
	points = []
	for i in range(segments, -1, -1):
		end = i in (0, segments)
		drop = shallow + 0.03 if end else (shallow + p.rng.random() * 0.06 if i % 2 else shallow + 0.14 + p.rng.random() * 0.2)
		points.append((-half + 2 * half * i / segments, drop))
	face = hanging_face(p, facing, z1 - 0.004, half, points)
	p.paint([face], "pasto", "DARK", z_range=(z1 - shallow - 0.4, z1))
	return [face]


def hanging_face(p, facing, top, half, bottom, lean=0.25):
	"""Una sola cara del lado facing, de top hacia abajo hasta bottom ([(u, cuánto cuelga)], de +u a -u); las puntas de
	abajo se corren hacia afuera en proporción a cuánto cuelgan, así es plana. Reemplaza el costado de una caja."""
	right = Vector((0, 0, 1)).cross(facing)
	points = [(-half, 0.0), (half, 0.0)] + bottom
	verts = [p.bm.verts.new(facing * (half + lean * d) + right * u + Vector((0, 0, top - d))) for u, d in points]
	face = p.bm.faces.new(verts)
	face.normal_update()
	if face.normal.dot(facing) < 0:
		face.normal_flip()
	p.fixed.add(face)
	return face


def eye(p, center, size, depth=0.03, pupil_swatch=None, pupils=None):
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
		if pupils is not None:
			pupils += pupil
		return almond
	return almond + pupil


def angry_face(p, center, radius, tilt, eye_swatch="noche", brow_swatch="noche", teeth_swatch="hueso", size=1.0):
	"""Cara enojada pegada a una cabeza esférica (centro, radio) que mira a -Y, subida tilt rad hacia arriba: cejas
	gruesas caídas hacia el medio, ojos chicos y boca de dientes apretados."""
	k = radius / 0.5 * size
	faces = []

	def stick(item, u, v, roll=0.0, lift=0.0):
		d = Vector((u, -math.sqrt(max(radius * radius - u * u - v * v, 0.01)), v)).normalized()
		d = Matrix.Rotation(-tilt, 3, "X") @ d
		turn = Vector((0, -1, 0)).rotation_difference(d).to_matrix().to_4x4()
		p.transform(item, Matrix.Translation(center + d * (radius + lift)) @ turn @ Matrix.Rotation(roll, 4, "Y"))
		faces.extend(item)

	for side in (-1, 1):
		brow = p.rounded_box(-0.13 * k, 0.13 * k, -0.04 * k, 0.02 * k, -0.04 * k, 0.04 * k, radius=0.015 * k, segments=1)
		p.paint(brow, brow_swatch, "MID")
		stick(brow, side * 0.16 * k, 0.16 * k, roll=side * 0.4)
		eye = p.cylinder(0.042 * k, -0.02 * k, 0.02 * k, sides=12)
		p.transform(eye, Matrix.Scale(1.35, 4, Vector((0, 0, 1))) @ Matrix.Rotation(math.pi / 2, 4, "X"))
		p.paint(eye, eye_swatch, "MID")
		stick(eye, side * 0.13 * k, 0.05 * k)
	lip = p.rounded_box(-0.17 * k, 0.17 * k, -0.02 * k, 0.02 * k, -0.065 * k, 0.065 * k, radius=0.02 * k, segments=1)
	p.paint(lip, "noche", "MID")
	stick(lip, 0.0, -0.14 * k)
	teeth = p.box(-0.15 * k, 0.15 * k, -0.03 * k, 0.0, -0.048 * k, 0.048 * k)
	p.paint(teeth, teeth_swatch, "LIGHT")
	stick(teeth, 0.0, -0.14 * k)
	gaps = p.box(-0.15 * k, 0.15 * k, -0.035 * k, 0.0, -0.007 * k, 0.007 * k)
	for x in (-0.075, 0.0, 0.075):
		gaps += p.box((x - 0.007) * k, (x + 0.007) * k, -0.035 * k, 0.0, -0.048 * k, 0.048 * k)
	p.paint(gaps, "noche", "MID")
	stick(gaps, 0.0, -0.14 * k)
	return faces


LOGO_RAY = [(-13, -114), (13, -114), (13, -130), (8, -130), (8, -145), (3.5, -145), (3.5, -160), (-3.5, -160), (-3.5, -145),
	(-8, -145), (-8, -130), (-13, -130)]
LOGO_GOLD = [
	[(372, 158), (398, 158), (398, 182), (372, 182), (372, 176), (352, 176), (352, 164), (372, 164)],
	[(828, 158), (802, 158), (802, 182), (828, 182), (828, 176), (848, 176), (848, 164), (828, 164)],
	[(552, 250), (564, 248), (564, 282), (572, 282), (572, 296), (544, 296), (544, 282), (552, 282)],
	[(594, 252), (606, 252), (606, 300), (614, 300), (614, 314), (586, 314), (586, 300), (594, 300)],
	[(636, 248), (648, 250), (648, 282), (656, 282), (656, 296), (628, 296), (628, 282), (636, 282)],
]


def logo_eye(p, center, width, depth=0.05):
	"""El ojo de art/logo/epiphany_logo.svg en relieve, de frente a -Y y de width de ancho (sin los rayos ni adornos de oro
	cuenta solo la almendra): rayos arriba, almendra de oro con el blanco, iris rojo con aro, pupila y brillo, barras a los
	costados y tres colgantes."""
	k = width / 380.0

	def flat(points, z0, z1):
		pts = [((x - 600) * k, (170 - y) * k) for x, y in points]
		if sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1])) < 0:
			pts.reverse()
		return p.polygon(pts, z0, z1)

	def almond(half, peak, z0, z1):
		pts = []
		for i in range(17):
			t = i / 16
			pts.append((600 - half + 2 * half * t, 170 - 4 * t * (1 - t) * peak))
		for i in range(1, 16):
			t = i / 16
			pts.append((600 + half - 2 * half * t, 170 + 4 * t * (1 - t) * peak))
		return flat(pts, z0, z1)

	def disc(r, z0, z1, x=600, y=170):
		return p.cylinder(r * k, z0, z1, sides=24, center=((x - 600) * k, (170 - y) * k))

	gold = almond(196, 72, 0.0, depth)
	for side in LOGO_GOLD:
		gold += flat(side, 0.0, depth)
	for a in range(-60, 61, 20):
		ray = flat([(600 + x, 170 + y) for x, y in LOGO_RAY], 0.0, depth)
		p.transform(ray, Matrix.Rotation(math.radians(-a), 4, "Z"))
		gold += ray
	p.paint(gold, "dorado", "GRADIENT")
	white = almond(186, 62, 0.0, depth * 1.3)
	p.paint(white, "hueso", "LIGHT")
	ring = disc(62, 0.0, depth * 1.5)
	p.paint(ring, "dorado", "LIGHT")
	iris = disc(57, 0.0, depth * 1.6)
	p.paint(iris, "tela_roja", "DARK")
	pupil = disc(25, 0.0, depth * 1.75)
	p.paint(pupil, "noche", "MID")
	glint = disc(9, 0.0, depth * 1.85, x=582, y=150)
	p.paint(glint, "blanco", "LIGHT")
	faces = gold + white + ring + iris + pupil + glint
	p.transform(faces, Matrix.Translation(center) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	return faces


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
	return faces + hole


def crack_web(p, face_y, center, half_w, z_lo, z_hi, stone, gap):
	"""Estallido de grietas en la cara de face_y (el signo dice el lado): un hueco donde pegó el golpe, rayos que salen
	de ahí con ramas y anillos de telaraña entre rayos. Cada trazo se pega a la superficie (sigue el relieve de las
	piedras o la roca, sin hundirse en las juntas) y lleva debajo un borde más ancho de la misma piedra en claro, para que se lea desde lejos. Las
	grietas tienen la sombra del color de las juntas de esa pared (gap) y un núcleo fino oscuro."""
	tree = BVHTree.FromBMesh(p.bm)
	side = 1.0 if face_y > 0 else -1.0
	rng = p.rng

	def onto(x, z, lift):
		hit, normal, _, _ = tree.ray_cast(Vector((x, face_y + side * 0.6, z)), Vector((0, -side, 0)), 2.0)
		if hit is None or side * hit.y < side * face_y - 0.01:
			return Vector((x, face_y + side * lift, z))
		return hit + normal * lift

	def inside(q):
		return -half_w < q.x < half_w and z_lo < q.y < z_hi

	strokes = []

	def walk(start, heading, length, w0, depth):
		pts, widths = [start], [w0]
		pos, a, travelled = start, heading, 0.0
		while travelled < length:
			step = rng.uniform(0.09, 0.16)
			a = heading + max(-0.55, min(0.55, a - heading + rng.uniform(-0.5, 0.5)))
			nxt = pos + Vector((math.cos(a), math.sin(a))) * step
			if not inside(nxt):
				break
			travelled += step
			w = w0 * (1.0 - 0.75 * travelled / length)
			pts.append(nxt)
			widths.append(w)
			if depth < 1 and rng.random() < 0.18:
				walk(nxt, a + rng.choice((-1, 1)) * rng.uniform(0.5, 1.0), max(0.15, (length - travelled) * 0.5), w * 0.75, depth + 1)
			pos = nxt
		if len(pts) > 1:
			strokes.append((pts, widths))

	c = Vector(center)
	rays = rng.randint(6, 8)
	angles = sorted(2 * math.pi * (k + rng.uniform(-0.25, 0.25)) / rays for k in range(rays))
	for ang in angles:
		start = c + Vector((math.cos(ang), math.sin(ang))) * 0.12
		walk(start, ang, rng.uniform(0.7, 1.3), rng.uniform(0.08, 0.11), 0)
	for radius in (0.3, 0.6):
		for a0, a1 in zip(angles, angles[1:] + [angles[0] + 2 * math.pi]):
			if rng.random() > 0.5:
				continue
			r = radius * rng.uniform(0.85, 1.15)
			pts = [c + Vector((math.cos(t), math.sin(t))) * (r + rng.uniform(-0.04, 0.04)) for t in (a0 + (a1 - a0) * k / 4 for k in range(5))]
			pts = [q for q in pts if inside(q)]
			if len(pts) > 1:
				strokes.append((pts, [0.04] * len(pts)))

	def slab(faces):
		"""Le da espesor hacia la pared, así es un volumen cerrado y las normales quedan para afuera."""
		new = bmesh.ops.extrude_face_region(p.bm, geom=faces, use_keep_orig=True)["geom"]
		bmesh.ops.translate(p.bm, verts=[v for v in new if isinstance(v, bmesh.types.BMVert)], vec=Vector((0, -side * 0.012, 0)))
		return faces + [f for f in new if isinstance(f, bmesh.types.BMFace)] + list({f for e in new if isinstance(e, bmesh.types.BMEdge) for f in e.link_faces})

	def ribbon(pts, widths, grow, lift):
		left, right = [], []
		for i, q in enumerate(pts):
			t = pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]
			n = Vector((-t.y, t.x)).normalized() * (widths[i] * grow / 2 + (0.02 if grow > 1 else 0.0))
			left.append(p.bm.verts.new(onto(q.x + n.x, q.y + n.y, lift)))
			right.append(p.bm.verts.new(onto(q.x - n.x, q.y - n.y, lift)))
		faces = []
		for i in range(len(pts) - 1):
			quad = (left[i], left[i + 1], right[i + 1], right[i])
			faces.append(p.bm.faces.new(quad if side > 0 else quad[::-1]))
		return slab(faces)

	def blob(radius, lift, n=9):
		ring = [p.bm.verts.new(onto(c.x + math.cos(t) * radius * rng.uniform(0.7, 1.2), c.y + math.sin(t) * radius * rng.uniform(0.7, 1.2), lift)) for t in (2 * math.pi * k / n for k in range(n))]
		mid = p.bm.verts.new(onto(c.x, c.y, lift))
		return slab([p.bm.faces.new((mid, ring[k], ring[(k + 1) % n]) if side < 0 else (mid, ring[(k + 1) % n], ring[k])) for k in range(n)])

	rims, shade, core = blob(0.27, 0.008), blob(0.2, 0.016), blob(0.13, 0.024)
	for pts, widths in strokes:
		rims += ribbon(pts, widths, 2.4, 0.008)
		shade += ribbon(pts, widths, 1.3, 0.016)
		core += ribbon(pts, widths, 0.5, 0.024)
	p.paint(rims, stone, "LIGHT")
	p.paint(shade, gap, "DARK")
	p.paint(core, "noche", "DARK")


def cracks_both_faces(p, face, center, half_w, z_lo, z_hi, stone, gap):
	for side in (-1, 1):
		crack_web(p, side * face, center, half_w, z_lo, z_hi, stone, gap)
