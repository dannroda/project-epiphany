extends Control
## Menú de pausa: pestañas Equipo, Ítems y Mapa. Cada página es un hijo de %Pages.

@onready var pages: Control = %Pages
@onready var tabs: HBoxContainer = %Tabs
@onready var hints: Label = %Hints
@onready var prev_key: Label = %PrevKey
@onready var next_key: Label = %NextKey

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


func _update_hints() -> void:
	if InputDevice.current == InputDevice.Device.GAMEPAD:
		hints.text = "A  Usar      B  Cerrar      LB / RB  Pestaña"
		prev_key.text = "LB"
		next_key.text = "RB"
	else:
		hints.text = "Enter  Usar      Esc  Cerrar      Q / E  Pestaña"
		prev_key.text = "Q"
		next_key.text = "E"
