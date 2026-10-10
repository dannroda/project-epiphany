extends SceneTree
## Arma player/animation/libs/Carry.res desde assets/epiphany/anim/carry.glb (lo genera tools/blender/build_carry_anims.py),
## con las pistas apuntando a "Skeleton3D:<hueso>" como las otras librerías del player.
## godot --headless --path . --script res://tools/build_carry_library.gd

const SOURCE := "res://assets/epiphany/anim/carry.glb"
const OUTPUT := "res://player/animation/libs/Carry.res"
const LOOPS: Array[StringName] = [&"Carry_Idle", &"Carry_Walk"]


func _initialize() -> void:
	var scene := (load(SOURCE) as PackedScene).instantiate()
	var player := scene.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var lib := AnimationLibrary.new()
	for anim_name in player.get_animation_list():
		var anim := player.get_animation(anim_name).duplicate() as Animation
		for i in anim.get_track_count():
			var path := String(anim.track_get_path(i))
			anim.track_set_path(i, NodePath("Skeleton3D:" + path.get_slice(":", 1)))
		anim.loop_mode = Animation.LOOP_LINEAR if anim_name in LOOPS else Animation.LOOP_NONE
		lib.add_animation(anim_name, anim)
	scene.free()
	var uid := ResourceLoader.get_resource_uid(OUTPUT)
	var err := ResourceSaver.save(lib, OUTPUT)
	if err == OK and uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(OUTPUT, uid)
	print("carry_library: ", error_string(err), " · ", lib.get_animation_list())
	quit(0 if err == OK else 1)
