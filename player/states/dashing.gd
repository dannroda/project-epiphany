extends PlayerState
## Sandalias (11.118): con el botón mantenido toma impulso en el lugar (el stick elige hacia dónde) y después corre recto
## hasta soltarlo o chocar. Al chocar rebota, sacude el encuadre y golpea lo de adelante con el elemento `dash`: cada
## Hurtbox decide (los árboles y muros agrietados se sacuden). Con la pluma en plena carrera, salto largo (Jumping).

const ELEMENT := DamageInfo.DASH

@export var windup := 0.5
@export var speed := 9.5
@export var crash_damage := 1
@export var crash_knockback := 6.0
@export var bounce_speed := 4.0
@export var bounce_time := 0.3
@export var dust_every := 0.08

enum Phase { WINDUP, RUN, BOUNCE }

var _phase := Phase.WINDUP
var _direction := Vector3.ZERO
var _elapsed := 0.0
var _dust := 0.0
var _button := &""


func _enter() -> void:
	player.attack_runner.stop()
	if player.is_blocking():
		blackboard.set_var(BB_IS_BLOCKING, false)
		player.shield.set_guard(false)
	_phase = Phase.WINDUP
	_elapsed = 0.0
	_dust = 0.0
	_button = PlayerCharacter.ITEM_ACTIONS[blackboard.get_var(BB_ITEM_BUTTON, 0)]
	_direction = player.model.global_basis.z
	_direction.y = 0.0
	_direction = _direction.normalized()
	player.anim_tree.set(&"parameters/Movement/transition_request", "Running")


func _update(delta: float) -> void:
	_elapsed += delta
	match _phase:
		Phase.WINDUP:
			_aim()
			player.velocity.x = 0.0
			player.velocity.z = 0.0
			player.move_and_slide()
			_puff(delta)
			if not player.controls.pressed(_button):
				dispatch("finished")
			elif _elapsed >= windup:
				_phase = Phase.RUN
				Feel.sfx(&"roll", player.global_position)
		Phase.RUN:
			player.velocity.x = _direction.x * speed
			player.velocity.z = _direction.z * speed
			player.move_and_slide()
			_puff(delta)
			if _crashed():
				_crash()
			elif not player.controls.pressed(_button):
				dispatch("finished")
		Phase.BOUNCE:
			var left := 1.0 - clampf((_elapsed) / bounce_time, 0.0, 1.0)
			player.velocity.x = -_direction.x * bounce_speed * left
			player.velocity.z = -_direction.z * bounce_speed * left
			player.move_and_slide()
			if _elapsed >= bounce_time:
				dispatch("finished")


func _exit() -> void:
	if _phase == Phase.RUN:
		blackboard.set_var(BB_LONG_JUMP, [_direction, Engine.get_physics_frames()])


func running() -> bool:
	return _phase == Phase.RUN


func _aim() -> void:
	var input: Vector2 = blackboard.get_var(BB_INPUT_DIR, Vector2.ZERO)
	if input.length() > 0.3:
		_direction = Vector3(input.x, 0.0, input.y).normalized()
	player.model.look_at(player.model.global_position - _direction, Vector3.UP)


func _puff(delta: float) -> void:
	_dust -= delta
	if _dust <= 0.0 and player.is_on_floor():
		_dust = dust_every
		Feel.burst(&"dust", player.global_position + Vector3.UP * 0.1, -_direction + Vector3.UP * 0.3)


func _crashed() -> bool:
	for i in player.get_slide_collision_count():
		if player.get_slide_collision(i).get_normal().dot(_direction) < -0.6:
			return true
	return false


func _crash() -> void:
	var ahead := player.global_position + Vector3.UP * 0.8 + _direction * 0.7
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, ahead)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in player.get_world_3d().direct_space_state.intersect_shape(query, 16):
		var box := hit.collider as Hurtbox
		if box == null or box == player.hurtbox or box.team == player.hurtbox.team:
			continue
		box.receive(DamageInfo.make(crash_damage, crash_knockback, player, ELEMENT))
	Feel.shake(0.35, _direction, player.controls.joypads)
	Feel.sfx(&"hit_stone", ahead)
	Feel.burst(&"dust", ahead, -_direction)
	_phase = Phase.BOUNCE
	_elapsed = 0.0
