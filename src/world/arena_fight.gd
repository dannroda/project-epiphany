class_name ArenaFight
extends Node3D
## Pelea de sub-jefe o jefe en una sala. Sus hijos pelean dentro de ella (WatcherEye, MummyGuard: los que tienen
## `attack_finished`): al entrar el player se cierran las puertas, la cámara muestra al primero con el nombre y arranca,
## con la barra del HUD. De a uno ataca por vez; cuando cae uno, los demás se apuran. Si el player sale de la sala,
## la pelea vuelve a empezar. Hace de interruptor (`active`/`activated`) para lo que se abre al ganar; con flag,
## ganada queda ganada.

signal activated
signal bar_changed

const SKIP_ACTIONS: Array[StringName] = [&"ui_accept", &"attack", &"interact"]

@export var room: Room
@export var flag: StringName:
	set(value):
		flag = value
		update_configuration_warnings()
@export var display_name := ""
## Se cierran durante la pelea y se abren al ganar.
@export var doors: Array[Door] = []
## Aparece al ganar (el contenedor de corazón): queda fuera del árbol hasta entonces; tomado, no vuelve.
@export var reward: Pickup
@export var reward_flag: StringName
@export var arena_margin := 1.5
@export var close_delay := 0.6
@export var intro_hold := 1.6
## Lo que se apuran los que quedan al caer uno.
@export var enrage_pace := 1.4

var active := false
var started := false
var in_intro := false
var _fighters: Array = []
var _attacker = null
var _persistent: PersistentFlag


func _ready() -> void:
	for child in get_children():
		if child.has_signal(&"attack_finished"):
			_fighters.append(child)
	if reward:
		remove_child(reward)
	_persistent = $PersistentFlag
	_persistent.flag = flag
	if _persistent.value == true:
		_already_won()
		return
	var bounds := room.bounds().grow(-arena_margin)
	for fighter in _fighters:
		fighter.arena = bounds
		fighter.may_attack = _may_attack
		fighter.peers = _fighters
		fighter.attack_finished.connect(_on_attack_finished.bind(fighter))
		fighter.defeated.connect(_on_defeated)
		fighter.health_changed.connect(bar_changed.emit)
	room.player_entered.connect(func(_room: Room) -> void: _begin())
	room.player_left.connect(func(_room: Room) -> void: _reset())


func _get_configuration_warnings() -> PackedStringArray:
	return PersistentFlag.warnings_for(flag, true)


func _begin() -> void:
	if started or active:
		return
	started = true
	await get_tree().create_timer(close_delay, false).timeout
	if not started:
		return
	for door in doors:
		door.close()
	in_intro = true
	Music.boss_fight = true
	await TopDownCamera.reveal(_fighters[0].body, _awaken, intro_hold)
	in_intro = false
	if not started:
		return
	get_tree().call_group(Hud.GROUP, &"show_boss", self)
	for fighter in _fighters:
		fighter.start()


func _awaken() -> void:
	get_tree().call_group(Hud.GROUP, &"show_area_name", tr(display_name))
	Feel.sfx(&"rumble", _fighters[0].body.global_position)
	Feel.shake(0.35)


func _unhandled_input(event: InputEvent) -> void:
	if not in_intro:
		return
	for action in SKIP_ACTIONS:
		if event.is_action_pressed(action):
			get_tree().call_group(TopDownCamera.GROUP, &"skip_reveal")
			get_viewport().set_input_as_handled()
			return


## El player salió (cayó por un hueco): todo como al llegar.
func _reset() -> void:
	if not started or active:
		return
	started = false
	_attacker = null
	Music.boss_fight = false
	get_tree().call_group(Hud.GROUP, &"hide_boss")
	for fighter in _fighters:
		fighter.reset()
	for door in doors:
		door.open(false)


func _may_attack(fighter) -> bool:
	if is_instance_valid(_attacker) and _attacker != fighter and not _attacker.is_dead:
		return false
	_attacker = fighter
	return true


func _on_attack_finished(fighter) -> void:
	if _attacker == fighter:
		_attacker = null


func _on_defeated(_fighter) -> void:
	bar_changed.emit()
	var left := _fighters.filter(func(fighter) -> bool: return not fighter.is_dead)
	for fighter in left:
		fighter.pace = enrage_pace
	if left.is_empty():
		await get_tree().create_timer(1.2, false).timeout
		_win(true)


func _win(announce: bool) -> void:
	active = true
	started = false
	_persistent.value = true
	Music.boss_fight = false
	get_tree().call_group(Hud.GROUP, &"hide_boss")
	for door in doors:
		door.open()
	_show_reward()
	if announce:
		Feel.sfx(&"secret", global_position)
		SaveManager.autosave()
	activated.emit()


func _already_won() -> void:
	active = true
	for fighter in _fighters:
		fighter.queue_free()
	_show_reward()


func _show_reward() -> void:
	if reward == null or reward.is_inside_tree() or GameState.get_flag(reward_flag) == true:
		return
	add_child(reward)
	reward.collected.connect(func() -> void: GameState.set_flag(reward_flag, true))


## Barra del HUD: la vida que les queda a todos.
func bar_fraction() -> float:
	var total := 0
	var left := 0
	for fighter in _fighters:
		total += fighter.health.max_health
		left += maxi(fighter.health.current, 0)
	return float(left) / maxf(total, 1)


func phase() -> int:
	return 0


func _exit_tree() -> void:
	if started:
		Music.boss_fight = false
	if reward and not reward.is_inside_tree():
		reward.queue_free()
