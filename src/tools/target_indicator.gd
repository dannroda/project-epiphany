class_name TargetIndicator
extends Node3D

@export var height_offset: float = 2.2
@export var follow_smooth: float = 16.0

var current_target: Node3D = null

func _ready() -> void:
	top_level = true 
	visible = false

func set_target(new_target: Node3D) -> void:
	current_target = new_target
	if current_target and is_instance_valid(current_target):
		visible = true
		if not is_visible_in_tree():
			global_position = current_target.global_position + Vector3(0, _height_of(current_target), 0)
	else:
		visible = false

func _process(delta: float) -> void:
	if not current_target or not is_instance_valid(current_target):
		visible = false
		return

	var target_pos := current_target.global_position + Vector3(0, _height_of(current_target), 0)

	global_position = global_position.lerp(target_pos, 1.0 - exp(-follow_smooth * delta))


func _height_of(target: Node3D) -> float:
	var config = target.get(&"config")
	return config.target_height if config is EntityConfig else height_offset
