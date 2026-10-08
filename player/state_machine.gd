extends LimboHSM

var player: PlayerCharacter


func _setup() -> void:
	player = agent
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


func _update(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity += player.get_gravity() * delta

	var input_dir := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backward")
	blackboard.set_var("input_dir", input_dir)

	if Input.is_action_just_pressed(&"attack"):
		dispatch("attack")
	elif input_dir:
		dispatch("move")
	else:
		dispatch("idle")
