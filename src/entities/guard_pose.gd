class_name GuardPose
extends SkeletonModifier3D
## Pone encima de la animación los huesos de una pose fija (el brazo del escudo levantado). `influence` la mezcla.

@export var library: AnimationLibrary
@export var animation: StringName = &"Melee_Blocking"
@export var time := 0.4
@export var bones: PackedStringArray = ["upperarm.l", "lowerarm.l", "wrist.l", "hand.l"]

var _pose: Dictionary[int, Quaternion] = {}


func _ready() -> void:
	var anim := library.get_animation(animation)
	var skeleton := get_skeleton()
	for bone in bones:
		var track := anim.find_track(NodePath("Skeleton3D:" + bone), Animation.TYPE_ROTATION_3D)
		var index := skeleton.find_bone(bone)
		if track >= 0 and index >= 0:
			_pose[index] = anim.rotation_track_interpolate(track, time)


func _process_modification() -> void:
	var skeleton := get_skeleton()
	for index in _pose:
		skeleton.set_bone_pose_rotation(index, _pose[index])
