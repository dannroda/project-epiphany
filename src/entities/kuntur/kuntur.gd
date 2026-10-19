class_name Kuntur
extends ArenaFighter
## Cóndor de la Cumbre (D4): vuela en círculos sobre la sala y entre vuelta y vuelta ataca. El joven (sub-jefe) se
## tira en picada (la sombra marca dónde) y queda clavado en la nieve, o se posa en un borde y bate las alas: la ráfaga
## empuja al player y una flecha ahí lo voltea. El Apu (`apu`, jefe) tira plumas que el escudo espejo devuelve (una
## devuelta lo voltea) y con media vida enciende los soles de la sala y se posa a cargar una ráfaga grande: un rayo
## devuelto con el escudo lo encandila y lo voltea. Clavado o volteado le pega todo; volando, todo rebota.

enum State { IDLE, CIRCLE, AIM, DIVE, STUCK, GUST, VOLLEY, PERCH, DOWN, DEAD }

const FEATHER := preload("res://src/entities/projectile.tscn")
const FEATHER_COLOR := Color(0.92, 0.9, 0.86)

@export var apu := false
@export var hover_height := 3.5
@export var circle_time := 2.4
@export var circle_speed := 1.3
@export var fly_speed := 9.0
@export var aim_time := 1.0
@export var lock_time := 0.4
@export var dive_time := 0.25
@export var dive_damage := 2
@export var stuck_time := 2.4
@export var gust_time := 1.8
@export var gust_push := 5.0
@export var volley_count := 3
@export var volley_spread := 0.35
@export var feather_speed := 8.0
@export var feather_damage := 2
@export var perch_time := 3.0
@export var down_time := 3.0
## Los soles de la sala (LightSource): apagados hasta que el Apu llega a media vida.
@export var suns: Array[Node3D] = []

@onready var muzzle: Marker3D = %Muzzle
@onready var roar_fx: Roar = %Roar
@onready var aim_mark: MeshInstance3D = %AimMark
@onready var impact: Hitbox = %Impact
@onready var light_catch: StaticBody3D = %LightCatch
@onready var flash: HitFlash = $HitFlash
## Un clip por pose de alas (planear, batir, plegadas...); _wings cruza de una a otra.
@onready var wings: AnimationPlayer = %Wings

var state := State.IDLE
var _angle := 0.0
var _attacks := 0
var _suns_on := false
var _aim_locked := false
var _push := 0.0
var _scale := Vector3.ONE

## 0 entero, 1 aplastado contra el piso; lo anima el clip die sobre la escala propia del cuerpo.
var squash := 0.0:
	set(value):
		squash = value
		if body:
			body.scale = _scale * Vector3.ONE.lerp(Vector3(1.2, 0.1, 1.2), value)


func _ready() -> void:
	super()
	impact.team = config.team
	impact.monitoring = false
	impact.damage_factory = func() -> DamageInfo: return DamageInfo.make(dive_damage, config.attack_knockback, impact)
	light_catch.lit.connect(_on_lit)
	_catch_light(false)
	body.position.y = hover_height
	_scale = body.scale
	aim_mark.hide()
	_set_suns(false)


func reset() -> void:
	_interrupt()
	state = State.IDLE
	pace = 1.0
	_attacks = 0
	remove_from_group(Enemy.GROUP)
	health.reset(config.max_health)
	hurtbox.set_deferred(&"monitorable", true)
	global_position = _home
	body.position.y = hover_height
	body.rotation = Vector3.ZERO
	squash = 0.0
	body.show()
	_wings(&"glide", 0.0)
	_set_suns(false)


## Mira al player, abre las alas, levanta la cabeza y grita; anda también en la pausa de la presentación.
func roar() -> void:
	var player := Players.nearest(global_position)
	if player:
		_face(player.global_position - global_position)
	_wings(&"roar", 0.6)
	_clip(&"roar", false)
	roar_fx.play()


func _physics_process(delta: float) -> void:
	if state in [State.IDLE, State.DEAD]:
		return
	var player := Players.nearest(global_position)
	match state:
		State.CIRCLE:
			_angle += circle_speed * pace * delta
			var goal := _center() + Vector3(cos(_angle), 0.0, sin(_angle)) * _radius()
			var step := goal - global_position
			global_position = global_position.move_toward(goal, fly_speed * pace * delta)
			_face(step if step.length() > 0.05 else Vector3(-sin(_angle), 0.0, cos(_angle)))
		State.AIM:
			if player and not _aim_locked:
				aim_mark.global_position = _clamp_to_arena(player.global_position) + Vector3.UP * 0.03
			var over := aim_mark.global_position - (aim_mark.global_position - global_position).normalized() * 3.0
			global_position = global_position.move_toward(Vector3(over.x, global_position.y, over.z), fly_speed * 0.5 * delta)
			_face(aim_mark.global_position - global_position)
		State.GUST:
			if player:
				_face(player.global_position - global_position)
				var away := (player.global_position - global_position) * Vector3(1, 0, 1)
				if away.length() < 10.0 and not away.is_zero_approx():
					player.move_and_collide(away.normalized() * _push * delta)
		State.VOLLEY, State.PERCH:
			if player:
				_face(player.global_position - global_position)


func _run() -> void:
	var turn := _turn
	while not is_dead and turn == _turn:
		if apu and not _suns_on and _enraged():
			await _wake_suns()
			if turn != _turn:
				return
		await _circle()
		if turn != _turn:
			return
		if may_attack.is_valid() and not may_attack.call(self):
			continue
		match _next_attack():
			&"dive":
				await _dive()
			&"gust":
				await _gust(gust_push)
			&"volley":
				await _volley()
			&"perch":
				await _perch()
		if turn != _turn:
			return
		_attacks += 1
		attack_finished.emit()


func _enraged() -> bool:
	return health.current <= health.max_health / 2


func _next_attack() -> StringName:
	if not apu:
		return &"gust" if _attacks % 3 == 2 else &"dive"
	if _suns_on and _attacks % 3 == 2:
		return &"perch"
	return &"volley" if _attacks % 2 == 0 else &"dive"


func _circle() -> void:
	state = State.CIRCLE
	var from := global_position - _center()
	_angle = atan2(from.z, from.x)
	_wings(&"glide", 0.3)
	_tween_to(body, ^"position:y", hover_height, 0.5).set_trans(Tween.TRANS_SINE)
	await _wait(circle_time)


func _dive() -> void:
	state = State.AIM
	_aim_locked = false
	var player := Players.nearest(global_position)
	aim_mark.global_position = _clamp_to_arena(player.global_position if player else global_position) + Vector3.UP * 0.03
	aim_mark.show()
	_clip(&"aim", true, aim_time + lock_time)
	_wings(&"aim", 0.3)
	await _wait(aim_time)
	if state != State.AIM:
		return
	_aim_locked = true
	flash.warn(lock_time)
	Feel.sfx(&"click", body.global_position)
	await _wait(lock_time)
	if state != State.AIM:
		return
	state = State.DIVE
	_wings(&"tuck", 0.1)
	var target := Vector3(aim_mark.global_position.x, global_position.y, aim_mark.global_position.z)
	_tween_to(self, ^"global_position", target, dive_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween_to(body, ^"position:y", 0.5, dive_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _wait(dive_time)
	aim_mark.hide()
	if state != State.DIVE:
		return
	impact.activate()
	_after(0.15, impact.deactivate)
	Feel.burst(&"dust", global_position + Vector3.UP * 0.1, Vector3.UP)
	Feel.sfx(&"boom", global_position)
	Feel.shake(0.4)
	if apu:
		await _wait(0.8)
		return
	state = State.STUCK
	_wings(&"stuck", 0.2)
	body.rotation.x = 0.5
	await _wait(stuck_time, false)
	if state != State.STUCK:
		return
	body.rotation.x = 0.0
	Feel.burst(&"dust", global_position + Vector3.UP * 0.3, Vector3.UP)


func _gust(push: float) -> void:
	var player := Players.nearest(global_position)
	if state != State.PERCH:
		state = State.GUST
		_push = 0.0
		var toward := (global_position - (player.global_position if player else _center())) * Vector3(1, 0, 1)
		toward = Vector3.BACK if toward.is_zero_approx() else toward.normalized()
		var spot := _clamp_to_arena((player.global_position if player else _center()) + toward * 5.0)
		spot.y = global_position.y
		_tween_to(self, ^"global_position", spot, 0.6).set_trans(Tween.TRANS_SINE)
		_tween_to(body, ^"position:y", 0.6, 0.6).set_trans(Tween.TRANS_SINE)
		await _wait(0.6)
		if state != State.GUST:
			return
	state = State.GUST
	_push = push * pace
	_wings(&"gust", 0.1)
	Feel.sfx(&"roll", body.global_position)
	var puffs := int(gust_time / 0.3)
	for i in puffs:
		if state != State.GUST:
			return
		var front := global_position + Vector3.UP * 0.4 + body.global_basis.z * 1.2
		Feel.burst(&"dust", front, body.global_basis.z)
		await _wait(0.3)
	_push = 0.0


func _volley() -> void:
	state = State.VOLLEY
	_tween_to(body, ^"position:y", 1.4, 0.5).set_trans(Tween.TRANS_SINE)
	_wings(&"volley", 0.3)
	flash.warn(0.6)
	await _wait(0.6)
	if state != State.VOLLEY:
		return
	var player := Players.nearest(global_position)
	var from := Vector3(muzzle.global_position.x, global_position.y + 1.1, muzzle.global_position.z)
	var aim := ((player.global_position + Vector3.UP * 1.1) if player else from + body.global_basis.z) - from
	aim.y = 0.0
	aim = Vector3.FORWARD if aim.is_zero_approx() else aim.normalized()
	for i in volley_count:
		var turn := (i - (volley_count - 1) / 2.0) * volley_spread
		var info := DamageInfo.make(feather_damage, config.attack_knockback, self)
		info.team = config.team
		info.reflectable = true
		var feather := Projectile.fire(FEATHER, self, from, aim.rotated(Vector3.UP, turn) * feather_speed, info)
		feather.tint(FEATHER_COLOR)
	Feel.sfx(&"click", from)
	await _wait(0.5)


func _perch() -> void:
	state = State.PERCH
	var spot := _center()
	spot.y = global_position.y
	_tween_to(self, ^"global_position", spot, 0.8).set_trans(Tween.TRANS_SINE)
	_tween_to(body, ^"position:y", 0.3, 0.8).set_trans(Tween.TRANS_SINE)
	await _wait(0.8)
	if state != State.PERCH:
		return
	_catch_light(true)
	_wings(&"perch", 0.4)
	flash.warn(perch_time)
	Feel.sfx(&"rumble", body.global_position)
	await _wait(perch_time)
	if state != State.PERCH:
		return
	_catch_light(false)
	await _gust(gust_push * 1.8)


func _wake_suns() -> void:
	state = State.CIRCLE
	roar()
	Feel.shake(0.5)
	_set_suns(true)
	await _wait(1.0)


func _set_suns(on: bool) -> void:
	_suns_on = on
	for sun in suns:
		var beam := sun.get_node(^"Beam") as Node3D
		beam.visible = on
		beam.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _on_lit() -> void:
	if state == State.PERCH:
		Feel.burst(&"sparkle", body.global_position + Vector3.UP, Vector3.UP)
		_knock_down()


func _knock_down() -> void:
	_interrupt()
	state = State.DOWN
	Feel.sfx(&"hit", body.global_position)
	Feel.shake(0.3)
	_wings(&"down", 0.2)
	_tween_to(body, ^"position:y", 0.4, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
	body.rotation.z = 0.4
	var turn := _turn
	await _wait(0.35, false)
	if turn != _turn:
		return
	Feel.burst(&"dust", global_position + Vector3.UP * 0.1, Vector3.UP)
	await _wait(down_time, false)
	if turn != _turn:
		return
	body.rotation.z = 0.0
	_tween_to(body, ^"position:y", hover_height, 0.6).set_ease(Tween.EASE_OUT)
	await _wait(0.6, false)
	if turn == _turn:
		_run()


func _on_interrupt() -> void:
	aim_mark.hide()
	_push = 0.0
	_catch_light(false)
	impact.deactivate()
	body.rotation = Vector3(0.0, body.rotation.y, 0.0)


func is_vulnerable() -> bool:
	return state in [State.STUCK, State.DOWN]


func _is_idle() -> bool:
	return state == State.IDLE


func _react_to(info: DamageInfo) -> bool:
	var projectile := info.source as Projectile
	if projectile and not is_vulnerable():
		var reflected := projectile.shooter == self
		if (apu and reflected) or (not apu and state == State.GUST):
			_knock_down()
			return true
	return false


func _die() -> void:
	_interrupt()
	state = State.DEAD
	Log.info(&"combat", name, "murió")
	remove_from_group(Targeting.GROUP)
	hurtbox.set_deferred(&"monitorable", false)
	_set_suns(false)
	Feel.burst(&"shards", body.global_position, Vector3.UP)
	Feel.sfx(&"break", body.global_position)
	Feel.shake(0.5)
	wings.pause()
	create_tween().tween_property(body, ^"position:y", 0.3, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_clip(&"die", false)
	defeated.emit(self)


## Cruza las alas a la pose `pose` (un clip de %Wings) en `seconds`; el aleteo se acelera con la pelea.
func _wings(pose: StringName, seconds: float) -> void:
	wings.speed_scale = pace
	wings.play(pose, seconds)


func _catch_light(on: bool) -> void:
	light_catch.collision_layer = 1 if on else 0


func _face(direction: Vector3) -> void:
	direction.y = 0.0
	if direction.length() > 0.01:
		body.rotation.y = atan2(direction.x, direction.z)


func _center() -> Vector3:
	return Vector3(arena.get_center().x, global_position.y, arena.get_center().y)


func _radius() -> float:
	return maxf(minf(arena.size.x, arena.size.y) / 2.0 - 0.5, 1.5)
