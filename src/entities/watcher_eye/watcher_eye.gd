class_name WatcherEye
extends Node3D
## Ojo vigía de la Queñoa (D1): flota por la sala, se abre, carga y barre el piso con un rayo (antes marca la línea).
## Con `lunges` (sub-jefe) después del barrido se tira sobre el player y queda enganchado en las raíces: ahí le pega
## todo (espada, bomba, vasija). Sin `lunges` (jefe) una flecha con el ojo abierto lo derriba y en el piso le pega la
## espada. Flotando y sin derribar, todo rebota.

signal defeated(eye: WatcherEye)
signal health_changed
## Terminó (o se cortó) su ataque: otro ojo puede atacar.
signal attack_finished

enum State { IDLE, DRIFT, CHARGE, SWEEP, LUNGE, STUCK, DOWN, DEAD }

## Cuánto giran los párpados (en X, el de arriba hacia atrás y el de abajo hacia adelante) para abrir del todo.
const LID_OPEN := 1.4
## Lo que tardan los párpados en abrirse o cerrarse de golpe (al clavarse, al caer y al levantarse).
const LID_SNAP := 0.15

@export var config: EntityConfig
@export var lunges := false
@export var hover_height := 3.0
@export var drift_speed := 3.5
@export var rest_time := 1.0
@export var charge_time := 1.0
@export var sweep_length := 12.0
@export var sweep_time := 1.4
@export var beam_damage := 2
@export var lunge_aim_time := 0.7
@export var lunge_damage := 4
@export var stuck_time := 3.0
@export var down_time := 3.5

@onready var body: Node3D = %Body
@onready var lid_top: Node3D = %LidTop
@onready var lid_bottom: Node3D = %LidBottom
@onready var iris: MeshInstance3D = %Iris
@onready var glow: OmniLight3D = %Glow
@onready var beam: MeshInstance3D = %Beam
@onready var spot: Hitbox = %Spot
@onready var path_mark: MeshInstance3D = %PathMark
@onready var aim_mark: MeshInstance3D = %AimMark
@onready var impact: Hitbox = %Impact
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health: Health = $Health

var state := State.IDLE
## La sala menos el borde, en XZ; la pone ArenaFight.
var arena := Rect2()
## Más de 1: todo más rápido (el que queda cuando cae el otro).
var pace := 1.0
## () -> bool: si puede atacar ahora (ArenaFight no deja que dos barran a la vez).
var may_attack: Callable
## Los otros ojos de la pelea: no se amontona con ellos.
var peers: Array = []
var _turn := 0
var _open := 0.0
var _tweens: Array[Tween] = []
var _sweep_from := Vector3.ZERO
var _sweep_to := Vector3.ZERO
var _home := Vector3.ZERO

var is_dead: bool:
	get:
		return health.current <= 0


func _ready() -> void:
	health.max_health = config.max_health
	health.current = config.max_health
	hurtbox.team = config.team
	hurtbox.hit.connect(_on_hit)
	health.died.connect(_die)
	for hitbox: Hitbox in [spot, impact]:
		hitbox.team = config.team
		hitbox.monitoring = false
	spot.damage_factory = func() -> DamageInfo: return DamageInfo.make(beam_damage, config.attack_knockback, spot, &"blast")
	impact.damage_factory = func() -> DamageInfo: return DamageInfo.make(lunge_damage, config.attack_knockback * 1.5, impact, &"blast")
	body.position.y = hover_height
	_home = global_position
	_show_beam(false)
	path_mark.hide()
	aim_mark.hide()
	_set_open(0.0)


func start() -> void:
	if state != State.IDLE or is_dead:
		return
	add_to_group(Enemy.GROUP)
	config.apply_to(self)
	_run()


## Vuelve a como estaba al llegar el player (la pelea se reinicia).
func reset() -> void:
	_interrupt()
	state = State.IDLE
	pace = 1.0
	remove_from_group(Enemy.GROUP)
	health.reset(config.max_health)
	hurtbox.set_deferred(&"monitorable", true)
	global_position = _home
	body.position.y = hover_height
	body.rotation = Vector3.ZERO
	body.scale = Vector3.ONE
	body.show()
	_set_open(0.0)


func _physics_process(_delta: float) -> void:
	if state in [State.IDLE, State.DEAD]:
		return
	var player := Players.nearest(global_position)
	if player and state not in [State.STUCK, State.DOWN]:
		var look := player.global_position + Vector3.UP * 0.5
		if state == State.SWEEP:
			look = spot.global_position
		if not body.global_position.is_equal_approx(look):
			body.look_at(look, Vector3.UP, true)
	if state == State.SWEEP:
		_place_beam()


func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds / pace, false).timeout


func _run() -> void:
	var turn := _turn
	while not is_dead and turn == _turn:
		state = State.DRIFT
		var point := _drift_point()
		var time := maxf(global_position.distance_to(point) / drift_speed, 0.4)
		_tween_to(self, ^"global_position", point, time).set_trans(Tween.TRANS_SINE)
		await _wait(time + rest_time)
		if turn != _turn:
			return
		if may_attack.is_valid() and not may_attack.call(self):
			await _wait(0.4)
			continue
		await _charge()
		if turn != _turn:
			return
		await _sweep()
		if turn != _turn:
			return
		if lunges:
			await _lunge()
			if turn != _turn:
				return
		attack_finished.emit()


func _drift_point() -> Vector3:
	var player := Players.nearest(global_position)
	var best := global_position
	var best_score := -INF
	for i in 8:
		var candidate := Vector3(randf_range(arena.position.x, arena.end.x), global_position.y, randf_range(arena.position.y, arena.end.y))
		var score := candidate.distance_to(global_position) * 0.2
		if player:
			score -= absf(candidate.distance_to(player.global_position) - 6.0)
		for peer in peers:
			if peer != self and not peer.is_dead and candidate.distance_to(peer.global_position) < 6.0:
				score -= 10.0
		if score > best_score:
			best_score = score
			best = candidate
	return best


func _charge() -> void:
	state = State.CHARGE
	var player := Players.nearest(global_position)
	var center := player.global_position if player else global_position
	var across := (center - global_position) * Vector3(1, 0, 1)
	across = Vector3.RIGHT if across.is_zero_approx() else across.normalized().cross(Vector3.UP)
	if randf() < 0.5:
		across = -across
	_sweep_from = _clamp_to_arena(center - across * sweep_length / 2.0)
	_sweep_to = _clamp_to_arena(center + across * sweep_length / 2.0)
	var mid := (_sweep_from + _sweep_to) / 2.0
	path_mark.global_position = Vector3(mid.x, global_position.y + 0.03, mid.z)
	path_mark.global_basis = Basis.looking_at(_sweep_to - _sweep_from, Vector3.UP) if not _sweep_to.is_equal_approx(_sweep_from) else Basis()
	path_mark.scale = Vector3(1, 1, _sweep_from.distance_to(_sweep_to))
	path_mark.show()
	Feel.sfx(&"click", body.global_position)
	_lids(1.0, charge_time * 0.4)
	await _wait(charge_time)


func _sweep() -> void:
	state = State.SWEEP
	spot.global_position = _sweep_from
	spot.active_attack = null
	spot.monitoring = true
	_show_beam(true)
	Feel.sfx(&"reflect", body.global_position)
	_tween_to(spot, ^"global_position", _sweep_to, sweep_time / pace)
	await _wait(sweep_time)
	_end_sweep()
	_lids(0.0, 0.3)


func _end_sweep() -> void:
	spot.set_deferred(&"monitoring", false)
	_show_beam(false)
	path_mark.hide()


func _lunge() -> void:
	state = State.LUNGE
	var player := Players.nearest(global_position)
	var target := _clamp_to_arena(player.global_position if player else global_position)
	target.y = global_position.y
	aim_mark.global_position = target + Vector3.UP * 0.03
	aim_mark.scale = Vector3.ONE * 0.3
	aim_mark.show()
	_tween_to(aim_mark, ^"scale", Vector3.ONE, lunge_aim_time)
	_tween_to(body, ^"position:y", hover_height + 0.8, lunge_aim_time * 0.8).set_ease(Tween.EASE_OUT)
	await _wait(lunge_aim_time)
	if state != State.LUNGE:
		return
	global_position = target
	_tween_to(body, ^"position:y", 0.7, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await _wait(0.18)
	aim_mark.hide()
	if state != State.LUNGE:
		return
	impact.active_attack = null
	impact.monitoring = true
	Feel.burst(&"dust", global_position + Vector3.UP * 0.1, Vector3.UP)
	Feel.sfx(&"boom", global_position)
	Feel.shake(0.4)
	get_tree().create_timer(0.15, false).timeout.connect(func() -> void: impact.monitoring = false)
	state = State.STUCK
	_lids(1.0, LID_SNAP)
	var wobble := _new_tween().set_loops(int(stuck_time / 0.3))
	wobble.tween_property(body, ^"rotation:z", 0.25, 0.15)
	wobble.tween_property(body, ^"rotation:z", -0.25, 0.15)
	await get_tree().create_timer(stuck_time, false).timeout
	if state != State.STUCK:
		return
	wobble.kill()
	body.rotation.z = 0.0
	Feel.burst(&"leaves", global_position + Vector3.UP * 0.3, Vector3.UP)
	_lids(0.0, 0.3)
	_tween_to(body, ^"position:y", hover_height, 0.6).set_ease(Tween.EASE_OUT)
	await _wait(0.6)


func _knock_down() -> void:
	_interrupt()
	state = State.DOWN
	Feel.sfx(&"hit", body.global_position)
	Feel.shake(0.3)
	_lids(0.6, LID_SNAP)
	_tween_to(body, ^"position:y", 0.8, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
	var turn := _turn
	await get_tree().create_timer(0.35, false).timeout
	if turn != _turn:
		return
	Feel.burst(&"dust", global_position + Vector3.UP * 0.1, Vector3.UP)
	await get_tree().create_timer(down_time, false).timeout
	if turn != _turn:
		return
	_lids(0.0, 0.3)
	_tween_to(body, ^"position:y", hover_height, 0.6).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.6, false).timeout
	if turn == _turn:
		_run()


func _interrupt() -> void:
	_turn += 1
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	_end_sweep()
	aim_mark.hide()
	impact.set_deferred(&"monitoring", false)
	body.rotation.z = 0.0
	attack_finished.emit()


func is_vulnerable() -> bool:
	return state in [State.STUCK, State.DOWN]


func _on_hit(info: DamageInfo) -> void:
	if is_dead or state == State.IDLE:
		return
	if not lunges and info.source is Projectile and state in [State.CHARGE, State.SWEEP]:
		_knock_down()
		return
	if not is_vulnerable():
		hurtbox.surface = "stone"
		Feel.burst(&"sparks", body.global_position, Vector3.UP)
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
	Feel.burst(&"shards", body.global_position, Vector3.UP)
	Feel.sfx(&"break", body.global_position)
	Feel.shake(0.5)
	var tween := create_tween()
	tween.tween_property(body, ^"scale", Vector3(1.3, 0.1, 1.3), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(body.hide)
	defeated.emit(self)


func _lids(to: float, seconds: float) -> void:
	_tween_method(_set_open, _open, to, seconds)


func _set_open(amount: float) -> void:
	_open = amount
	lid_top.rotation.x = -LID_OPEN * amount
	lid_bottom.rotation.x = LID_OPEN * amount
	iris.visible = amount > 0.01
	glow.light_energy = amount * 2.5


func _show_beam(on: bool) -> void:
	beam.visible = on
	spot.visible = on


func _place_beam() -> void:
	var from := body.global_position
	var to := spot.global_position
	var along := to - from
	if along.length() < 0.01:
		return
	var up := along.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	beam.global_transform = Transform3D(Basis(side, up * along.length(), side.cross(up)), (from + to) / 2.0)


func _clamp_to_arena(point: Vector3) -> Vector3:
	return Vector3(clampf(point.x, arena.position.x, arena.end.x), global_position.y, clampf(point.z, arena.position.y, arena.end.y))


func _new_tween() -> Tween:
	_tweens = _tweens.filter(func(tween: Tween) -> bool: return tween.is_valid())
	var tween := create_tween()
	_tweens.append(tween)
	return tween


func _tween_to(target: Object, property: NodePath, value: Variant, seconds: float) -> PropertyTweener:
	return _new_tween().tween_property(target, property, value, seconds / pace)


func _tween_method(method: Callable, from: float, to: float, seconds: float) -> void:
	_new_tween().tween_method(method, from, to, seconds / pace)
