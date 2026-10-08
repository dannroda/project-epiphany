extends PlayerState

@export var duration := 0.45
@export var speed := 8.0
## Tramo del roll (0..1) en que no recibe daño.
@export_range(0.0, 1.0) var iframes_from := 0.1
@export_range(0.0, 1.0) var iframes_to := 0.75

var _direction := Vector3.ZERO
var _elapsed := 0.0
var _iframes_given := false


func _enter() -> void:
	player.attack_runner.stop()
	if player.is_blocking():
		blackboard.set_var("is_blocking", false)
		player.set_guard(false)
	_elapsed = 0.0
	_iframes_given = false
	var input: Vector2 = blackboard.get_var("input_dir", Vector2.ZERO)
	_direction = Vector3(input.x, 0.0, input.y).normalized()
	if _direction.is_zero_approx():
		_direction = player.model.global_basis.z
		_direction.y = 0.0
		_direction = _direction.normalized()
	player.anim_tree.set(&"parameters/DodgeDir/transition_request", _animation_for(_direction))
	player.anim_tree.set(&"parameters/Dodge/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	Feel.burst(&"dust", player.global_position + Vector3.UP * 0.1, -_direction)
	Feel.sfx(&"roll", player.global_position)


func _update(delta: float) -> void:
	_elapsed += delta
	if not _iframes_given and _elapsed >= iframes_from * duration:
		player.health.make_invulnerable((iframes_to - iframes_from) * duration)
		_iframes_given = true
	player.velocity.x = _direction.x * speed
	player.velocity.z = _direction.z * speed
	player.move_and_slide()
	if _elapsed >= duration:
		dispatch("finished")


## Sin objetivo: siempre hacia adelante, mirando hacia donde rueda. Con objetivo: según la dirección relativa.
func _animation_for(direction: Vector3) -> String:
	var target := player.targeting.current
	if target == null:
		player.model.look_at(player.model.global_position - direction, Vector3.UP)
		return "Forward"
	var forward := target.global_position - player.global_position
	forward.y = 0.0
	forward = forward.normalized()
	var right := Vector3.UP.cross(-forward)
	var along := direction.dot(forward)
	var side := direction.dot(right)
	if absf(along) >= absf(side):
		return "Forward" if along >= 0.0 else "Backward"
	return "Right" if side >= 0.0 else "Left"
