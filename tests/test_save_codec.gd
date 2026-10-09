extends "res://tests/test_case.gd"

const DIR := "user://tests_tmp"
const PATH := DIR + "/slot.cfg"


func _clean() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _cfg(bombs: int) -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.set_value("inventory", "bomb", bombs)
	cfg.set_value("flags", "ow_test_chest", true)
	return cfg


func _read() -> ConfigFile:
	var cfg := ConfigFile.new()
	assert_eq(SaveCodec.read(PATH, cfg), OK)
	return cfg


func test_round_trip() -> void:
	_clean()
	assert_eq(SaveCodec.write(_cfg(3), PATH), OK)
	var cfg := _read()
	assert_eq(cfg.get_value("inventory", "bomb"), 3)
	assert_eq(cfg.get_value("meta", "version"), SaveCodec.VERSION)
	assert_eq(SaveCodec.is_tampered(cfg), false)
	assert_eq(FileAccess.file_exists(PATH + ".tmp"), false)
	_clean()


func test_second_write_keeps_backup() -> void:
	_clean()
	SaveCodec.write(_cfg(3), PATH)
	SaveCodec.write(_cfg(5), PATH)
	var backup := ConfigFile.new()
	assert_eq(backup.load(PATH + ".bak"), OK)
	assert_eq(backup.get_value("inventory", "bomb"), 3)
	assert_eq(_read().get_value("inventory", "bomb"), 5)
	_clean()


func test_broken_save_falls_back_to_backup() -> void:
	_clean()
	SaveCodec.write(_cfg(3), PATH)
	SaveCodec.write(_cfg(5), PATH)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[inventory\nbomb=")
	file.close()
	assert_eq(_read().get_value("inventory", "bomb"), 3)
	_clean()


func test_hand_edit_is_detected() -> void:
	_clean()
	SaveCodec.write(_cfg(3), PATH)
	var text := FileAccess.get_file_as_string(PATH).replace("bomb=3", "bomb=9")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var cfg := _read()
	assert_eq(cfg.get_value("inventory", "bomb"), 9)
	assert_eq(SaveCodec.is_tampered(cfg), true)
	_clean()


func test_reads_encrypted_saves() -> void:
	_clean()
	DirAccess.make_dir_recursive_absolute(DIR)
	var cfg := _cfg(3)
	assert_eq(cfg.save_encrypted_pass(PATH, SaveCodec._PASS), OK)
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
	for scenario in ["start", "full_inventory", "test_rooms", "dungeon_no_bow", "dungeon_test", "bombs_only", "pre_temple", "pre_boss"]:
		var cfg := ConfigFile.new()
		assert_eq(SaveCodec.read("res://debug/scenarios/%s.cfg" % scenario, cfg), OK, scenario)
		assert_eq(SaveCodec.validate(cfg).size(), 0, scenario)
		assert_eq(SaveCodec.is_tampered(cfg), false, scenario)


func test_inconsistent_scenario_is_flagged() -> void:
	var cfg := ConfigFile.new()
	assert_eq(SaveCodec.read("res://debug/scenarios/boss_key_door_locked.cfg", cfg), OK)
	var problems := SaveCodec.validate(cfg)
	assert_eq(problems.size(), 1, "boss_key_door_locked es inconsistente a propósito")
	assert_true(problems.size() == 1 and "llave del jefe" in problems[0], str(problems))

