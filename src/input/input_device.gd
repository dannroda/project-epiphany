# Autoload
extends Node
## Qué dispositivo usó el jugador último: el HUD lo usa para mostrar el ícono correcto (4.1).

signal input_device_changed(device: Device)

enum Device { KEYBOARD_MOUSE, GAMEPAD }

## Movimientos de stick más chicos que esto no cambian el dispositivo (drift).
@export var stick_threshold := 0.4
## Movimientos de mouse más chicos que esto (en píxeles) tampoco.
@export var mouse_threshold := 4.0

var current: Device = Device.KEYBOARD_MOUSE


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_switch_to(Device.GAMEPAD)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > stick_threshold:
		_switch_to(Device.GAMEPAD)
	elif event is InputEventKey or event is InputEventMouseButton:
		_switch_to(Device.KEYBOARD_MOUSE)
	elif event is InputEventMouseMotion and event.relative.length() > mouse_threshold:
		_switch_to(Device.KEYBOARD_MOUSE)


func _switch_to(device: Device) -> void:
	if device == current:
		return
	current = device
	Log.debug(&"input", "Dispositivo:", Device.find_key(device))
	input_device_changed.emit(device)
