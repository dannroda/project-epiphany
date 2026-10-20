# Arma assets/epiphany/anim/carry.glb: animaciones de cargar algo sobre la cabeza para el Rig_Medium de KayKit
# (Carry_Lift, Carry_Idle, Carry_Walk, Carry_Throw), de levantar un ítem recién conseguido (ItemGet_Raise, _Hold, _Lower)
# de trepar la escalera de soga (Climb) y del golpe en picada (Plunge_Rise, _Fall, _Stuck, _Pull: la espada arriba, apuntando
# derecho abajo, clavada en el piso y sacándola). Parten de Idle_A y Walking_A; los brazos van por IK a puntos
# fijos y el torso se dobla a mano (las piernas siguen la base). Se hornea todo a claves FK por hueso. El frente del rig mira a -Y.
# Con la cabeza chibi las manos no llegan arriba del casco: quedan levantadas a los costados de la cabeza y el objeto
# va apoyado arriba. Después: tools/build_carry_library.gd arma player/animation/libs/Carry.res.
# blender -b -P tools/blender/build_carry_anims.py
import math
import os

import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, "assets", "kaykit_charanim", "Animations", "gltf", "Rig_Medium", "Rig_Medium_%s.glb")
OUT = os.path.join(ROOT, "assets", "epiphany", "anim", "carry.glb")
FPS = 30
HANDS = Vector((0.52, -0.05, 1.5))
ELBOWS = Vector((1.3, 0.25, 1.0))


def load_rig():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.context.scene.render.fps = FPS
	bpy.ops.import_scene.gltf(filepath=SOURCE % "General")
	rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
	for extra in ("MovementBasic", "MovementAdvanced"):
		before = set(bpy.data.objects)
		bpy.ops.import_scene.gltf(filepath=SOURCE % extra)
		for obj in set(bpy.data.objects) - before:
			bpy.data.objects.remove(obj)
	return rig


def empty(name, co):
	obj = bpy.data.objects.new(name, None)
	bpy.context.scene.collection.objects.link(obj)
	obj.location = co
	return obj


def mirror(v, side):
	return Vector((v.x * side, v.y, v.z))


def add_ik(rig):
	targets = {}
	for bone, chain, goal, pole, angle in (
		("lowerarm.l", 2, HANDS, ELBOWS, 0.0),
		("lowerarm.r", 2, mirror(HANDS, -1), mirror(ELBOWS, -1), math.pi),
	):
		t = empty("ik_" + bone, goal)
		p = empty("pole_" + bone, pole)
		c = rig.pose.bones[bone].constraints.new("IK")
		c.target, c.pole_target, c.pole_angle, c.chain_count = t, p, angle, chain
		c.influence = 0.0
		targets[bone] = (t, p, c)
	return targets


def use(rig, action):
	rig.animation_data.action = action
	if rig.animation_data.action_slot is None:
		rig.animation_data.action_slot = action.slots[0]


def lerp_keys(keys, f):
	"""keys: [(fracción, valor)] ordenadas; interpola suave entre claves."""
	if f <= keys[0][0]:
		return keys[0][1]
	for (a, va), (b, vb) in zip(keys, keys[1:]):
		if f <= b:
			t = (f - a) / (b - a)
			t = t * t * (3 - 2 * t)
			if isinstance(va, Vector):
				return va.lerp(vb, t)
			return va + (vb - va) * t
	return keys[-1][1]


def sample(rig, action, f):
	use(rig, action)
	bpy.context.scene.frame_set(int(round(action.frame_range[0] + f * (action.frame_range[1] - action.frame_range[0]))))
	return {b.name: b.matrix_basis.copy() for b in rig.pose.bones}


def blend(a, b, w):
	la, ra, sa = a.decompose()
	lb, rb, sb = b.decompose()
	return Matrix.LocRotScale(la.lerp(lb, w), ra.slerp(rb, w), sa.lerp(sb, w))


def bake(rig, ik, name, base, frames, pose_at, loop=False, mix=None):
	"""Para cada cuadro: pose de `base` (mezclada con mix = (acción, peso(fracción))), los cambios de pose_at(fracción)
	y las IK; guarda la pose final como FK."""
	bones = rig.pose.bones
	result = {b.name: [] for b in bones}
	for i in range(frames + (0 if loop else 1)):
		f = i / frames
		basis = sample(rig, base, f)
		if mix:
			other, w = sample(rig, mix[0], f), mix[1](f)
			basis = {n: blend(m, other[n], w) for n, m in basis.items()}
		rig.animation_data.action = None
		for b in bones:
			b.matrix_basis = basis[b.name]
		bpy.context.view_layer.update()
		chest = rig.matrix_world @ bones["chest"].matrix
		edit = pose_at(f, chest)
		for bone_name, (axis, angle) in edit.get("bend", {}).items():
			pb = bones[bone_name]
			head = pb.matrix.to_translation()
			pb.matrix = Matrix.Translation(head) @ Matrix.Rotation(angle, 4, axis) @ Matrix.Translation(-head) @ pb.matrix
			bpy.context.view_layer.update()
		for bone_name, (t, p, c) in ik.items():
			left = bone_name.endswith(".l")
			c.influence = edit.get("arms_l", edit.get("arms", 1.0)) if left else edit.get("arms", 1.0)
			t.location = mirror(edit["hands"] if left else edit.get("hands_r", edit["hands"]), 1 if left else -1)
		bpy.context.view_layer.update()
		if "blade" in edit:
			pb = bones["hand.r"]
			now = -(rig.matrix_world @ pb.matrix).col[0].xyz
			turn = Quaternion().slerp(now.rotation_difference(edit["blade"].normalized()), edit.get("blade_w", 1.0))
			head = pb.matrix.to_translation()
			pb.matrix = Matrix.Translation(head) @ turn.to_matrix().to_4x4() @ Matrix.Translation(-head) @ pb.matrix
			bpy.context.view_layer.update()
		for b in bones:
			result[b.name].append(rig.convert_space(pose_bone=b, matrix=b.matrix, from_space="POSE", to_space="LOCAL"))
	for _, _, c in ik.values():
		c.influence = 0.0
	action = bpy.data.actions.new(name)
	action.use_fake_user = True
	rig.animation_data.action = action
	for b in bones:
		b.rotation_mode = "QUATERNION"
		for i, m in enumerate(result[b.name]):
			loc, rot, scale = m.decompose()
			b.location, b.rotation_quaternion, b.scale = loc, rot, scale
			for path in ("location", "rotation_quaternion", "scale"):
				b.keyframe_insert(path, frame=i)
	if loop:
		for b in bones:
			b.matrix_basis = result[b.name][0]
			for path in ("location", "rotation_quaternion", "scale"):
				b.keyframe_insert(path, frame=frames)
	rig.animation_data.action = None
	return action


def carry_pose(f, chest):
	return {"hands": HANDS + (chest.to_translation() - REST_CHEST)}


def lift_pose(f, chest):
	return {
		"hands": lerp_keys([(0.0, Vector((0.3, -0.05, 0.75))), (0.4, Vector((0.28, -0.5, 0.5))), (0.75, Vector((0.45, -0.3, 1.2))), (1.0, HANDS)], f),
		"arms": lerp_keys([(0.0, 0.0), (0.25, 1.0)], f),
		"bend": {"spine": (Vector((1, 0, 0)), -0.5 * lerp_keys([(0.0, 0.0), (0.4, 1.0), (0.85, 0.0)], f))},
	}


RELEASE = 0.45


def throw_pose(f, chest):
	return {
		"hands": lerp_keys([(0.0, HANDS), (0.28, Vector((0.5, 0.1, 1.55))), (RELEASE, Vector((0.3, -0.48, 1.3))), (0.7, Vector((0.28, -0.45, 0.95))), (1.0, Vector((0.3, -0.05, 0.75)))], f),
		"arms": lerp_keys([(0.0, 1.0), (0.7, 1.0), (1.0, 0.0)], f),
		"bend": {"spine": (Vector((1, 0, 0)), lerp_keys([(0.0, 0.0), (0.28, 0.2), (RELEASE, -0.3), (0.75, -0.15), (1.0, 0.0)], f))},
	}


ITEM_HANDS = Vector((0.6, -0.4, 1.72))
ITEM_LEAN = 0.12


def raise_pose(f, chest):
	return {
		"hands": lerp_keys([(0.0, Vector((0.3, -0.05, 0.75))), (0.35, Vector((0.32, -0.3, 0.9))), (0.8, ITEM_HANDS + Vector((0, 0, 0.06))), (1.0, ITEM_HANDS)], f),
		"arms": lerp_keys([(0.0, 0.0), (0.3, 1.0)], f),
		"bend": {"spine": (Vector((1, 0, 0)), lerp_keys([(0.0, 0.0), (0.35, -0.18), (0.8, ITEM_LEAN + 0.04), (1.0, ITEM_LEAN)], f))},
	}


def hold_pose(f, chest):
	return {
		"hands": ITEM_HANDS + (chest.to_translation() - REST_CHEST),
		"bend": {"spine": (Vector((1, 0, 0)), ITEM_LEAN)},
	}


def lower_pose(f, chest):
	return {
		"hands": lerp_keys([(0.0, ITEM_HANDS), (1.0, Vector((0.3, -0.05, 0.75)))], f),
		"arms": lerp_keys([(0.0, 1.0), (1.0, 0.0)], f),
		"bend": {"spine": (Vector((1, 0, 0)), lerp_keys([(0.0, ITEM_LEAN), (1.0, 0.0)], f))},
	}


CLIMB_REACH = (Vector((0.2, -0.32, 1.78)), Vector((0.24, -0.3, 1.3)))


def climb_pose(f, chest):
	"""Trepando de cara a la escalera (el frente del rig): cada mano sube cuando baja la otra y la rodilla del mismo
	lado sube con ella."""
	up = 0.5 - 0.5 * math.cos(2 * math.pi * f)
	high, low = CLIMB_REACH
	return {
		"hands": low.lerp(high, up),
		"hands_r": low.lerp(high, 1.0 - up),
		"bend": {
			"spine": (Vector((1, 0, 0)), -0.12),
			"upperleg.l": (Vector((1, 0, 0)), -0.85 * up),
			"lowerleg.l": (Vector((1, 0, 0)), 1.2 * up),
			"upperleg.r": (Vector((1, 0, 0)), -0.85 * (1.0 - up)),
			"lowerleg.r": (Vector((1, 0, 0)), 1.2 * (1.0 - up)),
		},
	}


# Golpe en picada. La hoja sale por -X de hand.r; "blade" la apunta en el mundo. Las manos van juntas en el mango: la
# izquierda (sobre la derecha) se da en su lado espejado, como hands_r.
DOWN = Vector((0, 0, -1))
PLUNGE_GRIP = Vector((0.06, -0.38, 0.85))
STUCK_GRIP = Vector((0.06, -0.42, 0.62))
IDLE_HAND = Vector((0.48, -0.07, 0.63))


def grip(right):
	return {"hands_r": right, "hands": Vector((-right.x, right.y, right.z + 0.12))}


def rise_pose(f, chest):
	up = lerp_keys([(0.0, 0.0), (0.5, 1.0)], f)
	return {
		"hands_r": lerp_keys([(0.0, IDLE_HAND), (0.6, Vector((0.3, 0.05, 1.45)))], f),
		"hands": Vector((0.5, -0.2, 0.85)),
		"arms": up,
		"blade": Vector((0, -1, 0)).lerp(Vector((0, 0.25, 1)), lerp_keys([(0.0, 0.0), (0.6, 1.0)], f)),
		"blade_w": up,
		"bend": {"spine": (Vector((1, 0, 0)), 0.12 * up)},
	}


def fall_pose(f, chest):
	return {**grip(PLUNGE_GRIP), "blade": DOWN, "bend": {"spine": (Vector((1, 0, 0)), -0.2)}}


def stuck_pose(f, chest):
	return {
		**grip(STUCK_GRIP + (chest.to_translation() - REST_CHEST)),
		"blade": DOWN,
		"bend": {"spine": (Vector((1, 0, 0)), -0.25)},
	}


def pull_pose(f, chest):
	offset = chest.to_translation() - REST_CHEST
	right = lerp_keys([(0.0, STUCK_GRIP), (0.4, STUCK_GRIP + Vector((0, 0.04, 0.33))), (1.0, IDLE_HAND)], f) + offset * (1.0 - f)
	return {
		**grip(right),
		"arms": lerp_keys([(0.0, 1.0), (0.45, 1.0), (1.0, 0.0)], f),
		"arms_l": lerp_keys([(0.0, 1.0), (0.35, 1.0), (0.7, 0.0)], f),
		"blade": DOWN,
		"blade_w": lerp_keys([(0.0, 1.0), (0.4, 1.0), (1.0, 0.0)], f),
		"bend": {"spine": (Vector((1, 0, 0)), lerp_keys([(0.0, -0.25), (0.4, -0.1), (1.0, 0.0)], f))},
	}


rig = load_rig()
rig.animation_data_create()
ik = add_ik(rig)
idle = bpy.data.actions["Idle_A"]
walk = bpy.data.actions["Walking_A"]
air = bpy.data.actions["Jump_Idle"]
crouch = bpy.data.actions["Crouching"]
use(rig, idle)
bpy.context.scene.frame_set(int(idle.frame_range[0]))
REST_CHEST = (rig.matrix_world @ rig.pose.bones["chest"].matrix).to_translation()


def frames_of(action):
	return int(round(action.frame_range[1] - action.frame_range[0]))


made = [
	bake(rig, ik, "Carry_Lift", idle, int(0.5 * FPS), lift_pose),
	bake(rig, ik, "Carry_Idle", idle, frames_of(idle), carry_pose, loop=True),
	bake(rig, ik, "Carry_Walk", walk, frames_of(walk), carry_pose, loop=True),
	bake(rig, ik, "Carry_Throw", idle, int(0.6 * FPS), throw_pose),
	bake(rig, ik, "ItemGet_Raise", idle, int(0.4 * FPS), raise_pose),
	bake(rig, ik, "ItemGet_Hold", idle, frames_of(idle), hold_pose, loop=True),
	bake(rig, ik, "ItemGet_Lower", idle, int(0.3 * FPS), lower_pose),
	bake(rig, ik, "Climb", idle, int(0.9 * FPS), climb_pose, loop=True),
	bake(rig, ik, "Plunge_Rise", air, int(0.3 * FPS), rise_pose),
	bake(rig, ik, "Plunge_Fall", air, frames_of(air), fall_pose, loop=True),
	bake(rig, ik, "Plunge_Stuck", crouch, frames_of(crouch), stuck_pose, loop=True),
	bake(rig, ik, "Plunge_Pull", crouch, int(0.35 * FPS), pull_pose, mix=(idle, lambda f: lerp_keys([(0.0, 0.0), (0.3, 0.0), (1.0, 1.0)], f))),
]
for b in rig.pose.bones:
	for c in list(b.constraints):
		b.constraints.remove(c)
for action in list(bpy.data.actions):
	if action not in made:
		bpy.data.actions.remove(action)
for obj in list(bpy.data.objects):
	if obj.type == "EMPTY":
		bpy.data.objects.remove(obj)
rig.animation_data.action = made[1]
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animation_mode="ACTIONS", export_force_sampling=True, export_frame_range=False)
print("carry:", [(a.name, a.frame_range[:]) for a in made], "suelta en", RELEASE)
