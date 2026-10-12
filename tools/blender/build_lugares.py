# Publica assets/epiphany/lugares.glb (epi.publish; el .blend de trabajo en art/blender/): piezas de los lugares del overworld (cueva, santuario, puzzle de luz, templo por fuera)
# y los mecanismos que comparten overworld y templo (reja, bloque, interruptores, puente, portal).
# El frente mira a -Y. Las piezas de celda van de -1 a 1 en X e Y; las demás, con el origen en la base.
# blender -b -P tools/blender/build_lugares.py
import math
import os
import sys

import bmesh
from mathutils import Matrix, Vector, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

TOP = 2.6
kit = epi.start()


def piece(name, seed, fn):
	p = epi.Piece(seed)
	extra = fn(p)
	obj = p.build(name, kit)
	for key, value in (extra if isinstance(extra, dict) else {}).items():
		obj[key] = value
	return obj


def rock(p, x0, x1, y0, y1, z0, z1, push=0.14, cuts=2, swatch="acantilado", keep_top=True, z_range=None):
	"""Bloque de roca natural: caja subdividida con las caras de los costados empujadas hacia afuera con ruido."""
	before = set(p.bm.faces)
	faces = p.box(x0, x1, y0, y1, z0, z1)
	bmesh.ops.subdivide_edges(p.bm, edges=list({e for f in faces for e in f.edges}), cuts=cuts, use_grid_fill=True)
	new = [f for f in p.bm.faces if f not in before]
	verts = {v for f in new for v in f.verts}
	off = Vector((p.rng.random() * 40, p.rng.random() * 40, p.rng.random() * 40))
	for v in verts:
		if keep_top and v.co.z > z1 - 1e-4:
			continue
		if v.co.z < z0 + 1e-4:
			continue
		out = Vector((1 if v.co.x > x1 - 1e-4 else -1 if v.co.x < x0 + 1e-4 else 0, 1 if v.co.y > y1 - 1e-4 else -1 if v.co.y < y0 + 1e-4 else 0, 0))
		if out.length:
			v.co += out.normalized() * push * (0.3 + 0.7 * (0.5 + 0.5 * noise.noise(v.co * 1.8 + off)))
			v.co.z += (p.rng.random() - 0.5) * push * 0.6
	bmesh.ops.triangulate(p.bm, faces=new)
	new = [f for f in p.bm.faces if f not in before]
	p.paint(new, swatch, z_range=z_range or (z0, z1), vary=0.1)
	return new


def ground_tile(p, swatch="pasto", shade="MID"):
	faces = p.box(-1, 1, -1, 1, -0.5, 0)
	p.paint([f for f in faces if f.normal.z <= 0.5], "tierra", z_range=(-0.5, 0.0))
	p.paint([f for f in faces if f.normal.z > 0.5], swatch, shade)


# --- cueva ---

def cueva_boca(p):
	"""Celda de risco con la boca trapezoidal hacia -Y; adentro, oscuro."""
	inner = p.box(-0.75, 0.75, -0.7, 1.0, -0.1, 2.0)
	p.paint(inner, "noche", "DARK")
	floor = p.box(-0.75, 0.75, -1.0, 1.0, -0.5, 0.0)
	p.paint(floor, "gris_4", "MID")
	for x0, x1 in ((-1.0, -0.62), (0.62, 1.0)):
		jamb = rock(p, x0, x1, -1.0, 1.0, -0.5, TOP - 0.15, push=0.1)
		for v in {v for f in jamb for v in f.verts}:
			if v.co.z > 1.5 and abs(v.co.x) < 0.7:
				v.co.x *= 0.7
	rock(p, -0.62, 0.62, -1.0, 1.0, 1.95, TOP - 0.15, push=0.1, cuts=1)
	epi.grass_cap(p, TOP - 0.15, TOP)


def cueva_pared(p):
	faces = rock(p, -1, 1, -1, 1, -0.5, TOP, push=0.16, swatch="gris_4", keep_top=True, z_range=(-1.5, TOP + 1.0))
	bmesh.ops.delete(p.bm, geom=[f for f in faces if min(v.co.z for v in f.verts) > TOP - 1e-4], context="FACES")
	top = p.box(-1, 1, -1, 1, TOP - 0.01, TOP)
	p.paint(top, "noche", "MID")


def cueva_piso(p):
	ground_tile(p, "gris_4", "MID")
	for _ in range(4):
		x, y = p.rng.uniform(-0.8, 0.8), p.rng.uniform(-0.8, 0.8)
		p.paint(p.blob((x, y, 0), p.rng.uniform(0.08, 0.15), squash=(1.3, 1, 0.5), subdiv=1, rough=0.3, flat_bottom=0.0), "gris_2", vary=0.1)


def estalagmitas(p):
	cones = []
	for i in range(4):
		a = 2 * math.pi * i / 4 + p.rng.random()
		d = 0.0 if i == 0 else 0.3
		h = 1.4 if i == 0 else p.rng.uniform(0.5, 0.9)
		c = p.cylinder(0.25 if i == 0 else 0.14, 0.0, h, sides=6, radius_top=0.02, phase=p.rng.random())
		p.transform(c, Matrix.Translation((math.cos(a) * d, math.sin(a) * d, 0)))
		p.jitter(c, 0.03)
		cones += c
	p.paint(cones, "gris_2", z_range=(0, 1.6), vary=0.08)


piece("cueva_boca", 1, cueva_boca)
piece("cueva_pared", 2, cueva_pared)
piece("cueva_piso", 3, cueva_piso)
piece("estalagmitas", 4, estalagmitas)


# --- vertiente: la sala de la cueva con el ojo de agua ---

def vertiente_pico(p):
	"""Piedra que asoma del muro con la canaleta de donde cae el agua; el origen es el borde de la canaleta, el muro en
	y = 0.7 y el agua sale hacia -Y."""
	chunk = []
	chunk += rock(p, -0.32, 0.32, -0.05, 0.7, -0.55, 0.0, push=0.12, cuts=2, swatch="gris_2", keep_top=True, z_range=(-0.8, 0.4))
	for x0, x1 in ((-0.9, -0.26), (0.26, 0.9)):
		chunk += rock(p, x0, x1, 0.0, 0.7, -0.7, p.rng.uniform(0.2, 0.4), push=0.14, cuts=2, swatch="gris_2", keep_top=False, z_range=(-0.8, 0.4))
	for v in {v for f in chunk for v in f.verts}:
		t = min(1.0, max(0.0, (v.co.z + 0.7) / 0.7))
		v.co.y = 0.7 + (v.co.y - 0.7) * (0.35 + 0.65 * t)
		v.co.x *= 0.7 + 0.3 * t
	channel = p.box(-0.2, 0.2, 0.0, 0.7, 0.0, 0.02)
	p.paint(channel, "agua", "LIGHT")
	moss = []
	for x in (-0.28, 0.28):
		moss += p.blob((x, 0.05, 0.02), 0.13, squash=(1.0, 1.5, 0.35), rough=0.3)
	p.paint(moss, "musgo", vary=0.1)


def orilla_piedras(p):
	"""Tramo de 2 m de lajas chatas con musgo para el borde de una pileta; el agua del lado -Y."""
	stones, moss = [], []
	x = -1.0
	while x < 1.0:
		w = p.rng.uniform(0.3, 0.5)
		cx = min(x + w / 2, 1.0 - w / 2)
		stones += p.blob((cx, p.rng.uniform(-0.05, 0.08), 0.0), w / 2, squash=(1.0, 0.8, 0.35), rough=0.25, flat_bottom=-0.04)
		if p.rng.random() < 0.4:
			moss += p.blob((cx + p.rng.uniform(-0.08, 0.08), 0.06, 0.07), w / 4, squash=(1.0, 0.8, 0.25), rough=0.3)
		x += w * 0.85
	p.paint(stones, "gris_2", z_range=(-0.04, 0.12), vary=0.1)
	p.paint(moss, "musgo", vary=0.1)


def cristales_cueva(p):
	"""Racimo de cristales celestes que brillan solos, sobre una base de roca."""
	base = p.blob((0, 0, 0), 0.3, squash=(1.2, 1.0, 0.45), rough=0.3, flat_bottom=0.0)
	p.paint(base, "gris_4", vary=0.1)
	shards = []
	for i in range(5):
		a = 2 * math.pi * i / 5 + p.rng.random() * 0.6
		d = 0.0 if i == 0 else p.rng.uniform(0.12, 0.22)
		h = 0.9 if i == 0 else p.rng.uniform(0.35, 0.6)
		shards += crystal(p, (math.cos(a) * d, math.sin(a) * d, 0.05), h, 0.09 if i == 0 else 0.06, tilt=0.0 if i == 0 else p.rng.uniform(0.25, 0.5), turn=a + math.pi / 2)
	p.paint(shards, "neon", z_range=(0, 0.9))


def rocas_rincon(p):
	"""Montón de rocas para el rincón de una sala: el rincón en (1, 1), crece hacia -X y -Y."""
	faces = []
	for cx, cy, r, h in ((0.55, 0.55, 0.75, 1.5), (-0.35, 0.65, 0.5, 0.9), (0.65, -0.35, 0.5, 0.8), (-0.05, -0.05, 0.35, 0.45)):
		faces += p.blob((cx, cy, 0.0), r, squash=(1.0, 1.0, h / r), rough=0.25, flat_bottom=0.0)
	p.paint(faces, "gris_2", z_range=(-0.6, 1.5), vary=0.1)


def estalactitas_borde(p):
	"""Tramo de 2 m de estalactitas colgando del borde de arriba de un muro de cueva (el muro hacia +Y)."""
	cones = []
	x = -0.9
	while x < 0.9:
		h = p.rng.uniform(0.25, 0.7)
		r = p.rng.uniform(0.06, 0.13)
		c = p.cylinder(r * 0.15, TOP - h, TOP, sides=5, radius_top=r, center=(x, p.rng.uniform(-0.1, 0.05)), phase=p.rng.random())
		p.jitter(c, 0.015)
		cones += c
		x += p.rng.uniform(0.18, 0.35)
	p.paint(cones, "gris_4", z_range=(TOP - 0.7, TOP), vary=0.08)




# --- muros agrietados: la celda de muro de cada lugar con grietas en las dos caras; solo las grietas la delatan ---

CAP = 0.15


def muro_agrietado(p):
	"""Celda de andén del overworld (como la del kit) con grietas adelante y atrás."""
	epi.stone_wall(p, -0.5, TOP - CAP)
	epi.grass_cap(p, TOP - CAP, TOP)
	epi.cracks_both_faces(p, 1.09, (0.0, 1.2), 0.92, 0.05, TOP - CAP - 0.05, "acantilado", "tierra")


def muro_agrietado_risco(p):
	"""Celda de risco (roca natural) con grietas adelante y atrás."""
	rock(p, -1, 1, -1, 1, -0.5, TOP - CAP, push=0.06, cuts=3, z_range=(-0.5, TOP - CAP))
	epi.grass_cap(p, TOP - CAP, TOP)
	epi.cracks_both_faces(p, 1.1, (0.0, 1.2), 0.92, 0.05, TOP - CAP - 0.05, "acantilado", "tierra")


def muro_agrietado_templo(p):
	"""Tapón de piedra del templo para la abertura de un paso de puerta (1.8 × 2.3, 2 de fondo), con grietas."""
	epi.stone_wall(p, -0.5, 2.3, swatch="piedra_templo", rows=(0.45, 0.12), widths=(0.6, 0.4), mortar="gris_5", depth=0.05, vary=0.07, size=(0.9, 1.0), sides=[Vector((0, -1, 0)), Vector((0, 1, 0))])
	epi.cracks_both_faces(p, 1.06, (0.0, 1.15), 0.86, 0.05, 2.25, "piedra_templo", "piedra_templo")


def escombro(p, n):
	chunks = []
	for _ in range(n):
		x, y = p.rng.uniform(-0.5, 0.5), p.rng.uniform(-0.4, 0.4)
		s = p.rng.uniform(0.14, 0.26)
		c = p.box(x - s, x + s, y - s * 0.8, y + s * 0.8, 0.0, s * 1.2, taper=0.03)
		p.jitter(c, 0.04)
		chunks += c
	p.paint(chunks, "ladrillo", vary=0.15)


piece("muro_agrietado", 5, muro_agrietado)
piece("muro_agrietado_risco", 27, muro_agrietado_risco)
piece("muro_agrietado_templo", 28, muro_agrietado_templo)
piece("escombro_a", 6, lambda p: escombro(p, 4))
piece("escombro_b", 7, lambda p: escombro(p, 2))


# --- santuario ---

def santuario_piso(p):
	base = p.box(-1, 1, -1, 1, -0.5, -0.03)
	p.paint(base, "gris_5", "MID")
	slabs = []
	for x in (-1, 0):
		for y in (-1, 0):
			s = p.box(x + 0.03, x + 0.97, y + 0.03, y + 0.97, -0.05, 0.0, taper=0.015)
			slabs += s
	p.paint(slabs, "piedra_templo", "MID", vary=0.08)


def santuario_pared(p):
	epi.stone_wall(p, -0.5, TOP, swatch="piedra_templo", rows=(0.42, 0.1), widths=(0.6, 0.35), mortar="gris_5", depth=0.05, vary=0.08)
	cap = p.box(-1.0, 1.0, -1.0, 1.0, TOP, TOP + 0.12, taper=0.04)
	p.paint(cap, "piedra_templo", "LIGHT")


def pedestal(p):
	"""Altar escalonado de 1.4 m para el cofre grande."""
	steps = []
	for i, w in enumerate((1.4, 1.1, 0.8)):
		steps += p.box(-w / 2, w / 2, -w / 2, w / 2, i * 0.18, (i + 1) * 0.18)
	p.paint(steps, "piedra_templo", z_range=(0, 0.6), vary=0.06)
	trim = p.box(-0.42, 0.42, -0.42, 0.42, 0.54, 0.56)
	p.paint(trim, "dorado", "MID")


piece("santuario_piso", 8, santuario_piso)
piece("santuario_pared", 9, santuario_pared)
piece("pedestal", 10, pedestal)


# --- puzzle de luz ---

def stepped_base(p, w, steps=2, h=0.18, swatch="piedra_templo"):
	faces = []
	for i in range(steps):
		s = w - i * 0.2
		faces += p.box(-s / 2, s / 2, -s / 2, s / 2, i * h, (i + 1) * h)
	p.paint(faces, swatch, z_range=(0, steps * h), vary=0.06)
	return steps * h


def crystal(p, center, height, radius, tilt=0.0, turn=0.0):
	"""Prisma de seis caras con las dos puntas afiladas."""
	c = p.lathe([(0.0, 0.0), (radius, height * 0.2), (radius, height * 0.75), (0.0, height)], sides=6)
	p.transform(c, Matrix.Translation(center) @ Matrix.Rotation(turn, 4, "Z") @ Matrix.Rotation(tilt, 4, "X"))
	return c


def fuente_luz(p):
	"""Fuente del haz: base escalonada, aro de cobre y un cristal de sol."""
	z = stepped_base(p, 0.9)
	post = p.box(-0.15, 0.15, -0.15, 0.15, z, z + 0.55, taper=0.03)
	p.paint(post, "piedra_templo", vary=0.05)
	ring = p.lathe([(0.3, -0.04), (0.34, 0.0), (0.3, 0.04), (0.24, 0.0), (0.3, -0.04)], sides=12, caps=False)
	p.transform(ring, Matrix.Translation((0, 0, z + 0.9)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	p.paint(ring, "cobre_verde", "MID")
	p.paint(crystal(p, Vector((0, 0, z + 0.62)), 0.56, 0.16), "fuego", vary=0.08)


def espejo_fijo(p):
	"""Espejo de bronce en un soporte de piedra; el disco mira a -Y (el giro se pone en la escena)."""
	z = stepped_base(p, 0.8)
	for x in (-0.5, 0.42):
		post = p.box(x, x + 0.08, -0.08, 0.08, z, z + 1.2)
		p.paint(post, "piedra_templo", vary=0.05)
	disk = p.cylinder(0.42, 0.0, 0.04, sides=14)
	p.transform(disk, Matrix.Translation((0, 0, z + 0.85)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	p.paint(disk, "cristal", "LIGHT")
	rim = p.lathe([(0.42, -0.06), (0.48, -0.04), (0.48, 0.05), (0.42, 0.05), (0.42, -0.06)], sides=14, caps=False)
	p.transform(rim, Matrix.Translation((0, 0, z + 0.85)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	p.paint(rim, "dorado", "MID")


def cristal_receptor(p):
	stepped_base(p, 0.9)


def cristal_receptor_cristales(p):
	"""Los cristales del receptor, aparte de la base para que el juego los ilumine."""
	z = 0.36
	shards = crystal(p, Vector((0, 0, z)), 1.0, 0.16)
	for i in range(4):
		a = math.pi / 2 * i + 0.4
		shards += crystal(p, Vector((math.cos(a) * 0.14, math.sin(a) * 0.14, z)), 0.5 + p.rng.random() * 0.2, 0.09, tilt=0.45, turn=a + math.pi / 2)
	p.paint(shards, "cristal", z_range=(z, z + 1.0), vary=0.08)


piece("fuente_luz", 11, fuente_luz)
piece("espejo_fijo", 12, espejo_fijo)
piece("cristal_receptor", 13, cristal_receptor)
piece("cristal_receptor_cristales", 27, cristal_receptor_cristales)


# --- mecanismos ---

def reja(p):
	"""2.4 × 2.2 × 0.3: barrotes de cobre verde con travesaños y un remate escalonado. Baja hacia el piso."""
	bars = []
	for i in range(7):
		x = -1.05 + i * 0.35
		bars += p.box(x - 0.05, x + 0.05, -0.05, 0.05, 0.0, 2.05)
	rails = p.box(-1.2, 1.2, -0.08, 0.08, 0.35, 0.47) + p.box(-1.2, 1.2, -0.08, 0.08, 1.7, 1.82)
	crest = []
	for w, z in ((2.4, 2.05), (1.4, 2.13), (0.6, 2.2)):
		crest += p.box(-w / 2, w / 2, -0.1, 0.1, z - 0.08, z + 0.05)
	p.paint(bars, "cobre_verde", z_range=(0, 2.2), vary=0.05)
	p.paint(rails + crest, "cobre_verde", "DARK", vary=0.05)


def bloque_empujable(p):
	"""Cubo de 1.8 m de piedra labrada con la chakana en relieve en cada lado."""
	body = p.box(-0.9, 0.9, -0.9, 0.9, 0.0, 1.75)
	p.paint(body, "piedra", z_range=(0, 2.2), vary=0.05)
	top = p.box(-0.86, 0.86, -0.86, 0.86, 1.75, 1.8, taper=0.04)
	p.paint(top, "piedra", "LIGHT")
	relief = []
	for k in range(4):
		faces = []
		for w, h in ((0.9, 0.3), (0.6, 0.6), (0.3, 0.9)):
			faces += p.box(-w / 2, w / 2, -0.94, -0.9, 0.9 - h / 2, 0.9 + h / 2)
		p.transform(faces, Matrix.Rotation(math.pi / 2 * k, 4, "Z"))
		relief += faces
	p.paint(relief, "piedra", "DARK", vary=0.03)


def interruptor_marco(p):
	"""Marco de 1.9 m al ras del piso; la placa va aparte."""
	ring = []
	for x0, x1, y0, y1 in ((-0.95, 0.95, -0.95, -0.72), (-0.95, 0.95, 0.72, 0.95), (-0.95, -0.72, -0.72, 0.72), (0.72, 0.95, -0.72, 0.72)):
		ring += p.box(x0, x1, y0, y1, -0.02, 0.06)
	p.paint(ring, "piedra_templo", "MID", vary=0.05)
	pit = p.box(-0.72, 0.72, -0.72, 0.72, -0.1, -0.05)
	p.paint(pit, "noche", "MID")


def interruptor_placa(p):
	plate = p.box(-0.7, 0.7, -0.7, 0.7, 0.0, 0.1, taper=0.03)
	p.paint(plate, "cobre_verde", "MID", vary=0.03)
	glyph = epi.eye(p, Vector((0, 0, 0)), 0.38, depth=0.02)
	p.transform(glyph, Matrix.Translation((0, 0, 0.1)) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
	p.paint(glyph, "cobre_verde", "LIGHT")


def ojo_pilar(p):
	"""Pilar de 0.7 × 1.3 × 0.5 con la cuenca adelante, a 0.95 m; el globo va aparte."""
	body = p.box(-0.35, 0.35, -0.25, 0.25, 0.0, 1.2)
	p.paint(body, "piedra_templo", z_range=(0, 1.6), vary=0.05)
	cap = p.box(-0.4, 0.4, -0.3, 0.3, 1.2, 1.32, taper=0.03)
	p.paint(cap, "piedra_templo", "LIGHT")
	socket = p.lathe([(0.3, 0.0), (0.3, 0.05), (0.24, 0.05), (0.24, 0.0)], sides=12, caps=False)
	p.transform(socket, Matrix.Translation((0, -0.25, 0.95)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	p.paint(socket, "dorado", "MID")
	hole = p.cylinder(0.24, 0.0, 0.02, sides=12)
	p.transform(hole, Matrix.Translation((0, -0.24, 0.95)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	p.paint(hole, "noche", "MID")
	return {"centro_ojo": [0.0, 0.95, 0.25]}


def ojo_globo(p):
	"""Globo de 0.24 de radio con el iris violeta y la pupila hacia -Y."""
	ball = p.blob((0, 0, 0), 0.24, subdiv=2, rough=0.0)
	white, iris, pupil = [], [], []
	for f in ball:
		c = f.calc_center_median().normalized()
		(pupil if c.y < -0.93 else iris if c.y < -0.72 else white).append(f)
	p.paint(white, "hueso", "LIGHT")
	p.paint(iris, "sello", "MID")
	p.paint(pupil, "noche", "MID")


def puente(p):
	"""Puente de soga (queswachaca): piso tejido de paja de 2 × 4 m a lo largo de Y, barandas de soga y postes."""
	floor = []
	for i in range(16):
		y = -2.0 + i * 0.25
		floor += p.box(-0.95, 0.95, y + 0.01, y + 0.24, -0.12, 0.0)
	p.paint(floor, "paja", "MID", vary=0.12)
	under = p.box(-0.9, 0.9, -2.0, 2.0, -0.2, -0.12)
	p.paint(under, "paja", "DARK")
	for x in (-0.95, 0.95):
		for y in (-1.95, 1.95):
			post = p.box(x - 0.08, x + 0.08, y - 0.08, y + 0.08, -0.3, 1.05, taper=0.02)
			p.paint(post, "madera_oscura", vary=0.08)
		segs = []
		for k in range(8):
			y0 = -1.95 + k * 0.4875
			sag0 = 0.95 - 0.25 * math.sin(math.pi * k / 8)
			sag1 = 0.95 - 0.25 * math.sin(math.pi * (k + 1) / 8)
			seg = Vector((0, 0.4875, sag1 - sag0))
			c = p.cylinder(0.035, 0.0, seg.length, sides=5)
			p.transform(c, Matrix.Translation((x, y0, sag0)) @ seg.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4())
			segs += c
			hang = p.box(x - 0.012, x + 0.012, y0 - 0.012, y0 + 0.012, 0.0, sag0)
			segs += hang
		p.paint(segs, "paja", "DARK", vary=0.08)


def flag_floor(p, half_x, half_y, cols, rows, z1, swatch="piedra_templo", skip=(), gap=0.04):
	"""Lajas sueltas sobre el piso (sin base), de -half a half; skip = (col, fila) que faltan."""
	slabs = []
	w, d = 2 * half_x / cols, 2 * half_y / rows
	for c in range(cols):
		for r in range(rows):
			if (c, r) in skip:
				continue
			x0, y0 = -half_x + c * w, -half_y + r * d
			slab = p.box(x0 + gap, x0 + w - gap, y0 + gap, y0 + d - gap, -0.02, z1 + p.rng.uniform(-0.01, 0.01), taper=0.012)
			p.jitter(slab, 0.012, keep_z=True)
			slabs += slab
	p.paint(slabs, swatch, "MID", vary=0.1)
	return slabs


def cornisa_ojo(p):
	"""Estrado de lajas bajo el pilar del ojo, con un borde escalonado adelante y dos mojones escalonados a los lados."""
	base = p.box(-1.15, 1.15, -1.1, 0.45, -0.05, 0.06, taper=0.03)
	p.paint(base, "piedra_templo", "DARK")
	slabs = flag_floor(p, 1.05, 0.72, 3, 2, 0.1, skip={(2, 0)})
	p.transform(slabs, Matrix.Translation((0, -0.33, 0)))
	rim = []
	for i, w in enumerate((0.9, 0.6, 0.3)):
		rim += p.box(-w, w, -1.16 + i * 0.04, -1.08 + i * 0.04, 0.06, 0.1 + i * 0.03)
	p.paint(rim, "piedra_templo", "LIGHT", vary=0.05)
	for x in (-0.95, 0.95):
		marker = []
		for i, w in enumerate((0.3, 0.22, 0.14)):
			marker += p.box(x - w / 2, x + w / 2, 0.15 - w / 2, 0.15 + w / 2, 0.06 + i * 0.16, 0.22 + i * 0.16)
		p.paint(marker, "piedra_templo", z_range=(0.0, 0.6), vary=0.06)


def nicho_carcaj(p):
	"""Piso de lajas del nicho del carcaj (dos por dos celdas), con lajas que faltan donde asoma el pasto."""
	flag_floor(p, 1.8, 1.8, 4, 4, 0.04, skip={(0, 0), (3, 1), (1, 3)})


def estela_carcaj(p):
	"""Estela contra la pared del nicho, con una flecha en relieve que apunta hacia arriba."""
	base = p.box(-0.5, 0.5, -0.2, 0.2, 0.0, 0.18)
	p.jitter(base, 0.015)
	slab = p.box(-0.4, 0.4, -0.08, 0.08, 0.18, 1.4)
	for v in {v for f in slab for v in f.verts}:
		if v.co.z > 1.1:
			v.co.x *= 0.8
	p.paint(base, "piedra_templo", "DARK", vary=0.1)
	p.paint(slab, "piedra_templo", z_range=(0.0, 1.6), vary=0.06)
	relief = p.box(-0.035, 0.035, -0.1, -0.08, 0.35, 1.05)
	shapes = p.polygon([(-0.16, 1.0), (0.16, 1.0), (0.0, 1.24)], 0.08, 0.1)
	for side in (-1, 1):
		shapes += p.polygon([(0.0, 0.4), (side * 0.13, 0.32), (side * 0.13, 0.46), (0.0, 0.54)][::side], 0.08, 0.1)
	p.transform(shapes, Matrix.Rotation(math.pi / 2, 4, "X"))
	p.paint(relief + shapes, "dorado", "MID")


piece("reja", 14, reja)
piece("bloque_empujable", 15, bloque_empujable)
piece("interruptor_marco", 16, interruptor_marco)
piece("interruptor_placa", 17, interruptor_placa)
piece("ojo_pilar", 18, ojo_pilar)
piece("ojo_globo", 19, ojo_globo)
piece("puente", 20, puente)


# --- templo por fuera ---

def fachada_templo(p):
	"""Portada del templo, 6 m de ancho: jambas y dintel monolíticos con un friso de ojos y escalonados.
	La abertura (2.4 × 2.6, trapezoidal arriba) queda centrada en el origen; el sello entra justo ahí."""
	plinth = p.box(-3.2, 3.2, -0.9, 0.9, -0.5, 0.2)
	p.paint(plinth, "piedra_templo", "DARK", vary=0.05)
	dark = p.box(-1.2, 1.2, -0.3, 0.9, 0.2, 2.8)
	p.paint(dark, "noche", "DARK")
	for side in (-1, 1):
		jamb = p.box(1.2, 3.0, -0.7, 0.7, 0.2, 3.4)
		for v in {v for f in jamb for v in f.verts}:
			if v.co.z > 3.0 and v.co.x < 1.3:
				v.co.x = 1.0
		p.transform(jamb, Matrix.Scale(side, 4, Vector((1, 0, 0))))
		p.paint(jamb, "piedra_templo", z_range=(0, 5), vary=0.06)
		for k in range(3):
			niche = p.box(1.9, 2.4, -0.74, -0.7, 0.6 + k * 0.9, 1.2 + k * 0.9)
			for v in {v for f in niche for v in f.verts}:
				if v.co.z > 0.9 + k * 0.9:
					v.co.x += 0.06 if v.co.x < 2.1 else -0.06
			p.transform(niche, Matrix.Scale(side, 4, Vector((1, 0, 0))))
			p.paint(niche, "gris_5", "MID")
	lintel = p.box(-3.1, 3.1, -0.8, 0.8, 3.4, 4.6)
	p.paint(lintel, "piedra_templo", z_range=(0, 5), vary=0.04)
	frieze = epi.eye(p, Vector((0, -0.8, 4.0)), 0.55, depth=0.06)
	for side in (-1, 1):
		for i in range(3):
			w = 0.9 - i * 0.25
			step = p.box(-w / 2, w / 2, -0.86, -0.8, 3.55 + i * 0.25, 3.8 + i * 0.25)
			p.transform(step, Matrix.Translation((side * 1.9, 0, 0)))
			frieze += step
	p.paint(frieze, "dorado", "MID", vary=0.05)
	cornice = p.box(-3.3, 3.3, -0.95, 0.95, 4.6, 4.85, taper=0.08)
	p.paint(cornice, "piedra_templo", "LIGHT")


def sello_losa(p):
	"""Losa del sello, 2.4 × 2.6 × 0.5, violeta con marco dorado; el ojo va aparte (centro a 1.4 m)."""
	slab = p.box(-1.2, 1.2, -0.25, 0.25, 0.0, 2.6)
	p.paint(slab, "sello", z_range=(-0.5, 3.2), vary=0.04)
	frame = []
	for x0, x1, z0, z1 in ((-1.2, 1.2, 0.0, 0.12), (-1.2, 1.2, 2.48, 2.6), (-1.2, -1.08, 0.0, 2.6), (1.08, 1.2, 0.0, 2.6)):
		frame += p.box(x0, x1, -0.29, -0.25, z0, z1)
	p.paint(frame, "dorado", "MID")
	socket = p.lathe([(0.55, 0.0), (0.55, 0.04), (0.47, 0.04), (0.47, 0.0)], sides=16, caps=False)
	p.transform(socket, Matrix.Translation((0, -0.25, 1.4)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	p.paint(socket, "dorado", "LIGHT")


def sello_ojo(p):
	"""El ojo del sello: almendra con iris y pupila, mirando a -Y, centrado en el origen."""
	almond = epi.eye(p, Vector((0, 0, 0)), 0.45, depth=0.08, pupil_swatch="noche")
	p.paint(almond, "hueso", "LIGHT")
	iris = p.cylinder(0.2, 0.0, 0.1, sides=12)
	p.transform(iris, Matrix.Rotation(math.pi / 2, 4, "X"))
	p.paint(iris, "sello", "LIGHT")


def portal_disco(p):
	disk = p.cylinder(1.0, 0.0, 0.08, sides=16)
	p.paint(disk, "piedra_templo", "MID")
	inlay = []
	for w, h in ((1.2, 0.4), (0.8, 0.8), (0.4, 1.2)):
		inlay += p.box(-w / 2, w / 2, -h / 2, h / 2, 0.08, 0.1)
	p.paint(inlay, "dorado", "MID")


def portal_anillo(p):
	ring = p.lathe([(1.0, 0.0), (1.12, 0.0), (1.12, 0.14), (1.0, 0.14), (1.0, 0.0)], sides=16, caps=False)
	p.paint(ring, "dorado", "LIGHT")
	teeth = []
	for i in range(8):
		a = 2 * math.pi * i / 8
		t = p.box(-0.08, 0.08, 1.1, 1.24, 0.0, 0.2)
		p.transform(t, Matrix.Rotation(a, 4, "Z"))
		teeth += t
	p.paint(teeth, "dorado", "MID")


def monolito(p):
	"""Columna del overworld: monolito de 0.8 × 0.8 × 2.6 con escalonados y el ojo arriba."""
	body = p.box(-0.4, 0.4, -0.4, 0.4, 0.0, 2.4, taper=0.06)
	p.paint(body, "piedra", z_range=(0, 3), vary=0.05)
	cap = p.box(-0.45, 0.45, -0.45, 0.45, 2.4, 2.6, taper=0.05)
	p.paint(cap, "piedra", "LIGHT")
	relief = epi.eye(p, Vector((0, -0.4, 2.0)), 0.22, depth=0.03)
	for i in range(3):
		w = 0.5 - i * 0.14
		relief += p.box(-w / 2, w / 2, -0.43, -0.4, 0.3 + i * 0.12, 0.4 + i * 0.12)
	p.paint(relief, "piedra", "DARK")


piece("fachada_templo", 21, fachada_templo)
piece("sello_losa", 22, sello_losa)
piece("sello_ojo", 23, sello_ojo)
piece("portal_disco", 24, portal_disco)
piece("portal_anillo", 25, portal_anillo)
piece("monolito", 26, monolito)
piece("cornisa_ojo", 35, cornisa_ojo)
piece("nicho_carcaj", 36, nicho_carcaj)
piece("estela_carcaj", 37, estela_carcaj)

piece("vertiente_pico", 30, vertiente_pico)
piece("orilla_piedras", 31, orilla_piedras)
piece("cristales_cueva", 32, cristales_cueva)
piece("rocas_rincon", 33, rocas_rincon)
piece("estalactitas_borde", 34, estalactitas_borde)


# --- terrazas: escalinata metida en la meseta (sube TOP en 2 celdas hacia +Y) y alero del salto de una vía ---

STEPS = 13
WALL = 0.22


def escalinata(walls):
	"""Origen en el centro de la celda de abajo, pie en z 0 al ras de la cara del risco; walls: lados (-1 oeste, 1 este) con muro."""
	def make(p):
		run = 4.0 / STEPS
		rise = TOP / STEPS
		x0 = -1.0 + (WALL if -1 in walls else 0.0)
		x1 = 1.0 - (WALL if 1 in walls else 0.0)
		treads = []
		for i in range(STEPS):
			y = -1.0 + i * run
			top = (i + 1) * rise
			joint = 0.0 if i % 2 else 0.5 * (1 if i % 4 == 0 else -1)
			for a, b in ((x0, joint), (joint, x1)):
				if b - a > 0.05:
					slab = p.box(a + 0.008, b - 0.008, y + 0.005, y + run + 0.02, top - rise - 0.12, top, taper=0.01)
					p.jitter(slab, 0.01, keep_z=True)
					treads += slab
		p.paint([f for f in treads if f.normal.z > 0.5], "piedra", "LIGHT", vary=0.1)
		p.paint([f for f in treads if f.normal.z <= 0.5], "piedra", "LOW", vary=0.1)
		for side in walls:
			cheek(p, side)
	return make


def cheek(p, side):
	inner = side * (1.0 - WALL)
	outer = side * 1.0
	core = p.box(min(inner, outer), max(inner, outer), -1.0, 3.0, 0.0, TOP)
	p.paint(core, "acantilado", "DARK")
	facing = Vector((-side, 0, 0))
	stones = []
	z = 0.0
	while z < TOP - 0.12:
		h = min(TOP - z, 0.3 + p.rng.random() * 0.2)
		if TOP - (z + h) < 0.2:
			h = TOP - z
		y = -1.0
		while y < 2.9:
			w = min(3.0 - y, 0.4 + p.rng.random() * 0.4)
			if 3.0 - (y + w) < 0.25:
				w = 3.0 - y
			if z + h > TOP * (y + w + 1.0) / 4.0 - 0.05:
				st = p.stone(Vector((inner, y + w / 2, z + h / 2)), w - 0.035, h - 0.035, 0.06 + p.rng.random() * 0.05, facing, inset=0.03)
				p.jitter(st, 0.012)
				stones += st
			y += w
		z += h
	front = []
	z = 0.0
	while z < TOP - 0.1:
		h = min(TOP - z, 0.35 + p.rng.random() * 0.15)
		front += p.stone(Vector(((inner + outer) / 2, -1.0, z + h / 2)), WALL - 0.03, h - 0.035, 0.07, Vector((0, -1, 0)), inset=0.02)
		z += h
	cap = p.box(min(inner, outer) - 0.03, max(inner, outer) + 0.03, -1.08, 3.0, TOP, TOP + 0.08)
	p.jitter(cap, 0.01)
	p.paint(stones + front, "acantilado", z_range=(0, TOP), vary=0.12)
	p.paint(cap, "piedra", "LIGHT")


def salto(ends):
	"""Alero del salto: lajas que sobresalen 0.3 m del borde (y 0) hacia -Y y piedras bajas encima; origen en el borde, z 0 = piso."""
	def make(p):
		slabs = []
		stones = []
		x = -1.0
		k = 0
		while x < 0.99:
			w = min(1.0 - x, 0.5 + 0.12 * (k % 3))
			if 1.0 - (x + w) < 0.2:
				w = 1.0 - x
			reach = 0.3 + 0.06 * ((k * 7) % 3 - 1)
			slab = p.box(x + 0.02, x + w - 0.02, -reach, 0.45, -0.24, 0.03 + 0.02 * (k % 2), taper=0.03)
			p.jitter(slab, 0.015, keep_z=True)
			slabs += slab
			x += w
			k += 1
		for i in range(5):
			cx = -0.8 + i * 0.4 + p.rng.uniform(-0.05, 0.05)
			r = p.rng.uniform(0.17, 0.21)
			stones += p.blob((cx, 0.15, 0.03), r, squash=(1.1, 0.9, 0.85), subdiv=1, rough=0.2, flat_bottom=0.02)
		for side in ends:
			stones += p.blob((side * 0.8, 0.1, 0.03), 0.3, squash=(1.0, 1.0, 1.1), subdiv=1, rough=0.2, flat_bottom=0.02)
		p.paint(slabs, "piedra", z_range=(-0.3, 0.05), vary=0.1)
		p.paint(stones, "acantilado", z_range=(0.0, 0.35), vary=0.1)
	return make


piece("escalinata_o", 40, escalinata((-1,)))
piece("escalinata_medio", 41, escalinata(()))
piece("escalinata_e", 42, escalinata((1,)))
piece("escalinata_sola", 43, escalinata((-1, 1)))
piece("salto_o", 44, salto((-1,)))
piece("salto_medio", 45, salto(()))
piece("salto_e", 46, salto((1,)))

epi.layout(kit, columns=7, spacing=3.5)
epi.publish("lugares", material="outdoor")
