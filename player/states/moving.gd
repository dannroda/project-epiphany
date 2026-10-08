# Moving
extends PlayerState

const BLOCK_SPEED = 2.0

func _enter() -> void:
	pass

func _update(delta: float) -> void:
	var input_dir: Vector2 = blackboard.get_var("input_dir", Vector2.ZERO)
	var target: Node3D = blackboard.get_var("target", null)
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()
	var combat_anim_state = player.anim_tree.get(&"parameters/Combat/current_state")

	if target and is_instance_valid(target):
		if combat_anim_state == "Normal":
			player.anim_tree.set(&"parameters/Combat/transition_request", "Targeting")
		_locked_move(input_dir, delta, target)
	else:
		if combat_anim_state == "Targeting":
			player.anim_tree.set(&"parameters/Combat/transition_request", "Normal")
		player.anim_tree.set(&"parameters/Movement/transition_request", "Running")
		_free_move(direction, delta)

func _locked_move(input: Vector2, _delta: float, target: Node3D) -> void:
	var is_blocking: bool = blackboard.get_var("is_blocking", false)
	move_locked(input, BLOCK_SPEED if is_blocking else SPEED, target)

func _free_move(dir: Vector3, delta: float) -> void:
	var is_blocking: bool = blackboard.get_var("is_blocking", false)
	var speed := BLOCK_SPEED if is_blocking else SPEED
	
	player.velocity.x = dir.x * speed
	player.velocity.z = dir.z * speed
	player.move_and_slide()
	if not player.velocity.is_zero_approx() and not player.aim.aiming:
		player.model.look_at(player.global_position - player.velocity)
