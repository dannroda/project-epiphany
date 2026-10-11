# Arma assets/epiphany/objetos.blend: props del overworld e interactivos (cofres, llaves, pickups, proyectiles).
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


def piece(name, seed, fn):
	p = epi.Piece(seed)
	extra = fn(p)
	obj = p.build(name, kit)
	for key, value in (extra if isinstance(extra, dict) else {}).items():
		obj[key] = value
	return obj


# --- props ---

def vasija(p):
	"""Aríbalo: cuerpo panzón, cuello angosto y boca abierta, con guardas rojas, negras y crema."""
	profile = [(0.1, 0.0), (0.2, 0.05), (0.27, 0.18), (0.29, 0.3), (0.26, 0.42), (0.17, 0.52), (0.1, 0.58), (0.1, 0.64), (0.15, 0.7), (0.0, 0.69)]
	body = p.lathe(profile, sides=12)
	p.paint_bands(body, [(0.16, 0.24, "noche", "MID"), (0.24, 0.36, "hueso", "MID"), (0.36, 0.46, "tela_roja", "MID"), (0.46, 0.52, "noche", "MID"), (0.62, 0.71, "tela_roja", "DARK")], default=(0, 0, "roca_naranja", "MID"))
	for side in (-1, 1):
		ear = p.box(-0.04, 0.04, -0.035, 0.035, 0.2, 0.3)
		p.transform(ear, Matrix.Translation((side * 0.29, 0, 0)))
		p.paint(ear, "roca_naranja", "DARK")


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
	base = p.box(-0.55, 0.55, -0.22, 0.22, 0.0, 0.2)
	p.jitter(base, 0.015)
	slab = p.box(-0.45, 0.45, -0.09, 0.09, 0.2, 1.3, taper=0.0)
	for v in {v for f in slab for v in f.verts}:
		if v.co.z > 1.0:
			v.co.x *= 0.82
	p.paint(base, "piedra", "DARK", vary=0.1)
	p.paint(slab, "piedra", z_range=(0.0, 1.5), vary=0.06)
	relief = []
	relief += epi.eye(p, Vector((0, -0.09, 0.85)), 0.28)
	for i in range(3):
		w = 0.62 - i * 0.16
		relief += p.box(-w / 2, w / 2, -0.11, -0.09, 0.32 + i * 0.07, 0.38 + i * 0.07)
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
			stones += p.blob((math.cos(a) * d, math.sin(a) * d, z + size * 0.3), size, squash=(1.2, 1.0, 0.5), subdiv=1, rough=0.25)
		z += 0.17
		r -= 0.13
	p.paint(stones, "piedra", z_range=(0, z + 0.2), vary=0.18)
	top = p.blob((0, 0, z + 0.12), 0.14, squash=(0.8, 0.8, 1.4), subdiv=1, rough=0.15)
	p.paint(top, "hueso", "MID")


def cajon(p):
	"""Caja física de 1 m: tablas con marco oscuro."""
	core = p.box(-0.47, 0.47, -0.47, 0.47, 0.03, 0.97)
	p.paint(core, "madera", z_range=(0, 1), vary=0.08)
	frame = []
	for x in (-0.5, 0.42):
		for y in (-0.5, 0.42):
			frame += p.box(x, x + 0.08, y, y + 0.08, 0.0, 1.0)
	for z in (0.0, 0.92):
		frame += p.box(-0.5, 0.5, -0.5, -0.42, z, z + 0.08) + p.box(-0.5, 0.5, 0.42, 0.5, z, z + 0.08)
		frame += p.box(-0.5, -0.42, -0.5, 0.5, z, z + 0.08) + p.box(0.42, 0.5, -0.5, 0.5, z, z + 0.08)
	p.paint(frame, "madera_oscura", "MID", vary=0.08)
	planks = []
	for z in (0.33, 0.64):
		planks += p.box(-0.42, 0.42, -0.5, -0.47, z - 0.015, z + 0.015)
	p.paint(planks, "madera_oscura", "DARK")


def fogata(p):
	ring = []
	for i in range(9):
		a = 2 * math.pi * i / 9
		ring += p.blob((math.cos(a) * 0.45, math.sin(a) * 0.45, 0.06), 0.13, squash=(1.2, 1, 0.7), subdiv=1, rough=0.25)
	p.paint(ring, "piedra", vary=0.15)
	logs = []
	for i in range(4):
		a = math.pi * i / 2 + 0.4
		log = p.cylinder(0.06, 0.0, 0.55, sides=6)
		p.transform(log, Matrix.Translation((math.cos(a) * 0.22, math.sin(a) * 0.22, 0.02)) @ Matrix.Rotation(-1.0, 4, Vector((-math.sin(a), math.cos(a), 0))))
		logs += log
	p.paint(logs, "madera_oscura", "DARK", vary=0.1)
	p.paint(p.cylinder(0.25, 0.0, 0.03, sides=8), "noche", "MID")


piece("vasija", 1, vasija)
piece("vasija_pedazos", 2, vasija_pedazos)
piece("estela", 3, estela)
piece("apacheta", 4, apacheta)
piece("cajon", 5, cajon)
piece("fogata", 6, fogata)


# --- cofres ---

def hollow_top(p, w, d, top, rim, swatch, inside="noche"):
	"""Borde de la boca (de top - 0.06 a top) y el fondo oscuro adentro, para que el cofre abierto se lea hueco."""
	ring = p.box(-w / 2, w / 2, -d / 2, -d / 2 + rim, top - 0.06, top) + p.box(-w / 2, w / 2, d / 2 - rim, d / 2, top - 0.06, top)
	ring += p.box(-w / 2, -w / 2 + rim, -d / 2 + rim, d / 2 - rim, top - 0.06, top) + p.box(w / 2 - rim, w / 2, -d / 2 + rim, d / 2 - rim, top - 0.06, top)
	p.paint(ring, swatch, "MID", vary=0.05)
	p.paint(p.box(-w / 2 + rim, w / 2 - rim, -d / 2 + rim, d / 2 - rim, top - 0.08, top - 0.06), inside, "LOW")


def chest_base(p, w, d, h, wood, metal):
	box = p.box(-w / 2, w / 2, -d / 2, d / 2, 0.0, h - 0.06)
	hollow_top(p, w, d, h, 0.07, wood)
	p.paint(box, wood, z_range=(0, h * 1.5), vary=0.05)
	bands = []
	for x in (-w / 2 + 0.1, w / 2 - 0.16):
		bands += p.box(x, x + 0.06, -d / 2 - 0.02, d / 2 + 0.02, -0.01, h + 0.005)
	bands += p.box(-w / 2 - 0.02, w / 2 + 0.02, -d / 2 - 0.02, d / 2 + 0.02, 0.0, 0.07)
	p.paint(bands, metal, "MID", vary=0.05)
	epi.chakana_plate(p, Vector((0, -d / 2 - 0.02, h - 0.12)), 0.2, metal)
	p.paint(p.box(-w / 2 + 0.1, w / 2 - 0.1, -d / 2 + 0.1, d / 2 - 0.1, h - 0.07, h - 0.02), "dorado", "LIGHT", vary=0.2)


def chest_lid(p, w, d, h, wood, metal):
	"""Tapa trapezoidal con la bisagra en el origen (arriba del borde de atrás de la base)."""
	lid = p.box(-w / 2, w / 2, -d, 0.0, 0.0, h, taper=0.0)
	for v in {v for f in lid for v in f.verts}:
		if v.co.z > h / 2:
			v.co.y = -d + 0.08 if v.co.y < -d / 2 else -0.08
			v.co.x *= 0.92
	p.paint(lid, wood, z_range=(-h, h * 1.3), vary=0.05)
	bands = []
	for x in (-w / 2 + 0.1, w / 2 - 0.16):
		b = p.box(x, x + 0.06, -d - 0.02, 0.02, -0.005, h * 0.5)
		bands += b
	p.paint(bands, metal, "MID", vary=0.05)
	p.paint(p.box(-w / 2 + 0.07, w / 2 - 0.07, -d + 0.07, -0.07, -0.01, 0.0), "madera_oscura", "DARK")


piece("cofre", 7, lambda p: chest_base(p, 1.0, 0.7, 0.5, "madera", "cobre_verde"))
piece("cofre_tapa", 8, lambda p: (chest_lid(p, 1.0, 0.7, 0.3, "madera", "cobre_verde"), {"bisagra": [0.0, 0.5, -0.35]})[1])
def arca(p, w, d, h):
	"""Cofre grande: arca de piedra del templo, con zócalo escalonado, guardas doradas y el ojo en el frente."""
	plinth = p.box(-w / 2 - 0.06, w / 2 + 0.06, -d / 2 - 0.06, d / 2 + 0.06, 0.0, 0.1)
	body = p.box(-w / 2, w / 2, -d / 2, d / 2, 0.1, h - 0.06)
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
	low = p.box(-w / 2 - 0.02, w / 2 + 0.02, -d - 0.02, 0.02, 0.0, h * 0.5)
	high = p.box(-w / 2 + 0.12, w / 2 - 0.12, -d + 0.12, -0.12, h * 0.5, h)
	p.paint(low + high, "piedra_templo", z_range=(-h, h * 1.4), vary=0.05)
	p.paint(p.box(-w / 2 + 0.1, w / 2 - 0.1, -d + 0.1, -0.1, -0.01, 0.0), "piedra_templo", "DARK")
	chakana = []
	for cw, cd in ((0.36, 0.12), (0.24, 0.24), (0.12, 0.36)):
		chakana += p.box(-cw / 2, cw / 2, -d / 2 - cd / 2, -d / 2 + cd / 2, h, h + 0.03)
	p.paint(chakana, "dorado", "LIGHT")


piece("cofre_grande", 9, lambda p: arca(p, 1.4, 0.95, 0.65))
piece("cofre_grande_tapa", 10, lambda p: (arca_tapa(p, 1.4, 0.95, 0.35), {"bisagra": [0.0, 0.65, -0.475]})[1])


# --- llaves y objetos de mazmorra ---

def key(p, length, metal, boss=False):
	"""Llave acostada sobre XY, con el ojal en -X: un ojo (anillo con pupila) o, la del jefe, una chakana."""
	parts = []
	shaft = p.box(-length * 0.15, length * 0.55, -0.025, 0.025, -0.025, 0.025)
	parts += shaft
	parts += p.box(length * 0.4, length * 0.48, -0.12, -0.025, -0.025, 0.025)
	parts += p.box(length * 0.5, length * 0.56, -0.09, -0.025, -0.025, 0.025)
	if boss:
		s = length * 0.36
		for w, h in ((s, s * 0.34), (s * 0.67, s * 0.67), (s * 0.34, s)):
			parts += p.box(-length * 0.32 - w / 2, -length * 0.32 + w / 2, -h / 2, h / 2, -0.03, 0.03)
	else:
		r = length * 0.17
		ring = p.cylinder(r, -0.03, 0.03, sides=10)
		p.transform(ring, Matrix.Translation((-length * 0.32, 0, 0)))
		parts += ring
	p.paint(parts, metal, "MID", vary=0.08)
	center = p.cylinder(length * 0.06, -0.04, 0.04, sides=8)
	p.transform(center, Matrix.Translation((-length * 0.32, 0, 0)))
	p.paint(center, "noche" if not boss else "doom", "MID")
	everything = parts + center
	p.transform(everything, Matrix.Translation((0, 0, 0.04)))


piece("llave", 11, lambda p: key(p, 0.5, "cobre_verde"))
piece("llave_jefe", 12, lambda p: key(p, 0.75, "dorado", boss=True))


def mapa(p):
	"""Tela enrollada en franjas (rojo, crema, azul) con un cordón."""
	bands = [(-0.3, -0.2, "tela_roja"), (-0.2, -0.07, "hueso"), (-0.07, 0.07, "tela_azul"), (0.07, 0.2, "hueso"), (0.2, 0.3, "tela_roja")]
	for x0, x1, swatch in bands:
		seg = p.cylinder(0.08, x0, x1, sides=10)
		p.transform(seg, Matrix.Translation((0, 0, 0.08)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
		p.paint(seg, swatch, "MID")
	cord = p.cylinder(0.088, -0.02, 0.02, sides=10)
	p.transform(cord, Matrix.Translation((0.13, 0, 0.08)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
	p.paint(cord, "paja", "DARK")


def brujula(p):
	"""Disco de piedra con una aguja de obsidiana y cuatro marcas."""
	disk = p.cylinder(0.26, 0.0, 0.08, sides=12)
	p.paint(disk, "piedra", "MID", vary=0.05)
	rim = p.cylinder(0.28, 0.0, 0.05, sides=12)
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


piece("mapa", 13, mapa)
piece("brujula", 14, brujula)


def heart_points(size, steps=20):
	pts = []
	for i in range(steps):
		t = 2 * math.pi * i / steps
		x = 16 * math.sin(t) ** 3
		y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
		pts.append((x / 16 * size, y / 16 * size))
	return pts


def heart(p, size, thick, swatch="tela_roja"):
	"""Corazón parado, mirando a -Y."""
	h = p.polygon(heart_points(size), -thick / 2, thick / 2)
	p.transform(h, Matrix.Translation((0, 0, size * 1.05)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	p.paint(h, swatch, z_range=(0, size * 2.1), vary=0.03)
	return h


def contenedor(p):
	heart(p, 0.32, 0.14)
	ring = []
	for i in range(8):
		a = 2 * math.pi * i / 8
		b = p.box(-0.04, 0.04, -0.04, 0.04, -0.04, 0.04)
		p.transform(b, Matrix.Translation((math.cos(a) * 0.42, 0, 0.36 + math.sin(a) * 0.42)))
		ring += b
	p.paint(ring, "dorado", "LIGHT")


piece("corazon", 15, lambda p: heart(p, 0.2, 0.1))
piece("contenedor_corazon", 16, contenedor)


# --- proyectiles y municiones ---

def arrow(p, length=0.9):
	"""Flecha a lo largo de +X: caña, punta de obsidiana y plumas."""
	shaft = p.box(0.0, length * 0.86, -0.012, 0.012, -0.012, 0.012)
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
	body = p.lathe([(0.0, 0.0), (radius * 0.7, radius * 0.1), (radius, radius * 0.9), (radius * 0.8, radius * 1.6), (radius * 0.35, radius * 1.9), (radius * 0.35, radius * 2.05), (0.0, radius * 2.05)], sides=10)
	p.paint_bands(body, [(radius * 1.05, radius * 1.25, "noche", "MID")], default=(0, 0, "roca_naranja", "DARK"))
	fuse = p.cylinder(0.02, radius * 2.0, radius * 2.0 + 0.16, sides=4, radius_top=0.015)
	p.transform(fuse, Matrix.Rotation(0.3, 4, "X"))
	p.paint(fuse, "paja", "MID")


def bombas_x3(p):
	for i, (x, y) in enumerate(((-0.15, 0.0), (0.15, 0.02), (0.0, 0.2))):
		q = epi.Piece(i)
		bomb(q, 0.13)
		q.transform(list(q.bm.faces), Matrix.Translation((x, y, 0)))
		p.merge(q)


def orbe(p):
	core = p.blob((0, 0, 0), 0.22, subdiv=1, rough=0.0)
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


piece("flecha", 17, flecha)
piece("flechas_x5", 18, flechas_x5)
piece("bomba", 19, lambda p: bomb(p))
piece("bombas_x3", 20, bombas_x3)
piece("orbe", 21, orbe)
piece("explosion", 22, explosion)

epi.layout(kit, columns=6, spacing=2.0)
epi.save("objetos")
