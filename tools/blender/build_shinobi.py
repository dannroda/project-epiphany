# Prueba de estilo tipo Wind Waker HD (12.12): cuerpo continuo (skin modifier), pelo en mechones de curvas, cara pintada
# proyectada y cel shading de dos tonos, posado con Idle_A. Renderiza 5 vistas y guarda estilo.blend en <carpeta>.
# blender -b -P tools/blender/estilo_toon.py -- <carpeta>
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = sys.argv[-1]
RIG_SRC = os.path.join(ROOT, "assets", "kaykit_charanim", "Animations", "gltf", "Rig_Medium", "Rig_Medium_%s.glb")

C = Vector((0.0, -0.02, 1.66))
R = Vector((0.36, 0.33, 0.34))


def hexc(h, mult=1.0):
	h = h.lstrip("#")
	c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
	return [((x * mult) ** 2.2) for x in c] + [1.0]


MATS = {}


def toon(name, lit, shade, glow=0.0):
	if name in MATS:
		return MATS[name]
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	t = m.node_tree
	t.nodes.clear()
	out = t.nodes.new("ShaderNodeOutputMaterial")
	if glow:
		em = t.nodes.new("ShaderNodeEmission")
		em.inputs["Color"].default_value = hexc(lit)
		em.inputs["Strength"].default_value = glow
		t.links.new(em.outputs[0], out.inputs[0])
	else:
		dif = t.nodes.new("ShaderNodeBsdfDiffuse")
		s2 = t.nodes.new("ShaderNodeShaderToRGB")
		ramp = t.nodes.new("ShaderNodeValToRGB")
		ramp.color_ramp.interpolation = "CONSTANT"
		ramp.color_ramp.elements[0].color = hexc(shade)
		ramp.color_ramp.elements[1].position = 0.12
		ramp.color_ramp.elements[1].color = hexc(lit)
		em = t.nodes.new("ShaderNodeEmission")
		t.links.new(dif.outputs[0], s2.inputs[0])
		t.links.new(s2.outputs["Color"], ramp.inputs[0])
		t.links.new(ramp.outputs[0], em.inputs["Color"])
		t.links.new(em.outputs[0], out.inputs[0])
	MATS[name] = m
	return m


def mat(key):
	table = {
		"piel": ("f6d2b0", "d89a7c"),
		"pelo": ("444a66", "1c1e2c"),
		"tela": ("3c3f52", "1a1b25"),
		"roja": ("d8483a", "8e2430"),
		"crema": ("f2ead6", "c4b49e"),
		"bota": ("5a4038", "2c1e1c"),
		"blanco": ("ffffff", "e8e8f0"),
		"negro": ("101018", "101018"),
		"iris": ("e0403a", "a02028"),
		"rubor": ("f4a0a0", "e08888"),
		"hierro": ("a8b0bc", "5a6070"),
		"dorado": ("f5d67e", "b88a3c"),
	}
	if key == "glow":
		return toon("glow", "ff5a48", "ff5a48", glow=4.0)
	return toon(key, *table[key])


# --- utilidades de malla ---

def obj_from_bm(name, bm, material, smooth=True, subsurf=0, solidify=0.0):
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	mesh.materials.append(mat(material))
	ob = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(ob)
	for p in mesh.polygons:
		p.use_smooth = smooth
	if solidify:
		apply_mod(ob, "SOLIDIFY", thickness=solidify, offset=0.0)
	if subsurf:
		apply_mod(ob, "SUBSURF", levels=subsurf)
	return ob


def apply_mod(ob, kind, **props):
	mod = ob.modifiers.new(kind, kind)
	for k, v in props.items():
		setattr(mod, k, v)
	bpy.context.view_layer.objects.active = ob
	bpy.ops.object.modifier_apply(modifier=mod.name)


def lathe(bm, profile, sides=32, folds=0, matrix=Matrix(), phase=0.0):
	"""profile: [(radio, z, amplitud de pliegue)]; tubo abierto con pliegues senoidales."""
	rings = []
	for r, z, amp in profile:
		ring = []
		for i in range(sides):
			a = 2 * math.pi * i / sides
			rr = r * (1 + amp * math.sin(folds * a + phase))
			ring.append(bm.verts.new(matrix @ Vector((rr * math.cos(a), rr * math.sin(a), z))))
		rings.append(ring)
	for ra, rb in zip(rings, rings[1:]):
		for i in range(sides):
			bm.faces.new((ra[i], ra[(i + 1) % sides], rb[(i + 1) % sides], rb[i]))
	return rings


def ellipsoid(bm, center, radii, segs=24):
	res = bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=segs // 2, radius=1.0)
	for v in res["verts"]:
		v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2])) + Vector(center)
	return res["verts"]


def curve_obj(name, chains, bevel, material, flat=0.0):
	"""chains: [[(punto, radio)]]; tubos NURBS que se afinan según el radio de cada punto."""
	cu = bpy.data.curves.new(name, "CURVE")
	cu.dimensions = "3D"
	cu.resolution_u = 8
	if flat:
		cu.extrude = flat
	else:
		cu.bevel_depth = bevel
		cu.bevel_resolution = 3
		cu.use_fill_caps = True
	for chain in chains:
		sp = cu.splines.new("NURBS")
		sp.points.add(len(chain) - 1)
		for p, (co, rad) in zip(sp.points, chain):
			p.co = (co.x, co.y, co.z, 1.0)
			p.radius = rad
		sp.use_endpoint_u = True
		sp.order_u = 4
	ob = bpy.data.objects.new(name + "_c", cu)
	bpy.context.scene.collection.objects.link(ob)
	bpy.context.view_layer.update()
	mesh = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
	bpy.data.objects.remove(ob)
	mesh.materials.clear()
	mesh.materials.append(mat(material))
	for p in mesh.polygons:
		p.use_smooth = True
	res = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(res)
	if flat:
		apply_mod(res, "SOLIDIFY", thickness=0.012, offset=0.0)
	return res


# --- rig ---

def load_rig():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=RIG_SRC % "General")
	rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
	for o in list(bpy.data.objects):
		if o is not rig and o.type != "ARMATURE":
			bpy.data.objects.remove(o)
	return rig


def rigid(ob, rig, bone):
	ob.parent = rig
	ob.matrix_parent_inverse = rig.matrix_world.inverted()
	g = ob.vertex_groups.new(name=bone)
	g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
	ob.modifiers.new("Armature", "ARMATURE").object = rig


# --- cuerpo ---

def body():
	"""Cuerpo continuo con skin modifier: nodos (posición, radio x, radio y)."""
	nodes = {
		"hips": ((0, 0, 0.56), 0.16, 0.13),
		"waist": ((0, 0, 0.76), 0.13, 0.11),
		"chest": ((0, 0, 1.0), 0.17, 0.13),
		"neck": ((0, 0, 1.22), 0.06, 0.06),
		"neck_top": ((0, 0, 1.36), 0.06, 0.06),
	}
	edges = [("hips", "waist"), ("waist", "chest"), ("chest", "neck"), ("neck", "neck_top")]
	for s, side in ((1, "l"), (-1, "r")):
		nodes.update({
			"sh" + side: ((s * 0.2, 0, 1.11), 0.075, 0.075),
			"el" + side: ((s * 0.45, 0, 1.11), 0.055, 0.055),
			"wr" + side: ((s * 0.72, 0, 1.11), 0.042, 0.042),
			"ha" + side: ((s * 0.8, 0, 1.11), 0.055, 0.035),
			"fi" + side: ((s * 0.9, 0, 1.1), 0.045, 0.03),
			"hp" + side: ((s * 0.11, 0, 0.5), 0.095, 0.095),
			"kn" + side: ((s * 0.16, -0.01, 0.29), 0.065, 0.065),
			"an" + side: ((s * 0.17, 0.02, 0.14), 0.055, 0.055),
		})
		edges += [("chest", "sh" + side), ("sh" + side, "el" + side), ("el" + side, "wr" + side), ("wr" + side, "ha" + side),
			("ha" + side, "fi" + side), ("hips", "hp" + side), ("hp" + side, "kn" + side), ("kn" + side, "an" + side)]
	names = list(nodes)
	mesh = bpy.data.meshes.new("cuerpo")
	mesh.from_pydata([nodes[n][0] for n in names], [(names.index(a), names.index(b)) for a, b in edges], [])
	ob = bpy.data.objects.new("cuerpo", mesh)
	bpy.context.scene.collection.objects.link(ob)
	sk = ob.modifiers.new("Skin", "SKIN")
	sk.use_smooth_shade = True
	for i, n in enumerate(names):
		d = ob.data.skin_vertices[0].data[i]
		d.radius = (nodes[n][1], nodes[n][2])
		d.use_root = n == "hips"
	bpy.context.view_layer.objects.active = ob
	bpy.ops.object.modifier_apply(modifier=sk.name)
	apply_mod(ob, "SUBSURF", levels=2)
	for m in ("tela", "piel"):
		ob.data.materials.append(mat(m))
	for p in ob.data.polygons:
		c = p.center
		skin = (c.z > 1.18) or (abs(c.x) > 0.2 and abs(c.x) < 0.42 and c.z > 1.0) or abs(c.x) > 0.74
		p.material_index = 1 if skin else 0
		p.use_smooth = True
	return ob


def head_point(x, z, off=0.0):
	u, w = x / R.x, z / R.z
	s = max(1 - u * u - w * w, 0.0)
	p = Vector((C.x + x, C.y - R.y * math.sqrt(s) - off, C.z + z))
	return chin(p)


def chin(p):
	rel = p - C
	if rel.z < 0 and rel.y < 0:
		a = (-rel.z / R.z) * (-rel.y / R.y)
		p = p + Vector((0, -0.02 * a, -0.05 * a))
	return p


def head():
	bm = bmesh.new()
	verts = ellipsoid(bm, C, R, segs=32)
	for v in verts:
		v.co = chin(v.co)
	return obj_from_bm("cabeza", bm, "piel")


def decal(name, pts2d, off, material):
	bm = bmesh.new()
	cx = sum(p[0] for p in pts2d) / len(pts2d)
	cz = sum(p[1] for p in pts2d) / len(pts2d)
	center = bm.verts.new(head_point(cx, cz, off))
	ring = [bm.verts.new(head_point(x, z, off)) for x, z in pts2d]
	for i in range(len(ring)):
		bm.faces.new((center, ring[i], ring[(i + 1) % len(ring)]))
	return obj_from_bm(name, bm, material)


def strip(name, outer, inner, off, material):
	bm = bmesh.new()
	a = [bm.verts.new(head_point(x, z, off)) for x, z in outer]
	b = [bm.verts.new(head_point(x, z, off)) for x, z in inner]
	for i in range(len(a) - 1):
		bm.faces.new((a[i], a[i + 1], b[i + 1], b[i]))
	return obj_from_bm(name, bm, material)


def oval(cx, cz, w, h, n=24, flat_bottom=0.8):
	pts = []
	for i in range(n):
		t = 2 * math.pi * i / n
		pts.append((cx + w * math.cos(t), cz + h * math.sin(t) * (1 if math.sin(t) > 0 else flat_bottom)))
	return pts


def face():
	parts = []
	for s in (1, -1):
		ex, ez = s * 0.135, -0.05
		parts.append(decal("ojo", oval(ex, ez, 0.08, 0.105), 0.003, "blanco"))
		parts.append(decal("iris", oval(ex - s * 0.012, ez - 0.012, 0.05, 0.078, flat_bottom=1.0), 0.006, "iris"))
		parts.append(decal("pupila", oval(ex - s * 0.012, ez - 0.01, 0.024, 0.044, flat_bottom=1.0), 0.008, "negro"))
		parts.append(decal("brillo", oval(ex - s * 0.0, ez + 0.03, 0.016, 0.016, n=10, flat_bottom=1.0), 0.010, "blanco"))
		arc_o, arc_i = [], []
		for i in range(13):
			t = math.pi * (0.0 + 1.0 * i / 12)
			wing = 0.02 if (s * math.cos(t)) > 0.6 else 0.0
			arc_o.append((ex + 0.094 * math.cos(t) + s * wing, ez + 0.122 * math.sin(t) + wing * 0.5))
			arc_i.append((ex + 0.08 * math.cos(t), ez + 0.1 * math.sin(t)))
		parts.append(strip("parpado", arc_o, arc_i, 0.009, "negro"))
		bo, bi = [], []
		for i in range(9):
			t = i / 8
			x = ex + s * (-0.06 + 0.13 * t)
			z = ez + 0.17 + 0.02 * math.sin(math.pi * t) - 0.02 * t
			bo.append((x, z + 0.016 * (1 - 0.6 * t)))
			bi.append((x, z - 0.012 * (1 - 0.6 * t)))
		parts.append(strip("ceja", bo, bi, 0.004, "negro"))
		parts.append(decal("rubor", oval(s * 0.2, -0.16, 0.045, 0.022, flat_bottom=1.0), 0.003, "rubor"))
	mo, mi = [], []
	for i in range(7):
		x = -0.035 + 0.07 * i / 6
		z = -0.205 - 0.008 * math.sin(math.pi * i / 6)
		mo.append((x, z + 0.006))
		mi.append((x, z - 0.006))
	parts.append(strip("boca", mo, mi, 0.004, "negro"))
	return parts


# --- pelo ---

CH = C + Vector((0, 0.04, 0.03))
RH = Vector((0.39, 0.38, 0.38))


def sph(az, el, bulge=1.0):
	return CH + Vector((RH.x * bulge * math.cos(el) * math.sin(az), -RH.y * bulge * math.cos(el) * math.cos(az), RH.z * bulge * math.sin(el)))


def lock(az, el0, el1, r0, curl=1.0, n=7, az_drift=0.0):
	pts = []
	for i in range(n):
		t = i / (n - 1)
		p = sph(az + az_drift * t, el0 + (el1 - el0) * t, 1.0 + 0.12 * math.sin(math.pi * t))
		pts.append((p, r0 * (1 - 0.45 * t)))
	end = pts[-1][0]
	out = (end - CH)
	out.z = 0
	out.normalize()
	down = Vector((0, 0, -1))
	tip = r0 * 0.5
	for k, (o, d) in enumerate(((0.03, 0.05), (0.075, 0.035), (0.08, -0.005), (0.055, -0.02))):
		pts.append((end + out * o * curl + down * d * curl, tip * (1 - 0.22 * k)))
	return pts


def hair():
	bm = bmesh.new()
	verts = ellipsoid(bm, CH, RH * 0.96, segs=32)
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if _cut(f.calc_center_median())], context="FACES")
	cap = obj_from_bm("pelo_casco", bm, "pelo")
	d = math.radians
	chains = []
	for az in range(40, 330, 22):
		chains.append([(p, r) for p, r in lock(d(az), d(35), d(-38 - 10 * math.sin(az)), 1.0)])
	for az in range(55, 310, 30):
		chains.append([(p, r) for p, r in lock(d(az + 11), d(5), d(-55), 0.9, curl=1.2)])
	for az in (-48, -32, -16, 0, 16, 32, 48):
		chains.append([(p, r) for p, r in lock(d(az), d(80), d(16 + abs(az) * 0.15), 0.85, curl=0.5, az_drift=d(az * 0.25))])
	locks = curve_obj("pelo_mechones", chains, 0.07, "pelo")
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
		bun_parts.append(curve_obj("rodete_espiral", [coil], 0.04, "pelo"))
		bun_parts += kunai(bc + Vector((-s * 0.12, -0.02, 0.06)), Vector((s * 1.0, 0.25, 0.55)))
		bun_parts += kunai(bc + Vector((-s * 0.1, 0.04, -0.02)), Vector((s * 1.0, 0.1, 0.25)))
		for side in (-1, 1):
			bow = bmesh.new()
			ellipsoid(bow, bc + Vector((side * 0.06, 0.12, -0.11)), (0.06, 0.025, 0.04), segs=12)
			bun_parts.append(obj_from_bm("lazo", bow, "roja"))
		tail = [(bc + Vector((0, 0.13, -0.12)) + Vector((s * 0.03 * k, 0.04 * k, -0.08 * k)), 1.0) for k in range(5)]
		bun_parts.append(curve_obj("cinta", [tail], 0.0, "roja", flat=0.03))
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
	return [handle, blade, curve_obj("kunai_aro", [ring], 0.006, "dorado")]


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
		tail = [(Vector((s * (0.04 + 0.03 * k), 0.19 + 0.025 * k, 0.7 - 0.09 * k)), 1.0) for k in range(5)]
		out["faja_cola." + side] = curve_obj("faja_cola", [tail], 0.0, "roja", flat=0.05)
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
	lathe(bm, [(0.2, 1.14, 0.05), (0.24, 1.2, 0.1), (0.22, 1.28, 0.1), (0.16, 1.32, 0.05)], sides=32, folds=7, matrix=Matrix.Translation((0, 0.05, 0)))
	out["capucha"] = obj_from_bm("capucha", bm, "tela", solidify=0.03, subsurf=1)
	for x in (-0.06, 0.06):
		cord = [(Vector((x, -0.17 + 0.0, 1.2 - 0.06 * k)) + Vector((0, -0.02 * k * 0.3, 0)), 1.0) for k in range(5)]
		out["cordon%+.2f" % x] = curve_obj("cordon", [cord], 0.008, "crema")
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


# --- escena ---

def setup_render():
	sc = bpy.context.scene
	sc.render.engine = "BLENDER_EEVEE"
	sc.render.resolution_x, sc.render.resolution_y = 640, 800
	sc.view_settings.view_transform = "Standard"
	world = bpy.data.worlds.new("w")
	world.use_nodes = True
	world.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.5, 0.62, 1)
	world.node_tree.nodes["Background"].inputs[1].default_value = 0.25
	sc.world = world
	sun = bpy.data.objects.new("sol", bpy.data.lights.new("sol", "SUN"))
	sun.data.energy = 3.0
	sun.rotation_euler = (math.radians(55), 0, math.radians(-30))
	sc.collection.objects.link(sun)
	cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
	cam.data.lens = 85
	sc.collection.objects.link(cam)
	sc.camera = cam
	return cam


def shoot(cam, name, az, target, dist):
	a = math.radians(az)
	cam.location = target + Vector((math.sin(a) * dist, -math.cos(a) * dist, dist * 0.18))
	cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
	bpy.context.scene.render.filepath = os.path.join(OUT, name + ".png")
	bpy.ops.render.render(write_still=True)


rig = load_rig()
rig.animation_data_create()
cuerpo = body()
bpy.ops.object.select_all(action="DESELECT")
cuerpo.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
for ob in [head()] + face() + hair():
	rigid(ob, rig, "head")
bones = {"pollera": "hips", "ruedo": "hips", "faja": "hips", "nudo": "hips", "delantal": "chest", "capucha": "chest"}
for key, ob in clothes().items():
	base = key.split(".")[0]
	side = key.split(".")[1] if "." in key else ""
	bone = bones.get(base) or {"manga": "lowerarm", "manga_borde": "lowerarm", "manga_sup": "upperarm", "liga": "upperleg", "bota": "foot", "faja_cola": "hips"}.get(base, "chest")
	rigid(ob, rig, bone + ("." + side if side and bone not in ("hips", "chest") else ""))
idle = bpy.data.actions["Idle_A"]
rig.animation_data.action = idle
rig.animation_data.action_slot = idle.slots[0]
bpy.context.scene.frame_set(int(idle.frame_range[0]) + 10)
cam = setup_render()
for name, az, tz, dist in (("frente", 0, 1.05, 7.0), ("tres_cuartos", 35, 1.05, 7.0), ("perfil", 90, 1.05, 7.0), ("espalda", 180, 1.05, 7.0), ("cara", 20, 1.62, 4.0)):
	shoot(cam, name, az, Vector((0, 0, tz)), dist)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "estilo.blend"))
