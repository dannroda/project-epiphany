# Publica assets/epiphany/personaje_guerrero_<mazmorra>.glb: los enemigos comunes de cada mazmorra (12.39), sobre el
# Rig_Medium de KayKit como la chullpa, así usan su IA y sus animaciones. Mismo cuerpo (cadera envuelta, torso, brazos y
# piernas por hueso) con los materiales de la mazmorra, y una cabeza propia: Chullpa, momia vendada con máscara de hueso;
# Queñoa, corteza roja de queñoa con musgo y hojas; Totora, junco tejido con capucha; Cumbre, lana con chullo y
# escarcha; Templo, oro con la máscara de sol. Los ojos son del doom en todos.
# blender -b --factory-startup -P tools/blender/build_guerreros.py [-- chullpa queñoa ...]
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_personajes as bp  # noqa: E402
import epi  # noqa: E402

GLOW = "doom"
STYLES = {
	"chullpa": {"bone": "hueso", "body": "tierra", "wrap": "tierra", "accent": "tela_roja", "metal": "cobre_verde", "boot": "madera_oscura"},
	"quenoa": {"bone": "madera_oscura", "body": "roca_naranja", "wrap": "musgo", "accent": "follaje", "metal": "madera", "boot": "madera_oscura"},
	"totora": {"bone": "paja", "body": "paja", "wrap": "tela_azul", "accent": "cobre_verde", "metal": "madera", "boot": "madera"},
	"cumbre": {"bone": "hueso", "body": "gris_2", "wrap": "blanco", "accent": "tela_azul", "metal": "cristal", "boot": "gris_4"},
	"templo": {"bone": "noche", "body": "dorado", "wrap": "noche", "accent": "tela_roja", "metal": "dorado", "boot": "noche"},
}


def eyes(head, hz, y, size=0.08):
	for x in (-0.16, 0.16):
		head.paint(head.blob((x, y, hz - 0.01), size, squash=(1.0, 0.45, 1.0), subdiv=2, rough=0.0), GLOW, "LIGHT")


def head_chullpa(head, hz, s):
	"""Momia: cabeza vendada en franjas, máscara de hueso con los ojos y una diadema de cobre con el ojo del logo."""
	skull = head.blob((0, 0, hz), 0.42, squash=(1.0, 0.95, 1.05), subdiv=3, rough=0.03)
	head.paint_bands(skull, [(hz - 0.3 + i * 0.16, hz - 0.22 + i * 0.16, "hueso", "MID") for i in range(5)], default=(0, 0, s["wrap"], "MID"))
	mask = head.rounded_box(-0.3, 0.3, -0.44, -0.3, hz - 0.3, hz + 0.12, radius=0.08, segments=2)
	head.paint(mask, "hueso", "LIGHT")
	eyes(head, hz, -0.45)
	band = head.lathe([(0.43, hz + 0.16), (0.44, hz + 0.2), (0.43, hz + 0.24), (0.0, hz + 0.24)], sides=18, caps=False)
	head.paint(band, s["metal"], "MID")
	epi.logo_eye(head, Vector((0, -0.45, hz + 0.24)), 0.22, depth=0.015, iris=(GLOW, "MID"))
	for i, x in enumerate((-0.2, 0.0, 0.2)):
		strip = head.rounded_box(x - 0.06, x + 0.06, 0.36, 0.42, hz - 0.8 + i % 2 * 0.15, hz + 0.1, radius=0.025, segments=2)
		head.paint(strip, s["wrap"], "LOW", vary=0.1)


def head_quenoa(head, hz, s):
	"""Corteza: máscara de madera roja de queñoa, musgo en la nuca y una cresta de hojas."""
	block = head.rounded_box(-0.36, 0.36, -0.36, 0.34, hz - 0.42, hz + 0.26, radius=0.12, segments=2)
	head.jitter(block, 0.02)
	head.paint(block, s["body"], z_range=(hz - 0.6, hz + 0.5), vary=0.08)
	for z in (hz - 0.2, hz + 0.05):
		head.paint(head.box(-0.37, 0.37, -0.37, -0.33, z, z + 0.03), s["bone"], "MID")
	head.paint(head.box(-0.28, 0.28, -0.38, -0.34, hz - 0.12, hz + 0.08), "noche", "MID")
	eyes(head, hz - 0.02, -0.39, 0.07)
	moss = head.blob((0, 0.12, hz + 0.2), 0.3, squash=(1.1, 0.9, 0.5), subdiv=2, rough=0.15)
	head.paint(moss, s["wrap"], "MID", vary=0.1)
	leaves = []
	for i in range(7):
		a = -0.9 + i * 0.3
		leaf = head.blob((0.0, 0.0, 0.0), 0.12, squash=(0.35, 1.0, 0.12), subdiv=1, rough=0.0)
		head.transform(leaf, Matrix.Translation((math.sin(a) * 0.28, 0.0, hz + 0.32 + math.cos(a) * 0.12)) @ Matrix.Rotation(a, 4, "Y") @ Matrix.Rotation(1.3, 4, "X"))
		leaves += leaf
	head.paint(leaves, s["accent"], "MID", vary=0.1)


def head_totora(head, hz, s):
	"""Junco: capucha cónica de totora tejida con franjas azules, la cara en sombra con los ojos y un penacho de junco."""
	hood = head.lathe([(0.0, hz - 0.45), (0.42, hz - 0.42), (0.46, hz - 0.1), (0.4, hz + 0.2), (0.26, hz + 0.42), (0.08, hz + 0.6), (0.0, hz + 0.64)], sides=16)
	head.paint_bands(hood, [(hz - 0.3, hz - 0.24, s["wrap"], "MID"), (hz + 0.1, hz + 0.16, s["wrap"], "MID")], default=(0, 0, s["body"], "MID"))
	face = head.rounded_box(-0.27, 0.27, -0.47, -0.38, hz - 0.3, hz + 0.08, radius=0.1, segments=2)
	head.paint(face, "noche", "MID")
	eyes(head, hz - 0.08, -0.48, 0.065)
	reeds = []
	for i in range(5):
		a = (i - 2) * 0.22
		reed = head.cylinder(0.02, 0.0, 0.4, sides=4, radius_top=0.006)
		head.transform(reed, Matrix.Translation((0, 0, hz + 0.58)) @ Matrix.Rotation(a, 4, "Y") @ Matrix.Rotation(0.25, 4, "X"))
		reeds += reed
	head.paint(reeds, "paja", "DARK")
	head.paint(head.blob((0, -0.42, hz + 0.16), 0.06, squash=(1.4, 0.5, 0.8), subdiv=1, rough=0.0), s["accent"], "MID")


def head_cumbre(head, hz, s):
	"""Escarcha: calavera bajo un chullo de lana (franjas, orejeras y pompón) con escarcha de cristal."""
	skull = head.blob((0, 0, hz), 0.4, squash=(1.0, 0.95, 1.05), subdiv=3, rough=0.02)
	head.paint(skull, s["bone"], z_range=(hz - 0.5, hz + 0.6))
	jaw = head.rounded_box(-0.24, 0.24, -0.34, 0.1, hz - 0.5, hz - 0.3, radius=0.09, segments=3)
	head.paint(jaw, s["bone"], "LOW")
	eyes(head, hz, -0.38, 0.075)
	cap = head.lathe([(0.44, hz + 0.02), (0.45, hz + 0.18), (0.4, hz + 0.36), (0.26, hz + 0.5), (0.0, hz + 0.56)], sides=18)
	head.paint_bands(cap, [(hz + 0.08, hz + 0.14, s["wrap"], "MID"), (hz + 0.24, hz + 0.3, s["accent"], "DARK"), (hz + 0.38, hz + 0.44, s["wrap"], "MID")], default=(0, 0, s["accent"], "MID"))
	for side in (-1, 1):
		flap = head.rounded_box(side * 0.36 - 0.07, side * 0.36 + 0.07, -0.12, 0.14, hz - 0.36, hz + 0.08, radius=0.05, segments=2)
		head.paint(flap, s["accent"], "MID")
		head.paint(head.cylinder(0.015, hz - 0.62, hz - 0.36, sides=4, center=(side * 0.36, 0.0)), s["wrap"], "MID")
	head.paint(head.blob((0, 0, hz + 0.6), 0.1, subdiv=2, rough=0.08), s["wrap"], "LIGHT")
	frost = []
	for i in range(6):
		x = -0.2 + i * 0.08
		frost += head.cylinder(0.025, 0.0, 0.1, sides=4, radius_top=0.004, center=(x, -0.3))
	head.transform(frost, Matrix.Translation((0, 0, hz - 0.62)) @ Matrix.Rotation(math.pi, 4, "X") @ Matrix.Translation((0, 0, -0.1)))
	head.paint(frost, s["metal"], "LIGHT")


def head_templo(head, hz, s):
	"""Oro: la máscara de sol, con rayos alrededor de una cara oscura con los ojos y el ojo del logo en la frente."""
	face = head.rounded_box(-0.34, 0.34, -0.36, 0.3, hz - 0.42, hz + 0.24, radius=0.14, segments=2)
	head.paint(face, s["wrap"], "MID")
	rim = head.lathe([(0.4, -0.02), (0.42, 0.0), (0.4, 0.02), (0.0, 0.02)], sides=20, caps=False)
	head.transform(rim, Matrix.Translation((0, -0.34, hz - 0.08)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	head.paint(rim, s["body"], "MID")
	rays = []
	for i in range(12):
		a = 2 * math.pi * i / 12
		ray = head.cylinder(0.06, 0.0, 0.2, sides=4, radius_top=0.01, phase=math.pi / 4)
		head.transform(ray, Matrix.Translation((math.cos(a) * 0.4, -0.3, hz - 0.08 + math.sin(a) * 0.4)) @ Matrix.Rotation(-a + math.pi / 2, 4, "Y"))
		rays += ray
	head.paint(rays, s["body"], "LIGHT")
	eyes(head, hz - 0.1, -0.37, 0.07)
	epi.logo_eye(head, Vector((0, -0.37, hz + 0.12)), 0.24, depth=0.015, iris=(GLOW, "MID"))


HEADS = {"chullpa": head_chullpa, "quenoa": head_quenoa, "totora": head_totora, "cumbre": head_cumbre, "templo": head_templo}


def guerrero(style):
	s = STYLES[style]
	rig = bp.start()
	pts = bp.bone_points(rig)
	body = bp.Body(rig, f"guerrero_{style}", 70 + len(style))
	hips = body.part("hips")
	hips.paint(hips.rounded_box(-0.2, 0.2, -0.13, 0.13, 0.42, 0.62, radius=0.05, segments=2), s["bone"], "LOW")
	wrap = hips.lathe([(0.24, 0.28), (0.28, 0.33), (0.29, 0.45), (0.29, 0.5), (0.29, 0.54), (0.28, 0.58), (0.25, 0.62), (0.0, 0.62)], sides=18)
	hips.paint_bands(wrap, [(0.5, 0.54, s["accent"], "MID")], default=(0, 0, s["wrap"], "LOW"))
	hips.paint(hips.rounded_box(-0.3, 0.3, -0.21, 0.21, 0.56, 0.63, radius=0.03, segments=1), s["boot"], "MID")
	spine = body.part("spine")
	spine.paint(bp.limb(spine, *pts["spine"], 0.07, 0.07, sides=10), s["bone"], "MID")
	chest = body.part("chest")
	torso = chest.rounded_box(-0.26, 0.26, -0.2, 0.14, 0.82, 1.2, radius=0.06, segments=2)
	chest.paint_bands(torso, [(0.92, 0.96, s["accent"], "MID")], default=(0, 0, s["body"], "MID"))
	collar = chest.lathe([(0.25, 1.12), (0.29, 1.17), (0.28, 1.22), (0.0, 1.23)], sides=14)
	chest.paint(collar, s["metal"], "MID", vary=0.06)
	HEADS[style](body.part("head"), 1.66, s)
	for side in ("l", "r"):
		up = body.part(f"upperarm.{side}")
		a, b = pts[f"upperarm.{side}"]
		up.paint(bp.limb(up, a, b, 0.06, 0.05, sides=10), s["bone"], "MID")
		pad = up.rounded_box(a.x - 0.15, a.x + 0.15, a.y - 0.15, a.y + 0.15, a.z - 0.08, a.z + 0.14, radius=0.08, segments=3)
		up.paint(pad, s["body"], "LOW", vary=0.06)
		low = body.part(f"lowerarm.{side}")
		a, b = pts[f"lowerarm.{side}"]
		low.paint(bp.limb(low, a, b, 0.05, 0.045, sides=10), s["bone"], "MID")
		low.paint(bp.limb(low, a + (b - a) * 0.4, a + (b - a) * 0.9, 0.08, 0.075, sides=10), s["wrap"], "LOW", vary=0.08)
		low.paint(bp.limb(low, a + (b - a) * 0.62, a + (b - a) * 0.72, 0.085, 0.085, sides=10), s["accent"], "MID")
		wr = body.part(f"wrist.{side}")
		wr.paint(bp.limb(wr, *pts[f"wrist.{side}"], 0.045, 0.045, sides=10), s["bone"], "MID")
		hand = body.part(f"hand.{side}")
		h0, h1 = pts[f"hand.{side}"]
		hand.paint(hand.blob((h0 + h1) / 2, 0.09, squash=(1.2, 0.9, 1.0), subdiv=2, rough=0.06), s["bone"], "MID")
		ul = body.part(f"upperleg.{side}")
		ul.paint(bp.limb(ul, *pts[f"upperleg.{side}"], 0.07, 0.06, sides=10), s["bone"], "MID")
		ll = body.part(f"lowerleg.{side}")
		a, b = pts[f"lowerleg.{side}"]
		ll.paint(bp.limb(ll, a, b, 0.14, 0.12, sides=14), s["wrap"], "LOW", vary=0.08)
		ll.paint(bp.limb(ll, a - (b - a) * 0.05, a + (b - a) * 0.12, 0.16, 0.155, sides=14), s["accent"], "MID")
		foot = body.part(f"foot.{side}")
		f0, _ = pts[f"foot.{side}"]
		foot.paint(foot.rounded_box(f0.x - 0.12, f0.x + 0.12, f0.y - 0.22, f0.y + 0.09, 0.0, 0.15, radius=0.07, segments=3), s["boot"], "LOW")
	body.build(smooth=55)
	bp.save(f"guerrero_{style}")


if __name__ == "__main__":
	only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(STYLES)
	for style in only:
		guerrero(style)
