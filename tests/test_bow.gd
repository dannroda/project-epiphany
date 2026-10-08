extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"


func _setup(arrows: int) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	state.give(Items.get_item(&"bow"))
	if arrows > 0:
		state.give(Items.get_item(&"arrow"), arrows)
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var eye: EyeSwitch = tree.current_scene.get_node(^"EyeSwitch")
	player.global_position = eye.global_position + Vector3(0, 0, 7)
	for i in 3:
		await tree.physics_frame
	return [tree, state, player, eye]


func _action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _shoot(tree: SceneTree, player: PlayerCharacter) -> void:
	_action(&"item_1", true)
	await tree.create_timer(0.4).timeout
	assert_eq(player.movement_state.get_active_state().name, &"AimingItem", "mantener apunta")
	assert_true(player.aim.aiming, "el modelo sigue la mira")
	_action(&"item_1", false)
	await tree.create_timer(0.8).timeout


func _face(player: PlayerCharacter, direction: Vector3) -> void:
	player.model.look_at(player.model.global_position - direction, Vector3.UP)


func test_shoot_eye_switch_facing_it() -> void:
	var setup: Array = await _setup(10)
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	var eye: EyeSwitch = setup[3]
	var activations: Array = []
	eye.activated.connect(func() -> void: activations.append(true))
	_face(player, Vector3.FORWARD)
	await _shoot(tree, player)
	assert_eq(state.inventory.count(&"arrow"), 9, "gasta una flecha")
	assert_eq(activations.size(), 1, "la flecha activa el ojo a distancia")
	assert_eq(player.movement_state.get_active_state().name, &"Idle", "vuelve a Idle")
	assert_eq(player.aim.aiming, false)
	state.reset()


func test_shoot_with_right_stick() -> void:
	var setup: Array = await _setup(10)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var eye: EyeSwitch = setup[3]
	_face(player, Vector3.RIGHT)
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_Y
	stick.axis_value = -1.0
	Input.parse_input_event(stick)
	await tree.physics_frame
	await _shoot(tree, player)
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	assert_eq(eye.active, true, "el stick derecho apunta aunque el player mire a otro lado")
	setup[1].reset()


func test_no_arrows_denies() -> void:
	var setup: Array = await _setup(0)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var denied: Array = []
	player.item_denied.connect(func(button: int) -> void: denied.append(button))
	_action(&"item_1", true)
	for i in 3:
		await tree.physics_frame
	_action(&"item_1", false)
	assert_eq(denied, [0], "sin flechas suena el no se puede")
	assert_true(player.movement_state.get_active_state().name != &"AimingItem", "no tensa el arco")
	setup[1].reset()


func test_big_quiver_raises_capacity() -> void:
	var state: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"GameState")
	state.reset()
	assert_eq(state.inventory.capacity(&"arrow"), 30)
	state.give(Items.get_item(&"quiver_big"))
	assert_eq(state.inventory.capacity(&"arrow"), 50, "el carcaj grande suma 20")
	state.reset()
