extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"


func _open(max_health := 0) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	if max_health:
		state.max_health = max_health
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 5:
		await tree.process_frame
	state.give(Items.get_item(&"shield_mirror"))
	state.give(Items.get_item(&"armor_chainmail"))
	var stack: Node = tree.root.get_node(^"MenuStack")
	stack.push(load("res://src/ui/menus/pause_menu.tscn").instantiate())
	for i in 3:
		await tree.process_frame
	var page: Control = stack.top().pages.get_node(^"Equipo")
	return [tree, state, stack, page]


func _slot_for(page: Control, id: StringName) -> Button:
	for slot in page._slots:
		if page._slots[slot].id == id:
			return slot
	return null


func test_equip_from_the_screen() -> void:
	var setup: Array = await _open()
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var stack: Node = setup[2]
	var page: Control = setup[3]
	var focused := tree.root.get_viewport().gui_get_focus_owner()
	assert_eq(focused, _slot_for(page, &"sword_basic"), "el foco arranca en lo equipado")
	assert_true(stack.top().hints.find_children("*", "Label", true, false).any(func(c: Node) -> bool: return c.text.begins_with("Equipar")), "ayuda: Equipar")

	var mirror := _slot_for(page, &"shield_mirror")
	assert_eq(mirror.disabled, false)
	mirror.grab_focus()
	mirror.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	assert_eq(state.equipment[ItemData.Category.SHIELD], &"shield_mirror")
	assert_eq(mirror.get_node(^"Badge").visible, true, "marca E en el nuevo")
	assert_eq(_slot_for(page, &"shield_wood").get_node(^"Badge").visible, false)
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	assert_eq(player.equipment.shield_on_back.scene_file_path, "res://assets/items/shield/shield_mirror.tscn", "el player cambió de escudo")

	var chainmail := _slot_for(page, &"armor_chainmail")
	chainmail.grab_focus()
	await tree.process_frame
	var stats: Array = page.detail.stats.get_children().filter(func(row: Node) -> bool: return row is MarginContainer).map(func(row: Node) -> String: return row.get_child(0).get_child(1).text)
	assert_eq(stats, ["25 %"], "detalle de la armadura")
	stack.pop()
	state.reset()


func test_unowned_slots_are_locked() -> void:
	var setup: Array = await _open()
	var stack: Node = setup[2]
	var page: Control = setup[3]
	var state: Node = setup[1]
	state.inventory.remove(&"armor_chainmail")
	page._refresh()
	assert_eq(_slot_for(page, &"armor_chainmail").disabled, true, "sin la cota, ranura bloqueada")
	assert_eq(_slot_for(page, &"armor_chainmail").icon, page.LOCK)
	stack.pop()
	state.reset()


func test_max_hearts_keep_the_layout() -> void:
	var setup: Array = await _open(80)
	var page: Control = setup[3]
	var left: Control = page.get_node(^"Left")
	assert_eq(page.hearts.get_child_count(), 20)
	assert_true(left.size.x <= left.custom_minimum_size.x, "la columna no se ensancha")
	assert_true(page.hearts.size.y < 60.0, "20 corazones en 2 filas")
	setup[2].pop()
	setup[1].reset()
