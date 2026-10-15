@tool
class_name Boss
extends Node3D
## El Ojo con manos (gdd §9). Sin esqueleto: el ojo gira entero hacia lo que mira, los párpados de hierro se abren
## rotando en X y las manos flotan sueltas (vuelven a su reposo, al lado del cuerpo).
## Fases con LimboHSM (cada una corre su BT); el BT le pide el ataque a `choose_attack` (utilidad).

signal defeated
## Terminó la animación de muerte (el jefe ya no se ve).
signal death_finished
signal phase_changed(phase: int)
## Lo que muestra la barra del HUD cambió (`bar_fraction`).
signal bar_changed

const LID_OPEN_ANGLE := 70.0
const PHASES := {&"Phase1": 1, &"Phase2": 2, &"Phase3": 3}
const ORB := preload("res://src/entities/projectile.tscn")
const CORRUPT_GLOW := Color(1.0, 0.3, 0.18)
## Cuadros de física en que la explosión de la marca lastima.
const BLAST_FRAMES := 3
## Alto del cuerpo en la fase 2 (más cerca para mirarte) y aturdido (apoyado en el piso: lo más bajo del cuerpo queda
## 2,35 m debajo de su origen).
const BODY_HEIGHT_OPEN := 2.6
const BODY_HEIGHT_STUNNED := 2.4
const BOB_HEIGHT := 0.12
const BOB_SPEED := 1.3
const LEAN_ANGLE := 9.0
const BLINK_EVERY := Vector2(2.5, 6.0)
## Cuánto cierra los párpados mientras apunta el orbe.
const SQUINT := 0.45
## Pupila: qué tan rápido sigue a su meta (-1 rendija, 0 normal, 1 dilatada) y cuánto tiembla aturdida.
const PUPIL_SPEED := 9.0
const PUPIL_DAZED_WOBBLE := 0.2
## Brillo del neón del ojo (multiplicador de emisión): en reposo, cargando el orbe y apagado.
const EYE_GLOW := 1.0
const EYE_GLOW_CHARGED := 4.0
const SLOW_MOTION := 0.25
const SLOW_MOTION_TIME := 0.7
## Qué tanto mira la pupila hacia la cámara en vez de al jugador: tranquilo y mientras dispara orbes.
const GAZE_CALM := 0.5
const GAZE_FIRING := 0.2
## Cuánto se queda la cámara en el jefe al presentar la fase 2.
const PHASE_HOLD := 2.2

@export_group("Ajuste")
@export var eye_stun_time := 3.0
## La fase 3 arranca con el ojo a este tanto de su vida (la última marca de la barra).
@export var enrage_fraction := 1.0 / 3.0
@export var mark_count := 3
@export var mark_radius := 1.6
@export var mark_spacing := 3.2
@export var mark_telegraph := 1.4
@export var mark_damage := 4
## Las manos vuelven un rato después de que se abre el ojo.
@export var hands_back_delay := 1.2
@export var repeat_penalty := 0.25
@export var same_hand_penalty := 0.7
## Entran al sorteo los que tienen al menos esta fracción del mejor puntaje.
@export var shortlist := 0.75
@export_group("")

## 0 cerrado, 1 abierto.
@export_range(0.0, 1.0) var eye_open := 0.0:
	set(value):
		eye_open = value
		if is_node_ready():
			_apply_lids()
@export var attacks: Array[BossAttack] = []
@export var display_name := "BOSS_NAME"
@export var orb_damage := 4
@export var orb_speed := 9.0
@export var orb_charge_time := 0.8
@export_group("Rayo")
## Con las dos manos fuera de juego en las fases 2 y 3: marca una línea por el player, carga y la barre.
@export var laser_damage := 4
@export var laser_length := 12.0
@export var laser_charge_time := 1.0
@export var laser_sweep_time := 1.4
@export_group("")

var target: Node3D
## Piso de la pelea (XZ global); lo pone `BossArena` con la sala. Las manos no salen de acá.
var arena: Rect2
var chosen_attack: BossAttack
var attacker: Node3D
var rng := RandomNumberGenerator.new()
var _eye_stun_left := 0.0
var _eye_attacking := false
## El último ataque del ojo: con las manos fuera de juego alterna orbe y rayo.
var _last_eye_attack: StringName
var _laser_tween: Tween
var _laser_from := Vector3.ZERO
var _laser_to := Vector3.ZERO
var _body_tween: Tween
var _charge_tween: Tween
var _body_height := 0.0
var _time := 0.0
## 1 flota, 0 quieto (aturdido, apoyado en el piso).
var _bob := 1.0
var _blink := 0.0
var _squint := 0.0
## -1 rendija, 0 normal, 1 dilatada.
var pupil := 0.0
var _pupil_goal := 0.0
var _pupil_keys := Vector2i(-1, -1)
var _next_blink := 4.0
var _alive := true
var _eye_material: StandardMaterial3D
var _body_material: StandardMaterial3D
var _flash: HitFlash
var _eye_base_glow := 1.0
var _body_base_glow := 1.0
## Corre Transform (la máscara estalla al entrar a la fase 3) o se presenta una fase: no ataca ni recibe daño.
var _transforming := false
## Lo prende BossArena al arrancar la pelea: cada fase nueva se presenta con la cámara, como el inicio.
var presents_phases := false
## Revancha o reintento: esas presentaciones ya se vieron y se pueden saltear.
var skippable_phases := false
## La cámara se acercó a presentar la fase y el juego está en pausa: los efectos tienen que andar igual.
var _presenting := false

@onready var body: Node3D = $Body
@onready var eye: Node3D = %Eye
@onready var roar_fx: Roar = %Roar
@onready var orb_muzzle: Marker3D = %OrbMuzzle
@onready var hand_left: BossHand = $HandLeft
@onready var hand_right: BossHand = $HandRight
@onready var health: Health = $Health
@onready var eye_hurtbox: Hurtbox = %EyeHurtbox
@onready var phases: LimboHSM = $Phases
@onready var _charge: MeshInstance3D = %Charge
@onready var _eye_mesh: MeshInstance3D = $Body/Eye/Mesh
@onready var _upper_lid: Node3D = %UpperLid
@onready var _lower_lid: Node3D = %LowerLid
@onready var _transform: AnimationPlayer = %Transform
@onready var _laser_path: MeshInstance3D = %LaserPath
@onready var _laser_beam: MeshInstance3D = %LaserBeam
@onready var _laser_spot: Hitbox = %LaserSpot


func _ready() -> void:
	_apply_lids()
	if Engine.is_editor_hint():
		return
	_body_height = body.position.y
	_eye_material = _own_material(_eye_mesh)
	_body_material = _own_material($Body/Mesh)
	_eye_base_glow = _eye_material.emission_energy_multiplier
	_body_base_glow = _body_material.emission_energy_multiplier
	_pupil_keys = Vector2i(_eye_mesh.find_blend_shape_by_name(&"rendija"), _eye_mesh.find_blend_shape_by_name(&"dilatada"))
	if not arena.has_area():
		arena = Rect2(global_position.x - 9.0, global_position.z - 3.0, 18.0, 10.0)
	for hand in [hand_left, hand_right]:
		hand.rest = hand_rest(hand)
		hand.global_position = hand.rest.global_position
		hand.downed.connect(_on_hand_downed)
	eye_hurtbox.team = EntityConfig.Team.ENEMY
	eye_hurtbox.hit.connect(_on_eye_hit)
	health.died.connect(func() -> void: phases.dispatch(&"died"))
	_flash = %HitFlash
	phases.add_transition($Phases/Phase1, $Phases/Phase2, &"hands_down")
	phases.add_transition($Phases/Phase2, $Phases/Phase3, &"enraged")
	phases.add_transition($Phases/Phase2, $Phases/Defeated, &"died")
	phases.add_transition($Phases/Phase3, $Phases/Defeated, &"died")
	$Phases/Phase3.entered.connect(_on_phase3_entered)
	health.changed.connect(func(current: int, max_value: int) -> void:
		if phase() == 2 and current > 0 and current <= max_value * enrage_fraction:
			phases.dispatch(&"enraged"))
	$Phases/Phase1.entered.connect(func() -> void: phase_changed.emit(1))
	$Phases/Phase2.entered.connect(_on_phase2_entered)
	health.changed.connect(func(_c: int, _m: int) -> void: bar_changed.emit())
	for hand in [hand_left, hand_right]:
		hand.health.changed.connect(func(_c: int, _m: int) -> void: bar_changed.emit())
	phase_changed.connect(func(_p: int) -> void: bar_changed.emit())
	$Phases/Defeated.entered.connect(_on_defeated)


func start_fight() -> void:
	target = Players.nearest(eye.global_position)
	phases.initialize(self)
	phases.set_active(true)


func phase() -> int:
	var state := phases.get_active_state() if phases.is_active() else null
	if state == null:
		return 0
	return PHASES.get(state.name, 0)


## Barra del HUD: en la fase 1, la vida que les queda a las dos manos; después, la del ojo.
func bar_fraction() -> float:
	if phase() >= 2 or health.current == 0:
		return health.current / float(health.max_health)
	var left := hand_left.health.current + hand_right.health.current
	return left / float(hand_left.health.max_health + hand_right.health.max_health)


func is_eye_stunned() -> bool:
	return _eye_stun_left > 0.0


func is_transforming() -> bool:
	return _transforming


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _alive:
		return
	_time += delta
	_bob = move_toward(_bob, 0.0 if is_eye_stunned() else 1.0, delta * 4.0)
	body.position.y = _body_height + sin(_time * BOB_SPEED * TAU) * BOB_HEIGHT * _bob
	var lean := 0.0
	if attacker is BossHand and attacker.striking:
		lean = -signf(attacker.global_position.x - global_position.x) * deg_to_rad(LEAN_ANGLE)
	body.rotation.z = lerpf(body.rotation.z, lean, 1.0 - exp(-4.0 * delta))
	if eye_open >= 1.0 and not is_eye_stunned() and not _charge.visible:
		_next_blink -= delta
		if _next_blink <= 0.0:
			_next_blink = rng.randf_range(BLINK_EVERY.x, BLINK_EVERY.y)
			var blink := create_tween()
			blink.tween_property(self, ^"_blink", 1.0, 0.07)
			blink.tween_property(self, ^"_blink", 0.0, 0.12)
	_apply_lids()
	var goal := _pupil_goal
	if is_eye_stunned():
		goal = 1.0 - PUPIL_DAZED_WOBBLE * (0.5 + 0.5 * sin(_time * 11.0))
	pupil = lerpf(pupil, goal, 1.0 - exp(-PUPIL_SPEED * delta))
	_apply_pupil()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not phases.is_active():
		return
	if _eye_stun_left > 0.0:
		_eye_stun_left -= delta
		if _eye_stun_left <= 0.0:
			_move_body(BODY_HEIGHT_OPEN, 0.6)
	if _laser_beam.visible:
		_place_laser()
	if is_instance_valid(target) and not is_eye_stunned():
		var wanted := (gaze_point(target.global_position) - eye.global_position).normalized()
		look_at_point(eye.global_position + eye.global_basis.z.normalized().slerp(wanted, 1.0 - exp(-4.0 * delta)))
	var blackboard := phases.blackboard
	blackboard.set_var(&"target", target)
	blackboard.set_var(&"phase", phase())
	blackboard.set_var(&"hand_left", BossHand.State.keys()[hand_left.state])
	blackboard.set_var(&"hand_right", BossHand.State.keys()[hand_right.state])
	blackboard.set_var(&"eye_stunned", is_eye_stunned())
	DebugOverlay.watch("boss/phase", phase())
	DebugOverlay.watch("boss/hand_left", blackboard.get_var(&"hand_left"))
	DebugOverlay.watch("boss/hand_right", blackboard.get_var(&"hand_right"))
	DebugOverlay.watch("boss/attack", "%s (%s)" % [chosen_attack.id, attacker.name] if chosen_attack else "-")


## Puntúa cada ataque posible por cada pieza libre que lo puede hacer y sortea, por puntaje, entre los que quedan
## cerca del mejor: así no se vuelve un patrón fijo pero tampoco elige algo que no conviene.
func choose_attack(for_phase: int) -> bool:
	if is_eye_stunned() or _transforming:
		return false
	var options: Array[Array] = []
	var best_score := 0.0
	var hands_out := hands_out()
	for attack in attacks:
		if not for_phase in attack.phases:
			continue
		if attack.id == BossAttack.LASER and not hands_out:
			continue
		if hands_out and attack.user == BossAttack.User.EYE and (attack.id not in [BossAttack.ORB, BossAttack.LASER] or attack.id == _last_eye_attack):
			continue
		for user in _users(attack):
			var score := attack.weight * compensated([
				_distance_score(attack, user),
				repeat_penalty if chosen_attack and attack.id == chosen_attack.id else 1.0,
				same_hand_penalty if user == attacker and user is BossHand else 1.0,
			])
			if score > 0.0:
				options.append([score, attack, user])
				best_score = maxf(best_score, score)
	options = options.filter(func(option: Array) -> bool: return option[0] >= best_score * shortlist)
	if options.is_empty():
		return false
	var total := 0.0
	for option in options:
		total += option[0]
	var roll := rng.randf() * total
	var picked: Array = options.back()
	for option in options:
		roll -= option[0]
		if roll <= 0.0:
			picked = option
			break
	chosen_attack = picked[1]
	attacker = picked[2]
	if phases.is_active():
		phases.blackboard.set_var(&"attack", chosen_attack.id)
		phases.blackboard.set_var(&"attacker", attacker)
	Log.debug(&"boss", "elige", chosen_attack.id, "con", attacker.name, "(%.2f de %.2f)" % [picked[0], best_score])
	return true


## Lo corre la hoja `PerformBossAttack` del BT después de elegir.
func perform_chosen() -> void:
	if chosen_attack == null or not is_instance_valid(target):
		return
	if attacker == eye:
		_last_eye_attack = chosen_attack.id
	if attacker is BossHand:
		attacker.perform(chosen_attack, target, arena)
	elif attacker == eye and chosen_attack.id == BossAttack.MARK:
		_mark_floor()
	elif attacker == eye and chosen_attack.id == BossAttack.ORB:
		_fire_orb()
	elif attacker == eye and chosen_attack.id == BossAttack.LASER:
		_sweep_laser()
	else:
		push_error("Boss: %s no sabe hacer %s" % [attacker.name, chosen_attack.id])


## El BT espera a que la mano termine de golpear (no a que se reponga): la otra puede atacar mientras.
func is_attack_running() -> bool:
	return _eye_attacking or (attacker is BossHand and attacker.striking)


## El ojo carga (la bola de luz crece en la salida) y escupe un orbe que el escudo espejo puede devolver.
## El ojo marca el piso alrededor del player (círculos rojos que se cargan) y una mano libre golpea a la vez.
## Las marcas estallan juntas: solo se esquivan (el escudo no frena el estallido).
func _mark_floor() -> void:
	_eye_attacking = true
	var points := _mark_points()
	var marks: Array[Decal] = []
	for point in points:
		var mark := %MarkTemplate.duplicate() as Decal
		add_child(mark)
		mark.global_position = point + Vector3.UP * 0.5
		mark.scale = Vector3(mark_radius * 2.0, 1.0, mark_radius * 2.0)
		mark.modulate.a = 0.3
		mark.visible = true
		marks.append(mark)
		create_tween().tween_property(mark, ^"modulate:a", 1.0, mark_telegraph).set_ease(Tween.EASE_IN)
	Feel.sfx(&"deny", eye.global_position)
	_flare_body()
	_snap_pupil()
	_combo_hand()
	await get_tree().create_timer(mark_telegraph, false).timeout
	for mark in marks:
		if is_instance_valid(mark):
			if health.current > 0:
				_blast(Vector3(mark.global_position.x, 0.0, mark.global_position.z))
			mark.queue_free()
	_eye_attacking = false


## Una marca bajo el player y las otras alrededor; se queda con el primer reparto que deja salida a 2,4 m
## (contra las paredes las marcas se corren hacia adentro y pueden cerrarla). Si ninguno sirve, solo la del player.
func _mark_points() -> Array[Vector3]:
	var center := Vector3(target.global_position.x, 0.0, target.global_position.z) if is_instance_valid(target) else Vector3(arena.get_center().x, 0.0, arena.get_center().y)
	var first := _clamp_to_arena(center)
	for attempt in 8:
		var points: Array[Vector3] = [first]
		var angle := rng.randf() * TAU
		for i in mark_count - 1:
			points.append(_clamp_to_arena(center + Vector3(cos(angle), 0.0, sin(angle)) * mark_spacing))
			angle += TAU / float(mark_count) * rng.randf_range(0.8, 1.1)
		if _has_way_out(points, center):
			return points
	return [first] as Array[Vector3]


func _has_way_out(points: Array[Vector3], center: Vector3) -> bool:
	for step in 24:
		var angle := TAU * step / 24.0
		var spot := center + Vector3(cos(angle), 0.0, sin(angle)) * 2.4
		if not arena.grow(0.5).has_point(Vector2(spot.x, spot.z)):
			continue
		if points.all(func(point: Vector3) -> bool: return point.distance_to(spot) > mark_radius + 0.3):
			return true
	return false


func _clamp_to_arena(point: Vector3) -> Vector3:
	return Vector3(clampf(point.x, arena.position.x, arena.end.x), 0.0, clampf(point.z, arena.position.y, arena.end.y))


func _combo_hand() -> void:
	for hand in [hand_left, hand_right]:
		if hand.is_available() and is_instance_valid(target):
			for attack in attacks:
				if attack.id == BossAttack.SLAM:
					hand.perform(attack, target, arena)
					return


func _blast(point: Vector3) -> void:
	var blast := %BlastTemplate.duplicate() as MeshInstance3D
	add_child(blast)
	blast.global_position = point + Vector3.UP * 1.2
	blast.scale = Vector3(mark_radius, 1.0, mark_radius)
	blast.visible = true
	var fade := blast.create_tween()
	fade.tween_property(blast, ^"transparency", 1.0, 0.4)
	fade.tween_callback(blast.queue_free)
	Feel.sfx(&"boom", point)
	Feel.burst(&"dust", point, Vector3.UP)
	Feel.shake(0.3)
	var hit := %BlastHitTemplate.duplicate() as Hitbox
	add_child(hit)
	hit.global_position = point + Vector3.UP * 1.2
	hit.team = EntityConfig.Team.ENEMY
	hit.damage_factory = func() -> DamageInfo: return DamageInfo.make(mark_damage, 8.0, hit, &"blast")
	hit.monitoring = true
	for i in BLAST_FRAMES:
		await get_tree().physics_frame
	hit.queue_free()


## Las dos manos aturdidas o caídas: el ojo queda solo y suma el rayo.
func hands_out() -> bool:
	return [hand_left, hand_right].all(func(hand: BossHand) -> bool: return hand.state == BossHand.State.STUNNED or hand.state == BossHand.State.DOWN)


## Como el Ojo Vigía: marca una línea que cruza al player, carga y la barre con el rayo; el escudo no lo frena.
func _sweep_laser() -> void:
	_eye_attacking = true
	var center := Vector3(target.global_position.x, 0.0, target.global_position.z)
	var across := (center - Vector3(eye.global_position.x, 0.0, eye.global_position.z))
	across = Vector3.RIGHT if across.is_zero_approx() else across.normalized().cross(Vector3.UP)
	if rng.randf() < 0.5:
		across = -across
	_laser_from = _clamp_to_arena(center - across * laser_length / 2.0)
	_laser_to = _clamp_to_arena(center + across * laser_length / 2.0)
	var mid := (_laser_from + _laser_to) / 2.0
	_laser_path.global_position = Vector3(mid.x, target.global_position.y + 0.03, mid.z)
	if not _laser_to.is_equal_approx(_laser_from):
		_laser_path.global_basis = Basis.looking_at(_laser_to - _laser_from, Vector3.UP)
	_laser_path.scale = Vector3(1, 1, _laser_from.distance_to(_laser_to))
	_laser_path.visible = true
	Feel.sfx(&"click", eye.global_position)
	_laser_tween = create_tween()
	_laser_tween.tween_property(self, ^"_squint", 1.0, 0.2)
	_laser_tween.parallel().tween_method(_pulse_eye, 0.0, 1.0, laser_charge_time)
	await _laser_tween.finished
	if not _eye_attacking:
		return
	var floor_y := target.global_position.y if is_instance_valid(target) else 0.0
	_laser_spot.global_position = Vector3(_laser_from.x, floor_y, _laser_from.z)
	_laser_spot.team = EntityConfig.Team.ENEMY
	_laser_spot.damage_factory = func() -> DamageInfo: return DamageInfo.make(laser_damage, 6.0, _laser_spot, &"blast")
	_laser_spot.monitoring = true
	_laser_spot.visible = true
	_laser_beam.visible = true
	_place_laser()
	Feel.sfx(&"reflect", eye.global_position)
	_laser_tween = create_tween()
	_laser_tween.tween_property(_laser_spot, ^"global_position", Vector3(_laser_to.x, floor_y, _laser_to.z), laser_sweep_time)
	await _laser_tween.finished
	_end_laser()
	var relax := create_tween().set_parallel()
	relax.tween_property(self, ^"_squint", 0.0, 0.3)
	relax.tween_method(_set_eye_glow, EYE_GLOW_CHARGED, EYE_GLOW, 0.3)


func _end_laser() -> void:
	if _laser_tween:
		_laser_tween.kill()
	_laser_spot.set_deferred(&"monitoring", false)
	_laser_spot.visible = false
	_laser_beam.visible = false
	_laser_path.visible = false
	_eye_attacking = false


func _place_laser() -> void:
	var from := orb_muzzle.global_position
	var along := _laser_spot.global_position - from
	if along.length() < 0.01:
		return
	var up := along.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	_laser_beam.global_transform = Transform3D(Basis(side, up * along.length(), side.cross(up)), (from + _laser_spot.global_position) / 2.0)


func _fire_orb() -> void:
	_eye_attacking = true
	_charge.visible = true
	_charge.scale = Vector3.ONE * 0.1
	_charge_tween = create_tween()
	var grow := _charge_tween
	grow.tween_property(_charge, ^"scale", Vector3.ONE, orb_charge_time).set_ease(Tween.EASE_IN)
	grow.parallel().tween_property(self, ^"_squint", 1.0, 0.2)
	grow.parallel().tween_method(_pulse_eye, 0.0, 1.0, orb_charge_time)
	grow.parallel().tween_property(self, ^"_pupil_goal", 1.0, orb_charge_time).set_ease(Tween.EASE_IN)
	await grow.finished
	_charge.visible = false
	_eye_attacking = false
	_flare_body()
	_snap_pupil()
	var relax := create_tween().set_parallel()
	relax.tween_property(self, ^"_squint", 0.0, 0.3)
	relax.tween_method(_set_eye_glow, EYE_GLOW_CHARGED, EYE_GLOW, 0.3)
	if is_eye_stunned() or not is_instance_valid(target) or health.current <= 0:
		return
	var info := DamageInfo.make(orb_damage, 6.0, self)
	info.team = EntityConfig.Team.ENEMY
	info.reflectable = true
	var aim := target.global_position + Vector3.UP * 1.1
	var orb := Projectile.fire(ORB, self, orb_muzzle.global_position, (aim - orb_muzzle.global_position).normalized() * orb_speed, info)
	if phase() >= 3:
		orb.tint(CORRUPT_GLOW)
	Feel.sfx(&"click", orb_muzzle.global_position)


## Producto compensado: muchos factores no hunden el puntaje solo por ser muchos (Dave Mark).
static func compensated(values: Array) -> float:
	var make_up := 1.0 - 1.0 / values.size()
	var result := 1.0
	for value: float in values:
		result *= value + (1.0 - value) * make_up * value
	return result


## Presentación: el ojo se abre de par en par y grita.
func roar() -> void:
	var open := eye.create_tween()
	open.tween_property(self, ^"eye_open", 1.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open.tween_interval(roar_fx.duration)
	open.tween_property(self, ^"eye_open", 0.0, 0.4)
	roar_fx.play()


func look_at_point(point: Vector3) -> void:
	eye.look_at(point, Vector3.UP, true)


## Adónde mira la pupila: entre el blanco y la cámara, para que desde arriba se lea mirando al jugador; cuando dispara
## orbes (fases 2 y 3), más cerca del jugador.
func gaze_point(at: Vector3) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return at + Vector3.UP
	var toward_camera := GAZE_FIRING if phases.is_active() and phase() >= 2 and not _presenting else GAZE_CALM
	return (at + Vector3.UP).lerp(camera.global_position, toward_camera)


func hand_rest(hand: BossHand) -> Marker3D:
	return %HandRestLeft if hand == hand_left else %HandRestRight


func _users(attack: BossAttack) -> Array[Node3D]:
	var users: Array[Node3D] = []
	if attack.user == BossAttack.User.EYE:
		if eye_open >= 1.0 and not is_eye_stunned():
			users.append(eye)
	else:
		for hand in [hand_left, hand_right]:
			if hand.is_available():
				users.append(hand)
	return users


## 1 con el player dentro del rango ideal; cae a 0 a `falloff` metros del borde.
func _distance_score(attack: BossAttack, user: Node3D) -> float:
	if target == null:
		return 0.5
	var from := hand_rest(user).global_position if user is BossHand else user.global_position
	var distance := Vector2(from.x, from.z).distance_to(Vector2(target.global_position.x, target.global_position.z))
	var outside := maxf(attack.ideal_distance.x - distance, distance - attack.ideal_distance.y)
	return clampf(1.0 - outside / attack.falloff, 0.0, 1.0)


## Cerrado rebota; abierto, una flecha o un orbe devuelto lo aturde y recién ahí la espada lastima.
func _on_eye_hit(info: DamageInfo) -> void:
	if eye_open < 0.5 or _transforming:
		Feel.sfx(&"block", eye.global_position)
		return
	if is_eye_stunned():
		if health.damage(info.amount):
			Feel.sfx(&"hit", eye.global_position)
	elif info.source is Projectile:
		_stun_eye()
	else:
		Feel.sfx(&"block", eye.global_position)
		Feel.burst(&"sparks", eye.global_position, Vector3.BACK)


## Cae aturdido: el cuerpo baja a tiro de espada, el ojo mira al piso y deja de atacar.
func _stun_eye() -> void:
	_eye_stun_left = eye_stun_time
	Feel.sfx(&"deny", eye.global_position)
	Feel.burst(&"sparks", eye.global_position, Vector3.BACK)
	Feel.shake(0.3)
	_cut_charge()
	_squint = 0.0
	_pupil_goal = 0.0
	_set_eye_glow(EYE_GLOW)
	_move_body(BODY_HEIGHT_STUNNED, 0.35)
	look_at_point(eye.global_position + Vector3(0, -1, 0.4))


func _move_body(height: float, seconds: float) -> void:
	if _body_tween:
		_body_tween.kill()
	_body_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_body_tween.tween_property(self, ^"_body_height", height, seconds)


func _on_hand_downed() -> void:
	if hand_left.state == BossHand.State.DOWN and hand_right.state == BossHand.State.DOWN:
		phases.dispatch(&"hands_down")


## Como el inicio de la pelea: la cámara se acerca, `action` arranca la fase y el jefe grita; mientras, no ataca.
func _present(action: Callable, hold: float) -> void:
	_transforming = true
	if not presents_phases:
		action.call()
		return
	_presenting = true
	await TopDownCamera.reveal(self, action, hold, skippable_phases)
	_presenting = false


## El ojo se abre de golpe con un grito; el cuerpo baja un poco y ya se lo puede fijar.
func _on_phase2_entered() -> void:
	chosen_attack = null
	attacker = null
	%Solid.add_to_group(&"targetable")
	phase_changed.emit(2)
	await _present(_open_eye, PHASE_HOLD)
	_transforming = false
	await get_tree().create_timer(hands_back_delay, false).timeout
	if phase() == 2:
		for hand in [hand_left, hand_right]:
			hand.regenerate()


func _open_eye() -> void:
	Feel.sfx(&"rumble", eye.global_position, true)
	Feel.shake(0.6)
	_move_body(BODY_HEIGHT_OPEN, 0.8)
	var lids := create_tween()
	lids.tween_property(self, ^"eye_open", 0.15, 0.5).set_delay(0.3)
	lids.tween_property(self, ^"eye_open", 1.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lids.tween_callback(_awaken_flash)
	lids.tween_callback(roar_fx.play)


## Furia: el ojo grita, la máscara de oro se raja y estalla y queda el ojo corrupto, manos incluidas (Transform, que
## llama a _scream, _crack, _burst y _calm y cambia las mallas). Mientras, ni el ojo ni las manos atacan o reciben daño.
func _on_phase3_entered() -> void:
	_eye_stun_left = 0.0
	_cut_charge()
	for hand in [hand_left, hand_right]:
		hand.held = true
	_move_body(BODY_HEIGHT_OPEN, 0.4)
	phase_changed.emit(3)
	await _present(_transform.play.bind(&"transform"), _transform.get_animation(&"transform").length + 0.3)
	if _transform.is_playing():
		await _transform.animation_finished
	_transforming = false
	for hand in [hand_left, hand_right]:
		hand.held = false


func _scream() -> void:
	Feel.sfx(&"rumble", eye.global_position, _presenting)
	Feel.shake(0.7)
	roar_fx.play()
	_pupil_goal = 1.0
	_squint = 0.0
	var lids := create_tween()
	lids.tween_property(self, ^"eye_open", 0.3, 0.1)
	lids.tween_property(self, ^"eye_open", 1.0, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash.warn(1.4)
	create_tween().tween_method(_set_eye_glow, EYE_GLOW, EYE_GLOW_CHARGED * 1.5, 1.5)


func _crack() -> void:
	var spot := body.to_global(Vector3(rng.randf_range(-1.6, 1.6), rng.randf_range(-1.2, 1.6), 1.7))
	Feel.burst(&"sparks", spot, (spot - body.global_position).normalized(), _presenting)
	Feel.burst(&"shards", spot, (spot - body.global_position).normalized() + Vector3.UP, _presenting)
	Feel.sfx(&"block", spot, _presenting)
	Feel.shake(0.3)
	_flare_body()


func _burst() -> void:
	Feel.sfx(&"boom", eye.global_position, _presenting)
	Feel.shake(1.0)
	Feel.freeze(0.2, 0.2)
	for i in 6:
		var spot := body.to_global(Vector3(rng.randf_range(-2.0, 2.0), rng.randf_range(-1.5, 2.0), rng.randf_range(0.5, 1.8)))
		Feel.burst(&"explosion", spot, Vector3.UP, _presenting)
		Feel.burst(&"shards", spot, (spot - body.global_position).normalized() + Vector3.UP, _presenting)
	for hand in [hand_left, hand_right]:
		Feel.burst(&"explosion", hand.global_position, Vector3.UP, _presenting)
		Feel.burst(&"shards", hand.global_position, Vector3.UP, _presenting)
		hand.glow_color = CORRUPT_GLOW
	_charge.set_instance_shader_parameter(&"color", CORRUPT_GLOW)
	_awaken_flash()


func _calm() -> void:
	_pupil_goal = 0.0
	_set_eye_glow(EYE_GLOW)


## Corta la carga del orbe a mitad (aturdido o vencido): no dispara y el BT ya puede seguir.
func _cut_charge() -> void:
	if _charge_tween:
		_charge_tween.kill()
	_charge.visible = false
	_eye_attacking = false
	_end_laser()


func _on_defeated() -> void:
	%Solid.remove_from_group(&"targetable")
	_eye_stun_left = 0.0
	_cut_charge()
	eye_hurtbox.set_deferred(&"monitorable", false)
	for hand in [hand_left, hand_right]:
		hand.collapse()
	Feel.sfx(&"rumble", eye.global_position)
	Feel.shake(0.8)
	Feel.freeze(SLOW_MOTION_TIME, SLOW_MOTION)
	_play_death()
	DebugOverlay.watch("boss/phase", "derrotado")
	defeated.emit()


## En etapas: el neón se apaga titilando, saltan placas y explotan las juntas, y recién ahí se hunde.
func _play_death() -> void:
	if _body_tween:
		_body_tween.kill()
	_alive = false
	_squint = 0.0
	pupil = 1.0
	_apply_pupil()
	var death := create_tween()
	death.tween_property(self, ^"eye_open", 0.0, 0.6)
	death.parallel().tween_method(_set_eye_glow, EYE_GLOW_CHARGED, 0.0, 1.4).set_trans(Tween.TRANS_BOUNCE)
	death.parallel().tween_method(_set_body_glow, 1.0, 0.0, 1.4).set_trans(Tween.TRANS_BOUNCE)
	var base := body.position
	for i in 10:
		death.tween_property(body, ^"position", base + Vector3(0.15 * (1 if i % 2 else -1), 0, 0), 0.08)
		if i % 2 == 0:
			death.tween_callback(_joint_blast)
	death.tween_property(body, ^"position", Vector3(base.x, 0.2, base.z), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	death.parallel().tween_property(body, ^"scale", Vector3.ONE * 0.6, 1.2)
	death.tween_callback(func() -> void:
		Feel.burst(&"dust", Vector3(body.global_position.x, 0.1, body.global_position.z), Vector3.UP)
		Feel.shake(0.5)
		visible = false
		%Solid.process_mode = Node.PROCESS_MODE_DISABLED
		death_finished.emit())


## Al soltar un ataque la pupila se cierra de golpe en rendija y vuelve sola.
func _snap_pupil() -> void:
	pupil = -1.0
	_pupil_goal = -1.0
	var back := create_tween()
	back.tween_interval(0.35)
	back.tween_property(self, ^"_pupil_goal", 0.0, 0.5)


func _apply_pupil() -> void:
	if _pupil_keys.x >= 0:
		_eye_mesh.set_blend_shape_value(_pupil_keys.x, maxf(-pupil, 0.0))
	if _pupil_keys.y >= 0:
		_eye_mesh.set_blend_shape_value(_pupil_keys.y, maxf(pupil, 0.0))


func _apply_lids() -> void:
	var open := eye_open * (1.0 - _blink) * (1.0 - SQUINT * _squint)
	_upper_lid.rotation.x = deg_to_rad(-LID_OPEN_ANGLE * open)
	_lower_lid.rotation.x = deg_to_rad(LID_OPEN_ANGLE * open)


## Brillo del neón del ojo relativo al de la paleta (1 = normal).
func eye_glow() -> float:
	return _eye_material.emission_energy_multiplier / _eye_base_glow if _eye_material else EYE_GLOW


func _own_material(mesh: MeshInstance3D) -> StandardMaterial3D:
	var material := mesh.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	mesh.material_override = material
	return material


func _set_eye_glow(value: float) -> void:
	_eye_material.emission_energy_multiplier = _eye_base_glow * value


func _set_body_glow(value: float) -> void:
	_body_material.emission_energy_multiplier = _body_base_glow * value


## El iris late cada vez más rápido mientras crece el orbe.
func _pulse_eye(progress: float) -> void:
	var beat := 0.5 + 0.5 * sin(progress * progress * 14.0 * PI)
	_set_eye_glow(lerpf(EYE_GLOW, EYE_GLOW_CHARGED, progress * (0.6 + 0.4 * beat)))


## La boca de horno se enciende en cada ataque.
func _flare_body() -> void:
	if not _alive:
		return
	var flare := create_tween()
	flare.tween_method(_set_body_glow, 3.0, 1.0, 0.5).set_ease(Tween.EASE_OUT)


## Se abren los párpados de golpe: destello del ojo y polvo que cae del techo.
func _awaken_flash() -> void:
	_flash.warn(0.05)
	var glow := create_tween()
	glow.tween_method(_set_eye_glow, EYE_GLOW_CHARGED * 1.5, EYE_GLOW, 0.6)
	Feel.shake(0.4)
	for i in 6:
		var spot := Vector3(rng.randf_range(arena.position.x, arena.end.x), 6.0, rng.randf_range(arena.position.y, arena.end.y))
		Feel.burst(&"shards", spot, Vector3.DOWN, _presenting)
		Feel.burst(&"dust", spot, Vector3.DOWN, _presenting)


func _joint_blast() -> void:
	var spot := body.global_position + Vector3(rng.randf_range(-2.0, 2.0), rng.randf_range(-1.5, 1.0), rng.randf_range(0.5, 1.8))
	Feel.burst(&"explosion", spot, Vector3.UP)
	Feel.burst(&"shards", spot, (spot - body.global_position).normalized() + Vector3.UP)
	Feel.sfx(&"boom", spot)
	Feel.shake(0.25)
