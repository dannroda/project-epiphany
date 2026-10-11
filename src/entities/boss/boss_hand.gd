@tool
class_name BossHand
extends Node3D
## Guantelete del jefe: tres mallas hermanas, una por pose; se ve una sola.
## Solo recibe daño aturdida; si no, el golpe rebota en el hierro.
## Los ataques (`perform`) avisan antes: la sombra en el piso se achica y oscurece hasta el impacto.

signal state_changed(state: State)
signal downed

enum Pose { OPEN, FIST, CLAW }
enum State { READY, BUSY, STUNNED, DOWN }

## Alto del centro de la mano apoyada en el piso.
const FLOOR_HEIGHT := 0.6
const SLAM_HEIGHT := 4.5
const GRAB_REACH := 1.2
## Cuánto sube de más antes de caer y cuánto rebota al pegar.
const SLAM_OVERSHOOT := 0.7
const SLAM_BOUNCE := 0.35
const SQUASH := Vector3(1.25, 0.7, 1.25)
const TREMBLE := 0.06
const IMPACT_HIT_STOP := 0.06
const CRACK_LIFETIME := 8.0
const STUN_WOBBLE := 0.18

@export var pose := Pose.OPEN:
	set(value):
		pose = value
		if is_inside_tree():
			_show_pose()
@export var damage := 4
@export var knockback := 10.0

@export_group("Golpe al piso")
@export var slam_rise_time := 0.6
## Sigue al player desde arriba.
@export var slam_track_time := 1.0
## Quieta antes de caer: la última oportunidad para salir de la sombra.
@export var slam_lock_time := 0.4
@export var slam_fall_time := 0.09
@export var slam_stun_time := 2.6
@export var shockwave_radius := 2.6

@export_group("Agarre")
@export var grab_windup_time := 0.7
@export var grab_lunge_time := 0.35
@export var grab_hold_time := 3.0
@export var grab_tick := 0.75
## Se soltó a fuerza de botones: queda mareada.
@export var grab_escape_stun := 1.8

@export_group("Barrido")
@export var sweep_windup_time := 0.7
@export var sweep_time := 0.6

var state := State.READY
## Telegrafiando o golpeando; el jefe espera a que termine (no a que se reponga).
var striking := false
var rest: Node3D
var _stun_left := 0.0
var _fall: Tween
var _motion: Tween
var _shockwave_data := AttackData.new()
var _flash: HitFlash
var _material: StandardMaterial3D
var _spark_left := 0.0
var _stun_time := 0.0
var _base_glow := 1.0
static var _crack: Texture2D

@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var attack_runner: AttackRunner = $AttackRunner
@onready var strike: Hitbox = $Hitboxes/Strike
@onready var shockwave: Hitbox = $Hitboxes/Shockwave
@onready var shadow: Decal = $Shadow
@onready var ring: MeshInstance3D = $Ring
@onready var grip: Marker3D = $Grip


func _ready() -> void:
	_show_pose()
	if Engine.is_editor_hint():
		return
	_shockwave_data.damage_multiplier = 0.5
	_shockwave_data.hitbox = &"shockwave"
	hurtbox.team = EntityConfig.Team.ENEMY
	for hitbox: Hitbox in attack_runner.hitboxes.values():
		hitbox.team = EntityConfig.Team.ENEMY
		hitbox.damage_factory = _make_damage
	hurtbox.hit.connect(_on_hit)
	health.died.connect(_on_died)
	_flash = HitFlash.attach(self, health)
	_material = ($Open as MeshInstance3D).mesh.surface_get_material(0).duplicate()
	_base_glow = _material.emission_energy_multiplier
	for mesh in _meshes():
		mesh.material_override = _material
	shadow.visible = false
	ring.visible = false


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() and state == State.READY and rest:
		global_position = rest.global_position


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or state != State.STUNNED:
		return
	_stun_left -= delta
	_stun_time += delta
	rotation.x = sin(_stun_time * 7.0) * STUN_WOBBLE * 0.5
	rotation.z = sin(_stun_time * 4.3) * STUN_WOBBLE
	_material.emission_energy_multiplier = _base_glow * (0.15 if randf() < 0.35 else 1.0)
	_spark_left -= delta
	if _spark_left <= 0.0:
		_spark_left = randf_range(0.25, 0.6)
		Feel.burst(&"sparks", global_position + Vector3(randf_range(-0.5, 0.5), 0.4, randf_range(-0.5, 0.5)), Vector3.UP)
	if _stun_left <= 0.0:
		_steady()
		_recover()


func is_available() -> bool:
	return state == State.READY


func set_state(value: State) -> void:
	if value == state:
		return
	if state == State.STUNNED:
		_steady()
	state = value
	if state != State.BUSY:
		attack_runner.stop()
		_set_hitbox(strike, null)
	state_changed.emit(state)


func stun(seconds: float) -> void:
	if state == State.DOWN:
		return
	_stun_left = seconds
	_stun_time = 0.0
	striking = false
	set_state(State.STUNNED)


## Fase 2: vuelve con la vida llena.
func regenerate() -> void:
	if _fall:
		_fall.kill()
	health.reset(health.max_health)
	rotation = Vector3.ZERO
	set_state(State.BUSY)
	await _return_to_rest()
	if state == State.BUSY:
		set_state(State.READY)


## Corre el ataque; `striking` queda en true hasta que golpea (o falla). `area`: el piso de la arena (XZ).
func perform(attack: BossAttack, target: Node3D, area: Rect2) -> void:
	if not is_available():
		return
	set_state(State.BUSY)
	striking = true
	pose = attack.pose
	match attack.id:
		&"slam":
			await _slam(attack, target, area)
		&"grab":
			await _grab(attack, target, area)
		&"sweep":
			await _sweep(attack, target, area)
	striking = false
	_hide_shadow()
	if state == State.BUSY:
		await _return_to_rest()
		if state == State.BUSY:
			set_state(State.READY)


func _slam(attack: BossAttack, target: Node3D, area: Rect2) -> void:
	var above := _floor_point(target.global_position, area) + Vector3.UP * SLAM_HEIGHT
	_show_shadow(above, 3.6, 0.3)
	await _move(above, slam_rise_time)
	var left := slam_track_time
	while left > 0.0:
		await get_tree().physics_frame
		if state != State.BUSY:
			return
		var delta := get_physics_process_delta_time()
		left -= delta
		var wanted := _floor_point(target.global_position, area) + Vector3.UP * SLAM_HEIGHT
		global_position = global_position.lerp(wanted, 1.0 - exp(-6.0 * delta))
		var t := 1.0 - left / slam_track_time
		_show_shadow(global_position, lerpf(3.6, 2.6, t), lerpf(0.3, 0.75, t))
	_show_shadow(global_position, 2.4, 1.0)
	_flash.warn(slam_lock_time)
	var hold := create_tween()
	hold.tween_property(self, ^"position:y", position.y + SLAM_OVERSHOOT, slam_lock_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hold.parallel().tween_method(_tremble.bind(position), 0.0, 1.0, slam_lock_time)
	hold.parallel().tween_method(_flash_shadow, 0.0, 1.0, slam_lock_time)
	await hold.finished
	if state != State.BUSY:
		return
	_set_hitbox(strike, attack.attack)
	await _move(Vector3(global_position.x, FLOOR_HEIGHT, global_position.z), slam_fall_time, Tween.EASE_IN)
	_impact()
	_squash_and_bounce()
	await get_tree().create_timer(0.08, false).timeout
	_set_hitbox(strike, null)
	await get_tree().create_timer(0.1, false).timeout
	_set_hitbox(shockwave, null)
	if state == State.BUSY:
		stun(slam_stun_time)


func _impact() -> void:
	_hide_shadow()
	var floor_point := Vector3(global_position.x, 0.05, global_position.z)
	shockwave.global_position = floor_point
	_set_hitbox(shockwave, _shockwave_data)
	ring.global_position = floor_point
	ring.scale = Vector3.ONE * 0.4
	ring.transparency = 0.0
	ring.visible = true
	var wave := create_tween().set_parallel()
	wave.tween_property(ring, ^"scale", Vector3.ONE * shockwave_radius, 0.3).set_ease(Tween.EASE_OUT)
	wave.tween_property(ring, ^"transparency", 1.0, 0.35)
	wave.chain().tween_callback(ring.hide)
	Feel.sfx(&"boom", floor_point)
	Feel.burst(&"dust", floor_point, Vector3.UP)
	Feel.burst(&"shards", floor_point + Vector3.UP * 0.2, Vector3.UP)
	Feel.shake(0.5)
	_leave_crack(floor_point)
	Feel.freeze(IMPACT_HIT_STOP)


func _grab(_attack: BossAttack, target: Node3D, area: Rect2) -> void:
	var side := signf(global_position.x - target.global_position.x)
	if side == 0.0:
		side = 1.0
	var start := _floor_point(target.global_position + Vector3(side * 3.5, 0.0, 0.0), area) + Vector3.UP * 1.4
	await _move(start, 0.5)
	if state != State.BUSY:
		return
	_flash.warn(grab_windup_time)
	var shake := create_tween()
	for i in 6:
		shake.tween_property(self, ^"rotation:z", 0.12 * (1 if i % 2 else -1), grab_windup_time / 6.0)
	shake.tween_property(self, ^"rotation:z", 0.0, 0.05)
	_show_shadow(global_position, 1.6, 0.4)
	await shake.finished
	if state != State.BUSY:
		return
	var from := global_position
	var aim := _floor_point(target.global_position, area) + Vector3.UP * 1.0
	var to := aim + (aim - from).normalized() * 1.5
	to.y = 1.0
	var elapsed := 0.0
	var caught := false
	while elapsed < grab_lunge_time:
		await get_tree().physics_frame
		if state != State.BUSY:
			return
		elapsed += get_physics_process_delta_time()
		global_position = from.lerp(to, ease(elapsed / grab_lunge_time, 0.5))
		_show_shadow(global_position, 1.6, 0.4)
		if Vector2(global_position.x, global_position.z).distance_to(Vector2(target.global_position.x, target.global_position.z)) < GRAB_REACH:
			var player := target as PlayerCharacter
			if player == null:
				continue
			if player.blocks_from(global_position):
				Feel.sfx(&"block", global_position)
				Feel.burst(&"sparks", global_position, Vector3.UP)
				await _move(global_position + (from - to).normalized() * 1.5, 0.25)
				return
			if player.grab(grip):
				caught = true
				break
	if caught:
		await _hold(target as PlayerCharacter)


func _hold(target: PlayerCharacter) -> void:
	striking = false
	var escaped := [false]
	var on_escape := func() -> void: escaped[0] = true
	target.escaped.connect(on_escape)
	await _move(global_position + Vector3.UP * 0.8, 0.3)
	var left := grab_hold_time
	var tick := grab_tick
	while left > 0.0 and not escaped[0] and state == State.BUSY and target.is_grabbed():
		await get_tree().physics_frame
		var delta := get_physics_process_delta_time()
		left -= delta
		tick -= delta
		if tick <= 0.0:
			tick = grab_tick
			if target.health.damage(1):
				Feel.sfx(&"hurt", target.global_position)
	target.escaped.disconnect(on_escape)
	if escaped[0]:
		stun(grab_escape_stun)
		return
	target.release()
	if state == State.BUSY:
		var info := _make_damage()
		info.amount = 2
		info.knockback = 12.0
		info.team = EntityConfig.Team.ENEMY
		(target.get_node(^"Hurtbox") as Hurtbox).receive(info)


func _sweep(attack: BossAttack, target: Node3D, area: Rect2) -> void:
	var side := signf(global_position.x - area.get_center().x)
	if side == 0.0:
		side = 1.0
	var z := clampf(target.global_position.z, area.position.y, area.end.y)
	var start := Vector3(area.get_center().x + side * area.size.x * 0.5, FLOOR_HEIGHT + 0.2, z)
	var finish := Vector3(area.get_center().x - side * area.size.x * 0.5, FLOOR_HEIGHT + 0.2, z)
	await _move(start, 0.6)
	if state != State.BUSY:
		return
	_show_shadow(global_position, 1.8, 0.5)
	_flash.warn(sweep_windup_time)
	var windup := create_tween()
	windup.tween_property(self, ^"position:x", position.x + side * 0.9, sweep_windup_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	windup.parallel().tween_method(func(t: float) -> void: position.z += randf_range(-TREMBLE, TREMBLE) * t, 0.0, 1.0, sweep_windup_time)
	await windup.finished
	if state != State.BUSY:
		return
	Feel.shake(0.25, finish - start)
	_set_hitbox(strike, attack.attack)
	var from := global_position
	var elapsed := 0.0
	while elapsed < sweep_time:
		await get_tree().physics_frame
		if state != State.BUSY:
			return
		elapsed += get_physics_process_delta_time()
		global_position = from.lerp(finish, elapsed / sweep_time)
		_show_shadow(global_position, 1.8, 0.5)
	_set_hitbox(strike, null)


## El reposo flota con el cuerpo: lo sigue mientras vuelve.
func _return_to_rest() -> void:
	if rest:
		var from := global_position
		_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_motion.tween_method(func(t: float) -> void: global_position = from.lerp(rest.global_position, t), 0.0, 1.0, 0.6)
		await _motion.finished
	pose = Pose.OPEN


func _recover() -> void:
	set_state(State.BUSY)
	await _return_to_rest()
	if state == State.BUSY:
		set_state(State.READY)


func _move(to: Vector3, seconds: float, ease_type := Tween.EASE_IN_OUT) -> void:
	_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(ease_type)
	_motion.tween_property(self, ^"global_position", to, seconds)
	await _motion.finished


func _floor_point(point: Vector3, area: Rect2) -> Vector3:
	return Vector3(clampf(point.x, area.position.x, area.end.x), 0.0, clampf(point.z, area.position.y, area.end.y))


func _show_shadow(over: Vector3, size: float, alpha: float) -> void:
	shadow.visible = true
	shadow.global_position = Vector3(over.x, 0.5, over.z)
	shadow.scale = Vector3(size, 1.0, size)
	shadow.modulate.a = alpha


func _hide_shadow() -> void:
	shadow.visible = false


func _set_hitbox(hitbox: Hitbox, data: AttackData) -> void:
	if (hitbox.active_attack != null) == (data != null):
		return
	hitbox.active_attack = data
	hitbox.set_deferred(&"monitoring", data != null)


func _make_damage() -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = damage
	info.knockback = knockback
	info.source = self
	return info


func _on_hit(info: DamageInfo) -> void:
	if state == State.DOWN:
		return
	if state != State.STUNNED:
		if info.stun_time > 0.0 and state == State.READY:
			stun(info.stun_time)
			Feel.sfx(&"deny", global_position)
		else:
			Feel.sfx(&"block", global_position)
			Feel.burst(&"sparks", global_position, Vector3.UP)
		return
	health.damage(info.amount)


func _on_died() -> void:
	collapse()
	downed.emit()


## Cae al piso y queda ahí (sin vida, o porque murió el jefe).
func collapse() -> void:
	if state == State.DOWN:
		return
	if _motion:
		_motion.kill()
	striking = false
	_hide_shadow()
	set_state(State.DOWN)
	_fall = create_tween().set_parallel()
	_fall.tween_property(self, ^"global_position:y", FLOOR_HEIGHT - 0.2, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_fall.tween_property(self, ^"rotation:z", 0.5 * signf(position.x), 0.4)
	Feel.sfx(&"boom", global_position)


func _meshes() -> Array[MeshInstance3D]:
	return [$Open, $Fist, $Claw]


## Tiembla cada vez más alrededor de `center` (en coordenadas del padre); la altura la maneja otro tween.
func _tremble(amount: float, center: Vector3) -> void:
	var jitter := TREMBLE * amount
	position.x = center.x + randf_range(-jitter, jitter)
	position.z = center.z + randf_range(-jitter, jitter)


## La sombra crece y titila el último instante del aviso.
func _flash_shadow(progress: float) -> void:
	var size := lerpf(2.4, 3.0, progress)
	shadow.scale = Vector3(size, 1.0, size)
	shadow.modulate.a = 0.35 if progress > 0.6 and int(progress * 20.0) % 2 == 0 else 1.0


func _squash_and_bounce() -> void:
	for mesh in _meshes():
		mesh.scale = SQUASH
		var back := mesh.create_tween()
		back.tween_property(mesh, ^"scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var bounce := create_tween()
	bounce.tween_property(self, ^"position:y", position.y + SLAM_BOUNCE, 0.12).set_ease(Tween.EASE_OUT).set_delay(0.08)
	bounce.tween_property(self, ^"position:y", position.y, 0.14).set_ease(Tween.EASE_IN)


## Una grieta que queda en el piso un rato y se va borrando.
func _leave_crack(at: Vector3) -> void:
	if _crack == null:
		_crack = DoomAmbience.crack_texture()
	var crack := Decal.new()
	crack.texture_albedo = _crack
	crack.size = Vector3(3.2, 1.0, 3.2)
	crack.modulate = Color(0.1, 0.07, 0.07)
	get_tree().current_scene.add_child(crack)
	crack.global_position = Vector3(at.x, 0.1, at.z)
	crack.rotation.y = randf() * TAU
	var fade := crack.create_tween()
	fade.tween_property(crack, ^"modulate:a", 0.0, 2.0).set_delay(CRACK_LIFETIME)
	fade.tween_callback(crack.queue_free)


func _steady() -> void:
	rotation.x = 0.0
	rotation.z = 0.0
	_material.emission_energy_multiplier = _base_glow


func _show_pose() -> void:
	$Open.visible = pose == Pose.OPEN
	$Fist.visible = pose == Pose.FIST
	$Claw.visible = pose == Pose.CLAW
