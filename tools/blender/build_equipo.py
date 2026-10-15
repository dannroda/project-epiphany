# Publica assets/epiphany/equipo.glb (epi.publish; el .blend de trabajo en art/blender/): armas, escudos y objetos del inventario, con los ejes de KayKit Adventurers:
# espada sobre +Z con la empuñadura en el origen; escudos en el plano XZ con el frente hacia -Y; arco sobre Y.
# blender -b -P tools/blender/build_equipo.py
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

kit = epi.start()
UPRIGHT = Matrix.Rotation(math.pi / 2, 4, "X")


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


def flat(p, points, thickness):
	"""Polígono en el plano XZ con espesor en Y."""
	f = p.polygon(points, -thickness / 2, thickness / 2)
	p.transform(f, UPRIGHT)
	return f


def espada(p):
	blade_pts = [(0.0, 0.06), (0.07, 0.1), (0.085, 0.55), (0.1, 0.95), (0.06, 1.25), (0.0, 1.42), (-0.06, 1.25), (-0.1, 0.95), (-0.085, 0.55), (-0.07, 0.1)]
	blade = flat(p, blade_pts, 0.045)
	p.paint(blade, "dorado", z_range=(-0.4, 1.8), vary=0.03)
	ridge = flat(p, [(0.0, 0.12), (0.015, 0.2), (0.012, 1.2), (0.0, 1.3), (-0.012, 1.2), (-0.015, 0.2)], 0.06)
	p.paint(ridge, "neon", "MID")
	guard = []
	for w, h, z in ((0.5, 0.07, 0.0), (0.32, 0.12, 0.0), (0.16, 0.18, 0.0)):
		guard += p.rounded_box(-w / 2, w / 2, -0.05, 0.05, z - h / 2, z + h / 2, radius=0.02, segments=2)
	p.paint(guard, "cobre_verde", "MID", vary=0.05)
	grip = []
	for i in range(5):
		z = -0.07 - i * 0.055
		grip += p.cylinder(0.042, z - 0.05, z, sides=12)
	p.paint_bands(grip, [(-0.13, -0.07, "tela_roja", "MID"), (-0.24, -0.18, "tela_roja", "MID"), (-0.35, -0.29, "tela_roja", "MID")], default=(0, 0, "hueso", "MID"))
	pommel = p.rounded_box(-0.07, 0.07, -0.06, 0.06, -0.37, -0.33, radius=0.015, segments=2) + p.blob((0, 0, -0.39), 0.05, subdiv=2, rough=0.0)
	p.paint(pommel, "cobre_verde", "LIGHT")


def espada_dorada(p):
	"""La espada del templo: la misma empuñadura que espada, con hoja de oro más ancha y escalonada (media chakana) en la
	base, filo claro, canal rojo que brilla, guarda de sol con el ojo del logo en las dos caras y pomo de chakana."""
	blade_pts = [(0.0, 0.06), (0.11, 0.08), (0.11, 0.16), (0.085, 0.16), (0.085, 0.24), (0.095, 0.6), (0.11, 0.98), (0.07, 1.27), (0.0, 1.44),
		(-0.07, 1.27), (-0.11, 0.98), (-0.095, 0.6), (-0.085, 0.24), (-0.085, 0.16), (-0.11, 0.16), (-0.11, 0.08)]
	blade = flat(p, blade_pts, 0.045)
	p.paint(blade, "dorado", z_range=(-0.2, 1.6), vary=0.03)
	edge = []
	for side in (-1, 1):
		edge += flat(p, [(side * x, z) for x, z in ((0.07, 0.3), (0.094, 0.6), (0.108, 0.98), (0.068, 1.27), (0.0, 1.44), (0.05, 1.25), (0.08, 0.98), (0.066, 0.6), (0.05, 0.3))][::side], 0.05)
	p.paint(edge, "hueso", "LIGHT")
	ridge = flat(p, [(0.0, 0.2), (0.02, 0.28), (0.016, 1.18), (0.0, 1.3), (-0.016, 1.18), (-0.02, 0.28)], 0.06)
	p.paint(ridge, "doom", "MID")
	guard = p.rounded_box(-0.3, 0.3, -0.05, 0.05, -0.04, 0.04, radius=0.02, segments=2)
	guard += p.rounded_box(-0.17, 0.17, -0.055, 0.055, -0.08, 0.06, radius=0.02, segments=2)
	rays = []
	for a in (-70, -40, 40, 70):
		r = p.box(-0.022, 0.022, -0.04, 0.04, 0.0, 0.13, taper=0.012)
		p.transform(r, Matrix.Translation((0.0, 0.0, 0.0)) @ Matrix.Rotation(math.radians(a), 4, "Y") @ Matrix.Translation((0, 0, 0.12)))
		rays += r
	for side in (-1, 1):
		tip = p.blob((side * 0.32, 0, 0), 0.045, subdiv=1, rough=0.0)
		guard += tip
	p.paint(guard + rays, "dorado", "LOW", vary=0.04)
	for turn in (0.0, math.pi):
		eye = epi.logo_eye(p, Vector((0, -0.058, 0.0)), 0.26, depth=0.015)
		p.transform(eye, Matrix.Rotation(turn, 4, "Z"))
	grip = []
	for i in range(5):
		z = -0.07 - i * 0.055
		grip += p.cylinder(0.042, z - 0.05, z, sides=12)
	p.paint_bands(grip, [(-0.13, -0.07, "dorado", "MID"), (-0.24, -0.18, "dorado", "MID"), (-0.35, -0.29, "dorado", "MID")], default=(0, 0, "tela_roja", "MID"))
	collar = p.cylinder(0.055, -0.38, -0.34, sides=12)
	p.paint(collar, "dorado", "MID")
	pommel = epi.chakana_plate(p, Vector((0, 0.0, -0.45)), 0.16, "dorado")
	back = epi.chakana_plate(p, Vector((0, 0.0, 0.0)), 0.16, "dorado")
	p.transform(back, Matrix.Translation((0, 0.0, -0.45)) @ Matrix.Rotation(math.pi, 4, "Z"))
	core = p.cylinder(0.075, -0.025, 0.025, sides=12)
	p.transform(core, Matrix.Translation((0, 0, -0.45)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	p.paint(core, "dorado", "MID")
	gem = p.blob((0, 0, -0.45), 0.04, squash=(1.0, 0.8, 1.0), subdiv=2, rough=0.0)
	p.paint(gem, "doom", "MID")


def escudo_madera(p):
	"""Redondo, de tablas verticales con borde de cuero y un rombo escalonado pintado."""
	r = 0.44
	boards = []
	for i in range(5):
		x0 = -r + i * 2 * r / 5
		x1 = x0 + 2 * r / 5 - 0.012
		xs = [x0 + (x1 - x0) * k / 3 for k in range(4)]
		arc = [(x, math.sqrt(max(r * r - x * x, 0.0))) for x in xs]
		boards += flat(p, [(x, -z) for x, z in arc] + [(x, z) for x, z in reversed(arc)], 0.06)
	p.paint(boards, "madera", z_range=(-0.8, 0.8), vary=0.1)
	rim = p.lathe([(r + 0.01, -0.035), (r + 0.03, 0.0), (r + 0.01, 0.035), (r - 0.03, 0.035), (r - 0.03, -0.035), (r + 0.01, -0.035)], sides=28, caps=False)
	p.transform(rim, UPRIGHT)
	p.paint(rim, "madera_oscura", "MID")
	steps = []
	for w, h in ((0.5, 0.12), (0.34, 0.28), (0.18, 0.44)):
		steps += p.box(-w / 2, w / 2, -0.045, -0.03, -h / 2, h / 2)
	p.paint(steps, "tela_roja", "MID")
	core = p.box(-0.06, 0.06, -0.05, -0.03, -0.06, 0.06)
	p.paint(core, "hueso", "LIGHT")


def escudo_espejo(p):
	"""Disco solar: centro espejado, aro de bronce y doce rayos."""
	disk = p.cylinder(0.36, 0.0, 0.04, sides=28)
	p.transform(disk, UPRIGHT)
	p.paint(disk, "cristal", "LIGHT", vary=0.03)
	ring = p.lathe([(0.36, -0.05), (0.44, -0.04), (0.44, 0.03), (0.36, 0.03), (0.36, -0.05)], sides=28, caps=False)
	p.transform(ring, UPRIGHT)
	p.paint(ring, "dorado", "MID")
	rays = []
	for i in range(12):
		a = 2 * math.pi * i / 12
		ray = flat(p, [(-0.06, 0.43), (0.06, 0.43), (0.0, 0.58 if i % 2 == 0 else 0.52)], 0.05)
		p.transform(ray, Matrix.Rotation(a, 4, "Y"))
		rays += ray
	p.paint(rays, "dorado", "LIGHT", vary=0.05)
	back = p.cylinder(0.3, -0.1, -0.02, sides=20)
	p.transform(back, UPRIGHT)
	p.paint(back, "madera_oscura", "MID")


def arco(p):
	"""Arco recurvo sobre Y, el agarre en el origen, el lomo hacia +X (el blanco) y la cuerda del lado del arquero (-X).
	Shape key «tensado»: la cuerda se va 0.38 m hacia -X en V y las palas se doblan hacia atrás y adentro."""
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
			c = p.cylinder(0.035 - 0.017 * (t - 1 / 8), 0.0, seg.length, sides=10, radius_top=0.035 - 0.017 * t)
			p.transform(c, Matrix.Translation(prev) @ seg.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4())
			limbs += c
			prev = cur
	p.paint(limbs, "madera_oscura", "MID", vary=0.08)
	tips = []
	for side in (-1, 1):
		tips += p.blob((-brace, side * half, 0.0), 0.035, subdiv=2, rough=0.0)
	p.paint(tips, "dorado", "MID")
	wrap = p.rounded_box(-0.05, 0.05, -0.1, 0.1, -0.045, 0.045, radius=0.02, segments=2)
	p.paint(wrap, "tela_roja", "MID")
	string = []
	for side in (-1, 1):
		lo, hi = sorted((0.0, side * half))
		string += p.box(-brace - 0.006, -brace + 0.006, lo, hi, -0.006, 0.006)
	p.paint(string, "hueso", "LIGHT")
	p.bm.verts.index_update()
	cord = {v.index for f in string for v in f.verts}
	draw, bend, squeeze = 0.38, 0.1, 0.05

	def tensado(i, co):
		s = min(abs(co.y) / half, 1.0)
		if i in cord:
			tip = Vector((-brace - bend, math.copysign(half * (1 - squeeze), co.y), 0.0))
			return Vector((-brace - draw, 0.0, 0.0)).lerp(tip, s) + Vector((co.x + brace, 0.0, co.z))
		return Vector((co.x - bend * s ** 2, co.y * (1 - squeeze * s ** 2), co.z))

	return {"tensado": tensado}


def carcaj(p):
	tube = p.cylinder(0.11, 0.0, 0.62, sides=16, radius_top=0.12)
	p.paint_bands(tube, [(0.1, 0.18, "tela_roja", "MID"), (0.45, 0.52, "tela_roja", "MID")], default=(0, 0, "madera", "DARK"))
	shafts = []
	for i in range(5):
		a = 2 * math.pi * i / 5
		x, y = math.cos(a) * 0.05, math.sin(a) * 0.05
		shafts += p.box(x - 0.01, x + 0.01, y - 0.01, y + 0.01, 0.55, 0.82)
		feather = p.polygon([(x - 0.03, y), (x + 0.03, y), (x, y + 0.002)], 0.72, 0.84)
		shafts += feather
	p.paint(shafts, "hueso", "MID", vary=0.1)
	strap = p.box(-0.02, 0.02, -0.13, 0.13, 0.25, 0.3)
	p.paint(strap, "madera_oscura", "MID")


def bolsa_bombas(p):
	"""Bolsa tejida con franjas de aguayo y la boca atada."""
	body = p.lathe([(0.0, 0.0), (0.18, 0.03), (0.24, 0.15), (0.22, 0.3), (0.12, 0.38), (0.06, 0.4), (0.1, 0.46), (0.0, 0.47)], sides=18)
	p.paint_bands(body, [(0.08, 0.13, "tela_azul", "MID"), (0.13, 0.17, "flor_amarilla", "MID"), (0.17, 0.22, "tela_azul", "MID"), (0.26, 0.3, "flor_rosa", "MID"), (0.36, 0.42, "paja", "DARK")], default=(0, 0, "tela_roja", "MID"))


# Frasco redondo de vidrio (perfil [(radio, z)]); el líquido llena la panza hasta LIQUID_TOP.
FLASK = [(0.0, 0.0), (0.08, 0.005), (0.13, 0.05), (0.145, 0.11), (0.13, 0.17), (0.08, 0.215), (0.05, 0.24), (0.045, 0.32),
	(0.056, 0.33), (0.056, 0.345), (0.0, 0.345)]
LIQUID_TOP = 0.165


def botella(p):
	"""Lo opaco de la botella: tapón de madera y el cordel del cuello. El vidrio y el líquido son piezas aparte."""
	cork = p.cylinder(0.04, 0.315, 0.4, sides=12, radius_top=0.045)
	p.paint(cork, "madera", "MID")
	cord = p.lathe([(0.049, 0.255), (0.052, 0.27), (0.049, 0.285)], sides=10, caps=False)
	p.paint(cord, "paja", "MID")


def botella_vidrio(p):
	"""El frasco de vidrio (en Godot, con material transparente)."""
	p.paint(p.lathe(FLASK, sides=20), "cristal", "LIGHT")


def botella_liquido(p):
	"""El contenido: la panza llena hasta LIQUID_TOP, en blanco; el material del ítem le da el color."""
	inner = [(r * 0.9, z) for r, z in FLASK if z < LIQUID_TOP] + [(0.0, LIQUID_TOP)]
	inner[0] = (0.0, 0.015)
	p.paint(p.lathe(inner, sides=20), "blanco", "LIGHT")


def armadura(p):
	"""La armadura del jugador suelta (para los íconos): peto con la franja de neón, hombreras y cuello, sobre el traje."""
	p.paint(p.box(-0.22, 0.22, -0.16, 0.16, 0.0, 0.58), "noche", "MID")
	plate = p.box(-0.26, 0.26, -0.22, 0.12, 0.22, 0.58, taper=0.03)
	p.paint_bands(plate, [(0.3, 0.33, "neon", "MID")], default=(0, 0, "tela_roja", "MID"))
	epi.chakana_plate(p, Vector((0, -0.23, 0.45)), 0.16, "dorado")
	p.paint(p.lathe([(0.2, 0.55), (0.22, 0.62), (0.0, 0.62)], sides=16), "dorado", "MID")
	for side in (-1, 1):
		x = side * 0.36
		p.paint(p.rounded_box(x - 0.17, x + 0.17, -0.17, 0.17, 0.38, 0.64, radius=0.07), "tela_roja", "MID")
		p.paint(p.box(x - 0.175, x + 0.175, -0.175, 0.175, 0.42, 0.45), "neon", "MID")
	flap = p.box(-0.17, 0.17, -0.22, -0.18, -0.3, 0.02, taper=0.0)
	p.paint_bands(flap, [(-0.22, -0.19, "neon", "MID")], default=(0, 0, "tela_roja", "MID"))
	p.paint(p.box(-0.26, 0.26, -0.19, 0.19, -0.04, 0.04), "dorado", "MID")


def pluma(p):
	"""Pluma de cóndor sobre +Z con el cañón en el origen: vexilo blanco curvado con la punta negra, una franja roja y
	una muesca; las mitades abren en V a los lados del raquis y van en tiras para que las franjas tengan borde."""
	length = 0.64
	bend = lambda z: 0.07 * (z / length) ** 2  # noqa: E731
	zs = [0.1, 0.17, 0.24, 0.27, 0.31, 0.38, 0.44, 0.5, 0.56, 0.6, length + 0.02]
	for side, width, notch in ((1, 0.085, 0.38), (-1, 0.065, 0.5)):
		def edge(z):
			w = width * math.sin(math.pi * min(1.0, (z - 0.06) / (length - 0.04))) ** 0.6
			return side * (w * 0.6 if abs(z - notch) < 0.01 else w) + bend(z)
		for z0, z1 in zip(zs, zs[1:]):
			pts = [(bend(z0), z0), (edge(z0), z0), (edge(z1), z1), (bend(z1), z1)]
			strip = flat(p, pts if side < 0 else pts[::-1], 0.016)
			p.transform(strip, Matrix.Rotation(side * 0.18, 4, "Z"))
			mid = (z0 + z1) / 2
			p.paint(strip, "noche" if mid > 0.5 else "tela_roja" if 0.27 < mid < 0.31 else "blanco", "MID", vary=0.03)
	quill = flat(p, [(bend(z) + d, z) for d, z in ((0.008, -0.08), (0.008, 0.3), (0.003, length))] + [(bend(z) - d, z) for d, z in ((0.003, length), (0.008, 0.3), (0.008, -0.08))], 0.024)
	p.paint(quill, "dorado", "MID")
	tie = p.cylinder(0.02, 0.0, 0.05, sides=6)
	p.paint(tie, "tela_azul", "MID")


def tube(p, points, radius, sides=6):
	"""Tira redonda que pasa por points (cuero de las correas)."""
	faces = []
	for a, b in zip(points, points[1:]):
		a, b = Vector(a), Vector(b)
		seg = p.cylinder(radius, 0.0, (b - a).length + radius, sides=sides)
		p.transform(seg, Matrix.Translation(a) @ (b - a).to_track_quat("Z", "Y").to_matrix().to_4x4())
		faces += seg
	return faces


SOLE = [(0.0, 0.155), (0.033, 0.146), (0.044, 0.1), (0.043, 0.03), (0.053, -0.04), (0.058, -0.1), (0.045, -0.142), (0.016, -0.16),
		(-0.018, -0.156), (-0.043, -0.13), (-0.049, -0.07), (-0.039, 0.0), (-0.039, 0.1), (-0.029, 0.145)]


def ojota(p, side, at, turn):
	"""Una ojota (side 1 derecha, -1 izquierda) apoyada en z 0 con la punta hacia -Y: suela de dos capas, dos correas
	rojas del dedo a los costados, la tira del talón y un ala chica de cóndor en el talón, del lado de afuera."""
	faces = []
	outline = [(side * x, y) for x, y in SOLE]
	if side > 0:
		outline.reverse()
	base = p.polygon(outline, 0.0, 0.016)
	p.paint(base, "noche", "MID")
	top = p.polygon([(x * 0.97, y * 0.98) for x, y in outline], 0.016, 0.03)
	p.paint(top, "madera", "MID", vary=0.04)
	faces += base + top
	post = (0.0, -0.105, 0.026)
	for k in (-1, 1):
		strap = tube(p, [post, (k * 0.022, -0.075, 0.062), (k * 0.044, -0.02, 0.05), (k * 0.043, 0.0, 0.026)], 0.012)
		p.paint(strap, "tela_roja", "MID")
		faces += strap
	heel = tube(p, [(-0.04, 0.0, 0.026), (-0.045, 0.08, 0.075), (-0.025, 0.155, 0.085), (0.025, 0.155, 0.085), (0.045, 0.08, 0.075), (0.04, 0.0, 0.026)], 0.011)
	p.paint(heel, "tela_roja", "LOW")
	faces += heel
	for x, y, z in (post, (0.044, -0.02, 0.05), (-0.044, -0.02, 0.05)):
		bead = p.blob((x, y, z), 0.016, subdiv=1, rough=0.0)
		p.paint(bead, "dorado", "MID")
		faces += bead
	for i, tilt in enumerate((0.25, 0.65, 1.05)):
		length = 0.15 - i * 0.02
		quill = flat(p, [(0.0, 0.0), (0.024, length * 0.3), (0.018, length * 0.8), (0.0, length), (-0.01, length * 0.6), (-0.008, length * 0.2)], 0.012)
		p.transform(quill, Matrix.Translation((side * 0.05, 0.13, 0.06)) @ Matrix.Rotation(side * math.pi / 2, 4, "Z") @ Matrix.Rotation(tilt, 4, "Y"))
		p.paint_bands(quill, [(0.06 + length * 0.7, 1.0, "noche", "MID")], default=(0, 0, "blanco", "MID"))
		faces += quill
	p.transform(faces, Matrix.Translation(at) @ Matrix.Rotation(turn, 4, "Z"))


def sandalias(p):
	"""El par de ojotas para correr (las botas Pegaso): la derecha un poco adelante."""
	ojota(p, 1, (0.075, -0.02, 0.0), -0.08)
	ojota(p, -1, (-0.075, 0.02, 0.0), 0.08)


def aro(p, radius, thick, z=0.0, sides=16, segs=8):
	"""Aro (toro) alrededor de Z a la altura z."""
	profile = [(radius + thick * math.cos(a), z + thick * math.sin(a)) for a in (2 * math.pi * k / segs for k in range(segs + 1))]
	return p.lathe(profile, sides=sides, caps=False)


def punta(p):
	"""La punta del gancho sobre +Z con el ojo de la cadena en el origen: cuello de cobre atado con lana roja, punta de
	rombo y dos garfios que vuelven hacia atrás."""
	eye = aro(p, 0.035, 0.012, sides=10, segs=6)
	p.transform(eye, Matrix.Rotation(math.pi / 2, 4, "Y"))
	p.paint(eye, "hierro", "LIGHT")
	neck = p.cylinder(0.04, 0.02, 0.15, sides=8, radius_top=0.05)
	p.paint_bands(neck, [(0.06, 0.1, "tela_roja", "MID")], default=(0, 0, "roca_naranja", "MID"))
	head = p.lathe([(0.0, 0.14), (0.06, 0.15), (0.09, 0.21), (0.0, 0.42)], sides=4)
	p.paint(head, "roca_naranja", "LIGHT", vary=0.03)
	barbs = []
	right = [(0.04, 0.26), (0.1, 0.22), (0.17, 0.12), (0.19, 0.03), (0.15, 0.06), (0.11, 0.13), (0.05, 0.17)]
	for side in (1, -1):
		pts = [(side * x, z) for x, z in right]
		barbs += flat(p, pts if side < 0 else pts[::-1], 0.035)
	p.paint(barbs, "dorado", "MID")
	return eye + neck + head + barbs


def gancho_punta(p):
	punta(p)


CHAIN_TILE = 0.16


def gancho_cadena(p):
	"""Un tramo de cadena de CHAIN_TILE sobre +Y (en Godot, de 0 a -CHAIN_TILE en Z): dos eslabones cruzados que encastran
	con los del tramo siguiente; se repite a lo largo, sin estirar."""
	links = []
	for k in (0, 1):
		zc = CHAIN_TILE * (0.25 + 0.5 * k)
		pts = [(0.03 * math.cos(t), 0.0, zc + 0.055 * math.sin(t)) for t in (2 * math.pi * i / 10 for i in range(11))]
		link = tube(p, pts, 0.01, sides=5)
		p.transform(link, Matrix.Rotation(math.pi / 2 * k, 4, "Z"))
		links += link
	p.paint(links, "hierro", "LIGHT", vary=0.05)
	p.transform(links, Matrix.Rotation(-math.pi / 2, 4, "X"))


def gancho(p):
	"""El gancho entero (para el ícono): caño de cobre sobre +Z con la empuñadura colgando, la cadena enrollada y la punta."""
	barrel = p.lathe([(0.0, 0.0), (0.05, 0.0), (0.056, 0.02), (0.05, 0.3), (0.062, 0.32), (0.062, 0.34), (0.0, 0.34)], sides=12)
	p.paint_bands(barrel, [(0.0, 0.03, "dorado", "MID"), (0.29, 0.34, "dorado", "MID")], default=(0, 0, "roca_naranja", "MID"))
	coil = []
	for z in (0.1, 0.125, 0.15, 0.175, 0.2):
		coil += aro(p, 0.062, 0.013, z, sides=12, segs=6)
	p.paint(coil, "hierro", "LIGHT", vary=0.06)
	grip = p.cylinder(0.032, 0.0, 0.17, sides=8, radius_top=0.028)
	p.paint_bands(grip, [(0.05, 0.08, "tela_roja", "MID"), (0.12, 0.15, "tela_roja", "MID")], default=(0, 0, "madera_oscura", "MID"))
	p.transform(grip, Matrix.Translation((0, 0, 0.05)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	p.transform(punta(p), Matrix.Translation((0, 0, 0.33)))


def martillo(p):
	"""El martillo del golpe fuerte, sobre +Z con la empuñadura en el origen como la espada: mango de madera con tiento
	rojo, cabeza de piedra oscura con bocas de bronce, zunchos dorados y el ojo del logo en las dos caras, como las manos del jefe."""
	p.paint(p.cylinder(0.036, 0.05, 0.72, sides=10, radius_top=0.032), "madera", "MID")
	grip = []
	for i in range(6):
		z = 0.05 - i * 0.058
		grip += p.cylinder(0.043, z - 0.05, z, sides=10)
	p.paint_bands(grip, [(-0.07, -0.01, "tela_roja", "MID"), (-0.19, -0.12, "tela_roja", "MID"), (-0.3, -0.24, "tela_roja", "MID")], default=(0, 0, "hueso", "MID"))
	knob = p.blob((0, 0, -0.33), 0.055, subdiv=2, rough=0.0)
	p.paint(knob, "cobre_verde", "MID")
	head = p.rounded_box(-0.2, 0.2, -0.13, 0.13, 0.66, 0.92, radius=0.04, segments=2)
	p.paint(head, "acantilado", "DARK", vary=0.05)
	faces = []
	for side in (-1, 1):
		cap = p.cylinder(0.15, 0.0, 0.06, sides=8, phase=math.pi / 8)
		p.transform(cap, Matrix.Translation((side * 0.2, 0, 0.79)) @ Matrix.Rotation(side * math.pi / 2, 4, "Y"))
		faces += cap
	p.paint(faces, "cobre_verde", "MID", vary=0.04)
	bands = []
	for x in (-0.17, 0.17):
		bands += p.box(x - 0.02, x + 0.02, -0.14, 0.14, 0.65, 0.93)
	p.paint(bands, "dorado", "MID")
	for turn in (0.0, math.pi):
		eye = epi.logo_eye(p, Vector((0, 0, 0)), 0.2, depth=0.012, iris=("neon", "MID"))
		p.transform(eye, Matrix.Rotation(turn, 4, "Z") @ Matrix.Translation((0, -0.13, 0.78)))


piece("espada", 1, espada)
piece("espada_dorada", 16, espada_dorada)
piece("escudo_madera", 2, escudo_madera)
piece("escudo_espejo", 3, escudo_espejo)
piece("arco", 4, arco)
piece("carcaj", 5, carcaj)
piece("bolsa_bombas", 6, bolsa_bombas)
piece("botella", 7, botella)
piece("botella_vidrio", 8, botella_vidrio)
piece("botella_liquido", 10, botella_liquido)
piece("armadura", 9, armadura)
piece("pluma", 11, pluma)
piece("sandalias", 12, sandalias)
piece("gancho", 13, gancho)
piece("gancho_punta", 14, gancho_punta)
piece("gancho_cadena", 15, gancho_cadena)
piece("martillo", 17, martillo)
epi.layout(kit, columns=8, spacing=2.0)
epi.publish("equipo")
