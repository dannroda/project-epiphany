extends PlayerState

func _enter() -> void:
	var tween := create_tween()
	tween.tween_property(player, "velocity", Vector3.ZERO, 0.3)
	
	var observer:AnimationNodeObserver = player.anim_tree.get(&"parameters/Attack/observer")
	if not observer.fade_out_started.is_connected(_on_attack_finished):
		observer.fade_out_started.connect(_on_attack_finished)
	
	var is_blocking: bool = blackboard.get_var("is_blocking", false)
	if is_blocking:
		player.anim_tree.set(&"parameters/AttackType/transition_request", "ShieldThrust")
	else:
		player.anim_tree.set(&"parameters/AttackType/transition_request", "Slash")
		
	player.anim_tree.set(&"parameters/Attack/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	#await get_tree().create_timer(0.2).timeout
	#dispatch("finished")
	
#
func _on_attack_finished():
	dispatch("finished")
