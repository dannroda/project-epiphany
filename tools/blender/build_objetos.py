# Publica assets/epiphany/objetos.glb (epi.publish; el .blend de trabajo en art/blender/): props del overworld e interactivos (cofres, llaves, pickups, proyectiles).
# El frente mira a -Y (hacia la cámara en Godot). Origen en la base, salvo las tapas de los cofres: en la bisagra.
# blender -b -P tools/blender/build_objetos.py
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

kit = epi.start()
FRONT = Vector((0, -1, 0))


def piece(name, seed, fn, smooth=None):
	p = epi.Piece(seed)
	extra = fn(p)
	obj = p.build(name, kit, smooth=smooth)
	for key, value in (extra if isinstance(extra, dict) else {}).items():
		obj[key] = value
	return obj


# --- props ---

def cordon(p, radius, z, width=0.05):
	"""Cordón de lana roja y crema con un nudo y dos borlas adelante: la marca de lo que se levanta."""
	band = p.cylinder(radius, z - width / 2, z + width / 2, sides=14, cap_top=False, cap_bottom=False)
	p.paint(band, "tela_roja", "MID")
	stripe = p.cylinder(radius + 0.004, z - width / 6, z + width / 6, sides=14, cap_top=False, cap_bottom=False)
	p.paint(stripe, "hueso", "LIGHT")
	knot = p.blob((0, -radius - 0.02, z), 0.045, subdiv=1, rough=0.1)
	p.paint(knot, "tela_roja", "DARK")
	for side in (-1, 1):
		tassel = p.box(-0.018, 0.018, -0.018, 0.018, z - 0.13, z - 0.02, taper=0.01)
		p.transform(tassel, Matrix.Translation((side * 0.035, -radius - 0.03, 0)))
		p.paint(tassel, "hueso", "MID")


def vasija(p):
	"""Aríbalo: cuerpo panzón, cuello angosto y boca con labio, con guardas rojas, negras y crema; liso y redondo."""
	profile = [(0.1, 0.0), (0.17, 0.02), (0.23, 0.07), (0.27, 0.14), (0.29, 0.22), (0.295, 0.3), (0.28, 0.38), (0.25, 0.44), (0.2, 0.5), (0.14, 0.55), (0.105, 0.59), (0.1, 0.63), (0.12, 0.67), (0.155, 0.7), (0.14, 0.715), (0.09, 0.69), (0.0, 0.66)]
	body = p.lathe(profile, sides=20)
	p.paint_bands(body, [(0.16, 0.24, "noche", "MID"), (0.24, 0.36, "hueso", "MID"), (0.36, 0.46, "tela_roja", "MID"), (0.46, 0.52, "noche", "MID"), (0.62, 0.72, "tela_roja", "DARK")], default=(0, 0, "roca_naranja", "MID"))
	for side in (-1, 1):
		ear = p.rounded_box(-0.045, 0.045, -0.035, 0.035, 0.2, 0.3, radius=0.02)
		p.transform(ear, Matrix.Translation((side * 0.29, 0, 0)))
		p.paint(ear, "roca_naranja", "DARK")
	cordon(p, 0.115, 0.6, width=0.04)


def _surface_radius(profile, z):
	for (r0, z0), (r1, z1) in zip(profile, profile[1:]):
		if z0 <= z <= z1:
			return r0 + (r1 - r0) * (z - z0) / max(z1 - z0, 1e-6)
	return profile[-1][0]


def _burn_line(p, profile, z_of, width=0.014, steps=80):
	"""Línea quemada apenas por fuera de la calabaza, a la altura z_of(vuelta de 0 a 1)."""
	faces = []
	ring = []
	for i in range(steps + 1):
		t = i / steps
		z = z_of(t)
		r = _surface_radius(profile, z) + 0.004
		a = 2 * math.pi * t
		ring.append([p.bm.verts.new((math.cos(a) * r, math.sin(a) * r, z + dz)) for dz in (-width / 2, width / 2)])
	for (a0, a1), (b0, b1) in zip(ring, ring[1:]):
		faces.append(p.bm.faces.new((a0, b0, b1, a1)))
	return faces


def mate(p):
	"""Mate burilado de la Queñoa: calabaza seca de dos panzas, con guardas quemadas (zigzag entre dos líneas), cabito
	y el cordón."""
	profile = [(0.1, 0.0), (0.2, 0.03), (0.27, 0.1), (0.3, 0.2), (0.29, 0.3), (0.24, 0.39), (0.18, 0.45), (0.17, 0.5), (0.2, 0.56), (0.21, 0.62), (0.18, 0.68), (0.1, 0.72), (0.0, 0.73)]
	body = p.lathe(profile, sides=24)
	p.paint(body, "madera", z_range=(-0.2, 0.73), vary=0.04)
	burned = []
	for z0 in (0.16, 0.3):
		burned += _burn_line(p, profile, lambda t, z0=z0: z0)
	burned += _burn_line(p, profile, lambda t: 0.19 + 0.08 * abs((t * 12) % 1.0 - 0.5), steps=144)
	burned += _burn_line(p, profile, lambda t: 0.62, width=0.012)
	p.paint(burned, "madera_oscura", "DARK")
	stem = p.cylinder(0.025, 0.71, 0.8, sides=6, radius_top=0.018)
	p.paint(stem, "madera_oscura", "MID")
	cordon(p, 0.175, 0.48, width=0.04)


def brasero_quenoa(p):
	"""Brasero de la Queñoa, colgado de la pared: un muñón de tronco de corteza rojiza que se pela, angosto abajo, con un
	cuenco de barro y brasas arriba."""
	z = 0.82
	trunk = p.lathe([(0.0, 0.05), (0.1, 0.06), (0.18, 0.18), (0.23, 0.38), (0.25, z - 0.08), (0.29, z), (0.0, z)], sides=12)
	p.jitter(trunk, 0.015)
	p.paint(trunk, "madera_oscura", z_range=(0, z), vary=0.12)
	peel = []
	for i in range(6):
		a = 2 * math.pi * i / 6 + p.rng.random() * 0.5
		h = p.rng.uniform(0.16, 0.26)
		z0 = p.rng.uniform(0.4, z - 0.1 - h)
		strip = p.box(-0.025, 0.025, -0.006, 0.006, 0.0, h, taper=0.01)
		p.transform(strip, Matrix.Translation((math.cos(a) * 0.245, math.sin(a) * 0.245, z0)) @ Matrix.Rotation(a + math.pi / 2, 4, "Z") @ Matrix.Rotation(0.1, 4, "X"))
		peel += strip
	p.paint(peel, "madera", "MID", vary=0.06)
	bowl = p.lathe([(0.2, z), (0.27, z + 0.04), (0.36, z + 0.12), (0.42, z + 0.19), (0.44, z + 0.215), (0.42, z + 0.235), (0.38, z + 0.2), (0.0, z + 0.12)], sides=20)
	p.paint(bowl, "roca_naranja", "MID")
	coals = p.blob((0, 0, z + 0.16), 0.3, squash=(1, 1, 0.35), subdiv=2, rough=0.3)
	p.paint(coals, "fuego", "DARK", vary=0.1)


def soga(p, points, radius=0.03, sides=6):
	"""Soga que pasa por points: tramos de cilindro, con un nudo chico en cada unión."""
	faces = []
	for a, b in zip(points, points[1:]):
		a, b = Vector(a), Vector(b)
		seg = p.cylinder(radius, 0.0, (b - a).length, sides=sides)
		p.transform(seg, Matrix.Translation(a) @ (b - a).to_track_quat("Z", "Y").to_matrix().to_4x4())
		faces += seg
	return faces


## Escalera de soga (rope_ladder.tscn): ejes de Godot pasados a Blender (z de Godot = -y). Cuelga LADDER_DROP con 12
## peldaños; las sogas salen de las estacas, pasan por arriba del labio del risco (LADDER_LIP) y cuelgan a LADDER_OUT.
LADDER_DROP = 5.4
LADDER_HALF = 0.4
LADDER_LIP = 1.0
LADDER_OUT = 1.15
LADDER_RUNGS = 12


def escalera_soga(p):
	"""Lo que cuelga: dos sogas de ichu trenzado que ondulan apenas y peldaños de palo atados con una vuelta de soga."""
	rope = []
	for side in (-1, 1):
		points = [(side * LADDER_HALF, 0.2, 0.36), (side * LADDER_HALF, -0.3, 0.06), (side * LADDER_HALF, -LADDER_LIP, 0.06), (side * LADDER_HALF, -LADDER_OUT, -0.12)]
		points += [(side * LADDER_HALF + 0.02 * math.sin(k * 1.3 + side), -LADDER_OUT, -0.12 - (LADDER_DROP - 0.12) * k / 16) for k in range(1, 17)]
		rope += soga(p, points, 0.032)
	p.paint(rope, "paja", "MID", vary=0.06)
	rungs, ties = [], []
	for k in range(LADDER_RUNGS):
		z = -0.25 - k * (5.05 - 0.25) / (LADDER_RUNGS - 1)
		tilt = p.rng.uniform(-0.04, 0.04)
		rung = p.cylinder(0.035, -LADDER_HALF - 0.06, LADDER_HALF + 0.06, sides=6)
		p.transform(rung, Matrix.Translation((0, -LADDER_OUT, z)) @ Matrix.Rotation(tilt, 4, "Y") @ Matrix.Rotation(math.pi / 2, 4, "Y"))
		p.jitter(rung, 0.006)
		rungs += rung
		for side in (-1, 1):
			tie = p.cylinder(0.05, z - 0.04, z + 0.04, sides=6)
			p.transform(tie, Matrix.Translation((side * LADDER_HALF, -LADDER_OUT, 0)))
			ties += tie
	p.paint(rungs, "madera", "MID", vary=0.08)
	p.paint(ties, "paja", "DARK", vary=0.05)


def escalera_soga_estacas(p):
	"""Las dos estacas clavadas al borde, con la soga atada en varias vueltas, y unas piedras que las calzan."""
	wood, wraps = [], []
	for side in (-1, 1):
		x = side * 0.5
		stake = p.lathe([(0.075, 0.0), (0.07, 0.5), (0.06, 0.6), (0.0, 0.7)], sides=6)
		p.transform(stake, Matrix.Translation((x, 0.25, 0)) @ Matrix.Rotation(-side * 0.08, 4, "Y") @ Matrix.Rotation(0.12, 4, "X"))
		p.jitter(stake, 0.01)
		wood += stake
		for k in range(3):
			wrap = p.cylinder(0.088, 0.3 + k * 0.05, 0.34 + k * 0.05, sides=8)
			p.transform(wrap, Matrix.Translation((x + (-side * 0.08) * 0.32, 0.25 + 0.04, 0)))
			wraps += wrap
		for k in range(2):
			stone = p.blob((x + p.rng.uniform(-0.15, 0.15), 0.25 + p.rng.uniform(0.08, 0.2), 0.0), p.rng.uniform(0.08, 0.12), squash=(1.2, 1.0, 0.6), subdiv=1, rough=0.25, flat_bottom=0.0)
			p.paint(stone, "piedra", vary=0.1)
	p.paint(wood, "madera_oscura", z_range=(0.0, 0.7), vary=0.08)
	p.paint(wraps, "paja", "MID", vary=0.05)


def escalera_soga_rollo(p):
	"""La escalera enrollada al borde: un rollo acostado de vueltas de soga con las puntas de los peldaños asomando."""
	coil = []
	for k in range(5):
		x = -0.32 + k * 0.16
		ring = [(x, 0.2 + 0.2 * math.cos(a), 0.2 + 0.2 * math.sin(a)) for a in (2 * math.pi * i / 14 for i in range(15))]
		coil += soga(p, ring, 0.055, sides=6)
	p.paint(coil, "paja", z_range=(0.0, 0.42), vary=0.06)
	ends = []
	for k in range(4):
		a = 2 * math.pi * k / 4 + 0.4
		stick = p.cylinder(0.03, -0.45, 0.45, sides=6)
		p.transform(stick, Matrix.Translation((0, 0.2 + 0.17 * math.cos(a), 0.2 + 0.17 * math.sin(a))) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
		ends += stick
	p.paint(ends, "madera", "MID", vary=0.08)


def piedra_levantable(p):
	"""Piedra que se levanta: más clara y redonda que las de adorno, atada con el cordón."""
	rock = p.blob((0, 0, 0.25), 0.28, squash=(1.0, 0.95, 0.9), subdiv=3, rough=0.06, flat_bottom=0.0)
	p.paint(rock, "tierra", "LIGHT", vary=0.06)
	cordon(p, 0.292, 0.26, width=0.05)


def vasija_pedazos(p):
	shards = []
	for i in range(6):
		w, h = p.rng.uniform(0.12, 0.22), p.rng.uniform(0.1, 0.18)
		s = p.box(-w / 2, w / 2, -0.012, 0.012, 0, h, taper=0.0)
		p.jitter(s, 0.02)
		a = 2 * math.pi * i / 6 + p.rng.random()
		m = Matrix.Translation((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.012)) @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(math.pi / 2 - 0.15, 4, "X")
		p.transform(s, m)
		shards += s
	p.paint(shards, "roca_naranja", "MID", vary=0.15)


def estela(p):
	"""Tablilla: monolito trapezoidal sobre una base, con un ojo y un escalonado en relieve en la cara de adelante."""
	base = p.rounded_box(-0.55, 0.55, -0.22, 0.22, 0.0, 0.2, radius=0.06)
	slab = p.rounded_box(-0.45, 0.45, -0.09, 0.09, 0.18, 1.3, radius=0.07)
	for v in {v for f in slab for v in f.verts}:
		if v.co.z > 1.0:
			v.co.x *= 0.82
	p.paint(base, "piedra", "DARK", vary=0.1)
	p.paint(slab, "piedra", z_range=(0.0, 1.5), vary=0.06)
	relief = []
	relief += epi.eye(p, Vector((0, -0.09, 0.85)), 0.28)
	for i in range(3):
		w = 0.62 - i * 0.16
		relief += p.rounded_box(-w / 2, w / 2, -0.115, -0.08, 0.32 + i * 0.07, 0.38 + i * 0.07, radius=0.012, segments=1)
	p.paint(relief, "piedra", "LIGHT")


def apacheta(p):
	"""Pila de piedras planas que se achica hacia arriba: marca el claro del inicio."""
	stones = []
	z = 0.0
	r = 0.7
	while r > 0.12:
		for _ in range(max(1, int(r * 7))):
			a = p.rng.random() * 2 * math.pi
			d = r * p.rng.uniform(0.0, 0.7)
			size = p.rng.uniform(0.18, 0.28) * (0.6 + r)
			stones += p.blob((math.cos(a) * d, math.sin(a) * d, z + size * 0.3), size, squash=(1.2, 1.0, 0.5), subdiv=2, rough=0.1)
		z += 0.17
		r -= 0.13
	p.paint(stones, "piedra", z_range=(0, z + 0.2), vary=0.18)
	top = p.blob((0, 0, z + 0.12), 0.14, squash=(0.8, 0.8, 1.4), subdiv=2, rough=0.06)
	p.paint(top, "hueso", "MID")


def cajon(p):
	"""Caja física de 1 m: tablas con marco oscuro de cantos gastados y clavos en las esquinas."""
	core = p.box(-0.47, 0.47, -0.47, 0.47, 0.03, 0.97)
	p.paint(core, "madera", z_range=(0, 1), vary=0.08)
	frame = []
	for x in (-0.5, 0.42):
		for y in (-0.5, 0.42):
			frame += p.rounded_box(x, x + 0.08, y, y + 0.08, 0.0, 1.0, radius=0.015, segments=1)
	for z in (0.0, 0.92):
		frame += p.rounded_box(-0.5, 0.5, -0.5, -0.42, z, z + 0.08, radius=0.015, segments=1) + p.rounded_box(-0.5, 0.5, 0.42, 0.5, z, z + 0.08, radius=0.015, segments=1)
		frame += p.rounded_box(-0.5, -0.42, -0.5, 0.5, z, z + 0.08, radius=0.015, segments=1) + p.rounded_box(0.42, 0.5, -0.5, 0.5, z, z + 0.08, radius=0.015, segments=1)
	p.paint(frame, "madera_oscura", "MID", vary=0.08)
	planks = []
	for z in (0.33, 0.64):
		for facing in range(4):
			plank = p.box(-0.42, 0.42, -0.48, -0.465, z - 0.012, z + 0.012)
			p.transform(plank, Matrix.Rotation(facing * math.pi / 2, 4, "Z"))
			planks += plank
	p.paint(planks, "madera_oscura", "DARK")
	nails = []
	for x in (-0.46, 0.46):
		for z in (0.04, 0.96):
			nails += p.box(x - 0.014, x + 0.014, -0.507, -0.5, z - 0.014, z + 0.014)
	p.paint(nails, "hierro", "LIGHT")


def fogata(p):
	ring = []
	for i in range(9):
		a = 2 * math.pi * i / 9
		ring += p.blob((math.cos(a) * 0.45, math.sin(a) * 0.45, 0.06), 0.13, squash=(1.2, 1, 0.7), subdiv=2, rough=0.08)
	p.paint(ring, "piedra", vary=0.15)
	logs = []
	for i in range(4):
		a = math.pi * i / 2 + 0.4
		log = p.cylinder(0.06, 0.0, 0.55, sides=10)
		p.transform(log, Matrix.Translation((math.cos(a) * 0.22, math.sin(a) * 0.22, 0.02)) @ Matrix.Rotation(-1.0, 4, Vector((-math.sin(a), math.cos(a), 0))))
		logs += log
	p.paint(logs, "madera_oscura", "DARK", vary=0.1)
	p.paint(p.cylinder(0.25, 0.0, 0.03, sides=8), "noche", "MID")


piece("vasija", 1, vasija, smooth=50)
piece("vasija_pedazos", 2, vasija_pedazos, smooth=30)
piece("mate", 30, mate, smooth=50)
piece("brasero_quenoa", 31, brasero_quenoa, smooth=40)
piece("escalera_soga", 32, escalera_soga, smooth=40)
piece("escalera_soga_estacas", 33, escalera_soga_estacas, smooth=40)
piece("escalera_soga_rollo", 34, escalera_soga_rollo, smooth=40)
piece("estela", 3, estela, smooth=35)
piece("apacheta", 4, apacheta, smooth=60)
piece("cajon", 5, cajon, smooth=35)
piece("fogata", 6, fogata, smooth=50)


# --- cofres ---

def hollow_top(p, w, d, top, rim, swatch, inside="noche"):
	"""Borde de la boca (de top - 0.06 a top) y el fondo oscuro adentro, para que el cofre abierto se lea hueco."""
	ring = p.box(-w / 2, w / 2, -d / 2, -d / 2 + rim, top - 0.06, top) + p.box(-w / 2, w / 2, d / 2 - rim, d / 2, top - 0.06, top)
	ring += p.box(-w / 2, -w / 2 + rim, -d / 2 + rim, d / 2 - rim, top - 0.06, top) + p.box(w / 2 - rim, w / 2, -d / 2 + rim, d / 2 - rim, top - 0.06, top)
	p.paint(ring, swatch, "MID", vary=0.05)
	p.paint(p.box(-w / 2 + rim, w / 2 - rim, -d / 2 + rim, d / 2 - rim, top - 0.08, top - 0.06), inside, "LOW")


def rivets(p, points, swatch, size=0.018):
	"""Cabezas de remache que miran a -Y."""
	faces = []
	for x, y, z in points:
		head = p.blob((x, y, z), size, squash=(1, 0.6, 1), subdiv=1, rough=0.0)
		faces += head
	p.paint(faces, swatch, "LIGHT")


def chest_base(p, w, d, h, wood, metal):
	"""Cofre de tablas: canto redondeado, juntas de las tablas, esquineros y remaches de metal."""
	box = p.rounded_box(-w / 2, w / 2, -d / 2, d / 2, 0.0, h - 0.06, radius=0.025, segments=2)
	hollow_top(p, w, d, h, 0.07, wood)
	p.paint(box, wood, z_range=(0, h * 1.5), vary=0.05)
	seams = []
	for z in (h * 0.36, h * 0.68):
		seams += p.box(-w / 2 + 0.02, w / 2 - 0.02, -d / 2 - 0.004, -d / 2 + 0.01, z - 0.008, z + 0.008)
		seams += p.box(-w / 2 + 0.02, w / 2 - 0.02, d / 2 - 0.01, d / 2 + 0.004, z - 0.008, z + 0.008)
		seams += p.box(-w / 2 - 0.004, -w / 2 + 0.01, -d / 2 + 0.02, d / 2 - 0.02, z - 0.008, z + 0.008)
		seams += p.box(w / 2 - 0.01, w / 2 + 0.004, -d / 2 + 0.02, d / 2 - 0.02, z - 0.008, z + 0.008)
	p.paint(seams, "madera_oscura", "DARK")
	bands = []
	for x in (-w / 2 + 0.1, w / 2 - 0.16):
		bands += p.rounded_box(x, x + 0.06, -d / 2 - 0.02, d / 2 + 0.02, -0.01, h + 0.005, radius=0.012, segments=1)
	bands += p.rounded_box(-w / 2 - 0.02, w / 2 + 0.02, -d / 2 - 0.02, d / 2 + 0.02, 0.0, 0.07, radius=0.015, segments=1)
	for x in (-w / 2, w / 2):
		for y in (-d / 2, d / 2):
			bands += p.rounded_box(x - 0.035, x + 0.035, y - 0.035, y + 0.035, 0.0, h - 0.04, radius=0.012, segments=1)
	p.paint(bands, metal, "MID", vary=0.05)
	rivets(p, [(x + 0.03, -d / 2 - 0.022, z) for x in (-w / 2 + 0.1, w / 2 - 0.16) for z in (0.14, h - 0.12)], metal)
	epi.chakana_plate(p, Vector((0, -d / 2 - 0.02, h - 0.12)), 0.2, metal)
	p.paint(p.box(-w / 2 + 0.1, w / 2 - 0.1, -d / 2 + 0.1, d / 2 - 0.1, h - 0.07, h - 0.02), "dorado", "LIGHT", vary=0.2)


def barrel(p, x0, x1, d, h, grow=0.0, steps=10):
	"""Medio cilindro a lo largo de x, de y = -d (frente) a y = 0 (bisagra), alto h: la tapa abombada de los cofres."""
	ry, rz = d / 2 + grow, h + grow
	arc = [(-d / 2 - ry * math.cos(math.pi * i / steps), rz * math.sin(math.pi * i / steps)) for i in range(steps + 1)]
	left = [p.bm.verts.new((x0, y, z)) for y, z in arc]
	right = [p.bm.verts.new((x1, y, z)) for y, z in arc]
	faces = [p.bm.faces.new((left[i], left[i + 1], right[i + 1], right[i])) for i in range(steps)]
	faces.append(p.bm.faces.new(list(reversed(left))))
	faces.append(p.bm.faces.new(right))
	faces.append(p.bm.faces.new((left[0], right[0], right[-1], left[-1])))
	return faces


def chest_lid(p, w, d, h, wood, metal):
	"""Tapa abombada con la bisagra en el origen (arriba del borde de atrás de la base), con aros y remaches."""
	lid = barrel(p, -w / 2, w / 2, d, h)
	p.paint(lid, wood, z_range=(-h, h * 1.3), vary=0.05)
	bands = []
	for x in (-w / 2 + 0.1, w / 2 - 0.16):
		bands += barrel(p, x, x + 0.06, d, h, grow=0.015)
	for x in (-w / 2 - 0.012, w / 2 - 0.008):
		bands += barrel(p, x, x + 0.02, d, h, grow=0.008)
	p.paint(bands, metal, "MID", vary=0.05)
	rivets(p, [(x + 0.03, -d - 0.016, 0.06) for x in (-w / 2 + 0.1, w / 2 - 0.16)], metal)
	p.paint(p.box(-w / 2 + 0.07, w / 2 - 0.07, -d + 0.07, -0.07, -0.01, 0.0), "madera_oscura", "DARK")


piece("cofre", 7, lambda p: chest_base(p, 1.0, 0.7, 0.5, "madera", "cobre_verde"), smooth=35)
piece("cofre_tapa", 8, lambda p: (chest_lid(p, 1.0, 0.7, 0.3, "madera", "cobre_verde"), {"bisagra": [0.0, 0.5, -0.35]})[1], smooth=35)
def arca(p, w, d, h):
	"""Cofre grande: arca de piedra del templo, con zócalo escalonado, guardas doradas y el ojo en el frente."""
	plinth = p.rounded_box(-w / 2 - 0.06, w / 2 + 0.06, -d / 2 - 0.06, d / 2 + 0.06, 0.0, 0.1, radius=0.03, segments=2)
	body = p.rounded_box(-w / 2, w / 2, -d / 2, d / 2, 0.1, h - 0.06, radius=0.035, segments=2)
	p.paint(plinth, "piedra_templo", "DARK", vary=0.05)
	p.paint(body, "piedra_templo", z_range=(0, h * 1.4), vary=0.05)
	hollow_top(p, w + 0.04, d + 0.04, h, 0.1, "dorado")
	p.paint(p.box(-w / 2 + 0.2, w / 2 - 0.2, -d / 2 + 0.2, d / 2 - 0.2, h - 0.07, h - 0.01), "dorado", "LIGHT", vary=0.25)
	trim = []
	for x in (-w / 2 + 0.06, w / 2 - 0.14):
		trim += p.box(x, x + 0.08, -d / 2 - 0.02, -d / 2, 0.1, h - 0.08)
	p.paint(trim, "dorado", "MID")
	p.paint(epi.eye(p, Vector((0, -d / 2, h * 0.55)), 0.2, depth=0.025), "dorado", "LIGHT")


def arca_tapa(p, w, d, h):
	"""Tapa escalonada (dos gradas), con la bisagra en el origen."""
	low = p.rounded_box(-w / 2 - 0.02, w / 2 + 0.02, -d - 0.02, 0.02, 0.0, h * 0.5, radius=0.03, segments=2)
	high = p.rounded_box(-w / 2 + 0.12, w / 2 - 0.12, -d + 0.12, -0.12, h * 0.5, h, radius=0.03, segments=2)
	p.paint(low + high, "piedra_templo", z_range=(-h, h * 1.4), vary=0.05)
	p.paint(p.box(-w / 2 + 0.1, w / 2 - 0.1, -d + 0.1, -0.1, -0.01, 0.0), "piedra_templo", "DARK")
	chakana = []
	for cw, cd in ((0.36, 0.12), (0.24, 0.24), (0.12, 0.36)):
		chakana += p.box(-cw / 2, cw / 2, -d / 2 - cd / 2, -d / 2 + cd / 2, h, h + 0.03)
	p.paint(chakana, "dorado", "LIGHT")


piece("cofre_grande", 9, lambda p: arca(p, 1.4, 0.95, 0.65), smooth=35)
piece("cofre_grande_tapa", 10, lambda p: (arca_tapa(p, 1.4, 0.95, 0.35), {"bisagra": [0.0, 0.65, -0.475]})[1], smooth=35)


# --- llaves y objetos de mazmorra ---

def key(p, length, metal, boss=False):
	"""Llave acostada sobre XY, con el ojal en -X: un ojo (anillo con pupila) o, la del jefe, una chakana."""
	parts = []
	shaft = p.cylinder(0.028, -length * 0.15, length * 0.58, sides=12)
	p.transform(shaft, Matrix.Rotation(math.pi / 2, 4, "Y"))
	parts += shaft
	parts += p.rounded_box(length * 0.4, length * 0.48, -0.12, -0.02, -0.025, 0.025, radius=0.012, segments=1)
	parts += p.rounded_box(length * 0.5, length * 0.56, -0.09, -0.02, -0.025, 0.025, radius=0.012, segments=1)
	if boss:
		s = length * 0.36
		for w, h in ((s, s * 0.34), (s * 0.67, s * 0.67), (s * 0.34, s)):
			parts += p.rounded_box(-length * 0.32 - w / 2, -length * 0.32 + w / 2, -h / 2, h / 2, -0.03, 0.03, radius=0.012, segments=1)
	else:
		r = length * 0.17
		ring = p.cylinder(r, -0.03, 0.03, sides=24)
		p.transform(ring, Matrix.Translation((-length * 0.32, 0, 0)))
		parts += ring
	p.paint(parts, metal, "MID", vary=0.08)
	center = p.cylinder(length * 0.06, -0.04, 0.04, sides=16)
	p.transform(center, Matrix.Translation((-length * 0.32, 0, 0)))
	p.paint(center, "noche" if not boss else "doom", "MID")
	everything = parts + center
	p.transform(everything, Matrix.Translation((0, 0, 0.04)))


piece("llave", 11, lambda p: key(p, 0.5, "cobre_verde"), smooth=40)
piece("llave_jefe", 12, lambda p: key(p, 0.75, "dorado", boss=True), smooth=40)


def mapa(p):
	"""Tela enrollada en franjas (rojo, crema, azul) con un cordón."""
	bands = [(-0.3, -0.2, "tela_roja"), (-0.2, -0.07, "hueso"), (-0.07, 0.07, "tela_azul"), (0.07, 0.2, "hueso"), (0.2, 0.3, "tela_roja")]
	for x0, x1, swatch in bands:
		seg = p.cylinder(0.08, x0, x1, sides=18)
		p.transform(seg, Matrix.Translation((0, 0, 0.08)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
		p.paint(seg, swatch, "MID")
	cord = p.cylinder(0.088, -0.02, 0.02, sides=18)
	p.transform(cord, Matrix.Translation((0.13, 0, 0.08)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
	p.paint(cord, "paja", "DARK")


def brujula(p):
	"""Disco de piedra con una aguja de obsidiana y cuatro marcas."""
	disk = p.cylinder(0.26, 0.0, 0.08, sides=28)
	p.paint(disk, "piedra", "MID", vary=0.05)
	rim = p.cylinder(0.28, 0.0, 0.05, sides=28)
	p.paint(rim, "cobre_verde", "MID")
	marks = []
	for i in range(4):
		a = math.pi / 2 * i
		m = p.box(-0.02, 0.02, 0.17, 0.23, 0.08, 0.1)
		p.transform(m, Matrix.Rotation(a, 4, "Z"))
		marks += m
	p.paint(marks, "hueso", "LIGHT")
	needle = p.polygon([(0, 0.2), (0.04, 0), (0, -0.2), (-0.04, 0)], 0.08, 0.11)
	p.paint(needle, "noche", "MID")
	tip = p.polygon([(0, 0.2), (0.025, 0.08), (-0.025, 0.08)], 0.11, 0.115)
	p.paint(tip, "doom", "LIGHT")


piece("mapa", 13, mapa, smooth=40)
piece("brujula", 14, brujula, smooth=40)


def heart_points(size, steps=20):
	pts = []
	for i in range(steps):
		t = 2 * math.pi * i / steps
		x = 16 * math.sin(t) ** 3
		y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
		pts.append((x / 16 * size, y / 16 * size))
	return pts


def heart(p, size, thick, swatch="tela_roja", layers=6):
	"""Corazón parado y abombado (el contorno se achica hacia el frente y la espalda), mirando a -Y."""
	outline = heart_points(size, steps=36)
	rings = []
	for k in range(-layers, layers + 1):
		t = k / layers
		scale = math.sqrt(max(0.0, 1.0 - t * t)) * 0.85 + 0.15
		rings.append([p.bm.verts.new((x * scale, y * scale, t * thick / 2)) for x, y in outline])
	h = []
	n = len(outline)
	for a, b in zip(rings, rings[1:]):
		h += [p.bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i])) for i in range(n)]
	h.append(p.bm.faces.new(list(reversed(rings[0]))))
	h.append(p.bm.faces.new(rings[-1]))
	p.transform(h, Matrix.Translation((0, 0, size * 1.05)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	p.paint(h, swatch, z_range=(0, size * 2.1), vary=0.03)
	return h


def contenedor(p):
	heart(p, 0.32, 0.14)
	ring = []
	for i in range(8):
		a = 2 * math.pi * i / 8
		b = p.blob((math.cos(a) * 0.42, 0, 0.36 + math.sin(a) * 0.42), 0.045, subdiv=2, rough=0.0)
		ring += b
	p.paint(ring, "dorado", "LIGHT")


piece("corazon", 15, lambda p: heart(p, 0.2, 0.1), smooth=70)
piece("contenedor_corazon", 16, contenedor, smooth=70)


# --- proyectiles y municiones ---

def arrow(p, length=0.9):
	"""Flecha a lo largo de +X: caña, punta de obsidiana y plumas."""
	shaft = p.cylinder(0.013, 0.0, length * 0.86, sides=6)
	p.transform(shaft, Matrix.Rotation(math.pi / 2, 4, "Y"))
	p.paint(shaft, "madera", "MID")
	head = p.polygon([(length * 0.86, 0.045), (length, 0.0), (length * 0.86, -0.045)], -0.012, 0.012)
	p.paint(head, "noche", "LIGHT")
	feathers = []
	for z in (-1, 1):
		feathers += p.polygon([(0.0, 0.0), (0.14, 0.0), (0.04, 0.06 * z)], -0.004, 0.004)
	p.paint(feathers, "tela_roja", "MID")
	return shaft + head + feathers


def flecha(p):
	arrow(p)


def flechas_x5(p):
	for i in range(5):
		q = epi.Piece(i)
		f = arrow(q, 0.7)
		q.transform(list(q.bm.faces), Matrix.Translation((-0.35, (i - 2) * 0.035, 0.05 + (i % 2) * 0.03)) @ Matrix.Rotation((i - 2) * 0.06, 4, "Z"))
		p.merge(q)
	tie = p.box(-0.03, 0.03, -0.1, 0.1, 0.02, 0.12)
	p.paint(tie, "paja", "DARK")


def bomb(p, radius=0.22):
	"""Cántaro de barro redondo con boca corta y mecha de cordel."""
	body = p.lathe([(0.0, 0.0), (radius * 0.7, radius * 0.1), (radius, radius * 0.9), (radius * 0.8, radius * 1.6), (radius * 0.35, radius * 1.9), (radius * 0.35, radius * 2.05), (0.0, radius * 2.05)], sides=20)
	p.paint_bands(body, [(radius * 1.05, radius * 1.25, "noche", "MID")], default=(0, 0, "roca_naranja", "DARK"))
	fuse = p.cylinder(0.02, radius * 2.0, radius * 2.0 + 0.16, sides=6, radius_top=0.015)
	p.transform(fuse, Matrix.Rotation(0.3, 4, "X"))
	p.paint(fuse, "paja", "MID")


def bombas_x3(p):
	for i, (x, y) in enumerate(((-0.15, 0.0), (0.15, 0.02), (0.0, 0.2))):
		q = epi.Piece(i)
		bomb(q, 0.13)
		q.transform(list(q.bm.faces), Matrix.Translation((x, y, 0)))
		p.merge(q)


def orbe(p):
	core = p.blob((0, 0, 0), 0.22, subdiv=3, rough=0.0)
	p.paint(core, "doom", "MID")
	shell = []
	for i in range(6):
		a = 2 * math.pi * i / 6
		s = p.polygon([(0, 0.0), (0.08, 0.02), (0.0, 0.16)], -0.01, 0.01)
		p.transform(s, Matrix.Rotation(a, 4, "Y") @ Matrix.Translation((0, 0, 0.18)))
		shell += s
	p.paint(shell, "sello", "LIGHT")


def explosion(p):
	"""Bola de fuego de radio 1: núcleo facetado y puntas en cono hacia todos lados, clara al centro y naranja en las
	puntas (la agranda y desvanece src/items/bomb/explosion.gd)."""
	core = p.blob((0, 0, 0), 0.62, subdiv=1, rough=0.15)
	p.paint(core, "fuego", "LIGHT", vary=0.05)
	golden = math.pi * (3 - math.sqrt(5))
	count = 14
	for i in range(count):
		z = 1 - 2 * (i + 0.5) / count
		r = math.sqrt(1 - z * z)
		direction = Vector((math.cos(golden * i) * r, math.sin(golden * i) * r, z * 0.8)).normalized()
		length = p.rng.uniform(0.75, 1.0)
		spike = p.cylinder(0.26, 0.3, length, sides=4, radius_top=0.0, phase=p.rng.random())
		p.paint(spike, "fuego", z_range=(length, 0.3), vary=0.06)
		p.transform(spike, direction.to_track_quat("Z", "Y").to_matrix().to_4x4())


piece("flecha", 17, flecha, smooth=40)
piece("flechas_x5", 18, flechas_x5, smooth=40)
piece("bomba", 19, lambda p: bomb(p), smooth=50)
piece("bombas_x3", 20, bombas_x3, smooth=50)
piece("orbe", 21, orbe, smooth=40)
piece("explosion", 22, explosion)
piece("piedra_levantable", 23, piedra_levantable, smooth=70)


def bloque_empujable(p):
	"""Cubo de 1.8 m de piedra labrada con los cantos redondeados y la chakana tallada en cada lado."""
	body = p.rounded_box(-0.9, 0.9, -0.9, 0.9, 0.0, 1.8, radius=0.14, segments=2)
	p.paint(body, "acantilado", z_range=(-0.4, 2.4), vary=0.04)
	relief = []
	for k in range(4):
		faces = []
		for w, h in ((0.9, 0.3), (0.6, 0.6), (0.3, 0.9)):
			faces += p.rounded_box(-w / 2, w / 2, -0.94, -0.88, 0.9 - h / 2, 0.9 + h / 2, radius=0.02, segments=1)
		p.transform(faces, Matrix.Rotation(math.pi / 2 * k, 4, "Z"))
		relief += faces
	p.paint(relief, "madera_oscura", "MID", vary=0.03)


def interruptor_marco(p):
	"""Marco de 1.9 m al ras del piso; la placa va aparte."""
	ring = []
	for x0, x1, y0, y1 in ((-0.95, 0.95, -0.95, -0.72), (-0.95, 0.95, 0.72, 0.95), (-0.95, -0.72, -0.72, 0.72), (0.72, 0.95, -0.72, 0.72)):
		ring += p.rounded_box(x0, x1, y0, y1, -0.02, 0.07, radius=0.03, segments=1)
	p.paint(ring, "acantilado", "DARK", vary=0.05)
	pit = p.box(-0.72, 0.72, -0.72, 0.72, -0.1, -0.05)
	p.paint(pit, "noche", "MID")


def interruptor_placa(p):
	plate = p.rounded_box(-0.68, 0.68, -0.68, 0.68, 0.0, 0.1, radius=0.04, segments=1)
	p.paint(plate, "madera", "MID", vary=0.03)
	glyph = epi.eye(p, Vector((0, 0, 0)), 0.38, depth=0.02)
	p.transform(glyph, Matrix.Translation((0, 0, 0.1)) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
	p.paint(glyph, "dorado", "MID")


def interruptor_peso_marco(p):
	"""Marco de la placa de peso (floor_switch_weight.tscn): más ancho y alto que el del que se pisa, de bloques de piedra
	con cuatro mojones en las esquinas, para que se lea que ahí va algo pesado y no el player."""
	ring = []
	for x0, x1, y0, y1 in ((-1.05, 1.05, -1.05, -0.72), (-1.05, 1.05, 0.72, 1.05), (-1.05, -0.72, -0.72, 0.72), (0.72, 1.05, -0.72, 0.72)):
		ring += p.rounded_box(x0, x1, y0, y1, -0.02, 0.16, radius=0.04, segments=1)
	p.jitter(ring, 0.01)
	p.paint(ring, "acantilado", "DARK", vary=0.05)
	posts, caps = [], []
	for sx in (-1, 1):
		for sy in (-1, 1):
			posts += p.rounded_box(sx * 0.88 - 0.17, sx * 0.88 + 0.17, sy * 0.88 - 0.17, sy * 0.88 + 0.17, 0.0, 0.34, radius=0.05, segments=2)
			caps += p.rounded_box(sx * 0.88 - 0.12, sx * 0.88 + 0.12, sy * 0.88 - 0.12, sy * 0.88 + 0.12, 0.34, 0.39, radius=0.02, segments=1)
	p.paint(posts, "acantilado", "MID", vary=0.05)
	p.paint(caps, "cobre_verde", "MID", vary=0.04)
	p.paint(p.box(-0.72, 0.72, -0.72, 0.72, -0.1, -0.05), "noche", "MID")


def interruptor_peso_placa(p):
	"""Losa de piedra con un aríbalo tallado: ahí se apoya una vasija (o lo que pese)."""
	p.paint(p.rounded_box(-0.68, 0.68, -0.68, 0.68, 0.0, 0.12, radius=0.04, segments=1), "piedra", "MID", vary=0.04)
	outline = [(0.0, -0.42), (0.1, -0.33), (0.22, -0.15), (0.27, 0.02), (0.24, 0.17), (0.12, 0.26), (0.08, 0.36), (0.16, 0.42)]
	points = outline + [(-x, y) for x, y in reversed(outline)]
	pot = p.polygon(points, 0.12, 0.15)
	p.paint(pot, "roca_naranja", "MID", vary=0.04)
	band = p.box(-0.22, 0.22, -0.015, 0.015, 0.15, 0.16)
	p.transform(band, Matrix.Translation((0, 0.12, 0)))
	p.paint(band, "noche", "MID")


piece("bloque_empujable", 24, bloque_empujable, smooth=40)
piece("interruptor_marco", 25, interruptor_marco, smooth=40)
piece("interruptor_placa", 26, interruptor_placa, smooth=40)
piece("interruptor_peso_marco", 35, interruptor_peso_marco, smooth=40)
piece("interruptor_peso_placa", 36, interruptor_peso_placa, smooth=40)

epi.layout(kit, columns=6, spacing=2.0)
epi.publish("objetos")
