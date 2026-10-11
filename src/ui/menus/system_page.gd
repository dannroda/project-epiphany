extends Control
## Pestaña Sistema de la pausa: las opciones y Guardar y salir al título.

var accept_label := "HINT_CHANGE"

@onready var panel: OptionsPanel = %OptionsPanel


func _ready() -> void:
	%SaveAndQuit.pressed.connect(func() -> void:
		SaveManager.save_game()
		SaveManager.quit_to_title())


func focus_default() -> void:
	panel.focus_default()
