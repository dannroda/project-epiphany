# Autoload
extends Node
## Opciones del jugador (pantalla Opciones): se guardan en user://settings.cfg, aparte de la partida, y se aplican al arrancar.

signal changed(key: StringName)

const PATH := "user://settings.cfg"
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
	## Tope de cuadros por segundo (0 = sin límite): con un monitor de 200 Hz el juego dibujaba 200 sin necesidad.
	&"max_fps": 60,
	## Calidad de la sombra del sol (15.3): 2 = alta (atlas 4096, filtro del proyecto); 1 = baja (2048, filtro bajo), ~0.5 ms
	## menos de GPU en el overworld a 1080p.
	&"shadows": 2,
	## Escala de la resolución 3D en % (15.7): por debajo de 100 escala con FSR; la UI sigue a resolución completa.
	&"render_scale": 100,
	&"language": "",
	## Co-op, a prueba (13.9): "ring" = cada uno elige con su anillo; "shared" = el menú de pausa con un cursor por player.
	&"coop_item_menu": "ring",
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


## `persist` false: aplica sin escribir a disco (un slider mientras se arrastra); después se llama a `save_settings`.
func set_value(key: StringName, value: Variant, persist := true) -> void:
	values[key] = value
	_apply(key)
	if persist:
		save_settings()
	changed.emit(key)


func load_settings() -> void:
	values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	var from := path if FileAccess.file_exists(path) else path + ".tmp"
	if FileAccess.file_exists(from) and cfg.load(from) == OK:
		for key in DEFAULTS:
			values[key] = SaveCodec.typed(cfg, "options", key, DEFAULTS[key])
	_apply()


## A un .tmp y después se renombra: un corte a mitad de camino no deja las opciones vacías.
func save_settings() -> Error:
	var cfg := ConfigFile.new()
	for key in values:
		cfg.set_value("options", key, values[key])
	var tmp := path + ".tmp"
	var err := cfg.save(tmp)
	if err == OK and FileAccess.file_exists(path):
		err = DirAccess.remove_absolute(path)
	if err == OK:
		err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		Log.error(&"settings", "No se pudieron guardar las opciones", path, error_string(err))
	return err


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


## Solo lo que depende de `key`; sin clave, todo (al arrancar o al cargar).
func _apply(key := &"") -> void:
	var all := key == &""
	if all or key == &"music":
		_volume(&"Music", get_value(&"music"))
	if all or key == &"sfx":
		_volume(&"SFX", get_value(&"sfx"))
		_volume(&"UI", get_value(&"sfx"))
	if all or key == &"ambience":
		_volume(&"Ambience", get_value(&"ambience"))
	if all or key == &"ui_scale":
		get_tree().root.content_scale_factor = float(get_value(&"ui_scale")) / 100.0
	if all or key == &"language":
		TranslationServer.set_locale(language())
	if all or key == &"render_scale":
		var scale: int = get_value(&"render_scale")
		get_tree().root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 100 else Viewport.SCALING_3D_MODE_BILINEAR
		get_tree().root.scaling_3d_scale = scale / 100.0
	if DisplayServer.get_name() == "headless":
		return
	if all or key == &"max_fps":
		Engine.max_fps = get_value(&"max_fps")
	if all or key == &"shadows":
		var high: bool = get_value(&"shadows") >= 2
		RenderingServer.directional_shadow_atlas_set_size(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size") if high else 2048,
			ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits"))
		RenderingServer.directional_soft_shadow_filter_set_quality(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality") if high else RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
	if all or key == &"fullscreen":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if get_value(&"fullscreen") else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)


func _volume(bus: StringName, percent: int) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(percent, 0.01) / 100.0))
	AudioServer.set_bus_mute(index, percent <= 0)
