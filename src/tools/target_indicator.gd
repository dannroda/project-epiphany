class_name TargetIndicator
extends Node3D

@export var height_offset: float = 2.2
@export var rotation_speed: float = 3.0
@export var bob_speed: float = 5.0
@export var bob_amount: float = 0.12
@export var follow_smooth: float = 16.0

var current_target: Node3D = null
var time: float = 0.0

func _ready() -> void:
	top_level = true 
	visible = false

func set_target(new_target: Node3D) -> void:
	current_target = new_target
	if current_target and is_instance_valid(current_target):
		visible = true
		if not is_visible_in_tree():
			global_position = current_target.global_position + Vector3(0, height_offset, 0)
	else:
		visible = false

func _process(delta: float) -> void:
	if not current_target or not is_instance_valid(current_target):
		visible = false
		return

	time += delta
	var bob := sin(time * bob_speed) * bob_amount
	var target_pos := current_target.global_position + Vector3(0, height_offset + bob, 0)

	global_position = global_position.lerp(target_pos, follow_smooth * delta)
	
	rotate_y(rotation_speed * delta)
