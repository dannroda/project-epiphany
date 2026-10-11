# Herramientas de los personajes en estilo toon tipo Wind Waker (12.12): cuerpo continuo (skin modifier) con pesos
# automáticos, cabeza con la cara de calcomanías proyectadas, mechones de curvas, cadenas de huesos spring y el armado
# final: cada parte se arma con un material etiqueta y al terminar todo se une en una malla pintada con UVs de la paleta
# (PALETA) y se publica con epi.publish. Lo usa build_shinobi.py.
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_personajes as P  # noqa: E402
import epi  # noqa: E402

C = Vector((0.0, -0.02, 1.66))
R = Vector((0.36, 0.33, 0.34))
CH = C + Vector((0, 0.04, 0.03))
RH = Vector((0.39, 0.38, 0.38))

# etiqueta → (tira de la paleta, posición en su degradé: 0 oscuro, 1 claro)
PALETA = {
	"piel": ("piel", 0.85),
	"pelo": ("ladrillo", 0.0),
	"tela": ("gris_4", 0.25),
	"roja": ("tela_roja", 0.6),
	"crema": ("hueso", 0.85),
	"bota": ("madera_oscura", 0.35),
	"blanco": ("blanco", 1.0),
	"negro": ("noche", 0.0),
	"iris": ("tela_roja", 0.75),
	"rubor": ("flor_rosa", 0.9),
	"hierro": ("hierro", 0.85),
	"dorado": ("dorado", 0.5),
	"glow": ("doom", 0.75),
}


def mat(key):
	return bpy.data.materials.get(key) or bpy.data.materials.new(key)


def palette_uv(swatch, t):
	pal = epi.palette
	i = epi.NAMES.index(swatch)
	col, row = i % pal.COLS, i // pal.COLS
	lo = (pal.ROWS - 1 - row + pal.MARGIN) / pal.ROWS
	hi = (pal.ROWS - row - pal.MARGIN) / pal.ROWS
	return ((col + 0.5) / pal.COLS, lo + (hi - lo) * t)


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


def curve_obj(name, chains, bevel, material, flat=0.0, resolution=3, ring=1):
	"""chains: [[(punto, radio)]]; tubos NURBS que se afinan según el radio de cada punto."""
	cu = bpy.data.curves.new(name, "CURVE")
	cu.dimensions = "3D"
	cu.resolution_u = resolution
	if flat:
		cu.extrude = flat
	else:
		cu.bevel_depth = bevel
		cu.bevel_resolution = ring
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


def skin_mesh(name, nodes, edges, root, subsurf=2):
	"""Malla continua por skin modifier: nodes {nombre: (posición, radio x, radio y)}, edges [(a, b)]."""
	names = list(nodes)
	mesh = bpy.data.meshes.new(name)
	mesh.from_pydata([nodes[n][0] for n in names], [(names.index(a), names.index(b)) for a, b in edges], [])
	ob = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(ob)
	sk = ob.modifiers.new("Skin", "SKIN")
	sk.use_smooth_shade = True
	for i, n in enumerate(names):
		d = ob.data.skin_vertices[0].data[i]
		d.radius = (nodes[n][1], nodes[n][2])
		d.use_root = n == root
	bpy.context.view_layer.objects.active = ob
	bpy.ops.object.modifier_apply(modifier=sk.name)
	if subsurf:
		apply_mod(ob, "SUBSURF", levels=subsurf)
	for p in ob.data.polygons:
		p.use_smooth = True
	return ob


def paint_by(ob, keys, pick):
	"""Material etiqueta por cara: pick(centro) devuelve el índice en keys."""
	for k in keys:
		ob.data.materials.append(mat(k))
	for p in ob.data.polygons:
		p.material_index = pick(p.center)


# --- rig ---

def rigid(ob, rig, bone):
	ob.parent = rig
	ob.matrix_parent_inverse = rig.matrix_world.inverted()
	g = ob.vertex_groups.new(name=bone)
	g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
	ob.modifiers.new("Armature", "ARMATURE").object = rig


def auto_weights(rig, objects):
	bpy.ops.object.select_all(action="DESELECT")
	for ob in objects:
		ob.select_set(True)
	rig.select_set(True)
	bpy.context.view_layer.objects.active = rig
	bpy.ops.object.parent_set(type="ARMATURE_AUTO")


def add_chain(rig, bones, parent, points, stiffness):
	"""Huesos de points[i] a points[i + 1] con los nombres de bones; el primero lleva la property spring."""
	bpy.context.view_layer.objects.active = rig
	bpy.ops.object.mode_set(mode="EDIT")
	to_rig = rig.matrix_world.inverted()
	prev = rig.data.edit_bones[parent]
	for name, a, b in zip(bones, points, points[1:]):
		bone = rig.data.edit_bones.new(name)
		bone.head, bone.tail = to_rig @ a, to_rig @ b
		bone.parent = prev
		prev = bone
	bpy.ops.object.mode_set(mode="OBJECT")
	rig.data.bones[bones[0]]["spring"] = stiffness


def chain_weights(ob, rig, bones, points):
	"""Cada vértice pesa según cuánto avanzó a lo largo de la cadena, mezclando dos huesos cerca de cada unión."""
	ob.parent = rig
	ob.matrix_parent_inverse = rig.matrix_world.inverted()
	groups = [ob.vertex_groups.new(name=b) for b in bones]
	start, end = points[0], points[-1]
	axis = end - start
	n = len(bones)
	for v in ob.data.vertices:
		u = max(0.0, min(1.0, (v.co - start).dot(axis) / axis.length_squared)) * n
		j = min(max(round(u), 1), n - 1) if n > 1 else 0
		if n > 1 and abs(u - j) < 0.3:
			w = (u - j + 0.3) / 0.6
			groups[j - 1].add([v.index], 1.0 - w, "REPLACE")
			groups[j].add([v.index], w, "REPLACE")
		else:
			groups[min(int(u), n - 1)].add([v.index], 1.0, "REPLACE")
	ob.modifiers.new("Armature", "ARMATURE").object = rig


# --- cuerpo y cabeza ---

def body(skin_at, cloth="tela"):
	"""Cuerpo continuo de la escala del Rig_Medium; skin_at(centro de cara) dice si la cara es piel o cloth."""
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
	ob = skin_mesh("cuerpo", nodes, edges, "hips")
	paint_by(ob, (cloth, "piel"), lambda c: 1 if skin_at(c) else 0)
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


def face(iris="iris", blush=True):
	parts = []
	for s in (1, -1):
		ex, ez = s * 0.135, -0.05
		parts.append(decal("ojo", oval(ex, ez, 0.08, 0.105), 0.003, "blanco"))
		parts.append(decal("iris", oval(ex - s * 0.012, ez - 0.012, 0.05, 0.078, flat_bottom=1.0), 0.006, iris))
		parts.append(decal("pupila", oval(ex - s * 0.012, ez - 0.01, 0.024, 0.044, flat_bottom=1.0), 0.008, "negro"))
		parts.append(decal("brillo", oval(ex, ez + 0.03, 0.016, 0.016, n=10, flat_bottom=1.0), 0.010, "blanco"))
		arc_o, arc_i = [], []
		for i in range(13):
			t = math.pi * i / 12
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
		if blush:
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

def sph(az, el, bulge=1.0):
	return CH + Vector((RH.x * bulge * math.cos(el) * math.sin(az), -RH.y * bulge * math.cos(el) * math.cos(az), RH.z * bulge * math.sin(el)))


def lock(az, el0, el1, r0, curl=1.0, n=7, az_drift=0.0):
	"""Mechón sobre el casco del pelo de (az, el0) a (az, el1) que se afina y termina en un rulo hacia afuera."""
	pts = []
	for i in range(n):
		t = i / (n - 1)
		p = sph(az + az_drift * t, el0 + (el1 - el0) * t, 1.0 + 0.12 * math.sin(math.pi * t))
		pts.append((p, r0 * (1 - 0.45 * t)))
	end = pts[-1][0]
	out = end - CH
	out.z = 0
	out.normalize()
	down = Vector((0, 0, -1))
	tip = r0 * 0.5
	for k, (o, d) in enumerate(((0.03, 0.05), (0.075, 0.035), (0.08, -0.005), (0.055, -0.02))):
		pts.append((end + out * o * curl + down * d * curl, tip * (1 - 0.22 * k)))
	return pts


# --- armado ---

def to_palette(ob):
	"""Cada cara toma el color de su material etiqueta como un punto de la paleta; después queda un solo material."""
	mesh = ob.data
	for uv in list(mesh.uv_layers):
		mesh.uv_layers.remove(uv)
	layer = mesh.uv_layers.new(name="paleta")
	names = [m.name for m in mesh.materials]
	for p in mesh.polygons:
		uv = palette_uv(*PALETA[names[p.material_index].split(".")[0]])
		for li in p.loop_indices:
			layer.data[li].uv = uv
		p.material_index = 0
	mesh.materials.clear()
	mesh.materials.append(epi.palette.palette_material())


def socket(rig, name, bone, kind):
	e = bpy.data.objects.new(name, None)
	bpy.context.scene.collection.objects.link(e)
	e["socket"] = kind
	e.parent, e.parent_type, e.parent_bone = rig, "BONE", bone
	bpy.context.view_layer.update()
	e.matrix_world = Matrix.Translation(rig.matrix_world @ rig.data.bones[bone].tail_local)
	return e


def assemble(name, rig, parts, sockets):
	"""Une las partes (ya pesadas al rig) en una malla, la pasa a la paleta y publica personaje_<name>.glb."""
	tris = {}
	for ob in parts:
		ob.data.calc_loop_triangles()
		key = ob.name.split(".")[0]
		tris[key] = tris.get(key, 0) + len(ob.data.loop_triangles)
	print("tris por parte:", sorted(tris.items(), key=lambda kv: -kv[1])[:10])
	bpy.ops.object.select_all(action="DESELECT")
	for ob in parts:
		ob.select_set(True)
	bpy.context.view_layer.objects.active = parts[0]
	bpy.ops.object.join()
	body_ob = parts[0]
	body_ob.name = body_ob.data.name = name
	for mod in list(body_ob.modifiers)[1:]:
		body_ob.modifiers.remove(mod)
	to_palette(body_ob)
	body_ob.data.calc_loop_triangles()
	print(name + ":", len(body_ob.data.vertices), "vértices,", len(body_ob.data.loop_triangles), "triángulos")
	epi.publish("personaje_" + name, [rig, body_ob] + sockets)


start_rig = P.start
