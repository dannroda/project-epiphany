# Personaje cyber-shinobi en estilo toon tipo Wind Waker (12.12): cuerpo continuo (skin modifier) con pesos automáticos,
# pelo en mechones de curvas, cara de calcomanías proyectadas, ropa con pliegues. Cada parte se arma con un material
# etiqueta y al final todo se une en una malla pintada con UVs de la paleta (PALETA) para el shader toon de Godot.
# Huesos spring para las cintas de los rodetes y las colas de la faja; sockets de sable y pistola en las manos.
# Publica assets/epiphany/personaje_shinobi.glb (epi.publish).
# blender -b -P tools/blender/build_shinobi.py
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from toon import (  # noqa: E402
	CH, RH, assemble, auto_weights, add_chain, body, chain_weights, curve_obj, ellipsoid, face, head, lathe, lock,
	mat, apply_mod, obj_from_bm, rigid, socket, start_rig,
)


def cinta_points(s):
	bc = CH + Vector((s * 0.27, 0.08, 0.31))
	return [bc + Vector((0, 0.13, -0.12)) + Vector((s * 0.03 * k, 0.04 * k, -0.08 * k)) for k in range(5)]


def faja_points(s):
	return [Vector((s * (0.04 + 0.03 * k), 0.19 + 0.025 * k, 0.7 - 0.09 * k)) for k in range(5)]


# cadena: (nombre, hueso padre, puntos según el lado, rigidez)
CHAINS = [("cinta", "head", cinta_points, 0.5), ("faja", "hips", faja_points, 0.6)]


def add_chains(rig):
	for name, parent, points, stiffness in CHAINS:
		for s, side in ((1, "l"), (-1, "r")):
			pts = points(s)
			add_chain(rig, [f"{name}1.{side}", f"{name}2.{side}"], parent, pts[::2], stiffness)


def chain_bones(name, side):
	return [f"{name}1.{side}", f"{name}2.{side}"]


def skin_at(c):
	return (c.z > 1.18) or (abs(c.x) > 0.2 and abs(c.x) < 0.42 and c.z > 1.0) or abs(c.x) > 0.74


# --- pelo ---

def hair():
	bm = bmesh.new()
	verts = ellipsoid(bm, CH, RH * 0.96, segs=32)
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if _cut(f.calc_center_median())], context="FACES")
	cap = obj_from_bm("pelo_casco", bm, "pelo")
	d = math.radians
	chains = []
	for az in range(40, 330, 29):
		chains.append([(p, r) for p, r in lock(d(az), d(35), d(-38 - 10 * math.sin(az)), 1.0)])
	for az in range(55, 310, 42):
		chains.append([(p, r) for p, r in lock(d(az + 11), d(5), d(-55), 0.9, curl=1.2)])
	for az in (-48, -32, -16, 0, 16, 32, 48):
		chains.append([(p, r) for p, r in lock(d(az), d(80), d(16 + abs(az) * 0.15), 0.85, curl=0.5, az_drift=d(az * 0.25))])
	locks = curve_obj("pelo_mechones", chains, 0.08, "pelo", resolution=2)
	bun_parts = []
	for s in (1, -1):
		bc = CH + Vector((s * 0.27, 0.08, 0.31))
		bm = bmesh.new()
		ellipsoid(bm, bc, (0.13, 0.13, 0.13), segs=20)
		bun_parts.append(obj_from_bm("rodete", bm, "pelo"))
		coil = []
		axis = Vector((s * 0.5, 0.2, 1.0)).normalized()
		q = axis.to_track_quat("Z", "Y")
		for k in range(26):
			t = k / 25
			h = -0.11 + 0.2 * t
			rr = math.sqrt(max(0.14 ** 2 - h * h, 0.0)) + 0.015
			a = 7.5 * math.pi * t
			coil.append((bc + q @ Vector((rr * math.cos(a), rr * math.sin(a), h)), 1.0 - 0.5 * t))
		bun_parts.append(curve_obj("rodete_espiral", [coil], 0.04, "pelo", resolution=2))
		bun_parts += kunai(bc + Vector((-s * 0.12, -0.02, 0.06)), Vector((s * 1.0, 0.25, 0.55)))
		bun_parts += kunai(bc + Vector((-s * 0.1, 0.04, -0.02)), Vector((s * 1.0, 0.1, 0.25)))
		for side in (-1, 1):
			bow = bmesh.new()
			ellipsoid(bow, bc + Vector((side * 0.06, 0.12, -0.11)), (0.06, 0.025, 0.04), segs=12)
			bun_parts.append(obj_from_bm("lazo", bow, "roja"))
		bun_parts.append(curve_obj("cinta." + ("l" if s > 0 else "r"), [[(p, 1.0) for p in cinta_points(s)]], 0.0, "roja", flat=0.03))
	return [cap, locks] + bun_parts


def _cut(c):
	rel = c - CH
	front_low = rel.y < -0.05 and rel.z < 0.16
	low = rel.z < -0.3
	return front_low or low


def kunai(base, direction):
	direction = direction.normalized()
	m = Matrix.Translation(base) @ direction.to_track_quat("Z", "Y").to_matrix().to_4x4()
	bm = bmesh.new()
	r = bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.014, radius2=0.014, depth=0.12, matrix=Matrix.Translation((0, 0, 0.06)))
	bmesh.ops.transform(bm, matrix=m, verts=r["verts"])
	handle = obj_from_bm("kunai_mango", bm, "roja")
	bm = bmesh.new()
	r = bmesh.ops.create_cone(bm, cap_ends=True, segments=4, radius1=0.04, radius2=0.0, depth=0.16, matrix=Matrix.Translation((0, 0, 0.2)))
	for v in r["verts"]:
		v.co.y *= 0.3
	bmesh.ops.transform(bm, matrix=m, verts=r["verts"])
	blade = obj_from_bm("kunai_hoja", bm, "hierro", smooth=False)
	ring = [(m @ Vector((0.025 * math.cos(a), 0.0, -0.02 + 0.025 * math.sin(a))), 1.0) for a in [2 * math.pi * k / 10 for k in range(11)]]
	return [handle, blade, curve_obj("kunai_aro", [ring], 0.006, "dorado", resolution=1, ring=0)]


# --- ropa ---

def clothes():
	out = {}
	bm = bmesh.new()
	lathe(bm, [(0.33, 0.42, 0.07), (0.3, 0.5, 0.06), (0.24, 0.62, 0.03), (0.19, 0.72, 0.0)], sides=48, folds=12)
	out["pollera"] = obj_from_bm("pollera", bm, "tela", solidify=0.015)
	bm = bmesh.new()
	lathe(bm, [(0.335, 0.415, 0.07), (0.33, 0.45, 0.07)], sides=48, folds=12)
	out["ruedo"] = obj_from_bm("ruedo", bm, "roja", solidify=0.02)
	bm = bmesh.new()
	rings = lathe(bm, [(0.205, 0.64, 0.0), (0.21, 0.71, 0.0), (0.2, 0.79, 0.0)], sides=32, matrix=Matrix.Scale(0.85, 4, Vector((0, 1, 0))))
	out["faja"] = obj_from_bm("faja", bm, "roja", solidify=0.02)
	bm = bmesh.new()
	ellipsoid(bm, (0, 0.17, 0.72), (0.07, 0.05, 0.06), segs=16)
	for s in (1, -1):
		ellipsoid(bm, (s * 0.1, 0.18, 0.74), (0.08, 0.035, 0.05), segs=16)
	out["nudo"] = obj_from_bm("nudo", bm, "roja")
	for s, side in ((1, "l"), (-1, "r")):
		out["faja_cola." + side] = curve_obj("faja_cola", [[(p, 1.0) for p in faja_points(s)]], 0.0, "roja", flat=0.05)
	bm = bmesh.new()
	grid = []
	for j in range(9):
		z = 0.5 + 0.62 * j / 8
		row = []
		for i in range(7):
			x = -0.15 + 0.3 * i / 6
			depth = 0.15 if z > 0.82 else (0.13 if z > 0.66 else 0.3 - (z - 0.42) * 0.5)
			row.append(bm.verts.new((x, -depth - 0.01 + 1.6 * x * x, z)))
		grid.append(row)
	for j in range(8):
		for i in range(6):
			bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
	out["delantal"] = obj_from_bm("delantal", bm, "crema", solidify=0.012, subsurf=1)
	bm = bmesh.new()
	lathe(bm, [(0.2, 1.14, 0.05), (0.24, 1.2, 0.1), (0.22, 1.28, 0.1), (0.16, 1.32, 0.05)], sides=21, folds=7, matrix=Matrix.Translation((0, 0.05, 0)))
	out["capucha"] = obj_from_bm("capucha", bm, "tela", solidify=0.03, subsurf=1)
	for x in (-0.06, 0.06):
		cord = [(Vector((x, -0.17 + 0.0, 1.2 - 0.06 * k)) + Vector((0, -0.02 * k * 0.3, 0)), 1.0) for k in range(5)]
		out["cordon%+.2f" % x] = curve_obj("cordon", [cord], 0.008, "crema", resolution=2, ring=0)
		bm = bmesh.new()
		ellipsoid(bm, (x, -0.18, 0.95), (0.016, 0.016, 0.025), segs=8)
		out["puntera%+.2f" % x] = obj_from_bm("cordon_punta", bm, "glow")
	for s, side in ((1, "l"), (-1, "r")):
		rot = Matrix.Rotation(s * math.pi / 2, 4, "Y")
		bm = bmesh.new()
		lathe(bm, [(0.075, 0.0, 0.0), (0.12, 0.12, 0.05), (0.17, 0.22, 0.08), (0.2, 0.3, 0.1)], sides=32, folds=6, matrix=Matrix.Translation((s * 0.44, 0, 1.11)) @ rot)
		out["manga." + side] = obj_from_bm("manga", bm, "tela", solidify=0.015)
		bm = bmesh.new()
		lathe(bm, [(0.205, 0.29, 0.1), (0.21, 0.32, 0.1)], sides=32, folds=6, matrix=Matrix.Translation((s * 0.44, 0, 1.11)) @ rot)
		out["manga_borde." + side] = obj_from_bm("manga_borde", bm, "glow", solidify=0.02)
		bm = bmesh.new()
		lathe(bm, [(0.085, 0.0, 0.0), (0.095, 0.08, 0.04), (0.09, 0.14, 0.04)], sides=24, folds=5, matrix=Matrix.Translation((s * 0.3, 0, 1.11)) @ rot)
		out["manga_sup." + side] = obj_from_bm("manga_sup", bm, "tela", solidify=0.012)
		bm = bmesh.new()
		lathe(bm, [(0.098, 0.34, 0.0), (0.1, 0.38, 0.0)], sides=24, matrix=Matrix.Translation((s * 0.15, 0, 0)))
		out["liga." + side] = obj_from_bm("liga", bm, "roja", solidify=0.015)
		out["bota." + side] = boot(s)
	return out


def boot(s):
	nodes = [((s * 0.17, 0.03, 0.24), 0.07), ((s * 0.17, 0.02, 0.12), 0.065), ((s * 0.17, -0.06, 0.06), 0.065), ((s * 0.17, -0.17, 0.05), 0.055)]
	mesh = bpy.data.meshes.new("bota")
	mesh.from_pydata([n[0] for n in nodes], [(i, i + 1) for i in range(len(nodes) - 1)], [])
	ob = bpy.data.objects.new("bota", mesh)
	bpy.context.scene.collection.objects.link(ob)
	sk = ob.modifiers.new("Skin", "SKIN")
	for i, n in enumerate(nodes):
		ob.data.skin_vertices[0].data[i].radius = (n[1], n[1])
		ob.data.skin_vertices[0].data[i].use_root = i == 0
	bpy.context.view_layer.objects.active = ob
	bpy.ops.object.modifier_apply(modifier=sk.name)
	apply_mod(ob, "SUBSURF", levels=2)
	for v in ob.data.vertices:
		v.co.z = max(v.co.z, 0.0)
	ob.data.materials.append(mat("bota"))
	ob.data.materials.append(mat("roja"))
	ob.data.materials.append(mat("glow"))
	for p in ob.data.polygons:
		p.use_smooth = True
		p.material_index = 1 if p.center.z > 0.24 else (2 if p.center.z < 0.02 else 0)
	return ob


rig = start_rig()
add_chains(rig)
cuerpo = body(skin_at)
auto_weights(rig, [cuerpo])
parts = [cuerpo]
for ob in [head()] + face() + hair():
	if ob.name.startswith("cinta."):
		side = ob.name.split(".")[1]
		chain_weights(ob, rig, chain_bones("cinta", side), cinta_points(1 if side == "l" else -1))
	else:
		rigid(ob, rig, "head")
	parts.append(ob)
bones = {"pollera": "hips", "ruedo": "hips", "faja": "hips", "nudo": "hips", "delantal": "chest", "capucha": "chest"}
for key, ob in clothes().items():
	base = key.split(".")[0]
	side = key.split(".")[1] if "." in key else ""
	if base == "faja_cola":
		chain_weights(ob, rig, chain_bones("faja", side), faja_points(1 if side == "l" else -1))
	else:
		bone = bones.get(base) or {"manga": "lowerarm", "manga_borde": "lowerarm", "manga_sup": "upperarm", "liga": "upperleg", "bota": "foot"}.get(base, "chest")
		rigid(ob, rig, bone + ("." + side if side and bone not in ("hips", "chest") else ""))
	parts.append(ob)
assemble("shinobi", rig, parts, [socket(rig, "SableSocket", "hand.r", "sable"), socket(rig, "PistolaSocket", "hand.l", "pistola")])
