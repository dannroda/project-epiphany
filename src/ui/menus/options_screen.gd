class_name OptionsScreen
extends UiScreen
## Opciones (mockup Options): a pantalla completa desde el título, dentro del marco de la pausa desde Sistema.

const SCENE_PATH := "res://src/ui/menus/options_screen.tscn"
const PAUSE_SCENE_PATH := "res://src/ui/menus/pause_options_screen.tscn"

@onready var panel: OptionsPanel = %OptionsPanel


static func open(in_pause := false) -> OptionsScreen:
	var screen: OptionsScreen = load(PAUSE_SCENE_PATH if in_pause else SCENE_PATH).instantiate()
	MenuStack.push(screen)
	return screen


func _ready() -> void:
	%Hints.hints = [[&"ui_accept", "HINT_CHANGE"], [&"ui_cancel", "HINT_BACK"]]


func focus_default() -> void:
	panel.focus_default()
