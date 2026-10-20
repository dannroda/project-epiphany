class_name OptionsPanel
extends HBoxContainer
## Las opciones del mockup Options en dos columnas (Controles e Idioma | Audio y Video). Cada control se llama como su
## clave en Settings y guarda al cambiar (un slider, al soltarlo o al dejarlo: mientras se mueve solo aplica).

const TOGGLES: Array[StringName] = [&"mouse_aim", &"flick", &"vibration", &"fullscreen", &"shake", &"minimap"]
const SLIDERS: Array[StringName] = [&"stick_sensitivity", &"music", &"sfx", &"ambience"]

@onready var first: Control = %lock_mantener


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
	for key: StringName in [&"ui_scale", &"max_fps", &"shadows"]:
		var picker := get_node("%" + key) as OptionButton
		picker.select(picker.get_item_index(Settings.get_value(key)))
		picker.item_selected.connect(func(index: int) -> void: Settings.set_value(key, picker.get_item_id(index)))
	%ShowControls.pressed.connect(ControlsScreen.open)


func focus_default() -> void:
	first.grab_focus()


func _exit_tree() -> void:
	Settings.save_settings()
