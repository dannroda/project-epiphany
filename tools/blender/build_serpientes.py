# Publica assets/epiphany/serpientes.glb (epi.publish): los jefes de la Totora como anguilas o serpientes de agua.
# *_cuello: el cuello parado, centrado en el origen a lo largo de Z, ondulado en S hacia los costados, con panza clara
# hacia +Y (adelante) y aleta dorsal atrás. *_cabeza: la cabeza con el origen en su nodo y el hocico hacia +Y.
# yacumama_cola: la cola que barre la sala, de y 0 a 9 con la aleta al final.
# blender -b --factory-startup -P tools/blender/build_serpientes.py
import math
import os
import sys

from mathutils import Matrix, Vector, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

kit = epi.start()

AMARU = {"skin": "musgo", "belly": "paja", "fin": "cobre_verde", "eye": "neon", "spots": None, "gold": None,
	"length": 2.0, "radius": 0.4, "head": Vector((0, 0.2, 1.05)), "scale": 1.3, "sway": 0.22}
YACUMAMA = {"skin": "cobre_verde", "belly": "tierra", "fin": "tela_roja", "eye": "doom", "spots": "noche", "gold": "dorado",
	"length": 3.2, "radius": 0.6, "head": Vector((0, 0.3, 1.6)), "scale": 1.9, "sway": 0.32}


def piece(name, seed, fn, smooth=45):
	p = epi.Piece(seed)
	fn(p)
	return p.build(name, kit, smooth=smooth)


def tube(p, centers, radii, sides=12, ref=Vector((0, 1, 0)), squash=(1.0, 1.0)):
	"""Tubo por una serie de centros; ref marca hacia dónde mira el segundo eje de cada anillo. Cierra las puntas."""
	rings = []
	for i, (c, r) in enumerate(zip(centers, radii)):
		t = (centers[min(i + 1, len(centers) - 1)] - centers[max(i - 1, 0)]).normalized()
		right = ref.cross(t).normalized()
		fwd = t.cross(right).normalized()
		rings.append([p.bm.verts.new(c + right * r * squash[0] * math.cos(a) + fwd * r * squash[1] * math.sin(a))
			for a in (2 * math.pi * k / sides for k in range(sides))])
	faces = []
	for a, b in zip(rings, rings[1:]):
		for k in range(sides):
			faces.append(p.bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k])))
	for ring, c, flip in ((rings[0], centers[0], True), (rings[-1], centers[-1], False)):
		tip = p.bm.verts.new(c)
		for k in range(sides):
			f = (ring[k], ring[(k + 1) % sides], tip)
			faces.append(p.bm.faces.new(f[::-1] if flip else f))
	return faces


def fin(p, bases, tips, thick=0.025, side=Vector((1, 0, 0))):
	"""Aleta fina: una lámina entre la fila de bases (metida en el cuerpo) y la de puntas, con grosor hacia side."""
	off = side.normalized() * thick
	bl = [p.bm.verts.new(b - off) for b in bases]
	br = [p.bm.verts.new(b + off) for b in bases]
	tl = [p.bm.verts.new(t - off) for t in tips]
	tr = [p.bm.verts.new(t + off) for t in tips]
	faces = []
	for i in range(len(bases) - 1):
		faces.append(p.bm.faces.new((bl[i], tl[i], tl[i + 1], bl[i + 1])))
		faces.append(p.bm.faces.new((br[i + 1], tr[i + 1], tr[i], br[i])))
		faces.append(p.bm.faces.new((tl[i], tr[i], tr[i + 1], tl[i + 1])))
	faces.append(p.bm.faces.new((bl[0], br[0], tr[0], tl[0])))
	faces.append(p.bm.faces.new((tl[-1], tr[-1], br[-1], bl[-1])))
	return faces


def spine_paint(p, faces, c, belly_axis, along, freq=1.6, threshold=0.35):
	"""Panza clara del lado de belly_axis y piel; con manchas, pares de manchas de anaconda a lo largo de along."""
	belly, skin, spots = [], [], []
	for f in faces:
		f.normal_update()
		n = f.normal.dot(belly_axis)
		center = f.calc_center_median()
		phase = center.dot(along) * freq + (0.5 if center.x > 0 else 0.0)
		if n > threshold:
			belly.append(f)
		elif c["spots"] and n < 0.1 and phase % 1.0 < 0.32:
			spots.append(f)
		else:
			skin.append(f)
	p.paint(belly, c["belly"], "MID", vary=0.08)
	p.paint(skin, c["skin"], "LOW" if c["spots"] else "MID", vary=0.1)
	if spots:
		p.paint(spots, c["spots"], "LIGHT", vary=0.05)


def cuello(p, c):
	half = c["length"] / 2
	r = c["radius"]
	top = c["head"] + Vector((0, -0.15, -0.1)) * c["scale"]
	n = 16
	centers, radii = [], []
	for i in range(n + 1):
		t = i / n
		z = -half + t * (top.z + half)
		x = c["sway"] * math.sin(2 * math.pi * t) * (1.0 - 0.3 * t)
		y = top.y * t * t
		centers.append(Vector((x, y, z)))
		radii.append(r * (1.0 - 0.22 * t) * (1.0 + 0.06 * math.sin(t * 9)))
	body = tube(p, centers, radii, sides=14)
	spine_paint(p, body, c, Vector((0, 1, 0)), Vector((0, 0, 1)))
	bases, tips = [], []
	for i in range(3, n + 1):
		t = i / n
		back = centers[i] + Vector((0, -1, 0)) * radii[i] * 0.75
		h = r * (0.35 + 0.18 * math.sin(t * 14)) * min(1.0, (t - 0.15) * 4)
		bases.append(back)
		tips.append(back + Vector((0, -h, h * 0.25)))
	dorsal = fin(p, bases, tips, thick=0.03 * r / 0.4)
	p.paint(dorsal, c["fin"], "MID", vary=0.1)
	for s in (-1, 1):
		i = int(n * 0.72)
		root = centers[i] + Vector((s * radii[i] * 0.85, 0, 0))
		pts = [root + Vector((s * r * 0.9 * math.sin(a), -r * 0.4 * math.cos(a), -r * 0.6 * math.sin(a))) for a in (0.0, 0.6, 1.2, 1.7, 2.2)]
		pec = fin(p, [root + Vector((0, 0.04, -0.06 * k)) for k in range(len(pts))], pts, thick=0.02, side=Vector((0, 1, 0.2)))
		p.paint(pec, c["fin"], "LIGHT", vary=0.1)


def cabeza(p, c):
	skull = p.lathe([(0.0, -0.42), (0.22, -0.4), (0.33, -0.25), (0.36, -0.05), (0.32, 0.15), (0.24, 0.35), (0.15, 0.5), (0.06, 0.57), (0.0, 0.58)], sides=14)
	p.transform(skull, Matrix.Translation((0, 0, 0.06)) @ Matrix.Diagonal((1, 1, 0.6, 1)) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
	mouth, back = [], []
	for f in skull:
		f.normal_update()
		(mouth if f.normal.z < -0.55 and f.calc_center_median().y > -0.15 else back).append(f)
	spine_paint(p, back, dict(c, spots=None), Vector((0, 0, -1)), Vector((0, 1, 0)), threshold=2.0)
	p.paint(mouth, "tela_roja", "DARK", vary=0.05)
	jaw = p.lathe([(0.0, -0.3), (0.2, -0.28), (0.28, -0.1), (0.25, 0.15), (0.15, 0.38), (0.0, 0.48)], sides=12)
	p.transform(jaw, Matrix.Translation((0, -0.12, -0.1)) @ Matrix.Rotation(-0.2, 4, "X") @ Matrix.Translation((0, 0.12, 0))
		@ Matrix.Diagonal((1, 1, 0.38, 1)) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
	p.paint(jaw, c["belly"], "MID", vary=0.08)
	teeth = []
	for s in (-1, 1):
		for y, rad in ((0.1, 0.3), (0.24, 0.25), (0.37, 0.19), (0.48, 0.12)):
			t = p.cylinder(0.028, 0.0, -0.1, sides=4, radius_top=0.0)
			p.transform(t, Matrix.Translation((s * rad * 0.82, y, 0.06 - 0.6 * rad * 0.55)))
			teeth += t
	p.paint(teeth, "hueso", "LIGHT")
	for s in (-1, 1):
		brow = p.blob((s * 0.2, 0.02, 0.24), 0.11, squash=(1.0, 1.4, 0.55), rough=0.05)
		p.paint(brow, c["skin"], "LOW" if c["spots"] else "MID")
		eye = p.blob((s * 0.25, 0.1, 0.2), 0.075, squash=(0.8, 1.0, 1.0), rough=0.0)
		p.paint(eye, c["eye"], "LIGHT")
		pupil = p.box(-0.012, 0.012, -0.02, 0.02, -0.05, 0.05)
		p.transform(pupil, Matrix.Translation((s * 0.31, 0.13, 0.2)))
		p.paint(pupil, "noche", "DARK")
		spines = []
		for k, (up, out) in enumerate(((0.55, 0.25), (0.2, 0.55), (-0.2, 0.5))):
			root = Vector((s * 0.3, -0.25 + k * 0.04, 0.06))
			tip = root + Vector((s * out * 0.55, -0.32, up * 0.45))
			mid = (root + tip) / 2 + Vector((s * 0.05, -0.02, 0.04))
			spines.append((root, mid, tip))
		bases = [Vector((s * 0.3, -0.2, 0.2)), Vector((s * 0.33, -0.22, 0.04)), Vector((s * 0.3, -0.2, -0.1))]
		tips = [sp[2] for sp in spines]
		frill = fin(p, bases, tips, thick=0.018, side=Vector((s, 0.4, 0)))
		p.paint(frill, c["fin"], "MID", vary=0.1)
		for root, mid, tip in spines:
			rib = tube(p, [root, mid, tip], [0.03, 0.025, 0.01], sides=5, ref=Vector((0, 0, 1)))
			p.paint(rib, c["fin"], "LOW")
	crest = fin(p, [Vector((0, y, 0.24 - 0.3 * (y + 0.45) ** 2)) for y in (0.0, -0.15, -0.3, -0.42)],
		[Vector((0, y - 0.06, 0.38 + 0.06 * math.sin(y * 18) - 0.2 * (y + 0.45) ** 2)) for y in (0.0, -0.15, -0.3, -0.42)], thick=0.02)
	p.paint(crest, c["fin"], "MID", vary=0.1)
	for s in (-1, 1):
		nostril = p.box(-0.02, 0.02, -0.025, 0.025, -0.01, 0.01)
		p.transform(nostril, Matrix.Translation((s * 0.07, 0.5, 0.11)))
		p.paint(nostril, "noche", "DARK")
	if c["gold"]:
		plate = epi.chakana_plate(p, Vector((0, 0, 0)), 0.3, c["gold"])
		p.transform(plate, Matrix.Translation((0, 0.18, 0.255)) @ Matrix.Rotation(math.pi / 2 - 0.25, 4, "X"))
		horns = []
		for s in (-1, 1):
			root = Vector((s * 0.17, -0.12, 0.22))
			horns += tube(p, [root, root + Vector((s * 0.12, -0.16, 0.14)), root + Vector((s * 0.16, -0.36, 0.2))], [0.06, 0.04, 0.008], sides=6, ref=Vector((0, 0, 1)))
		p.paint(horns, c["gold"], "MID", vary=0.05)
	else:
		barbels = []
		for s in (-1, 1):
			root = Vector((s * 0.16, 0.4, -0.02))
			barbels += tube(p, [root, root + Vector((s * 0.06, -0.05, -0.16)), root + Vector((s * 0.03, -0.18, -0.28))], [0.03, 0.02, 0.006], sides=5, ref=Vector((0, 1, 0)))
		p.paint(barbels, c["fin"], "LIGHT")
	p.transform(list(p.bm.faces), Matrix.Scale(c["scale"], 4))


def cola(p, c):
	n = 24
	length = 9.0
	centers, radii = [], []
	for i in range(n + 1):
		t = i / n
		centers.append(Vector((0.25 * math.sin(t * math.pi * 2.0) * t, t * (length - 0.9), 0.28 - 0.12 * t)))
		radii.append(0.36 * (1.0 - 0.78 * t) + 0.02)
	body = tube(p, centers, radii, sides=10, ref=Vector((0, 0, 1)), squash=(1.0, 0.85))
	spine_paint(p, body, c, Vector((0, 0, -1)), Vector((0, 1, 0)), freq=0.9)
	ridge = []
	for i in range(1, n - 2, 2):
		top = centers[i] + Vector((0, 0, radii[i] * 0.8))
		spike = tube(p, [top, top + Vector((0, 0.18, radii[i] * 0.9 + 0.06))], [0.08 * radii[i] / 0.36 + 0.03, 0.005], sides=4, ref=Vector((1, 0, 0)))
		ridge += spike
	p.paint(ridge, c["fin"], "MID", vary=0.1)
	end = centers[-1]
	bases = [end + Vector((0, -0.9 + 0.3 * k, 0)) for k in range(4)] + [end + Vector((0, 0.1, 0))]
	tips = [b + Vector((0, 0.15 + 0.12 * k, 0.12 + 0.2 * k)) for k, b in enumerate(bases)]
	tips[-1] = end + Vector((0, 0.9, 0.35))
	tail_fin = fin(p, bases, tips, thick=0.025)
	low = fin(p, bases, [Vector((t.x, t.y, 2 * b.z - t.z)) for b, t in zip(bases, tips)], thick=0.025)
	p.paint(tail_fin + low, c["fin"], "MID", vary=0.1)


piece("amaru_cuello", 1, lambda p: cuello(p, AMARU))
piece("amaru_cabeza", 2, lambda p: cabeza(p, AMARU))
piece("yacumama_cuello", 3, lambda p: cuello(p, YACUMAMA))
piece("yacumama_cabeza", 4, lambda p: cabeza(p, YACUMAMA))
piece("yacumama_cola", 5, lambda p: cola(p, YACUMAMA))

epi.layout(kit, columns=5, spacing=4.0)
epi.publish("serpientes")
