# Publica assets/epiphany/momia.glb (epi.publish): la Momia Guardiana de la Chullpa, un fardo funerario de 3 m en una
# sola pieza (el código la mueve, gira y aplasta entera). Bulto de algodón con franjas de aguayo abajo y red de cuerdas,
# cabeza falsa con máscara de oro, orejeras y tocado de plumas. Origen en la base, la cara mira a -Y.
# blender -b -P tools/blender/build_momia.py
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

kit = epi.start()
BODY = [(0.0, 0.0), (0.62, 0.0), (0.84, 0.12), (0.93, 0.4), (0.96, 0.8), (0.91, 1.2), (0.81, 1.6), (0.66, 1.95), (0.48, 2.15), (0.3, 2.25), (0.0, 2.28)]
SIDES = 28
## Franjas del aguayo (de abajo arriba) y alturas de los anillos de cuerda.
STRIPES = [(0.0, 0.14, "tela_roja", "DARK"), (0.14, 0.2, "flor_amarilla", "MID"), (0.2, 0.36, "tela_roja", "MID"), (0.36, 0.42, "hueso", "LIGHT"),
	(0.42, 0.56, "tela_azul", "MID"), (0.56, 0.62, "flor_amarilla", "MID"), (0.62, 0.8, "tela_roja", "MID"), (0.8, 0.86, "noche", "MID")]
ROPE_RINGS = (0.86, 2.08)
## Red de cuerdas en rombos: dos juegos de cuerdas que suben girando en sentidos contrarios.
ROPE_MERIDIANS = 8
ROPE_TWIST = 1.1
COTTON = "hueso"
## La cara mira hacia arriba (FACE_TILT rad desde el frente) para que se lea desde la cámara alta.
FACE_Z = 2.68
FACE_TILT = 0.25
HEAD = [(math.cos(a) * 0.5, FACE_Z + math.sin(a) * 0.5) for a in (math.radians(d) for d in range(-90, 91, 10))]
ROPE = "madera_oscura"


def radius_at(profile, z):
	for (r0, z0), (r1, z1) in zip(profile, profile[1:]):
		if z0 <= z <= z1 and z1 > z0:
			return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
	return 0.0


def refine(profile, step=0.06):
	"""El perfil con un anillo cada step de alto, para que las franjas pintadas por altura tengan dónde caer."""
	out = [profile[0]]
	for (r0, z0), (r1, z1) in zip(profile, profile[1:]):
		n = max(1, int(abs(z1 - z0) / step))
		for i in range(1, n + 1):
			t = i / n
			out.append((r0 + (r1 - r0) * t, z0 + (z1 - z0) * t))
	return out


def rope_ring(p, z, thick=0.045):
	r = radius_at(BODY, z)
	return p.lathe([(r - 0.01, z - thick), (r + thick * 0.7, z - thick * 0.5), (r + thick * 0.7, z + thick * 0.5), (r - 0.01, z + thick)], sides=SIDES, caps=False)


def rope_meridian(p, angle, twist=0.0, z0=0.86, z1=2.08, width=0.035, steps=24):
	"""Cuerda pegada al bulto que sube girando twist radianes: una tira que sigue el perfil, apenas afuera."""
	rows = []
	for i in range(steps + 1):
		z = z0 + (z1 - z0) * i / steps
		a = angle + twist * i / steps
		c, s = math.cos(a), math.sin(a)
		tx, ty = -s, c
		r = radius_at(BODY, z) + 0.02
		rows.append([p.bm.verts.new((c * r + tx * w, s * r + ty * w, z)) for w in (-width, 0.0, width)])
		rows[-1][1].co += Vector((c, s, 0)) * 0.025
	faces = []
	for a, b in zip(rows, rows[1:]):
		faces.append(p.bm.faces.new((a[0], a[1], b[1], b[0])))
		faces.append(p.bm.faces.new((a[1], a[2], b[2], b[1])))
	return faces


def momia(p):
	body = p.lathe(refine(BODY), sides=SIDES)
	p.paint_bands(body, STRIPES, default=(0, 0, COTTON, "MID"))
	ropes = []
	for z in ROPE_RINGS:
		ropes += rope_ring(p, z)
	for i in range(ROPE_MERIDIANS):
		for twist in (ROPE_TWIST, -ROPE_TWIST):
			ropes += rope_meridian(p, 2 * math.pi * (i + 0.5) / ROPE_MERIDIANS, twist)
	p.paint(ropes, ROPE, "MID", vary=0.05)

	head = p.lathe(refine(HEAD), sides=SIDES)
	p.paint(head, COTTON, "LIGHT", vary=0.03)
	collar = p.lathe([(0.3, 2.2), (0.36, 2.22), (0.35, 2.27), (0.28, 2.29)], sides=SIDES, caps=False)
	p.paint(collar, "tela_roja", "DARK")

	epi.angry_face(p, Vector((0, 0, FACE_Z)), 0.5, FACE_TILT, size=1.3)
	for side in (-1, 1):
		spool = p.cylinder(0.15, -0.05, 0.05, sides=20)
		p.transform(spool, Matrix.Translation((side * 0.5, -0.02, FACE_Z)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
		p.paint(spool, "dorado", "LIGHT")
		stud = p.cylinder(0.07, -0.06, 0.06, sides=14)
		p.transform(stud, Matrix.Translation((side * 0.5, -0.02, FACE_Z)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
		p.paint(stud, "doom", "MID")

	band = p.lathe([(radius_at(HEAD, z) + 0.03, z) for z in (FACE_Z + 0.34, FACE_Z + 0.39, FACE_Z + 0.44, FACE_Z + 0.48)], sides=SIDES, caps=False)
	p.paint(band, "tela_roja", "MID")
	feathers = []
	colors = ["flor_amarilla", "tela_roja", "tela_azul", "flor_amarilla", "tela_roja", "tela_azul", "flor_amarilla"]
	for i, swatch in enumerate(colors):
		t = (i - (len(colors) - 1) / 2) / ((len(colors) - 1) / 2)
		f = p.polygon([(-0.06, 0.0), (0.06, 0.0), (0.05, 0.42), (0.0, 0.5), (-0.05, 0.42)], -0.012, 0.012)
		p.transform(f, Matrix.Translation((0, 0.12, FACE_Z + 0.2)) @ Matrix.Rotation(t * 0.9, 4, "Y") @ Matrix.Rotation(math.pi / 2 - 0.25, 4, "X"))
		p.paint(f, swatch, "MID")
		feathers += f
	return {}


p = epi.Piece(31)
momia(p)
p.build("momia", kit, smooth=45)
epi.publish("momia")
