@tool
extends VBoxContainer

signal edited

var cfg: ConfigFile
var db: ItemDatabase
var flags: FlagRegistry


func refresh() -> void:
	pass


func mark_edited() -> void:
	edited.emit()


func editor_color(color_name: StringName) -> Color:
	return get_theme_color(color_name, &"Editor")


func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func group_label(text: String, color := Color()) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 11)
	label.add_theme_color_override(&"font_color", color if color != Color() else editor_color(&"font_placeholder_color"))
	return label


func dim_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 11)
	label.add_theme_color_override(&"font_color", editor_color(&"font_placeholder_color"))
	return label


func button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	return b


## − n / máx + [Máx]
func stepper(value: int, max_value: int, on_change: Callable, with_max := true) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(button("−", func() -> void: on_change.call(clampi(value - 1, 0, max_value))))
	var label := Label.new()
	label.text = "%d / %d" % [value, max_value]
	label.custom_minimum_size.x = 56
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(label)
	row.add_child(button("+", func() -> void: on_change.call(clampi(value + 1, 0, max_value))))
	if with_max:
		row.add_child(button("Máx", func() -> void: on_change.call(max_value)))
	return row


func set_or_erase(section: String, key: String, value: Variant, erase_when: Variant) -> void:
	if value == erase_when:
		if cfg.has_section_key(section, key):
			cfg.erase_section_key(section, key)
	else:
		cfg.set_value(section, key, value)
