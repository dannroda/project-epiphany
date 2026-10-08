extends Control
## Menú de pausa: pestañas Equipo, Ítems y Mapa. Cada página es un hijo de %Pages.

@onready var pages: Control = %Pages
@onready var tabs: HBoxContainer = %Tabs
@onready var hints: HBoxContainer = %Hints
@onready var prev_key: TextureRect = %PrevKey
@onready var next_key: TextureRect = %NextKey

var current := 0


func _ready() -> void:
	for page in pages.get_children():
		var label := Label.new()
		label.text = page.name
		label.theme_type_variation = &"TabLabel"
		tabs.add_child(label)
	InputDevice.input_device_changed.connect(func(_d: int) -> void: _update_hints())
	_update_hints()
	show_page(0)


func show_page(index: int) -> void:
	current = wrapi(index, 0, pages.get_child_count())
	for i in pages.get_child_count():
		pages.get_child(i).visible = i == current
		var label := tabs.get_child(i) as Label
		label.theme_type_variation = &"TabLabelSelected" if i == current else &"TabLabel"
	focus_default()
	_update_hints()


func focus_default() -> void:
	var page := pages.get_child(current)
	if page.has_method(&"focus_default"):
		page.focus_default()
		return
	for control in page.find_children("*", "Control", true, false):
		if (control as Control).focus_mode == FOCUS_ALL and (control as Control).is_visible_in_tree():
			(control as Control).grab_focus()
			return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_tab_left"):
		show_page(current - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_tab_right"):
		show_page(current + 1)
		get_viewport().set_input_as_handled()


const HINTS := [[&"ui_accept", ""], [&"ui_cancel", "Cerrar"], [&"ui_tab_left", ""], [&"ui_tab_right", "Pestaña"]]


func _update_hints() -> void:
	prev_key.texture = InputPrompts.icon_for_current(&"ui_tab_left")
	next_key.texture = InputPrompts.icon_for_current(&"ui_tab_right")
	for child in hints.get_children():
		hints.remove_child(child)
		child.queue_free()
	var page := pages.get_child(current)
	var extra = page.get(&"extra_hints")
	for hint in (extra if extra is Array else []) + HINTS:
		if hint[0] == &"ui_accept" and _accept_label().is_empty():
			continue
		var icon := TextureRect.new()
		icon.texture = InputPrompts.icon_for_current(hint[0])
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hints.add_child(icon)
		var text: String = hint[1] if hint[0] != &"ui_accept" else _accept_label()
		if not text.is_empty():
			var label := Label.new()
			label.text = text + "    "
			label.theme_type_variation = &"Hint"
			hints.add_child(label)


func _accept_label() -> String:
	var page := pages.get_child(current)
	var label = page.get(&"accept_label")
	return label if label is String else "Usar"
