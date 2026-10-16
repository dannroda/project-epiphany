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


## Un escenario editado a mano con un solo botón, o con basura, no rompe al asignar.
func test_malformed_buttons_are_read_as_two() -> void:
	var state := _new_state()
	for saved: Array in [[&"bow"], [], [&"bow", &"bomb_bag", &"feather"], [3, &"no_existe"]]:
		var cfg := ConfigFile.new()
		cfg.set_value("inventory", "bow", 1)
		cfg.set_value("equipment", "buttons", saved)
		state.read_from(cfg)
		assert_eq(state.item_buttons.size(), 2, str(saved))
		assert_true(state.item_buttons.all(func(id: StringName) -> bool: return id == &"" or Items.get_item(id) != null), str(state.item_buttons))
		assert_true(state.assign_button(1, &"bow"), "se puede asignar con %s" % [saved])
	state.free()


## Una flag con otro tipo que su valor por defecto queda en el defecto.
func test_a_flag_of_the_wrong_type_is_skipped() -> void:
	var state := _new_state()
	var cfg := ConfigFile.new()
	var id: StringName = GameStateScript.FLAGS.definitions[0].id
	cfg.set_value("flags", id, "abierta")
	state.read_from(cfg)
	assert_eq(state.get_flag(id), GameStateScript.FLAGS.default_of(id))
	state.free()


## 11.86: un flag que no cambia no avisa.
func test_set_flag_only_emits_on_change() -> void:
	var state := _new_state()
	var emitted := [0]
	state.flag_changed.connect(func(_id: StringName, _value: Variant) -> void: emitted[0] += 1)
	state.set_flag(&"ow_test_chest", true)
	state.set_flag(&"ow_test_chest", true)
	assert_eq(emitted[0], 1, "la segunda vez no")
	state.set_flag(&"ow_test_chest", false)
	assert_eq(emitted[0], 2, "cambiar sí")
	state.free()


## 11.86: cargar avisa `loaded` y nada intermedio (ni la mazmorra ni ítem por ítem).
func test_reading_a_save_only_emits_loaded() -> void:
	var state := _new_state()
	state.give(Items.get_item(&"bomb"), 3)
	state.current_dungeon = &"ch"
	state.give(Items.get_item(&"small_key"))
	var cfg := ConfigFile.new()
	state.write_to(cfg)
	var heard: Array[String] = []
	state.dungeon_changed.connect(func() -> void: heard.append("dungeon"))
	state.inventory.changed.connect(func(_id: StringName, _count: int) -> void: heard.append("inventory"))
	state.flag_changed.connect(func(_id: StringName, _value: Variant) -> void: heard.append("flag"))
	state.loaded.connect(func() -> void: heard.append("loaded"))
	state.read_from(cfg)
	assert_eq(heard, ["loaded"] as Array[String])
	assert_eq(state.inventory.count(&"bomb"), 3, "y el inventario quedó cargado")
	assert_eq(state.current_dungeon, &"ch")
	heard.clear()
	state.give(Items.get_item(&"bomb"))
	assert_eq(heard, ["inventory"] as Array[String], "después de cargar vuelve a avisar")
	state.free()
