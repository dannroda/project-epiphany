# Jugador en estilo toon tipo Wind Waker (12.12), el mismo diseño inspirado en Zero de build_personajes.jugador:
# traje negro, casco rojo con aletas, gema de neón y discos en las orejas, trenza larga, peto con la chakana,
# hombreras, brazales, cinturón dorado con faldones y botas rojas con suela de neón. La trenza lleva huesos spring.
# Publica assets/epiphany/personaje_jugador_toon.glb (epi.publish).
# blender -b -P tools/blender/build_jugador_toon.py
import math
import os
import sys

import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from toon import (  # noqa: E402
	C, add_chain, assemble, auto_weights, body, chain_weights, chakana, curve_obj, disc, ellipsoid, face,
	front_plate, head, lathe, obj_from_bm, prism, rigid, skin_mesh, paint_by, socket, sph, start_rig,
)

HELMET_C = C + Vector((0, 0.01, 0.03))
HELMET_R = Vector((0.395, 0.37, 0.375))
TRENZA_BONES = ["trenza1", "trenza2", "trenza3"]


def trenza_point(t):
	return Vector((0.05 * math.sin(3 * t), 0.34 + 0.26 * math.sin(1.5 * t), 1.64 - 0.86 * t))


TRENZA_POINTS = [trenza_point(k / 3) for k in range(4)]


# --- cabeza ---

def _visor(c):
	rel = c - HELMET_C
	if rel.z < -0.3:
		return True
	return rel.y < 0.05 and rel.z < 0.12 and not (abs(rel.x) > 0.27 and rel.z > -0.24)


def helmet():
	parts = []
	bm = bmesh.new()
	ellipsoid(bm, HELMET_C, HELMET_R, segs=32)
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if _visor(f.calc_center_median())], context="FACES")
	parts.append(obj_from_bm("casco", bm, "armadura", solidify=0.03))
	front = HELMET_C.y - HELMET_R.y * math.sqrt(1 - (0.17 / HELMET_R.z) ** 2)
	z = HELMET_C.z + 0.17
	bm = bmesh.new()
	front_plate(bm, [(x, z + y) for x, y in chakana(0.26)], front - 0.02, 0.03)
	parts.append(obj_from_bm("casco_chakana", bm, "dorado", smooth=False))
	bm = bmesh.new()
	front_plate(bm, [(0, z + 0.06), (0.045, z), (0, z - 0.06), (-0.045, z)], front - 0.04, 0.03)
	parts.append(obj_from_bm("gema", bm, "neon", smooth=False))
	for s in (1, -1):
		center = Vector((s * (HELMET_R.x + 0.03), HELMET_C.y + 0.02, C.z - 0.1))
		bm = bmesh.new()
		disc(bm, center, (1, 0, 0), 0.12, 0.05)
		parts.append(obj_from_bm("oreja", bm, "cobre", smooth=False))
		bm = bmesh.new()
		disc(bm, center + Vector((s * 0.01, 0, 0)), (1, 0, 0), 0.055, 0.06, sides=8)
		parts.append(obj_from_bm("oreja_nucleo", bm, "neon", smooth=False))
		pts = [(-0.14, 0.0), (0.22, 0.0), (0.62, 0.2), (0.78, 0.38), (0.42, 0.25), (0.02, 0.17)]
		bm = bmesh.new()
		prism(bm, pts, 0.0, 0.04)
		bmesh.ops.transform(bm, matrix=Matrix.Translation((s * 0.33, HELMET_C.y, HELMET_C.z + 0.08)) @ Matrix.Rotation(-s * 0.12, 4, "Y"), verts=bm.verts)
		parts.append(obj_from_bm("aleta", bm, "armadura", smooth=False))
	return parts


def spike(az, el0, el1, r0, drift):
	pts = []
	for k in range(6):
		t = k / 5
		pts.append((sph(az + drift * t, el0 + (el1 - el0) * t, 1.0 + 0.1 * math.sin(math.pi * t)), r0 * (1 - t) + 0.08))
	return pts


def bangs():
	d = math.radians
	chains = [spike(d(az), d(26), d(-10 + abs(az) * 0.25), 1.0, d(az * 0.35)) for az in (-42, -21, 0, 21, 42)]
	return [curve_obj("flequillo", chains, 0.075, "pelo_azul", resolution=2)]


def trenza():
	parts = []
	bm = bmesh.new()
	for i in range(9):
		t = i / 8
		c = trenza_point(t) + Vector((0.025 * (1 if i % 2 else -1), 0, 0))
		r = 0.1 - 0.045 * t
		ellipsoid(bm, c, (r, r, r * 1.35), segs=12)
	parts.append(obj_from_bm("trenza", bm, "pelo_azul"))
	for t in (0.25, 0.7):
		bm = bmesh.new()
		c = trenza_point(t)
		disc(bm, c, trenza_point(t + 0.02) - c, 0.1 - 0.045 * t + 0.012, 0.035, sides=12)
		parts.append(obj_from_bm("trenza_anillo", bm, "neon", smooth=False))
	end = trenza_point(1.0)
	bm = bmesh.new()
	bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.07, radius2=0.025, depth=0.16, matrix=Matrix.Translation(end - Vector((0, 0, 0.12))))
	parts.append(obj_from_bm("borla", bm, "armadura"))
	bm = bmesh.new()
	ellipsoid(bm, end - Vector((0, 0, 0.03)), (0.045, 0.045, 0.045), segs=10)
	parts.append(obj_from_bm("cuenta", bm, "dorado"))
	return parts


# --- armadura ---

def armor():
	"""{nombre: (objeto, hueso)}"""
	out = {}
	torso = Matrix.Scale(0.82, 4, Vector((0, 1, 0)))
	bm = bmesh.new()
	lathe(bm, [(0.18, 0.8, 0.0), (0.2, 0.88, 0.0), (0.215, 0.98, 0.0), (0.205, 1.08, 0.0), (0.17, 1.16, 0.0), (0.12, 1.2, 0.0)], sides=24, matrix=torso)
	out["peto"] = (obj_from_bm("peto", bm, "armadura", solidify=0.025, subsurf=1), "chest")
	bm = bmesh.new()
	lathe(bm, [(0.212, 0.915, 0.0), (0.216, 0.955, 0.0)], sides=24, matrix=torso)
	out["peto_neon"] = (obj_from_bm("peto_neon", bm, "neon", solidify=0.02), "chest")
	bm = bmesh.new()
	front_plate(bm, [(x, 1.06 + z) for x, z in chakana(0.15)], -0.205 * 0.82 - 0.03, 0.025)
	out["peto_chakana"] = (obj_from_bm("peto_chakana", bm, "dorado", smooth=False), "chest")
	bm = bmesh.new()
	lathe(bm, [(0.1, 1.16, 0.0), (0.095, 1.25, 0.0)], sides=16)
	out["cuello"] = (obj_from_bm("cuello", bm, "dorado", solidify=0.02), "chest")
	bm = bmesh.new()
	lathe(bm, [(0.185, 0.6, 0.0), (0.175, 0.67, 0.0)], sides=24, matrix=torso)
	out["cinturon"] = (obj_from_bm("cinturon", bm, "dorado", solidify=0.025), "hips")
	for y in (-1, 1):
		flap = [(-0.14, 0.62), (0.14, 0.62), (0.1, 0.35), (-0.1, 0.35)]
		bm = bmesh.new()
		front_plate(bm, flap, y * 0.175, 0.025)
		out["faldon%+d" % y] = (obj_from_bm("faldon", bm, "armadura", smooth=False), "hips")
		bm = bmesh.new()
		front_plate(bm, [(-0.105, 0.4), (0.105, 0.4), (0.1, 0.37), (-0.1, 0.37)], y * 0.19, 0.01)
		out["faldon_neon%+d" % y] = (obj_from_bm("faldon_neon", bm, "neon", smooth=False), "hips")
	for s, side in ((1, "l"), (-1, "r")):
		bm = bmesh.new()
		ellipsoid(bm, (s * 0.25, 0, 1.13), (0.13, 0.13, 0.1), segs=20)
		bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z < 1.09], context="FACES")
		out["hombrera." + side] = (obj_from_bm("hombrera", bm, "armadura", solidify=0.02), "upperarm." + side)
		arm = Matrix.Translation((s * 0.48, 0, 1.11)) @ Matrix.Rotation(s * math.pi / 2, 4, "Y")
		bm = bmesh.new()
		lathe(bm, [(0.06, 0.0, 0.0), (0.072, 0.07, 0.0), (0.082, 0.19, 0.0), (0.08, 0.24, 0.0)], sides=16, matrix=arm)
		out["brazal." + side] = (obj_from_bm("brazal", bm, "armadura", solidify=0.015), "lowerarm." + side)
		bm = bmesh.new()
		lathe(bm, [(0.084, 0.16, 0.0), (0.086, 0.19, 0.0)], sides=16, matrix=arm)
		out["brazal_neon." + side] = (obj_from_bm("brazal_neon", bm, "neon", solidify=0.012), "lowerarm." + side)
		leg = Matrix.Translation((s * 0.165, 0.005, 0))
		bm = bmesh.new()
		lathe(bm, [(0.068, 0.13, 0.0), (0.078, 0.2, 0.0), (0.09, 0.29, 0.0), (0.095, 0.32, 0.0)], sides=16, matrix=leg)
		out["canillera." + side] = (obj_from_bm("canillera", bm, "armadura", solidify=0.015), "lowerleg." + side)
		bm = bmesh.new()
		lathe(bm, [(0.1, 0.3, 0.0), (0.1, 0.34, 0.0)], sides=16, matrix=leg)
		out["canillera_aro." + side] = (obj_from_bm("canillera_aro", bm, "dorado", solidify=0.015), "lowerleg." + side)
		out["bota." + side] = (boot(s), "foot." + side)
	return out


def boot(s):
	ob = skin_mesh("bota", {
		"tobillo": ((s * 0.17, 0.02, 0.16), 0.075, 0.075),
		"talon": ((s * 0.17, -0.03, 0.08), 0.078, 0.078),
		"punta": ((s * 0.17, -0.17, 0.06), 0.068, 0.068),
	}, [("tobillo", "talon"), ("talon", "punta")], "tobillo")
	for v in ob.data.vertices:
		v.co.z = max(v.co.z, 0.0)
	paint_by(ob, ("armadura", "neon"), lambda c: 1 if c.z < 0.02 else 0)
	return ob


rig = start_rig()
add_chain(rig, TRENZA_BONES, "head", TRENZA_POINTS, 0.4)
cuerpo = body(lambda c: False, cloth="traje")
auto_weights(rig, [cuerpo])
parts = [cuerpo]
for ob in [head()] + face(iris="iris_azul") + helmet() + bangs():
	rigid(ob, rig, "head")
	parts.append(ob)
for ob in trenza():
	chain_weights(ob, rig, TRENZA_BONES, TRENZA_POINTS)
	parts.append(ob)
for ob, bone in armor().values():
	rigid(ob, rig, bone)
	parts.append(ob)
assemble("jugador_toon", rig, parts, [socket(rig, "SableSocket", "hand.r", "sable"), socket(rig, "PistolaSocket", "hand.l", "pistola")])
