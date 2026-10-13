extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"
const BIG_POT := preload("res://src/world/big_pot.tscn")
const FLOOR_SWITCH := preload("res://src/world/floor_switch.tscn")
const SPOT := Vector3(6, 0.25, 6)


func _setup() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	var skeleton: Enemy = null
	for enemy in tree.get_nodes_in_group(&"enemies"):
		if enemy is Enemy and skeleton == null:
			skeleton = enemy
		else:
			enemy.free()
	skeleton.bt_player.active = false
	skeleton.stop_moving()
	skeleton.global_position = Vector3(20, 0.25, 20)
	var pot: BigPot = BIG_POT.instantiate()
	tree.current_scene.add_child(pot)
	pot.global_position = SPOT
	pot._start = SPOT
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.global_position = SPOT + Vector3(0, 0, 1.3)
	player.model.look_at(player.model.global_position + Vector3.BACK, Vector3.UP)
	await tree.create_timer(0.5).timeout
	return [tree, state, player, pot, skeleton]


func _tap(tree: SceneTree, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await tree.physics_frame
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)
	await tree.physics_frame


func _hold(action: StringName, on: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = on
	event.strength = 1.0 if on else 0.0
	Input.parse_input_event(event)


func _lift(tree: SceneTree) -> void:
	await _tap(tree, &"interact")
	await tree.create_timer(0.8).timeout


func _state(player: PlayerCharacter) -> StringName:
	return player.movement_state.get_active_state().name


func test_pushed_like_a_block() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var pot: BigPot = setup[3]
	_hold(&"move_forward", true)
	await tree.create_timer(1.5).timeout
	_hold(&"move_forward", false)
	assert_true(pot.global_position.distance_to(SPOT + Vector3(0, 0, -PushBlock.CELL)) < 0.05, "empujada una celda (quedó en %s)" % pot.global_position)
	setup[1].reset()


func test_still_hands_set_it_down_ahead() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var pot: BigPot = setup[3]
	await _lift(tree)
	assert_eq(_state(player), &"Carrying", "interactuar la levanta")
	await _tap(tree, &"interact")
	await tree.create_timer(0.5).timeout
	assert_eq(_state(player), &"Idle")
	assert_eq(pot.broken, false, "apoyada no se rompe")
	assert_true(pot.get_parent() == tree.current_scene, "vuelve a la escena")
	var ahead := SPOT
	ahead.y = player.global_position.y
	assert_true(pot.global_position.distance_to(ahead) < 0.05, "en la celda de adelante, la suya (quedó en %s)" % pot.global_position)
	assert_eq(pot.shape.disabled, false, "otra vez sólida")
	assert_true(pot.try_push(Vector3.FORWARD), "y se puede volver a empujar")
	setup[1].reset()


func test_with_a_direction_it_is_thrown_and_breaks() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var pot: BigPot = setup[3]
	setup[4].global_position = Vector3(40, 0.25, 40)
	await _lift(tree)
	_hold(&"move_left", true)
	await tree.create_timer(0.2).timeout
	await _tap(tree, &"interact")
	_hold(&"move_left", false)
	await tree.create_timer(1.5).timeout
	assert_true(pot.broken, "tirada se rompe")
	assert_true(pot.global_position.x < player.global_position.x, "hacia la izquierda")
	setup[1].reset()


func test_a_hit_while_carrying_drops_and_breaks_it() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var pot: BigPot = setup[3]
	var skeleton: Enemy = setup[4]
	await _lift(tree)
	var info := DamageInfo.make(1, 0.0, skeleton)
	info.team = EntityConfig.Team.ENEMY
	player.hurtbox.receive(info)
	await tree.create_timer(1.5).timeout
	assert_eq(player.carrier.is_carrying(), false, "la suelta")
	assert_true(pot.broken, "y se rompe al caer")
	setup[1].reset()


func test_the_sword_breaks_it_and_it_comes_back_whole() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var pot: BigPot = setup[3]
	await _tap(tree, &"attack")
	await tree.create_timer(0.6).timeout
	assert_true(pot.broken, "la espada la rompe")
	assert_eq(pot.visible, false)
	pot.reset_position()
	await tree.physics_frame
	assert_true(not pot.broken and pot.visible and not pot.shape.disabled, "al salir de la sala vuelve entera")
	setup[1].reset()


func test_pushed_onto_a_weight_switch_presses_it() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var pot: BigPot = setup[3]
	var plate: FloorSwitch = FLOOR_SWITCH.instantiate()
	plate.mode = FloorSwitch.Mode.WEIGHT
	tree.current_scene.add_child(plate)
	plate.global_position = SPOT + Vector3(0, 0, -PushBlock.CELL)
	await tree.physics_frame
	assert_true(pot.try_push(Vector3.FORWARD))
	await tree.create_timer(0.8).timeout
	assert_true(plate.active, "la placa queda apretada")
	setup[1].reset()
