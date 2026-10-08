extends PlayerState
## Cruce de sala: sin input, el player camina solo hacia la sala nueva mientras la cámara se desliza.

@export var speed := 3.2

var _direction := Vector3.ZERO
var _duration := 0.5
var _elapsed := 0.0


func _enter() -> void:
	_direction = blackboard.get_var("transition_dir", Vector3.FORWARD)
	_duration = blackboard.get_var("transition_time", 0.5)
	_elapsed = 0.0
	player.attack_runner.stop()
	player.input_buffer.clear()
	player.anim_tree.set(&"parameters/Combat/transition_request", "Normal")
	player.anim_tree.set(&"parameters/Movement/transition_request", "Running")
	player.model.look_at(player.model.global_position - _direction, Vector3.UP)


func _update(delta: float) -> void:
	_elapsed += delta
	player.velocity.x = _direction.x * speed
	player.velocity.z = _direction.z * speed
	player.move_and_slide()
	if _elapsed >= _duration:
		dispatch("finished")
