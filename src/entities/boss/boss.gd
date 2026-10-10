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
const ORB := preload("res://src/entities/projectile.tscn")
const EYE_STUN_TIME := 3.0
## Las manos vuelven un rato después de que se abre el ojo.
const HANDS_BACK_DELAY := 1.2
## Alto del cuerpo en la fase 2 (más cerca para mirarte) y aturdido (caído, a tiro de espada).
const BODY_HEIGHT_OPEN := 2.6
const BODY_HEIGHT_STUNNED := 1.9
const REPEAT_PENALTY := 0.25
const SAME_HAND_PENALTY := 0.7
## Entran al sorteo los que tienen al menos esta fracción del mejor puntaje.
const SHORTLIST := 0.75

## 0 cerrado, 1 abierto.
@export_range(0.0, 1.0) var eye_open := 0.0:
	set(value):
		eye_open = value
		if is_inside_tree():
			_apply_lids()
@export var attacks: Array[BossAttack] = []
@export var display_name := "El Ojo Antiguo"
@export var orb_damage := 4
@export var orb_speed := 9.0
@export var orb_charge_time := 0.8

var target: Node3D
## Piso de la pelea (XZ global); lo pone `BossArena` con la sala. Las manos no salen de acá.
var arena: Rect2
var chosen_attack: BossAttack
var attacker: Node3D
var rng := RandomNumberGenerator.new()
var _eye_stun_left := 0.0
var _eye_attacking := false
var _body_tween: Tween

@onready var body: Node3D = $Body
@onready var eye: Node3D = %Eye
@onready var orb_muzzle: Marker3D = %OrbMuzzle
@onready var hand_left: BossHand = $HandLeft
@onready var hand_right: BossHand = $HandRight
@onready var health: Health = $Health
@onready var eye_hurtbox: Hurtbox = %EyeHurtbox
@onready var phases: LimboHSM = $Phases


func _ready() -> void:
	_apply_lids()
	if Engine.is_editor_hint():
		return
	arena = Rect2(global_position.x - 9.0, global_position.z - 3.0, 18.0, 10.0)
	for hand in [hand_left, hand_right]:
		hand.rest = hand_rest(hand)
		hand.global_position = hand.rest.global_position
		hand.downed.connect(_on_hand_downed)
	eye_hurtbox.team = EntityConfig.Team.ENEMY
	eye_hurtbox.hit.connect(_on_eye_hit)
	health.died.connect(func() -> void: phases.dispatch(&"died"))
	HitFlash.attach(eye, health)
	phases.add_transition($Phases/Phase1, $Phases/Phase2, &"hands_down")
	phases.add_transition($Phases/Phase2, $Phases/Defeated, &"died")
	$Phases/Phase1.entered.connect(func() -> void: phase_changed.emit(1))
	$Phases/Phase2.entered.connect(_on_phase2_entered)
	health.changed.connect(func(_c: int, _m: int) -> void: bar_changed.emit())
	for hand in [hand_left, hand_right]:
		hand.health.changed.connect(func(_c: int, _m: int) -> void: bar_changed.emit())
	phase_changed.connect(func(_p: int) -> void: bar_changed.emit())
	$Phases/Defeated.entered.connect(_on_defeated)


func start_fight() -> void:
	target = get_tree().get_first_node_in_group(&"player") as Node3D
	phases.initialize(self)
	phases.set_active(true)


func phase() -> int:
	var state := phases.get_active_state() if phases.is_active() else null
	if state == null:
		return 0
	return {&"Phase1": 1, &"Phase2": 2}.get(state.name, 0)


## Barra del HUD: en la fase 1, la vida que les queda a las dos manos; después, la del ojo.
func bar_fraction() -> float:
	if phase() == 2 or health.current == 0:
		return health.current / float(health.max_health)
	var left := hand_left.health.current + hand_right.health.current
	return left / float(hand_left.health.max_health + hand_right.health.max_health)


func is_eye_stunned() -> bool:
	return _eye_stun_left > 0.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not phases.is_active():
		return
	if _eye_stun_left > 0.0:
		_eye_stun_left -= delta
		if _eye_stun_left <= 0.0:
			_move_body(BODY_HEIGHT_OPEN, 0.6)
	if is_instance_valid(target) and not is_eye_stunned():
		var wanted := (target.global_position + Vector3.UP - eye.global_position).normalized()
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
	if is_eye_stunned():
		return false
	var options: Array[Array] = []
	var best_score := 0.0
	for attack in attacks:
		if not for_phase in attack.phases:
			continue
		for user in _users(attack):
			var score := attack.weight * compensated([
				_distance_score(attack, user),
				REPEAT_PENALTY if chosen_attack and attack.id == chosen_attack.id else 1.0,
				SAME_HAND_PENALTY if user == attacker and user is BossHand else 1.0,
			])
			if score > 0.0:
				options.append([score, attack, user])
				best_score = maxf(best_score, score)
	options = options.filter(func(option: Array) -> bool: return option[0] >= best_score * SHORTLIST)
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
	if attacker is BossHand:
		attacker.perform(chosen_attack, target, arena)
	elif attacker == eye:
		_fire_orb()


## El BT espera a que la mano termine de golpear (no a que se reponga): la otra puede atacar mientras.
func is_attack_running() -> bool:
	return _eye_attacking or (attacker is BossHand and attacker.striking)


## El ojo carga (la bola de luz crece en la salida) y escupe un orbe que el escudo espejo puede devolver.
func _fire_orb() -> void:
	_eye_attacking = true
	var charge: MeshInstance3D = %Charge
	charge.visible = true
	charge.scale = Vector3.ONE * 0.1
	var grow := create_tween()
	grow.tween_property(charge, ^"scale", Vector3.ONE, orb_charge_time).set_ease(Tween.EASE_IN)
	await grow.finished
	charge.visible = false
	_eye_attacking = false
	if is_eye_stunned() or not is_instance_valid(target) or health.current <= 0:
		return
	var info := DamageInfo.new()
	info.amount = orb_damage
	info.knockback = 6.0
	info.source = self
	info.team = EntityConfig.Team.ENEMY
	info.reflectable = true
	var orb: Projectile = ORB.instantiate()
	get_tree().current_scene.add_child(orb)
	var aim := target.global_position + Vector3.UP * 1.1
	orb.launch(orb_muzzle.global_position, (aim - orb_muzzle.global_position).normalized() * orb_speed, info)
	Feel.sfx(&"click", orb_muzzle.global_position)


## Producto compensado: muchos factores no hunden el puntaje solo por ser muchos (Dave Mark).
static func compensated(values: Array) -> float:
	var make_up := 1.0 - 1.0 / values.size()
	var result := 1.0
	for value: float in values:
		result *= value + (1.0 - value) * make_up * value
	return result


func look_at_point(point: Vector3) -> void:
	eye.look_at(point, Vector3.UP, true)


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
	if eye_open < 0.5:
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
	_eye_stun_left = EYE_STUN_TIME
	Feel.sfx(&"deny", eye.global_position)
	Feel.burst(&"sparks", eye.global_position, Vector3.BACK)
	Feel.shake(0.3)
	%Charge.visible = false
	_move_body(BODY_HEIGHT_STUNNED, 0.35)
	look_at_point(eye.global_position + Vector3(0, -1, 0.4))


func _move_body(height: float, seconds: float) -> void:
	if _body_tween:
		_body_tween.kill()
	_body_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_body_tween.tween_property(body, ^"position:y", height, seconds)


func _on_hand_downed() -> void:
	if hand_left.state == BossHand.State.DOWN and hand_right.state == BossHand.State.DOWN:
		phases.dispatch(&"hands_down")


## El ojo se abre con un temblor; el cuerpo baja un poco y ya se lo puede fijar.
func _on_phase2_entered() -> void:
	chosen_attack = null
	attacker = null
	Feel.sfx(&"rumble", eye.global_position)
	Feel.shake(0.6)
	_move_body(BODY_HEIGHT_OPEN, 0.8)
	create_tween().tween_property(self, ^"eye_open", 1.0, 0.8).set_delay(0.3)
	%Solid.add_to_group(&"targetable")
	phase_changed.emit(2)
	await get_tree().create_timer(HANDS_BACK_DELAY, false).timeout
	if phase() == 2:
		for hand in [hand_left, hand_right]:
			hand.regenerate()


## Las manos caen, el ojo se cierra, el cuerpo tiembla soltando polvo y se hunde.
func _on_defeated() -> void:
	%Solid.remove_from_group(&"targetable")
	_eye_stun_left = 0.0
	%Charge.visible = false
	eye_hurtbox.set_deferred(&"monitorable", false)
	for hand in [hand_left, hand_right]:
		hand.collapse()
	Feel.sfx(&"rumble", eye.global_position)
	Feel.shake(0.8)
	_play_death()
	DebugOverlay.watch("boss/phase", "derrotado")
	defeated.emit()


func _play_death() -> void:
	if _body_tween:
		_body_tween.kill()
	var death := create_tween()
	death.tween_property(self, ^"eye_open", 0.0, 0.6)
	var base := body.position
	for i in 10:
		death.tween_property(body, ^"position", base + Vector3(0.15 * (1 if i % 2 else -1), 0, 0), 0.08)
		if i % 3 == 0:
			death.tween_callback(func() -> void:
				Feel.burst(&"dust", body.global_position + Vector3(randf_range(-2, 2), -1.5, 1.5), Vector3.UP)
				Feel.sfx(&"boom", body.global_position))
	death.tween_property(body, ^"position", Vector3(base.x, 0.2, base.z), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	death.parallel().tween_property(body, ^"scale", Vector3.ONE * 0.6, 1.2)
	death.tween_callback(func() -> void:
		Feel.burst(&"dust", Vector3(body.global_position.x, 0.1, body.global_position.z), Vector3.UP)
		Feel.shake(0.5)
		visible = false
		%Solid.process_mode = Node.PROCESS_MODE_DISABLED
		death_finished.emit())


func _apply_lids() -> void:
	%UpperLid.rotation.x = deg_to_rad(-LID_OPEN_ANGLE * eye_open)
	%LowerLid.rotation.x = deg_to_rad(LID_OPEN_ANGLE * eye_open)
