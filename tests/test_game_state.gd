extends "res://tests/test_case.gd"

const GameStateScript := preload("res://src/state/game_state.gd")


func _new_state() -> Node:
	var state: Node = GameStateScript.new()
	state.reset()
	return state


func test_new_game() -> void:
	var state := _new_state()
	assert_eq(state.max_health, 12)
	assert_eq(state.equipment[ItemData.Category.SWORD], &"sword_basic")
	assert_eq(state.equipment[ItemData.Category.SHIELD], &"shield_wood")
	assert_eq(state.equipment[ItemData.Category.ARMOR], &"tunic")
	assert_eq(state.inventory.count(&"sword_basic"), 1)
	state.free()


func test_write_then_read_restores_state() -> void:
	var state := _new_state()
	state.give(Items.get_item(&"bomb"), 3)
	state.set_flag(&"ow_test_chest", true)
	state.current_dungeon = &"d1"
	state.give(Items.get_item(&"small_key"))
	state.current_dungeon_state().visit(5)
	state.item_buttons = [&"bomb_bag", &""] as Array[StringName]
	state.equip(Items.get_item(&"shield_mirror"))
	var cfg := ConfigFile.new()
	state.write_to(cfg)

	state.give(Items.get_item(&"bomb"), 5)
	state.set_flag(&"ow_test_chest", false)
	state.give(Items.get_item(&"heart_container"))
	state.read_from(cfg)

	assert_eq(state.inventory.count(&"bomb"), 3)
	assert_eq(state.get_flag(&"ow_test_chest"), true)
	assert_eq(state.max_health, 12)
	assert_eq(state.dungeons[&"d1"].small_keys, 1)
	assert_true(state.dungeons[&"d1"].was_visited(5))
	assert_eq(state.item_buttons, [&"bomb_bag", &""] as Array[StringName])
	assert_eq(state.equipment[ItemData.Category.SHIELD], &"shield_mirror")
	state.free()


func test_read_clears_previous_game() -> void:
	var state := _new_state()
	var cfg := ConfigFile.new()
	state.write_to(cfg)
	state.set_flag(&"ow_test_chest", true)
	state.give(Items.get_item(&"arrow"), 10)
	state.current_dungeon = &"d1"
	state.give(Items.get_item(&"boss_key"))
	state.read_from(cfg)
	assert_eq(state.get_flag(&"ow_test_chest"), false)
	assert_eq(state.inventory.count(&"arrow"), 0)
	assert_true(state.dungeons.is_empty())
	state.free()


func test_give_routes_special_items() -> void:
	var state := _new_state()
	state.current_dungeon = &"d1"
	state.give(Items.get_item(&"small_key"), 2)
	state.give(Items.get_item(&"dungeon_map"))
	state.give(Items.get_item(&"heart_container"))
	assert_eq(state.current_dungeon_state().small_keys, 2)
	assert_true(state.current_dungeon_state().has_map)
	assert_eq(state.max_health, 16)
	assert_eq(state.inventory.has(&"small_key"), false)
	state.free()


func test_unknown_item_in_save_is_skipped() -> void:
	var state := _new_state()
	var cfg := ConfigFile.new()
	cfg.set_value("inventory", "no_existe", 2)
	cfg.set_value("inventory", "bomb", 4)
	state.read_from(cfg)
	assert_eq(state.inventory.count(&"bomb"), 4)
	assert_eq(state.inventory.ids().size(), 1)
	state.free()
