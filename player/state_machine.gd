extends LimboHSM

var player: PlayerCharacter

enum LockMode {
	HOLD,
	TOGGLE
}

@export var lock_mode: LockMode = LockMode.HOLD
@export var target_indicator:TargetIndicator

func _setup() -> void:
	player = agent
	if not target_indicator and player.has_node("TargetIndicator"):
		target_indicator = player.get_node("TargetIndicator")
		
	blackboard.set_var("target", null)
	blackboard.set_var("is_blocking", false)
	
	add_transition($Spawning, $Idle, "idle")
	
	add_transition($Idle, $Moving, "move")
	add_transition($Idle, $Attacking, "attack")
	
	add_transition($Moving, $Idle, "idle")
	add_transition($Moving, $Attacking, "attack")
	
	add_transition($Attacking, $Idle, "finished")
	
	initial_state = $Spawning

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"block"):
		blackboard.set_var("is_blocking", true)
		player.set_guard(true)
		
	elif event.is_action_released(&"block"):
		blackboard.set_var("is_blocking", false)
		player.set_guard(false)
		
	if lock_mode == LockMode.HOLD:
		if event.is_action_pressed(&"z-lock"):
			_lock_best_target()

		if event.is_action_released(&"z-lock"):
			_clear_target()

	else: # Toggle
		if event.is_action_pressed(&"z-lock"):
			var current = blackboard.get_var("target", null)
			if current:
				_clear_target()
			else:
				_lock_best_target()


func get_active_camera() -> Camera3D:
	return get_viewport().get_camera_3d()

func _lock_best_target() -> void:
	var camera := get_active_camera()
	if not camera:
		return

	var valid_candidates: Array[Node3D] = []
	for candidate in player.possible_targets:
		if is_instance_valid(candidate) and not camera.is_position_behind(candidate.global_position) and _is_in_range(candidate):
			valid_candidates.append(candidate)

	if valid_candidates.is_empty():
		_clear_target()
		return

	var best := _get_most_centered_target(valid_candidates, camera)

	_set_target(best)

func _get_most_centered_target(candidates: Array[Node3D], camera: Camera3D) -> Node3D:
	var center := get_viewport().get_visible_rect().size / 2.0
	var best: Node3D = null
	var best_score: float = -INF
	for candidate in candidates:
		var screen_pos := camera.unproject_position(candidate.global_position)
		var score := -screen_pos.distance_to(center)
		if score > best_score:
			best_score = score
			best = candidate
	return best

func _set_target(new_target: Node3D) -> void:
	blackboard.set_var("target", new_target)
	
	if target_indicator:
		target_indicator.set_target(new_target)

func _clear_target() -> void:
	_set_target(null)

func _is_in_range(_target: Node3D) -> bool:
	var _space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3.UP,
		_target.global_position + Vector3.UP
	)
	query.exclude = [player.get_rid()]
	query.collision_mask = 1
	var result := _space.intersect_ray(query)
	return result.is_empty() or result.collider == _target

func _update(delta: float) -> void:
	var current_target: Node3D = blackboard.get_var("target", null)
	if current_target != null:
		if not is_instance_valid(current_target) or not player.possible_targets.has(current_target):
			_clear_target()

	if not player.is_on_floor():
		player.velocity += player.get_gravity() * delta

	var input_dir = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backward")
	blackboard.set_var("input_dir", input_dir)
	
	if Input.is_action_just_pressed(&"attack"):
		dispatch("attack")
	elif input_dir:
		dispatch("move")
	else:
		dispatch("idle")
