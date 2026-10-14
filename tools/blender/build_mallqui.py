# Publica assets/epiphany/mallqui.glb (epi.publish): Mallqui, el Ancestro, jefe de la Chullpa. El mismo fardo de 3 m que la
# momia (la pelea lo escala) pero de rey: manto rojo con franja de tocapus, cuerdas de oro, pectoral de sol, manto azul
# en los hombros, mascaipacha roja sobre la máscara de oro y una corona de sol con rayos detrás de la cabeza.
# Origen en la base, la cara mira a -Y.
# blender -b -P tools/blender/build_mallqui.py
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

kit = epi.start()
BODY = [(0.0, 0.0), (0.66, 0.0), (0.88, 0.12), (0.97, 0.4), (1.0, 0.8), (0.96, 1.2), (0.88, 1.6), (0.74, 1.95), (0.52, 2.15), (0.3, 2.25), (0.0, 2.28)]
HEAD = [(0.0, 2.18), (0.32, 2.22), (0.47, 2.38), (0.52, 2.6), (0.49, 2.8), (0.36, 2.95), (0.0, 3.0)]
SIDES = 28
CLOTH = "tela_roja"
GOLD = "dorado"
## Franja de tocapus (cuadros de colores) entre estas alturas, en filas de este alto.
TOCAPU = (0.5, 1.1)
TOCAPU_ROW = 0.15
TOCAPU_COLORS = [GOLD, "noche", "tela_azul", "flor_amarilla", "hueso", "noche"]
## Bordes de oro arriba y abajo de los tocapus, y el ruedo.
TRIM = [(0.0, 0.1), (0.44, 0.5), (1.1, 1.16)]
ROPE_RINGS = (1.22, 1.9)
ROPE_MERIDIANS = 8
ROPE_TWIST = 0.8
CHEST = 1.32
## Corona de sol detrás de la cabeza: abanico de rayos de este radio.
CROWN_RADIUS = 0.95
CROWN_RAYS = 11
## La cara mira hacia arriba (FACE_TILT rad desde el frente) para que se lea desde la cámara alta.
FACE_Z = 2.6
FACE_TILT = 0.55


def radius_at(profile, z):
	for (r0, z0), (r1, z1) in zip(profile, profile[1:]):
		if z0 <= z <= z1 and z1 > z0:
			return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
	return 0.0


def refine(profile, step=0.05):
	out = [profile[0]]
	for (r0, z0), (r1, z1) in zip(profile, profile[1:]):
		n = max(1, int(abs(z1 - z0) / step))
		for i in range(1, n + 1):
			t = i / n
			out.append((r0 + (r1 - r0) * t, z0 + (z1 - z0) * t))
	return out


def rope_ring(p, z, thick=0.05):
	r = radius_at(BODY, z)
	return p.lathe([(r - 0.01, z - thick), (r + thick * 0.7, z - thick * 0.5), (r + thick * 0.7, z + thick * 0.5), (r - 0.01, z + thick)], sides=SIDES, caps=False)


def rope_meridian(p, angle, twist, z0, z1, width=0.035, steps=16):
	rows = []
	for i in range(steps + 1):
		z = z0 + (z1 - z0) * i / steps
		a = angle + twist * i / steps
		c, s = math.cos(a), math.sin(a)
		r = radius_at(BODY, z) + 0.02
		rows.append([p.bm.verts.new((c * r - s * w, s * r + c * w, z)) for w in (-width, 0.0, width)])
		rows[-1][1].co += Vector((c, s, 0)) * 0.025
	faces = []
	for a, b in zip(rows, rows[1:]):
		faces.append(p.bm.faces.new((a[0], a[1], b[1], b[0])))
		faces.append(p.bm.faces.new((a[1], a[2], b[2], b[1])))
	return faces


def upright(p, points, thick, at, turn=0.0, tilt=0.0):
	"""Placa plana de planta points (x, alto), parada de frente a -Y, en at."""
	faces = p.polygon(points, -thick, thick)
	p.transform(faces, Matrix.Translation(at) @ Matrix.Rotation(turn, 4, "Z") @ Matrix.Rotation(math.pi / 2 - tilt, 4, "X"))
	return faces


def body(p):
	faces = p.lathe(refine(BODY), sides=SIDES)
	groups = {}
	for f in faces:
		c = f.calc_center_median()
		if any(z0 <= c.z < z1 for z0, z1 in TRIM):
			key = (GOLD, "MID")
		elif TOCAPU[0] <= c.z < TOCAPU[1]:
			col = int((math.atan2(c.y, c.x) + math.pi) / (2 * math.pi) * SIDES / 2)
			row = int((c.z - TOCAPU[0]) / TOCAPU_ROW)
			key = (TOCAPU_COLORS[(col + row * 3) % len(TOCAPU_COLORS)], "MID")
		else:
			key = (CLOTH, "GRADIENT")
		groups.setdefault(key, []).append(f)
	for (swatch, shade), group in groups.items():
		p.paint(group, swatch, shade, z_range=(0.0, 2.3) if shade == "GRADIENT" else None, vary=0.03)

	ropes = []
	for z in ROPE_RINGS:
		ropes += rope_ring(p, z)
	for i in range(ROPE_MERIDIANS):
		for twist in (ROPE_TWIST, -ROPE_TWIST):
			ropes += rope_meridian(p, 2 * math.pi * (i + 0.5) / ROPE_MERIDIANS, twist, *ROPE_RINGS)
	p.paint(ropes, GOLD, "MID", vary=0.05)

	mantle = p.lathe([(0.5, 2.22), (0.82, 2.0), (1.02, 1.74), (1.0, 1.7), (0.84, 1.92), (0.5, 2.16)], sides=SIDES, caps=False)
	p.paint(mantle, "tela_azul", "MID", vary=0.03)
	fringe = p.lathe([(1.0, 1.75), (1.04, 1.7), (1.0, 1.64), (0.96, 1.68)], sides=SIDES, caps=False)
	p.paint(fringe, GOLD, "LIGHT")


def sun(p, center, radius, rays=12):
	"""Disco de sol de oro con rayos, de frente a -Y."""
	disc = p.cylinder(radius, -0.04, 0.04, sides=24)
	p.transform(disc, Matrix.Translation(center) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	p.paint(disc, GOLD, "LIGHT")
	inner = p.cylinder(radius * 0.55, -0.03, 0.03, sides=20)
	p.transform(inner, Matrix.Translation(center + Vector((0, -0.04, 0))) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	p.paint(inner, GOLD, "DARK")
	for i in range(rays):
		a = 2 * math.pi * (i + 0.5) / rays
		ray = upright(p, [(-0.06, 0.0), (0.06, 0.0), (0.0, radius * 0.5)], 0.025, Vector((0, 0, 0)))
		p.transform(ray, Matrix.Translation(center) @ Matrix.Rotation(-a, 4, "Y") @ Matrix.Translation((0, 0, radius * 0.92)))
		p.paint(ray, GOLD, "MID")


def tilt_up(p, faces):
	p.transform(faces, Matrix.Translation((0, 0, FACE_Z)) @ Matrix.Rotation(-FACE_TILT, 4, "X") @ Matrix.Translation((0, 0, -FACE_Z)))


def head(p):
	skull = p.lathe(refine(HEAD), sides=SIDES)
	p.paint(skull, CLOTH, "DARK", vary=0.03)

	face = p.rounded_box(-0.38, 0.38, -0.06, 0.06, -0.34, 0.3, radius=0.05, segments=2)
	for v in {v for f in face for v in f.verts}:
		v.co.y += 0.14 * (v.co.x / 0.38) ** 2
	p.transform(face, Matrix.Translation((0, -0.52, FACE_Z)))
	p.paint(face, GOLD, "MID", vary=0.03)
	features = []
	for side in (-1, 1):
		eye = epi.eye(p, Vector((side * 0.17, -0.59, FACE_Z + 0.04)), 0.14, depth=0.03, pupil_swatch="doom", pupils=features)
		p.paint(eye, "hueso", "LIGHT")
		brow = p.box(side * 0.17 - 0.14, side * 0.17 + 0.14, -0.035, 0.0, -0.03, 0.03)
		p.transform(brow, Matrix.Translation((0, -0.585, FACE_Z + 0.19)) @ Matrix.Rotation(-side * 0.3, 4, "Y"))
		p.paint(brow, "noche", "MID")
		features += eye + brow
	nose = p.rounded_box(-0.055, 0.055, -0.08, 0.0, -0.12, 0.06, radius=0.02, segments=1)
	p.transform(nose, Matrix.Translation((0, -0.58, FACE_Z - 0.12)))
	p.paint(nose, GOLD, "LIGHT")
	mouth = p.rounded_box(-0.16, 0.16, -0.02, 0.0, -0.035, 0.035, radius=0.015, segments=1)
	p.transform(mouth, Matrix.Translation((0, -0.585, FACE_Z - 0.25)))
	p.paint(mouth, "noche", "MID")
	tassels = []
	for i in range(9):
		x = (i - 4) * 0.08
		tassels += p.box(x - 0.03, x + 0.03, -0.025, 0.025, FACE_Z + 0.26, FACE_Z + 0.4)
	p.transform(tassels, Matrix.Translation((0, -0.56, 0)))
	p.paint(tassels, CLOTH, "MID", vary=0.05)
	tilt_up(p, face + features + nose + mouth + tassels)
	for side in (-1, 1):
		spool = p.cylinder(0.17, -0.05, 0.05, sides=20)
		p.transform(spool, Matrix.Translation((side * 0.53, -0.02, 2.58)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
		p.paint(spool, GOLD, "LIGHT")
		stud = p.cylinder(0.08, -0.06, 0.06, sides=14)
		p.transform(stud, Matrix.Translation((side * 0.53, -0.02, 2.58)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
		p.paint(stud, "tela_azul", "MID")

	band = p.lathe([(0.47, 2.8), (0.52, 2.82), (0.52, 2.94), (0.44, 2.97)], sides=SIDES, caps=False)
	p.paint(band, GOLD, "MID")

	rays = 2 * CROWN_RAYS
	edge = [(math.cos(math.pi * i / rays) * r, math.sin(math.pi * i / rays) * r) for i in range(rays + 1) for r in [CROWN_RADIUS * (1.0 if i % 2 else 0.78)]]
	fan = upright(p, [(0.0, 0.0)] + edge, 0.03, Vector((0, 0.22, 2.78)), tilt=0.2)
	p.paint(fan, GOLD, "GRADIENT")
	sun(p, Vector((0, 0.12, 3.25)), 0.2, rays=10)

p = epi.Piece(37)
body(p)
sun(p, Vector((0, -radius_at(BODY, CHEST) - 0.02, CHEST)), 0.34)
head(p)
p.build("mallqui", kit, smooth=45)
epi.publish("mallqui")
