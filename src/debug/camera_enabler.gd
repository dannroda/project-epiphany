class_name CameraEnabler
extends CheckButton

@export var camera:Camera3D

func _ready() -> void:
	if camera and camera.current:
		set_pressed_no_signal(true)
	else:
		set_pressed_no_signal(false)

func _pressed() -> void:
	if camera:
		camera.make_current()
