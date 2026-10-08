# Autoload
extends Node

const SAVE_DIR := "user://saves/"
const SCENARIO_DIR := "res://debug/scenarios/"
const NEXT_SCENARIO_FILE := "user://debug/next_scenario.txt"


func _ready() -> void:
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
	return SAVE_DIR + "slot_%d.cfg" % slot


func save_game(slot: int = 0) -> Error:
	_capture_player()
	var cfg := ConfigFile.new()
	GameState.write_to(cfg)
	var err := SaveCodec.write(cfg, slot_path(slot))
	if err == OK:
		Log.success(&"save", "Partida guardada:", slot_path(slot))
	else:
		Log.error(&"save", "No se pudo guardar", slot_path(slot), error_string(err))
	return err


func load_game(slot: int = 0) -> Error:
	return await _load_path(slot_path(slot))


## Un nombre de debug/scenarios/ o una ruta completa (la que deja el Save Inspector).
func load_scenario(scenario: String) -> Error:
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


func _place_at_spawn() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	var point := SpawnPoint.find(get_tree(), GameState.spawn_point)
	if player and point:
		player.global_position = point.global_position
		player.velocity = Vector3.ZERO


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
