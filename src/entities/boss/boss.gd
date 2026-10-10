@tool
class_name Boss
extends Node3D
## El Ojo con manos (gdd §9). Sin esqueleto: el ojo gira entero hacia lo que mira, los párpados de hierro se abren
## rotando en X y las manos flotan sueltas (vuelven a su reposo, al lado del cuerpo).
## Fases con LimboHSM (cada una corre su BT); el BT le pide el ataque a `choose_attack` (utilidad).

signal defeated

const LID_OPEN_ANGLE := 70.0
const EYE_STUN_TIME := 3.0
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

var target: Node3D
var chosen_attack: BossAttack
var attacker: Node3D
var rng := RandomNumberGenerator.new()
var _eye_stun_left := 0.0

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
	for hand in [hand_left, hand_right]:
		hand.global_position = hand_rest(hand).global_position
		hand.downed.connect(_on_hand_downed)
	eye_hurtbox.team = EntityConfig.Team.ENEMY
	eye_hurtbox.hit.connect(_on_eye_hit)
	health.died.connect(func() -> void: phases.dispatch(&"died"))
	HitFlash.attach(eye, health)
	phases.add_transition($Phases/Phase1, $Phases/Phase2, &"hands_down")
	phases.add_transition($Phases/Phase2, $Phases/Defeated, &"died")
	$Phases/Phase2.entered.connect(_on_phase2_entered)
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


func is_eye_stunned() -> bool:
	return _eye_stun_left > 0.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not phases.is_active():
		return
	_eye_stun_left = maxf(_eye_stun_left - delta, 0.0)
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
		health.damage(info.amount)
	elif info.source is Projectile:
		_eye_stun_left = EYE_STUN_TIME
		Feel.sfx(&"deny", eye.global_position)
	else:
		Feel.sfx(&"block", eye.global_position)


func _on_hand_downed() -> void:
	if hand_left.state == BossHand.State.DOWN and hand_right.state == BossHand.State.DOWN:
		phases.dispatch(&"hands_down")


func _on_phase2_entered() -> void:
	chosen_attack = null
	attacker = null
	create_tween().tween_property(self, ^"eye_open", 1.0, 0.8)
	for hand in [hand_left, hand_right]:
		hand.regenerate()


func _on_defeated() -> void:
	DebugOverlay.watch("boss/phase", "derrotado")
	defeated.emit()


func _apply_lids() -> void:
	%UpperLid.rotation.x = deg_to_rad(-LID_OPEN_ANGLE * eye_open)
	%LowerLid.rotation.x = deg_to_rad(LID_OPEN_ANGLE * eye_open)
