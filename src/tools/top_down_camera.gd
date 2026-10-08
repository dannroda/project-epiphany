class_name TopDownCamera
extends Camera3D

@export var target_node: PlayerCharacter
@export var offset: Vector3 = Vector3(0, 12, 7) # Altura (Y=12) y distancia hacia atrás (Z=7)
@export var smooth_speed: float = 8.0

func _ready() -> void:
	top_level = true
	if not target_node and get_parent() is PlayerCharacter:
		target_node = get_parent()

	look_at_from_position(global_position, global_position - offset, Vector3.UP)

func _physics_process(delta: float) -> void:
	if not target_node:
		return

	var focus_point := target_node.global_position

	var locked_target: Node3D = null
	if target_node.movement_state and target_node.movement_state.blackboard:
		locked_target = target_node.movement_state.blackboard.get_var("target", null)

	if locked_target and is_instance_valid(locked_target):
		focus_point = (target_node.global_position + locked_target.global_position) / 2.0

	var desired_pos := focus_point + offset
	global_position = global_position.lerp(desired_pos, 1.0 - exp(-smooth_speed * delta))
