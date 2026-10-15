@tool
extends BTAction
## Rodea a `target` a `radius`, mirándolo, un rato al azar; si choca, cambia de sentido.

@export var target_var: StringName = &"target"
@export var radius := 3.5
@export var duration := Vector2(1.2, 2.6)
@export var speed_factor := 0.6
@export var animation: StringName = &"Atoq/walk"

var _side := 1.0
var _until := 0.0


func _generate_name() -> String:
	return "Circle %s m" % radius


func _enter() -> void:
	_side = 1.0 if randf() < 0.5 else -1.0
	_until = randf_range(duration.x, duration.y)
	agent.anim_player.play(animation, 0.2)


func _tick(_delta: float) -> Status:
	var target: Variant = blackboard.get_var(target_var, null, false)
	if not is_instance_valid(target):
		return FAILURE
	if elapsed_time >= _until:
		return SUCCESS
	if agent.is_on_wall():
		_side = -_side
	var out: Vector3 = (agent.global_position - target.global_position) * Vector3(1, 0, 1)
	if out.is_zero_approx():
		out = Vector3.BACK
	var tangent := out.normalized().cross(Vector3.UP) * _side
	var pull := out.normalized() * clampf(radius - out.length(), -1.0, 1.0)
	agent.desired_velocity = (tangent + pull).normalized() * agent.config.move_speed * speed_factor
	agent.face_towards(target.global_position)
	return RUNNING


func _exit() -> void:
	agent.stop_moving()
