# Publica assets/epiphany/jefe.glb (epi.publish): el Ojo con manos, por piezas sueltas que se mueven por código (sin esqueleto),
# en sus dos formas. jefe_*: la máscara de oro de las fases 1 y 2 (sol de rayos, tumi, orejeras de neón donde nacen las
# manos y guanteletes de oro). jefe_corrupto_*: lo que queda al romperse la máscara en la fase 3, el ojo metido en un nudo
# de corteza con costillas de hueso, venas rojas y raíces, con manos de corteza y garras de hueso.
# El cuerpo flota: el origen es su centro y mira a -Y. El ojo y los párpados tienen el origen en el centro del ojo (OJO);
# las manos, en la palma (abajo plana), abiertas y con shape keys que cierran los dedos (GRIP: estirada, garra, puño y
# los pasos intermedios, para que al mezclarlas las falanges giren en vez de acortarse). La derecha es la izquierda espejada.
# blender -b -P tools/blender/build_jefe.py
import math
import os
import sys

import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

GOLD = "dorado"
JADE = "cobre_verde"
RED = "tela_roja"
NEON = "neon"
GLOW = "doom"
BARK = "roca_naranja"
WOOD = "madera_oscura"
STONE = "piedra_templo"
OJO = Vector((0.0, -1.38, 0.3))
EYE = 1.2
LID = 1.32
HAND = 1.3
MASK = 2.4
MASK_BACK = 1.0
# Cuánto mira la máscara hacia arriba (y el sol, un poco más), para que la cámara de arriba le vea la cara.
TILT = 0.55
SUN_TILT = 0.35
SUN = Vector((0.0, 0.62, 0.2))
OPEN = (0.05, 0.05, 0.08)
CLAW = (0.55, 0.65, 0.6)
FIST = (1.35, 1.45, 1.3)
# Pupila: rendija cerrada al apuntar, redonda al cargar el orbe o aturdido (Boss.pupil: -1 rendija, 0 normal, 1 dilatada).
PUPIL = {"rendija": (0.026, 0.46), "dilatada": (0.3, 0.36)}
# shape key → curvatura de cada falange; BossHand.GRIP les da el valor de grip (abierta = 0, garra = 0,5, puño = 1)
GRIP = {
	"estirada": (-0.3, -0.25, -0.1),
	"garra_media": tuple((a + b) / 2 for a, b in zip(OPEN, CLAW)),
	"garra": CLAW,
	"puno_medio": tuple((a + b) / 2 for a, b in zip(CLAW, FIST)),
	"puno": FIST,
}
# Colores de cada forma (prefijo de sus piezas): ojo, párpados y manos.
FORMS = {
	"": {"iris": NEON, "ring": GOLD, "lid": GOLD, "rim": RED, "palm": GOLD, "back": GOLD, "finger": GOLD, "knuckle": JADE, "claw": GOLD, "cuff": GOLD, "band": JADE, "core": NEON},
	"corrupto_": {"iris": GLOW, "ring": WOOD, "lid": BARK, "rim": WOOD, "palm": BARK, "back": WOOD, "finger": WOOD, "knuckle": BARK, "claw": "hueso", "cuff": WOOD, "band": "hueso", "core": GLOW},
}
kit = epi.start()


def piece(name, seed, fn, smooth=40):
	p = epi.Piece(seed)
	extra = fn(p)
	obj = p.build(name, kit, smooth=smooth)
	for key, value in (extra if isinstance(extra, dict) else {}).items():
		obj[key] = value
	return obj


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


def root(p, start, heading, length, radius, droop=0.35, steps=6):
	"""Raíz que sale de start y cae, retorcida, afinándose."""
	faces = []
	pos = Vector(start)
	d = Vector(heading).normalized()
	for k in range(steps):
		r = radius * (1.0 - 0.75 * k / steps)
		seg = p.cylinder(r, 0.0, length / steps * 1.15, sides=6, radius_top=r * 0.85)
		p.transform(seg, Matrix.Translation(pos) @ Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4())
		faces += seg
		pos = pos + d * length / steps
		d = (d + Vector((p.rng.uniform(-0.3, 0.3), p.rng.uniform(-0.3, 0.3), -droop))).normalized()
	return faces


def facing(p, faces, at):
	"""Lleva caras dibujadas en XY (z hacia el frente) a at, mirando a -Y."""
	p.transform(faces, Matrix.Translation(at) @ Matrix.Rotation(math.pi / 2, 4, "X"))


def mask_point(x, z, lift=0.0):
	"""Punto sobre la cara de la máscara (la cáscara de radio MASK corrida MASK_BACK hacia atrás)."""
	r = MASK + lift
	return Vector((x, -math.sqrt(max(r * r - x * x - z * z, 0.0)) + MASK_BACK, z))


# --- forma 1: la máscara de oro ---

def jefe_cuerpo(p):
	"""La máscara: cara de oro curva con la cuenca del ojo, alas rojas a los lados del ojo, nariz, boca, mejillas
	pintadas, orejeras con el núcleo de neón donde nacen las manos, sol de rayos y tumi con una gema arriba,
	colgantes abajo y el propulsor."""
	back = p.blob((0, 0.6, -0.2), 1.75, squash=(1.0, 0.8, 1.0), subdiv=2, rough=0.08)
	p.paint(back, GOLD, "LOW", vary=0.05)
	face, edges = shell(p, MASK, 0.14, (-0.7, 0.9), (-0.85, 0.85), steps=(12, 16))
	p.transform(face + edges, Matrix.Translation((0, MASK_BACK, 0)))
	p.paint(face, GOLD, z_range=(-2.2, 2.2), vary=0.04)
	p.paint(edges, GOLD, "LOW")
	brim, brim_e = shell(p, MASK + 0.1, 0.1, (0.82, 0.92), (-0.86, 0.86), steps=(1, 16))
	p.transform(brim + brim_e, Matrix.Translation((0, MASK_BACK, 0)))
	p.paint(brim + brim_e, JADE, "MID")
	tilt = face + edges + brim + brim_e

	socket = ring(p, EYE + 0.04, 0.2, 0.7, sides=28)
	p.transform(socket, Matrix.Translation(OJO + Vector((0, 0.15, 0))))
	p.paint(socket, GOLD, "LOW")
	lip = ring(p, EYE + 0.2, 0.1, 0.1, sides=28)
	p.transform(lip, Matrix.Translation(OJO + Vector((0, 0.05, 0))))
	p.paint(lip, RED, "MID")
	hollow = p.blob((0, 0, 0), EYE * 0.9, subdiv=2, rough=0.0)
	p.transform(hollow, Matrix.Translation(OJO + Vector((0, 0.12, 0))))
	p.paint(hollow, "noche", "DARK")

	for sx in (-1, 1):
		wing = p.polygon([(0.0, 0.08), (0.95, 0.42), (1.2, 0.18), (0.95, -0.05), (0.0, -0.12)], -0.05, 0.05)
		p.transform(wing, Matrix.Scale(sx, 4, (1, 0, 0)))
		facing(p, wing, mask_point(sx * 1.35, OJO.z + 0.1, 0.06) + Vector((-sx * 0.05, 0, 0)))
		p.paint(wing, RED, "MID")
		tilt += wing
		cheek = p.box(-0.32, 0.32, -0.22, 0.22, -0.04, 0.04)
		facing(p, cheek, mask_point(sx * 1.3, -0.95, 0.04))
		p.paint(cheek, RED, "LOW")
		tilt += cheek
		ear = p.cylinder(0.55, 0.0, 0.18, sides=20)
		inner = p.cylinder(0.3, 0.18, 0.26, sides=16)
		p.transform(ear + inner, Matrix.Translation((sx * 2.2, 0.1, -0.1)) @ Matrix.Rotation(sx * math.pi / 2, 4, "Y"))
		p.paint(ear, GOLD, "MID")
		p.paint(inner, NEON, "MID")
		for k in range(3):
			x = sx * (0.45 + 0.32 * k)
			z = -1.4 - 0.06 * (k % 2)
			top = mask_point(x, -1.25)
			chain = p.box(-0.025, 0.025, -0.025, 0.025, z + 0.1, -1.25)
			p.transform(chain, Matrix.Translation((x, top.y - 0.05, 0)))
			disc = p.cylinder(0.15, -0.03, 0.03, sides=12)
			facing(p, disc, Vector((x, top.y - 0.05, z)))
			p.paint(chain + disc, GOLD, "LIGHT")
			tilt += chain + disc
	nose = p.box(-0.22, 0.22, -0.3, 0.0, -1.15, -0.8, taper=0.08)
	p.transform(nose, Matrix.Translation((0, mask_point(0, -1.0).y, 0)))
	p.paint(nose, GOLD, "MID")
	mouth = p.box(-0.6, 0.6, -0.14, 0.0, -1.5, -1.28)
	p.transform(mouth, Matrix.Translation((0, mask_point(0, -1.4).y + 0.04, 0)))
	p.paint(mouth, "noche", "DARK")
	teeth = []
	for k in range(5):
		x = -0.44 + k * 0.22
		teeth += p.box(x - 0.07, x + 0.07, -0.18, -0.02, -1.42, -1.28)
	p.transform(teeth, Matrix.Translation((0, mask_point(0, -1.35).y + 0.04, 0)))
	p.paint(teeth, "hueso", "MID", vary=0.05)
	tilt += nose + mouth + teeth

	rays = []
	for k in range(13):
		a = math.radians(-90 + 15 * k)
		r = p.polygon([(-0.24, 0.0), (0.24, 0.0), (0.0, 1.5 if k % 2 == 0 else 1.0)], -0.06, 0.06)
		p.transform(r, Matrix.Translation(SUN) @ Matrix.Rotation(-a, 4, "Y") @ Matrix.Translation((0, 0, 2.3)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
		rays += r
	p.paint(rays, GOLD, "LIGHT", vary=0.05)
	halo = ring(p, 2.25, 0.3, 0.12, sides=40)
	p.transform(halo, Matrix.Translation(SUN))
	p.paint(halo, JADE, "LOW")
	tumi = p.polygon([(-0.7, 0.0), (0.7, 0.0), (0.92, 0.72), (0.3, 0.5), (0.0, 1.1), (-0.3, 0.5), (-0.92, 0.72)], -0.08, 0.08)
	facing(p, tumi, Vector((0, -0.5, 1.95)))
	p.paint(tumi, GOLD, "MID")
	gem = p.blob((0, -0.62, 2.42), 0.18, subdiv=2, rough=0.0)
	p.paint(gem, JADE, "LIGHT")
	sun = rays + halo
	p.transform(sun, Matrix.Translation(SUN) @ Matrix.Rotation(-TILT - SUN_TILT, 4, "X") @ Matrix.Translation(-SUN))
	tilt += tumi + gem
	p.transform(tilt, Matrix.Translation(OJO) @ Matrix.Rotation(-TILT, 4, "X") @ Matrix.Translation(-OJO))

	thruster = p.lathe([(0.0, -1.9), (0.95, -1.9), (0.85, -2.15), (0.6, -2.26), (0.0, -2.26)], sides=24)
	p.paint(thruster, GOLD, "LOW")
	vent = p.cylinder(0.45, -2.3, -2.25, sides=24)
	p.paint(vent, NEON, "MID")
	return {"centro_ojo": list(OJO)}


# --- forma 2: el ojo corrupto ---

def jefe_corrupto_cuerpo(p):
	"""El nudo: cuenca de corteza alrededor del ojo, una masa de corteza atrás, costillas de hueso que lo abrazan,
	piedras del templo incrustadas, venas rojas, musgo, nudos de doom a los lados (donde nacen las manos) y raíces que
	cuelgan."""
	bark, edges = shell(p, EYE + 0.22, 0.2, (math.pi * 0.42, math.pi * 1.58), (-math.pi / 2, math.pi / 2), steps=(12, 16))
	p.jitter(bark + edges, 0.06)
	p.paint(bark, BARK, "LOW", vary=0.08)
	p.paint(edges, WOOD, "MID")
	p.transform(bark + edges, Matrix.Translation(OJO))
	hollow = p.blob((0, 0, 0), EYE * 0.9, subdiv=2, rough=0.0)
	p.transform(hollow, Matrix.Translation(OJO + Vector((0, 0.12, 0))))
	p.paint(hollow, "noche", "DARK")
	mass = []
	for k in range(9):
		a = 2 * math.pi * k / 9
		mass += p.blob((math.cos(a) * 1.65, 0.4, OJO.z + math.sin(a) * 1.5), p.rng.uniform(0.65, 0.9), squash=(1.0, 1.2, 0.9), subdiv=2, rough=0.3)
	mass += p.blob((0, 0.7, 0.1), 1.7, subdiv=2, rough=0.2)
	p.paint(mass, WOOD, z_range=(-2.2, 2.4), vary=0.06)
	ribs = []
	for sx in (-1, 1):
		for k in range(3):
			for s in range(8):
				t = -0.9 + 1.8 * s / 7
				seg = p.cylinder(0.08, 0.0, 0.4, sides=6, radius_top=0.07)
				pos = Vector((sx * (1.8 + 0.18 * k) * math.cos(t), -0.2 + 0.32 * k, OJO.z + (1.7 - 0.14 * k) * math.sin(t)))
				d = Vector((-sx * math.sin(t), 0, math.cos(t)))
				p.transform(seg, Matrix.Translation(pos) @ Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4())
				ribs += seg
	p.paint(ribs, "hueso", "MID", vary=0.06)
	stones = []
	for k in range(5):
		s = p.box(-0.32, 0.32, -0.22, 0.22, -0.28, 0.28, taper=0.05)
		a = 0.5 + 2 * math.pi * k / 5
		p.transform(s, Matrix.Translation((math.cos(a) * 2.0, 0.1, OJO.z + math.sin(a) * 1.85)) @ Matrix.Rotation(p.rng.uniform(-0.6, 0.6), 4, "Y") @ Matrix.Rotation(p.rng.uniform(-0.6, 0.6), 4, "X"))
		stones += s
	p.paint(stones, STONE, "MID", vary=0.08)
	veins = []
	for k in range(12):
		a = 2 * math.pi * k / 12
		v = p.box(-0.04, 0.04, -0.04, 0.04, 0.0, p.rng.uniform(0.45, 0.8))
		p.transform(v, Matrix.Translation(OJO + Vector((math.cos(a) * 1.5, 0.35, math.sin(a) * 1.42))) @ Matrix.Rotation(-a + math.pi / 2, 4, "Y") @ Matrix.Rotation(-0.4, 4, "X"))
		veins += v
	p.paint(veins, GLOW, "MID")
	moss = []
	for k in range(8):
		a = -1.2 + 2.4 * k / 7
		moss += p.blob((math.sin(a) * 1.7, 0.1, OJO.z + math.cos(a) * 1.7), p.rng.uniform(0.22, 0.32), squash=(1.3, 1.0, 0.6), subdiv=1, rough=0.25)
	p.paint(moss, "musgo", "MID", vary=0.1)
	knots = []
	for sx in (-1, 1):
		knots += p.blob((sx * 2.05, 0.1, -0.1), 0.36, subdiv=2, rough=0.2)
	p.paint(knots, GLOW, "MID")
	roots = []
	for k in range(9):
		sx = -1.5 + 3.0 * k / 8
		roots += root(p, (sx, 0.3, -1.3), (sx * 0.3, 0.2, -1.0), p.rng.uniform(0.8, 1.05), 0.19, steps=7)
	p.paint(roots, WOOD, z_range=(-2.4, -1.0), vary=0.06)
	return {"centro_ojo": list(OJO)}


# --- ojo, párpados y manos de las dos formas ---

def ojo(p, form, wide=0.075, tall=0.42):
	"""El globo: hueso con un iris redondo y su aro (como los ojos de la Queñoa) y la pupila de rendija, mirando a -Y.
	wide y tall son las medias medidas de la pupila; las shape keys de PUPIL la cierran o la dilatan. El corrupto lleva
	venas rojas."""
	c = FORMS[form]

	def onto(faces, lift):
		for v in {v for f in faces for v in f.verts}:
			x, z, r = v.co.x, v.co.y, EYE + lift + v.co.z
			v.co = Vector((x, -math.sqrt(max(EYE ** 2 - x * x - z * z, 0.0)), z)).normalized() * r

	def poked(faces):
		top = faces.pop(-2)
		return faces + bmesh.ops.poke(p.bm, faces=[top])["faces"]

	def disc(radius, sides=32):
		return poked(p.polygon([(math.cos(2 * math.pi * k / sides) * radius, math.sin(2 * math.pi * k / sides) * radius) for k in range(sides)], -0.03, 0.02))

	ball = p.blob((0, 0, 0), EYE, subdiv=3, rough=0.0)
	p.paint(ball, "hueso", z_range=(-EYE, EYE))
	outer = disc(EYE * 0.47)
	onto(outer, 0.0)
	p.paint(outer, c["ring"], "LOW")
	iris = disc(EYE * 0.4)
	onto(iris, 0.012)
	p.paint(iris, c["iris"], "MID")
	inner = disc(EYE * 0.24)
	onto(inner, 0.02)
	p.paint(inner, c["iris"], "LIGHT")
	slit = []
	for i in range(9):
		t = math.pi * i / 8
		slit.append((math.sin(t) * wide, -math.cos(t) * tall))
	for i in range(1, 8):
		t = math.pi * i / 8
		slit.append((-math.sin(t) * wide, math.cos(t) * tall))
	pupil = poked(p.polygon(slit, -0.03, 0.02))
	onto(pupil, 0.055)
	p.paint(pupil, "noche", "DARK")
	if form:
		veins = []
		for k in range(10):
			a = 2 * math.pi * k / 10 + p.rng.uniform(-0.2, 0.2)
			v = p.box(-0.018, 0.018, -0.018, 0.018, 0.0, p.rng.uniform(0.25, 0.45))
			p.transform(v, Matrix.Rotation(a, 4, "Y") @ Matrix.Rotation(-math.pi / 2 + 0.95, 4, "X") @ Matrix.Translation((0, 0, EYE * 0.99)))
			veins += v
		p.paint(veins, GLOW, "DARK")


def parpado(p, form, upper=True):
	"""Párpado de arriba, cerrado: un cuarto de cáscara adelante y arriba del ojo, con el borde de otro color. Se abre
	girando en X hacia atrás; el de abajo es el mismo espejado en Z. El de oro lleva un sol de jade y, el de arriba, las
	bisagras de los costados (sobre el eje de giro) que tapan las puntas del globo; el corrupto, musgo."""
	c = FORMS[form]
	plate, edges = shell(p, LID, 0.08, (0.0, math.pi * 0.8), (-math.pi / 2, math.pi / 2), steps=(9, 14))
	p.paint(plate, c["lid"], z_range=(0, LID), vary=0.05)
	p.paint(edges, c["lid"], "DARK")
	rim, rim_edges = shell(p, LID + 0.05, 0.06, (0.0, 0.14), (-math.pi / 2, math.pi / 2), steps=(1, 14))
	p.paint(rim + rim_edges, c["rim"], "MID")
	if form:
		p.jitter(plate, 0.015)
		if upper:
			tufts = []
			for k in range(5):
				a = -1.0 + 2.0 * k / 4
				tufts += p.blob((math.sin(a) * LID, -0.3, math.cos(a) * LID * 0.95), p.rng.uniform(0.12, 0.17), squash=(1.3, 1.0, 0.6), subdiv=1, rough=0.25)
			p.paint(tufts, "musgo", "MID", vary=0.1)
	else:
		sun = p.cylinder(0.17, 0.0, 0.04, sides=12)
		for k in range(8):
			r = p.box(-0.03, 0.03, 0.21, 0.34, 0.0, 0.04)
			p.transform(r, Matrix.Rotation(2 * math.pi * k / 8, 4, "Z"))
			sun += r
		p.transform(sun, Matrix.Rotation(-0.75, 4, "X") @ Matrix.Translation((0, -LID - 0.08, 0)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
		p.paint(sun, JADE, "LIGHT")
		if upper:
			pins, rings = [], []
			for sx in (-1, 1):
				pin = p.cylinder(0.34, 0.0, 0.42, sides=18, radius_top=0.3)
				band = p.cylinder(0.37, 0.12, 0.2, sides=18)
				cap = p.cylinder(0.14, 0.42, 0.48, sides=14)
				p.transform(pin + band + cap, Matrix.Rotation(sx * math.pi / 2, 4, "Y") @ Matrix.Translation((0, 0, EYE - 0.22)))
				pins += pin
				rings += band + cap
			p.paint(pins, GOLD, "MID", vary=0.04)
			p.paint(rings, JADE, "MID")
	if not upper:
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


def hand(p, form, curl, mirror):
	"""Mano flotando, la palma (plana, abajo) en el origen y los dedos hacia -Y. El lomo lleva un ojo que brilla (dónde
	pegar cuando la mano queda aturdida); la muñeca, el núcleo que la une al cuerpo. De oro con nudillos de jade, o de
	corteza con garras de hueso y raíces en la muñeca."""
	c = FORMS[form]
	palm = p.rounded_box(-0.6, 0.6, -0.6, 0.45, 0.0, 0.42, radius=0.08, segments=1)
	p.paint(palm, c["palm"], z_range=(0, 0.45), vary=0.04)
	back = p.rounded_box(-0.5, 0.5, -0.5, 0.35, 0.42, 0.56, radius=0.05, segments=1)
	p.paint(back, c["back"], "MID" if form else "LIGHT", vary=0.06)
	glyph = epi.eye(p, Vector((0, 0, 0)), 0.26, depth=0.04, pupil_swatch="noche")
	p.transform(glyph, Matrix.Translation((0, -0.07, 0.56)) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
	p.paint(glyph, c["core"], "MID")
	fingers, knuckles, claws = [], [], []
	for i, x in enumerate((-0.43, -0.145, 0.145, 0.43)):
		base = 0.36 + (0.06 if i in (1, 2) else 0.0)
		s, k, cl = finger(p, x, (base, base * 0.82, base * 0.67), curl, width=0.09 if form else 0.11)
		fingers += s
		knuckles += k
		claws += cl
	s, k, cl = finger(p, 0.0, (0.36, 0.3), curl[:2], width=0.12, height=0.28)
	p.transform(s + k + cl, Matrix.Translation((-0.6, -0.15, 0.0)) @ Matrix.Rotation(-0.6, 4, "Z") @ Matrix.Translation((0, 0.55, 0)))
	fingers += s
	knuckles += k
	claws += cl
	p.paint(fingers, c["finger"], z_range=(-0.6, 0.45), vary=0.05)
	p.paint(knuckles, c["knuckle"], "MID")
	p.paint(claws, c["claw"], "LIGHT")
	cuff = p.cylinder(0.36, 0.0, 0.35, sides=8, radius_top=0.32, phase=math.pi / 8)
	p.transform(cuff, Matrix.Translation((0, 0.42, 0.24)) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
	p.paint(cuff, c["cuff"], "LOW")
	band = p.cylinder(0.38, 0.0, 0.08, sides=8, phase=math.pi / 8)
	p.transform(band, Matrix.Translation((0, 0.62, 0.24)) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
	p.paint(band, c["band"], "MID")
	core = p.cylinder(0.24, 0.0, 0.06, sides=8, phase=math.pi / 8)
	p.transform(core, Matrix.Translation((0, 0.76, 0.24)) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
	p.paint(core, c["core"], "MID")
	if form:
		tendrils = []
		for sx in (-0.25, 0.0, 0.25):
			tendrils += root(p, (sx, 0.7, 0.2), (sx, 1.0, -0.4), 0.7, 0.07, droop=0.5, steps=4)
		p.paint(tendrils, WOOD, "MID", vary=0.06)
	p.transform(list(p.bm.faces), Matrix.Scale(-HAND if mirror else HAND, 4, (1, 0, 0)) @ Matrix.Scale(HAND, 4, (0, 1, 0)) @ Matrix.Scale(HAND, 4, (0, 0, 1)))


def keyed(name, seed, build, keys):
	"""Pieza con shape keys: build(p, valor) arma cada pose (None la base) y keys = {nombre: valor}."""
	obj = piece(name, seed, lambda p: build(p, None))
	obj.shape_key_add(name="Basis")
	for key_name, value in keys.items():
		p = epi.Piece(seed)
		build(p, value)
		assert len(p.bm.verts) == len(obj.data.vertices), key_name
		key = obj.shape_key_add(name=key_name, from_mix=False)
		key.value = 0.0
		for i, v in enumerate(p.bm.verts):
			key.data[i].co = v.co
		p.bm.free()


piece("jefe_cuerpo", 1, jefe_cuerpo)
piece("jefe_corrupto_cuerpo", 5, jefe_corrupto_cuerpo)
for form in FORMS:
	keyed("jefe_" + form + "ojo", 2, lambda p, v, form=form: ojo(p, form, *(v or (0.075, 0.42))), PUPIL)
	piece("jefe_" + form + "parpado", 3, lambda p, form=form: parpado(p, form))
	piece("jefe_" + form + "parpado_inf", 3, lambda p, form=form: parpado(p, form, upper=False))
	for side, mirror in (("izq", False), ("der", True)):
		keyed("jefe_" + form + "mano_" + side, 4, lambda p, curl, form=form, mirror=mirror: hand(p, form, curl or OPEN, mirror), GRIP)

epi.layout(kit, columns=6, spacing=5.5)
epi.publish("jefe")
