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


def piece(name, seed, fn, smooth=None):
	p = epi.Piece(seed)
	extra = fn(p)
	obj = p.build(name, kit, smooth=smooth)
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

def fitted_stones(p, half, front, z0, z1, door=0.0):
	"""Hileras de piedras grandes encajadas, de canto redondeado, en un frente de x ±half con la cara en y = front;
	deja libre el hueco de la puerta (|x| < door, hasta 3 m)."""
	faces = []
	z, row = z0, 0
	while z < z1 - 0.1:
		h = min(0.6 if row % 2 else 0.5, z1 - z)
		x = -half + (0.35 if row % 2 else 0.0)
		if row % 2:
			faces += p.rounded_box(-half + 0.02, x - 0.02, front, front + 2.0, z + 0.02, z + h - 0.02, radius=0.07, segments=2)
		while x < half - 0.01:
			w = min(0.7 + p.rng.random() * 0.5, half - x)
			if half - x - w < 0.3:
				w = half - x
			if not (abs(x + w / 2) < door + w / 2 and z < 3.0):
				out = p.rng.uniform(0.0, 0.05)
				faces += p.rounded_box(x + 0.02, x + w - 0.02, front - out, front + 2.0, z + 0.02, z + h - 0.02, radius=0.07, segments=2)
			x += w
		z += h
		row += 1
	return faces


def fachada_templo(p):
	"""Templo escalonado a lo Link's Awakening: un muro de piedras grandes encajadas con la puerta trapezoidal de
	doble marco y nichos a los costados, y dos gradas que suben detrás hasta un altar con el ojo de oro.
	La abertura (2.4 × 2.6, la del sello) queda centrada en el origen; el frente mira a -Y."""
	stone = "piedra_templo"
	p.paint(p.rounded_box(-3.7, 3.7, -1.3, 2.8, -0.5, 0.15, radius=0.08), stone, "DARK", vary=0.05)
	p.paint(p.box(-1.2, 1.2, -0.3, 1.2, 0.15, 2.8), "noche", "DARK")
	blocks = fitted_stones(p, 3.5, -0.75, 0.15, 3.55, door=1.55)
	blocks += fitted_stones(p, 2.6, 0.0, 3.8, 4.9)
	blocks += fitted_stones(p, 1.5, 0.7, 5.05, 6.0)
	p.paint(blocks, stone, z_range=(0, 6.5), vary=0.07)
	frame = []
	for inset, out, swatch in ((1.55, 0.82, stone), (1.35, 0.9, stone)):
		for side in (-1, 1):
			jamb = p.polygon([(side * 1.2, -out), (side * inset, -out), (side * (inset - 0.18), -0.3), (side * 1.2, -0.3)][:: side], 0.15, 2.95)
			for v in {v for f in jamb for v in f.verts if abs(v.co.x) > 1.25}:
				v.co.x -= side * 0.25 * (v.co.z - 0.15) / 2.8
			frame += jamb
		frame += p.rounded_box(-inset + 0.2, inset - 0.2, -out, 0.4, 2.6, 3.1 if inset > 1.4 else 2.95, radius=0.05)
	niches = []
	for side in (-1, 1):
		for k in range(2):
			cx = side * (2.25 + k * 0.85)
			rim = p.polygon([(cx - 0.36, -0.86), (cx + 0.36, -0.86), (cx + 0.36, -0.7), (cx - 0.36, -0.7)], 0.8, 2.2)
			hole = p.polygon([(cx - 0.24, -0.88), (cx + 0.24, -0.88), (cx + 0.24, -0.84), (cx - 0.24, -0.84)], 0.92, 2.06)
			for faces, top, k in ((rim, 1.5, 0.7), (hole, 1.5, 0.62)):
				for v in {v for f in faces for v in f.verts if v.co.z > top}:
					v.co.x = cx + (v.co.x - cx) * k
			frame += rim
			niches += hole
	p.paint(frame, stone, "LIGHT", vary=0.04)
	p.paint(niches, "noche", "MID")
	p.paint(p.rounded_box(-3.6, 3.6, -0.9, 2.7, 3.55, 3.8, radius=0.06), stone, "LIGHT")
	p.paint(p.rounded_box(-2.6, 2.6, 0.1, 2.7, 3.8, 4.9, radius=0.1), stone, "DARK")
	p.paint(p.rounded_box(-2.8, 2.8, -0.1, 2.8, 4.9, 5.05, radius=0.05), stone, "LIGHT")
	p.paint(p.rounded_box(-1.5, 1.5, 0.8, 2.6, 5.05, 6.0, radius=0.1), stone, "DARK")
	p.paint(p.rounded_box(-1.7, 1.7, 0.6, 2.7, 6.0, 6.15, radius=0.05), stone, "LIGHT")
	gold = epi.eye(p, Vector((0, -0.1, 4.35)), 0.42, depth=0.06)
	for side in (-1, 1):
		for i in range(3):
			w = 0.9 - i * 0.25
			gold += p.rounded_box(side * 1.75 - w / 2, side * 1.75 + w / 2, -0.12, -0.03, 3.9 + i * 0.25, 4.15 + i * 0.25, radius=0.02, segments=1)
	gold += epi.eye(p, Vector((0, 0.6, 5.5)), 0.3, depth=0.05)
	p.paint(gold, "dorado", "MID", vary=0.05)
	mountain(p)


## Frente del cerro: donde termina la explanada (la roca del terreno empieza ahí).
MOUNTAIN_FRONT = 0.6


def mountain(p):
	"""El cerro donde está tallado el templo: peñascos redondos apilados a los costados y detrás, más altos hacia
	atrás, con pasto encima; deja libre el frente del templo (el templo sigue bajo tierra)."""
	rock, grass = [], []
	for gy in range(5):
		for gx in range(-7, 8):
			x = gx * 1.13 + p.rng.uniform(-0.15, 0.15)
			if abs(x) < 3.9 and gy < 2:
				continue
			top = 3.2 + 4.6 * max(0.0, 1.0 - abs(x) / 9.0) + gy * 0.6
			if abs(x) < 3.0 and gy < 4:
				top = max(top, 6.6)
			z = 0.0
			while z < top:
				r = p.rng.uniform(0.85, 1.25)
				y = MOUNTAIN_FRONT + r + gy * 1.4 + (p.rng.uniform(0.0, 0.3) if gy else 0.0)
				faces = p.blob((x, y, z + r * 0.55), r, squash=(1.1, 1.0, 0.75), subdiv=2, rough=0.12, flat_bottom=0.0 if z == 0.0 else None)
				for f in faces:
					(grass if f.normal.z > 0.75 and f.calc_center_median().z > top - 0.6 else rock).append(f)
				z += r * 1.1
	p.paint(rock, "acantilado", z_range=(0.0, 9.0), vary=0.08)
	p.paint(grass, "pasto", "MID", vary=0.06)


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


# --- necrópolis ---

CHULLPA_BODY = 2.9
CHULLPA_BOTTOM = 0.9
CHULLPA_TOP = 1.15
CHULLPA_COURSES = 8
CHULLPA_DOOR = (0.32, 0.7)


def chullpa_radius(z):
	return CHULLPA_BOTTOM + (CHULLPA_TOP - CHULLPA_BOTTOM) * z / CHULLPA_BODY


def chullpa_tumba(p):
	"""Chullpa de Sillustani: torre de piedras labradas en hileras que se ensancha hacia arriba, cornisa, cúpula baja
	y la puerta chica a ras del piso mirando al frente. Origen en el centro de la base."""
	core = p.lathe([(CHULLPA_BOTTOM - 0.06, 0.0), (CHULLPA_TOP - 0.06, CHULLPA_BODY)], sides=20)
	p.paint(core, "acantilado", "DARK")
	h = CHULLPA_BODY / CHULLPA_COURSES
	for k in range(CHULLPA_COURSES):
		z0, z1 = k * h, (k + 1) * h
		r = chullpa_radius((z0 + z1) / 2)
		n = max(8, round(2 * math.pi * r / 0.68))
		step = 2 * math.pi / n
		phase = step / 2 if k % 2 else 0.0
		for i in range(n):
			a = phase + i * step
			if abs(math.remainder(a, 2 * math.pi)) < CHULLPA_DOOR[0] / r + step / 2 and z0 < CHULLPA_DOOR[1]:
				continue
			w = 2 * r * math.sin(step / 2) - 0.04
			out = p.rng.uniform(0.0, 0.03)
			block = p.rounded_box(-w / 2, w / 2, -r - out, -r + 0.3, z0 + 0.02, z1 - 0.02, radius=0.06, segments=2)
			p.paint(block, "piedra", "MID", z_range=(0.0, CHULLPA_BODY + 0.6), vary=0.08)
			p.transform(block, Matrix.Rotation(a, 4, "Z"))
	door = p.box(-CHULLPA_DOOR[0], CHULLPA_DOOR[0], -CHULLPA_BOTTOM - 0.02, -CHULLPA_BOTTOM + 0.4, 0.0, CHULLPA_DOOR[1], taper=0.06)
	p.paint(door, "noche", "MID")
	lintel = p.rounded_box(-CHULLPA_DOOR[0] - 0.12, CHULLPA_DOOR[0] + 0.12, -chullpa_radius(0.8) - 0.06, -chullpa_radius(0.8) + 0.3,
			CHULLPA_DOOR[1], CHULLPA_DOOR[1] + 0.18, radius=0.04, segments=2)
	p.paint(lintel, "piedra", "LIGHT", vary=0.05)
	cornice = p.lathe([(CHULLPA_TOP - 0.05, CHULLPA_BODY - 0.02), (CHULLPA_TOP + 0.08, CHULLPA_BODY), (CHULLPA_TOP + 0.1, CHULLPA_BODY + 0.16),
			(CHULLPA_TOP - 0.02, CHULLPA_BODY + 0.18)], sides=24)
	p.paint(cornice, "piedra", "LIGHT", vary=0.04)
	dome = p.lathe([(CHULLPA_TOP - 0.04, CHULLPA_BODY + 0.16), (CHULLPA_TOP - 0.1, CHULLPA_BODY + 0.42), (0.85, CHULLPA_BODY + 0.72),
			(0.5, CHULLPA_BODY + 0.9), (0.0, CHULLPA_BODY + 0.97)], sides=24)
	p.paint(dome, "acantilado", "GRADIENT", z_range=(CHULLPA_BODY, CHULLPA_BODY + 1.0), vary=0.05)
	for i in range(7):
		a = p.rng.uniform(0, 2 * math.pi)
		r = CHULLPA_BOTTOM + 0.05
		tuft = p.blob((r * math.cos(a), r * math.sin(a), 0.05), p.rng.uniform(0.12, 0.2), squash=(1.3, 1.3, 0.6), subdiv=1, rough=0.25)
		p.paint(tuft, "musgo", "MID")


piece("chullpa_tumba", 38, chullpa_tumba, smooth=40)


def hoyo_escalera(p):
	"""Hoyo con escalera bajo una mata (el piso del terreno no se abre: todo va apenas sobre el suelo). Tierra removida,
	un borde de piedras redondeadas y adentro el negro con tres escalones que bajan hacia el fondo (-Y en Blender es el
	sur de Godot: el escalón de arriba queda del lado de la cámara)."""
	dirt = p.lathe([(0.0, 0.035), (1.1, 0.035), (1.2, 0.0)], sides=16)
	p.jitter(dirt, 0.05, keep_z=True)
	p.paint(dirt, "tierra", "DARK", vary=0.05)
	hole = p.box(-0.7, 0.7, -0.7, 0.7, 0.036, 0.045)
	p.paint(hole, "noche", "DARK")
	for i, (y, shade) in enumerate(((-0.5, "MID"), (-0.18, "LOW"), (0.14, "DARK"))):
		step = p.box(-0.6, 0.6, y - 0.13, y + 0.13, 0.045, 0.055 - i * 0.003)
		p.paint(step, "piedra", shade, vary=0.04)
	rim = []
	for k in range(12):
		t = k / 12 * 4
		side, f = int(t), t - int(t)
		x, y = [(-0.8 + 1.6 * f, -0.8), (0.8, -0.8 + 1.6 * f), (0.8 - 1.6 * f, 0.8), (-0.8, 0.8 - 1.6 * f)][side]
		w = p.rng.uniform(0.24, 0.32)
		stone = p.rounded_box(x - w, x + w, y - 0.17, y + 0.17, 0.0, p.rng.uniform(0.13, 0.19), radius=0.06)
		if side % 2:
			p.transform(stone, Matrix.Translation((x, y, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z") @ Matrix.Translation((-x, -y, 0)))
		p.jitter(stone, 0.015)
		rim += stone
	p.paint(rim, "piedra", z_range=(0.0, 0.19), vary=0.08)


piece("hoyo_escalera", 39, hoyo_escalera, smooth=30)
piece("fachada_templo", 21, fachada_templo, smooth=60)
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


def escalon_alto(p):
	"""Escalón de roca de 0.6 m en medio del pasto: no se sube caminando, sí saltando con la pluma; origen en la base."""
	rock(p, -0.85, 0.85, -0.85, 0.85, 0.0, 0.6, push=0.1)


piece("escalon_alto", 47, escalon_alto)


# --- entradas de las mazmorras en el overworld ---

## Chullpa grande: radio abajo y arriba, alto del cuerpo, hileras. La puerta (2.2 × 2.6) mira a -Y.
ENTRADA_CHULLPA = (3.2, 3.9, 8.0, 11)
ENTRADA_DOOR = (1.1, 0.9, 2.6)


def _arc(p, radius, a0, a1, y, thick, steps=8, center_z=0.0):
	"""Tronco curvo en el plano XZ (y fijo): tramos de cilindro sobre un arco."""
	faces = []
	pts = [Vector((radius * math.cos(a0 + (a1 - a0) * i / steps), y, center_z + radius * math.sin(a0 + (a1 - a0) * i / steps))) for i in range(steps + 1)]
	for a, b in zip(pts, pts[1:]):
		seg = p.cylinder(thick, 0.0, (b - a).length + thick * 0.6, sides=7)
		p.transform(seg, Matrix.Translation(a) @ (b - a).to_track_quat("Z", "Y").to_matrix().to_4x4())
		faces += seg
	return faces


def chullpa_entrada(p):
	"""Entrada a la Chullpa: chullpa grande de piedra de campo asentada en barro que se ensancha hacia arriba, puerta
	trapezoidal con jambas de piedra y dintel con la media chakana escalonada, nichos con cráneos bajo la cornisa y
	cúpula baja. Origen en el centro de la base."""
	bottom, top, body, courses = ENTRADA_CHULLPA
	half0, half1, door_h = ENTRADA_DOOR

	def radius(z):
		return bottom + (top - bottom) * z / body

	p.paint(p.lathe([(bottom - 0.1, 0.0), (top - 0.1, body)], sides=32), "tierra", "DARK")
	h = body / courses
	niches = [math.pi / 4 * i + math.pi / 8 for i in range(8)]
	niche_z = (body - 2.0, body - 0.9)
	stones = []
	for k in range(courses):
		z0, z1 = k * h, (k + 1) * h
		r = radius((z0 + z1) / 2)
		n = max(10, round(2 * math.pi * r / 0.95))
		step = 2 * math.pi / n
		phase = step * (0.5 if k % 2 else 0.0) + p.rng.uniform(-0.05, 0.05)
		for i in range(n):
			a = phase + i * step
			along = abs(math.remainder(a, 2 * math.pi)) * r
			if along < 1.75 + step * r / 2 and z0 < door_h + 0.65:
				continue
			if z1 > niche_z[0] and z0 < niche_z[1] and any(abs(math.remainder(a - b, 2 * math.pi)) * r < 0.55 + step * r / 2 for b in niches):
				continue
			w = 2 * r * math.sin(step / 2) - 0.06
			out = p.rng.uniform(0.0, 0.06)
			block = p.rounded_box(-w / 2, w / 2, -r - out, -r + 0.35, z0 + 0.04, z1 - 0.04, radius=0.1, segments=2)
			p.jitter(block, 0.035)
			p.transform(block, Matrix.Rotation(a, 4, "Z"))
			stones += block
	p.paint(stones, "acantilado", z_range=(0.0, body + 0.5), vary=0.12)
	front = -radius(1.3)
	door = p.box(-half0, half0, front - 0.45, front + 1.5, 0.0, door_h, taper=half0 - half1)
	p.paint(door, "noche", "MID")
	frame = []
	for side in (-1, 1):
		jamb = p.box(-0.32, 0.32, front - 0.6, front + 0.3, 0.0, door_h, taper=0.04)
		p.jitter(jamb, 0.02)
		lean = Matrix.Rotation(-side * math.atan2(half0 - half1, door_h), 4, "Y")
		p.transform(jamb, Matrix.Translation((side * (half0 + 0.3), 0, 0)) @ lean)
		frame += jamb
	frame += p.rounded_box(-1.75, 1.75, front - 0.7, front + 0.4, door_h, door_h + 0.65, radius=0.08, segments=2)
	frame += p.rounded_box(-1.6, 1.6, front - 1.05, front - 0.5, -0.05, 0.14, radius=0.05, segments=1)
	p.paint(frame, "acantilado", "LIGHT", vary=0.05)
	relief = []
	for i in range(3):
		w = 1.35 - i * 0.38
		relief += p.rounded_box(-w, w, front - 0.78, front - 0.68, door_h + 0.1 + i * 0.15, door_h + 0.23 + i * 0.15, radius=0.02, segments=1)
	p.paint(relief, "cobre_verde", "MID", vary=0.04)
	skulls, holes = [], []
	for b in niches:
		r = radius(sum(niche_z) / 2)
		hole = p.box(-0.42, 0.42, -r + 0.12, -r + 0.6, niche_z[0] + 0.05, niche_z[1] - 0.05, taper=0.08)
		lintel = p.rounded_box(-0.6, 0.6, -r - 0.12, -r + 0.3, niche_z[1] - 0.06, niche_z[1] + 0.12, radius=0.04, segments=1)
		skull = p.blob((0, -r - 0.02, niche_z[0] + 0.45), 0.3, squash=(0.95, 1.0, 0.95), subdiv=2, rough=0.05)
		jaw = p.rounded_box(-0.16, 0.16, -r - 0.22, -r + 0.05, niche_z[0] + 0.1, niche_z[0] + 0.26, radius=0.05, segments=1)
		eyes = [p.blob((s * 0.11, -r - 0.29, niche_z[0] + 0.48), 0.075, subdiv=1, rough=0.0) for s in (-1, 1)]
		for faces in (hole, lintel, skull, jaw, *eyes):
			p.transform(faces, Matrix.Rotation(b, 4, "Z"))
		holes += hole + sum(eyes, [])
		skulls += skull + jaw
		stones_l = lintel
		p.paint(stones_l, "piedra", "LIGHT", vary=0.04)
	p.paint(holes, "noche", "MID")
	p.paint(skulls, "hueso", "MID", vary=0.05)
	cornice = p.lathe([(top - 0.1, body - 0.02), (top + 0.14, body), (top + 0.18, body + 0.3), (top - 0.04, body + 0.34)], sides=40)
	p.paint(cornice, "tierra", "MID", vary=0.04)
	dome = p.lathe([(top - 0.08, body + 0.3), (top - 0.25, body + 0.9), (2.2, body + 1.5), (1.2, body + 1.9), (0.0, body + 2.0)], sides=40)
	p.paint(dome, "acantilado", "GRADIENT", z_range=(body, body + 2.0), vary=0.05)
	tufts = []
	for i in range(14):
		a = p.rng.uniform(0, 2 * math.pi)
		if abs(math.remainder(a + math.pi / 2, 2 * math.pi)) < 0.75:
			continue
		r = bottom + 0.1
		tufts += p.blob((r * math.cos(a), r * math.sin(a), 0.05), p.rng.uniform(0.2, 0.35), squash=(1.3, 1.3, 0.6), subdiv=1, rough=0.25)
	for i in range(10):
		a = p.rng.uniform(0, 2 * math.pi)
		z = p.rng.uniform(body - 0.2, body + 0.4)
		tufts += p.blob((top * math.cos(a), top * math.sin(a), z), p.rng.uniform(0.18, 0.3), squash=(1.3, 1.3, 0.5), subdiv=1, rough=0.25)
	p.paint(tufts, "musgo", "MID", vary=0.08)


## Queñoa gigante: tronco retorcido de corteza que se pela, raíces, cuatro ramas y la copa. Puerta en arco a -Y.
QUENOA_DOOR = (1.1, 2.6)


def quenoa_entrada(p):
	"""Entrada a la Queñoa: un queñoa enorme de tronco retorcido, corteza rojiza que se pela en láminas, raíces que
	abrazan la base, cuatro ramas gruesas y copa de hojitas gris verdosas; en el frente, una puerta en arco con marco
	de troncos atados con soga y musgo colgando, como las puertas de adentro. Origen en el centro de la base."""
	half, door_h = QUENOA_DOOR
	front_angle = -math.pi / 2
	trunk = p.lathe([(3.5, -0.2), (3.0, 0.7), (2.8, 2.2), (2.6, 4.5), (2.45, 6.5), (2.2, 8.0), (1.4, 8.8), (0.0, 9.0)], sides=28)
	off = Vector((3.1, 7.7, 1.3))
	for v in {v for f in trunk for v in f.verts}:
		flat = Vector((v.co.x, v.co.y, 0.0))
		if flat.length < 1e-3:
			continue
		a = math.atan2(v.co.y, v.co.x)
		calm = min(1.0, abs(math.remainder(a - front_angle, 2 * math.pi)) / 0.8) if v.co.z < door_h + 0.8 else 1.0
		twist = v.co.z * 0.12
		n = noise.noise(Vector((math.cos(a + twist) * 1.6, math.sin(a + twist) * 1.6, v.co.z * 0.3)) + off)
		k = 1.0 + calm * (0.12 * n + 0.07 * math.sin(a * 5 + v.co.z * 0.5))
		v.co.x *= k
		v.co.y *= k
	p.paint(trunk, "roca_naranja", "DARK", vary=0.06)
	limbs = []
	ends = []
	for i in range(4):
		a = front_angle + math.pi / 4 + i * math.pi / 2 + p.rng.uniform(-0.2, 0.2)
		start = Vector((1.0 * math.cos(a), 1.0 * math.sin(a), 7.6))
		end = Vector((3.8 * math.cos(a), 3.8 * math.sin(a), 11.2 + p.rng.uniform(-0.5, 0.5)))
		limb = p.cylinder(1.0, 0.0, (end - start).length, sides=9, radius_top=0.45)
		p.jitter(limb, 0.06)
		p.transform(limb, Matrix.Translation(start) @ (end - start).to_track_quat("Z", "Y").to_matrix().to_4x4())
		limbs += limb
		ends.append(end)
	p.paint(limbs, "roca_naranja", "DARK", vary=0.06)
	roots = []
	for i in range(7):
		a = front_angle + 0.95 + i * (2 * math.pi - 1.9) / 6
		start = Vector((2.4 * math.cos(a), 2.4 * math.sin(a), 1.4))
		end = Vector((4.6 * math.cos(a), 4.6 * math.sin(a), -0.3))
		root = p.cylinder(0.75, 0.0, (end - start).length, sides=8, radius_top=0.2)
		p.jitter(root, 0.05)
		p.transform(root, Matrix.Translation(start) @ (end - start).to_track_quat("Z", "Y").to_matrix().to_4x4())
		roots += root
	p.paint(roots, "madera_oscura", "MID", vary=0.06)
	from mathutils.bvhtree import BVHTree
	tree = BVHTree.FromBMesh(p.bm)
	flakes = []
	for i in range(320):
		a = p.rng.uniform(0, 2 * math.pi)
		z = p.rng.uniform(0.3, 8.0)
		if abs(math.remainder(a - front_angle, 2 * math.pi)) < 0.55 and z < door_h + 0.9:
			continue
		out = Vector((math.cos(a), math.sin(a), 0.0))
		hit, normal, _, _ = tree.ray_cast(Vector((0, 0, z)) + out * 6.0, -out, 7.0)
		if hit is None:
			continue
		w, hgt = p.rng.uniform(0.12, 0.28), p.rng.uniform(0.5, 1.3)
		flake = p.box(-w / 2, w / 2, 0.0, 0.03, -hgt, 0.0)
		p.jitter(flake, 0.02)
		curl = Matrix.Rotation(-p.rng.uniform(0.15, 0.5), 4, "X")
		p.transform(flake, Matrix.Translation(hit + out * 0.02) @ Matrix.Rotation(a + math.pi / 2, 4, "Z") @ curl)
		flakes += flake
	p.paint(flakes, "roca_naranja", "LIGHT", vary=0.12)
	leaves = []
	for end in ends + [Vector((0, 0, 12.3))]:
		for k in range(7):
			c = end + Vector((p.rng.uniform(-1.6, 1.6), p.rng.uniform(-1.6, 1.6), p.rng.uniform(-0.3, 1.4)))
			leaves += p.blob(c, p.rng.uniform(1.3, 2.0), squash=(1.0, 1.0, 0.75), subdiv=3, rough=0.18)
	p.paint(leaves, "musgo", z_range=(9.5, 14.5), vary=0.1)
	front = -2.95
	arch = [(-half, 0.0), (half, 0.0), (half, door_h - half)]
	arch += [(half * math.cos(t), door_h - half + half * math.sin(t)) for t in (math.pi * i / 8 for i in range(1, 8))]
	arch += [(-half, door_h - half)]
	door = p.polygon(arch, -front - 1.8, -front + 0.25)
	p.transform(door, Matrix.Rotation(math.pi / 2, 4, "X"))
	p.paint(door, "noche", "MID")
	frame, rope, moss = [], [], []
	for side in (-1, 1):
		post = p.cylinder(0.22, -0.1, door_h - half, sides=8, radius_top=0.2, center=(side * (half + 0.15), front - 0.15))
		p.jitter(post, 0.02)
		frame += post
		for z in (0.55, 1.35):
			rope += p.cylinder(0.26, z, z + 0.14, sides=8, center=(side * (half + 0.15), front - 0.15))
	frame += _arc(p, half + 0.15, 0.0, math.pi, front - 0.15, 0.21, steps=9, center_z=door_h - half)
	p.paint(frame, "madera", "MID", vary=0.08)
	p.paint(rope, "paja", "DARK", vary=0.05)
	for i in range(9):
		t = math.pi * (i + 0.5) / 9
		c = Vector(((half + 0.15) * math.cos(t), front - 0.2, door_h - half + (half + 0.35) * math.sin(t)))
		moss += p.blob(c, p.rng.uniform(0.16, 0.26), squash=(1.2, 0.9, 1.4), subdiv=1, rough=0.25)
		if i % 2:
			moss += p.cylinder(0.05, c.z - p.rng.uniform(0.5, 0.9), c.z, sides=5, center=(c.x, c.y - 0.05), radius_top=0.08)
	p.paint(moss, "musgo", "DARK", vary=0.08)


## Choza de la Totora (TotoraHut en el overworld): 4 × 4 m de planta y 3.5 m hasta el alero; la puerta mira a -Y.
TOTORA_HUT = (2.0, 2.6)
TOTORA_DOOR = (0.8, 2.2)


def totora_entrada(p):
	"""Entrada a la Totora: choza de los uros sobre una balsa de totora tejida, paredes de atados parados, techo de
	totora a cuatro aguas amarrado con soga oscura y una borla roja en la punta; al frente dos columnas de atados con
	cabeza de puma (como las proas de las balsas), una franja de aguayo sobre la puerta y totoras en flor alrededor.
	Origen en el centro de la base."""
	half, wall_h = TOTORA_HUT
	door_half, door_h = TOTORA_DOOR
	raft = p.lathe([(0.0, -0.05), (2.75, -0.05), (2.85, 0.04), (2.75, 0.13), (0.0, 0.13)], sides=24)
	p.paint_bands(raft, [(0.06, 0.14, "paja", "MID")], default=(0, 0, "tierra", "MID"))
	ring = p.lathe([(2.55, 0.1), (2.68, 0.17), (2.55, 0.24), (2.42, 0.17), (2.55, 0.1)], sides=24, caps=False)
	p.paint(ring, "paja", "LIGHT", vary=0.06)
	reeds = []
	step = 0.22
	for side in range(4):
		turn = Matrix.Rotation(side * math.pi / 2, 4, "Z")
		k = 0
		x = -half + step / 2
		while x < half:
			front = side == 0
			if front and abs(x) < door_half + 0.05:
				x += step
				continue
			top = wall_h + 0.08 * math.sin(k * 1.7)
			bundle = p.cylinder(0.12, 0.13, top, sides=6, radius_top=0.1, center=(x, -half + 0.12))
			p.transform(bundle, turn)
			reeds += bundle
			x += step
			k += 1
	p.paint(reeds, "paja", z_range=(-1.5, wall_h + 2.5), vary=0.06)
	lintel = []
	for z in (door_h + 0.06, door_h + 0.24):
		bar = p.cylinder(0.1, -door_half - 0.25, door_half + 0.25, sides=6)
		p.transform(bar, Matrix.Translation((0, -half + 0.1, z)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
		lintel += bar
	p.paint(lintel, "paja", "DARK", vary=0.04)
	inside = p.box(-half + 0.25, half - 0.25, -half + 0.25, half - 0.25, 0.13, wall_h)
	p.paint(inside, "noche", "MID")
	ties = []
	for z in (0.7, 1.6):
		for side in range(4):
			if side == 0:
				tie = p.box(-half - 0.02, -door_half - 0.05, -half - 0.02, -half + 0.05, z - 0.05, z + 0.05) + p.box(door_half + 0.05, half + 0.02, -half - 0.02, -half + 0.05, z - 0.05, z + 0.05)
			else:
				tie = p.box(-half - 0.02, half + 0.02, -half - 0.02, -half + 0.05, z - 0.05, z + 0.05)
			p.transform(tie, Matrix.Rotation(side * math.pi / 2, 4, "Z"))
			ties += tie
	p.paint(ties, "madera_oscura", "MID")
	roof = p.lathe([(0.0, wall_h - 0.3), (3.15, wall_h - 0.3), (3.1, wall_h - 0.1), (1.6, wall_h + 1.2), (0.25, wall_h + 2.05), (0.0, wall_h + 2.15)], sides=4, phase=math.pi / 4)
	p.jitter(roof, 0.03)
	p.paint_bands(roof, [(wall_h + 0.35, wall_h + 0.45, "madera_oscura", "MID"), (wall_h + 1.05, wall_h + 1.15, "madera_oscura", "MID")], default=(0, 0, "paja", "DARK"))
	tassel = p.blob((0, 0, wall_h + 2.2), 0.18, squash=(1.0, 1.0, 1.3), subdiv=1, rough=0.1)
	tassel += p.cylinder(0.05, wall_h + 2.05, wall_h + 2.55, sides=6, radius_top=0.0)
	p.paint(tassel, "tela_roja", "MID")
	cloth = p.box(-door_half - 0.3, door_half + 0.3, -half - 0.06, -half + 0.02, door_h + 0.38, door_h + 0.68)
	p.paint_bands(cloth, [(door_h + 0.38, door_h + 0.45, "tela_roja", "MID"), (door_h + 0.45, door_h + 0.52, "flor_amarilla", "MID"),
		(door_h + 0.52, door_h + 0.58, "tela_azul", "MID"), (door_h + 0.58, door_h + 0.68, "flor_rosa", "MID")], default=(0, 0, "tela_roja", "MID"))
	for side in (-1, 1):
		cx, cy = side * (door_half + 0.42), -half - 0.32
		column = p.lathe([(0.0, 0.1), (0.24, 0.1), (0.22, 1.6), (0.18, 3.0), (0.22, 3.25), (0.0, 3.35)], sides=10, center=(cx, cy))
		p.paint_bands(column, [(0.55, 0.65, "tela_roja", "MID"), (1.5, 1.6, "tela_roja", "MID"), (2.45, 2.55, "tela_roja", "MID")], default=(0, 0, "paja", "MID"))
		head = p.blob((cx, cy - 0.12, 3.45), 0.3, squash=(0.85, 1.25, 0.8), subdiv=2, rough=0.05)
		head += p.blob((cx, cy - 0.42, 3.38), 0.15, squash=(0.9, 1.1, 0.8), subdiv=1, rough=0.0)
		for ear in (-1, 1):
			head += p.cylinder(0.08, 3.62, 3.8, sides=5, radius_top=0.0, center=(cx + ear * 0.17, cy))
		p.paint(head, "paja", "LIGHT", vary=0.05)
		for eye in (-1, 1):
			dot = p.blob((cx + eye * 0.13, cy - 0.36, 3.52), 0.045, subdiv=1, rough=0.0)
			p.paint(dot, "noche", "MID")
	plants, heads = [], []
	for i in range(14):
		a = -math.pi / 2 + 0.75 + i * (2 * math.pi - 1.5) / 13 + p.rng.uniform(-0.1, 0.1)
		cx, cy = 2.95 * math.cos(a), 2.95 * math.sin(a)
		for k in range(5):
			length = p.rng.uniform(0.9, 1.7)
			blade = p.cylinder(0.035, 0.0, length, sides=4, radius_top=0.005)
			place = Matrix.Translation((cx + p.rng.uniform(-0.2, 0.2), cy + p.rng.uniform(-0.2, 0.2), -0.1)) @ Matrix.Rotation(p.rng.uniform(0.05, 0.3), 4, Vector((math.cos(k * 1.3), math.sin(k * 1.3), 0.0)))
			p.transform(blade, place)
			plants += blade
			if k < 2:
				spike = p.cylinder(0.06, length * 0.7, length * 0.88, sides=6)
				p.transform(spike, place)
				heads += spike
	p.paint(plants, "follaje", vary=0.12)
	p.paint(heads, "madera_oscura", "MID", vary=0.06)


piece("chullpa_entrada", 48, chullpa_entrada, smooth=40)
piece("quenoa_entrada", 49, quenoa_entrada, smooth=40)
piece("totora_entrada", 50, totora_entrada, smooth=40)

epi.layout(kit, columns=7, spacing=3.5)
epi.publish("lugares", material="outdoor")
