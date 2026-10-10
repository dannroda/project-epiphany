class_name Ending
extends UiScreen
## Fin del MVP (sin mockup: sigue el estilo de GameOver): el ojo vencido, créditos placeholder y volver.

const SCENE_PATH := "res://src/ui/menus/ending.tscn"

@onready var _keep_playing: Button = %KeepPlaying


static func open() -> Ending:
	var screen: Ending = load(SCENE_PATH).instantiate()
	MenuStack.push(screen)
	return screen


func _ready() -> void:
	%Hints.hints = [[&"ui_accept", "Aceptar"]]
	_keep_playing.pressed.connect(MenuStack.pop)
	%ToTitle.pressed.connect(_on_to_title)


func focus_default() -> void:
	_keep_playing.grab_focus()


func _on_to_title() -> void:
	SaveManager.save_checkpoint()
	SaveManager.quit_to_title()
