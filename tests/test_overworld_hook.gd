extends "res://tests/test_case.gd"
## Los postes del gancho del overworld: desde abajo se apunta al poste del borde y el gancho sube al player.

const LEVEL := "res://levels/overworld.tscn"


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


func _state(player: PlayerCharacter) -> StringName:
	return player.movement_state.get_active_state().name


func _place(tree: SceneTree, player: PlayerCharacter, at: Vector3, facing: Vector3) -> void:
	var still := 0
	for i in 300:
		player.global_position = at
		player.velocity = Vector3.ZERO
		player.model.look_at(player.model.global_position - facing, Vector3.UP)
		await tree.physics_frame
		still = still + 1 if _state(player) == &"Idle" else 0
		if still >= 10:
			break
	tree.call_group(TopDownCamera.GROUP, &"snap_to_target")
	await tree.process_frame


func _fire(tree: SceneTree, player: PlayerCharacter) -> void:
	var press := InputEventAction.new()
	press.action = &"item_1"
	press.pressed = true
	Input.parse_input_event(press)
	await tree.physics_frame
	var release := InputEventAction.new()
	release.action = &"item_1"
	Input.parse_input_event(release)
	for i in 180:
		await tree.physics_frame
		if i > 3 and _state(player) != &"Hooking":
			break
	for i in 10:
		await tree.physics_frame


func _climb(post_name: NodePath, from: Vector3) -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var post := tree.current_scene.get_node(post_name) as HookPost
	await _place(tree, player, from, Vector3.RIGHT)
	player.targeting.lock_best_target()
	assert_true(player.targeting.current == post, "desde abajo se fija %s" % post.name)
	await _fire(tree, player)
	assert_true(absf(player.global_position.y - post.global_position.y) < 0.3 and player.global_position.distance_to(post.global_position) < 1.5, "%s sube al player al borde (%s)" % [post.name, player.global_position.snappedf(0.1)])
	assert_eq(_state(player), &"Idle", "y queda parado arriba")
	player.targeting.clear()
	setup[2].reset()


func test_the_hookshot_climbs_from_the_corridor_to_the_risco_heart_piece() -> void:
	await _climb(^"RiscoPost", Vector3(65.8, 0.1, -35))


func test_the_hookshot_climbs_from_the_strip_to_the_cumbre() -> void:
	await _climb(^"CumbrePost", Vector3(3.8, 0.1, -36))
