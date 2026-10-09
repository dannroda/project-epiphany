# Arma assets/epiphany/personaje_<nombre>.blend: personajes low poly sobre el esqueleto Rig_Medium de KayKit (mismos nombres
# de huesos), así usan las animaciones de player/animation/libs/. Cada parte va pegada entera a un hueso (skinning rígido).
# blender -b -P tools/blender/build_personajes.py
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

RIG_SOURCE = os.path.join(epi.ROOT, "assets", "kaykit_adventure", "Characters", "gltf", "Knight.glb")


def start():
	"""Escena vacía con el material de la paleta y solo el armature de KayKit (sin las mallas del Knight)."""
	bpy.ops.wm.read_factory_settings(use_empty=True)
	epi.palette.palette_material()
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=RIG_SOURCE)
	rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
	for obj in set(bpy.data.objects) - before:
		if obj is not rig:
			bpy.data.objects.remove(obj)
	for col in list(bpy.data.collections):
		if col.name == "glTF_not_exported":
			bpy.data.collections.remove(col)
	for bone in rig.pose.bones:
		bone.custom_shape = None
	rig.name = "Rig_Medium"
	return rig


def bone_points(rig):
	return {b.name: (rig.matrix_world @ b.head_local, rig.matrix_world @ b.tail_local) for b in rig.data.bones}


def limb(p, a, b, r0, r1, sides=6):
	"""Cilindro de a a b."""
	a, b = Vector(a), Vector(b)
	d = b - a
	c = p.cylinder(r0, 0.0, d.length, sides=sides, radius_top=r1, phase=math.pi / sides)
	p.transform(c, Matrix.Translation(a) @ d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4())
	return c


class Body:
	"""Junta las partes por hueso y arma una sola malla con un grupo de vértices por hueso."""

	def __init__(self, rig, name, seed=0):
		self.rig = rig
		self.name = name
		self.parts = {}
		self.seed = seed

	def part(self, bone):
		if bone not in self.parts:
			self.parts[bone] = epi.Piece(self.seed + len(self.parts))
		return self.parts[bone]

	def build(self):
		col = bpy.context.scene.collection
		objs = []
		for bone, piece in self.parts.items():
			mesh = bpy.data.meshes.new(f"{self.name}_{bone}")
			piece.bm.to_mesh(mesh)
			piece.bm.free()
			mesh.materials.append(epi.palette.palette_material())
			obj = bpy.data.objects.new(mesh.name, mesh)
			col.objects.link(obj)
			group = obj.vertex_groups.new(name=bone)
			group.add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
			objs.append(obj)
		bpy.ops.object.select_all(action="DESELECT")
		for obj in objs:
			obj.select_set(True)
		bpy.context.view_layer.objects.active = objs[0]
		bpy.ops.object.join()
		body = bpy.context.object
		body.name = self.name
		body.data.name = self.name
		body.parent = self.rig
		mod = body.modifiers.new("Armature", "ARMATURE")
		mod.object = self.rig
		return body


def arms_and_legs(body, bp, sleeve, skin, pants, shoe, arm_r=0.085, leg_r=0.1, bony=False):
	for side in ("l", "r"):
		up = body.part(f"upperarm.{side}")
		up.paint(limb(up, *bp[f"upperarm.{side}"], arm_r * 1.15, arm_r), sleeve, "MID", vary=0.05)
		low = body.part(f"lowerarm.{side}")
		low.paint(limb(low, *bp[f"lowerarm.{side}"], arm_r, arm_r * 0.85), skin if bony else sleeve, "MID", vary=0.05)
		wr = body.part(f"wrist.{side}")
		wr.paint(limb(wr, *bp[f"wrist.{side}"], arm_r * 0.75, arm_r * 0.75), skin, "MID")
		hand = body.part(f"hand.{side}")
		h0, h1 = bp[f"hand.{side}"]
		hand.paint(hand.blob((h0 + h1) / 2, 0.1, squash=(1.2, 0.9, 1.0), subdiv=1, rough=0.1), skin, "MID")
		ul = body.part(f"upperleg.{side}")
		ul.paint(limb(ul, *bp[f"upperleg.{side}"], leg_r * 1.1, leg_r), pants, "MID", vary=0.05)
		ll = body.part(f"lowerleg.{side}")
		ll.paint(limb(ll, *bp[f"lowerleg.{side}"], leg_r, leg_r * 0.9), skin if bony else pants, "LOW", vary=0.05)
		foot = body.part(f"foot.{side}")
		f0, _ = bp[f"foot.{side}"]
		foot.paint(foot.box(f0.x - 0.1, f0.x + 0.1, f0.y - 0.2, f0.y + 0.08, 0.0, 0.12, taper=0.02), shoe, "MID")


def save(name):
	path = os.path.join(epi.ROOT, "assets", "epiphany", f"personaje_{name}.blend")
	bpy.ops.wm.save_as_mainfile(filepath=path)
	bpy.ops.file.make_paths_relative()
	bpy.ops.wm.save_mainfile()
	if os.path.exists(path + "1"):
		os.remove(path + "1")
	print("guardado:", path)


# --- jugador ---

ARMOR = "tela_roja"
SUIT = "noche"
TRIM = "dorado"
NEON = "neon"


def side_plane(p, points, x, thickness):
	"""Prisma de una planta (y, z) con espesor en X, centrado en x."""
	f = p.polygon(points, -thickness / 2, thickness / 2)
	p.transform(f, Matrix.Translation((x, 0, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "X"))
	return f


def jugador_head(head, hz):
	head.paint(head.rounded_box(-0.38, 0.38, -0.36, 0.34, hz - 0.42, hz + 0.3, radius=0.14), "piel", "MID")
	for x in (-0.15, 0.15):
		head.paint(head.box(x - 0.055, x + 0.055, -0.38, -0.35, hz - 0.14, hz + 0.02), SUIT, "MID")
		head.paint(head.box(x - 0.02, x + 0.02, -0.385, -0.37, hz - 0.06, hz), NEON, "MID")
	head.paint(head.box(-0.16, 0.16, -0.38, -0.36, hz - 0.3, hz - 0.28), "piel", "DARK")
	shell = head.rounded_box(-0.44, 0.44, -0.3, 0.42, hz - 0.05, hz + 0.44, radius=0.12)
	head.paint(shell, ARMOR, z_range=(hz - 0.3, hz + 0.6))
	brow = head.box(-0.43, 0.43, -0.42, -0.28, hz + 0.08, hz + 0.36, taper=0.03)
	head.paint(brow, ARMOR, "MID")
	for side in (-1, 1):
		guard = head.box(side * 0.4 - 0.05, side * 0.4 + 0.05, -0.32, 0.3, hz - 0.36, hz + 0.1)
		head.paint(guard, ARMOR, "LOW")
		disc = head.cylinder(0.13, 0.0, 0.06, sides=8)
		head.transform(disc, Matrix.Translation((side * 0.45, 0.0, hz - 0.1)) @ Matrix.Rotation(side * math.pi / 2, 4, "Y"))
		head.paint(disc, "cobre_verde", "MID")
		core = head.cylinder(0.06, 0.0, 0.08, sides=6)
		head.transform(core, Matrix.Translation((side * 0.45, 0.0, hz - 0.1)) @ Matrix.Rotation(side * math.pi / 2, 4, "Y"))
		head.paint(core, NEON, "MID")
		fin = side_plane(head, [(-0.32, 0.0), (0.1, 0.0), (0.2, 0.08), (0.38, 0.08), (0.48, 0.18), (0.85, 0.3), (0.42, 0.34), (0.28, 0.26), (0.0, 0.3), (-0.2, 0.2)], side * 0.33, 0.08)
		head.transform(fin, Matrix.Translation((0, 0, hz + 0.32)) @ Matrix.Rotation(-side * 0.18, 4, "Y"))
		head.paint(fin, ARMOR, z_range=(hz + 0.2, hz + 1.0))
	epi.chakana_plate(head, Vector((0, -0.43, hz + 0.22)), 0.3, TRIM)
	gem = head.polygon([(0.0, -0.1), (0.08, 0.0), (0.0, 0.1), (-0.08, 0.0)], 0.0, 0.05)
	head.transform(gem, Matrix.Translation((0, -0.45, hz + 0.22)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	head.paint(gem, NEON, "MID")


def trenza(head, hz):
	"""Trenza larga que cae por la espalda y se abre hacia atrás, con anillos de neón y una borla."""
	prev = None
	for i in range(10):
		t = i / 9
		c = Vector((0.12 * math.sin(t * 3.0), 0.42 + 0.95 * math.sin(t * 1.5), hz + 0.2 - 0.95 * t))
		r = 0.15 - 0.07 * t
		head.paint(head.blob(c, r, squash=(1.0, 1.0, 1.25), subdiv=1, rough=0.05), SUIT, "MID", vary=0.05)
		if i in (2, 6):
			ring = head.cylinder(r * 1.1, -0.03, 0.03, sides=8)
			head.transform(ring, Matrix.Translation(c))
			head.paint(ring, NEON, "MID")
		prev = c
	tassel = head.cylinder(0.08, 0.0, 0.22, sides=6, radius_top=0.03)
	head.transform(tassel, Matrix.Translation(prev - Vector((0, 0, 0.25))))
	head.paint(tassel, ARMOR, "MID")
	head.paint(head.blob(prev - Vector((0, 0, 0.04)), 0.06, subdiv=1, rough=0.0), TRIM, "MID")


def jugador():
	rig = start()
	bp = bone_points(rig)
	body = Body(rig, "jugador", 10)
	hips = body.part("hips")
	hips.paint(hips.box(-0.24, 0.24, -0.17, 0.17, 0.4, 0.66), SUIT, "MID", vary=0.03)
	hips.paint(hips.box(-0.26, 0.26, -0.19, 0.19, 0.58, 0.66), TRIM, "MID")
	for y0, y1 in ((-0.22, -0.18), (0.18, 0.22)):
		flap = hips.box(-0.17, 0.17, y0, y1, 0.28, 0.6, taper=0.0)
		hips.paint_bands(flap, [(0.36, 0.39, NEON, "MID")], default=(0, 0, ARMOR, "MID"))
	torso = body.part("chest")
	torso.paint(torso.box(-0.22, 0.22, -0.16, 0.16, 0.62, 1.2, taper=0.0), SUIT, "MID")
	plate = torso.box(-0.26, 0.26, -0.22, 0.12, 0.84, 1.2, taper=0.03)
	torso.paint_bands(plate, [(0.92, 0.95, NEON, "MID")], default=(0, 0, ARMOR, "MID"))
	epi.chakana_plate(torso, Vector((0, -0.23, 1.07)), 0.16, TRIM)
	collar = torso.lathe([(0.2, 1.17), (0.22, 1.24), (0.0, 1.24)], sides=8)
	torso.paint(collar, TRIM, "MID")
	jugador_head(body.part("head"), 1.72)
	trenza(body.part("head"), 1.72)
	for side in ("l", "r"):
		up = body.part(f"upperarm.{side}")
		a, b = bp[f"upperarm.{side}"]
		up.paint(limb(up, a, b, 0.085, 0.075), SUIT, "MID")
		up.paint(up.rounded_box(a.x - 0.17, a.x + 0.17, a.y - 0.17, a.y + 0.17, a.z - 0.1, a.z + 0.16, radius=0.07), ARMOR, "MID")
		low = body.part(f"lowerarm.{side}")
		a, b = bp[f"lowerarm.{side}"]
		low.paint(limb(low, a, b, 0.1, 0.13, sides=8), ARMOR, "MID", vary=0.03)
		low.paint(limb(low, a + (b - a) * 0.72, a + (b - a) * 0.84, 0.135, 0.135, sides=8), NEON, "MID")
		wr = body.part(f"wrist.{side}")
		wr.paint(limb(wr, *bp[f"wrist.{side}"], 0.07, 0.07), SUIT, "MID")
		hand = body.part(f"hand.{side}")
		h0, h1 = bp[f"hand.{side}"]
		hand.paint(hand.blob((h0 + h1) / 2, 0.1, squash=(1.2, 0.9, 1.0), subdiv=1, rough=0.1), SUIT, "MID")
		ul = body.part(f"upperleg.{side}")
		ul.paint(limb(ul, *bp[f"upperleg.{side}"], 0.11, 0.1), SUIT, "MID", vary=0.03)
		ll = body.part(f"lowerleg.{side}")
		a, b = bp[f"lowerleg.{side}"]
		ll.paint(limb(ll, a, b, 0.15, 0.13, sides=8), ARMOR, "MID", vary=0.03)
		ll.paint(limb(ll, a - (b - a) * 0.05, a + (b - a) * 0.12, 0.17, 0.165, sides=8), TRIM, "MID")
		foot = body.part(f"foot.{side}")
		f0, _ = bp[f"foot.{side}"]
		foot.paint(foot.box(f0.x - 0.13, f0.x + 0.13, f0.y - 0.24, f0.y + 0.1, 0.0, 0.16, taper=0.03), ARMOR, "LOW")
		foot.paint(foot.box(f0.x - 0.135, f0.x + 0.135, f0.y - 0.245, f0.y + 0.105, 0.0, 0.035), NEON, "MID")
	body.build()
	save("jugador")


# --- chullpas (enemigos) ---

RUST = "hierro"
WRAP = "tierra"
GLOW = "doom"


def chullpa_head(head, hz, guardian):
	"""Calavera con casco de cobre escalonado, visor y ojos de doom; el guardián lleva aletas como el jugador."""
	skull = head.blob((0, 0, hz), 0.4, squash=(1.0, 0.95, 1.05), subdiv=2, rough=0.05)
	head.paint(skull, "hueso", z_range=(hz - 0.5, hz + 0.6))
	jaw = head.box(-0.24, 0.24, -0.34, 0.1, hz - 0.5, hz - 0.3, taper=0.03)
	head.paint(jaw, "hueso", "LOW")
	for x in (-0.07, 0.0, 0.07):
		head.paint(head.box(x - 0.02, x + 0.02, -0.355, -0.33, hz - 0.36, hz - 0.3), "noche", "MID")
	shell = head.rounded_box(-0.44, 0.44, -0.28, 0.42, hz + 0.02, hz + 0.44, radius=0.1)
	head.jitter(shell, 0.015)
	head.paint(shell, RUST, "LOW", vary=0.08)
	visor = head.box(-0.44, 0.44, -0.42, -0.28, hz - 0.12, hz + 0.16, taper=0.02)
	head.paint(visor, RUST, "DARK", vary=0.06)
	for x in (-0.16, 0.16):
		head.paint(head.box(x - 0.09, x + 0.09, -0.435, -0.42, hz - 0.06, hz + 0.04), GLOW, "MID")
	epi.chakana_plate(head, Vector((0, -0.43, hz + 0.28)), 0.24, "dorado" if guardian else "cobre_verde")
	if guardian:
		for side in (-1, 1):
			fin = side_plane(head, [(-0.3, 0.0), (0.1, 0.0), (0.2, 0.08), (0.38, 0.08), (0.48, 0.18), (0.85, 0.3), (0.42, 0.34), (0.28, 0.26), (0.0, 0.3), (-0.2, 0.2)], side * 0.33, 0.08)
			head.transform(fin, Matrix.Translation((0, 0, hz + 0.32)) @ Matrix.Rotation(-side * 0.18, 4, "Y"))
			head.paint(fin, RUST, "LOW")
			edge = side_plane(head, [(0.48, 0.18), (0.85, 0.3), (0.8, 0.31), (0.46, 0.21)], side * 0.33, 0.1)
			head.transform(edge, Matrix.Translation((0, 0, hz + 0.32)) @ Matrix.Rotation(-side * 0.18, 4, "Y"))
			head.paint(edge, GLOW, "MID")
	else:
		crest = side_plane(head, [(-0.2, 0.0), (0.3, 0.0), (0.45, 0.18), (0.2, 0.16), (0.05, 0.26), (-0.1, 0.12)], 0.0, 0.07)
		head.transform(crest, Matrix.Translation((0, 0, hz + 0.4)))
		head.paint(crest, RUST, "LOW", vary=0.1)
	# jirones que cuelgan atrás, como la trenza del jugador
	for i, x in enumerate((-0.18, 0.0, 0.18)):
		strip = head.box(x - 0.07, x + 0.07, 0.36, 0.42, hz - 0.9 + i % 2 * 0.15, hz + 0.1, taper=0.0)
		head.transform(strip, Matrix.Translation((0, 0.42, hz + 0.1)) @ Matrix.Rotation(-0.35, 4, "X") @ Matrix.Translation((0, -0.42, -hz - 0.1)))
		head.jitter(strip, 0.02)
		head.paint(strip, "tela_roja" if guardian else WRAP, "LOW", vary=0.12)


def chullpa(name, guardian):
	rig = start()
	bp = bone_points(rig)
	body = Body(rig, name, 20 if guardian else 30)
	hips = body.part("hips")
	hips.paint(hips.box(-0.2, 0.2, -0.13, 0.13, 0.42, 0.62), "hueso", "LOW")
	wrap = hips.lathe([(0.27, 0.28), (0.27, 0.62), (0.0, 0.62)], sides=6)
	hips.jitter(wrap, 0.04)
	hips.paint_bands(wrap, [(0.5, 0.54, GLOW, "MID")] if guardian else [], default=(0, 0, "tela_roja" if guardian else WRAP, "LOW"))
	hips.paint(hips.box(-0.29, 0.29, -0.2, 0.2, 0.56, 0.63), "madera_oscura", "MID")
	spine = body.part("spine")
	spine.paint(limb(spine, *bp["spine"], 0.07, 0.07), "hueso", "MID")
	chest = body.part("chest")
	ribs = []
	for i in range(4):
		z = 0.82 + i * 0.1
		ribs += chest.box(-0.2 + i * 0.01, 0.2 - i * 0.01, -0.13, 0.11, z, z + 0.06)
	chest.paint(ribs, "hueso", "MID", vary=0.05)
	core = chest.blob((0, -0.02, 1.0), 0.1, subdiv=1, rough=0.1)
	chest.paint(core, GLOW, "MID")
	if guardian:
		plate = chest.box(-0.26, 0.26, -0.22, 0.12, 0.84, 1.2, taper=0.03)
		chest.paint_bands(plate, [(0.92, 0.95, GLOW, "MID")], default=(0, 0, RUST, "LOW"))
		chest.paint(epi.eye(chest, Vector((0, -0.23, 1.07)), 0.12, depth=0.02, pupil_swatch=GLOW), "dorado", "LIGHT")
	else:
		strap = chest.box(-0.24, 0.24, -0.16, 0.14, 0.86, 0.94)
		chest.transform(strap, Matrix.Translation((0, 0, 0.9)) @ Matrix.Rotation(0.6, 4, "Y") @ Matrix.Translation((0, 0, -0.9)))
		chest.paint(strap, WRAP, "LOW", vary=0.1)
	collar = chest.lathe([(0.24, 1.12), (0.27, 1.22), (0.0, 1.23)], sides=6)
	chest.jitter(collar, 0.03)
	chest.paint(collar, "dorado" if guardian else WRAP, "MID" if guardian else "DARK", vary=0.1)
	chullpa_head(body.part("head"), 1.66, guardian)
	for side in ("l", "r"):
		armored = guardian or side == "l"
		up = body.part(f"upperarm.{side}")
		a, b = bp[f"upperarm.{side}"]
		up.paint(limb(up, a, b, 0.06, 0.05), "hueso", "MID")
		if armored:
			pad = up.rounded_box(a.x - 0.17, a.x + 0.17, a.y - 0.17, a.y + 0.17, a.z - 0.1, a.z + 0.16, radius=0.07)
			up.jitter(pad, 0.015)
			up.paint(pad, RUST, "LOW", vary=0.06)
		low = body.part(f"lowerarm.{side}")
		a, b = bp[f"lowerarm.{side}"]
		if armored:
			low.paint(limb(low, a, b, 0.09, 0.12, sides=8), RUST, "LOW", vary=0.06)
			low.paint(limb(low, a + (b - a) * 0.72, a + (b - a) * 0.84, 0.125, 0.125, sides=8), GLOW, "MID")
		else:
			low.paint(limb(low, a, b, 0.05, 0.045), "hueso", "MID")
			low.paint(limb(low, a + (b - a) * 0.3, a + (b - a) * 0.8, 0.075, 0.07), WRAP, "LOW", vary=0.1)
		wr = body.part(f"wrist.{side}")
		wr.paint(limb(wr, *bp[f"wrist.{side}"], 0.045, 0.045), "hueso", "MID")
		hand = body.part(f"hand.{side}")
		h0, h1 = bp[f"hand.{side}"]
		hand.paint(hand.blob((h0 + h1) / 2, 0.09, squash=(1.2, 0.9, 1.0), subdiv=1, rough=0.15), "hueso", "MID")
		ul = body.part(f"upperleg.{side}")
		ul.paint(limb(ul, *bp[f"upperleg.{side}"], 0.07, 0.06), "hueso", "MID")
		ll = body.part(f"lowerleg.{side}")
		a, b = bp[f"lowerleg.{side}"]
		ll.paint(limb(ll, a, b, 0.14, 0.12, sides=8), RUST if guardian else WRAP, "LOW", vary=0.08)
		ll.paint(limb(ll, a - (b - a) * 0.05, a + (b - a) * 0.12, 0.16, 0.155, sides=8), "madera_oscura", "MID")
		foot = body.part(f"foot.{side}")
		f0, _ = bp[f"foot.{side}"]
		boot = foot.box(f0.x - 0.12, f0.x + 0.12, f0.y - 0.22, f0.y + 0.09, 0.0, 0.15, taper=0.03)
		foot.jitter(boot, 0.01)
		foot.paint(boot, RUST if guardian else "madera_oscura", "LOW")
		if guardian:
			foot.paint(foot.box(f0.x - 0.125, f0.x + 0.125, f0.y - 0.225, f0.y + 0.095, 0.0, 0.03), GLOW, "MID")
	body.build()
	save(name)


jugador()
chullpa("chullpa", False)
chullpa("chullpa_guardian", True)
