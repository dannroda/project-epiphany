# Moving
extends PlayerState

const BLOCK_SPEED = 2.0

func _enter() -> void:
	pass

func _update(delta: float) -> void:
	var input_dir: Vector2 = blackboard.get_var(BB_INPUT_DIR, Vector2.ZERO)
	var target: Node3D = blackboard.get_var(BB_TARGET, null)
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()
	var locked := is_instance_valid(target)
	set_locked_legs(locked)
	if locked:
		_locked_move(input_dir, delta, target)
	else:
		player.anim_tree.set(&"parameters/Movement/transition_request", "Running")
		_free_move(direction, delta)

func _locked_move(input: Vector2, _delta: float, target: Node3D) -> void:
	var is_blocking: bool = blackboard.get_var(BB_IS_BLOCKING, false)
	move_locked(input, BLOCK_SPEED if is_blocking else SPEED, target)

func _free_move(dir: Vector3, _delta: float) -> void:
	var is_blocking: bool = blackboard.get_var(BB_IS_BLOCKING, false)
	var holding_light := is_blocking and player.shield.is_catching_light()
	var speed := (BLOCK_SPEED if is_blocking else SPEED) * player.ground_speed
	if player.sword_charge.is_charging():
		speed *= player.sword_charge.move_factor
	
	player.velocity.x = dir.x * speed
	player.velocity.z = dir.z * speed
	player.move_and_slide()
	var block := player.block_ahead(dir)
	if block:
		blackboard.set_var(BB_PUSH_BLOCK, block)
		blackboard.set_var(BB_PUSH_DIR, PushBlock.axis(dir))
		dispatch("push")
		return
	var flat := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if not flat.is_zero_approx() and not player.aim.aiming and not holding_light:
		player.model.look_at(player.model.global_position - flat)
