extends PlayerState

@export var duration := 0.25
@export var friction := 20.0

var _left := 0.0


func _enter() -> void:
	player.attack_runner.stop()
	_left = duration
	player.anim_tree.set(&"parameters/Hurt/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	var info: DamageInfo = blackboard.get_var("last_hit", null)
	if info == null or info.source == null:
		return
	var away := player.global_position - info.source.global_position
	away.y = 0.0
	if away.is_zero_approx():
		return
	away = away.normalized()
	player.velocity = away * info.knockback
	player.model.look_at(player.model.global_position + away, Vector3.UP)


func _update(delta: float) -> void:
	player.velocity.x = move_toward(player.velocity.x, 0.0, friction * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, friction * delta)
	player.move_and_slide()
	_left -= delta
	if _left <= 0.0:
		dispatch("finished")
