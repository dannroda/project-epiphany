extends "res://tests/test_case.gd"

var _dir: String = tmp_dir
var _path: String = _dir + "/slot.cfg"


func _clean() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_path + suffix):
			DirAccess.remove_absolute(_path + suffix)


func _cfg(bombs: int) -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.set_value("inventory", "bomb", bombs)
	cfg.set_value("flags", "ow_test_chest", true)
	return cfg


func _read() -> ConfigFile:
	var cfg := ConfigFile.new()
	assert_eq(SaveCodec.read(_path, cfg), OK)
	return cfg


func test_round_trip() -> void:
	_clean()
	assert_eq(SaveCodec.write(_cfg(3), _path), OK)
	var cfg := _read()
	assert_eq(cfg.get_value("inventory", "bomb"), 3)
	assert_eq(cfg.get_value("meta", "version"), SaveCodec.VERSION)
	assert_eq(SaveCodec.is_tampered(cfg), false)
	assert_eq(FileAccess.file_exists(_path + ".tmp"), false)
	_clean()


func test_second_write_keeps_backup() -> void:
	_clean()
	SaveCodec.write(_cfg(3), _path)
	SaveCodec.write(_cfg(5), _path)
	var backup := ConfigFile.new()
	assert_eq(backup.load(_path + ".bak"), OK)
	assert_eq(backup.get_value("inventory", "bomb"), 3)
	assert_eq(_read().get_value("inventory", "bomb"), 5)
	_clean()


func test_broken_save_falls_back_to_backup() -> void:
	_clean()
	SaveCodec.write(_cfg(3), _path)
	SaveCodec.write(_cfg(5), _path)
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string("[inventory\nbomb=")
	file.close()
	assert_eq(_read().get_value("inventory", "bomb"), 3)
	_clean()


func test_hand_edit_is_detected() -> void:
	_clean()
	SaveCodec.write(_cfg(3), _path)
	var text := FileAccess.get_file_as_string(_path).replace("bomb=3", "bomb=9")
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var cfg := _read()
	assert_eq(cfg.get_value("inventory", "bomb"), 9)
	assert_eq(SaveCodec.is_tampered(cfg), true)
	_clean()


func test_reads_encrypted_saves() -> void:
	_clean()
	DirAccess.make_dir_recursive_absolute(_dir)
	var cfg := _cfg(3)
	assert_eq(cfg.save_encrypted_pass(_path, SaveCodec._PASS), OK)
	assert_eq(_read().get_value("inventory", "bomb"), 3)
	_clean()


func test_validate() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("inventory", "bomb", 99)
	cfg.set_value("inventory", "no_existe", 1)
	cfg.set_value("flags", "flag_inventada", true)
	assert_eq(SaveCodec.validate(cfg).size(), 3)
	assert_eq(SaveCodec.validate(_cfg(3)).size(), 0)


func test_scenarios_are_valid() -> void:
	for scenario in ["start", "full_inventory", "test_rooms", "templo", "dungeon_test", "bombs_only", "pre_temple", "pre_boss", "chullpa", "travel"]:
		var cfg := ConfigFile.new()
		assert_eq(SaveCodec.read("res://debug/scenarios/%s.cfg" % scenario, cfg), OK, scenario)
		assert_eq(SaveCodec.validate(cfg).size(), 0, scenario)
		assert_eq(SaveCodec.is_tampered(cfg), false, scenario)


func test_scenario_spawn_points_exist() -> void:
	for file in DirAccess.get_files_at("res://debug/scenarios/"):
		var cfg := ConfigFile.new()
		SaveCodec.read("res://debug/scenarios/" + file, cfg)
		var spawn: StringName = cfg.get_value("player", "spawn_point", &"")
		var scene: String = cfg.get_value("player", "spawn_scene", "")
		if spawn == &"" or scene.is_empty() or cfg.has_section_key("player", "position"):
			continue
		var level: Node = load(scene).instantiate()
		var ids := level.find_children("*", "SpawnPoint", true, false).map(func(point: SpawnPoint) -> StringName: return point.id)
		ids.append_array(level.find_children("*", "TravelPortal", true, false).map(func(portal: TravelPortal) -> StringName: return portal.spawn_id()))
		assert_true(spawn in ids, "%s: %s tiene el punto %s" % [file, scene.get_file(), spawn])
		level.free()


func test_inconsistent_scenario_is_flagged() -> void:
	var cfg := ConfigFile.new()
	assert_eq(SaveCodec.read("res://debug/scenarios/boss_key_door_locked.cfg", cfg), OK)
	var problems := SaveCodec.validate(cfg)
	assert_eq(problems.size(), 1, "boss_key_door_locked es inconsistente a propósito")
	assert_true(problems.size() == 1 and "llave del jefe" in problems[0], str(problems))


func test_a_key_of_the_wrong_type_falls_back_to_its_default() -> void:
	var state: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"GameState")
	var cfg := ConfigFile.new()
	cfg.set_value("player", "max_health", "doce")
	cfg.set_value("player", "play_time", 30)
	cfg.set_value("player", "spawn_point", "start")
	cfg.set_value("inventory", "bomb", "muchas")
	cfg.set_value("inventory", "arrow", 5)
	cfg.set_value("dungeon_d1", "small_keys", true)
	cfg.set_value("map", "visited_zones", "pradera")
	state.read_from(cfg)
	assert_eq(state.max_health, GameState.NEW_GAME_MAX_HEALTH, "un tipo inesperado vuelve al valor por defecto")
	assert_eq(state.play_time, 30.0, "un entero donde va un decimal pasa")
	assert_eq(state.spawn_point, &"start", "un texto donde va un StringName pasa")
	assert_eq(state.inventory.count(&"bomb"), 0)
	assert_eq(state.inventory.count(&"arrow"), 5, "lo demás se lee igual")
	assert_eq(state.dungeons[&"d1"].small_keys, 0)
	assert_true(state.visited_zones.is_empty())
	state.reset()

