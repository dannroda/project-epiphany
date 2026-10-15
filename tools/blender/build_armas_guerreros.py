# Publica assets/epiphany/armas_guerreros.glb: las armas de los enemigos comunes de cada mazmorra (12.39), en los ejes
# de build_equipo.py: arma_<mazmorra> sobre +Z con la empuñadura en el origen (la de espada), escudo_<mazmorra> en el
# plano XZ con el frente a -Y y radio ~0.44 (el de escudo_madera), arco_<mazmorra> sobre Y con el lomo a +X, la cuerda
# en x -0.2 y el shape key «tensado» de arco (BowModel), y armadura_<mazmorra> en los ejes de armadura (la del acorazado).
# blender -b --factory-startup -P tools/blender/build_armas_guerreros.py
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

kit = epi.start()
UPRIGHT = Matrix.Rotation(math.pi / 2, 4, "X")
GLOW = "doom"


def piece(name, seed, fn, smooth=40):
	p = epi.Piece(seed)
	keys = fn(p) or {}
	obj = p.build(name, kit, smooth=smooth)
	if keys:
		obj.shape_key_add(name="Basis")
	for key_name, move in keys.items():
		key = obj.shape_key_add(name=key_name, from_mix=False)
		key.value = 0.0
		for i, v in enumerate(obj.data.vertices):
			key.data[i].co = move(i, v.co.copy())
	return obj


def flat(p, points, thickness, y=0.0):
	if sum(x0 * z1 - x1 * z0 for (x0, z0), (x1, z1) in zip(points, points[1:] + points[:1])) < 0:
		points = points[::-1]
	f = p.polygon(points, y - thickness / 2, y + thickness / 2)
	p.transform(f, UPRIGHT)
	return f


def bands(p, swatch, radius, zs, height=0.05, sides=8):
	faces = []
	for z in zs:
		faces += p.cylinder(radius, z, z + height, sides=sides)
	p.paint(faces, swatch, "MID")


def spike(p, at, angle, length, radius, sides=4):
	s = p.cylinder(radius, 0.0, length, sides=sides, radius_top=radius * 0.15, phase=math.pi / 4)
	p.transform(s, Matrix.Translation(at) @ Matrix.Rotation(angle, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "Y"))
	return s


# --- armas de mano ---


def arma_chullpa(p):
	"""Hacha de cobre de las chullpas: mango de hueso con tiento rojo y una hoja de media luna verdosa con púa atrás."""
	p.paint(p.cylinder(0.038, -0.36, 1.1, sides=8, radius_top=0.032), "hueso", "MID", vary=0.05)
	bands(p, "tela_roja", 0.045, (-0.3, -0.2, -0.1, 0.0), 0.06)
	knob = p.blob((0, 0, -0.4), 0.06, subdiv=1, rough=0.1)
	p.paint(knob, "hueso", "LIGHT")
	blade = flat(p, [(0.03, 0.78), (0.18, 0.76), (0.34, 0.66), (0.42, 0.8), (0.44, 0.96), (0.4, 1.12), (0.32, 1.24), (0.18, 1.12), (0.03, 1.1)], 0.05)
	p.paint(blade, "cobre_verde", z_range=(0.6, 1.3), vary=0.08)
	edge = flat(p, [(0.36, 0.7), (0.42, 0.8), (0.44, 0.96), (0.4, 1.12), (0.33, 1.22), (0.37, 1.1), (0.4, 0.96), (0.38, 0.8)], 0.06)
	p.paint(edge, "dorado", "LIGHT")
	back = flat(p, [(-0.03, 0.86), (-0.2, 0.93), (-0.03, 1.0)], 0.04)
	p.paint(back, "cobre_verde", "DARK")
	lash = p.cylinder(0.05, 0.84, 1.04, sides=8)
	p.paint(lash, "tierra", "MID", vary=0.1)


def arma_quenoa(p):
	"""Macana de queñoa: garrote de corteza roja que engorda hacia la punta, con espinas oscuras y musgo."""
	club = p.lathe([(0.0, -0.4), (0.045, -0.38), (0.045, 0.05), (0.07, 0.45), (0.11, 0.85), (0.13, 1.08), (0.1, 1.24), (0.0, 1.28)], sides=8)
	p.jitter(club, 0.012)
	p.paint(club, "roca_naranja", z_range=(-0.4, 1.3), vary=0.1)
	bands(p, "follaje", 0.052, (-0.34, -0.22, -0.1), 0.07)
	thorns = []
	for k in range(9):
		a = k * 2.4
		z = 0.6 + (k % 3) * 0.2 + k * 0.02
		thorns += spike(p, (0.09 * math.cos(a), 0.09 * math.sin(a), z), a, 0.12, 0.025)
	p.paint(thorns, "madera_oscura", "DARK")
	moss = p.blob((0.02, 0.03, 1.12), 0.12, squash=(1.0, 1.0, 0.6), subdiv=2, rough=0.2)
	p.paint(moss, "musgo", "MID", vary=0.1)


def arma_totora(p):
	"""Lanza corta de los uros: asta de junco atada con tiento azul y una punta de obsidiana en forma de hoja."""
	p.paint(p.cylinder(0.032, -0.4, 1.2, sides=6), "paja", "MID", vary=0.08)
	bands(p, "tela_azul", 0.04, (-0.32, -0.12, 0.5, 1.12), 0.07, sides=6)
	tip = flat(p, [(0.0, 1.14), (0.09, 1.3), (0.07, 1.48), (0.0, 1.66), (-0.07, 1.48), (-0.09, 1.3)], 0.04)
	p.paint(tip, "noche", "MID", vary=0.05)
	edge = flat(p, [(0.0, 1.2), (0.02, 1.3), (0.015, 1.5), (0.0, 1.58), (-0.015, 1.5), (-0.02, 1.3)], 0.05)
	p.paint(edge, GLOW, "MID")
	tuft = []
	for k in range(5):
		f = p.box(-0.01, 0.01, -0.01, 0.01, 0.0, 0.22, taper=0.008)
		p.transform(f, Matrix.Translation((0, 0, 1.06)) @ Matrix.Rotation(k * 1.26, 4, "Z") @ Matrix.Rotation(2.6, 4, "X"))
		tuft += f
	p.paint(tuft, "paja", "LIGHT")


def arma_cumbre(p):
	"""Espada de hielo de la cumbre: hoja de cristal astillada, guarda de cuerno y empuñadura de lana con franjas."""
	blade = flat(p, [(0.0, 0.05), (0.08, 0.1), (0.1, 0.42), (0.06, 0.5), (0.11, 0.86), (0.07, 0.95), (0.08, 1.24), (0.0, 1.46), (-0.07, 1.2), (-0.1, 0.9), (-0.06, 0.78), (-0.1, 0.4), (-0.08, 0.1)], 0.06)
	p.paint(blade, "cristal", z_range=(0.0, 1.5), vary=0.06)
	core = flat(p, [(0.0, 0.1), (0.025, 0.2), (0.02, 1.1), (0.0, 1.25), (-0.02, 1.1), (-0.025, 0.2)], 0.07)
	p.paint(core, "blanco", "LIGHT")
	horn = []
	for side in (-1, 1):
		h = p.cylinder(0.05, 0.0, 0.22, sides=6, radius_top=0.01)
		p.transform(h, Matrix.Rotation(side * 1.2, 4, "Y"))
		horn += h
	p.paint(horn, "hueso", "MID")
	grip = []
	for i in range(5):
		z = -0.07 - i * 0.055
		grip += p.cylinder(0.044, z - 0.05, z, sides=8)
	p.paint_bands(grip, [(-0.13, -0.07, "tela_azul", "MID"), (-0.24, -0.18, "tela_azul", "MID"), (-0.35, -0.29, "tela_azul", "MID")], default=(0, 0, "blanco", "MID"))
	pom = p.blob((0, 0, -0.42), 0.07, subdiv=1, rough=0.0)
	p.paint(pom, "blanco", "LIGHT")


def arma_templo(p):
	"""Tumi del templo: vara de obsidiana con anillos de oro y la media luna del tumi en la punta, con el ojo del logo."""
	p.paint(p.cylinder(0.04, -0.4, 0.86, sides=8), "noche", "MID")
	bands(p, "dorado", 0.05, (-0.38, 0.02, 0.4, 0.8), 0.05)
	neck = flat(p, [(-0.06, 0.82), (0.06, 0.82), (0.1, 0.98), (-0.1, 0.98)], 0.06)
	p.paint(neck, "dorado", "MID")
	moon = [(0.0, 0.94)]
	for i in range(13):
		a = math.pi * i / 12
		moon.append((0.34 * math.cos(a), 0.94 + 0.38 * math.sin(a)))
	half = flat(p, list(reversed(moon[1:])), 0.05)
	p.paint(half, "dorado", z_range=(0.9, 1.35), vary=0.04)
	outer = [(0.34 * math.cos(math.pi * i / 12), 0.94 + 0.38 * math.sin(math.pi * i / 12)) for i in range(13)]
	inner = [(0.3 * math.cos(math.pi * i / 12), 0.94 + 0.34 * math.sin(math.pi * i / 12)) for i in range(12, -1, -1)]
	edge = flat(p, outer + inner, 0.06)
	p.paint(edge, GLOW, "LIGHT")
	for turn in (0.0, math.pi):
		eye = epi.logo_eye(p, Vector((0, 0, 0)), 0.3, depth=0.012, iris=(GLOW, "MID"))
		p.transform(eye, Matrix.Rotation(turn, 4, "Z") @ Matrix.Translation((0, -0.03, 1.08)))


# --- escudos ---


def rim(p, swatch, r=0.44, sides=16):
	f = p.lathe([(r + 0.01, -0.045), (r + 0.03, 0.0), (r + 0.01, 0.045), (r - 0.04, 0.045), (r - 0.04, -0.045), (r + 0.01, -0.045)], sides=sides, caps=False)
	p.transform(f, UPRIGHT)
	p.paint(f, swatch, "MID")


def escudo_chullpa(p):
	"""Cuero tensado sobre costillas de hueso, borde de cobre y una franja escalonada roja."""
	hide = p.cylinder(0.42, -0.03, 0.03, sides=16)
	p.transform(hide, UPRIGHT)
	p.paint(hide, "tierra", "MID", vary=0.08)
	rim(p, "cobre_verde")
	ribs = []
	for x in (-0.22, 0.0, 0.22):
		h = math.sqrt(0.4 ** 2 - x * x)
		ribs += p.rounded_box(x - 0.035, x + 0.035, -0.07, -0.03, -h, h, radius=0.015, segments=1)
	p.paint(ribs, "hueso", "LIGHT", vary=0.05)
	steps = []
	for w, z in ((0.6, -0.04), (0.44, 0.04), (0.28, 0.12)):
		steps += p.box(-w / 2, w / 2, -0.05, -0.035, z - 0.04, z + 0.04)
	p.paint(steps, "tela_roja", "MID")


def escudo_quenoa(p):
	"""Rodaja de tronco de queñoa: corteza roja alrededor, anillos de madera al frente y un mechón de musgo."""
	slab = p.cylinder(0.42, -0.05, 0.05, sides=12)
	p.transform(slab, UPRIGHT)
	p.jitter(slab, 0.015)
	p.paint(slab, "roca_naranja", "MID", vary=0.1)
	rings = []
	for k, r in enumerate((0.34, 0.25, 0.16, 0.07)):
		ring = p.cylinder(r, 0.05 + k * 0.004, 0.056 + k * 0.004, sides=12)
		p.transform(ring, UPRIGHT)
		p.paint(ring, "madera" if k % 2 == 0 else "madera_oscura", "MID")
		rings += ring
	moss = p.blob((0.22, -0.02, 0.32), 0.14, squash=(1.2, 0.8, 0.6), subdiv=2, rough=0.2)
	p.paint(moss, "musgo", "MID", vary=0.1)


def escudo_totora(p):
	"""Escudo ovalado de junco: varas horizontales atadas con dos tientos azules."""
	rods = []
	for i in range(11):
		z = -0.48 + i * 0.096
		w = 0.38 * math.sqrt(max(1 - (z / 0.52) ** 2, 0.05))
		rod = p.cylinder(0.05, -w, w, sides=6)
		p.transform(rod, Matrix.Translation((0, 0, z)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
		rods += rod
	p.paint(rods, "paja", z_range=(-0.5, 0.5), vary=0.1)
	ties = []
	for x in (-0.14, 0.14):
		ties += p.box(x - 0.03, x + 0.03, -0.065, 0.065, -0.44, 0.44)
	p.paint(ties, "tela_azul", "MID")
	disc = p.cylinder(0.08, 0.06, 0.09, sides=8)
	p.transform(disc, UPRIGHT)
	p.paint(disc, "cobre_verde", "LIGHT")


def escudo_cumbre(p):
	"""Losa hexagonal de hielo con borde de escarcha y un copo blanco al frente."""
	slab = p.cylinder(0.43, -0.04, 0.04, sides=6, phase=math.pi / 6)
	p.transform(slab, UPRIGHT)
	p.paint(slab, "cristal", z_range=(-0.5, 0.5), vary=0.06)
	rim(p, "blanco", 0.43, 6)
	flake = []
	for k in range(3):
		bar = p.box(-0.3, 0.3, -0.07, -0.04, -0.03, 0.03)
		p.transform(bar, Matrix.Rotation(k * math.pi / 3, 4, "Y"))
		flake += bar
	for k in range(6):
		a = k * math.pi / 3
		tip = p.box(-0.06, 0.06, -0.07, -0.04, -0.02, 0.02)
		p.transform(tip, Matrix.Rotation(a, 4, "Y") @ Matrix.Translation((0.2, 0, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
		flake += tip
	p.paint(flake, "blanco", "LIGHT")


def escudo_templo(p):
	"""Disco de obsidiana con borde y rayos de oro, y el ojo del logo con el iris del doom."""
	disk = p.cylinder(0.4, -0.04, 0.04, sides=24)
	p.transform(disk, UPRIGHT)
	p.paint(disk, "noche", "MID")
	rim(p, "dorado", 0.4, 24)
	rays = []
	for i in range(8):
		ray = flat(p, [(-0.05, 0.42), (0.05, 0.42), (0.0, 0.56)], 0.05)
		p.transform(ray, Matrix.Rotation(2 * math.pi * i / 8 + math.pi / 8, 4, "Y"))
		rays += ray
	p.paint(rays, "dorado", "LIGHT")
	epi.logo_eye(p, Vector((0, -0.045, 0.0)), 0.4, depth=0.015, iris=(GLOW, "MID"))


# --- arcos ---


def arco(p, limb, tip, wrap, cord, deco=None):
	"""El arco de build_equipo.arco con otros materiales; deco(p, side) agrega adornos en cada punta (y = side * 0.98)."""
	half, brace = 0.98, 0.2

	def limb_x(t):
		return -brace * t ** 1.8

	limbs = []
	for side in (-1, 1):
		prev = Vector((0.0, 0.0, 0.0))
		for k in range(1, 9):
			t = k / 8
			cur = Vector((limb_x(t), side * half * t, 0.0))
			seg = cur - prev
			c = p.cylinder(0.038 - 0.017 * (t - 1 / 8), 0.0, seg.length, sides=8, radius_top=0.038 - 0.017 * t)
			p.transform(c, Matrix.Translation(prev) @ seg.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4())
			limbs += c
			prev = cur
	p.paint(limbs, *limb)
	tips = []
	for side in (-1, 1):
		tips += p.blob((-brace, side * half, 0.0), 0.04, subdiv=2, rough=0.0)
		if deco:
			deco(p, side)
	p.paint(tips, *tip)
	grip = p.rounded_box(-0.055, 0.055, -0.11, 0.11, -0.048, 0.048, radius=0.02, segments=2)
	p.paint(grip, wrap, "MID")
	string = []
	for side in (-1, 1):
		lo, hi = sorted((0.0, side * half))
		string += p.box(-brace - 0.006, -brace + 0.006, lo, hi, -0.006, 0.006)
	p.paint(string, cord, "LIGHT")
	p.bm.verts.index_update()
	cords = {v.index for f in string for v in f.verts}
	draw, bend, squeeze = 0.38, 0.1, 0.05

	def tensado(i, co):
		s = min(abs(co.y) / half, 1.0)
		if i in cords:
			end = Vector((-brace - bend, math.copysign(half * (1 - squeeze), co.y), 0.0))
			return Vector((-brace - draw, 0.0, 0.0)).lerp(end, s) + Vector((co.x + brace, 0.0, co.z))
		return Vector((co.x - bend * s ** 2, co.y * (1 - squeeze * s ** 2), co.z))

	return {"tensado": tensado}


def deco_feathers(swatch):
	def deco(p, side):
		f = []
		for k in (-1, 1):
			fe = p.box(-0.015, 0.015, 0.0, 0.16, -0.035, 0.035, taper=0.02)
			p.transform(fe, Matrix.Translation((-0.22, side * 0.9, 0)) @ Matrix.Rotation(side * (math.pi / 2 + 0.5) + k * 0.25, 4, "Z"))
			f += fe
		p.paint(f, swatch, "MID")
	return deco


def deco_leaves(p, side):
	f = []
	for k in (-1, 1):
		leaf = p.blob((0, 0, 0), 0.06, squash=(0.5, 1.6, 0.25), subdiv=1, rough=0.0)
		p.transform(leaf, Matrix.Translation((-0.24 + k * 0.04, side * 0.92, 0.02 * k)) @ Matrix.Rotation(k * 0.6, 4, "Z"))
		f += leaf
	p.paint(f, "follaje", "MID", vary=0.1)


def deco_ice(p, side):
	f = p.cylinder(0.04, 0.0, 0.16, sides=4, radius_top=0.005, phase=math.pi / 4)
	p.transform(f, Matrix.Translation((-0.2, side * 0.98, 0)) @ Matrix.Rotation(-side * math.pi / 2, 4, "X"))
	p.paint(f, "cristal", "LIGHT")


def deco_sun(p, side):
	f = []
	for k in range(5):
		ray = p.box(-0.012, 0.012, 0.0, 0.1, -0.012, 0.012, taper=0.008)
		p.transform(ray, Matrix.Translation((-0.2, side * 0.98, 0)) @ Matrix.Rotation(side * (k - 2) * 0.5 + (0 if side > 0 else math.pi), 4, "Z"))
		f += ray
	p.paint(f, "dorado", "LIGHT")


# --- armaduras (los ejes de build_equipo.armadura: el pecho desde z 0, frente a -Y, hombreras en x ±0.36) ---


def torso(p, swatch, shade="MID"):
	p.paint(p.box(-0.22, 0.22, -0.16, 0.16, 0.0, 0.58), swatch, shade)


def shoulders(p, swatch, shade="MID", radius=0.07):
	faces = []
	for side in (-1, 1):
		x = side * 0.36
		faces += p.rounded_box(x - 0.17, x + 0.17, -0.17, 0.17, 0.38, 0.64, radius=radius)
	p.paint(faces, swatch, shade, vary=0.05)
	return faces


def armadura_chullpa(p):
	"""Cuero curtido con costillas de hueso al frente, hombreras de cobre y faldón rojo."""
	torso(p, "tierra")
	p.paint(p.box(-0.26, 0.26, -0.22, 0.12, 0.2, 0.58, taper=0.03), "tierra", "LOW", vary=0.06)
	ribs = []
	for k in range(4):
		z = 0.26 + k * 0.08
		w = 0.2 - abs(k - 1.5) * 0.02
		for side in (-1, 1):
			ribs += p.rounded_box(min(side * 0.03, side * (0.03 + w)), max(side * 0.03, side * (0.03 + w)), -0.26, -0.21, z, z + 0.045, radius=0.015, segments=1)
	ribs += p.box(-0.03, 0.03, -0.26, -0.21, 0.22, 0.58)
	p.paint(ribs, "hueso", "LIGHT", vary=0.05)
	shoulders(p, "cobre_verde")
	p.paint(p.box(-0.17, 0.17, -0.22, -0.18, -0.3, 0.02), "tela_roja", "MID")
	p.paint(p.box(-0.26, 0.26, -0.19, 0.19, -0.04, 0.04), "cobre_verde", "DARK")


def armadura_quenoa(p):
	"""Placas de corteza roja de queñoa atadas, musgo sobre las hombreras y cinto de madera."""
	torso(p, "madera_oscura")
	plates = []
	for i, (z0, z1) in enumerate(((0.2, 0.34), (0.33, 0.47), (0.46, 0.6))):
		for side in (-1, 1):
			plates += p.box(side * 0.005, side * 0.26, -0.22 - i * 0.005, 0.12, z0, z1, taper=0.015)
	p.jitter(plates, 0.01)
	p.paint(plates, "roca_naranja", z_range=(0.1, 0.7), vary=0.1)
	shoulders(p, "roca_naranja", radius=0.05)
	for side in (-1, 1):
		moss = p.blob((side * 0.36, 0.0, 0.64), 0.13, squash=(1.2, 1.1, 0.5), subdiv=2, rough=0.2)
		p.paint(moss, "musgo", "MID", vary=0.1)
	p.paint(p.box(-0.26, 0.26, -0.19, 0.19, -0.04, 0.05), "madera", "MID")
	p.paint(p.box(-0.15, 0.15, -0.22, -0.18, -0.28, 0.02), "follaje", "MID", vary=0.08)


def armadura_totora(p):
	"""Chaleco de varas de junco atado con tiento azul, hombreras de atados de junco."""
	torso(p, "tela_azul", "DARK")
	rods = []
	for k in range(9):
		z = 0.18 + k * 0.05
		rod = p.cylinder(0.028, -0.26, 0.26, sides=6)
		p.transform(rod, Matrix.Translation((0, -0.2, z)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
		rods += rod
	p.paint(rods, "paja", z_range=(0.1, 0.7), vary=0.1)
	ties = []
	for x in (-0.12, 0.12):
		ties += p.box(x - 0.025, x + 0.025, -0.24, -0.17, 0.16, 0.62)
	p.paint(ties, "tela_azul", "MID")
	bundles = []
	for side in (-1, 1):
		for k in range(3):
			b = p.cylinder(0.05, -0.17, 0.17, sides=6)
			p.transform(b, Matrix.Translation((side * (0.27 + k * 0.08), 0, 0.6 - k * 0.04)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
			bundles += b
	p.paint(bundles, "paja", "LIGHT", vary=0.08)
	p.paint(p.box(-0.16, 0.16, -0.22, -0.18, -0.3, 0.02), "paja", "MID", vary=0.1)


def armadura_cumbre(p):
	"""Poncho de lana blanca con franjas azules y hombreras de hielo."""
	torso(p, "gris_2")
	cuts = (0.0, 0.12, 0.17, 0.3, 0.34, 0.46, 0.5, 0.6)
	for k, (z0, z1) in enumerate(zip(cuts, cuts[1:])):
		w = 0.28 - 0.04 * z0 / 0.6
		p.paint(p.box(-w, w, -0.22, 0.2, z0, z1), "tela_azul" if k % 2 else "blanco", "MID")
	ice = []
	for side in (-1, 1):
		x = side * 0.36
		ice += p.cylinder(0.16, 0.42, 0.62, sides=6, radius_top=0.1, center=(x, 0.0))
		for k in range(3):
			c = p.cylinder(0.04, 0.0, 0.14, sides=4, radius_top=0.004, phase=math.pi / 4)
			p.transform(c, Matrix.Translation((x + side * (k - 1) * 0.08, (k - 1) * 0.05, 0.6)) @ Matrix.Rotation(side * 0.4, 4, "Y"))
			ice += c
	p.paint(ice, "cristal", "LIGHT", vary=0.05)
	p.paint(p.box(-0.18, 0.18, -0.23, -0.2, -0.3, 0.02), "blanco", "MID")


def armadura_templo(p):
	"""Peto de oro sobre negro con el ojo del logo (iris del doom), hombreras de sol con rayos."""
	torso(p, "noche")
	plate = p.box(-0.26, 0.26, -0.22, 0.12, 0.2, 0.58, taper=0.03)
	p.paint_bands(plate, [(0.27, 0.3, GLOW, "MID")], default=(0, 0, "dorado", "MID"))
	epi.logo_eye(p, Vector((0, -0.225, 0.44)), 0.24, depth=0.012, iris=(GLOW, "MID"))
	shoulders(p, "dorado")
	rays = []
	for side in (-1, 1):
		for k in range(5):
			r = p.box(-0.02, 0.02, -0.02, 0.02, 0.0, 0.12, taper=0.015)
			p.transform(r, Matrix.Translation((side * 0.36, 0, 0.62)) @ Matrix.Rotation(side * (k - 2) * 0.45, 4, "Y"))
			rays += r
	p.paint(rays, "dorado", "LIGHT")
	p.paint(p.lathe([(0.2, 0.55), (0.22, 0.62), (0.0, 0.62)], sides=16), "dorado", "MID")
	p.paint(p.box(-0.17, 0.17, -0.22, -0.18, -0.3, 0.02), "noche", "MID")
	p.paint(p.box(-0.26, 0.26, -0.19, 0.19, -0.04, 0.04), "dorado", "MID")


piece("arma_chullpa", 1, arma_chullpa)
piece("arma_quenoa", 2, arma_quenoa)
piece("arma_totora", 3, arma_totora)
piece("arma_cumbre", 4, arma_cumbre)
piece("arma_templo", 5, arma_templo)
piece("escudo_chullpa", 6, escudo_chullpa)
piece("escudo_quenoa", 7, escudo_quenoa)
piece("escudo_totora", 8, escudo_totora)
piece("escudo_cumbre", 9, escudo_cumbre)
piece("escudo_templo", 10, escudo_templo)
piece("arco_chullpa", 11, lambda p: arco(p, ("hueso", "MID"), ("cobre_verde", "MID"), "tela_roja", "tierra", deco_feathers("tela_roja")))
piece("arco_quenoa", 12, lambda p: arco(p, ("roca_naranja", "MID"), ("madera_oscura", "MID"), "musgo", "paja", deco_leaves))
piece("arco_totora", 13, lambda p: arco(p, ("paja", "MID"), ("tela_azul", "MID"), "tela_azul", "paja", deco_feathers("tela_azul")))
piece("arco_cumbre", 14, lambda p: arco(p, ("gris_2", "MID"), ("cristal", "LIGHT"), "blanco", "blanco", deco_ice))
piece("arco_templo", 15, lambda p: arco(p, ("noche", "MID"), ("dorado", "MID"), "dorado", "dorado", deco_sun))
for i, d in enumerate(("chullpa", "quenoa", "totora", "cumbre", "templo")):
	piece("armadura_" + d, 16 + i, globals()["armadura_" + d])
epi.layout(kit, columns=5, spacing=2.0)
epi.publish("armas_guerreros")
