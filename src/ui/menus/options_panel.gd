class_name OptionsPanel
extends HBoxContainer
## Las opciones del mockup Options en dos columnas (Controles e Idioma | Audio y Video). Cada control se llama como su
## clave en Settings y guarda al cambiar.

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
		slider.value_changed.connect(func(value: float) -> void: Settings.set_value(key, int(value)))
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
	var picker := %ui_scale as OptionButton
	picker.select(picker.get_item_index(Settings.get_value(&"ui_scale")))
	picker.item_selected.connect(func(index: int) -> void: Settings.set_value(&"ui_scale", picker.get_item_id(index)))


func focus_default() -> void:
	first.grab_focus()
