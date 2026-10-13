extends PlayerState
## Atrapado por una mano del jefe: sigue al agarre y se suelta apretando botones.

const MASH_ACTIONS: Array[StringName] = [&"attack", &"interact", &"dodge", &"block"]

## Apretones para soltarse.
@export var presses_to_escape := 8

var _presses := 0


func _enter() -> void:
	player.attack_runner.stop()
	if player.is_blocking():
		blackboard.set_var(BB_IS_BLOCKING, false)
		player.shield.set_guard(false)
	player.velocity = Vector3.ZERO
	_presses = 0
	player.anim_tree.set(&"parameters/Hurt/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _update(_delta: float) -> void:
	var grip: Node3D = blackboard.get_var(BB_GRABBED_BY, null)
	if grip == null or not is_instance_valid(grip):
		dispatch("finished")
		return
	player.global_position = grip.global_position
	for action in MASH_ACTIONS:
		if player.controls.just_pressed(action):
			_presses += 1
			player.model.rotation.y += 0.25 * (1 if _presses % 2 else -1)
	if _presses >= presses_to_escape:
		blackboard.set_var(BB_GRABBED_BY, null)
		player.escaped.emit()
		dispatch("finished")
