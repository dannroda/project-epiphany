extends PlayerState
## Sube o baja una escalera de soga: sin input, sigue los puntos de BB_CLIMB_PATH. En los tramos verticales trepa
## (Carry/Climb) mirando a BB_CLIMB_FACE; en los demás camina hacia donde va.

@export_group("Ajuste")
@export var climb_speed := 4.4
@export var walk_speed := 6.4
@export_group("")

var _path := PackedVector3Array()
var _face := Vector3.FORWARD
var _next := 0
var _climbing := false


func _enter() -> void:
	_path = blackboard.get_var(BB_CLIMB_PATH, PackedVector3Array())
	_face = blackboard.get_var(BB_CLIMB_FACE, Vector3.FORWARD)
	_next = 0
	_climbing = false
	player.attack_runner.stop()
	player.input_buffer.clear()
	player.velocity = Vector3.ZERO
	player.anim_tree.set(&"parameters/Combat/transition_request", "Normal")


func _update(delta: float) -> void:
	player.velocity = Vector3.ZERO
	if _next >= _path.size():
		dispatch("finished")
		return
	var to := _path[_next] - player.global_position
	var vertical := absf(to.y) > 0.25 * to.length()
	if vertical != _climbing:
		_set_climbing(vertical)
	var step := (climb_speed if vertical else walk_speed) * delta
	if to.length() <= step:
		player.global_position = _path[_next]
		_next += 1
	else:
		player.global_position += to.normalized() * step
		if not vertical and Vector2(to.x, to.z).length() > 0.01:
			player.model.look_at(player.model.global_position - Vector3(to.x, 0.0, to.z), Vector3.UP)


func _exit() -> void:
	player.carrier.drop()


func _set_climbing(on: bool) -> void:
	_climbing = on
	if on:
		player.carrier.climb()
		player.model.look_at(player.model.global_position - _face, Vector3.UP)
	else:
		player.carrier.drop()
		player.anim_tree.set(&"parameters/Movement/transition_request", "Running")
