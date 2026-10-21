class_name OptionsPanel
extends VBoxContainer
## Las opciones del mockup Options_Tabs: pestañas Juego (Controles e Idioma | Audio) y Video (Pantalla | Gráficos),
## que se cambian con LB/RB. Cada control se llama como su clave en Settings y guarda al cambiar (un slider, al soltarlo
## o al dejarlo: mientras se mueve solo aplica).

const TOGGLES: Array[StringName] = [&"mouse_aim", &"flick", &"vibration", &"fullscreen", &"shake", &"minimap", &"counter_slow", &"ssao"]
const SLIDERS: Array[StringName] = [&"stick_sensitivity", &"music", &"sfx", &"ambience"]
const PICKERS: Array[StringName] = [&"ui_scale", &"max_fps", &"shadows", &"render_scale"]

@onready var pages: TabContainer = %Pages
@onready var tabs: TabBar = %Tabs
@onready var firsts: Array[Control] = [%lock_mantener, %fullscreen]

var current := 0


func _ready() -> void:
	for key in TOGGLES:
		var box := get_node("%" + key) as CheckBox
		box.button_pressed = Settings.get_value(key)
		box.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	for key in SLIDERS:
		var slider := get_node("%" + key) as HSlider
		slider.value = Settings.get_value(key)
		slider.value_changed.connect(func(value: float) -> void: Settings.set_value(key, int(value), false))
		slider.drag_ended.connect(func(_changed: bool) -> void: Settings.save_settings())
		slider.focus_exited.connect(Settings.save_settings)
	var lock_toggle: bool = Settings.get_value(&"lock_toggle")
	for radio: CheckBox in [%lock_mantener, %lock_alternar]:
		var value := radio == %lock_alternar
		radio.button_pressed = lock_toggle == value
		radio.toggled.connect(func(on: bool) -> void:
			if on:
				Settings.set_value(&"lock_toggle", value))
	for language in Settings.LANGUAGES:
		var radio := get_node("%language_" + language) as CheckBox
		radio.button_pressed = Settings.get_value(&"language") == language
		radio.toggled.connect(func(on: bool) -> void:
			if on:
				Settings.set_value(&"language", language))
	for key in PICKERS:
		var picker := get_node("%" + key) as OptionButton
		picker.select(picker.get_item_index(Settings.get_value(key)))
		picker.item_selected.connect(func(index: int) -> void: Settings.set_value(key, picker.get_item_id(index)))
	_show_quality()
	%quality.item_selected.connect(func(index: int) -> void: Settings.apply_profile(Settings.PROFILE_ORDER[index]))
	Settings.changed.connect(_on_setting_changed)
	%ShowControls.pressed.connect(ControlsScreen.open)
	tabs.tab_changed.connect(func(tab: int) -> void:
		if tab != current:
			show_page(tab))
	InputDevice.input_device_changed.connect(func(_d: int) -> void: _update_keys())
	_update_keys()


## Un perfil cambia varias opciones a la vez; Personalizado se muestra pero no se elige.
func _on_setting_changed(key: StringName) -> void:
	if key in PICKERS:
		var picker := get_node("%" + key) as OptionButton
		picker.select(picker.get_item_index(Settings.get_value(key)))
	elif key == &"ssao":
		(%ssao as CheckBox).set_pressed_no_signal(Settings.get_value(key))
	if key == &"quality" or key in Settings.GRAPHICS:
		_show_quality()


func _show_quality() -> void:
	var quality: String = Settings.matching_profile() if Settings.needs_calibration() else Settings.get_value(&"quality")
	var at := Settings.PROFILE_ORDER.find(quality)
	%quality.select(at if at >= 0 else Settings.PROFILE_ORDER.size())


func show_page(index: int) -> void:
	current = wrapi(index, 0, pages.get_tab_count())
	pages.current_tab = current
	tabs.current_tab = current
	focus_default()


func focus_default() -> void:
	firsts[current].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_tab_left"):
		show_page(current - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_tab_right"):
		show_page(current + 1)
		get_viewport().set_input_as_handled()


func _update_keys() -> void:
	%PrevKey.texture = InputPrompts.icon_for_current(&"ui_tab_left")
	%NextKey.texture = InputPrompts.icon_for_current(&"ui_tab_right")


func _exit_tree() -> void:
	Settings.save_settings()
