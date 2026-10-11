class_name ControlsView
extends Control
## Los controles básicos de un dispositivo: el mando dibujado o los grupos de teclado y mouse. `view_scale` achica
## los dos dibujos (la pestaña Sistema de la pausa los muestra más chicos).

signal device_changed(gamepad: bool)

const BASE_SIZE := Vector2(1040, 440)

@export var view_scale := 1.0

var gamepad := true:
	set(value):
		gamepad = value
		if is_node_ready():
			_show()

@onready var pad_diagram: Control = $Gamepad
@onready var keyboard_diagram: Control = $Keyboard


func _ready() -> void:
	custom_minimum_size = BASE_SIZE * view_scale
	for diagram in [pad_diagram, keyboard_diagram]:
		diagram.scale = Vector2.ONE * view_scale
	_show()


func use_current_device() -> void:
	gamepad = InputDevice.current == InputDevice.Device.GAMEPAD


func toggle() -> void:
	gamepad = not gamepad


func _show() -> void:
	pad_diagram.visible = gamepad
	keyboard_diagram.visible = not gamepad
	device_changed.emit(gamepad)
