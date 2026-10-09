# Autoload
extends Node

const SAVE_DIR := "user://saves/"
## Carpeta de las ranuras; los tests la cambian para no tocar las partidas reales.
var save_dir := SAVE_DIR
const SCENARIO_DIR := "res://debug/scenarios/"
const NEXT_SCENARIO_FILE := "user://debug/next_scenario.txt"
const TITLE := "res://src/ui/title/title_screen.tscn"
const NEW_GAME_SCENE := "res://levels/overworld.tscn"

signal saved(slot: int)

const SLOTS := 3
## Ranura de los escenarios de debug: su autosave nunca pisa una partida del jugador.
const SCENARIO_SLOT := 98

## Ranura de la partida en curso: el autosave y el guardado rápido van ahí.
var current_slot := 0
var traveling := false


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
		save_game()
	elif event.is_action_pressed(&"debug_quickload"):
		load_game()


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
	cfg.set_value("player", "location", location())
	var err := SaveCodec.write(cfg, slot_path(slot))
	if err == OK:
		Log.success(&"save", "Partida guardada:", slot_path(slot))
	else:
		Log.error(&"save", "No se pudo guardar", slot_path(slot), error_string(err))
	return err


## Guarda en la ranura actual (al cambiar de escena, al abrir un cofre grande, al entrar a la antesala).
func autosave() -> void:
	if save_game(current_slot) == OK:
		saved.emit(current_slot)


## Fundido a negro, `action` (cargar, partida nueva…) y fundido de vuelta. Corre acá y no en la pantalla que la pide,
## porque esa pantalla se libera al cambiar de escena y el fundido de vuelta nunca llegaría.
func with_fade(action: Callable) -> void:
	await Fader.fade_out(0.3)
	await action.call()
	await Fader.fade_in(0.3)


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(slot_path(slot))


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
		max_health = cfg.get_value("player", "max_health", GameState.NEW_GAME_MAX_HEALTH),
		location = cfg.get_value("player", "location", ""),
		play_time = cfg.get_value("player", "play_time", 0.0),
		items = items,
		timestamp = cfg.get_value("meta", "timestamp", 0.0),
	}


## La ranura guardada más recientemente; -1 si no hay ninguna.
func latest_slot() -> int:
	var best := -1
	var best_time := -1.0
	for slot in SLOTS:
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
	return DirAccess.copy_absolute(slot_path(from), slot_path(to))


## Dónde está el player, para la pantalla de ranuras: "Mazmorra · Sala" o la zona del overworld.
func location() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	for child in scene.get_children():
		if child is Dungeon:
			var camera := get_tree().get_first_node_in_group(&"room_camera") as TopDownCamera
			var room_name := camera.room.display_name if camera and camera.room else ""
			return child.display_name + (" · " + room_name if not room_name.is_empty() else "")
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	for child in scene.get_children():
		if child is AreaZone and player and (child as AreaZone).contains(player.global_position):
			return child.display_name
	for child in scene.get_children():
		if child is OverworldMap:
			return child.display_name
	return ""


## Partida nueva: equipo inicial, en el claro del inicio del overworld.
func new_game(slot: int = -1) -> Error:
	if slot >= 0:
		current_slot = slot
	GameState.reset()
	GameState.spawn_scene = NEW_GAME_SCENE
	GameState.spawn_point = &"start"
	GameState.player_position = null
	await _restore_player()
	autosave()
	return OK


func quit_to_title() -> void:
	while MenuStack.is_open():
		MenuStack.pop()
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE)
	await get_tree().scene_changed


func load_game(slot: int = -1) -> Error:
	if slot >= 0:
		current_slot = slot
	return await _load_path(slot_path(current_slot))


## Un nombre de debug/scenarios/ o una ruta completa (la que deja el Save Inspector).
func load_scenario(scenario: String) -> Error:
	current_slot = SCENARIO_SLOT
	return await _load_path(scenario if "://" in scenario else SCENARIO_DIR + scenario + ".cfg")


func _load_path(path: String) -> Error:
	var cfg := ConfigFile.new()
	var err := SaveCodec.read(path, cfg)
	if err != OK:
		Log.error(&"save", "No se pudo cargar", path, error_string(err))
		return err
	for problem in SaveCodec.validate(cfg):
		Log.warning(&"save", problem)
	_migrate(cfg, cfg.get_value("meta", "version", 0))
	GameState.read_from(cfg)
	GameState.save_tampered = SaveCodec.is_tampered(cfg)
	if GameState.save_tampered:
		Log.warning(&"save", "La partida fue modificada a mano:", path)
	await _restore_player()
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
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player:
		GameState.player_position = player.global_position


## Fundido, recarga la escena y pone al player en el punto de reaparición con la vida llena.
func respawn() -> void:
	await Fader.fade_out()
	get_tree().reload_current_scene()
	await get_tree().scene_changed
	_place_at_spawn()
	Log.info(&"combat", "Reapareció en", GameState.spawn_point if GameState.spawn_point else &"(el primero)")
	await Fader.fade_in()


## Cambio de escena por un `Portal`: fundido, carga en segundo plano (la imagen no se congela), el player en
## `spawn` de la escena nueva y autosave. El juego queda en pausa mientras dura.
func travel_to(scene_path: String, spawn: StringName) -> void:
	traveling = true
	get_tree().paused = true
	ResourceLoader.load_threaded_request(scene_path)
	await Fader.fade_out(0.3)
	while ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var packed := ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if packed == null:
		Log.error(&"save", "No se pudo cargar", scene_path)
		get_tree().paused = false
		await Fader.fade_in(0.3)
		traveling = false
		return
	get_tree().change_scene_to_packed(packed)
	await get_tree().scene_changed
	GameState.spawn_scene = scene_path
	GameState.spawn_point = spawn
	GameState.room_entry = null
	GameState.player_position = null
	_place_at_spawn()
	autosave()
	Log.info(&"save", "Viaje a", scene_path, spawn)
	get_tree().paused = false
	await Fader.fade_in(0.3)
	traveling = false


## En mazmorra, en la entrada de la última sala; si no, en el punto de reaparición.
func _place_at_spawn() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	if player == null:
		return
	get_tree().call_group(&"room_camera", &"reset_room")
	if GameState.current_dungeon != &"" and GameState.room_entry != null:
		player.global_position = GameState.room_entry
		player.velocity = Vector3.ZERO
		get_tree().call_group(&"room_camera", &"snap_to_target")
		return
	var point := SpawnPoint.find(get_tree(), GameState.spawn_point)
	if point:
		player.global_position = point.global_position
		player.velocity = Vector3.ZERO
	get_tree().call_group(&"room_camera", &"snap_to_target")


func _restore_player() -> void:
	var scene := get_tree().current_scene
	if not GameState.spawn_scene.is_empty() and (scene == null or scene.scene_file_path != GameState.spawn_scene):
		get_tree().change_scene_to_file(GameState.spawn_scene)
		await get_tree().scene_changed
	var player := get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	if player and GameState.player_position != null:
		player.global_position = GameState.player_position
		player.velocity = Vector3.ZERO
	elif GameState.spawn_point != &"":
		_place_at_spawn()
