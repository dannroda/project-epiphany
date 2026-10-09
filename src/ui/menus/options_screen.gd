class_name OptionsScreen
extends Control
## Opciones desde el título (mockup Options), a pantalla completa.

signal closed

var panel: OptionsPanel


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("#0b0d10")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	column.offset_left = 100
	column.offset_right = -100
	column.offset_top = 48
	column.offset_bottom = -48
	column.add_theme_constant_override(&"separation", 26)
	add_child(column)
	var heading := Label.new()
	heading.text = "Opciones"
	heading.theme_type_variation = &"Title"
	heading.add_theme_font_size_override(&"font_size", 36)
	column.add_child(heading)
	panel = OptionsPanel.new()
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(panel)
	var hints := HintBar.new()
	hints.alignment = BoxContainer.ALIGNMENT_END
	hints.hints = [[&"ui_accept", "Cambiar"], [&"ui_cancel", "Volver"]]
	column.add_child(hints)
	panel.focus_default.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
