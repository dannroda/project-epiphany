extends "res://tests/test_case.gd"
## El gancho (11.30): sale cuatro baldosas; en un poste o un cofre se clava y lleva al player por encima de un hueco;
## contra una pared rebota; trae vasijas y la vasija grande de a una celda; le arranca la coraza al acorazado.

const LEVEL := "res://levels/test.tscn"
const FAR := Vector3(200, 0, 0)
const POST := preload("res://src/world/hook_post.tscn")
const POT := preload("res://src/world/pot.tscn")
const BIG_POT := preload("res://src/world/big_pot.tscn")
const CHEST := preload("res://src/world/chest.tscn")
const ARMORED_SKELETON := preload("res://src/entities/armored_skeleton.tscn")


func _level() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state := tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	for i in 300:
		if _state(player) == &"Idle":
			break
		await tree.physics_frame
	state.give(Items.get_item(&"hookshot"))
	state.assign_button(0, &"hookshot")
	return [tree, player, state]


func _box(tree: SceneTree, center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	tree.current_scene.add_child(body)
	body.global_position = center
	return body


func _add(tree: SceneTree, scene: PackedScene, at: Vector3) -> Node3D:
	var node := scene.instantiate() as Node3D
	tree.current_scene.add_child(node)
	node.global_position = at
	return node


func _state(player: PlayerCharacter) -> StringName:
	return player.movement_state.get_active_state().name


func _place(tree: SceneTree, player: PlayerCharacter, at: Vector3, facing: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.model.look_at(player.model.global_position - facing, Vector3.UP)
	for i in 10:
		await tree.physics_frame
	tree.call_group(TopDownCamera.GROUP, &"snap_to_target")
	await tree.process_frame


## Dispara y espera a que el player vuelva a Idle; devuelve el estado de cada frame.
func _fire(tree: SceneTree, player: PlayerCharacter) -> Array:
	var press := InputEventAction.new()
	press.action = &"item_1"
	press.pressed = true
	Input.parse_input_event(press)
	await tree.physics_frame
	var release := InputEventAction.new()
	release.action = &"item_1"
	Input.parse_input_event(release)
	var states := []
	for i in 180:
		await tree.physics_frame
		states.append(_state(player))
		if i > 3 and _state(player) != &"Hooking":
			break
	return states


func test_into_the_air_it_goes_out_and_comes_back() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_box(tree, FAR + Vector3(0, -0.5, 0), Vector3(30, 1, 10))
	await _place(tree, player, FAR, Vector3.RIGHT)
	var states := await _fire(tree, player)
	assert_true(&"Hooking" in states, "dispara el gancho")
	assert_eq(_state(player), &"Idle", "y vuelve")
	assert_true(player.global_position.distance_to(FAR) < 0.3, "sin moverse (%s)" % player.global_position)
	assert_true(tree.current_scene.find_children("*", "Hook", true, false).is_empty(), "la punta desaparece")
	setup[2].reset()


func test_a_post_pulls_the_player_across_a_gap() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_box(tree, FAR + Vector3(-4, -0.5, 0), Vector3(6, 1, 6))
	_box(tree, FAR + Vector3(8, -0.5, 0), Vector3(6, 1, 6))
	var post := _add(tree, POST, FAR + Vector3(7, 0, 0))
	await _place(tree, player, FAR + Vector3(-1, 0, 0), Vector3.RIGHT)
	var states := await _fire(tree, player)
	for i in 20:
		await tree.physics_frame
	assert_true(&"Hooking" in states)
	assert_true(player.global_position.x > FAR.x + 5.0 and player.global_position.y > -0.3, "cruza los 6 m de hueco hasta el poste (%s)" % player.global_position.snappedf(0.1))
	assert_true(player.global_position.distance_to(post.global_position) < 1.6, "y queda al lado del poste")
	setup[2].reset()


func test_a_post_out_of_reach_does_not_pull() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_box(tree, FAR + Vector3(0, -0.5, 0), Vector3(30, 1, 10))
	_add(tree, POST, FAR + Vector3(9.5, 0, 0))
	await _place(tree, player, FAR, Vector3.RIGHT)
	await _fire(tree, player)
	assert_true(player.global_position.distance_to(FAR) < 0.3, "a más de cuatro baldosas no llega (%s)" % player.global_position)
	setup[2].reset()


func test_a_chest_is_an_anchor_and_a_wall_is_not() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_box(tree, FAR + Vector3(0, -0.5, 0), Vector3(30, 1, 20))
	_add(tree, CHEST, FAR + Vector3(6, 0, 0))
	_box(tree, FAR + Vector3(0, 1, -5), Vector3(4, 2, 1))
	await _place(tree, player, FAR, Vector3.FORWARD)
	await _fire(tree, player)
	assert_true(player.global_position.distance_to(FAR) < 0.3, "contra la pared rebota y vuelve sin llevarlo")
	await _place(tree, player, FAR, Vector3.RIGHT)
	await _fire(tree, player)
	for i in 10:
		await tree.physics_frame
	assert_true(player.global_position.x > FAR.x + 3.5, "en el cofre se clava y lo lleva (%s)" % player.global_position.snappedf(0.1))
	setup[2].reset()


func test_it_brings_a_pot_and_drags_the_big_pot() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_box(tree, FAR + Vector3(0, -0.5, 0), Vector3(30, 1, 20))
	var pot := _add(tree, POT, FAR + Vector3(5, 0, 0)) as Breakable
	await _place(tree, player, FAR, Vector3.RIGHT)
	await _fire(tree, player)
	assert_true(not is_instance_valid(pot) or pot.broken, "la vasija llega y se rompe a los pies")
	var big := _add(tree, BIG_POT, FAR + Vector3(1, 0, -7)) as BigPot
	await _place(tree, player, FAR + Vector3(1, 0, 0), Vector3.FORWARD)
	await _fire(tree, player)
	for i in 30:
		await tree.physics_frame
	assert_true(big.global_position.z > FAR.z - 3.5, "la vasija grande viene de a una celda hasta quedar al lado (%s)" % big.global_position)
	assert_true(absf(fposmod(big.global_position.z - FAR.z + 7.0, 2.0)) < 0.05, "sin salirse de las celdas")
	setup[2].reset()


func test_it_tears_the_armor_off_without_hurting() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_box(tree, FAR + Vector3(0, -0.5, 0), Vector3(30, 1, 20))
	var skeleton := _add(tree, ARMORED_SKELETON, FAR + Vector3(5, 0.25, 0)) as Enemy
	skeleton.bt_player.active = false
	await _place(tree, player, FAR, Vector3.RIGHT)
	var health := skeleton.health.current
	assert_true(skeleton.is_armored())
	await _fire(tree, player)
	assert_true(not skeleton.is_armored(), "el gancho le arranca la coraza")
	assert_eq(skeleton.health.current, health, "sin dañarlo")
	setup[2].reset()


func test_the_sandbox_gap_is_crossed_with_the_hookshot() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state := tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file("res://levels/sandbox_items.tscn")
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	for i in 300:
		if _state(player) == &"Idle":
			break
		await tree.physics_frame
	state.give(Items.get_item(&"hookshot"))
	state.assign_button(0, &"hookshot")
	var post := tree.current_scene.get_node(^"HookPostIsland") as Node3D
	await _place(tree, player, Vector3(post.global_position.x, 0.25, 16.5), Vector3.BACK)
	await _fire(tree, player)
	for i in 20:
		await tree.physics_frame
	assert_true(player.global_position.z > 22.0 and player.global_position.y > 0.0, "cruza el hueco del banco de pruebas (%s)" % player.global_position.snappedf(0.1))
	await _place(tree, player, Vector3(5, 0.25, 23.6), Vector3.FORWARD)
	await _fire(tree, player)
	for i in 20:
		await tree.physics_frame
	assert_true(player.global_position.z < 18.0 and player.global_position.y > 0.0, "y vuelve con el otro poste (%s)" % player.global_position.snappedf(0.1))
	state.reset()


func _cliff(tree: SceneTree) -> void:
	_box(tree, FAR + Vector3(-5, -0.5, 0), Vector3(16, 1, 10))
	_box(tree, FAR + Vector3(8, 2.1, 0), Vector3(10, 6.2, 10))


func test_a_post_up_a_ledge_is_targeted_and_lifts_the_player() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_cliff(tree)
	var post := _add(tree, POST, FAR + Vector3(3.4, 5.2, 0)) as HookPost
	await _place(tree, player, FAR, Vector3.RIGHT)
	player.targeting.lock_best_target()
	assert_true(player.targeting.current == post, "con el gancho en un botón, el poste del borde se fija")
	var states := await _fire(tree, player)
	for i in 10:
		await tree.physics_frame
	assert_true(&"Hooking" in states)
	assert_true(absf(player.global_position.y - 5.2) < 0.3 and player.global_position.distance_to(post.global_position) < 1.5, "sube 5.2 m al piso del poste (%s)" % player.global_position.snappedf(0.1))
	assert_eq(_state(player), &"Idle", "y queda parado arriba")
	player.targeting.clear()
	setup[2].reset()


func test_a_post_below_brings_the_player_down() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_cliff(tree)
	var post := _add(tree, POST, FAR) as HookPost
	await _place(tree, player, FAR + Vector3(3.3, 5.2, 0), Vector3.LEFT)
	player.targeting.lock_best_target()
	assert_true(player.targeting.current == post, "el poste de abajo también se fija")
	await _fire(tree, player)
	for i in 10:
		await tree.physics_frame
	assert_true(absf(player.global_position.y) < 0.3 and player.global_position.distance_to(post.global_position) < 1.5, "baja al pie del poste (%s)" % player.global_position.snappedf(0.1))
	player.targeting.clear()
	setup[2].reset()


func test_posts_are_targets_only_with_the_hookshot_and_in_reach() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var state: Node = setup[2]
	_cliff(tree)
	var post := _add(tree, POST, FAR + Vector3(3.4, 5.2, 0)) as HookPost
	var far_post := _add(tree, POST, FAR + Vector3(9.5, 5.2, 0)) as HookPost
	state.buttons_of(0).fill(&"")
	await _place(tree, player, FAR, Vector3.RIGHT)
	assert_true(not post in player.targeting.possible_targets, "sin el gancho en un botón el poste no se fija")
	state.assign_button(0, &"hookshot")
	await tree.physics_frame
	await tree.physics_frame
	assert_true(post in player.targeting.possible_targets, "con el gancho, sí")
	assert_true(not far_post in player.targeting.possible_targets, "pero no uno fuera del alcance del gancho")
	state.reset()
