# Prueba (no la usa el juego): el jugador de build_personajes.py llevado al estilo de Link's Awakening, el mismo diseño
# (casco rojo con aletas, traje oscuro, neón, chakana) como figura de juguete: cabeza un poco más grande, ojos ovalados,
# las mismas cajas pero con cantos muy redondeados, manos redondas y sombreado suave.
# Publica assets/epiphany/personaje_jugador_la.glb.
# blender -b -P tools/blender/build_jugador_la.py
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402
from build_personajes import ARMOR, NEON, SUIT, TRIM, Body, bone_points, limb, side_plane, start, trenza, trenza_bones  # noqa: E402

HZ = 1.72
SIDES = 16
SMOOTH = 50
## La cabeza crece desde el cuello: más grande que la del juego, sin llegar a chibi.
HEAD_SCALE = 1.08
NECK = Vector((0, 0, HZ - 0.42))
## Ancho del cuerpo de adelante a atrás respecto del de lado a lado (los barriles no son redondos).
DEPTH = 0.8


def soft(p, x0, x1, y0, y1, z0, z1, radius=0.06):
	return p.rounded_box(x0, x1, y0, y1, z0, z1, radius=radius, segments=3)


def barrel(p, profile, center=(0.0, 0.0)):
	faces = p.lathe(profile, sides=SIDES, center=center)
	for v in {v for f in faces for v in f.verts}:
		v.co.y = center[1] + (v.co.y - center[1]) * DEPTH
	return faces


def ball(p, center, radius, squash=(1.0, 1.0, 1.0)):
	return p.blob(center, radius, squash=squash, subdiv=3, rough=0.0)


def head(p, hz):
	p.paint(soft(p, -0.38, 0.38, -0.37, 0.34, hz - 0.42, hz + 0.3, radius=0.16), "piel", "MID")
	for x in (-0.15, 0.15):
		p.paint(ball(p, (x, -0.37, hz - 0.08), 0.075, squash=(0.8, 0.35, 1.15)), SUIT, "MID")
		p.paint(ball(p, (x + 0.02, -0.395, hz - 0.045), 0.026, squash=(1.0, 0.4, 1.0)), NEON, "LIGHT")
	p.paint(soft(p, -0.12, 0.12, -0.385, -0.355, hz - 0.31, hz - 0.27, radius=0.012), "piel", "DARK")
	p.paint(soft(p, -0.44, 0.44, -0.3, 0.42, hz - 0.05, hz + 0.44, radius=0.15), ARMOR, z_range=(hz - 0.3, hz + 0.6))
	p.paint(soft(p, -0.43, 0.43, -0.42, -0.26, hz + 0.06, hz + 0.34, radius=0.07), ARMOR, "MID")
	for side in (-1, 1):
		p.paint(soft(p, side * 0.4 - 0.06, side * 0.4 + 0.06, -0.32, 0.3, hz - 0.36, hz + 0.1, radius=0.05), ARMOR, "LOW")
		disc = p.cylinder(0.12, 0.0, 0.05, sides=SIDES)
		p.transform(disc, Matrix.Translation((side * 0.47, 0.0, hz - 0.12)) @ Matrix.Rotation(side * 1.5708, 4, "Y"))
		p.paint(disc, "cobre_verde", "MID")
		p.paint(ball(p, (side * 0.52, 0.0, hz - 0.12), 0.055, squash=(0.6, 1.0, 1.0)), NEON, "MID")
		fin = side_plane(p, [(-0.28, 0.0), (0.1, 0.0), (0.3, 0.06), (0.5, 0.16), (0.72, 0.3), (0.42, 0.32), (0.0, 0.26), (-0.18, 0.16)], side * 0.36, 0.09)
		p.transform(fin, Matrix.Translation((0, 0, hz + 0.26)) @ Matrix.Rotation(-side * 0.22, 4, "Y"))
		p.paint(fin, ARMOR, z_range=(hz + 0.2, hz + 1.0))
	epi.chakana_plate(p, Vector((0, -0.45, hz + 0.2)), 0.26, TRIM)
	p.paint(ball(p, (0, -0.47, hz + 0.2), 0.065, squash=(1.0, 0.5, 1.2)), NEON, "LIGHT")
	p.transform(list(p.bm.faces), Matrix.Translation(NECK) @ Matrix.Scale(HEAD_SCALE, 4) @ Matrix.Translation(-NECK))


def jugador_la():
	rig = start()
	bp = bone_points(rig)
	trenza_bones(rig, HZ)
	body = Body(rig, "jugador", 10)
	hips = body.part("hips")
	hips.paint(soft(hips, -0.24, 0.24, -0.17, 0.17, 0.4, 0.66, radius=0.09), SUIT, "MID", vary=0.03)
	hips.paint(soft(hips, -0.265, 0.265, -0.195, 0.195, 0.58, 0.66, radius=0.035), TRIM, "MID")
	for y0, y1 in ((-0.24, -0.17), (0.17, 0.24)):
		hips.paint_bands(soft(hips, -0.16, 0.16, y0, y1, 0.3, 0.6, radius=0.03), [(0.36, 0.39, NEON, "MID")], default=(0, 0, ARMOR, "MID"))
	torso = body.part("chest")
	torso.paint(soft(torso, -0.22, 0.22, -0.16, 0.16, 0.62, 1.2, radius=0.1), SUIT, "MID")
	torso.paint(soft(torso, -0.26, 0.26, -0.22, 0.12, 0.84, 1.2, radius=0.1), ARMOR, "MID")
	torso.paint(soft(torso, -0.255, 0.255, -0.225, 0.115, 0.88, 0.91, radius=0.012), NEON, "MID")
	epi.chakana_plate(torso, Vector((0, -0.23, 1.07)), 0.16, TRIM)
	torso.paint(barrel(torso, [(0.18, 1.18), (0.22, 1.21), (0.2, 1.26), (0.0, 1.27)]), TRIM, "MID")
	head(body.part("head"), HZ)
	for side in ("l", "r"):
		up = body.part(f"upperarm.{side}")
		a, b = bp[f"upperarm.{side}"]
		up.paint(limb(up, a, b, 0.095, 0.085, sides=SIDES), SUIT, "MID")
		up.paint(soft(up, a.x - 0.17, a.x + 0.17, a.y - 0.17, a.y + 0.17, a.z - 0.1, a.z + 0.16, radius=0.09), ARMOR, "MID")
		low = body.part(f"lowerarm.{side}")
		a, b = bp[f"lowerarm.{side}"]
		low.paint(limb(low, a, b, 0.105, 0.135, sides=SIDES), ARMOR, "MID", vary=0.03)
		low.paint(limb(low, a + (b - a) * 0.74, a + (b - a) * 0.86, 0.14, 0.14, sides=SIDES), NEON, "MID")
		wr = body.part(f"wrist.{side}")
		wr.paint(limb(wr, *bp[f"wrist.{side}"], 0.08, 0.08, sides=SIDES), SUIT, "MID")
		hand = body.part(f"hand.{side}")
		h0, h1 = bp[f"hand.{side}"]
		hand.paint(ball(hand, (h0 + h1) / 2, 0.12, squash=(1.1, 0.95, 1.0)), SUIT, "MID")
		ul = body.part(f"upperleg.{side}")
		ul.paint(limb(ul, *bp[f"upperleg.{side}"], 0.12, 0.105, sides=SIDES), SUIT, "MID", vary=0.03)
		ll = body.part(f"lowerleg.{side}")
		a, b = bp[f"lowerleg.{side}"]
		ll.paint(limb(ll, a, b, 0.16, 0.13, sides=SIDES), ARMOR, "MID", vary=0.03)
		ll.paint(limb(ll, a - (b - a) * 0.04, a + (b - a) * 0.1, 0.175, 0.175, sides=SIDES), TRIM, "MID")
		foot = body.part(f"foot.{side}")
		f0, _ = bp[f"foot.{side}"]
		foot.paint(soft(foot, f0.x - 0.135, f0.x + 0.135, f0.y - 0.25, f0.y + 0.1, 0.0, 0.17, radius=0.075), ARMOR, "LOW")
		foot.paint(soft(foot, f0.x - 0.14, f0.x + 0.14, f0.y - 0.255, f0.y + 0.105, 0.0, 0.04, radius=0.018), NEON, "MID")
	body.build(smooth=SMOOTH)
	braid = Body(rig, "trenza", 40)
	trenza(braid, HZ)
	braid.build(smooth=SMOOTH)
	epi.publish("personaje_jugador_la", objects=bpy.context.scene.objects)


jugador_la()
