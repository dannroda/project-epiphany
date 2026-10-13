extends "res://tests/test_case.gd"
## 13.9: el anillo de ítems (LB / F) y el menú compartido con un cursor por player, que se eligen con la tecla 5.

const PAD_1 := 0
const PAD_2 := 1


func _level(coop: bool) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var players: Node = tree.root.get_node(^"Players")
	Settings.path = "user://test_settings.cfg"
	Settings.load_settings()
	GameState.reset()
	tree.change_scene_to_file("res://levels/test_rooms.tscn")
	await tree.scene_changed
	for i in 4:
		await tree.physics_frame
	tree.current_scene.get_node(^"Skeleton").free()
	for id in [&"bow", &"bomb_bag", &"potion"]:
		GameState.give(Items.get_item(id))
	var second: PlayerCharacter = null
	if coop:
		players.lead_pad = PAD_1
		second = players.join(PAD_2)
	for i in 3:
		await tree.process_frame
	var hud := tree.get_first_node_in_group(&"hud")
	return [tree, hud, players.lead(), second]


func _done() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var players: Node = tree.root.get_node(^"Players")
	for action in InputMap.get_actions():
		Input.action_release(action)
	for slot in players.guests.keys():
		players.leave(slot)
	players.lead_pad = -1
	MenuStack.clear()
	Engine.time_scale = 1.0
	await tree.process_frame
	Settings.set_value(&"coop_item_menu", "ring")
	Settings.path = Settings.PATH
	Settings.load_settings()
	GameState.reset()


## Apunta el stick del player hacia el slot `index` del anillo.
func _point(player: PlayerCharacter, ring: ItemRing, index: int) -> void:
	var c := player.controls
	for name in [&"move_left", &"move_right", &"move_forward", &"move_backward"]:
		Input.action_release(c.action(name))
	var angle := TAU * index / ring._items.size()
	var x := sin(angle)
	var y := -cos(angle)
	if absf(x) > 0.01:
		Input.action_press(c.action(&"move_right" if x > 0 else &"move_left"), absf(x))
	if absf(y) > 0.01:
		Input.action_press(c.action(&"move_backward" if y > 0 else &"move_forward"), absf(y))


func _press(tree: SceneTree, action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
	await tree.process_frame
	await tree.process_frame


func _index(ring: ItemRing, id: StringName) -> int:
	return ring._items.find(Items.get_item(id))


func test_solo_ring_nearly_stops_the_world_and_assigns() -> void:
	var setup: Array = await _level(false)
	var tree: SceneTree = setup[0]
	var hud: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	var ring: ItemRing = hud.ring_of(player)
	assert_true(ring != null and not ring.is_open(), "hay anillo y arranca cerrado")
	Input.action_press(&"item_ring")
	await tree.process_frame
	await tree.process_frame
	assert_true(ring.is_open(), "mantener LB / F lo abre")
	assert_true(Engine.time_scale < 0.1, "el mundo casi se detiene")
	assert_true(hud.slow_dim.visible, "y se oscurece")
	assert_true(player.controls.captured, "el player no se mueve ni usa ítems")

	_point(player, ring, _index(ring, &"bottle_1"))
	await tree.process_frame
	assert_eq(ring._items[ring._selected].id, &"bottle_1", "el stick elige la botella con la poción")
	await _press(tree, &"item_1")
	assert_eq(GameState.item_buttons[0], &"bottle_1", "X la pone en X")

	Input.action_release(&"item_ring")
	await tree.process_frame
	await tree.process_frame
	assert_true(not ring.is_open() and Engine.time_scale == 1.0 and not hud.slow_dim.visible, "soltar cierra y el mundo sigue")
	assert_true(not player.controls.captured)
	await _done()


func test_the_ring_does_not_open_while_a_cutscene_has_the_controls() -> void:
	var setup: Array = await _level(false)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var ring: ItemRing = setup[1].ring_of(player)
	player.controls.captured = true
	Input.action_press(&"item_ring")
	await tree.process_frame
	await tree.process_frame
	assert_true(not ring.is_open(), "con los controles tomados por una cutscene, LB no abre el anillo")
	assert_eq(Engine.time_scale, 1.0, "ni frena la cutscene")
	Input.action_release(&"item_ring")
	await tree.process_frame
	assert_true(player.controls.captured, "y la cutscene sigue con los controles")
	player.controls.captured = false
	await _done()


func test_coop_ring_does_not_pause_and_respects_owners() -> void:
	var setup: Array = await _level(true)
	var tree: SceneTree = setup[0]
	var hud: Node = setup[1]
	var second: PlayerCharacter = setup[3]
	var ring: ItemRing = hud.ring_of(second)
	Input.action_press(second.controls.action(&"item_ring"))
	await tree.process_frame
	await tree.process_frame
	assert_true(ring.is_open(), "el P2 abre el suyo")
	assert_true(not hud.ring_of(setup[2]).is_open(), "el del P1 sigue cerrado")
	assert_eq(Engine.time_scale, 1.0, "en co-op no se frena nada")

	_point(second, ring, _index(ring, &"bow"))
	await tree.process_frame
	var bow_slot := ring.slots.get_child(_index(ring, &"bow"))
	assert_true(bow_slot.get_node(^"Owner").visible, "el arco del P1 se ve con su etiqueta")
	await _press(tree, second.controls.action(&"item_1"))
	assert_eq(GameState.buttons_of(1)[0], &"", "no se lo puede sacar")

	_point(second, ring, _index(ring, &"bottle_1"))
	await tree.process_frame
	await _press(tree, second.controls.action(&"item_1"))
	assert_eq(GameState.buttons_of(1)[0], &"bottle_1", "la poción libre sí")
	await _done()


func test_toggle_switches_to_one_menu_with_a_cursor_each() -> void:
	var setup: Array = await _level(true)
	var tree: SceneTree = setup[0]
	var hud: Node = setup[1]
	var second: PlayerCharacter = setup[3]
	await _press(tree, &"debug_item_menu")
	assert_eq(Settings.get_value(&"coop_item_menu"), "shared", "la tecla 5 cambia de modo")
	Input.action_press(second.controls.action(&"item_ring"))
	await tree.process_frame
	await tree.process_frame
	assert_true(not hud.ring_of(second).is_open(), "con el menú compartido no hay anillo")
	Input.action_release(second.controls.action(&"item_ring"))

	MenuStack.push(load("res://src/ui/menus/pause_menu.tscn").instantiate())
	await tree.process_frame
	MenuStack.top().show_page(1)
	await tree.process_frame
	await tree.process_frame
	var page: Control = MenuStack.top().pages.get_node(^"Ítems")
	assert_true(page.coop_box.visible and not page.detail.visible, "una tarjeta por player en vez del detalle")
	assert_eq(page.cards.get_child_count(), 2)
	var focus := tree.root.get_viewport().gui_get_focus_owner()

	for event in [_pad_button(JOY_BUTTON_DPAD_DOWN), _pad_button(JOY_BUTTON_DPAD_DOWN)]:
		Input.parse_input_event(event)
		await tree.process_frame
	assert_eq(page.cursor_of(1), 8, "el control del P2 mueve su cursor, hasta la fila de botellas")
	assert_eq(tree.root.get_viewport().gui_get_focus_owner(), focus, "sin mover el del P1")
	var potion_slot: Control = page.bottle_grid.get_child(0)
	assert_eq(page._slots.get(potion_slot).id, &"bottle_1", "la botella con la poción")
	Input.parse_input_event(_pad_button(JOY_BUTTON_X))
	await tree.process_frame
	assert_eq(GameState.buttons_of(1)[0], &"bottle_1", "X del P2 se la pone a él")
	await tree.process_frame
	assert_true(potion_slot.get_node(^"Owner").visible, "la celda muestra de quién es")
	await _done()


func _pad_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = PAD_2
	event.button_index = button
	event.pressed = true
	return event
