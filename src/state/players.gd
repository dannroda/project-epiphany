# Autoload
extends Node
## Los players en juego (co-op, M13). Ningún sistema asume uno solo: la IA y lo que busca a alguien eligen al más
## cercano y la cámara encuadra a todos; lo que todavía es de uno (guardado, menús, HUD) usa al primero, `lead()`,
## hasta 13.5.
## Start en un control libre suma un player (13.2); mantener Start en el suyo lo saca. Los invitados vuelven a
## aparecer al lado del primero en cada escena.

signal joined(player: PlayerCharacter)
signal left(player: PlayerCharacter)

const PLAYER_SCENE := "res://player/player.tscn"
## Por ahora el co-op es de dos (los puzzles y el HUD para 3–4 vienen después).
const MAX_PLAYERS := 2
## Mantener Start este rato saca al invitado; un toque pausa, como el de cualquiera.
const LEAVE_HOLD := 1.5
const JOIN_SPACING := 1.2

var all: Array[PlayerCharacter] = []
## Slot (1..) → control de cada invitado. El primero (slot 0) tiene el teclado y los controles que sobran.
var guests: Dictionary[int, int] = {}
## El control que venía usando el primero antes de que entre alguien (-1: solo teclado hasta ahora).
var lead_pad := -1
var _start_held: Dictionary[int, float] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool) -> void: _assign_lead())


func register(player: PlayerCharacter) -> void:
	if all.has(player):
		return
	all.append(player)
	all.sort_custom(func(a: PlayerCharacter, b: PlayerCharacter) -> bool: return a.controls.slot < b.controls.slot)
	joined.emit(player)
	if player.controls.slot == 0:
		_assign_lead()
		_spawn_guests.call_deferred()


func unregister(player: PlayerCharacter) -> void:
	if all.has(player):
		all.erase(player)
		left.emit(player)


func lead() -> PlayerCharacter:
	return all[0] if not all.is_empty() else null


func alive() -> Array[PlayerCharacter]:
	return all.filter(func(player: PlayerCharacter) -> bool: return not player.is_dead)


func any_alive() -> bool:
	return not alive().is_empty()


## El más cercano a `point` (en XZ), vivo salvo que `living` sea false; null si no hay.
func nearest(point: Vector3, living := true) -> PlayerCharacter:
	var best: PlayerCharacter = null
	var best_distance := INF
	for player in (alive() if living else all):
		var distance := Vector2(player.global_position.x - point.x, player.global_position.z - point.z).length()
		if distance < best_distance:
			best = player
			best_distance = distance
	return best


func slot_of_pad(pad: int) -> int:
	for slot in guests:
		if guests[slot] == pad:
			return slot
	return -1


## Con un solo control conectado y el primero en teclado, ese control es del primero (su Start pausa).
func can_join(pad: int) -> bool:
	if lead_pad == -1 and Input.get_connected_joypads().size() <= 1:
		return false
	var first := lead()
	return first != null and not first.is_dead and not get_tree().paused and slot_of_pad(pad) == -1 \
		and pad != lead_pad and guests.size() + 1 < MAX_PLAYERS


## Suma un player con el control `pad`, al lado del primero.
func join(pad: int) -> PlayerCharacter:
	if not can_join(pad):
		return null
	var slot := 1
	while guests.has(slot):
		slot += 1
	guests[slot] = pad
	_assign_lead()
	var player := _spawn(slot)
	Log.info(&"coop", "Entró el player", slot + 1, "con el control", pad)
	return player


func leave(slot: int) -> void:
	if not guests.has(slot):
		return
	guests.erase(slot)
	for player in all.duplicate():
		if player.controls.slot == slot:
			player.queue_free()
	_assign_lead()
	Log.info(&"coop", "Salió el player", slot + 1)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		if lead_pad == -1 and guests.is_empty() and slot_of_pad(event.device) == -1:
			lead_pad = event.device
	if not (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START):
		return
	var slot := slot_of_pad(event.device)
	if slot > 0:
		get_viewport().set_input_as_handled()
		if event.pressed:
			_start_held[event.device] = 0.0
		elif _start_held.has(event.device):
			_start_held.erase(event.device)
			_tap_pause()
	elif event.pressed and can_join(event.device):
		get_viewport().set_input_as_handled()
		join(event.device)


func _process(delta: float) -> void:
	for pad in _start_held.keys():
		_start_held[pad] += delta
		if _start_held[pad] >= LEAVE_HOLD:
			_start_held.erase(pad)
			leave(slot_of_pad(pad))


## El Start de un invitado pausa igual que el del primero (los menús son de todos).
func _tap_pause() -> void:
	for pressed in [true, false]:
		var pause := InputEventAction.new()
		pause.action = &"pause"
		pause.pressed = pressed
		Input.parse_input_event(pause)


## Solo: lee todo (las acciones de siempre). Con invitados: el teclado y los controles que no son de nadie.
func _assign_lead() -> void:
	var first := lead()
	if first == null:
		return
	if guests.is_empty():
		first.controls.share()
		return
	var pads: Array[int] = []
	for pad in Input.get_connected_joypads() + [lead_pad]:
		if pad >= 0 and slot_of_pad(pad) == -1 and not pads.has(pad):
			pads.append(pad)
	first.controls.assign(true, pads)


func _spawn_guests() -> void:
	for slot in guests:
		if not all.any(func(player: PlayerCharacter) -> bool: return player.controls.slot == slot):
			_spawn(slot)


func _spawn(slot: int) -> PlayerCharacter:
	var first := lead()
	var scene := get_tree().current_scene
	if first == null or scene == null:
		return null
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerCharacter
	player.name = "Player%d" % (slot + 1)
	player.controls.slot = slot
	player.controls.assign(false, [guests[slot]] as Array[int])
	scene.add_child(player)
	player.global_position = first.global_position + Vector3.RIGHT * JOIN_SPACING * slot
	return player
