# Publica assets/epiphany/ojo_vigia.glb (epi.publish): los ojos de la Queñoa (jefe y sub-jefe), como el ojo del jefe
# final pero de madera: globo de hueso con iris y pupila de rendija, metido en un nudo de corteza con raíces, y dos
# párpados de corteza que el código gira en X para abrir. Todo con el origen en el centro del ojo y mirando a -Y.
# Con "-- templo", ojo_vigia_templo_*: los de la revancha del templo, con la paleta del templo (epi.TEMPLO) y el musgo de cristal.
# blender -b -P tools/blender/build_ojo_vigia.py [-- templo]
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

EYE = 0.8
LID = 0.86
KNOT = 0.94
BARK = "roca_naranja"
ROOT = "madera_oscura"

kit = epi.start()


def piece(name, seed, fn):
	p = epi.Piece(seed)
	fn(p)
	return p.build(name, kit, smooth=40)


def shell(p, radius, thickness, t_range, u_range, steps=(6, 12)):
	"""Cáscara de esfera alrededor del origen: t gira desde -Y hacia +Z (en X), u abre hacia los costados."""
	rings = []
	for r in (radius, radius + thickness):
		grid = []
		for i in range(steps[0] + 1):
			t = t_range[0] + (t_range[1] - t_range[0]) * i / steps[0]
			row = []
			for j in range(steps[1] + 1):
				u = u_range[0] + (u_range[1] - u_range[0]) * j / steps[1]
				row.append(p.bm.verts.new((r * math.sin(u), -r * math.cos(u) * math.cos(t), r * math.cos(u) * math.sin(t))))
			grid.append(row)
		rings.append(grid)
	inner, outer = rings
	faces = []
	for i in range(steps[0]):
		for j in range(steps[1]):
			faces.append(p.bm.faces.new((outer[i][j], outer[i][j + 1], outer[i + 1][j + 1], outer[i + 1][j])))
			faces.append(p.bm.faces.new((inner[i][j], inner[i + 1][j], inner[i + 1][j + 1], inner[i][j + 1])))
	edges = []
	for i in range(steps[0]):
		for j in (0, steps[1]):
			edges.append(p.bm.faces.new((inner[i][j], outer[i][j], outer[i + 1][j], inner[i + 1][j])))
	for i in (0, steps[0]):
		for j in range(steps[1]):
			edges.append(p.bm.faces.new((inner[i][j], inner[i][j + 1], outer[i][j + 1], outer[i][j])))
	return faces, edges


def root(p, start, heading, length, radius):
	"""Raíz que sale de start y cae, retorcida, afinándose."""
	faces = []
	pos = Vector(start)
	d = Vector(heading).normalized()
	steps = 6
	for k in range(steps):
		r = radius * (1.0 - 0.75 * k / steps)
		seg = p.cylinder(r, 0.0, length / steps * 1.15, sides=6, radius_top=r * 0.85)
		rot = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
		p.transform(seg, Matrix.Translation(pos) @ rot)
		faces += seg
		pos = pos + d * length / steps
		d = (d + Vector((p.rng.uniform(-0.3, 0.3), p.rng.uniform(-0.3, 0.3), -0.35))).normalized()
	return faces


def onto_globe(p, faces, lift):
	"""Pega un prisma plano (dibujado en XY, de z -0.03 a 0.02) al frente del globo, lift por encima."""
	for v in {v for f in faces for v in f.verts}:
		x, z, r = v.co.x, v.co.y, EYE + lift + v.co.z
		v.co = Vector((x, -math.sqrt(max(EYE ** 2 - x * x - z * z, 0.0)), z)).normalized() * r


def disc(p, radius, sides=28):
	return p.polygon([(math.cos(2 * math.pi * k / sides) * radius, math.sin(2 * math.pi * k / sides) * radius) for k in range(sides)], -0.03, 0.02)


def globo(p):
	"""Hueso con iris rojo bordeado de oscuro y pupila de rendija."""
	ball = p.blob((0, 0, 0), EYE, subdiv=3, rough=0.0)
	p.paint(ball, "hueso", z_range=(-EYE, EYE))
	ring = disc(p, 0.37)
	onto_globe(p, ring, 0.0)
	p.paint(ring, ROOT, "DARK")
	iris = disc(p, 0.32)
	onto_globe(p, iris, 0.01)
	p.paint(iris, "doom", "MID")
	slit = []
	wide, tall = 0.05, 0.27
	for i in range(9):
		t = math.pi * i / 8
		slit.append((math.sin(t) * wide, -math.cos(t) * tall))
	for i in range(1, 8):
		t = math.pi * i / 8
		slit.append((-math.sin(t) * wide, math.cos(t) * tall))
	pupil = p.polygon(slit, -0.03, 0.02)
	onto_globe(p, pupil, 0.02)
	p.paint(pupil, "noche", "DARK")


def nudo(p):
	"""El nudo de corteza que envuelve el ojo por atrás, con el borde que hace de cuenca y raíces que cuelgan."""
	bark, edges = shell(p, KNOT, 0.12, (math.pi * 0.45, math.pi * 1.55), (-math.pi / 2, math.pi / 2), steps=(10, 14))
	p.jitter(bark + edges, 0.03)
	p.paint(bark, BARK, "LOW", vary=0.08)
	p.paint(edges, ROOT, "MID")
	moss = []
	for k in range(6):
		a = -1.1 + 2.2 * k / 5
		moss += p.blob((math.sin(a) * KNOT * 0.95, 0.15, math.cos(a) * KNOT * 0.95 + 0.05), p.rng.uniform(0.12, 0.17), squash=(1.3, 1.0, 0.6), subdiv=1, rough=0.25)
	p.paint(moss, "musgo", "MID", vary=0.1)
	roots = []
	for sx, length in ((-0.5, 1.1), (0.0, 1.4), (0.45, 1.0), (-0.2, 0.8)):
		roots += root(p, (sx, 0.3, -KNOT * 0.8), (sx * 0.6, 0.3, -1.0), length, 0.11)
	for sx in (-1, 1):
		roots += root(p, (sx * KNOT * 0.9, 0.2, 0.2), (sx, 0.4, -0.4), 0.7, 0.09)
	p.paint(roots, ROOT, z_range=(-2.5, 0.0), vary=0.06)


def parpado(p, moss=True):
	"""Párpado de arriba, cerrado: cuarto de cáscara de corteza adelante y arriba del ojo, con el borde oscuro."""
	plate, edges = shell(p, LID, 0.07, (0.0, math.pi / 2), (-math.pi / 2, math.pi / 2), steps=(6, 12))
	p.paint(plate, BARK, "LOW", vary=0.06)
	p.paint(edges, ROOT, "DARK")
	rim, rim_edges = shell(p, LID + 0.04, 0.05, (0.0, 0.12), (-math.pi / 2, math.pi / 2), steps=(1, 12))
	p.paint(rim + rim_edges, ROOT, "MID")
	p.jitter(plate, 0.015)
	if moss:
		tufts = []
		for k in range(4):
			a = -0.9 + 1.8 * k / 3
			tufts += p.blob((math.sin(a) * LID, -0.25, math.cos(a) * LID * 0.95), p.rng.uniform(0.09, 0.13), squash=(1.3, 1.0, 0.6), subdiv=1, rough=0.25)
		p.paint(tufts, "musgo", "MID", vary=0.1)


def parpado_inf(p):
	parpado(p, moss=False)
	p.transform(list(p.bm.faces), Matrix.Scale(-1, 4, (0, 0, 1)))


TEMPLE = epi.variant() == "templo"
NAME = "ojo_vigia_templo" if TEMPLE else "ojo_vigia"
if TEMPLE:
	epi.REMAP.update(epi.TEMPLO, musgo="cristal")
piece(NAME + "_globo", 1, globo)
piece(NAME + "_nudo", 2, nudo)
piece(NAME + "_parpado", 3, parpado)
piece(NAME + "_parpado_inf", 3, parpado_inf)
epi.layout(kit, columns=4, spacing=3.0)
epi.publish(NAME)
