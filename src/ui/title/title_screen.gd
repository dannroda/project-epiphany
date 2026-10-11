extends Control
## Pantalla de título (mockup Main): Continuar, Cargar partida, Nueva partida, Opciones, Salir; en debug, cargar un escenario.
## La primera vez que se abre el juego, antes pide el idioma (mockup Language).
## Es el estado raíz de la máquina de UI: todo lo que abre pasa por `MenuStack`.

const LANGUAGE_SELECT := preload("res://src/ui/title/language_select.gd")

@onready var continue_item: Button = %Continue
@onready var load_item: Button = %Load
@onready var new_game_item: Button = %NewGame
@onready var options_item: Button = %Options
@onready var quit_item: Button = %Quit
@onready var debug_scenarios: Button = %DebugScenarios


func _ready() -> void:
	MenuStack.set_base(self)
	%Version.text = BuildInfo.label()
	%Hints.hints = [[&"ui_accept", "HINT_ACCEPT"], [&"ui_cancel", "HINT_BACK"]]
	debug_scenarios.visible = OS.is_debug_build()
	continue_item.pressed.connect(func() -> void: _go(SaveManager.load_game.bind(SaveManager.latest_slot())))
	load_item.pressed.connect(open_file_select.bind(FileSelect.Mode.PLAY))
	new_game_item.pressed.connect(_new_game)
	options_item.pressed.connect(OptionsScreen.open)
	quit_item.pressed.connect(func() -> void: get_tree().quit())
	debug_scenarios.pressed.connect(func() -> void:
		ScenarioList.open().chosen.connect(func(scenario: String) -> void:
			_go(SaveManager.load_scenario.bind(scenario))))
	visibility_changed.connect(_refresh)
	_refresh()
	if Settings.has_language():
		focus_default.call_deferred()
	else:
		LANGUAGE_SELECT.open()


func focus_default() -> void:
	if not is_inside_tree():
		return
	(continue_item if not continue_item.disabled else new_game_item).grab_focus()


func open_file_select(mode: FileSelect.Mode) -> FileSelect:
	var screen := FileSelect.open(mode)
	screen.chosen.connect(func(slot: int, fresh: bool) -> void:
		_go(SaveManager.new_game.bind(slot, true) if fresh else SaveManager.load_game.bind(slot)))
	return screen


## Sin ninguna partida va directo a la primera ranura; si no, se elige dónde.
func _new_game() -> void:
	if SaveManager.latest_slot() < 0:
		_go(SaveManager.new_game.bind(SaveManager.PLAYER_SLOTS[0], true))
	else:
		open_file_select(FileSelect.Mode.NEW)


func _refresh() -> void:
	var none := SaveManager.latest_slot() < 0
	continue_item.disabled = none
	load_item.disabled = none
	for item: Button in [continue_item, load_item]:
		item.focus_mode = FOCUS_NONE if none else FOCUS_ALL


func _go(action: Callable) -> void:
	MenuStack.clear()
	process_mode = PROCESS_MODE_DISABLED
	SaveManager.with_fade(action)
