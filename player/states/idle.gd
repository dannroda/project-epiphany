# Idle
extends PlayerState

func _enter() -> void:
	if not player.anim_tree.active:
		player.anim_tree.active = true
	player.anim_tree.set(&"parameters/Movement/transition_request", "Idle")


func _update(delta: float) -> void:
	player.velocity.x = move_toward(player.velocity.x, 0, SPEED)
	player.velocity.z = move_toward(player.velocity.z, 0, SPEED)
	player.move_and_slide()

	var target: Node3D = blackboard.get_var("target", null)
	var combat_anim_state = player.anim_tree.get(&"parameters/Combat/current_state")

	if target and is_instance_valid(target):
		if combat_anim_state == "Normal":
			player.anim_tree.set(&"parameters/Combat/transition_request", "Targeting")
		player.anim_tree["parameters/Targeting/blend_position"] = Vector2.ZERO
		var forward := target.global_position - player.global_position
		forward.y = 0
		if not forward.is_zero_approx():
			forward = forward.normalized()
			player.look_at(player.global_position + forward, Vector3.UP)
			player.model.rotation = Vector3(0, PI, 0)
	else:
		if combat_anim_state == "Targeting":
			player.anim_tree.set(&"parameters/Combat/transition_request", "Normal")
