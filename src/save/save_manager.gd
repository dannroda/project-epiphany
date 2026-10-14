# Autoload
extends Node
## Partidas: ranuras, guardar, cargar y escenarios de debug. Los cambios de escena son de SceneFlow.

const SAVE_DIR := "user://saves/"
## Carpeta de las ranuras; los tests la cambian para no tocar las partidas reales.
var save_dir := SAVE_DIR
const SCENARIO_DIR := "res://debug/scenarios/"
const NEXT_SCENARIO_FILE := "user://debug/next_scenario.txt"

signal saved(slot: int)

## La última partida guardada sola (autosave o guardado rápido), venga de la ranura que venga.
const AUTO_SLOT := 0
## Las que guarda el jugador (Guardar en la pausa).
const PLAYER_SLOTS: Array[int] = [1, 2, 3]
## Ranura de los escenarios de debug: su autosave nunca pisa una partida del jugador.
const SCENARIO_SLOT := 98

## Ranura del jugador de la partida en curso: ahí va Guardar; el autosave va a `AUTO_SLOT`.
var current_slot := 1
## Mientras se aplica una partida: los objetos reciben sus flags pero no es algo que el jugador hizo.
var loading := false


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			load_scenario.call_deferred(arg.get_slice("=", 1))
			return
	if FileAccess.file_exists(NEXT_SCENARIO_FILE):
		var scenario := FileAccess.get_file_as_string(NEXT_SCENARIO_FILE).strip_edges()
		DirAccess.remove_absolute(NEXT_SCENARIO_FILE)
		load_scenario.call_deferred(scenario)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed(&"debug_quicksave"):
		autosave()
	elif event.is_action_pressed(&"debug_quickload"):
		load_game(auto_slot())


func slot_path(slot: int) -> String:
	return save_dir + "slot_%d.cfg" % slot


## Guarda en el punto de reaparición y no donde está el player (Guardar y salir del game over).
func save_checkpoint() -> Error:
	GameState.player_position = null
	return save_game(current_slot, false)


func save_game(slot: int = -1, capture_player := true) -> Error:
	if slot < 0:
		slot = current_slot
	if capture_player:
		_capture_player()
	var cfg := ConfigFile.new()
	GameState.write_to(cfg)
	cfg.set_value("player", "location", SceneFlow.location())
	cfg.set_value("meta", "slot", current_slot)
	var err := SaveCodec.write(cfg, slot_path(slot))
	if err == OK:
		Log.success(&"save", "Partida guardada:", slot_path(slot))
	else:
		Log.error(&"save", "No se pudo guardar", slot_path(slot), error_string(err))
	return err


## Al cambiar de escena, al abrir un cofre grande, al entrar a la antesala.
## capture_player false guarda en el punto de reaparición (el portal del jefe: al cargar no vuelve a dispararlo).
func autosave(capture_player := true) -> void:
	var slot := auto_slot()
	if not capture_player:
		GameState.player_position = null
	if save_game(slot, capture_player) == OK:
		saved.emit(slot)


## Adónde va el autosave: la ranura Auto, salvo en los escenarios y tests, que tienen la suya.
func auto_slot() -> int:
	return AUTO_SLOT if current_slot in PLAYER_SLOTS else current_slot


## También cuenta una ranura con solo la copia de respaldo (un guardado cortado): al leerla se usa esa.
func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(slot_path(slot) + ".bak")


## Lo que muestra la pantalla de ranuras; vacío si la ranura no tiene partida.
func slot_summary(slot: int) -> Dictionary:
	var cfg := ConfigFile.new()
	if not has_save(slot) or SaveCodec.read(slot_path(slot), cfg) != OK:
		return {}
	var items: Array[StringName] = []
	for key in ["SWORD", "SHIELD"]:
		var id: StringName = cfg.get_value("equipment", key, &"")
		if id != &"":
			items.append(id)
	for id in [&"bow", &"bomb_bag"]:
		if cfg.get_value("inventory", id, 0) > 0:
			items.append(id)
	return {
		max_health = cfg.get_value("player", "max_health", GameState.new_game_max_health()),
		location = cfg.get_value("player", "location", ""),
		play_time = cfg.get_value("player", "play_time", 0.0),
		items = items,
		timestamp = cfg.get_value("meta", "timestamp", 0.0),
		origin = cfg.get_value("meta", "slot", slot),
	}


## La ranura guardada más recientemente; -1 si no hay ninguna.
func latest_slot() -> int:
	var best := -1
	var best_time := -1.0
	for slot in [AUTO_SLOT] + PLAYER_SLOTS:
		var summary := slot_summary(slot)
		if not summary.is_empty() and summary.timestamp > best_time:
			best = slot
			best_time = summary.timestamp
	return best


func delete_slot(slot: int) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(slot_path(slot) + suffix):
			DirAccess.remove_absolute(slot_path(slot) + suffix)


func copy_slot(from: int, to: int) -> Error:
	if not has_save(from):
		return ERR_FILE_NOT_FOUND
	DirAccess.make_dir_recursive_absolute(save_dir)
	delete_slot(to)
	var source := slot_path(from) if FileAccess.file_exists(slot_path(from)) else slot_path(from) + ".bak"
	return DirAccess.copy_absolute(source, slot_path(to))


func load_game(slot: int = -1) -> Error:
	if slot < 0:
		slot = current_slot
	return await _load_path(slot_path(slot), slot)


## Un nombre de debug/scenarios/ o una ruta completa (la que deja el Save Inspector).
func load_scenario(scenario: String) -> Error:
	return await _load_path(scenario if "://" in scenario else SCENARIO_DIR + scenario + ".cfg", SCENARIO_SLOT)


## La ranura pasa a ser `slot` solo si la partida se pudo leer.
func _load_path(path: String, slot: int) -> Error:
	var cfg := ConfigFile.new()
	var err := SaveCodec.read(path, cfg)
	if err != OK:
		Log.error(&"save", "No se pudo cargar", path, error_string(err))
		return err
	var version: int = SaveCodec.typed(cfg, "meta", "version", 0)
	if version > SaveCodec.VERSION:
		Log.error(&"save", "La partida es de una versión más nueva del juego:", path, version)
		return ERR_FILE_UNRECOGNIZED
	_migrate(cfg, version)
	for problem in SaveCodec.validate(cfg):
		Log.warning(&"save", problem)
	current_slot = slot
	if current_slot == AUTO_SLOT:
		var origin: int = cfg.get_value("meta", "slot", PLAYER_SLOTS[0])
		current_slot = origin if origin in PLAYER_SLOTS else PLAYER_SLOTS[0]
	loading = true
	GameState.read_from(cfg)
	GameState.save_tampered = SaveCodec.is_tampered(cfg)
	if GameState.save_tampered:
		Log.warning(&"save", "La partida fue modificada a mano:", path)
	await SceneFlow.enter_saved_scene()
	loading = false
	Log.success(&"save", "Partida cargada:", path)
	Log.debug(&"save", "Inventario:", ", ".join(GameState.inventory.ids().map(func(id: StringName) -> String: return "%s=%d" % [id, GameState.inventory.count(id)])))
	return OK


func _migrate(_cfg: ConfigFile, from_version: int) -> void:
	match from_version:
		_:
			pass


func _capture_player() -> void:
	var scene := get_tree().current_scene
	if scene:
		GameState.spawn_scene = scene.scene_file_path
	var player := Players.lead()
	if player:
		GameState.player_position = player.global_position
