# Idle
extends PlayerState

const BRAKE = 20.0

func _enter() -> void:
	if not player.anim_tree.active:
		player.anim_tree.active = true
	player.anim_tree.set(&"parameters/Movement/transition_request", "Idle")


func _update(delta: float) -> void:
	player.velocity.x = move_toward(player.velocity.x, 0, BRAKE)
	player.velocity.z = move_toward(player.velocity.z, 0, BRAKE)
	player.move_and_slide()

	var target: Node3D = blackboard.get_var(BB_TARGET, null)
	var locked := is_instance_valid(target)
	set_locked_legs(locked)
	if locked:
		player.anim_tree["parameters/Targeting/blend_position"] = Vector2.ZERO
		var forward := target.global_position - player.global_position
		forward.y = 0
		if not forward.is_zero_approx():
			forward = forward.normalized()
			player.look_at(player.global_position + forward, Vector3.UP)
			player.model.rotation = Vector3(0, PI, 0)
