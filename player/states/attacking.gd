extends PlayerState


func _enter() -> void:
	var tween := create_tween()
	tween.tween_property(player, "velocity", Vector3.ZERO, 0.3)

	var observer: AnimationNodeObserver = player.anim_tree.get(&"parameters/Attack/observer")
	if not observer.fade_out_started.is_connected(_on_attack_finished):
		observer.fade_out_started.connect(_on_attack_finished)

	var attack := player.current_attack()
	var attack_type := "ShieldThrust" if player.is_blocking() else "Slash"
	player.anim_tree.set(&"parameters/AttackType/transition_request", attack_type)
	player.anim_tree.set(&"parameters/Attack/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if attack and player.anim_player.has_animation(attack.animation):
		player.attack_runner.start(attack, player.anim_player.get_animation(attack.animation).length)


func _update(_delta: float) -> void:
	player.move_and_slide()


func _exit() -> void:
	player.attack_runner.stop()


func _on_attack_finished() -> void:
	dispatch("finished")
