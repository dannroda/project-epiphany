extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"


func _load_level(tree: SceneTree) -> void:
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 5:
		await tree.physics_frame


func test_chest_gives_once_and_stays_open() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var stack: Node = tree.root.get_node(^"MenuStack")
	state.reset()
	await _load_level(tree)
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var chest: Node = tree.current_scene.get_node(^"Chest")
	player.global_position = chest.global_position + Vector3(0, 0, 1.1)
	player.model.look_at(player.model.global_position + Vector3.BACK, Vector3.UP)
	for i in 4:
		await tree.physics_frame
	assert_eq(player.get_node(^"InteractionDetector").best(), chest.interactable, "el detector elige el cofre")

	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	Input.parse_input_event(event)
	for i in 3:
		await tree.physics_frame
	assert_eq(state.inventory.has(&"bomb_bag"), true, "da la bolsa de bombas")
	assert_eq(state.get_flag(&"ow_test_chest"), true)
	assert_eq(state.item_buttons[0], &"bomb_bag", "primer usable: va a un botón libre")
	assert_eq(player.movement_state.get_active_state().name, &"ItemGet")

	await tree.create_timer(1.0).timeout
	assert_true(stack.top() != null and stack.top().has_signal(&"closed"), "caja de item get abierta")
	assert_eq(stack.top().text_box.title_label.text, "¡Conseguiste la Bolsa de bombas!")
	assert_true(tree.paused, "el mundo en pausa")
	stack.pop()
	await tree.create_timer(1.2).timeout
	assert_eq(player.movement_state.get_active_state().name, &"Idle", "vuelve a Idle")

	state.inventory.remove(&"bomb_bag")
	await _load_level(tree)
	chest = tree.current_scene.get_node(^"Chest")
	assert_eq(chest.interactable.enabled, false, "sigue abierto al volver")
	assert_true(chest.lid.rotation_degrees.x < -90.0)
	chest.interactable.interact(tree.get_first_node_in_group(&"player"))
	assert_eq(state.inventory.has(&"bomb_bag"), false, "no da de nuevo")
	state.reset()


func test_give_auto_equips_empty_slot() -> void:
	var state: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"GameState")
	state.reset()
	state.equipment.erase(ItemData.Category.SHIELD)
	state.give(Items.get_item(&"shield_mirror"))
	assert_eq(state.equipment[ItemData.Category.SHIELD], &"shield_mirror", "ranura vacía: se equipa")
	state.give(Items.get_item(&"shield_wood"))
	assert_eq(state.equipment[ItemData.Category.SHIELD], &"shield_mirror", "ocupada: no cambia")
	state.give(Items.get_item(&"bow"))
	state.give(Items.get_item(&"potion"))
	state.give(Items.get_item(&"bomb_bag"))
	assert_eq(state.item_buttons, [&"bow", &"potion"] as Array[StringName], "sin botón libre no se asigna")
	state.reset()


func test_item_get_raises_both_hands_until_the_box_closes() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var stack: Node = tree.root.get_node(^"MenuStack")
	state.reset()
	await _load_level(tree)
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.play_item_get(Items.get_item(&"bow"))
	await tree.create_timer(0.8).timeout
	assert_true(stack.top() != null and stack.top().has_signal(&"closed"), "caja abierta")
	assert_eq(player.anim_tree.get(&"parameters/CarryBlend/blend_amount"), 1.0, "en la pose de item get")
	assert_true(String(player.anim_tree.get(&"parameters/CarryPhase/current_state")).begins_with("Item"))
	assert_true(not player.equipment.weapon_socket.visible, "guarda la espada para levantar el ítem")
	var hands := (player.equipment.weapon_socket.global_position + player.equipment.shield_hand_socket.global_position) * 0.5
	assert_true(hands.y - player.global_position.y > 1.3, "las manos en alto")
	stack.pop()
	await tree.create_timer(0.6).timeout
	assert_eq(player.movement_state.get_active_state().name, &"Idle", "vuelve a Idle")
	assert_eq(player.anim_tree.get(&"parameters/CarryBlend/blend_amount"), 0.0, "sale de la pose")
	assert_true(player.equipment.weapon_socket.visible, "la espada vuelve a la mano")
	state.reset()
