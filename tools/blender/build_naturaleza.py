# Publica assets/epiphany/naturaleza.glb (epi.publish; el .blend de trabajo en art/blender/): vegetación y rocas del altiplano. Origen en la base, sin piso.
# blender -b -P tools/blender/build_naturaleza.py
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

kit = epi.start()


def piece(name, seed, fn):
	p = epi.Piece(seed)
	fn(p)
	p.build(name, kit)


def branch(p, start, direction, length, r0, r1, segments=3, bend=0.35):
	"""Rama torcida: tramos de cilindro que van cambiando de dirección. Devuelve las caras y la punta."""
	faces = []
	pos = Vector(start)
	d = Vector(direction).normalized()
	for i in range(segments):
		seg = length / segments
		ra = r0 + (r1 - r0) * i / segments
		rb = r0 + (r1 - r0) * (i + 1) / segments
		c = p.cylinder(ra, 0.0, seg + rb * 0.5, sides=6, radius_top=rb, cap_bottom=(i == 0), phase=p.rng.random())
		rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
		p.transform(c, Matrix.Translation(pos) @ rot)
		faces += c
		pos = pos + d * seg
		d = (d + Vector((p.rng.uniform(-bend, bend), p.rng.uniform(-bend, bend), p.rng.uniform(0, bend * 0.6)))).normalized()
	return faces, pos


def quenoa(p, height, spread, trunks, clusters):
	"""Queñoa: varios troncos retorcidos de corteza rojiza y copas chatas de hojas oscuras en las puntas."""
	bark, leaves = [], []
	tips = []
	for t in range(trunks):
		a = 2 * math.pi * t / trunks + p.rng.random()
		direction = Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, 1.0))
		f, tip = branch(p, (math.cos(a) * 0.08, math.sin(a) * 0.08, -0.05), direction, height * 0.62, 0.16, 0.07, segments=4)
		bark += f
		tips.append(tip)
		for _ in range(2):
			f2, tip2 = branch(p, tip - direction.normalized() * 0.3, Vector((math.cos(a + p.rng.uniform(-1, 1)), math.sin(a + p.rng.uniform(-1, 1)), 0.6)), height * 0.3, 0.07, 0.03, segments=2)
			bark += f2
			tips.append(tip2)
	for tip in tips[:clusters]:
		for _ in range(3):
			r = spread * (0.2 + p.rng.random() * 0.13)
			off = Vector((p.rng.uniform(-1, 1), p.rng.uniform(-1, 1), p.rng.uniform(-0.3, 0.5))) * r * 0.9
			leaves += p.blob(tip + off + Vector((0, 0, r * 0.2)), r, squash=(1.2, 1.2, 0.6), subdiv=1, rough=0.35)
	p.paint(bark, "madera_oscura", z_range=(0, height * 0.7), vary=0.1)
	zs = [v.co.z for f in leaves for v in f.verts]
	z0, z1 = min(zs), max(zs)
	p.paint(leaves, "follaje", z_range=(z0, z1 + (z1 - z0) * 0.6), vary=0.1)


piece("quenoa_grande", 1, lambda p: quenoa(p, 3.4, 1.5, 3, 9))
piece("quenoa_chica", 2, lambda p: quenoa(p, 2.3, 1.1, 2, 6))


def ribbed(p, radius, z0, z1, ribs=8, depth=0.18, center=(0, 0), round_top=True):
	"""Columna acanalada de cardón: perfil de estrella extruido, con la punta redondeada."""
	cx, cy = center
	pts = []
	for i in range(ribs * 2):
		a = math.pi * i / ribs
		r = radius if i % 2 == 0 else radius * (1 - depth)
		pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
	faces = p.polygon(pts, z0, z1)
	if round_top:
		faces += p.lathe([(radius * 0.92, z1), (radius * 0.75, z1 + radius * 0.45), (radius * 0.35, z1 + radius * 0.8), (0, z1 + radius * 0.9)], sides=ribs * 2, center=center)
	return faces


def cardon(p, height, arms):
	body = ribbed(p, 0.24, 0.0, height)
	for i, (a, h) in enumerate(arms):
		ox, oy = math.cos(a), math.sin(a)
		elbow_out = 0.45
		z = height * h
		elbow = p.cylinder(0.15, 0.0, elbow_out, sides=8, radius_top=0.15)
		rot = Vector((ox, oy, 0.35)).to_track_quat("Z", "Y").to_matrix().to_4x4()
		p.transform(elbow, Matrix.Translation((ox * 0.15, oy * 0.15, z)) @ rot)
		body += elbow
		up_h = height * (0.35 + p.rng.random() * 0.2)
		body += ribbed(p, 0.17, z + 0.08, z + up_h, center=(ox * (elbow_out * 0.9 + 0.12), oy * (elbow_out * 0.9 + 0.12)))
	p.paint(body, "follaje", z_range=(-height * 0.2, height * 1.5), vary=0.05)
	if p.rng.random() < 0.7:
		p.paint(p.blob((0.05, 0.0, height + 0.24), 0.08, subdiv=1, rough=0.0), "blanco", "LIGHT")


piece("cardon_a", 3, lambda p: cardon(p, 2.6, [(0.4, 0.45), (3.4, 0.55)]))
piece("cardon_b", 4, lambda p: cardon(p, 1.8, [(2.2, 0.5)]))
piece("cardon_chico", 5, lambda p: cardon(p, 0.9, []))


def tuft(p, x, y, height, blades, swatch="paja", radius=0.035, lean=(0.25, 0.6)):
	faces = []
	for i in range(blades):
		a = 2 * math.pi * i / blades + p.rng.random() * 0.6
		tilt = lean[0] + p.rng.random() * (lean[1] - lean[0])
		h = height * (0.65 + p.rng.random() * 0.45)
		blade = p.cylinder(radius, 0.0, h, sides=3, radius_top=0.0, cap_bottom=False, phase=p.rng.random() * 3)
		m = Matrix.Rotation(tilt, 4, Vector((-math.sin(a), math.cos(a), 0)))
		p.transform(blade, Matrix.Translation((x + math.cos(a) * 0.06, y + math.sin(a) * 0.06, 0)) @ m)
		faces += blade
	p.paint(faces, swatch, z_range=(0.0, height * 1.1))


def ichu_mata(p):
	tuft(p, 0.0, 0.0, 0.75, 16, radius=0.045)
	tuft(p, 0.12, -0.08, 0.55, 9, radius=0.04, lean=(0.1, 0.4))


def ichu_cortado(p):
	stubs = []
	for i in range(14):
		a = 2 * math.pi * i / 14
		h = 0.08 + p.rng.random() * 0.08
		s = p.cylinder(0.035, 0.0, h, sides=3, radius_top=0.02, cap_bottom=False)
		p.transform(s, Matrix.Translation((math.cos(a) * 0.12, math.sin(a) * 0.12, 0)))
		stubs += s
	p.paint(stubs, "paja", "DARK", vary=0.1)


piece("ichu_mata", 6, ichu_mata)
piece("ichu_cortado", 7, ichu_cortado)


def tola(p):
	"""Arbusto bajo y redondo, verde oliva."""
	parts = []
	for _ in range(5):
		parts += p.blob((p.rng.uniform(-0.3, 0.3), p.rng.uniform(-0.3, 0.3), 0.3 + p.rng.random() * 0.15), 0.35 + p.rng.random() * 0.12, squash=(1, 1, 0.75), subdiv=1, rough=0.35, flat_bottom=0.0)
	p.paint(parts, "musgo", z_range=(0, 0.9), vary=0.08)


piece("tola", 8, tola)


def roca(p, size, squash, swatch="piedra"):
	f = p.blob((0, 0, size * squash[2] * 0.55), size, squash=squash, subdiv=2, rough=0.28, flat_bottom=0.0)
	p.paint(f, swatch, z_range=(0, size * squash[2] * 1.4), vary=0.06)


piece("roca_grande_a", 9, lambda p: roca(p, 0.95, (1.0, 0.9, 0.8)))
piece("roca_grande_b", 10, lambda p: roca(p, 0.85, (1.2, 0.8, 0.65), "acantilado"))
piece("roca_alta", 11, lambda p: roca(p, 0.6, (0.8, 0.8, 1.9)))
piece("roca_fisica", 12, lambda p: roca(p, 0.62, (1.0, 1.0, 0.95)))
piece("piedra_chica_a", 13, lambda p: roca(p, 0.22, (1.3, 1.0, 0.6)))
piece("piedra_chica_b", 14, lambda p: roca(p, 0.3, (1.0, 1.1, 0.5), "acantilado"))


def tronco_caido(p):
	f, _ = branch(p, (-0.9, 0.0, 0.18), (1.0, 0.0, 0.05), 1.9, 0.2, 0.14, segments=3, bend=0.12)
	stub, _ = branch(p, (-0.2, 0.1, 0.25), (0.2, 1.0, 0.5), 0.5, 0.07, 0.03, segments=2)
	p.paint(f + stub, "madera_oscura", "MID", vary=0.12)


piece("tronco_caido", 15, tronco_caido)


def tocon(p):
	"""Tocón de queñoa: el corte claro arriba, mellado, y tres raíces."""
	trunk = p.cylinder(0.24, 0.0, 0.42, sides=8, radius_top=0.2)
	for v in {v for f in trunk for v in f.verts if v.co.z > 0.4}:
		v.co.z += (p.rng.random() - 0.5) * 0.1
	p.paint([f for f in trunk if f.normal.z <= 0.6], "madera_oscura", "MID", vary=0.1)
	p.paint([f for f in trunk if f.normal.z > 0.6], "madera", "LIGHT")
	roots = []
	for i in range(3):
		a = 2 * math.pi * i / 3 + p.rng.random() * 0.8
		r, _ = branch(p, (math.cos(a) * 0.15, math.sin(a) * 0.15, 0.12), (math.cos(a), math.sin(a), -0.35), 0.45, 0.09, 0.03, segments=2, bend=0.2)
		roots += r
	p.paint(roots, "madera_oscura", "DARK", vary=0.1)


def yareta(p):
	"""Yareta: cojín verde vivo, achatado y lleno de bultitos."""
	base = p.blob((0, 0, 0.12), 0.55, squash=(1.2, 1.0, 0.45), subdiv=2, rough=0.12, flat_bottom=0.0)
	p.paint(base, "follaje", z_range=(0.0, 0.45), vary=0.05)
	bumps = []
	for _ in range(9):
		a = p.rng.random() * 2 * math.pi
		d = p.rng.random() * 0.45
		bumps += p.blob((math.cos(a) * d * 1.2, math.sin(a) * d, 0.28 - d * 0.25), 0.13 + p.rng.random() * 0.06, squash=(1, 1, 0.6), subdiv=1, rough=0.2)
	p.paint(bumps, "follaje", "LIGHT", vary=0.08)


def flores(p):
	"""Macizo de flores silvestres sobre una mata baja."""
	p.paint(p.blob((0, 0, 0.05), 0.38, squash=(1.3, 1.0, 0.35), subdiv=1, rough=0.3, flat_bottom=0.0), "musgo", "MID", vary=0.08)
	stems, heads = [], []
	color = p.rng.choice(["flor_amarilla", "flor_rosa"])
	for _ in range(9):
		fx, fy = p.rng.uniform(-0.38, 0.38), p.rng.uniform(-0.28, 0.28)
		h = 0.22 + p.rng.random() * 0.18
		stems += p.box(fx - 0.016, fx + 0.016, fy - 0.016, fy + 0.016, 0.05, h)
		heads.append((p.blob((fx, fy, h + 0.03), 0.065, subdiv=1, rough=0.0, squash=(1, 1, 0.55)), color if p.rng.random() < 0.7 else "blanco"))
	p.paint(stems, "follaje", "DARK")
	for faces, swatch in heads:
		p.paint(faces, swatch, "LIGHT", vary=0.08)


def hongos(p):
	"""Tres hongos de sombrero ancho, para el pie de las queñoas."""
	parts_stem, parts_cap = [], []
	for x, y, h, r in ((0.0, 0.0, 0.22, 0.13), (0.18, 0.1, 0.15, 0.09), (-0.12, 0.14, 0.11, 0.07)):
		parts_stem += p.cylinder(r * 0.35, 0.0, h, sides=6, center=(x, y))
		parts_cap += p.blob((x, y, h), r, squash=(1, 1, 0.5), subdiv=1, rough=0.05)
	p.paint(parts_stem, "hueso", "LIGHT")
	p.paint(parts_cap, "tela_roja", "MID", vary=0.08)


piece("tocon", 16, tocon)
piece("yareta", 17, yareta)
piece("flores", 18, flores)
piece("hongos", 19, hongos)
epi.layout(kit, columns=6, spacing=3.5)
epi.publish("naturaleza", material="outdoor", materials={n: "wind" for n in ("quenoa_grande", "quenoa_chica", "ichu_mata", "ichu_cortado", "tola", "flores")})
