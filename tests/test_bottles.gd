extends "res://tests/test_case.gd"


func _state() -> Node:
	var state: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"GameState")
	state.reset()
	return state


func test_two_bottles_with_the_same_content_are_two() -> void:
	var state := _state()
	state.give(Items.get_item(&"potion"))
	state.give(Items.get_item(&"potion"))
	assert_eq(state.bottles, {&"bottle_1": &"potion", &"bottle_2": &"potion"}, "cada poción en su botella")
	assert_true(state.inventory.has(&"bottle_1") and state.inventory.has(&"bottle_2"))
	assert_eq(state.item_for(&"bottle_2").id, &"potion", "la botella muestra lo que tiene")
	state.reset()


func test_four_bottles_at_most() -> void:
	var state := _state()
	state.give(Items.get_item(&"holy_water"), 5)
	assert_eq(state.bottles.size(), 4, "no hay más de cuatro")
	state.reset()


func test_contents_fill_an_empty_bottle_first() -> void:
	var state := _state()
	state.give(Items.get_item(&"bottle_empty"))
	state.give(Items.get_item(&"potion"))
	assert_eq(state.bottles, {&"bottle_1": &"potion"}, "llena la vacía en vez de sumar otra")
	state.give(Items.get_item(&"bottle_empty"))
	assert_eq(state.bottles, {&"bottle_1": &"potion", &"bottle_2": &"bottle_empty"}, "una vacía nueva es otra botella")
	state.reset()


func test_drinking_empties_only_that_bottle() -> void:
	var state := _state()
	state.give(Items.get_item(&"potion"))
	state.give(Items.get_item(&"potion"))
	state.swap_item(&"bottle_2", Items.get_item(&"bottle_empty"))
	assert_eq(state.bottles, {&"bottle_1": &"potion", &"bottle_2": &"bottle_empty"})
	assert_true(state.inventory.has(&"bottle_2"), "la botella vacía se queda")
	state.reset()


func test_bottles_are_saved() -> void:
	var state := _state()
	state.give(Items.get_item(&"potion"))
	state.give(Items.get_item(&"holy_water"))
	var cfg := ConfigFile.new()
	state.write_to(cfg)
	state.reset()
	state.read_from(cfg)
	assert_eq(state.bottles, {&"bottle_1": &"potion", &"bottle_2": &"holy_water"})
	assert_eq(state.item_buttons, [&"bottle_1", &"bottle_2"] as Array[StringName])
	state.reset()


func test_old_saves_move_their_potions_into_bottles() -> void:
	var state := _state()
	var cfg := ConfigFile.new()
	state.write_to(cfg)
	cfg.set_value("inventory", "potion", 1)
	cfg.set_value("inventory", "holy_water", 1)
	cfg.set_value("equipment", "buttons", [&"holy_water", &""] as Array[StringName])
	SaveCodec.migrate(cfg)
	state.read_from(cfg)
	assert_eq(state.bottles.size(), 2, "una botella por cada contenido")
	assert_true(not state.inventory.has(&"potion") and not state.inventory.has(&"holy_water"), "los contenidos ya no van sueltos")
	var on_x: StringName = state.item_buttons[0]
	assert_eq(state.item_for(on_x).id, &"holy_water", "el botón pasa a la botella que la lleva")
	state.reset()
