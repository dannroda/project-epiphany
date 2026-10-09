extends Control
## Pantalla de título (mockup Main): Continuar, Nueva partida, Opciones, Salir; en debug, cargar un escenario.

@onready var menu: VBoxContainer = %Menu
@onready var continue_item: MenuItem = %Continue
@onready var new_game_item: MenuItem = %NewGame
@onready var options_item: MenuItem = %Options
@onready var quit_item: MenuItem = %Quit
@onready var debug_scenarios: Button = %DebugScenarios
@onready var hints: HintBar = $Hints

var _scenarios: Control


func _ready() -> void:
	%Version.text = "v" + str(ProjectSettings.get_setting("application/config/version", "0.1-dev"))
	var title := $Heading/Title as Label
	var spaced := title.get_theme_font(&"font").duplicate() as FontVariation
	spaced.spacing_glyph = 9
	title.add_theme_font_override(&"font", spaced)
	hints.hints = [[&"ui_accept", "Aceptar"], [&"ui_cancel", "Volver"]]
	continue_item.disabled = SaveManager.latest_slot() < 0
	debug_scenarios.visible = OS.is_debug_build()
	continue_item.pressed.connect(func() -> void: open_file_select(SaveManager.latest_slot()))
	new_game_item.pressed.connect(func() -> void: open_file_select(_first_empty_slot()))
	options_item.pressed.connect(_open_options)
	quit_item.pressed.connect(func() -> void: get_tree().quit())
	debug_scenarios.pressed.connect(_show_scenarios)
	(continue_item if not continue_item.disabled else new_game_item).grab_focus.call_deferred()


func open_file_select(slot: int) -> FileSelect:
	var screen := FileSelect.new()
	screen.name = "FileSelect"
	add_child(screen)
	screen.focus_slot(slot)
	menu.process_mode = PROCESS_MODE_DISABLED
	screen.chosen.connect(func(chosen_slot: int, empty: bool) -> void:
		_go(SaveManager.new_game.bind(chosen_slot) if empty else SaveManager.load_game.bind(chosen_slot)))
	screen.closed.connect(func() -> void:
		screen.queue_free()
		menu.process_mode = PROCESS_MODE_INHERIT
		continue_item.disabled = SaveManager.latest_slot() < 0
		(continue_item if not continue_item.disabled else new_game_item).grab_focus())
	return screen


func _open_options() -> void:
	var screen := OptionsScreen.new()
	screen.name = "Options"
	add_child(screen)
	menu.process_mode = PROCESS_MODE_DISABLED
	screen.closed.connect(func() -> void:
		screen.queue_free()
		menu.process_mode = PROCESS_MODE_INHERIT
		options_item.grab_focus())


func _first_empty_slot() -> int:
	for slot in SaveManager.SLOTS:
		if not SaveManager.has_save(slot):
			return slot
	return 0


func _go(action: Callable) -> void:
	menu.process_mode = PROCESS_MODE_DISABLED
	await Fader.fade_out(0.3)
	await action.call()
	await Fader.fade_in(0.3)


func _show_scenarios() -> void:
	_scenarios = PanelContainer.new()
	_scenarios.theme_type_variation = &"MenuFrame"
	_scenarios.set_anchors_and_offsets_preset(PRESET_CENTER)
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 4)
	_scenarios.add_child(list)
	var heading := Label.new()
	heading.text = "Cargar escenario"
	heading.theme_type_variation = &"Title"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(heading)
	for file in DirAccess.get_files_at(SaveManager.SCENARIO_DIR):
		if not file.ends_with(".cfg"):
			continue
		var item := MenuItem.new()
		item.font_size = 20
		item.label = file.get_basename()
		item.pressed.connect(func() -> void: _go(SaveManager.load_scenario.bind(file.get_basename())))
		list.add_child(item)
	add_child(_scenarios)
	_scenarios.position = (size - _scenarios.get_combined_minimum_size()) / 2.0
	menu.process_mode = PROCESS_MODE_DISABLED
	(list.get_child(1) as Control).grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and is_instance_valid(_scenarios):
		_scenarios.queue_free()
		menu.process_mode = PROCESS_MODE_INHERIT
		debug_scenarios.grab_focus()
		get_viewport().set_input_as_handled()
