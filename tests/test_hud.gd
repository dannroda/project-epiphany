extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"


func _quarters(tree: SceneTree) -> Array:
	var hud: Node = tree.current_scene.get_node(^"HUD")
	return hud.hearts.get_children().map(func(h: HeartIcon) -> int: return h.quarters)


func test_hearts_follow_health() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var game_state: Node = tree.root.get_node(^"GameState")
	game_state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.process_frame
	await tree.process_frame
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	assert_eq(_quarters(tree), [4, 4, 4], "3 corazones llenos")
	player.health.invulnerability_time = 0.0
	player.health.damage(1)
	assert_eq(_quarters(tree), [4, 4, 3], "un cuarto menos")
	player.health.damage(4)
	assert_eq(_quarters(tree), [4, 3, 0], "un corazón menos")
	player.health.heal(2)
	assert_eq(_quarters(tree), [4, 4, 1])
	game_state.max_health = 20
	game_state.loaded.emit()
	assert_eq(_quarters(tree), [4, 4, 4, 4, 4], "más vida máxima, más corazones")
	game_state.reset()


func test_item_slots_follow_buttons_and_ammo() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var device: Node = tree.root.get_node(^"InputDevice")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.process_frame
	var hud: Node = tree.current_scene.get_node(^"HUD")
	var x: Control = hud.item_slots.get_child(0).get_node(^"Body")
	var y: Control = hud.item_slots.get_child(1).get_node(^"Body")
	assert_eq(x.get_node(^"Icon").texture, null, "vacío sin ítem asignado")
	assert_eq(x.get_node(^"Ammo").visible, false)

	state.give(Items.get_item(&"bow"))
	state.give(Items.get_item(&"bomb_bag"))
	state.give(Items.get_item(&"arrow"), 12)
	state.assign_button(0, &"bow")
	assert_eq(x.get_node(^"Icon").texture, Items.get_item(&"bow").icon)
	assert_eq(x.get_node(^"Ammo").text, "12")
	state.inventory.remove(&"arrow")
	assert_eq(x.get_node(^"Ammo").text, "11", "la munición baja")

	state.assign_button(0, &"bomb_bag")
	assert_eq(x.get_node(^"Icon").texture, Items.get_item(&"bomb_bag").icon, "reasignar cambia el slot")
	assert_eq(x.get_node(^"Ammo").text, "0")
	assert_eq(y.get_node(^"Icon").texture, Items.get_item(&"bow").icon, "intercambio con Y")

	device._switch_to(1)
	assert_eq(x.get_node(^"Badge").texture, InputPrompts.icon(&"item_1", true), "ícono de gamepad")
	device._switch_to(0)
	assert_eq(x.get_node(^"Badge").texture, InputPrompts.icon(&"item_1", false), "ícono de teclado")
	state.reset()
