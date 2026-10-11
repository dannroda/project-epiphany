extends "res://tests/test_case.gd"
## Co-op (13.2): cada player lee su control; Start en otro control suma un player y mantenerlo lo saca.

const PAD_1 := 0
const PAD_2 := 1


func _load() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/test.tscn")
	await tree.scene_changed
	for i in 5:
		await tree.physics_frame
	var players: Node = tree.root.get_node(^"Players")
	players.lead_pad = PAD_1
	return [tree, players, players.lead()]


func _button(pad: int, button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = pad
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func _stick(pad: int, x: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = pad
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = x
	Input.parse_input_event(event)


func _cleanup(tree: SceneTree, players: Node) -> void:
	for slot in players.guests.keys():
		players.leave(slot)
	players.lead_pad = -1
	await tree.process_frame
	tree.root.get_node(^"GameState").reset()


func test_start_on_another_pad_joins_and_each_moves_its_own() -> void:
	var setup: Array = await _load()
	var tree: SceneTree = setup[0]
	var players: Node = setup[1]
	var first: PlayerCharacter = setup[2]
	_button(PAD_2, JOY_BUTTON_START, true)
	await tree.process_frame
	_button(PAD_2, JOY_BUTTON_START, false)
	await tree.physics_frame
	assert_eq(players.all.size(), 2, "entró el player 2")
	assert_eq(tree.paused, false, "sin pausar")
	var second: PlayerCharacter = players.all[1]
	assert_eq(second.controls.slot, 1)
	for i in 10:
		await tree.physics_frame
	var first_start := first.global_position
	var second_start := second.global_position
	_stick(PAD_2, 1.0)
	for i in 20:
		await tree.physics_frame
	_stick(PAD_2, 0.0)
	await tree.physics_frame
	assert_true(second.global_position.x - second_start.x > 0.5, "el control 2 mueve al player 2")
	assert_true(first.global_position.distance_to(first_start) < 0.1, "y no al 1")
	_stick(PAD_1, -1.0)
	for i in 20:
		await tree.physics_frame
	_stick(PAD_1, 0.0)
	assert_true(first.global_position.x - first_start.x < -0.5, "el control 1 mueve al player 1")
	await _cleanup(tree, players)


func test_holding_start_leaves_and_a_tap_pauses() -> void:
	var setup: Array = await _load()
	var tree: SceneTree = setup[0]
	var players: Node = setup[1]
	var first: PlayerCharacter = setup[2]
	players.join(PAD_2)
	await tree.physics_frame
	_button(PAD_2, JOY_BUTTON_START, true)
	await tree.process_frame
	_button(PAD_2, JOY_BUTTON_START, false)
	await tree.process_frame
	await tree.process_frame
	assert_eq(tree.paused, true, "un toque de Start del invitado pausa")
	tree.root.get_node(^"MenuStack").pop()
	await tree.process_frame
	_button(PAD_2, JOY_BUTTON_START, true)
	await tree.create_timer(players.LEAVE_HOLD + 0.2).timeout
	await tree.process_frame
	assert_eq(players.all.size(), 1, "mantener Start lo saca")
	assert_eq(tree.paused, false, "la partida sigue")
	assert_true(first.controls.shared, "el primero vuelve a leer todo")
	_button(PAD_2, JOY_BUTTON_START, false)
	await _cleanup(tree, players)


func test_guests_come_along_to_the_next_scene() -> void:
	var setup: Array = await _load()
	var tree: SceneTree = setup[0]
	var players: Node = setup[1]
	players.join(PAD_2)
	tree.change_scene_to_file("res://levels/test.tscn")
	await tree.scene_changed
	for i in 5:
		await tree.physics_frame
	assert_eq(players.all.size(), 2, "el invitado aparece en la escena nueva")
	assert_true(players.all[1].global_position.distance_to(players.lead().global_position) < 3.0, "al lado del primero")
	await _cleanup(tree, players)


func test_prompts_follow_each_players_device() -> void:
	var setup: Array = await _load()
	var tree: SceneTree = setup[0]
	var players: Node = setup[1]
	var second: PlayerCharacter = players.join(PAD_2)
	tree.root.get_node(^"InputDevice")._switch_to(0)
	assert_true(second.controls.uses_gamepad(), "el invitado ve los botones de su control aunque el último fue el teclado")
	assert_eq(players.lead().controls.uses_gamepad(), false, "el primero, con teclado, ve las teclas")
	assert_true(InputPrompts.icon_for(&"attack", second) != InputPrompts.icon_for(&"attack", players.lead()), "íconos distintos")
	await _cleanup(tree, players)
