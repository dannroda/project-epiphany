extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"
const BOMB := preload("res://src/items/bomb/bomb.tscn")


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
	state.give(Items.get_item(&"bomb_bag"))
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.global_position = Vector3(0, 0.25, -8)
	player.health.invulnerability_time = 0.0
	await tree.physics_frame
	return [tree, state, player, skeleton]


func _press(tree: SceneTree, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)
	for i in 3:
		await tree.physics_frame


func _bombs(tree: SceneTree) -> Array:
	return tree.get_nodes_in_group(&"bombs")


func test_bag_comes_with_bombs_and_places_one() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	assert_eq(state.inventory.count(&"bomb"), 10, "la bolsa trae 10 bombas")
	assert_eq(state.item_buttons[0], &"bomb_bag")
	player.model.look_at(player.model.global_position + Vector3.BACK, Vector3.UP)
	await _press(tree, &"item_1")
	await tree.create_timer(1.0).timeout
	assert_eq(_bombs(tree).size(), 1, "coloca una bomba")
	assert_eq(state.inventory.count(&"bomb"), 9)
	if _bombs(tree).size() == 1:
		var bomb: Node3D = _bombs(tree)[0]
		var ahead := bomb.global_position - player.global_position
		ahead.y = 0.0
		assert_true(ahead.length() < 1.6 and ahead.normalized().dot(Vector3.FORWARD) > 0.7, "delante del player")
	state.reset()


func test_explosion_hurts_everyone_and_launches_boxes() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var skeleton: Enemy = setup[3]
	var box: RigidBody3D = tree.current_scene.get_node(^"Caja3")
	var spot := Vector3(-3, 0.5, -10)
	skeleton.global_position = spot + Vector3(1.2, -0.25, 0)
	box.global_position = spot + Vector3(-1.0, 0.4, 0)
	player.global_position = spot + Vector3(0, -0.25, 1.5)
	player.model.look_at(player.model.global_position + Vector3.BACK, Vector3.UP)
	player.movement_state.blackboard.set_var("is_blocking", true)
	player.set_guard(true)
	await tree.physics_frame
	var bomb: Bomb = BOMB.instantiate()
	tree.current_scene.add_child(bomb)
	bomb.global_position = spot
	var skeleton_hp := skeleton.health.current
	var box_start := box.global_position
	await tree.create_timer(2.4).timeout
	assert_eq(is_instance_valid(bomb), false, "explota a los 2 s")
	assert_true(skeleton.health.current < skeleton_hp, "daña al esqueleto")
	assert_true(box.global_position.distance_to(box_start) > 1.0, "la caja sale volando")
	assert_true(player.health.current < player.health.max_health, "el player también se lastima, aunque bloquee con madera")
	setup[1].reset()


func test_only_two_bombs_at_once() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var denied: Array = []
	player.item_denied.connect(func(button: int) -> void: denied.append(button))
	for i in 3:
		await _press(tree, &"item_1")
		while player.movement_state.get_active_state().name == &"UsingItem":
			await tree.physics_frame
	assert_eq(_bombs(tree).size(), 2, "dos bombas a la vez")
	assert_eq(denied, [0], "la tercera no sale")
	setup[1].reset()


func test_throw_lands_near_locked_target() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var skeleton: Enemy = setup[3]
	skeleton.global_position = player.global_position + Vector3(4, 0, -3)
	await tree.physics_frame
	player.targeting.set_target(skeleton)
	await _press(tree, &"item_1")
	await tree.create_timer(1.4).timeout
	assert_eq(_bombs(tree).size(), 1)
	if _bombs(tree).size() == 1:
		var landed: Vector3 = _bombs(tree)[0].global_position
		landed.y = skeleton.global_position.y
		assert_true(landed.distance_to(skeleton.global_position) < 1.8, "cae cerca del objetivo (a %.1f m)" % landed.distance_to(skeleton.global_position))
	player.targeting.clear()
	setup[1].reset()


func test_chain_reaction_and_pots() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var pot: Node3D = tree.current_scene.get_node(^"Pot1")
	var first: Bomb = BOMB.instantiate()
	var second: Bomb = BOMB.instantiate()
	second.fuse = 30.0
	tree.current_scene.add_child(first)
	tree.current_scene.add_child(second)
	first.global_position = pot.global_position + Vector3(0.8, 0.3, 0)
	second.global_position = pot.global_position + Vector3(2.2, 0.3, 0)
	await tree.create_timer(2.5).timeout
	assert_eq(is_instance_valid(pot), false, "rompe la vasija")
	assert_eq(is_instance_valid(second), false, "detona la otra bomba en cadena")
	setup[1].reset()
