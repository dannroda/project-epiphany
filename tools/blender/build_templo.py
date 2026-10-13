# Publica assets/epiphany/templo.glb (epi.publish; el .blend de trabajo en art/blender/): el kit del templo (celdas de 2 × 2 m, paredes de -0.5 a 2.6), puertas, decoración,
# el doom, la torreta y el jefe. El frente mira a -Y.
# Con un estilo (STYLES) publica en cambio templo_<estilo>.glb: el mismo kit con la piedra, el muro, el piso y el relieve
# de esa mazmorra (12.17).
# blender -b -P tools/blender/build_templo.py [-- estilo]
import math
import os
import sys

import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

TOP = 2.6
## Por mazmorra: piedra y junta, hileras y anchos del muro (mínimo, variación), relieve del muro, remate de arriba y piso.
STYLES = {
	"templo": {"stone": "piedra_templo", "mortar": "gris_5", "rows": (0.45, 0.12), "widths": (0.6, 0.4), "depth": 0.05, "vary": 0.07},
	# D2: torre funeraria de piedra de campo con barro, cornisa saliente arriba y piso de tierra apisonada.
	"chullpa": {"stone": "acantilado", "mortar": "tierra", "rows": (0.18, 0.16), "widths": (0.22, 0.3), "depth": 0.1, "vary": 0.16},
	# D3: bloques grandes y lisos de piedra gris, musgo abajo y colgando del remate, charcos en el piso.
	"laguna": {"stone": "piedra", "mortar": "musgo", "rows": (0.38, 0.1), "widths": (0.7, 0.35), "depth": 0.04, "vary": 0.08},
	# D4: basalto oscuro en hiladas altas, nieve en el remate con carámbanos, escarcha en el piso y soles de oro.
	"cumbre": {"stone": "ladrillo", "mortar": "noche", "rows": (0.55, 0.2), "widths": (0.32, 0.18), "depth": 0.07, "vary": 0.1},
}
STYLE_NAME = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv[:-1] else "templo"
STYLE = STYLES[STYLE_NAME]
STONE = STYLE["stone"]
MORTAR = STYLE["mortar"]
kit = epi.start()
UPRIGHT = Matrix.Rotation(math.pi / 2, 4, "X")


def piece(name, seed, fn, smooth=None):
	p = epi.Piece(seed)
	extra = fn(p)
	obj = p.build(name, kit, smooth=smooth)
	for key, value in (extra if isinstance(extra, dict) else {}).items():
		obj[key] = value
	return obj


# --- piso ---

def styled_floor(p, special=False):
	"""Piso de las mazmorras que no son el templo; special (la variante que reparte vary_temple como musgo) le suma
	piedras (chullpa), un charco (laguna) o escarcha (cumbre)."""
	if STYLE_NAME == "chullpa":
		p.paint(p.box(-1, 1, -1, 1, -0.5, 0.0), "tierra", "LOW", vary=0.05)
		stones = []
		for _ in range(p.rng.randint(2, 4) if special else 0):
			cx, cy = p.rng.uniform(-0.8, 0.8), p.rng.uniform(-0.8, 0.8)
			r = p.rng.uniform(0.1, 0.2)
			stone = p.box(cx - r, cx + r, cy - r * 0.8, cy + r * 0.8, -0.03, 0.02, taper=0.03)
			p.jitter(stone, 0.03, keep_z=True)
			stones += stone
		p.paint(stones, "acantilado", "MID", vary=0.1)
		return
	base = p.box(-1, 1, -1, 1, -0.5, -0.05)
	p.paint(base, MORTAR, "DARK")
	tiles = []
	for x in (-1, 0):
		for y in (-1, 0):
			tiles += p.box(x + 0.03, x + 0.97, y + 0.03, y + 0.97, -0.06, -p.rng.random() * 0.015, taper=0.02)
	p.paint(tiles, STONE, "LOW" if STYLE_NAME == "laguna" else "MID", vary=0.06)
	if special:
		cx, cy = p.rng.uniform(-0.5, 0.5), p.rng.uniform(-0.5, 0.5)
		spot = p.blob((cx, cy, 0.0), p.rng.uniform(0.25, 0.4), squash=(1.5, 1.0, 0.04), subdiv=1, rough=0.25)
		p.paint(spot, "agua" if STYLE_NAME == "laguna" else "cristal", "LIGHT" if STYLE_NAME == "cumbre" else "MID")


def slabs(p, skip=(), moss=False, crack=False):
	"""Una laja grande por celda, con la junta del color de la piedra oscura; skip saca un cuarto (roto)."""
	if STYLE_NAME != "templo":
		styled_floor(p, special=moss)
		if skip:
			bits = []
			for _ in range(4):
				cx, cy = p.rng.uniform(-0.7, 0.7), p.rng.uniform(-0.7, 0.7)
				b = p.box(cx - 0.12, cx + 0.12, cy - 0.09, cy + 0.09, -0.02, 0.07, taper=0.03)
				p.jitter(b, 0.03)
				bits += b
			p.paint(bits, STONE, "DARK", vary=0.1)
		if crack:
			floor_crack(p)
		return
	base = p.box(-1, 1, -1, 1, -0.5, -0.05)
	p.paint(base, "musgo" if moss else STONE, "DARK")
	if not skip:
		tile = p.box(-0.975, 0.975, -0.975, 0.975, -0.06, 0.0, taper=0.02)
		p.paint(tile, STONE, "LOW", vary=0.04)
	else:
		tiles = []
		for x in (-1, 0):
			for y in (-1, 0):
				if (x, y) in skip:
					continue
				tiles += p.box(x + 0.025, x + 0.975, y + 0.025, y + 0.975, -0.06, -p.rng.random() * 0.012, taper=0.015)
		p.paint(tiles, STONE, "LOW", vary=0.06)
	for x, y in skip:
		bits = []
		for _ in range(3):
			cx, cy = x + 0.5 + p.rng.uniform(-0.3, 0.3), y + 0.5 + p.rng.uniform(-0.3, 0.3)
			b = p.box(cx - 0.1, cx + 0.1, cy - 0.08, cy + 0.08, -0.04, 0.04, taper=0.02)
			p.jitter(b, 0.03)
			bits += b
		p.paint(bits, STONE, "DARK", vary=0.1)
	if moss:
		tufts = []
		for _ in range(5):
			tufts += p.blob((p.rng.choice((-0.97, 0.97)) if p.rng.random() < 0.5 else p.rng.uniform(-0.9, 0.9), p.rng.uniform(-0.9, 0.9), 0.0), p.rng.uniform(0.08, 0.14), squash=(1.4, 1.4, 0.35), subdiv=1, rough=0.3)
		p.paint(tufts, "musgo", vary=0.1)
	if crack:
		floor_crack(p)


def floor_crack(p):
	lines = []
	x, y = -1.0, p.rng.uniform(-0.5, 0.5)
	while x < 1.0:
		nx, ny = x + p.rng.uniform(0.2, 0.35), max(-0.9, min(0.9, y + p.rng.uniform(-0.3, 0.3)))
		seg = Vector((nx - x, ny - y, 0))
		c = p.box(0, seg.length, -0.03, 0.03, -0.02, 0.005)
		p.transform(c, Matrix.Translation((x, y, 0)) @ Matrix.Rotation(math.atan2(seg.y, seg.x), 4, "Z"))
		lines += c
		x, y = nx, ny
	p.paint(lines, "doom", "LIGHT")


piece("piso", 1, lambda p: slabs(p))
piece("piso_roto", 2, lambda p: slabs(p, skip={(0, -1)}))
piece("piso_musgo", 3, lambda p: slabs(p, moss=True))
piece("piso_grieta", 4, lambda p: slabs(p, crack=True))


# --- paredes ---

def wall_block(p):
	if STYLE_NAME != "templo":
		styled_wall(p)
		return
	epi.stone_wall(p, -0.5, TOP - 0.2, swatch=STONE, rows=(0.45, 0.12), widths=(0.6, 0.4), mortar="gris_5", depth=0.05, vary=0.07)
	band = p.box(-1.0, 1.0, -1.0, 1.0, TOP - 0.2, TOP)
	p.paint([f for f in band if f.normal.z > 0.5], STONE, "LIGHT", vary=0.03)
	# Solo el frente (-Y, hacia la cámara): los costados casi siempre quedan contra otra pared y el fondo no se ve.
	bmesh.ops.delete(p.bm, geom=[f for f in band if f.normal.y < -0.5], context="FACES_ONLY")
	p.paint([f for f in band if f.is_valid and abs(f.normal.z) < 0.5], STONE, "LIGHT", vary=0.03)
	for facing in [Vector((0, -1, 0))]:
		p.paint([epi.hanging_face(p, facing, TOP, 1.0, chakana_steps(), lean=0.15)], STONE, "LIGHT", vary=0.03)


def styled_wall(p):
	"""Muro con la piedra del estilo y su remate: cornisa de barro (chullpa), musgo que cuelga (laguna) o nieve con
	carámbanos (cumbre). Como el del templo, el remate solo se ve de frente (-Y)."""
	stones = epi.stone_wall(p, -0.5, TOP - 0.2, swatch=STONE, rows=STYLE["rows"], widths=STYLE["widths"], mortar=MORTAR, depth=STYLE["depth"], vary=STYLE["vary"])
	front = Vector((0, -1, 0))
	if STYLE_NAME == "laguna":
		p.paint([f for f in stones if f.calc_center_median().z < 0.35 + 0.25 * p.rng.random()], "musgo", "MID", vary=0.1)
	if STYLE_NAME == "chullpa":
		band = p.box(-1.0, 1.0, -1.0, 1.0, TOP - 0.2, TOP - 0.08)
		cornice = p.box(-1.0, 1.0, -1.14, 1.0, TOP - 0.08, TOP)
		p.paint(band, "tierra", "MID", vary=0.04)
		p.paint(cornice, "tierra", "LIGHT", vary=0.04)
		return
	band = p.box(-1.0, 1.0, -1.0, 1.0, TOP - 0.2, TOP)
	top_swatch = "musgo" if STYLE_NAME == "laguna" else "cristal"
	p.paint([f for f in band if f.normal.z > 0.5], top_swatch, "LIGHT", vary=0.03)
	bmesh.ops.delete(p.bm, geom=[f for f in band if f.normal.y < -0.5], context="FACES_ONLY")
	p.paint([f for f in band if f.is_valid and abs(f.normal.z) < 0.5], top_swatch, "LIGHT", vary=0.03)
	points = []
	n = 9
	for k in range(n + 1):
		u = 1.0 - 2.0 * k / n
		drop = 0.2 + (p.rng.uniform(0.05, 0.3) if 0 < k < n and k % 2 else 0.0)
		points.append((u, drop))
	p.paint([epi.hanging_face(p, front, TOP, 1.0, points[1:-1], lean=0.1)], top_swatch, "LIGHT" if STYLE_NAME == "cumbre" else "MID", vary=0.04)
	if STYLE_NAME == "cumbre":
		ice = []
		for _ in range(p.rng.randint(2, 4)):
			x = p.rng.uniform(-0.85, 0.85)
			length = p.rng.uniform(0.2, 0.45)
			ice += p.cylinder(0.006, TOP - 0.2 - length, TOP - 0.2, sides=4, radius_top=0.05, center=(x, -1.04))
		p.paint(ice, "cristal", "LIGHT")


def relief(p):
	"""El relieve de la pared especial de cada estilo, en el frente (-Y)."""
	if STYLE_NAME == "chullpa":
		niche = p.box(-0.3, 0.3, -1.12, -1.0, 0.9, 1.75)
		for v in {v for f in niche for v in f.verts}:
			if v.co.z > 1.5:
				v.co.x *= 0.65
		p.paint(niche, "noche", "MID")
		skull = p.blob((0.0, -1.16, 1.08), 0.15, squash=(1.0, 0.8, 0.9), subdiv=1, rough=0.1)
		p.paint(skull, "hueso", "MID")
		for x in (-0.05, 0.05):
			p.paint(p.box(x - 0.03, x + 0.03, -1.3, -1.25, 1.08, 1.13), "noche", "DARK")
	elif STYLE_NAME == "laguna":
		ring = []
		for r in (0.42, 0.28, 0.14):
			ring += p.cylinder(r, 0.0, 0.04 + (0.42 - r) * 0.1, sides=14, center=(0.0, 0.0))
		p.transform(ring, Matrix.Translation((0, -1.0, 1.35)) @ UPRIGHT)
		p.paint(ring, STONE, "LIGHT", vary=0.04)
	else:
		disc = p.cylinder(0.24, 0.0, 0.05, sides=14)
		rays = []
		for k in range(8):
			ray = p.box(-0.04, 0.04, 0.28, 0.48, 0.0, 0.035)
			p.transform(ray, Matrix.Rotation(math.pi / 4 * k, 4, "Z"))
			rays += ray
		p.transform(disc + rays, Matrix.Translation((0, -1.0, 1.4)) @ UPRIGHT)
		p.paint(disc + rays, "dorado", "MID")


def chakana_steps(half=1.0, shallow=0.22, step=-0.07, run=0.13):
	"""Borde de abajo escalonado como la chakana: dos escalones que suben hacia el centro de cada lado y dejan ver el
	núcleo oscuro del muro (más abajo lo taparía el frente de las piedras)."""
	points = []
	edges = [-half, -half + 0.45, -half + 0.45 + run, -half + 0.45 + 2 * run]
	drops = [shallow, shallow + step, shallow + 2 * step]
	profile = [(edges[0], drops[0]), (edges[1], drops[0]), (edges[1], drops[1]), (edges[2], drops[1]), (edges[2], drops[2])]
	mirrored = [(-u, d) for u, d in reversed(profile)]
	for u, d in reversed(profile + mirrored):
		points.append((u, d))
	return points


def pared_nicho(p):
	wall_block(p)
	if STYLE_NAME == "chullpa":
		relief(p)
		return
	niche = p.box(-0.35, 0.35, -1.06, -1.0, 0.7, 1.9)
	for v in {v for f in niche for v in f.verts}:
		if v.co.z > 1.5:
			v.co.x *= 0.7
	p.paint(niche, "noche", "MID")
	frame = p.box(-0.45, 0.45, -1.08, -1.0, 0.6, 0.7)
	p.paint(frame, STONE, "LIGHT")


def pared_ojo(p):
	wall_block(p)
	if STYLE_NAME != "templo":
		relief(p)
		return
	p.paint(epi.eye(p, Vector((0, -1.0, 1.4)), 0.42, depth=0.05), STONE, "LIGHT")


def styled_column(p):
	"""Pilar de piedras apiladas (chullpa), columna de basalto hexagonal con nieve (cumbre) o pilar con musgo (laguna)."""
	slabs(p)
	if STYLE_NAME == "chullpa":
		stones = []
		z = -0.5
		while z < TOP - 0.25:
			h = p.rng.uniform(0.2, 0.32)
			ring = p.cylinder(0.5 + p.rng.uniform(-0.04, 0.04), z, min(z + h, TOP - 0.25), sides=7, phase=p.rng.random())
			p.jitter(ring, 0.03)
			stones += ring
			z += h
		p.paint(stones, STONE, z_range=(-0.5, TOP), vary=0.14)
		cap = p.cylinder(0.62, TOP - 0.25, TOP, sides=8)
		p.paint(cap, "tierra", "LIGHT", vary=0.04)
	elif STYLE_NAME == "cumbre":
		shaft = p.cylinder(0.45, -0.5, TOP - 0.12, sides=6)
		p.paint(shaft, STONE, z_range=(-0.5, TOP + 0.6), vary=0.05)
		snow = p.cylinder(0.5, TOP - 0.12, TOP, sides=6, radius_top=0.42)
		p.paint(snow, "cristal", "LIGHT")
	else:
		shaft = p.box(-0.42, 0.42, -0.42, 0.42, -0.5, TOP - 0.2, taper=0.03)
		p.paint(shaft, STONE, z_range=(-0.5, 3.2), vary=0.05)
		p.paint([f for f in shaft if f.calc_center_median().z < 0.6], "musgo", "MID", vary=0.08)
		cap = p.box(-0.5, 0.5, -0.5, 0.5, TOP - 0.2, TOP)
		p.paint(cap, "musgo", "LIGHT", vary=0.05)


def columna(p):
	"""Pilar cuadrado escalonado de 0.9 m, centrado en la celda, con su piso."""
	if STYLE_NAME != "templo":
		styled_column(p)
		return
	slabs(p)
	base = p.box(-0.55, 0.55, -0.55, 0.55, -0.5, 0.2) + p.box(-0.48, 0.48, -0.48, 0.48, 0.2, 0.35)
	shaft = p.box(-0.4, 0.4, -0.4, 0.4, 0.35, 2.2)
	capital = p.box(-0.48, 0.48, -0.48, 0.48, 2.2, 2.38) + p.box(-0.56, 0.56, -0.56, 0.56, 2.38, TOP)
	p.paint(base + capital, STONE, "LIGHT", vary=0.04)
	p.paint(shaft, STONE, z_range=(-0.5, 3.2), vary=0.04)
	inlay = []
	for k in range(4):
		f = p.box(-0.15, 0.15, -0.43, -0.4, 1.0, 1.6)
		p.transform(f, Matrix.Rotation(math.pi / 2 * k, 4, "Z"))
		inlay += f
	p.paint(inlay, MORTAR, "MID")


def paso_puerta(p):
	"""Celda de paso: jambas y dintel; la abertura (1.8 abajo, 1.5 arriba, 2.3 de alto) cruza en Y."""
	for side in (-1, 1):
		jamb = p.box(0.9, 1.0, -1.0, 1.0, -0.5, TOP)
		p.transform(jamb, Matrix.Scale(side, 4, Vector((1, 0, 0))))
		p.paint(jamb, STONE, vary=0.05)
		slope = p.box(0.75, 0.9, -1.0, 1.0, -0.5, 2.3)
		for v in {v for f in slope for v in f.verts}:
			if v.co.z < 0 and v.co.x < 0.8:
				v.co.x = 0.9
		p.transform(slope, Matrix.Scale(side, 4, Vector((1, 0, 0))))
		p.paint(slope, STONE, "MID", vary=0.05)
	lintel = p.box(-1.0, 1.0, -1.0, 1.0, 2.3, TOP)
	p.paint(lintel, STONE, "LIGHT", vary=0.04)
	floor = p.box(-0.9, 0.9, -1.0, 1.0, -0.5, -0.04)
	p.paint(floor, STONE, "DARK")


def escalon_templo(p):
	body = p.box(-1, 1, -1, 1, -0.5, 0.56)
	p.paint(body, STONE, z_range=(-0.5, 1.2), vary=0.05)
	cap = p.box(-1, 1, -1, 1, 0.56, 0.6)
	p.paint(cap, STONE, "LIGHT")


piece("pared", 5, wall_block)
piece("pared_nicho", 6, pared_nicho)
piece("pared_ojo", 7, pared_ojo)
piece("columna", 8, columna)
piece("paso_puerta", 9, paso_puerta)
piece("escalon", 10, escalon_templo)


# --- puertas (hoja de 1.8 × 2.3 × 0.3, origen abajo al centro) ---

def leaf(p, swatch, shade="MID"):
	body = p.box(-0.9, 0.9, -0.15, 0.15, 0.0, 2.3)
	for v in {v for f in body for v in f.verts}:
		if v.co.z > 2.0:
			v.co.x *= 0.85
	p.paint(body, swatch, z_range=(-0.5, 3.0), vary=0.04)
	return body


def puerta_madera(p):
	leaf(p, "madera")
	planks = []
	for i in range(5):
		x = -0.9 + i * 0.36 + 0.33
		planks += p.box(x, x + 0.03, -0.17, -0.15, 0.0, 2.15)
	for z in (0.4, 1.8):
		planks += p.box(-0.88, 0.88, -0.19, -0.15, z, z + 0.12)
	p.paint(planks, "cobre_verde", "MID")


def puerta_llave(p):
	puerta_madera(p)
	epi.chakana_plate(p, Vector((0, -0.19, 1.1)), 0.45, "dorado")


def puerta_persiana(p):
	"""Losa de piedra que sube y baja, con escalonados."""
	leaf(p, STONE)
	steps = []
	for i in range(4):
		w = 1.4 - i * 0.3
		steps += p.box(-w / 2, w / 2, -0.19, -0.15, 0.3 + i * 0.25, 0.5 + i * 0.25)
	p.paint(steps, STONE, "LIGHT")


def puerta_interruptor(p):
	"""Rejilla de cobre con el ojo: se abre con un interruptor."""
	frame = p.box(-0.9, 0.9, -0.12, 0.12, 0.0, 0.15) + p.box(-0.9, 0.9, -0.12, 0.12, 2.15, 2.3)
	bars = []
	for i in range(6):
		x = -0.75 + i * 0.3
		bars += p.box(x - 0.05, x + 0.05, -0.06, 0.06, 0.15, 2.15)
	p.paint(frame + bars, "cobre_verde", z_range=(0, 2.3), vary=0.05)
	p.paint(epi.eye(p, Vector((0, -0.12, 1.65)), 0.3, depth=0.04), "dorado", "LIGHT")


def puerta_jefe(p):
	"""Losa violeta con el gran ojo y marco dorado."""
	leaf(p, "sello")
	frame = p.box(-0.9, 0.9, -0.19, -0.15, 0.0, 0.1) + p.box(-0.9, -0.82, -0.19, -0.15, 0.0, 2.0) + p.box(0.82, 0.9, -0.19, -0.15, 0.0, 2.0)
	p.paint(frame, "dorado", "MID")
	p.paint(epi.eye(p, Vector((0, -0.15, 1.35)), 0.5, depth=0.06, pupil_swatch="doom"), "hueso", "LIGHT")


piece("puerta_madera", 11, puerta_madera)
piece("puerta_llave", 12, puerta_llave)
piece("puerta_persiana", 13, puerta_persiana)
piece("puerta_interruptor", 14, puerta_interruptor)
piece("puerta_jefe", 15, puerta_jefe)


# --- decoración ---

def antorcha_pared(p):
	"""Soporte de cobre para la pared (el origen es el punto de la pared, la llama va a 0.45 m adelante)."""
	plate = p.box(-0.12, 0.12, -0.04, 0.0, -0.2, 0.2)
	arm = p.box(-0.04, 0.04, -0.4, -0.04, -0.04, 0.04)
	bowl = p.lathe([(0.05, -0.08), (0.16, 0.0), (0.18, 0.08), (0.14, 0.08), (0.0, 0.0)], sides=8)
	p.transform(bowl, Matrix.Translation((0, -0.45, 0.04)))
	p.paint(plate + arm + bowl, "cobre_verde", "MID", vary=0.06)
	coals = p.blob((0, -0.45, 0.12), 0.11, squash=(1, 1, 0.5), subdiv=1, rough=0.2)
	p.paint(coals, "fuego", "DARK")
	return {"llama": [0.0, 0.2, 0.45]}


def brasero(p):
	"""Pedestal de tres gradas de cantos gastados y un cuenco de cobre redondo con borde y brasas."""
	z = 0.0
	parts = []
	for w, h in ((0.8, 0.2), (0.55, 0.5), (0.7, 0.12)):
		parts += p.rounded_box(-w / 2, w / 2, -w / 2, w / 2, z, z + h, radius=0.03, segments=2)
		z += h
	p.paint(parts, STONE, z_range=(0, 1.0), vary=0.05)
	bowl = p.lathe([(0.2, z), (0.27, z + 0.04), (0.36, z + 0.12), (0.42, z + 0.19), (0.44, z + 0.215), (0.42, z + 0.235), (0.38, z + 0.2), (0.0, z + 0.12)], sides=20)
	p.paint(bowl, "cobre_verde", "MID")
	coals = p.blob((0, 0, z + 0.16), 0.3, squash=(1, 1, 0.35), subdiv=2, rough=0.3)
	p.paint(coals, "fuego", "DARK", vary=0.1)
	return {"llama": [0.0, z + 0.25, 0.0]}


def estandarte(p):
	"""Tela de aguayo colgada de una vara (contra la pared, mirando a -Y)."""
	rod = p.cylinder(0.03, -0.55, 0.55, sides=6)
	p.transform(rod, Matrix.Translation((0, -0.06, 2.2)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
	p.paint(rod, "madera_oscura", "MID")
	stripes = [("tela_roja", 0.32), ("flor_amarilla", 0.06), ("tela_azul", 0.12), ("hueso", 0.06), ("tela_roja", 0.38), ("hueso", 0.06), ("tela_azul", 0.12), ("flor_amarilla", 0.06), ("tela_roja", 0.32)]
	z = 2.18
	for swatch, h in stripes:
		band = p.box(-0.45, 0.45, -0.05, -0.03, z - h, z)
		p.paint(band, swatch, "MID")
		z -= h
	fringe = []
	for i in range(9):
		x = -0.4 + i * 0.1
		fringe += p.box(x - 0.015, x + 0.015, -0.05, -0.03, z - 0.12, z)
	p.paint(fringe, "paja", "MID")


def escombros(p):
	chunks = []
	for _ in range(6):
		x, y = p.rng.uniform(-0.7, 0.7), p.rng.uniform(-0.6, 0.6)
		s = p.rng.uniform(0.1, 0.25)
		c = p.box(x - s, x + s, y - s * 0.8, y + s * 0.8, 0.0, s, taper=0.03)
		p.jitter(c, 0.04)
		chunks += c
	p.paint(chunks, STONE, vary=0.15)


def venas_doom(p):
	"""Raíces rojas que cruzan el piso (decoración del doom, sobre el piso)."""
	veins = []
	for _ in range(4):
		pos = Vector((p.rng.uniform(-0.9, 0.9), p.rng.uniform(-0.9, 0.9), 0.0))
		d = Vector((p.rng.uniform(-1, 1), p.rng.uniform(-1, 1), 0)).normalized()
		for _ in range(4):
			seg = d * p.rng.uniform(0.2, 0.35)
			c = p.cylinder(0.04, 0.0, seg.length, sides=5, radius_top=0.025)
			p.transform(c, Matrix.Translation(pos + Vector((0, 0, 0.02))) @ seg.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4())
			veins += c
			pos = pos + seg
			d = (d + Vector((p.rng.uniform(-0.6, 0.6), p.rng.uniform(-0.6, 0.6), 0))).normalized()
	p.paint(veins, "doom", "MID", vary=0.1)


SPIKE_GRID = (-0.6, 0.0, 0.6)


def pinchos_base(p):
	"""Marco de hierro y nueve agujeros apoyados sobre cualquier piso (la trampa de pinchos); las púas salen de pinchos."""
	frame = []
	for x0, x1, y0, y1 in ((-0.92, 0.92, -0.92, -0.84), (-0.92, 0.92, 0.84, 0.92), (-0.92, -0.84, -0.84, 0.84), (0.84, 0.92, -0.84, 0.84)):
		frame += p.box(x0, x1, y0, y1, 0.0, 0.03)
	p.paint(frame, "hierro", "MID")
	holes = []
	for x in SPIKE_GRID:
		for y in SPIKE_GRID:
			holes += p.box(x - 0.16, x + 0.16, y - 0.16, y + 0.16, 0.0, 0.008)
	p.paint(holes, "noche", "DARK")


def pinchos(p):
	"""Nueve púas de hierro de 0.75 m con el origen a ras del piso; el código las sube y baja."""
	spikes, collars = [], []
	for x in SPIKE_GRID:
		for y in SPIKE_GRID:
			spikes += p.cylinder(0.12, 0.05, 0.75, sides=4, radius_top=0.006, center=(x, y), phase=math.pi / 4)
			collars += p.box(x - 0.13, x + 0.13, y - 0.13, y + 0.13, -0.02, 0.06)
	p.paint(spikes, "hierro", z_range=(0.0, 0.75), vary=0.05)
	p.paint(collars, "hierro", "DARK")


piece("pinchos_base", 22, pinchos_base)
piece("pinchos", 23, pinchos)
piece("antorcha_pared", 16, antorcha_pared)
piece("brasero", 17, brasero, smooth=40)
piece("estandarte", 18, estandarte)
piece("escombros", 20, escombros)
piece("venas_doom", 21, venas_doom)


# --- enemigos fijos y jefe ---

def torreta(p):
	"""Ojo menor: tótem de piedra con la cuenca adelante a 1.1 m (el globo es ojo_globo de lugares.blend)."""
	z = 0.0
	parts = []
	for w, h in ((1.0, 0.2), (0.8, 0.6), (0.9, 0.7), (0.7, 0.15)):
		parts += p.box(-w / 2, w / 2, -w / 2, w / 2, z, z + h)
		z += h
	p.paint(parts, STONE, z_range=(0, 2.0), vary=0.06)
	brow = p.box(-0.45, 0.45, -0.52, -0.45, 1.35, 1.45)
	p.paint(brow, "doom", "MID")
	socket = p.lathe([(0.3, 0.0), (0.3, 0.05), (0.24, 0.05), (0.24, 0.0)], sides=12, caps=False)
	p.transform(socket, Matrix.Translation((0, -0.45, 1.1)) @ UPRIGHT)
	p.paint(socket, "doom", "LIGHT")
	return {"centro_ojo": [0.0, 1.1, 0.45]}


def piso_arena(p):
	"""Piso de la sala del jefe: arena con un anillo de lajas."""
	base = p.box(-1, 1, -1, 1, -0.5, 0.0)
	p.paint([f for f in base if f.normal.z <= 0.5], "gris_5", "MID")
	p.paint([f for f in base if f.normal.z > 0.5], "tierra", "LIGHT")
	for _ in range(3):
		x, y = p.rng.uniform(-0.7, 0.7), p.rng.uniform(-0.7, 0.7)
		p.paint(p.blob((x, y, 0.0), p.rng.uniform(0.05, 0.1), squash=(1.3, 1, 0.4), subdiv=1, rough=0.3, flat_bottom=0.0), STONE, vary=0.1)


piece("torreta", 22, torreta)
piece("piso_arena", 26, piso_arena)


# --- hueco (lados: 0 = -X, 1 = -Y, 2 = +X, 3 = +Y; las variantes giran en tools/vary_temple.gd) ---

PIT_DEPTH = -3.0


def pit_wall(p, side):
	"""Muro de piedra del lado side, de 0 a PIT_DEPTH, que se oscurece hacia abajo; tapa los costados del piso vecino."""
	before = set(p.bm.faces)
	epi.stone_wall(p, PIT_DEPTH, -0.06, swatch=STONE, rows=(0.4, 0.15), widths=(0.55, 0.4), mortar=MORTAR, depth=0.05,
		vary=0.06, sides=[Vector((0, -1, 0))], size=(1.0, 0.06))
	lip = p.box(-1.0, 1.0, -0.06, 0.06, -0.06, 0.0)
	p.paint(lip, STONE, "LIGHT", vary=0.03)
	faces = [f for f in p.bm.faces if f not in before]
	p.paint_bands([f for f in faces if f.calc_center_median().z < -1.0], [(-2.0, -1.0, "gris_4", "MID"), (PIT_DEPTH - 1, -2.0, "gris_5", "DARK")])
	p.transform(faces, Matrix.Rotation((side + 1) * math.pi / 2, 4, "Z") @ Matrix.Translation((0, 0.94, 0)))


def hueco(sides):
	def build(p):
		p.paint(p.box(-1, 1, -1, 1, PIT_DEPTH - 0.1, PIT_DEPTH), "gris_5", "DARK")
		for side in sides:
			pit_wall(p, side)
	return build


piece("hueco", 27, hueco(()))
piece("hueco_borde", 28, hueco((0,)))
piece("hueco_esquina", 29, hueco((0, 1)))
piece("hueco_pasillo", 30, hueco((0, 2)))
piece("hueco_punta", 31, hueco((0, 1, 2)))
piece("hueco_pozo", 32, hueco((0, 1, 2, 3)))

epi.layout(kit, columns=7, spacing=3.5)
epi.publish("templo" if STYLE_NAME == "templo" else "templo_" + STYLE_NAME)
