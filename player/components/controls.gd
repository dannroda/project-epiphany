extends Node
## Qué acciones lee este player. Jugando solo (`shared`) son las de siempre: el teclado y cualquier control.
## En co-op cada player tiene sus copias `p<slot>_<acción>` con los eventos de sus dispositivos (13.2).

const ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_forward", &"move_backward",
	&"look_left", &"look_right", &"look_up", &"look_down",
	&"attack", &"interact", &"dodge", &"block", &"item_1", &"item_2",
	&"z-lock", &"target_prev", &"target_next",
]

var slot := 0
var shared := true
var keyboard := true
var joypads: Array[int] = []


func action(name: StringName) -> StringName:
	return name if shared else StringName("p%d_%s" % [slot, name])


## Teclado y mouse más los controles `pads`; cada acción se copia con solo esos eventos.
func assign(with_keyboard: bool, pads: Array[int]) -> void:
	shared = false
	keyboard = with_keyboard
	joypads = pads.duplicate()
	for name in ACTIONS:
		var id := action(name)
		if InputMap.has_action(id):
			InputMap.action_erase_events(id)
		else:
			InputMap.add_action(id, InputMap.action_get_deadzone(name))
		for event in InputMap.action_get_events(name):
			if event is InputEventKey or event is InputEventMouseButton:
				if keyboard:
					InputMap.action_add_event(id, event)
			elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
				for pad in joypads:
					var copy := event.duplicate() as InputEvent
					copy.device = pad
					InputMap.action_add_event(id, copy)


func share() -> void:
	shared = true
	keyboard = true
	joypads.clear()


func owns(event: InputEvent) -> bool:
	if shared:
		return true
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return joypads.has(event.device)
	return keyboard


## Si muestra los íconos del gamepad: solo con control, sí; con teclado, el último dispositivo que se usó.
func uses_gamepad() -> bool:
	if not shared and not keyboard:
		return true
	return InputDevice.current == InputDevice.Device.GAMEPAD


func pressed(name: StringName) -> bool:
	return Input.is_action_pressed(action(name))


func just_pressed(name: StringName) -> bool:
	return Input.is_action_just_pressed(action(name))


func vector(negative_x: StringName, positive_x: StringName, negative_y: StringName, positive_y: StringName, deadzone := -1.0) -> Vector2:
	return Input.get_vector(action(negative_x), action(positive_x), action(negative_y), action(positive_y), deadzone)


func move() -> Vector2:
	return vector(&"move_left", &"move_right", &"move_forward", &"move_backward")


func look(deadzone := -1.0) -> Vector2:
	return vector(&"look_left", &"look_right", &"look_up", &"look_down", deadzone)


func event_pressed(event: InputEvent, name: StringName) -> bool:
	return event.is_action_pressed(action(name))


func event_released(event: InputEvent, name: StringName) -> bool:
	return event.is_action_released(action(name))
