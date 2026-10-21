extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test/test_targeting.tscn"


func _key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	if keycode == KEY_SHIFT:
		event.location = KEY_LOCATION_LEFT
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _mouse(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func test_keyboard_and_mouse_map() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var expectations := [
		[KEY_W, &"move_forward"], [KEY_A, &"move_left"], [KEY_S, &"move_backward"], [KEY_D, &"move_right"],
		[KEY_SPACE, &"dodge"], [KEY_E, &"interact"], [KEY_Q, &"item_1"], [KEY_R, &"item_2"],
		[KEY_SHIFT, &"z-lock"], [KEY_TAB, &"pause"], [KEY_ESCAPE, &"pause"], [KEY_M, &"map"],
		[KEY_3, &"debug_quicksave"], [KEY_2, &"debug_quickload"],
	]
	for pair in expectations:
		_key(pair[0], true)
		await tree.process_frame
		assert_true(Input.is_action_pressed(pair[1]), "%s → %s" % [OS.get_keycode_string(pair[0]), pair[1]])
		_key(pair[0], false)
		await tree.process_frame
	for pair in [[MOUSE_BUTTON_LEFT, &"attack"]]:
		_mouse(pair[0], true)
		await tree.process_frame
		assert_true(Input.is_action_pressed(pair[1]), str(pair[1]))
		_mouse(pair[0], false)
		await tree.process_frame
	var stack: Node = tree.root.get_node(^"MenuStack")
	while stack.is_open():
		stack.pop()
	var flow: Node = tree.root.get_node(^"SceneFlow")
	while flow.traveling:
		await tree.process_frame


func test_input_device_changes() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var device: Node = tree.root.get_node(^"InputDevice")
	var changes: Array = []
	device.input_device_changed.connect(func(d: int) -> void: changes.append(d))
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	Input.parse_input_event(pad)
	pad.pressed = false
	Input.parse_input_event(pad)
	await tree.process_frame
	_key(KEY_W, true)
	_key(KEY_W, false)
	await tree.process_frame
	assert_eq(changes, [1, 0], "gamepad y después teclado")


func test_shift_locks_and_wheel_switches() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy: Enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.bt_player.active = false
	for i in 10:
		await tree.physics_frame
	var targeting := (tree.get_first_node_in_group(&"player") as PlayerCharacter).targeting
	var stack: Node = tree.root.get_node(^"MenuStack")
	while stack.is_open():
		stack.pop()
	for i in 120:
		if targeting.possible_targets.size() >= 3 and not tree.paused:
			break
		await tree.physics_frame
	assert_true(not tree.paused, "el árbol no quedó en pausa")
	assert_eq(targeting.possible_targets.size(), 3, "los tres en el detector")
	_key(KEY_SHIFT, true)
	await _flush(tree)
	assert_eq(String(targeting.current.name) if targeting.current else "-", "Middle", "Shift fija")
	_mouse(MOUSE_BUTTON_WHEEL_DOWN, true)
	_mouse(MOUSE_BUTTON_WHEEL_DOWN, false)
	await _flush(tree)
	assert_eq(String(targeting.current.name) if targeting.current else "-", "Right", "rueda abajo → derecha")
	_mouse(MOUSE_BUTTON_WHEEL_UP, true)
	_mouse(MOUSE_BUTTON_WHEEL_UP, false)
	await _flush(tree)
	assert_eq(String(targeting.current.name) if targeting.current else "-", "Middle", "rueda arriba → izquierda")
	_key(KEY_SHIFT, false)
	await _flush(tree)
	assert_eq(targeting.current, null, "soltar Shift suelta (modo mantener)")


## Los eventos les llegan a los nodos un frame después de parse_input_event.
func _flush(tree: SceneTree) -> void:
	await tree.process_frame
	await tree.physics_frame
	await tree.process_frame
