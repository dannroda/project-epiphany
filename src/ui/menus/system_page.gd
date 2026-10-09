extends Control
## Pestaña Sistema de la pausa: las opciones y Guardar y salir al título.

var accept_label := "Cambiar"
var panel: OptionsPanel


func _ready() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	column.add_theme_constant_override(&"separation", 12)
	add_child(column)
	panel = OptionsPanel.new()
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(panel)
	var quit := MenuItem.new()
	quit.name = "SaveAndQuit"
	quit.label = "Guardar y salir al título"
	quit.font_size = 20
	quit.size_flags_horizontal = SIZE_SHRINK_BEGIN
	quit.pressed.connect(func() -> void:
		SaveManager.save_game()
		SaveManager.quit_to_title())
	column.add_child(quit)


func focus_default() -> void:
	panel.focus_default()
