class_name OptionsPanel
extends HBoxContainer
## Las opciones del mockup Options en dos columnas (Controles | Audio y Video). Cada control guarda al cambiar.

const GOLD := Color("#d9a441")

var first: Control


func _ready() -> void:
	add_theme_constant_override(&"separation", 56)
	var controls := _column()
	_section(controls, "Controles")
	_lock_row(controls)
	_toggle(controls, "Apuntar con el mouse", &"mouse_aim")
	_slider(controls, "Sensibilidad del stick derecho", &"stick_sensitivity")
	_toggle(controls, "Cambio de objetivo con flick", &"flick")
	_toggle(controls, "Vibración", &"vibration")
	var right := _column()
	_section(right, "Audio")
	_slider(right, "Música", &"music")
	_slider(right, "Efectos", &"sfx")
	_slider(right, "Ambiente", &"ambience")
	_section(right, "Video").custom_minimum_size.y = 52
	_toggle(right, "Pantalla completa", &"fullscreen")
	_toggle(right, "Temblor de cámara", &"shake")
	_scale_row(right)


func focus_default() -> void:
	if first:
		first.grab_focus()


func _column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 8)
	add_child(column)
	return column


func _section(column: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Title"
	label.add_theme_font_size_override(&"font_size", 20)
	label.add_theme_color_override(&"font_color", GOLD)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	column.add_child(label)
	return label


func _row(column: Control, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 44
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 19)
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(label)
	column.add_child(row)
	return row


func _remember(control: Control) -> void:
	if first == null:
		first = control


func _toggle(column: Control, text: String, key: StringName) -> CheckBox:
	var box := CheckBox.new()
	box.name = String(key)
	box.button_pressed = Settings.get_value(key)
	box.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	_row(column, text).add_child(box)
	_remember(box)
	return box


func _slider(column: Control, text: String, key: StringName) -> HSlider:
	var slider := HSlider.new()
	slider.name = String(key)
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = Settings.get_value(key)
	slider.custom_minimum_size = Vector2(240, 24)
	slider.size_flags_vertical = SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(value: float) -> void: Settings.set_value(key, int(value)))
	_row(column, text).add_child(slider)
	_remember(slider)
	return slider


func _lock_row(column: Control) -> void:
	var row := _row(column, "Fijar objetivo")
	var group := ButtonGroup.new()
	for option in [["Mantener", false], ["Alternar", true]]:
		var radio := CheckBox.new()
		radio.name = "lock_" + option[0].to_lower()
		radio.text = option[0]
		radio.button_group = group
		radio.button_pressed = Settings.get_value(&"lock_toggle") == option[1]
		radio.toggled.connect(func(on: bool) -> void:
			if on:
				Settings.set_value(&"lock_toggle", option[1]))
		row.add_child(radio)
		_remember(radio)


func _scale_row(column: Control) -> void:
	var picker := OptionButton.new()
	picker.name = "ui_scale"
	for percent in [90, 100, 125]:
		picker.add_item("%d%%" % percent, percent)
	picker.select(picker.get_item_index(Settings.get_value(&"ui_scale")))
	picker.item_selected.connect(func(index: int) -> void: Settings.set_value(&"ui_scale", picker.get_item_id(index)))
	_row(column, "Escala de la interfaz").add_child(picker)
