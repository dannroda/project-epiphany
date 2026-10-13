# Prueba (no la usa el juego): el jugador de build_personajes.py llevado al estilo de Link's Awakening, el mismo diseño
# (casco rojo con aletas, traje oscuro, neón, chakana) como figura de juguete: cabeza un poco más grande, ojos grandes
# ovalados, torso y piernas como barriles blandos, hombreras y manos redondas, botas infladas, todo liso y sin placas.
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
HEAD_SCALE = 1.15
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
	p.paint(ball(p, (0, -0.02, hz - 0.08), 0.4, squash=(1.0, 0.92, 0.95)), "piel", "MID")
	for x in (-0.15, 0.15):
		p.paint(ball(p, (x, -0.375, hz - 0.08), 0.085, squash=(0.8, 0.35, 1.15)), SUIT, "MID")
		p.paint(ball(p, (x + 0.025, -0.405, hz - 0.04), 0.03, squash=(1.0, 0.4, 1.0)), NEON, "LIGHT")
	p.paint(ball(p, (0, -0.37, hz - 0.29), 0.06, squash=(1.0, 0.3, 0.35)), "piel", "DARK")
	helmet = ball(p, (0, 0.04, hz + 0.08), 0.47, squash=(1.0, 1.0, 0.9))
	for v in {v for f in helmet for v in f.verts}:
		v.co.z = max(v.co.z, hz - 0.06)
	p.paint(helmet, ARMOR, z_range=(hz - 0.2, hz + 0.6))
	p.paint(barrel(p, [(0.0, hz + 0.05), (0.46, hz + 0.06), (0.49, hz + 0.12), (0.47, hz + 0.18), (0.0, hz + 0.19)], center=(0, 0.0)), ARMOR, "DARK")
	for side in (-1, 1):
		p.paint(ball(p, (side * 0.41, 0.0, hz - 0.16), 0.13, squash=(0.6, 1.3, 1.5)), ARMOR, "LOW")
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
	hips.paint(barrel(hips, [(0.0, 0.38), (0.2, 0.39), (0.25, 0.5), (0.24, 0.66), (0.0, 0.67)]), SUIT, "MID", vary=0.03)
	hips.paint(barrel(hips, [(0.25, 0.57), (0.28, 0.6), (0.28, 0.65), (0.25, 0.68)]), TRIM, "MID")
	for y0, y1 in ((-0.24, -0.17), (0.17, 0.24)):
		hips.paint_bands(soft(hips, -0.16, 0.16, y0, y1, 0.3, 0.6, radius=0.03), [(0.36, 0.39, NEON, "MID")], default=(0, 0, ARMOR, "MID"))
	torso = body.part("chest")
	torso.paint(barrel(torso, [(0.0, 0.62), (0.22, 0.64), (0.26, 0.82), (0.25, 1.05), (0.19, 1.2), (0.0, 1.24)]), SUIT, "MID")
	plate = barrel(torso, [(0.0, 0.84), (0.25, 0.85), (0.29, 0.98), (0.27, 1.13), (0.2, 1.21), (0.0, 1.22)], center=(0, -0.03))
	torso.paint(plate, ARMOR, "MID")
	torso.paint(barrel(torso, [(0.255, 0.865), (0.268, 0.88), (0.262, 0.895), (0.25, 0.9)], center=(0, -0.03)), NEON, "MID")
	epi.chakana_plate(torso, Vector((0, -0.25, 1.05)), 0.16, TRIM)
	torso.paint(barrel(torso, [(0.18, 1.18), (0.22, 1.21), (0.2, 1.26), (0.0, 1.27)]), TRIM, "MID")
	head(body.part("head"), HZ)
	for side in ("l", "r"):
		up = body.part(f"upperarm.{side}")
		a, b = bp[f"upperarm.{side}"]
		up.paint(limb(up, a, b, 0.095, 0.085, sides=SIDES), SUIT, "MID")
		up.paint(ball(up, (a.x, a.y, a.z + 0.03), 0.18, squash=(1.0, 1.0, 0.9)), ARMOR, "MID")
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
		foot.paint(ball(foot, (f0.x, f0.y - 0.06, 0.09), 0.16, squash=(0.9, 1.15, 0.62)), ARMOR, "LOW")
		sole = barrel(foot, [(0.0, 0.0), (0.15, 0.0), (0.155, 0.025), (0.0, 0.03)], center=(f0.x, f0.y - 0.06))
		foot.transform(sole, Matrix.Translation((f0.x, f0.y - 0.06, 0)) @ Matrix.Scale(1.0, 4) @ Matrix.Diagonal((0.9, 1.15 / DEPTH, 1.0, 1.0)) @ Matrix.Translation((-f0.x, -(f0.y - 0.06), 0)))
		foot.paint(sole, NEON, "MID")
	body.build(smooth=SMOOTH)
	braid = Body(rig, "trenza", 40)
	trenza(braid, HZ)
	braid.build(smooth=SMOOTH)
	epi.publish("personaje_jugador_la", objects=bpy.context.scene.objects)


jugador_la()
