# Arma assets/epiphany/equipo.blend: armas, escudos y objetos del inventario, con los ejes de KayKit Adventurers:
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


def piece(name, seed, fn):
	p = epi.Piece(seed)
	keys = fn(p) or {}
	obj = p.build(name, kit)
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
		guard += p.box(-w / 2, w / 2, -0.05, 0.05, z - h / 2, z + h / 2)
	p.paint(guard, "cobre_verde", "MID", vary=0.05)
	grip = []
	for i in range(5):
		z = -0.07 - i * 0.055
		grip += p.box(-0.04, 0.04, -0.04, 0.04, z - 0.05, z)
	p.paint_bands(grip, [(-0.13, -0.07, "tela_roja", "MID"), (-0.24, -0.18, "tela_roja", "MID"), (-0.35, -0.29, "tela_roja", "MID")], default=(0, 0, "hueso", "MID"))
	pommel = p.box(-0.07, 0.07, -0.06, 0.06, -0.37, -0.33) + p.box(-0.04, 0.04, -0.06, 0.06, -0.41, -0.37)
	p.paint(pommel, "cobre_verde", "LIGHT")


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
	rim = p.lathe([(r + 0.01, -0.035), (r + 0.03, 0.0), (r + 0.01, 0.035), (r - 0.03, 0.035), (r - 0.03, -0.035), (r + 0.01, -0.035)], sides=16, caps=False)
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
	disk = p.cylinder(0.36, 0.0, 0.04, sides=16)
	p.transform(disk, UPRIGHT)
	p.paint(disk, "cristal", "LIGHT", vary=0.03)
	ring = p.lathe([(0.36, -0.05), (0.44, -0.04), (0.44, 0.03), (0.36, 0.03), (0.36, -0.05)], sides=16, caps=False)
	p.transform(ring, UPRIGHT)
	p.paint(ring, "dorado", "MID")
	rays = []
	for i in range(12):
		a = 2 * math.pi * i / 12
		ray = flat(p, [(-0.06, 0.43), (0.06, 0.43), (0.0, 0.58 if i % 2 == 0 else 0.52)], 0.05)
		p.transform(ray, Matrix.Rotation(a, 4, "Y"))
		rays += ray
	p.paint(rays, "dorado", "LIGHT", vary=0.05)
	back = p.cylinder(0.3, -0.1, -0.02, sides=10)
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
			c = p.cylinder(0.035 - 0.017 * (t - 1 / 8), 0.0, seg.length, sides=6, radius_top=0.035 - 0.017 * t)
			p.transform(c, Matrix.Translation(prev) @ seg.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4())
			limbs += c
			prev = cur
	p.paint(limbs, "madera_oscura", "MID", vary=0.08)
	tips = []
	for side in (-1, 1):
		tips += p.box(-brace - 0.03, -brace + 0.03, side * half - 0.03, side * half + 0.03, -0.03, 0.03)
	p.paint(tips, "dorado", "MID")
	wrap = p.box(-0.05, 0.05, -0.1, 0.1, -0.045, 0.045)
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
	tube = p.cylinder(0.11, 0.0, 0.62, sides=8, radius_top=0.12)
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
	body = p.lathe([(0.0, 0.0), (0.18, 0.03), (0.24, 0.15), (0.22, 0.3), (0.12, 0.38), (0.06, 0.4), (0.1, 0.46), (0.0, 0.47)], sides=10)
	p.paint_bands(body, [(0.08, 0.13, "tela_azul", "MID"), (0.13, 0.17, "flor_amarilla", "MID"), (0.17, 0.22, "tela_azul", "MID"), (0.26, 0.3, "flor_rosa", "MID"), (0.36, 0.42, "paja", "DARK")], default=(0, 0, "tela_roja", "MID"))


# Frasco redondo de vidrio (perfil [(radio, z)]); el líquido llena la panza hasta LIQUID_TOP.
FLASK = [(0.0, 0.0), (0.08, 0.005), (0.13, 0.05), (0.145, 0.11), (0.13, 0.17), (0.08, 0.215), (0.05, 0.24), (0.045, 0.32),
	(0.056, 0.33), (0.056, 0.345), (0.0, 0.345)]
LIQUID_TOP = 0.165


def botella(p):
	"""Lo opaco de la botella: tapón de madera y el cordel del cuello. El vidrio y el líquido son piezas aparte."""
	cork = p.cylinder(0.04, 0.315, 0.4, sides=6, radius_top=0.045)
	p.paint(cork, "madera", "MID")
	cord = p.lathe([(0.049, 0.255), (0.052, 0.27), (0.049, 0.285)], sides=10, caps=False)
	p.paint(cord, "paja", "MID")


def botella_vidrio(p):
	"""El frasco de vidrio (en Godot, con material transparente)."""
	p.paint(p.lathe(FLASK, sides=12), "cristal", "LIGHT")


def botella_liquido(p):
	"""El contenido: la panza llena hasta LIQUID_TOP, en blanco; el material del ítem le da el color."""
	inner = [(r * 0.9, z) for r, z in FLASK if z < LIQUID_TOP] + [(0.0, LIQUID_TOP)]
	inner[0] = (0.0, 0.015)
	p.paint(p.lathe(inner, sides=12), "blanco", "LIGHT")


def armadura(p):
	"""La armadura del jugador suelta (para los íconos): peto con la franja de neón, hombreras y cuello, sobre el traje."""
	p.paint(p.box(-0.22, 0.22, -0.16, 0.16, 0.0, 0.58), "noche", "MID")
	plate = p.box(-0.26, 0.26, -0.22, 0.12, 0.22, 0.58, taper=0.03)
	p.paint_bands(plate, [(0.3, 0.33, "neon", "MID")], default=(0, 0, "tela_roja", "MID"))
	epi.chakana_plate(p, Vector((0, -0.23, 0.45)), 0.16, "dorado")
	p.paint(p.lathe([(0.2, 0.55), (0.22, 0.62), (0.0, 0.62)], sides=8), "dorado", "MID")
	for side in (-1, 1):
		x = side * 0.36
		p.paint(p.rounded_box(x - 0.17, x + 0.17, -0.17, 0.17, 0.38, 0.64, radius=0.07), "tela_roja", "MID")
		p.paint(p.box(x - 0.175, x + 0.175, -0.175, 0.175, 0.42, 0.45), "neon", "MID")
	flap = p.box(-0.17, 0.17, -0.22, -0.18, -0.3, 0.02, taper=0.0)
	p.paint_bands(flap, [(-0.22, -0.19, "neon", "MID")], default=(0, 0, "tela_roja", "MID"))
	p.paint(p.box(-0.26, 0.26, -0.19, 0.19, -0.04, 0.04), "dorado", "MID")


piece("espada", 1, espada)
piece("escudo_madera", 2, escudo_madera)
piece("escudo_espejo", 3, escudo_espejo)
piece("arco", 4, arco)
piece("carcaj", 5, carcaj)
piece("bolsa_bombas", 6, bolsa_bombas)
piece("botella", 7, botella)
piece("botella_vidrio", 8, botella_vidrio)
piece("botella_liquido", 10, botella_liquido)
piece("armadura", 9, armadura)
epi.layout(kit, columns=8, spacing=2.0)
epi.save("equipo")
