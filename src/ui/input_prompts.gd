class_name InputPrompts
extends RefCounted
## Ícono (Kenney Input Prompts) de la tecla o botón que tiene mapeado una acción, según el dispositivo.

const XBOX := "res://assets/kenney_input-prompts/Xbox Series/Vector/xbox_%s.svg"
const KEYBOARD := "res://assets/kenney_input-prompts/Keyboard & Mouse/Vector/%s.svg"

const JOY_BUTTONS := {
	JOY_BUTTON_A: "button_a", JOY_BUTTON_B: "button_b", JOY_BUTTON_X: "button_x", JOY_BUTTON_Y: "button_y",
	JOY_BUTTON_LEFT_SHOULDER: "lb", JOY_BUTTON_RIGHT_SHOULDER: "rb",
	JOY_BUTTON_BACK: "button_view", JOY_BUTTON_START: "button_menu",
	JOY_BUTTON_LEFT_STICK: "stick_l_press", JOY_BUTTON_RIGHT_STICK: "stick_r_press",
	JOY_BUTTON_DPAD_UP: "dpad_up", JOY_BUTTON_DPAD_DOWN: "dpad_down",
	JOY_BUTTON_DPAD_LEFT: "dpad_left", JOY_BUTTON_DPAD_RIGHT: "dpad_right",
}
const MOUSE_BUTTONS := {
	MOUSE_BUTTON_LEFT: "mouse_left", MOUSE_BUTTON_RIGHT: "mouse_right",
	MOUSE_BUTTON_WHEEL_UP: "mouse_scroll_up", MOUSE_BUTTON_WHEEL_DOWN: "mouse_scroll_down",
}


static func icon(action: StringName, gamepad: bool) -> Texture2D:
	for event in InputMap.action_get_events(action):
		var path := _path_for(event, gamepad)
		if not path.is_empty() and ResourceLoader.exists(path):
			return load(path)
	return null


static func icon_for_current(action: StringName) -> Texture2D:
	return icon(action, InputDevice.current == InputDevice.Device.GAMEPAD)


static func _path_for(event: InputEvent, gamepad: bool) -> String:
	if gamepad:
		if event is InputEventJoypadButton and JOY_BUTTONS.has(event.button_index):
			return XBOX % JOY_BUTTONS[event.button_index]
		if event is InputEventJoypadMotion:
			match event.axis:
				JOY_AXIS_TRIGGER_LEFT: return XBOX % "lt"
				JOY_AXIS_TRIGGER_RIGHT: return XBOX % "rt"
				JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y: return XBOX % "stick_l"
				JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y: return XBOX % "stick_r"
		return ""
	if event is InputEventKey:
		var keycode: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		return KEYBOARD % ("keyboard_" + OS.get_keycode_string(keycode).to_lower().replace(" ", "_"))
	if event is InputEventMouseButton and MOUSE_BUTTONS.has(event.button_index):
		return KEYBOARD % MOUSE_BUTTONS[event.button_index]
	return ""
