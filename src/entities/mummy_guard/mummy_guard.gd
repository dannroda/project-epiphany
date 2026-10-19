class_name MummyGuard
extends ArenaFighter
## Momia guardiana de la Chullpa (D1): se acerca a saltitos y después salta alto sobre el player (su sombra lo sigue
## y se fija antes de caer). Al caer golpea donde cae y manda una onda por el piso que lastima a quien esté parado en
## ella: el sub-jefe la tiene corta (se esquiva alejándose); el jefe, que llena la sala, se salta con la pluma.
## Después de caer queda trabada: ahí le pega todo (espada, bomba, vasija). Fuera de eso, todo rebota.

enum State { IDLE, HOP, AIM, FALL, STUCK, DEAD }

@export var hops := 2
@export var hop_distance := 3.0
@export var hop_time := 0.45
@export var leap_height := 4.0
## En el aire viaja hacia su sombra a esta velocidad (m/s): el salto se ve seguir al player.
@export var air_speed := 9.0
@export var aim_time := 1.1
@export var lock_time := 0.35
@export var impact_damage := 4
@export var wave_radius := 4.5
@export var wave_speed := 7.0
@export var wave_width := 0.9
@export var wave_damage := 2
## Colores del fuego de la onda (los de su mazmorra): el fuego y lo más caliente.
@export var wave_glow := Color(0.95, 0.25, 0.08)
@export var wave_core := Color(1.0, 0.8, 0.4)
@export var stuck_time := 2.6
@export var aim_size := 1.0
## Saltos seguidos (sin trabarse entre uno y otro) con la mitad de la vida o menos.
@export var rage_leaps := 1

@onready var roar_fx: Roar = %Roar
@onready var aim_mark: MeshInstance3D = %AimMark
@onready var ground_waves: GroundWaves = %GroundWaves
@onready var impact: Hitbox = %Impact
## El cuerpo choca con el player; se apaga mientras salta encima (cae donde está el player).
@onready var solid_shape: CollisionShape3D = %SolidShape
@onready var aim_anim: AnimationPlayer = %Aim

var state := State.IDLE
## Lo animan los clips: cuánto subió del salto (1 = `leap_height`) y cuánto creció la sombra (1 = `aim_size`).
var lift := 0.0:
	set(value):
		lift = value
		body.position.y = leap_height * value
var aim_grow := 0.0:
	set(value):
		aim_grow = value
		aim_mark.scale = Vector3.ONE * aim_size * lerpf(0.4, 1.0, value)
var _aim_locked := false


func _ready() -> void:
	super()
	impact.team = config.team
	impact.monitoring = false
	impact.damage_factory = func() -> DamageInfo: return DamageInfo.make(impact_damage, config.attack_knockback * 1.5, impact, DamageInfo.BLAST)
	aim_mark.hide()
	ground_waves.emitter = self
	ground_waves.team = config.team
	ground_waves.only_teams = [EntityConfig.Team.PLAYER]
	ground_waves.width = wave_width
	ground_waves.glow = wave_glow
	ground_waves.core = wave_core
	ground_waves.stop()


## Presentación: mira al player, se echa para atrás, se hincha y grita.
func roar() -> void:
	var player := Players.nearest(global_position)
	if player:
		var look := Vector3(player.global_position.x, body.global_position.y, player.global_position.z)
		if not look.is_equal_approx(body.global_position):
			body.look_at(look, Vector3.UP, true)
	_clip(&"roar", false)
	roar_fx.play()


func reset() -> void:
	_interrupt()
	state = State.IDLE
	pace = 1.0
	remove_from_group(Enemy.GROUP)
	health.reset(config.max_health)
	hurtbox.set_deferred(&"monitorable", true)
	global_position = _home
	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO
	body.scale = Vector3.ONE
	body.show()


func _physics_process(delta: float) -> void:
	if state in [State.IDLE, State.DEAD]:
		return
	var player := Players.nearest(global_position)
	if player and state in [State.HOP, State.AIM]:
		var look := player.global_position
		look.y = body.global_position.y
		if not look.is_equal_approx(body.global_position):
			body.look_at(look, Vector3.UP, true)
	if state == State.AIM and player and aim_mark.visible and not _aim_locked:
		aim_mark.global_position = _clamp_to_arena(player.global_position) + Vector3.UP * 0.03
	if state == State.AIM:
		var shadow := Vector3(aim_mark.global_position.x, global_position.y, aim_mark.global_position.z)
		global_position = global_position.move_toward(shadow, air_speed * pace * delta)


func _run() -> void:
	var turn := _turn
	while not is_dead and turn == _turn:
		for i in hops:
			await _hop()
			if turn != _turn:
				return
		if may_attack.is_valid() and not may_attack.call(self):
			await _wait(0.4)
			continue
		var leaps := rage_leaps if health.current * 2 <= health.max_health else 1
		for i in leaps:
			await _leap(i == leaps - 1)
			if turn != _turn:
				return
		attack_finished.emit()


func _hop() -> void:
	state = State.HOP
	var player := Players.nearest(global_position)
	var target := global_position
	if player:
		var toward := (player.global_position - global_position) * Vector3(1, 0, 1)
		target += toward.limit_length(hop_distance)
	target = _clamp_to_arena(target)
	_tween_to(self, ^"global_position", target, hop_time)
	_clip(&"hop", true, hop_time)
	await _wait(hop_time)
	Feel.burst(&"dust", global_position + Vector3.UP * 0.1, Vector3.UP)
	await _wait(0.25)


func _leap(last := true) -> void:
	state = State.AIM
	_set_solid(false)
	_aim_locked = false
	Feel.sfx(&"roll", global_position)
	var player := Players.nearest(global_position)
	aim_mark.global_position = _clamp_to_arena(player.global_position if player else global_position) + Vector3.UP * 0.03
	aim_grow = 0.0
	aim_mark.show()
	_clip(&"leap")
	aim_anim.speed_scale = pace / aim_time
	aim_anim.stop(true)
	aim_anim.play(&"grow")
	await _wait(aim_time)
	if state != State.AIM:
		return
	_aim_locked = true
	Feel.sfx(&"click", aim_mark.global_position)
	await _wait(lock_time)
	if state != State.AIM:
		return
	state = State.FALL
	var target := aim_mark.global_position
	target.y = global_position.y
	_tween_to(self, ^"global_position", target, 0.18)
	_clip(&"fall")
	await _wait(0.18)
	if state != State.FALL:
		return
	aim_mark.hide()
	impact.activate()
	_after(0.15, impact.deactivate)
	_set_solid(true)
	Feel.burst(&"dust", global_position + Vector3.UP * 0.1, Vector3.UP)
	Feel.sfx(&"boom", global_position)
	Feel.shake(0.45)
	_start_wave()
	if not last:
		await _wait(0.35)
		return
	state = State.STUCK
	_clip(&"stuck", false)
	await _wait(stuck_time, false)
	if state != State.STUCK:
		return
	Feel.burst(&"dust", global_position + Vector3.UP * 0.3, Vector3.UP)
	_clip(&"recover")
	await _wait(0.5)


func _start_wave() -> void:
	ground_waves.speed = wave_speed * pace
	ground_waves.pulse(global_position, wave_radius, wave_damage, config.attack_knockback)


func _on_interrupt() -> void:
	ground_waves.stop()
	aim_mark.hide()
	impact.deactivate()
	body.rotation.z = 0.0
	_set_solid(not is_dead)


func _set_solid(on: bool) -> void:
	solid_shape.set_deferred(&"disabled", not on)


func is_vulnerable() -> bool:
	return state == State.STUCK


func _is_idle() -> bool:
	return state == State.IDLE


func _spark_point() -> Vector3:
	return body.global_position + Vector3.UP


func _die() -> void:
	_interrupt()
	state = State.DEAD
	_set_solid(false)
	Log.info(&"combat", name, "murió")
	remove_from_group(Targeting.GROUP)
	hurtbox.set_deferred(&"monitorable", false)
	Feel.burst(&"dust", global_position + Vector3.UP, Vector3.UP)
	Feel.sfx(&"break", global_position)
	Feel.shake(0.6)
	_clip(&"die", false)
	defeated.emit(self)
