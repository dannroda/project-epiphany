extends PlayerState
## Cruce de sala: sin input, el player camina solo hacia la sala nueva mientras la cámara se desliza.

@export var speed := 3.2

var _direction := Vector3.ZERO
var _duration := 0.5
var _elapsed := 0.0


func _enter() -> void:
	_direction = blackboard.get_var(BB_TRANSITION_DIR, Vector3.FORWARD)
	_duration = blackboard.get_var(BB_TRANSITION_TIME, 0.5)
	_elapsed = 0.0
	player.attack_runner.stop()
	player.input_buffer.clear()
	player.anim_tree.set(&"parameters/Combat/transition_request", "Normal")
	player.anim_tree.set(&"parameters/Movement/transition_request", "Running")
	player.model.look_at(player.model.global_position - _direction, Vector3.UP)


func _update(delta: float) -> void:
	_elapsed += delta
	var walk := speed if _ground_ahead() else 0.0
	player.velocity.x = _direction.x * walk
	player.velocity.z = _direction.z * walk
	player.move_and_slide()
	if _elapsed >= _duration:
		dispatch("finished")


## Camina solo hasta el borde: un pozo o agua junto a la puerta no lo traga.
func _ground_ahead() -> bool:
	var ahead := player.global_position + _direction * 0.7
	var query := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 0.5, ahead + Vector3.DOWN * 0.6, 1, [player.get_rid()])
	return not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
