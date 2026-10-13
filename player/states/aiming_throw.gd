extends PlayerState
## Bomba sobre la cabeza: mientras se mantiene el botón se apunta como con el arco (la mecha sigue corriendo) y al
## soltar se tira en arco al punto de la retícula. Rodar o recibir un golpe la deja caer.


var _button := 0
var _behavior: PlaceBehavior
var _elapsed := 0.0
var _released_at := -1.0
var _reticle_distance := 0.0


func _enter() -> void:
	_button = blackboard.get_var(BB_ITEM_BUTTON, 0)
	_behavior = GameState.item_for(GameState.buttons_of(player.controls.slot)[_button]).behavior
	_elapsed = 0.0
	_released_at = -1.0
	player.velocity = Vector3.ZERO
	player.anim_tree.set(&"parameters/Movement/transition_request", "Idle")
	player.aim.aiming = true
	_reticle_distance = player.aim.reticle_distance
	player.aim.reticle_distance = player.aim.throw_distance
	var bomb := _behavior.spawn(player.make_item_context())
	player.carrier.carry(bomb)


func _update(delta: float) -> void:
	_elapsed += delta
	var target: Node3D = player.targeting.current
	player.aim.move_aims = not (target != null and is_instance_valid(target))
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.move_and_slide()
	if _released_at < 0.0:
		if not player.carrier.is_carrying():
			dispatch("finished")
		elif not player.controls.pressed(PlayerCharacter.ITEM_ACTIONS[_button]):
			_start_throw()
	elif player.carrier.is_carrying() and _elapsed - _released_at >= player.carrier.throw_delay():
		player.carrier.throw(_behavior.landing(_throw_point()), _behavior.flight_time)
	elif _elapsed - _released_at >= player.carrier.throw_length():
		dispatch("finished")


func _exit() -> void:
	player.carrier.drop()
	player.aim.aiming = false
	player.aim.move_aims = false
	player.aim.reticle_distance = _reticle_distance


func _start_throw() -> void:
	_released_at = _elapsed
	player.carrier.start_throw()


func _throw_point() -> Vector3:
	var point = player.aim.throw_point()
	if point != null:
		return point
	return player.global_position + player.aim.get_direction() * player.aim.throw_distance
