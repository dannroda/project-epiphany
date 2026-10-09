class_name GameOver
extends Control
## Game over (mockup GameOver): Continuar desde la entrada de la sala o el último checkpoint, Guardar y salir, Salir sin guardar.

## La pila de menús no la cierra con atrás ni con pausa: hay que elegir.
var modal := true
var _continue: MenuItem


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = load("res://src/ui/theme.tres")
	var background := ColorRect.new()
	background.color = Color("#07080a")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)
	var eye: Control = load("res://src/ui/title/title_eye.gd").new()
	eye.outline = Color("#2a1a16")
	eye.iris = Color("#2a0f0b")
	eye.iris_border = Color("#2a0f0b")
	eye.pupil = Color("#07080a")
	eye.iris_radius = 70.0
	eye.pupil_radius = 24.0
	eye.anchor_left = 0.5
	eye.anchor_right = 0.5
	eye.offset_left = -250
	eye.offset_right = 250
	eye.offset_top = 60
	eye.offset_bottom = 260
	add_child(eye)
	var title := Label.new()
	title.text = "CAÍSTE"
	title.theme_type_variation = &"Title"
	title.add_theme_font_size_override(&"font_size", 76)
	title.add_theme_color_override(&"font_color", Color("#d0503a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_right = 1.0
	title.offset_top = 250
	add_child(title)
	var spaced := title.get_theme_font(&"font").duplicate() as FontVariation
	spaced.spacing_glyph = 15
	title.add_theme_font_override(&"font", spaced)
	var menu := VBoxContainer.new()
	menu.anchor_left = 0.5
	menu.anchor_right = 0.5
	menu.offset_left = -220
	menu.offset_right = 220
	menu.offset_top = 400
	menu.add_theme_constant_override(&"separation", 6)
	add_child(menu)
	_continue = _item(menu, "Continuar", _on_continue)
	var caption := Label.new()
	caption.text = "Desde la entrada de la sala" if GameState.current_dungeon != &"" else "Desde el último punto de control"
	caption.add_theme_font_size_override(&"font_size", 15)
	caption.add_theme_color_override(&"font_color", Color("#a79f8e"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(caption)
	_item(menu, "Guardar y salir", _on_save_and_quit)
	_item(menu, "Salir sin guardar", _on_quit)
	var hints := HintBar.new()
	hints.hints = [[&"ui_accept", "Aceptar"]]
	hints.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT, PRESET_MODE_MINSIZE, 32)
	hints.grow_horizontal = GROW_DIRECTION_BEGIN
	hints.grow_vertical = GROW_DIRECTION_BEGIN
	add_child(hints)


func focus_default() -> void:
	_continue.grab_focus()


func _item(menu: Control, text: String, action: Callable) -> MenuItem:
	var item := MenuItem.new()
	item.label = text
	item.pressed.connect(action)
	menu.add_child(item)
	return item


func _on_continue() -> void:
	MenuStack.pop()
	SaveManager.respawn()


func _on_save_and_quit() -> void:
	SaveManager.save_checkpoint()
	SaveManager.quit_to_title()


func _on_quit() -> void:
	SaveManager.quit_to_title()
