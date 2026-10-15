class_name Centinela
extends Node3D
## Centinela del Bañado, mini jefe del martillo (11.192): camina pesado hacia el player, levanta la maza (marca en el
## piso dónde va a caer) y la baja. Cada pisada y el golpe mandan ondas por el piso (GroundWaves del modelo, que también
## lastiman a los esqueletos). La maza queda clavada: ahí le pega todo (espada, bomba, vasija). Fuera de eso, todo rebota.
## La maneja un ArenaFight.

signal defeated(centinela: Centinela)
signal health_changed
## Terminó (o se cortó) su ataque: otro puede atacar.
signal attack_finished

enum State { IDLE, WALK, WINDUP, SLAM, STUCK, DEAD }

@export var config: EntityConfig
@export var walk_speed := 1.8
## Camina hasta tener al player a esta distancia, o hasta `walk_time`.
@export var slam_reach := 2.6
@export var walk_time := 2.5
@export var windup_time := 0.9
@export var stuck_time := 2.4
## Golpes seguidos con la mitad de la vida o menos (el último es el que lo deja trabado).
@export var rage_slams := 2
@export_group("Animaciones")
@export var anim_idle := &"CombatMelee/Melee_2H_Idle"
@export var anim_walk := &"MovementBasic/Walking_A"
@export var anim_walk_speed := 0.7
@export var anim_slam := &"CombatMelee/Melee_2H_Attack_Chop"
## Dónde se frena la animación del golpe con la maza arriba (aviso) y dónde queda en el piso, en fracción del largo.
@export var anim_slam_raised := 0.35
@export var anim_slam_down := 0.55
@export var anim_hit := &"General/Hit_A"
@export var anim_death := &"General/Death_A"

@onready var body: Node3D = %Body
@onready var roar_fx: Roar = %Roar
@onready var aim_mark: MeshInstance3D = %AimMark
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var health: Health = $Health
@onready var tip: Marker3D = body.find_child("Punta", true, false) as Marker3D

var state := State.IDLE
## La sala menos el borde, en XZ; la pone ArenaFight.
var arena := Rect2()
var pace := 1.0
var may_attack: Callable
var peers: Array = []
var _turn := 0
var _tweens: Array[Tween] = []
var _home := Vector3.ZERO
var _anim: AnimationPlayer

var is_dead: bool:
	get:
		return health.current <= 0


func _ready() -> void:
	health.max_health = config.max_health
	health.current = config.max_health
	hurtbox.team = config.team
	hurtbox.hit.connect(_on_hit)
	health.died.connect(_die)
	_home = global_position
	_anim = body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		_anim.animation_finished.connect(_on_animation_finished)
	aim_mark.hide()
	_play.call_deferred(anim_idle)


func start() -> void:
	if state != State.IDLE or is_dead:
		return
	add_to_group(Enemy.GROUP)
	config.apply_to(self)
	_run()


## Presentación: mira al player, levanta la maza y la planta con el grito.
func roar() -> void:
	_face_player()
	_play(anim_slam)
	roar_fx.play()
	Feel.shake(0.3)


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
	_play(anim_idle)


func _physics_process(delta: float) -> void:
	if state in [State.IDLE, State.DEAD]:
		return
	if state in [State.WALK, State.WINDUP]:
		_face_player()
	if state == State.WALK:
		var player := Players.nearest(global_position)
		if player:
			var target := _clamp_to_arena(player.global_position)
			global_position = global_position.move_toward(target, walk_speed * pace * delta)


func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds / pace, false).timeout


func _run() -> void:
	var turn := _turn
	await _wait(0.6)
	while not is_dead and turn == _turn:
		await _walk()
		if turn != _turn:
			return
		if may_attack.is_valid() and not may_attack.call(self):
			await _wait(0.4)
			continue
		var slams := rage_slams if health.current * 2 <= health.max_health else 1
		for i in slams:
			await _slam(i == slams - 1)
			if turn != _turn:
				return
		attack_finished.emit()


func _walk() -> void:
	state = State.WALK
	_play(anim_walk, anim_walk_speed * pace)
	var until := Time.get_ticks_msec() + int(walk_time / pace * 1000.0)
	var turn := _turn
	while turn == _turn and Time.get_ticks_msec() < until:
		var player := Players.nearest(global_position)
		if player and _flat(player.global_position - global_position).length() <= slam_reach:
			break
		await get_tree().physics_frame
	if turn == _turn:
		_play(anim_idle)


func _slam(last := true) -> void:
	state = State.WINDUP
	var ahead := _strike_point()
	aim_mark.global_position = ahead + Vector3.UP * 0.03
	aim_mark.scale = Vector3.ONE * 0.4
	aim_mark.show()
	_tween_to(aim_mark, ^"scale", Vector3.ONE, windup_time)
	_play(anim_slam)
	_hold_at(anim_slam_raised * _slam_length())
	Feel.sfx(&"roll", global_position)
	_tween_to(body, ^"rotation:x", -0.15, windup_time * 0.6).set_ease(Tween.EASE_OUT)
	await _wait(windup_time)
	if state != State.WINDUP:
		return
	state = State.SLAM
	aim_mark.global_position = _strike_point() + Vector3.UP * 0.03
	_release()
	_tween_to(body, ^"rotation:x", 0.12, 0.12).set_ease(Tween.EASE_IN)
	await _wait(maxf((anim_slam_down - anim_slam_raised) * _slam_length(), 0.12))
	if state != State.SLAM:
		return
	_hold_at(anim_slam_down * _slam_length())
	if tip:
		aim_mark.global_position = Vector3(tip.global_position.x, global_position.y + 0.03, tip.global_position.z)
	aim_mark.hide()
	Feel.sfx(&"boom", aim_mark.global_position)
	if not last:
		await _wait(0.35)
		body.rotation.x = 0.0
		return
	state = State.STUCK
	var wobble := _new_tween().set_loops(maxi(int(stuck_time / 0.3), 1))
	wobble.tween_property(body, ^"rotation:z", 0.08, 0.15)
	wobble.tween_property(body, ^"rotation:z", -0.08, 0.15)
	await get_tree().create_timer(stuck_time, false).timeout
	if state != State.STUCK:
		return
	wobble.kill()
	body.rotation = Vector3.ZERO
	Feel.burst(&"dust", aim_mark.global_position + Vector3.UP * 0.3, Vector3.UP)
	_release()
	_play(anim_idle)
	await _wait(0.5)


func _strike_point() -> Vector3:
	var forward := body.global_transform.basis.z
	forward.y = 0.0
	return _clamp_to_arena(global_position + forward.normalized() * slam_reach)


func _interrupt() -> void:
	_turn += 1
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	aim_mark.hide()
	body.rotation = Vector3.ZERO
	_release()
	attack_finished.emit()


func is_vulnerable() -> bool:
	return state == State.STUCK


func _on_hit(info: DamageInfo) -> void:
	if is_dead or state == State.IDLE:
		return
	if not is_vulnerable():
		hurtbox.surface = "stone"
		Feel.burst(&"sparks", body.global_position + Vector3.UP * 1.5, Vector3.UP)
		Feel.sfx(&"block", body.global_position)
		return
	hurtbox.surface = "stone"
	if health.damage(info.amount):
		Log.info(&"combat", name, "recibió", info.amount, "de daño. Vida:", health.current)
		health_changed.emit()


func _die() -> void:
	_interrupt()
	state = State.DEAD
	Log.info(&"combat", name, "murió")
	remove_from_group(&"targetable")
	hurtbox.set_deferred(&"monitorable", false)
	_play(anim_death)
	Feel.burst(&"dust", global_position + Vector3.UP, Vector3.UP)
	Feel.sfx(&"break", global_position)
	Feel.shake(0.6)
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(body, ^"scale", Vector3(1.15, 0.05, 1.15), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(body.hide)
	defeated.emit(self)


func _face_player() -> void:
	var player := Players.nearest(global_position)
	if player == null:
		return
	var look := Vector3(player.global_position.x, body.global_position.y, player.global_position.z)
	if not look.is_equal_approx(body.global_position):
		body.look_at(look, Vector3.UP, true)


func _play(animation: StringName, speed := 1.0) -> void:
	if _anim and _anim.has_animation(animation):
		_anim.play(animation, 0.15, speed)


func _hold_at(seconds: float) -> void:
	if _anim and _anim.is_playing():
		_anim.seek(seconds, true)
		_anim.pause()


## Las de la biblioteca no se repiten: caminar y esperar vuelven a empezar.
func _on_animation_finished(animation: StringName) -> void:
	if state == State.WALK and animation == anim_walk:
		_play(anim_walk, anim_walk_speed * pace)
	elif state in [State.IDLE, State.WALK] and animation == anim_idle:
		_play(anim_idle)


func _slam_length() -> float:
	return _anim.get_animation(anim_slam).length if _anim and _anim.has_animation(anim_slam) else 1.0


func _release() -> void:
	if _anim and not _anim.is_playing() and _anim.current_animation != &"":
		_anim.play()


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _clamp_to_arena(point: Vector3) -> Vector3:
	if arena.size == Vector2.ZERO:
		return Vector3(point.x, global_position.y, point.z)
	return Vector3(clampf(point.x, arena.position.x, arena.end.x), global_position.y, clampf(point.z, arena.position.y, arena.end.y))


func _new_tween() -> Tween:
	_tweens = _tweens.filter(func(tween: Tween) -> bool: return tween.is_valid())
	var tween := create_tween()
	_tweens.append(tween)
	return tween


func _tween_to(target: Object, property: NodePath, value: Variant, seconds: float) -> PropertyTweener:
	return _new_tween().tween_property(target, property, value, seconds / pace)
