extends PlayerState
## Lleva algo levantado (Liftable) sobre la cabeza: camina más lento; interactuar o atacar lo tira hacia adelante (o al
## objetivo fijado), rodar o recibir un golpe lo suelta.

const CARRY_SPEED := 3.0
const THROW_DISTANCE := 4.5
const FLIGHT_TIME := 0.5

var _body: ThrownObject
var _elapsed := 0.0
var _lift_time := 0.0
var _thrown_at := -1.0


func _enter() -> void:
	var liftable: Liftable = blackboard.get_var("liftable")
	_body = liftable.make_body()
	_elapsed = 0.0
	_thrown_at = -1.0
	_lift_time = player.anim_player.get_animation(&"Carry/Carry_Lift").length
	player.velocity = Vector3.ZERO
	player.carrier.carry(_body, true)


func _update(delta: float) -> void:
	_elapsed += delta
	if _thrown_at >= 0.0:
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		player.move_and_slide()
		if player.carrier.is_carrying() and _elapsed - _thrown_at >= player.carrier.throw_delay():
			_body.flying = true
			player.carrier.throw(_throw_point(), FLIGHT_TIME)
		elif _elapsed - _thrown_at >= player.carrier.throw_length():
			dispatch("finished")
		return
	if not player.carrier.is_carrying():
		dispatch("finished")
		return
	var lifting := _elapsed < _lift_time
	var input_dir: Vector2 = blackboard.get_var("input_dir", Vector2.ZERO)
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized() if not lifting else Vector3.ZERO
	player.velocity.x = direction.x * CARRY_SPEED
	player.velocity.z = direction.z * CARRY_SPEED
	player.move_and_slide()
	if not direction.is_zero_approx():
		player.model.look_at(player.global_position - direction)
	if not lifting:
		player.carrier.set_walking(not direction.is_zero_approx())
		var buffer := player.input_buffer
		if player.controls.just_pressed(&"interact") or buffer.has(&"attack"):
			buffer.consume(&"attack")
			_thrown_at = _elapsed
			player.carrier.start_throw()


func _exit() -> void:
	if player.carrier.is_carrying():
		_body.flying = true
	player.carrier.drop()


func _throw_point() -> Vector3:
	var target: Node3D = player.targeting.current
	if target and is_instance_valid(target):
		return target.global_position + Vector3.UP * 0.5
	var forward := player.model.global_basis.z
	forward.y = 0.0
	return player.global_position + forward.normalized() * THROW_DISTANCE + Vector3.UP * 0.3
