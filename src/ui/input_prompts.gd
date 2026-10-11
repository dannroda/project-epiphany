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
## Los íconos de Kenney traen la letra calada: se rellena con este color para que no se vea lo de atrás.
const HOLE_FILL := Color("0b0d10")

static var _filled := {}

const MOUSE_BUTTONS := {
	MOUSE_BUTTON_LEFT: "mouse_left", MOUSE_BUTTON_RIGHT: "mouse_right",
	MOUSE_BUTTON_WHEEL_UP: "mouse_scroll_up", MOUSE_BUTTON_WHEEL_DOWN: "mouse_scroll_down",
}


static func icon(action: StringName, gamepad: bool) -> Texture2D:
	var all := icons(action, gamepad)
	return all[0] if not all.is_empty() else null


## Todos los del dispositivo, en el orden del InputMap (Pausa: Esc y Tab).
static func icons(action: StringName, gamepad: bool) -> Array[Texture2D]:
	var found: Array[Texture2D] = []
	for event in InputMap.action_get_events(action):
		var path := _path_for(event, gamepad)
		if not path.is_empty() and ResourceLoader.exists(path):
			if not _filled.has(path):
				_filled[path] = _fill_holes(load(path))
			if not found.has(_filled[path]):
				found.append(_filled[path])
	return found


static func icon_for_current(action: StringName) -> Texture2D:
	return icon(action, InputDevice.current == InputDevice.Device.GAMEPAD)


## El de un player (co-op): con solo un control, el del control aunque el último en tocar algo haya sido el teclado.
static func icon_for(action: StringName, player: Node) -> Texture2D:
	var controls: Node = player.get(&"controls") if player else null
	if controls == null:
		return icon_for_current(action)
	return icon(action, controls.uses_gamepad())


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
		return KEYBOARD % ("keyboard_" + OS.get_keycode_string(keycode).to_lower().replace(" ", "_").replace("page", "page_"))
	if event is InputEventMouseButton and MOUSE_BUTTONS.has(event.button_index):
		return KEYBOARD % MOUSE_BUTTONS[event.button_index]
	return ""


## Lo transparente que no se alcanza desde el borde (el calado de la letra) pasa a HOLE_FILL.
static func _fill_holes(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	if image == null:
		return texture
	image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var w := image.get_width()
	var h := image.get_height()
	var outside := PackedByteArray()
	outside.resize(w * h)
	var queue: Array[Vector2i] = []
	for x in w:
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, h - 1))
	for y in h:
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(w - 1, y))
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or outside[p.y * w + p.x] == 1:
			continue
		if image.get_pixelv(p).a >= 0.5:
			continue
		outside[p.y * w + p.x] = 1
		queue.append_array([p + Vector2i.LEFT, p + Vector2i.RIGHT, p + Vector2i.UP, p + Vector2i.DOWN])
	for y in h:
		for x in w:
			var color := image.get_pixel(x, y)
			if outside[y * w + x] == 0 and color.a < 1.0 and not _touches(outside, w, h, x, y):
				var filled := HOLE_FILL.lerp(Color(color, 1.0), color.a)
				filled.a = 1.0
				image.set_pixel(x, y, filled)
	return ImageTexture.create_from_image(image)


static func _touches(outside: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var n := Vector2i(x, y) + offset
		if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or outside[n.y * w + n.x] == 1:
			return true
	return false
