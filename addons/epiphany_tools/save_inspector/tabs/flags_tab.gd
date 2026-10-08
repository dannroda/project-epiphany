@tool
extends "tab.gd"


func _init() -> void:
	name = "Flags"


func refresh() -> void:
	clear(self)
	add_child(group_label("REGISTRADAS"))
	for definition in flags.definitions:
		add_child(_row(definition))
	var unknown := PackedStringArray()
	if cfg.has_section("flags"):
		for id in cfg.get_section_keys("flags"):
			if not flags.has(id):
				unknown.append(id)
	if unknown.is_empty():
		return
	add_child(group_label("NO REGISTRADAS", editor_color(&"error_color")))
	for id in unknown:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s = %s" % [id, var_to_str(cfg.get_value("flags", id))]
		label.tooltip_text = "No está en flag_registry.tres. El juego la ignora."
		label.mouse_filter = MOUSE_FILTER_PASS
		label.size_flags_horizontal = SIZE_EXPAND_FILL
		label.add_theme_color_override(&"font_color", editor_color(&"error_color"))
		row.add_child(label)
		row.add_child(button("Quitar", func() -> void:
			cfg.erase_section_key("flags", id)
			mark_edited()
			refresh()))
		add_child(row)


func _row(definition: FlagDefinition) -> HBoxContainer:
	var row := HBoxContainer.new()
	var value: Variant = cfg.get_value("flags", definition.id, definition.default_value)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = SIZE_EXPAND_FILL
	names.add_theme_constant_override(&"separation", 0)
	var title := Label.new()
	title.text = definition.id
	names.add_child(title)
	names.add_child(dim_label("%s · por defecto: %s" % [definition.description, var_to_str(definition.default_value)]))
	row.add_child(names)
	if typeof(definition.default_value) == TYPE_BOOL:
		var toggle := CheckButton.new()
		toggle.button_pressed = bool(value)
		toggle.toggled.connect(func(on: bool) -> void: _set_flag(definition, on))
		row.add_child(toggle)
	else:
		var edit := LineEdit.new()
		edit.text = var_to_str(value)
		edit.custom_minimum_size.x = 100
		edit.text_submitted.connect(func(text: String) -> void: _set_flag(definition, str_to_var(text)))
		row.add_child(edit)
	return row


func _set_flag(definition: FlagDefinition, value: Variant) -> void:
	set_or_erase("flags", definition.id, value, definition.default_value)
	mark_edited()
