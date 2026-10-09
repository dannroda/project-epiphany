class_name OptionsScreen
extends UiScreen
## Opciones desde el título (mockup Options), a pantalla completa.

const SCENE_PATH := "res://src/ui/menus/options_screen.tscn"

@onready var panel: OptionsPanel = %OptionsPanel


static func open() -> OptionsScreen:
	var screen: OptionsScreen = load(SCENE_PATH).instantiate()
	MenuStack.push(screen)
	return screen


func _ready() -> void:
	%Hints.hints = [[&"ui_accept", "Cambiar"], [&"ui_cancel", "Volver"]]


func focus_default() -> void:
	panel.focus_default()
