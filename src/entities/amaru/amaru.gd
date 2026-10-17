class_name Amaru
extends ArenaFighter
## Amaru, la serpiente joven del Santuario de Totora (sub-jefe de D3). Asoma por uno de sus charcos, mira al player y
## marca una línea en el piso; se lanza recta por ella y cae sobre la totora, donde queda tirada y expuesta: ahí le
## pega todo (espada, bomba, vasija). Después vuelve reptando al charco más cercano y se hunde. Asomada, todo rebota.
## Con la mitad de la vida o menos, escupe antes de lanzarse.

enum State { IDLE, UNDER, RISE, AIM, LUNGE, STUCK, RETURN, DEAD }

const ORB := preload("res://src/entities/projectile.tscn")

## Los charcos por donde asoma (en la sala).
@export var pools: Array[Node3D] = []
@export var under_time := 0.8
@export var rise_time := 0.5
@export var aim_time := 1.0
@export var lunge_speed := 13.0
@export var lunge_reach := 11.0
@export var lunge_damage := 2
@export var stuck_time := 2.2
@export var crawl_speed := 3.5
@export var spit_speed := 9.0
@export var spit_damage := 1
## Alto del cuerpo asomado (la cabeza).
@export var rise_height := 1.8
## Dónde queda el cuello tirado en el piso, para que la cabeza caiga donde está ella.
@export var flat_offset := Vector3(0, 0.4, 1.0)

@onready var neck: Node3D = %Neck
@onready var head: Node3D = %Head
@onready var _head_rest := head.position
@onready var jaw: Node3D = %Jaw
@onready var roar_fx: Roar = %Roar
@onready var aim_line: MeshInstance3D = %AimLine
@onready var impact: Hitbox = %Impact

var state := State.IDLE
var _pool: Node3D

## 0 asomada, 1 hundida bajo el charco (rise_height + 0.5 abajo); lo animan los clips dive y rise.
var submerge := 0.0:
	set(value):
		submerge = value
		if body:
			body.position.y = -(rise_height + 0.5) * value


func _ready() -> void:
	super()
	impact.team = config.team
	impact.monitoring = false
	impact.damage_factory = func() -> DamageInfo: return DamageInfo.make(lunge_damage, config.attack_knockback, impact)
	_pool = _nearest_pool(global_position)
	aim_line.hide()
	_pose_risen()


func reset() -> void:
	_interrupt()
	state = State.IDLE
	pace = 1.0
	remove_from_group(Enemy.GROUP)
	health.reset(config.max_health)
	hurtbox.set_deferred(&"monitorable", true)
	global_position = _home
	_pool = _nearest_pool(global_position)
	body.show()
	body.scale = Vector3.ONE
	submerge = 0.0
	_pose_risen()


## Al empezar la pelea: mira al player, levanta la cabeza, abre la boca y grita. Corre durante la pausa del
## acercamiento de la cámara, que deja andar solo a `body`.
func roar() -> void:
	var player := Players.nearest(global_position)
	if player:
		_face(player.global_position - global_position)
	_clip(&"roar", false)
	roar_fx.play()


func is_vulnerable() -> bool:
	return state == State.STUCK


func raging() -> bool:
	return health.current * 2 <= health.max_health


func _physics_process(_delta: float) -> void:
	hurtbox.global_transform = Transform3D(neck.global_basis.orthonormalized(), neck.global_position)
	if state == State.RISE:
		var player := Players.nearest(global_position)
		if player:
			_face(player.global_position - global_position)


func _run() -> void:
	var turn := _turn
	while not is_dead and turn == _turn:
		await _dive()
		if turn != _turn:
			return
		if may_attack.is_valid() and not may_attack.call(self):
			await _wait(0.4)
			continue
		await _rise()
		if turn != _turn:
			return
		if raging():
			_spit()
			await _wait(0.5)
			if turn != _turn:
				return
		await _aim()
		if turn != _turn:
			return
		await _lunge()
		if turn != _turn:
			return
		await _lie()
		if turn != _turn:
			return
		await _crawl_back()
		attack_finished.emit()


## Se hunde y asoma en otro charco.
func _dive() -> void:
	state = State.UNDER
	Feel.burst(&"splash", global_position + Vector3.UP * 0.1, Vector3.UP)
	Feel.sfx(&"splash", global_position)
	_clip(&"dive")
	await _wait(under_time)
	var others := pools.filter(func(pool: Node3D) -> bool: return pool != _pool)
	if not others.is_empty():
		_pool = others.pick_random()
	global_position = Vector3(_pool.global_position.x, global_position.y, _pool.global_position.z)


func _rise() -> void:
	state = State.RISE
	_pose_risen()
	submerge = 1.0
	Feel.burst(&"splash", global_position + Vector3.UP * 0.1, Vector3.UP)
	Feel.sfx(&"splash", global_position)
	_clip(&"rise", true, rise_time)
	await _wait(rise_time + 0.3)


func _spit() -> void:
	var player := Players.nearest(global_position)
	if player == null:
		return
	var mouth := global_position + Vector3.UP * rise_height
	var info := DamageInfo.make(spit_damage, config.attack_knockback * 0.5, self)
	info.team = config.team
	info.reflectable = true
	Projectile.fire(ORB, self, mouth, (player.global_position + Vector3.UP - mouth).normalized() * spit_speed, info)
	Feel.sfx(&"roll", mouth)


func _aim() -> void:
	state = State.AIM
	_draw_line()
	aim_line.show()
	Feel.sfx(&"click", global_position)
	await _wait(aim_time)
	aim_line.hide()


## Recta hacia donde miraba, hasta el borde de la sala o `lunge_reach`.
func _lunge() -> void:
	state = State.LUNGE
	var direction := _facing()
	var target := _line_end(direction)
	_pose_flat()
	impact.activate()
	Feel.sfx(&"roll", global_position)
	var seconds := global_position.distance_to(target) / lunge_speed
	_tween_to(self, ^"global_position", target, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _wait(seconds)
	impact.deactivate()
	Feel.burst(&"dust", global_position + Vector3.UP * 0.1, Vector3.UP)
	Feel.sfx(&"boom", global_position)
	Feel.shake(0.25)


func _lie() -> void:
	state = State.STUCK
	_clip(&"stuck", false)
	await _wait(stuck_time, false)
	if state != State.STUCK:
		return
	moves.stop(true)
	body.rotation.z = 0.0


func _crawl_back() -> void:
	state = State.RETURN
	_pool = _nearest_pool(global_position)
	var target := Vector3(_pool.global_position.x, global_position.y, _pool.global_position.z)
	_face(target - global_position)
	var seconds := global_position.distance_to(target) / crawl_speed
	_tween_to(self, ^"global_position", target, seconds)
	await _wait(seconds)


func _line_end(direction: Vector3) -> Vector3:
	var reach := lunge_reach
	for axis in [0, 2]:
		var d: float = direction[axis]
		if absf(d) < 0.001:
			continue
		var low: float = arena.position.x if axis == 0 else arena.position.y
		var high: float = arena.end.x if axis == 0 else arena.end.y
		var limit := ((high if d > 0.0 else low) - global_position[axis]) / d
		reach = minf(reach, maxf(limit, 0.0))
	return global_position + direction * reach


func _draw_line() -> void:
	var direction := _facing()
	var end := _line_end(direction)
	var length := global_position.distance_to(end)
	aim_line.global_transform = Transform3D(Basis.looking_at(direction) * Basis.from_scale(Vector3(1, 1, maxf(length, 0.1))), (global_position + end) * 0.5 + Vector3.UP * 0.03)


func _facing() -> Vector3:
	var forward := -body.global_basis.z * Vector3(1, 0, 1)
	return forward.normalized() if not forward.is_zero_approx() else Vector3.FORWARD


func _face(direction: Vector3) -> void:
	direction.y = 0.0
	if direction.length() > 0.01:
		body.global_basis = Basis.looking_at(direction.normalized()) * Basis.from_scale(body.scale)


## Asomada: el cuello parado sobre el charco. Mira al player hasta marcar la línea; después ya no corrige.
func _pose_risen() -> void:
	neck.rotation.x = 0.0
	neck.position = Vector3(0, rise_height / 2.0, 0)
	head.rotation.x = 0.0
	head.position = _head_rest


## Tirada: el cuerpo largo sobre el piso, hacia adelante.
func _pose_flat() -> void:
	neck.rotation.x = -PI / 2.0
	neck.position = flat_offset
	head.rotation.x = PI / 2.0
	head.position = _head_rest * Vector3(1, 1, -1)
	submerge = 0.0


func _nearest_pool(from: Vector3) -> Node3D:
	var best: Node3D = null
	for pool in pools:
		if best == null or from.distance_squared_to(pool.global_position) < from.distance_squared_to(best.global_position):
			best = pool
	return best


func _on_interrupt() -> void:
	aim_line.hide()
	impact.deactivate()
	body.rotation.z = 0.0


func _is_idle() -> bool:
	return state == State.IDLE


func _spark_point() -> Vector3:
	return body.global_position + Vector3.UP


func _die() -> void:
	_interrupt()
	state = State.DEAD
	Log.info(&"combat", name, "murió")
	remove_from_group(Targeting.GROUP)
	hurtbox.set_deferred(&"monitorable", false)
	Feel.burst(&"splash", global_position + Vector3.UP, Vector3.UP)
	Feel.sfx(&"break", global_position)
	Feel.shake(0.6)
	_clip(&"die", false)
	defeated.emit(self)
