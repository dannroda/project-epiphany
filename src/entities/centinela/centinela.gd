class_name Centinela
extends ArenaFighter
## Centinela del Bañado, mini jefe del martillo (11.192): camina pesado hacia el player, levanta la maza (marca en el
## piso dónde va a caer) y la baja. Cada pisada y el golpe mandan ondas por el piso (GroundWaves del modelo, que también
## lastiman a sus huancas). La maza queda clavada: ahí le pega todo (espada, bomba, vasija). Fuera de eso, todo rebota.
## La maneja un ArenaFight.

enum State { IDLE, WALK, WINDUP, SLAM, STUCK, DEAD }

@export var walk_speed := 1.8
## Camina hasta tener al player a esta distancia, o hasta `walk_time`.
@export var slam_reach := 2.6
@export var walk_time := 2.5
@export_group("Aviso del golpe")
## Se planta y junta fuerza (temblor y ruido de tierra) antes de levantar la maza.
@export var tell_time := 0.45
## Con la maza arriba; la marca del piso se va llenando hasta el anillo.
@export var windup_time := 1.3
## Los últimos segundos del aviso la marca deja de seguir al player y titila: cae ahí.
@export var aim_lock := 0.5
## El silbido que sube termina justo en el golpe.
@export var warn_lead := 0.55
@export_group("")
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

@onready var roar_fx: Roar = %Roar
@onready var aim_mark: Node3D = %AimMark
@onready var aim_disc: MeshInstance3D = %AimDisc
@onready var solid_shape: CollisionShape3D = %SolidShape
@onready var tip: Marker3D = body.find_child("Punta", true, false) as Marker3D

var state := State.IDLE
var _aim_locked := false
var _anim: AnimationPlayer


func _ready() -> void:
	super()
	_anim = body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		_anim.animation_finished.connect(_on_animation_finished)
	aim_mark.hide()
	_play.call_deferred(anim_idle)


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
	solid_shape.set_deferred(&"disabled", false)
	_play(anim_idle)


func _physics_process(delta: float) -> void:
	if state in [State.IDLE, State.DEAD]:
		return
	if state == State.WALK or (state == State.WINDUP and not _aim_locked):
		_face_player()
	if state == State.WINDUP and not _aim_locked:
		aim_mark.global_position = _strike_point() + Vector3.UP * 0.03
	if state == State.WALK:
		var player := Players.nearest(global_position)
		if player:
			var target := _clamp_to_arena(player.global_position)
			global_position = global_position.move_toward(target, walk_speed * pace * delta)


func _run() -> void:
	var turn := _turn
	await _wait(0.6)
	while not is_dead and turn == _turn and is_inside_tree():
		await _walk()
		if turn != _turn or not is_inside_tree():
			return
		if may_attack.is_valid() and not may_attack.call(self):
			await _wait(0.4)
			continue
		var slams := rage_slams if health.current * 2 <= health.max_health else 1
		for i in slams:
			await _slam(i == slams - 1)
			if turn != _turn or not is_inside_tree():
				return
		attack_finished.emit()


func _walk() -> void:
	state = State.WALK
	_play(anim_walk, anim_walk_speed * pace)
	var until := Time.get_ticks_msec() + int(walk_time / pace * 1000.0)
	var turn := _turn
	while turn == _turn and is_inside_tree() and Time.get_ticks_msec() < until:
		var player := Players.nearest(global_position)
		if player and _flat(player.global_position - global_position).length() <= slam_reach:
			break
		await get_tree().physics_frame
	if turn == _turn:
		_play(anim_idle)


func _slam(last := true) -> void:
	state = State.WINDUP
	_aim_locked = false
	aim_mark.global_position = _strike_point() + Vector3.UP * 0.03
	aim_disc.scale = Vector3.ONE * 0.3
	aim_disc.transparency = 0.0
	aim_mark.show()
	_play(anim_idle)
	Feel.sfx(&"rumble", global_position)
	Feel.shake(0.15)
	_tween_to(body, ^"scale", Vector3(1.08, 0.92, 1.08), tell_time).set_trans(Tween.TRANS_SINE)
	await _wait(tell_time)
	if state != State.WINDUP:
		return
	_tween_to(body, ^"scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_to(aim_disc, ^"scale", Vector3.ONE, windup_time)
	_play(anim_slam)
	_hold_at(anim_slam_raised * _slam_length())
	Feel.sfx(&"roll", global_position)
	_tween_to(body, ^"rotation:x", -0.15, windup_time * 0.6).set_ease(Tween.EASE_OUT)
	var cues := _new_tween().set_parallel()
	cues.tween_callback(_lock_aim).set_delay(maxf(windup_time - aim_lock, 0.0) / pace)
	cues.tween_callback(func() -> void: Feel.sfx(&"warp_out", aim_mark.global_position)).set_delay(maxf(windup_time - warn_lead, 0.0) / pace)
	await _wait(windup_time)
	if state != State.WINDUP:
		return
	state = State.SLAM
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
	await _wait(stuck_time, false)
	if state != State.STUCK:
		return
	wobble.kill()
	body.rotation = Vector3.ZERO
	Feel.burst(&"dust", aim_mark.global_position + Vector3.UP * 0.3, Vector3.UP)
	_release()
	_play(anim_idle)
	await _wait(0.5)


func _lock_aim() -> void:
	_aim_locked = true
	var blink := _new_tween().set_loops(maxi(int(aim_lock / pace / 0.12), 1))
	blink.tween_property(aim_disc, ^"transparency", 0.7, 0.06)
	blink.tween_property(aim_disc, ^"transparency", 0.0, 0.06)


func _strike_point() -> Vector3:
	var forward := body.global_transform.basis.z
	forward.y = 0.0
	return _clamp_to_arena(global_position + forward.normalized() * slam_reach)


func _on_interrupt() -> void:
	aim_mark.hide()
	_aim_locked = false
	body.rotation = Vector3.ZERO
	body.scale = Vector3.ONE
	_release()


func is_vulnerable() -> bool:
	return state == State.STUCK


func _is_idle() -> bool:
	return state == State.IDLE


func _spark_point() -> Vector3:
	return body.global_position + Vector3.UP * 1.5


func _wound_surface() -> String:
	return "stone"


func _die() -> void:
	_interrupt()
	state = State.DEAD
	solid_shape.set_deferred(&"disabled", true)
	Log.info(&"combat", name, "murió")
	remove_from_group(Targeting.GROUP)
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
