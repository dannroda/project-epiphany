extends Control
## Pantalla de título (mockup Main): Continuar, Nueva partida, Opciones, Salir; en debug, cargar un escenario.
## Es el estado raíz de la máquina de UI: todo lo que abre pasa por `MenuStack`.

@onready var continue_item: MenuItem = %Continue
@onready var new_game_item: MenuItem = %NewGame
@onready var options_item: MenuItem = %Options
@onready var quit_item: MenuItem = %Quit
@onready var debug_scenarios: Button = %DebugScenarios


func _ready() -> void:
	MenuStack.set_base(self)
	%Version.text = "v" + str(ProjectSettings.get_setting("application/config/version", "0.1-dev"))
	%Hints.hints = [[&"ui_accept", "Aceptar"], [&"ui_cancel", "Volver"]]
	debug_scenarios.visible = OS.is_debug_build()
	continue_item.pressed.connect(func() -> void: open_file_select(SaveManager.latest_slot()))
	new_game_item.pressed.connect(func() -> void: open_file_select(_first_empty_slot()))
	options_item.pressed.connect(OptionsScreen.open)
	quit_item.pressed.connect(func() -> void: get_tree().quit())
	debug_scenarios.pressed.connect(func() -> void:
		ScenarioList.open().chosen.connect(func(scenario: String) -> void:
			_go(SaveManager.load_scenario.bind(scenario))))
	visibility_changed.connect(_refresh)
	_refresh()
	focus_default.call_deferred()


func focus_default() -> void:
	if not is_inside_tree():
		return
	(continue_item if not continue_item.disabled else new_game_item).grab_focus()


func open_file_select(slot: int) -> FileSelect:
	var screen := FileSelect.open(slot)
	screen.chosen.connect(func(chosen_slot: int, empty: bool) -> void:
		_go(SaveManager.new_game.bind(chosen_slot) if empty else SaveManager.load_game.bind(chosen_slot)))
	return screen


func _refresh() -> void:
	continue_item.disabled = SaveManager.latest_slot() < 0


func _first_empty_slot() -> int:
	for slot in SaveManager.SLOTS:
		if not SaveManager.has_save(slot):
			return slot
	return 0


func _go(action: Callable) -> void:
	MenuStack.clear()
	process_mode = PROCESS_MODE_DISABLED
	SaveManager.with_fade(action)
