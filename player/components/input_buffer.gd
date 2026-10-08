class_name InputBuffer
extends Node
## Recuerda una acción apretada por un rato, para que salga aunque se apriete un poco antes de tiempo.

@export var window := 0.15
@export var actions: Array[StringName] = [&"attack", &"dodge", &"item_1", &"item_2"]

var _pressed_at: Dictionary[StringName, float] = {}


func _unhandled_input(event: InputEvent) -> void:
	for action in actions:
		if event.is_action_pressed(action):
			_pressed_at[action] = _now()


func has(action: StringName) -> bool:
	return _pressed_at.has(action) and _now() - _pressed_at[action] <= window


func consume(action: StringName) -> void:
	_pressed_at.erase(action)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
