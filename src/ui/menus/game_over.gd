class_name GameOver
extends UiScreen
## Game over (mockup GameOver): Continuar desde la entrada de la sala o el último checkpoint, Guardar y salir, Salir sin guardar.

const SCENE_PATH := "res://src/ui/menus/game_over.tscn"

@onready var _continue: Button = %Continue


static func open() -> GameOver:
	var screen: GameOver = load(SCENE_PATH).instantiate()
	MenuStack.push(screen)
	return screen


func _ready() -> void:
	%Where.text = "Desde la entrada de la sala" if GameState.current_dungeon != &"" else "Desde el último punto de control"
	%Hints.hints = [[&"ui_accept", "Aceptar"]]
	_continue.pressed.connect(_on_continue)
	%SaveAndQuit.pressed.connect(_on_save_and_quit)
	%Quit.pressed.connect(SaveManager.quit_to_title)


func focus_default() -> void:
	_continue.grab_focus()


func _on_continue() -> void:
	MenuStack.pop()
	SaveManager.respawn()


func _on_save_and_quit() -> void:
	SaveManager.save_checkpoint()
	SaveManager.quit_to_title()
