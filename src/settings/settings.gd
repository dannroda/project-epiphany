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
	## El mundo a media velocidad mientras dura la ventana del contraataque (11.34).
	&"counter_slow": true,
	&"ui_scale": 100,
	## Tope de cuadros por segundo (0 = sin límite): con un monitor de 200 Hz el juego dibujaba 200 sin necesidad.
	&"max_fps": 60,
	## Calidad de la sombra del sol (15.3): 2 = alta (atlas 4096, filtro del proyecto); 1 = baja (2048, filtro bajo), ~0.5 ms
	## menos de GPU en el overworld a 1080p; 0 = sin sombra del sol (15.4, ~0.5 ms menos en una mazmorra).
	&"shadows": 2,
	## SSAO de los niveles que lo traen (15.4): ~0.5 ms de GPU en una sala de mazmorra a 1080p.
	&"ssao": true,
	## Escala de la resolución 3D en % (15.7): por debajo de 100 escala con FSR; la UI sigue a resolución completa.
	&"render_scale": 100,
	## Sombras de las plantas (15.19).
	&"plant_shadows": true,
	## Efectos LA (15.19): 2 todos; 1 sin las sombras de nubes; 0 tampoco el AO.
	&"look_effects": 2,
	## Perfil de calidad (15.19): uno de PROFILES, CUSTOM si el jugador tocó una opción gráfica suelta, vacío si todavía no
	## se calibró (la primera vez que arranca).
	&"quality": "",
	&"language": "",
	## Co-op, a prueba (13.9): "ring" = cada uno elige con su anillo; "shared" = el menú de pausa con un cursor por player.
	&"coop_item_menu": "ring",
}
## Los gráficos de los defaults son los de Alto; en Mobile, la primera vez, Medio hasta que calibra (QualityCalibration).
const PROFILES := {
	"bajo": preload("res://data/quality/bajo.tres"),
	"medio": preload("res://data/quality/medio.tres"),
	"alto": preload("res://data/quality/alto.tres"),
}
const PROFILE_ORDER: Array[String] = ["bajo", "medio", "alto"]
const CUSTOM := "custom"
## Las opciones que pone un perfil (propiedades de QualityProfile con el mismo nombre).
const GRAPHICS: Array[StringName] = [&"render_scale", &"shadows", &"plant_shadows", &"ssao", &"look_effects", &"max_fps"]
const PLANTS := "res://src/world/plants/"
const DECOR := "res://levels/decor/"
## Los árboles horneados en el terreno del overworld (17.2): las plantas bajas ya vienen sin sombra.
const BAKED_TREES := "arboles_"
const AO := preload("res://src/world/look/sombra_la.gd")
const CLOUDS := preload("res://src/world/look/nubes_la.gd")
## Idiomas con traducción en translations/<código>.po. Vacío en `language` = todavía no se eligió.
const LANGUAGES: Array[String] = ["es", "en"]

var values := DEFAULTS.duplicate()
var _setting_profile := false
## Los tests la cambian para no tocar las opciones reales.
var path := PATH


func _ready() -> void:
	load_settings()
	get_tree().node_added.connect(_scene_look)


func get_value(key: StringName) -> Variant:
	return values.get(key, DEFAULTS.get(key))


## `persist` false: aplica sin escribir a disco (un slider mientras se arrastra); después se llama a `save_settings`.
func set_value(key: StringName, value: Variant, persist := true) -> void:
	values[key] = value
	_apply(key)
	if key in GRAPHICS and not _setting_profile and values[&"quality"] != "":
		values[&"quality"] = matching_profile()
		changed.emit(&"quality")
	if persist:
		save_settings()
	changed.emit(key)


## Pone todas las opciones gráficas del perfil.
func apply_profile(id: String, persist := true) -> void:
	var profile: QualityProfile = PROFILES[id]
	_setting_profile = true
	for key in GRAPHICS:
		set_value(key, profile.get(key), false)
	_setting_profile = false
	set_value(&"quality", id, persist)


## El perfil que coincide con las opciones gráficas de ahora, o CUSTOM.
func matching_profile() -> String:
	for id: String in PROFILE_ORDER:
		if GRAPHICS.all(func(key: StringName) -> bool: return get_value(key) == PROFILES[id].get(key)):
			return id
	return CUSTOM


## El perfil con el que arranca la calibración: Medio en Mobile, Alto en PC.
func platform_profile() -> String:
	return "medio" if RenderingServer.get_current_rendering_method() == "mobile" else "alto"


func needs_calibration() -> bool:
	return get_value(&"quality") == ""


func load_settings() -> void:
	values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	var from := path if FileAccess.file_exists(path) else path + ".tmp"
	if FileAccess.file_exists(from) and cfg.load(from) == OK:
		for key in DEFAULTS:
			values[key] = SaveCodec.typed(cfg, "options", key, DEFAULTS[key])
		if not cfg.has_section_key("options", "quality"):
			values[&"quality"] = matching_profile()
	else:
		var profile: QualityProfile = PROFILES[platform_profile()]
		for key in GRAPHICS:
			values[key] = profile.get(key)
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
	if all or key == &"ssao" or key == &"shadows" or key == &"look_effects":
		for node in get_tree().root.find_children("*", "WorldEnvironment", true, false) + get_tree().root.find_children("*", "DirectionalLight3D", true, false):
			_scene_look(node)
	if all or key == &"plant_shadows":
		for node in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
			_scene_look(node)
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


## Lo que el nivel trae prendido (SSAO del entorno, sombra del sol) queda prendido solo si la opción lo deja. Lo del nivel se
## anota en el Environment, que comparten las instancias de la escena, y en la luz.
func _scene_look(node: Node) -> void:
	if node is WorldEnvironment and (node as WorldEnvironment).environment:
		var env := (node as WorldEnvironment).environment
		if not env.has_meta(&"level_ssao"):
			env.set_meta(&"level_ssao", env.ssao_enabled)
		env.ssao_enabled = env.get_meta(&"level_ssao") and get_value(&"ssao")
		var compositor := (node as WorldEnvironment).compositor
		for effect in compositor.compositor_effects if compositor else []:
			var needs := 1 if effect and effect.get_script() == AO else 2 if effect and effect.get_script() == CLOUDS else 0
			if needs:
				if not effect.has_meta(&"level_enabled"):
					effect.set_meta(&"level_enabled", effect.enabled)
				effect.enabled = effect.get_meta(&"level_enabled") and get_value(&"look_effects") >= needs
	elif node is DirectionalLight3D:
		if not node.has_meta(&"level_shadow"):
			node.set_meta(&"level_shadow", (node as DirectionalLight3D).shadow_enabled)
		(node as DirectionalLight3D).shadow_enabled = node.get_meta(&"level_shadow") and get_value(&"shadows") > 0
	elif node is GeometryInstance3D and _is_plant(node):
		var geometry := node as GeometryInstance3D
		if not geometry.has_meta(&"level_cast_shadow"):
			geometry.set_meta(&"level_cast_shadow", geometry.cast_shadow)
		geometry.cast_shadow = geometry.get_meta(&"level_cast_shadow") if get_value(&"plant_shadows") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Una malla de una planta, de la decoración del overworld o de los árboles del terreno.
func _is_plant(node: Node) -> bool:
	if node.name.begins_with(BAKED_TREES):
		return true
	var scene := node.owner
	while scene:
		if scene.scene_file_path.begins_with(PLANTS) or scene.scene_file_path.begins_with(DECOR):
			return true
		scene = scene.owner
	return false


func _volume(bus: StringName, percent: int) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(percent, 0.01) / 100.0))
	AudioServer.set_bus_mute(index, percent <= 0)
