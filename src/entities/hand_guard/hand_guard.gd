class_name HandGuard
extends ArenaFighter
## La Mano, sub-jefe del templo: uno de los guanteletes del jefe, suelto (los mismos ataques que en la pelea final).
## Lista, todo rebota; después del golpe al piso queda aturdida y ahí le pega la espada. La maneja un ArenaFight.

@export var attacks: Array[BossAttack] = []
@export var rest_time := 0.8

@onready var hand: BossHand = %Hand
@onready var rest: Marker3D = %Rest
@onready var roar_fx: Roar = %Roar

var _running := false
var _last: BossAttack

func _ready() -> void:
	body = hand
	health = hand.health
	hand.rest = rest
	hand.health.changed.connect(func(_current: int, _max_value: int) -> void: health_changed.emit())
	hand.downed.connect(func() -> void:
		_turn += 1
		remove_from_group(Enemy.GROUP)
		defeated.emit(self))


func start() -> void:
	if _running or is_dead:
		return
	_running = true
	add_to_group(Enemy.GROUP)
	_run()


## Presentación: cierra el puño y lo abre de golpe con el grito.
func roar() -> void:
	hand.pose = BossHand.Pose.FIST
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_callback(func() -> void:
		hand.pose = BossHand.Pose.OPEN
		roar_fx.play()).set_delay(0.3)


func reset() -> void:
	_interrupt()
	_running = false
	remove_from_group(Enemy.GROUP)
	hand.reset()


func is_vulnerable() -> bool:
	return hand.state == BossHand.State.STUNNED


func _is_idle() -> bool:
	return not _running


func _is_dead() -> bool:
	return hand.state == BossHand.State.DOWN


func _die() -> void:
	pass


func _run() -> void:
	var turn := _turn
	await _wait(0.6, false)
	while turn == _turn and not is_dead:
		var player := Players.nearest(hand.global_position)
		if player == null or not hand.is_available() or (may_attack.is_valid() and not may_attack.call(self)):
			await _wait(0.2, false)
			continue
		await hand.perform(_choose(), player, arena)
		while turn == _turn and hand.state == BossHand.State.STUNNED:
			await get_tree().physics_frame
		if turn != _turn:
			return
		attack_finished.emit()
		await _wait(rest_time)


func _choose() -> BossAttack:
	var options := attacks.filter(func(attack: BossAttack) -> bool: return attack != _last)
	_last = options.pick_random() if not options.is_empty() else attacks[0]
	return _last
