extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"


func _open() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 5:
		await tree.process_frame
	for id in [&"bow", &"bomb_bag"]:
		state.give(Items.get_item(id))
	state.inventory.remove(&"arrow", state.inventory.count(&"arrow"))
	state.inventory.remove(&"bomb", state.inventory.count(&"bomb"))
	state.give(Items.get_item(&"arrow"), 12)
	var stack: Node = tree.root.get_node(^"MenuStack")
	stack.push(load("res://src/ui/menus/pause_menu.tscn").instantiate())
	await tree.process_frame
	stack.top().show_page(1)
	await tree.process_frame
	var page: Control = stack.top().pages.get_node(^"Ítems")
	return [tree, state, stack, page]


func _slot_for(page: Control, id: StringName) -> Button:
	for slot in page._slots:
		if page._slots[slot].id == id:
			return slot
	return null


func _press_key(tree: SceneTree, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	tree.root.push_input(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	tree.root.push_input(release)
	await tree.process_frame
	await tree.process_frame


func test_assign_button_swaps() -> void:
	var state: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"GameState")
	state.reset()
	state.assign_button(0, &"bow")
	state.assign_button(1, &"bomb_bag")
	assert_eq(state.item_buttons, [&"bow", &"bomb_bag"] as Array[StringName])
	state.assign_button(1, &"bow")
	assert_eq(state.item_buttons, [&"bomb_bag", &"bow"] as Array[StringName], "se intercambian")
	var cfg := ConfigFile.new()
	state.write_to(cfg)
	state.reset()
	state.read_from(cfg)
	assert_eq(state.item_buttons, [&"bomb_bag", &"bow"] as Array[StringName], "sobreviven al guardado")
	state.reset()


func test_keys_assign_on_the_items_page() -> void:
	var setup: Array = await _open()
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var stack: Node = setup[2]
	var page: Control = setup[3]
	var bow := _slot_for(page, &"bow")
	assert_eq(tree.root.get_viewport().gui_get_focus_owner(), bow, "el foco arranca en el primer ítem")
	assert_eq(bow.get_node(^"Count").text, "12", "munición en la celda")
	assert_eq(page.dungeon_box.visible, false, "objetos de mazmorra solo dentro de una")

	await _press_key(tree, KEY_Q)
	assert_eq(state.item_buttons[0], &"bow", "Q asigna a X")
	assert_eq(stack.top().current, 1, "Q no cambió de pestaña")
	assert_true(bow.get_node(^"Badge").visible, "marca del botón")

	_slot_for(page, &"bomb_bag").grab_focus()
	await _press_key(tree, KEY_R)
	assert_eq(state.item_buttons, [&"bow", &"bomb_bag"] as Array[StringName])
	await _press_key(tree, KEY_Q)
	assert_eq(state.item_buttons, [&"bomb_bag", &"bow"] as Array[StringName], "se intercambian")
	var actions: Array = page.detail.actions.get_children().filter(func(b: Node) -> bool: return not b.is_queued_for_deletion()).map(func(b: Button) -> String: return b.text)
	assert_eq(actions, [tr("ITEMS_ASSIGNED").format({button = "X"}), tr("ITEMS_ASSIGN").format({button = "Y"})], "botones del detalle")

	state.inventory.remove(&"arrow", 2)
	await tree.process_frame
	assert_eq(bow.get_node(^"Count").text, "10", "se actualiza con Inventory.changed")

	var locked := page.grid.get_child(page.grid.get_child_count() - 1) as Button
	locked.grab_focus()
	await _press_key(tree, KEY_Q)
	assert_eq(stack.top().current, 0, "sin ítem enfocado, Q cambia de pestaña")
	stack.pop()
	state.reset()
