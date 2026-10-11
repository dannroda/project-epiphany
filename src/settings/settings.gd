# Autoload
extends Node
## Opciones del jugador (pantalla Opciones): se guardan en user://settings.cfg, aparte de la partida, y se aplican al arrancar.

signal changed(key: StringName)

const PATH := "user://settings.cfg"
const BUSES: Array[StringName] = [&"Music", &"SFX", &"UI", &"Ambience"]
const DEFAULTS := {
	&"lock_toggle": false,
	&"mouse_aim": true,
	&"stick_sensitivity": 50,
	&"flick": true,
	&"vibration": true,
	&"music": 70,
	&"sfx": 80,
	&"ambience": 60,
	&"fullscreen": false,
	&"shake": true,
	&"minimap": true,
	&"ui_scale": 100,
	&"language": "",
}
## Idiomas con traducción en translations/<código>.po. Vacío en `language` = todavía no se eligió.
const LANGUAGES: Array[String] = ["es", "en"]

var values := DEFAULTS.duplicate()
## Los tests la cambian para no tocar las opciones reales.
var path := PATH


func _ready() -> void:
	load_settings()


func get_value(key: StringName) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: StringName, value: Variant) -> void:
	values[key] = value
	_apply()
	save_settings()
	changed.emit(key)


func load_settings() -> void:
	values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		for key in DEFAULTS:
			values[key] = cfg.get_value("options", key, DEFAULTS[key])
	_apply()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in values:
		cfg.set_value("options", key, values[key])
	cfg.save(path)


## El idioma elegido o, si todavía no se eligió, el del sistema si hay traducción (si no, español).
func language() -> String:
	var chosen: String = get_value(&"language")
	if chosen in LANGUAGES:
		return chosen
	var system := OS.get_locale_language()
	return system if system in LANGUAGES else LANGUAGES[0]


func has_language() -> bool:
	return get_value(&"language") in LANGUAGES


## Multiplicador de giro del stick derecho (apuntar y girar con el haz): 0..100 → 0.5..1.5.
func stick_factor() -> float:
	return lerpf(0.5, 1.5, float(get_value(&"stick_sensitivity")) / 100.0)


func _apply() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")
	_volume(&"Music", get_value(&"music"))
	_volume(&"SFX", get_value(&"sfx"))
	_volume(&"UI", get_value(&"sfx"))
	_volume(&"Ambience", get_value(&"ambience"))
	Feel.settings.shake_enabled = get_value(&"shake")
	get_tree().root.content_scale_factor = float(get_value(&"ui_scale")) / 100.0
	TranslationServer.set_locale(language())
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if get_value(&"fullscreen") else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)


func _volume(bus: StringName, percent: int) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(percent, 0.01) / 100.0))
	AudioServer.set_bus_mute(index, percent <= 0)
