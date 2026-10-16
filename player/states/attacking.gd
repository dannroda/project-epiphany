extends PlayerState

## Qué tan rápido se frena el paso del golpe.
@export var lunge_damping := 12.0

var _attack: AttackData


func _enter() -> void:
	var observer: AnimationNodeObserver = player.anim_tree.get(&"parameters/Attack/observer")
	if not observer.fade_out_started.is_connected(_on_attack_finished):
		observer.fade_out_started.connect(_on_attack_finished)

	_attack = player.current_attack()
	_face_attack_direction()
	var forward := player.model.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() * (_attack.lunge if _attack else 0.0)
	player.velocity.x = forward.x
	player.velocity.z = forward.z

	player.anim_tree.set(&"parameters/AttackType/transition_request", _attack.tree_state if _attack else &"Slash")
	player.anim_tree.set(&"parameters/Attack/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if _attack and player.anim_player.has_animation(_attack.animation):
		player.attack_runner.start(_attack, player.anim_player.get_animation(_attack.animation).length)


func _update(delta: float) -> void:
	var damping := exp(-lunge_damping * delta)
	player.velocity.x *= damping
	player.velocity.z *= damping
	player.move_and_slide()
	if not can_cancel():
		return
	var input_dir: Vector2 = blackboard.get_var(BB_INPUT_DIR, Vector2.ZERO)
	if input_dir or (player.is_blocking() and _attack != player.SWORD_STAB):
		dispatch("finished")


func _exit() -> void:
	player.attack_runner.stop()


func can_cancel() -> bool:
	return _attack == null or player.attack_runner.progress() >= _attack.cancel_from


## Con objetivo fijado mira al objetivo; si no, hacia donde apunta el stick.
func _face_attack_direction() -> void:
	var direction := Vector3.ZERO
	var target := player.targeting.current
	if target and is_instance_valid(target):
		direction = target.global_position - player.global_position
	else:
		var input: Vector2 = blackboard.get_var(BB_INPUT_DIR, Vector2.ZERO)
		direction = Vector3(input.x, 0.0, input.y)
	direction.y = 0.0
	if not direction.is_zero_approx():
		player.model.look_at(player.model.global_position - direction, Vector3.UP)


func _on_attack_finished() -> void:
	if is_active():
		dispatch("finished")
