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
			player.anim_tree.set(&"parameters/Combat/transition_request", "Targetting")
		_locked_move(input_dir, delta, target)
	else:
		if combat_anim_state == "Targetting":
			player.anim_tree.set(&"parameters/Combat/transition_request", "Normal")
		player.anim_tree.set(&"parameters/Movement/transition_request", "Running")
		_free_move(direction, delta)

func _locked_move(input: Vector2, delta: float, target: Node3D) -> void:
	var is_blocking: bool = blackboard.get_var("is_blocking", false)
	var speed := BLOCK_SPEED if is_blocking else SPEED
	
	var move_dir := Vector3(input.x, 0, input.y).normalized()
	player.velocity = move_dir * speed
	player.move_and_slide()
	var to_target := target.global_position - player.global_position
	to_target.y = 0
	if to_target.is_zero_approx():
		return
	
	var fwd := to_target.normalized()
	player.look_at(player.global_position + fwd, Vector3.UP)
	player.model.rotation = Vector3(0, PI, 0)
	var character_right := Vector3.UP.cross(-fwd)
	var strafe_x := move_dir.dot(character_right)
	var strafe_forward := move_dir.dot(fwd)
	player.anim_tree["parameters/Targetting/blend_position"] = Vector2(strafe_x, -strafe_forward)

func _free_move(dir: Vector3, delta: float) -> void:
	var is_blocking: bool = blackboard.get_var("is_blocking", false)
	var speed := BLOCK_SPEED if is_blocking else SPEED
	
	player.velocity.x = dir.x * speed
	player.velocity.z = dir.z * speed
	player.move_and_slide()
	if not player.velocity.is_zero_approx():
		player.model.look_at(player.global_position - player.velocity)
