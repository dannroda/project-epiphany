# Arma assets/epiphany/jefe.blend: el Ojo con manos, por piezas sueltas que se mueven por código (sin esqueleto).
# El cuerpo flota: el origen es su centro y mira a -Y. El ojo y los párpados tienen el origen en el centro del ojo (OJO);
# las manos, en la palma (abajo plana), con tres poses: abierta (golpe), puño y garra (agarre). La derecha es la izquierda espejada.
# blender -b -P tools/blender/build_jefe.py
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

STONE = "piedra_templo"
IRON = "hierro"
TRIM = "dorado"
GLOW = "doom"
NEON = "neon"
CENTER = 0.0
RADIUS = 2.2
LOBES = 8
OJO = Vector((0.0, -1.38, 0.3))
EYE = 1.2
LID = 1.32
HAND = 1.3
POSES = {"abierta": (0.05, 0.05, 0.08), "puno": (1.35, 1.45, 1.3), "garra": (0.55, 0.65, 0.6)}
kit = epi.start()


def piece(name, seed, fn):
	p = epi.Piece(seed)
	extra = fn(p)
	obj = p.build(name, kit)
	for key, value in (extra if isinstance(extra, dict) else {}).items():
		obj[key] = value
	return obj


def lobed(r, a):
	return r * (1.0 - 0.07 * abs(math.sin(a * LOBES / 2)) ** 0.5)


def shell(p, radius, thickness, t_range, u_range, steps=(6, 10)):
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


def ring(p, radius, width, depth, sides=16):
	"""Aro que mira a -Y, centrado en el origen."""
	faces = p.lathe([(radius, 0.0), (radius + width, 0.0), (radius + width, depth), (radius, depth), (radius, 0.0)], sides=sides, caps=False)
	p.transform(faces, Matrix.Rotation(math.pi / 2, 4, "X"))
	return faces


def surface(z, a):
	"""Punto del cuerpo a la altura z y el ángulo a (0 = frente, -Y)."""
	h = math.sqrt(max(RADIUS ** 2 - (z - CENTER) ** 2, 0.0)) * 1.04
	r = lobed(h, a)
	return Vector((r * math.sin(a), -r * math.cos(a), z))


def jefe_cuerpo(p):
	"""La calabaza de piedra: gajos con juntas de hierro, boca de horno, cuenca del ojo, tallo de cobre, anclas de neón
	para las manos y el propulsor de abajo."""
	sides = LOBES * 6
	profile = [(0.0, -RADIUS * 0.86)]
	for i in range(1, 12):
		t = -math.pi / 2 + math.pi * i / 12
		profile.append((math.cos(t) * RADIUS * 1.04, math.sin(t) * RADIUS * 0.92))
	profile.append((0.0, RADIUS * 0.92))
	body = p.lathe(profile, sides=sides, phase=math.pi / 2)
	for v in {v for f in body for v in f.verts}:
		a = math.atan2(v.co.x, -v.co.y)
		h = Vector((v.co.x, v.co.y, 0)).length
		v.co.x, v.co.y = lobed(h, a) * math.sin(a), -lobed(h, a) * math.cos(a)
	seams, plates = [], []
	for f in body:
		c = f.calc_center_median()
		a = math.atan2(c.x, -c.y) * LOBES / (2 * math.pi)
		(seams if abs(a - round(a)) < 0.1 else plates).append(f)
	p.paint(plates, STONE, z_range=(-RADIUS, RADIUS), vary=0.05)
	p.paint(seams, IRON, "LOW")

	socket = ring(p, EYE + 0.02, 0.18, 0.6, sides=20)
	p.transform(socket, Matrix.Translation(OJO + Vector((0, 0.2, 0))))
	p.paint(socket, IRON, "MID")
	studs = []
	for k in range(8):
		a = 2 * math.pi * k / 8 + math.pi / 8
		s = p.box(-0.08, 0.08, -0.08, 0.08, -0.08, 0.08)
		p.transform(s, Matrix.Translation(OJO + Vector((math.cos(a) * (EYE + 0.11), -0.42, math.sin(a) * (EYE + 0.11)))) @ Matrix.Rotation(math.pi / 4, 4, "Y"))
		studs += s
	p.paint(studs, TRIM, "MID")
	hollow = p.blob((0, 0, 0), EYE * 0.98, subdiv=2, rough=0.0)
	p.transform(hollow, Matrix.Translation(OJO + Vector((0, 0.12, 0))))
	p.paint(hollow, "noche", "DARK")

	top, bottom, span, n = -0.98, -1.5, 0.95, 10
	mouth, teeth, lips = [], [], []
	for i in range(n):
		a0, a1 = -span + 2 * span * i / n, -span + 2 * span * (i + 1) / n
		quad = [surface(bottom, a0), surface(bottom, a1), surface(top, a1), surface(top, a0)]
		mouth.append(p.bm.faces.new([p.bm.verts.new(Vector((q.x * 0.97, q.y * 0.97, q.z))) for q in quad]))
		am = (a0 + a1) / 2
		for z, sgn in ((top, 1), (bottom, -1)):
			if (i % 2 == 0) == (sgn > 0):
				continue
			tip = z - sgn * 0.36
			pts = (surface(z, a0 + 0.02), surface(z, a1 - 0.02), surface(tip, am))
			vs = [p.bm.verts.new(q) for q in pts]
			back = [p.bm.verts.new(Vector((q.x * 0.94, q.y * 0.94, q.z))) for q in pts]
			teeth.append(p.bm.faces.new(vs if sgn < 0 else vs[::-1]))
			teeth.append(p.bm.faces.new(back[::-1] if sgn < 0 else back))
			for k in range(3):
				teeth.append(p.bm.faces.new((vs[k], back[k], back[(k + 1) % 3], vs[(k + 1) % 3])))
	p.paint(mouth, GLOW, "DARK")
	p.paint(teeth, "hueso", "MID", vary=0.08)
	for lo, hi in ((top, top + 0.13), (bottom - 0.13, bottom)):
		for i in range(n):
			a0, a1 = -span - 0.05 + (2 * span + 0.1) * i / n, -span - 0.05 + (2 * span + 0.1) * (i + 1) / n
			quad = [surface(lo, a0), surface(lo, a1), surface(hi, a1), surface(hi, a0)]
			vs = [p.bm.verts.new(Vector((q.x * 1.03, q.y * 1.03, q.z))) for q in quad]
			bs = [p.bm.verts.new(Vector((q.x * 0.94, q.y * 0.94, q.z))) for q in quad]
			lips.append(p.bm.faces.new(vs))
			lips.append(p.bm.faces.new((vs[3], vs[2], bs[2], bs[3])))
			lips.append(p.bm.faces.new((bs[0], bs[1], vs[1], vs[0])))
	p.paint(lips, IRON, "MID")

	z = RADIUS * 0.9
	crown = []
	for w, h in ((0.8, 0.18), (0.55, 0.18), (0.32, 0.16)):
		crown += p.box(-w / 2, w / 2, -w / 2, w / 2, z - 0.06, z + h)
		z += h
	p.paint(crown, IRON, z_range=(z - 0.6, z), vary=0.05)
	stem = []
	steps = 9
	for i in range(steps):
		t = i / (steps - 1)
		r0 = 0.14 * (1 - t) + 0.03
		seg = p.cylinder(r0, 0.0, 0.17, sides=6, radius_top=r0 * 0.85)
		p.transform(seg, Matrix.Translation((0.2 * math.sin(t * 5), 0.1 * math.cos(t * 4) - 0.1, z + t * 1.15)) @ Matrix.Rotation(0.35 * math.cos(t * 5), 4, "Y"))
		stem += seg
	p.paint(stem, "cobre_verde", z_range=(z, z + 1.2))
	tip = p.blob((0.2 * math.sin(5), 0.1 * math.cos(4) - 0.1, z + 1.3), 0.13, subdiv=1, rough=0.0)
	p.paint(tip, NEON, "MID")
	for sx in (-1, 1):
		leaf = p.box(-0.06, 0.06, -0.02, 0.02, 0.0, 0.45)
		p.transform(leaf, Matrix.Translation((sx * 0.12, 0, z)) @ Matrix.Rotation(sx * 1.0, 4, "Y"))
		p.paint(leaf, "cobre_verde", "LOW")

	cores = []
	for sx in (-1, 1):
		base = Vector((sx * RADIUS * 0.97, 0.1, -0.1))
		a = ring(p, 0.26, 0.11, 0.24, sides=10)
		p.transform(a, Matrix.Translation(base) @ Matrix.Rotation(sx * math.pi / 2, 4, "Z"))
		p.paint(a, IRON, "MID")
		core = p.cylinder(0.26, 0.0, 0.14, sides=10)
		p.transform(core, Matrix.Translation(base) @ Matrix.Rotation(sx * math.pi / 2, 4, "Y"))
		cores += core
	thruster = p.lathe([(0.0, -RADIUS * 0.84), (1.05, -RADIUS * 0.84), (0.95, -RADIUS * 0.84 - 0.3), (0.7, -RADIUS * 0.84 - 0.42), (0.0, -RADIUS * 0.84 - 0.42)], sides=12)
	p.paint(thruster, IRON, "LOW")
	vent = p.cylinder(0.5, -RADIUS * 0.84 - 0.46, -RADIUS * 0.84 - 0.4, sides=12)
	cores += vent
	p.paint(cores, NEON, "MID")
	studs = []
	for k in range(12):
		s = p.box(-0.06, 0.06, -0.06, 0.06, -0.06, 0.06)
		p.transform(s, Matrix.Rotation(2 * math.pi * k / 12, 4, "Z") @ Matrix.Translation((0, -1.0, -RADIUS * 0.84 - 0.15)))
		studs += s
	p.paint(studs, TRIM, "MID")
	return {"centro_ojo": list(OJO)}


def jefe_ojo(p):
	"""El globo: blanco de hueso con venas de doom, iris de neón (el código lo pulsa al cargar el orbe) y pupila de rendija, mirando a -Y."""
	ball = p.blob((0, 0, 0), EYE, subdiv=3, rough=0.0)
	white, iris, pupil = [], [], []
	for f in ball:
		c = f.calc_center_median() / EYE
		if c.y < -0.8 and abs(c.x) < 0.11 and abs(c.z) < 0.5:
			pupil.append(f)
		elif c.y < -0.8:
			iris.append(f)
		else:
			white.append(f)
	p.paint(white, "hueso", z_range=(-EYE, EYE))
	p.paint(iris, NEON, "MID", vary=0.08)
	p.paint(pupil, "noche", "DARK")
	veins = []
	for k in range(10):
		a = 2 * math.pi * k / 10 + p.rng.uniform(-0.2, 0.2)
		length = p.rng.uniform(0.25, 0.45)
		v = p.box(-0.018, 0.018, -0.018, 0.018, 0.0, length)
		p.transform(v, Matrix.Rotation(a, 4, "Y") @ Matrix.Rotation(-math.pi / 2 + 0.75, 4, "X") @ Matrix.Translation((0, 0, EYE * 0.99)))
		veins += v
	p.paint(veins, GLOW, "DARK")


def jefe_parpado(p):
	"""Párpado de arriba, cerrado: un cuarto de cáscara de hierro adelante y arriba del ojo, con el borde dorado.
	Se abre girando en X hacia atrás; el de abajo es el mismo espejado en Z."""
	plate, edges = shell(p, LID, 0.08, (0.0, math.pi / 2), (-math.pi / 2, math.pi / 2), steps=(6, 12))
	p.paint(plate, IRON, z_range=(0, LID), vary=0.05)
	p.paint(edges, IRON, "DARK")
	rim, rim_edges = shell(p, LID + 0.05, 0.06, (0.0, 0.14), (-math.pi / 2, math.pi / 2), steps=(1, 12))
	p.paint(rim + rim_edges, TRIM, "MID")
	bands = []
	for t in (0.6, 1.05):
		b, be = shell(p, LID + 0.06, 0.03, (t, t + 0.08), (-math.pi / 2, math.pi / 2), steps=(1, 12))
		bands += b + be
	p.paint(bands, IRON, "LOW")
	glyph = epi.eye(p, Vector((0, 0, 0)), 0.22, depth=0.04, pupil_swatch="noche")
	p.transform(glyph, Matrix.Rotation(-0.75, 4, "X") @ Matrix.Translation((0, -LID - 0.08, 0)))
	p.paint(glyph, TRIM, "LIGHT")


def jefe_parpado_inf(p):
	jefe_parpado(p)
	p.transform(list(p.bm.faces), Matrix.Scale(-1, 4, (0, 0, 1)))


def finger(p, x, lengths, curl, width=0.11, height=0.3):
	"""Dedo de tres falanges que nace en (x, -0.55) y se dobla hacia abajo en cada nudillo."""
	segs, caps = [], []
	m = Matrix.Translation((x, -0.55, 0.04))
	for k, (length, bend) in enumerate(zip(lengths, curl)):
		m = m @ Matrix.Rotation(bend, 4, "X")
		h = height - k * 0.06
		seg = p.box(-width, width, -length, -0.02, 0.0, h, taper=0.015)
		cap = p.box(-width - 0.01, width + 0.01, -0.06, 0.02, 0.02, h + 0.03)
		p.transform(seg + cap, m)
		segs += seg
		caps += cap
		m = m @ Matrix.Translation((0, -length, 0))
	claw = p.box(-width * 0.6, width * 0.6, -0.2, 0.0, 0.0, 0.16, taper=0.05)
	p.transform(claw, m @ Matrix.Rotation(curl[-1] * 0.5, 4, "X"))
	return segs, caps, claw


def hand(p, pose, mirror):
	"""Guantelete de hierro flotando, la palma (plana, abajo) en el origen y los dedos hacia -Y. El lomo de piedra lleva
	un ojo de neón (dónde pegar cuando la mano queda aturdida); la muñeca, el núcleo de neón que la une al cuerpo."""
	curl = POSES[pose]
	palm = p.rounded_box(-0.6, 0.6, -0.6, 0.45, 0.0, 0.42, radius=0.08, segments=1)
	p.paint(palm, IRON, z_range=(0, 0.45), vary=0.04)
	back = p.rounded_box(-0.5, 0.5, -0.5, 0.35, 0.42, 0.56, radius=0.05, segments=1)
	p.paint(back, STONE, z_range=(0.4, 0.6), vary=0.06)
	glyph = epi.eye(p, Vector((0, 0, 0)), 0.26, depth=0.04, pupil_swatch="noche")
	p.transform(glyph, Matrix.Translation((0, -0.07, 0.56)) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
	p.paint(glyph, NEON, "MID")
	fingers, knuckles, claws = [], [], []
	for i, x in enumerate((-0.43, -0.145, 0.145, 0.43)):
		base = 0.36 + (0.06 if i in (1, 2) else 0.0)
		s, c, cl = finger(p, x, (base, base * 0.82, base * 0.67), curl)
		fingers += s
		knuckles += c
		claws += cl
	s, c, cl = finger(p, 0.0, (0.36, 0.3), curl[:2], width=0.12, height=0.28)
	p.transform(s + c + cl, Matrix.Translation((-0.6, -0.15, 0.0)) @ Matrix.Rotation(-0.6, 4, "Z") @ Matrix.Translation((0, 0.55, 0)))
	fingers += s
	knuckles += c
	claws += cl
	p.paint(fingers, IRON, z_range=(-0.6, 0.45), vary=0.05)
	p.paint(knuckles, TRIM, "MID")
	p.paint(claws, IRON, "LIGHT")
	cuff = p.cylinder(0.36, 0.0, 0.35, sides=8, radius_top=0.32, phase=math.pi / 8)
	p.transform(cuff, Matrix.Translation((0, 0.42, 0.24)) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
	p.paint(cuff, IRON, "LOW")
	band = p.cylinder(0.38, 0.0, 0.08, sides=8, phase=math.pi / 8)
	p.transform(band, Matrix.Translation((0, 0.62, 0.24)) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
	p.paint(band, TRIM, "MID")
	core = p.cylinder(0.24, 0.0, 0.06, sides=8, phase=math.pi / 8)
	p.transform(core, Matrix.Translation((0, 0.76, 0.24)) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
	p.paint(core, NEON, "MID")
	p.transform(list(p.bm.faces), Matrix.Scale(-HAND if mirror else HAND, 4, (1, 0, 0)) @ Matrix.Scale(HAND, 4, (0, 1, 0)) @ Matrix.Scale(HAND, 4, (0, 0, 1)))


piece("jefe_cuerpo", 1, jefe_cuerpo)
piece("jefe_ojo", 2, jefe_ojo)
piece("jefe_parpado", 3, jefe_parpado)
piece("jefe_parpado_inf", 3, jefe_parpado_inf)
for pose in POSES:
	for side, mirror in (("izq", False), ("der", True)):
		piece("jefe_mano_%s_%s" % (pose, side), 4, lambda p, pose=pose, mirror=mirror: hand(p, pose, mirror))

epi.layout(kit, columns=4, spacing=5.5)
epi.save("jefe")
