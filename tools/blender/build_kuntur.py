# Publica assets/epiphany/kuntur.glb (epi.publish): los cóndores de la Cumbre. kuntur_*: el joven (sub-jefe), negro con
# collar blanco y la banda blanca de las alas. apu_kuntur_*: el Apu (jefe), con un sol de oro en la frente, pectoral de
# oro y las alas con banda y puntas de oro. *_cuerpo: cuerpo, cabeza y cola, con el origen en el centro del cuerpo y
# el pico hacia -Y. *_ala_izq / *_ala_der: el ala desde el hombro (el origen, donde gira) hacia +X / -X.
# blender -b --factory-startup -P tools/blender/build_kuntur.py
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

kit = epi.start()

FEATHER = "gris_5"
YOUNG = {"band": "blanco", "tip": FEATHER, "eye": "fuego", "gold": None}
APU = {"band": "dorado", "tip": "dorado", "eye": "doom", "gold": "dorado"}


def piece(name, seed, fn, smooth=40):
	p = epi.Piece(seed)
	fn(p)
	return p.build(name, kit, smooth=smooth)


def plate(p, points, z, thick=0.03):
	"""Pluma o placa plana: un polígono (xy, antihorario) con grosor alrededor de z."""
	return p.polygon(points, z - thick / 2, z + thick / 2)


def feather(p, root, tip, width, z, thick=0.03):
	"""Pluma alargada de root a tip (xy), en punta redondeada."""
	d = (Vector(tip) - Vector(root)).normalized()
	n = Vector((-d.y, d.x))
	r, t = Vector(root), Vector(tip)
	pts = [r + n * width * 0.35, r + (t - r) * 0.55 + n * width * 0.5, t + n * width * 0.15, t - n * width * 0.15, r + (t - r) * 0.55 - n * width * 0.5, r - n * width * 0.35]
	return plate(p, [(v.x, v.y) for v in pts], z, thick)


def cuerpo(p, c):
	torso = p.lathe([(0.0, -0.78), (0.2, -0.7), (0.34, -0.45), (0.4, -0.1), (0.38, 0.25), (0.3, 0.5), (0.2, 0.62), (0.0, 0.66)], sides=12)
	p.transform(torso, Matrix.Diagonal((1.0, 1.0, 0.78, 1)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	p.paint(torso, FEATHER, z_range=(-0.4, 0.4), vary=0.08)
	back = []
	for row in range(4):
		y = -0.35 + row * 0.22
		for s in (-1, 1):
			back += feather(p, (s * 0.12, y), (s * 0.3, y + 0.32), 0.22, 0.27 - row * 0.015)
	p.paint(back, FEATHER, "LIGHT", vary=0.08)
	ruff = []
	for k in range(14):
		a = 2 * math.pi * k / 14
		ruff += p.blob((math.cos(a) * 0.24, -0.58, 0.08 + math.sin(a) * 0.2), 0.11, squash=(1.0, 0.8, 1.0), rough=0.2)
	p.paint(ruff, "blanco", "MID", vary=0.06)
	neck = p.cylinder(0.11, 0.0, 0.3, sides=8, radius_top=0.09)
	p.transform(neck, Matrix.Translation((0, -0.62, 0.1)) @ Matrix.Rotation(math.pi / 2 - 0.5, 4, "X"))
	head = p.blob((0, -0.86, 0.24), 0.16, squash=(0.85, 1.15, 0.9), rough=0.08)
	p.paint(neck + head, "roca_naranja", "LOW", vary=0.06)
	comb = []
	for k in range(4):
		comb += p.blob((0, -0.98 + k * 0.08, 0.36 - k * 0.012), 0.055 - k * 0.006, squash=(0.6, 1.0, 1.0), rough=0.1)
	p.paint(comb, "tela_roja", "LOW", vary=0.05)
	beak = []
	for s in (1.0, 0.75):
		beak += p.cylinder(0.065 * s, 0.0, 0.14, sides=6, radius_top=0.045 * s)
	p.transform(beak, Matrix.Translation((0, -0.98, 0.22)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	hook = p.cylinder(0.045, 0.0, 0.12, sides=6, radius_top=0.0)
	p.transform(hook, Matrix.Translation((0, -1.12, 0.22)) @ Matrix.Rotation(math.pi / 2 + 0.9, 4, "X"))
	p.paint(beak, "hueso", "MID")
	p.paint(hook, "gris_4", "MID")
	for s in (-1, 1):
		eye = p.blob((s * 0.11, -0.92, 0.29), 0.035, rough=0.0)
		p.paint(eye, c["eye"], "LIGHT")
	tail = []
	for k in range(7):
		a = (k - 3) * 0.16
		tail += feather(p, (math.sin(a) * 0.05, 0.55), (math.sin(a) * 0.55, 0.55 + math.cos(a) * 0.6), 0.2, 0.05 + abs(k - 3) * 0.005)
	p.paint(tail, FEATHER, "MID", vary=0.08)
	talons = []
	for s in (-1, 1):
		leg = p.cylinder(0.05, 0.0, 0.22, sides=6)
		p.transform(leg, Matrix.Translation((s * 0.16, 0.05, -0.38)))
		talons += leg
		for k in (-1, 0, 1):
			claw = p.cylinder(0.025, 0.0, 0.14, sides=4, radius_top=0.0)
			p.transform(claw, Matrix.Translation((s * 0.16, 0.05, -0.38)) @ Matrix.Rotation(-math.pi / 2 + 0.4, 4, "X") @ Matrix.Rotation(k * 0.4, 4, "Y"))
			talons += claw
	p.paint(talons, "gris_4", "MID", vary=0.05)
	if c["gold"]:
		sun = p.cylinder(0.12, 0.0, 0.03, sides=12)
		rays = []
		for k in range(8):
			ray = p.cylinder(0.04, 0.0, 0.025, sides=3)
			p.transform(ray, Matrix.Rotation(k * math.pi / 4, 4, "Z") @ Matrix.Translation((0.17, 0, 0)) @ Matrix.Scale(1.6, 4, Vector((1, 0, 0))))
			rays += ray
		p.transform(sun + rays, Matrix.Translation((0, -0.84, 0.43)) @ Matrix.Rotation(math.pi / 2 - 0.5, 4, "X"))
		chest = []
		for w, z in ((0.44, 0.0), (0.3, -0.12), (0.16, -0.24)):
			chest += p.box(-w / 2, w / 2, -0.03, 0.0, z - 0.06, z + 0.06)
		p.transform(chest, Matrix.Translation((0, -0.66, -0.02)) @ Matrix.Rotation(0.35, 4, "X"))
		p.paint(sun + rays + chest, c["gold"], "MID", vary=0.03)


def shaft(p, root, tip, z, width=0.018):
	"""Raquis: la vara clara del medio de una pluma, apenas arriba de ella."""
	d = (Vector(tip) - Vector(root)).normalized()
	n = Vector((-d.y, d.x)) * width / 2
	r, t = Vector(root), Vector(tip) - d * 0.06
	return plate(p, [(v.x, v.y) for v in (r + n, r - n, t - n * 0.4, t + n * 0.4)], z, 0.012)


def ala(p, c, mirror):
	"""Ala de plumas encimadas: hueso adelante, tres filas de cobertoras, la banda, secundarias y los dedos de las
	primarias abiertos y curvados hacia arriba en la punta, cada pluma con su raquis."""
	arm = []
	for x0, x1, r0, r1, y in ((0.0, 0.62, 0.075, 0.06, -0.17), (0.6, 1.25, 0.06, 0.04, -0.15)):
		bone = p.cylinder(r0, x0, x1, sides=7, radius_top=r1)
		p.transform(bone, Matrix.Translation((0, y, 0.02)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
		arm += bone
	p.paint(arm, FEATHER, "LIGHT", vary=0.05)
	coverts = []
	for row in range(3):
		count = 9 - row
		for k in range(count):
			x = 0.05 + (k + 0.5 * (row % 2)) * 1.2 / count
			y = -0.2 + row * 0.11
			coverts.append(feather(p, (x, y), (x + 0.03, y + 0.22), 0.2, 0.06 - row * 0.012, thick=0.025))
	for k, f in enumerate(coverts):
		p.paint(f, FEATHER, "LIGHT" if k % 3 else "MID", vary=0.06)
	band = []
	for k in range(9):
		x = 0.06 + k * 0.135
		band += feather(p, (x, 0.13), (x + 0.03, 0.36), 0.17, 0.07, thick=0.02)
	p.paint(band, c["band"], "MID", vary=0.06)
	secondaries, shafts = [], []
	for k in range(10):
		x = 0.06 + k * 0.125
		root, tip = (x, 0.14), (x + 0.06, 0.64 + 0.04 * math.sin(k * 1.7))
		secondaries += feather(p, root, tip, 0.17, -0.02 - (k % 2) * 0.008)
		shafts += shaft(p, root, tip, -0.003 - (k % 2) * 0.008)
	p.paint(secondaries, FEATHER, "MID", vary=0.08)
	primaries, tips = [], []
	for k in range(7):
		a = -0.42 + k * 0.15
		root = Vector((1.18, -0.14 + k * 0.05))
		d = Vector((math.cos(a), math.sin(a)))
		length = 0.8 + 0.12 * math.sin(k * 0.9 + 0.5)
		mid = root + d * length * 0.7
		z = -0.01 - k * 0.007
		primaries += feather(p, root, mid + d * 0.05, 0.15, z)
		shafts += shaft(p, root, mid, z + 0.016)
		curl = feather(p, mid - d * 0.02, root + d * length, 0.11, 0.0, thick=0.025)
		p.transform(curl, Matrix.Translation((mid.x, mid.y, z)) @ Matrix.Rotation(0.35, 4, Vector((-d.y, d.x, 0))) @ Matrix.Translation((-mid.x, -mid.y, 0)))
		tips += curl
	p.paint(primaries, FEATHER, "MID", vary=0.08)
	p.paint(tips, c["tip"], "MID" if c["gold"] else "LOW", vary=0.06)
	p.paint(shafts, "gris_2" if not c["gold"] else c["gold"], "MID", vary=0.04)
	if mirror:
		p.transform(list(p.bm.faces), Matrix.Scale(-1, 4, Vector((1, 0, 0))))

for prefix, c, seed in (("kuntur", YOUNG, 1), ("apu_kuntur", APU, 11)):
	piece(prefix + "_cuerpo", seed, lambda p, c=c: cuerpo(p, c))
	piece(prefix + "_ala_izq", seed + 1, lambda p, c=c: ala(p, c, False))
	piece(prefix + "_ala_der", seed + 1, lambda p, c=c: ala(p, c, True))

epi.layout(kit, columns=3, spacing=4.5)
epi.publish("kuntur")
