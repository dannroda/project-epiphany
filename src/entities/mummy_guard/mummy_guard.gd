class_name MummyGuard
extends Node3D
## Momia guardiana de la Chullpa (D1): se acerca a saltitos y después salta alto sobre el player (su sombra lo sigue
## y se fija antes de caer). Al caer golpea donde cae y manda una onda por el piso que lastima a quien esté parado en
## ella: el sub-jefe la tiene corta (se esquiva alejándose); el jefe, que llena la sala, se salta con la pluma.
## Después de caer queda trabada: ahí le pega todo (espada, bomba, vasija). Fuera de eso, todo rebota.

signal defeated(mummy: MummyGuard)
signal health_changed
## Terminó (o se cortó) su ataque: otro puede atacar.
signal attack_finished

enum State { IDLE, HOP, AIM, FALL, STUCK, DEAD }

@export var config: EntityConfig
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
@export var stuck_time := 2.6
@export var aim_size := 1.0
## Saltos seguidos (sin trabarse entre uno y otro) con la mitad de la vida o menos.
@export var rage_leaps := 1

@onready var body: Node3D = %Body
@onready var roar_fx: Roar = %Roar
@onready var aim_mark: MeshInstance3D = %AimMark
@onready var waves: Array[MeshInstance3D] = [%Wave, %Wave2]
@onready var impact: Hitbox = %Impact
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var health: Health = $Health

var state := State.IDLE
## La sala menos el borde, en XZ; la pone ArenaFight.
var arena := Rect2()
var pace := 1.0
var may_attack: Callable
var peers: Array = []
var _turn := 0
var _tweens: Array[Tween] = []
var _home := Vector3.ZERO
var _aim_locked := false
var _rings: Array[Dictionary] = []

var is_dead: bool:
	get:
		return health.current <= 0


func _ready() -> void:
	health.max_health = config.max_health
	health.current = config.max_health
	hurtbox.team = config.team
	hurtbox.hit.connect(_on_hit)
	health.died.connect(_die)
	impact.team = config.team
	impact.monitoring = false
	impact.damage_factory = func() -> DamageInfo: return DamageInfo.make(impact_damage, config.attack_knockback * 1.5, impact, &"blast")
	_home = global_position
	aim_mark.hide()
	_stop_waves()


func start() -> void:
	if state != State.IDLE or is_dead:
		return
	add_to_group(Enemy.GROUP)
	config.apply_to(self)
	_run()


## Presentación: mira al player, se echa para atrás, se hincha y grita.
func roar() -> void:
	var player := Players.nearest(global_position)
	if player:
		var look := Vector3(player.global_position.x, body.global_position.y, player.global_position.z)
		if not look.is_equal_approx(body.global_position):
			body.look_at(look, Vector3.UP, true)
	var rest := body.scale
	var tween := body.create_tween()
	tween.tween_property(body, ^"scale", rest * Vector3(1.12, 1.08, 1.12), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(body, ^"rotation:x", -0.18, 0.18)
	tween.tween_interval(roar_fx.duration)
	tween.tween_property(body, ^"scale", rest, 0.3)
	tween.parallel().tween_property(body, ^"rotation:x", 0.0, 0.3)
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
	if not _rings.is_empty():
		_spread_waves(delta)



func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds / pace, false).timeout


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
	var arc := _new_tween()
	arc.tween_property(body, ^"position:y", 0.8, hop_time / pace / 2.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	arc.tween_property(body, ^"position:y", 0.0, hop_time / pace / 2.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await _wait(hop_time)
	Feel.burst(&"dust", global_position + Vector3.UP * 0.1, Vector3.UP)
	await _wait(0.25)


func _leap(last := true) -> void:
	state = State.AIM
	_aim_locked = false
	Feel.sfx(&"roll", global_position)
	_tween_to(body, ^"position:y", leap_height, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	var player := Players.nearest(global_position)
	aim_mark.global_position = _clamp_to_arena(player.global_position if player else global_position) + Vector3.UP * 0.03
	aim_mark.scale = Vector3.ONE * 0.4 * aim_size
	aim_mark.show()
	_tween_to(aim_mark, ^"scale", Vector3.ONE * aim_size, aim_time)
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
	_tween_to(body, ^"position:y", 0.0, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await _wait(0.18)
	if state != State.FALL:
		return
	aim_mark.hide()
	impact.active_attack = null
	impact.monitoring = true
	get_tree().create_timer(0.15, false).timeout.connect(func() -> void: impact.monitoring = false)
	Feel.burst(&"dust", global_position + Vector3.UP * 0.1, Vector3.UP)
	Feel.sfx(&"boom", global_position)
	Feel.shake(0.45)
	_start_wave()
	if not last:
		await _wait(0.35)
		return
	state = State.STUCK
	body.position.y = -0.35
	var wobble := _new_tween().set_loops(maxi(int(stuck_time / 0.3), 1))
	wobble.tween_property(body, ^"rotation:z", 0.2, 0.15)
	wobble.tween_property(body, ^"rotation:z", -0.2, 0.15)
	await get_tree().create_timer(stuck_time, false).timeout
	if state != State.STUCK:
		return
	wobble.kill()
	body.rotation.z = 0.0
	Feel.burst(&"dust", global_position + Vector3.UP * 0.3, Vector3.UP)
	_tween_to(body, ^"position:y", 0.0, 0.4).set_ease(Tween.EASE_OUT)
	await _wait(0.5)


func _start_wave() -> void:
	var free := waves.filter(func(mesh: MeshInstance3D) -> bool: return not mesh.visible)
	var mesh: MeshInstance3D = waves[0] if free.is_empty() else free[0]
	_rings = _rings.filter(func(ring: Dictionary) -> bool: return ring.mesh != mesh)
	_rings.append({mesh = mesh, at = 0.0, center = global_position, hit = []})
	mesh.global_position = global_position + Vector3.UP * 0.05
	mesh.scale = Vector3.ONE * 0.01
	mesh.set_instance_shader_parameter(&"width", wave_width)
	mesh.show()


func _spread_waves(delta: float) -> void:
	for ring in _rings.duplicate():
		ring.at += wave_speed * pace * delta
		if ring.at > wave_radius:
			ring.mesh.hide()
			_rings.erase(ring)
			continue
		ring.mesh.scale = Vector3(ring.at, 1.0, ring.at)
		ring.mesh.set_instance_shader_parameter(&"radius", ring.at)
		ring.mesh.set_instance_shader_parameter(&"fade", 1.0 - ring.at / wave_radius)
		for player in Players.alive():
			if ring.hit.has(player) or not player.is_on_floor():
				continue
			var away: Vector3 = (player.global_position - ring.center) * Vector3(1, 0, 1)
			if absf(away.length() - ring.at) > wave_width / 2.0:
				continue
			ring.hit.append(player)
			var info := DamageInfo.make(wave_damage, config.attack_knockback, self, &"blast")
			info.team = config.team
			player.hurtbox.receive(info)


func _stop_waves() -> void:
	_rings.clear()
	for mesh in waves:
		mesh.hide()


func _interrupt() -> void:
	_turn += 1
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	_stop_waves()
	aim_mark.hide()
	impact.set_deferred(&"monitoring", false)
	body.rotation.z = 0.0
	attack_finished.emit()


func is_vulnerable() -> bool:
	return state == State.STUCK


func _on_hit(info: DamageInfo) -> void:
	if is_dead or state == State.IDLE:
		return
	if not is_vulnerable():
		hurtbox.surface = "stone"
		Feel.burst(&"sparks", body.global_position + Vector3.UP, Vector3.UP)
		Feel.sfx(&"block", body.global_position)
		return
	hurtbox.surface = "flesh"
	if health.damage(info.amount):
		Log.info(&"combat", name, "recibió", info.amount, "de daño. Vida:", health.current)
		health_changed.emit()


func _die() -> void:
	_interrupt()
	state = State.DEAD
	Log.info(&"combat", name, "murió")
	remove_from_group(&"targetable")
	hurtbox.set_deferred(&"monitorable", false)
	Feel.burst(&"dust", global_position + Vector3.UP, Vector3.UP)
	Feel.sfx(&"break", global_position)
	Feel.shake(0.6)
	var tween := create_tween()
	tween.tween_property(body, ^"scale", Vector3(1.2, 0.05, 1.2), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(body.hide)
	defeated.emit(self)


func _clamp_to_arena(point: Vector3) -> Vector3:
	return Vector3(clampf(point.x, arena.position.x, arena.end.x), global_position.y, clampf(point.z, arena.position.y, arena.end.y))


func _new_tween() -> Tween:
	_tweens = _tweens.filter(func(tween: Tween) -> bool: return tween.is_valid())
	var tween := create_tween()
	_tweens.append(tween)
	return tween


func _tween_to(target: Object, property: NodePath, value: Variant, seconds: float) -> PropertyTweener:
	return _new_tween().tween_property(target, property, value, seconds / pace)
