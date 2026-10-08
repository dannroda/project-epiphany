extends LimboHSM

## Desde qué punto del ataque (0..1) se puede cancelar rodando.
@export_range(0.0, 1.0) var attack_cancel_from := 0.0

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
	add_transition(anystate(), $Hurt, "hurt")
	add_transition($Hurt, $Idle, "finished")
	add_transition($Idle, $Dodging, "dodge")
	add_transition($Moving, $Dodging, "dodge")
	add_transition($Attacking, $Dodging, "dodge", func() -> bool: return player.attack_runner.progress() >= attack_cancel_from)
	add_transition($Dodging, $Idle, "finished")

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

	var buffer := player.input_buffer
	if buffer.has(&"dodge") and dispatch("dodge"):
		buffer.consume(&"dodge")
	elif buffer.has(&"attack") and dispatch("attack"):
		buffer.consume(&"attack")
	elif input_dir:
		dispatch("move")
	else:
		dispatch("idle")
