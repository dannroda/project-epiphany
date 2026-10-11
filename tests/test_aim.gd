extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test_targeting.tscn"


func _load() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy: Enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.bt_player.active = false
	for i in 10:
		await tree.physics_frame
	return [tree, tree.get_first_node_in_group(&"player")]


func _stick(x: float, y: float) -> void:
	for pair in [[JOY_AXIS_RIGHT_X, x], [JOY_AXIS_RIGHT_Y, y]]:
		var motion := InputEventJoypadMotion.new()
		motion.axis = pair[0]
		motion.axis_value = pair[1]
		Input.parse_input_event(motion)


func test_sources() -> void:
	var setup: Array = await _load()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var aim := player.aim
	player.model.rotation = Vector3.ZERO
	var facing := aim.get_direction()
	assert_eq(aim.source, Aim.Source.FACING)
	assert_true(facing.is_equal_approx(Vector3(0, 0, 1)), str(facing))

	_stick(1.0, 0.0)
	await tree.physics_frame
	aim.get_direction()
	assert_eq(aim.source, Aim.Source.FACING, "el stick derecho ya no apunta")

	player.targeting.lock_best_target()
	var target_dir := aim.get_direction()
	assert_eq(aim.source, Aim.Source.TARGET, "el objetivo fijado gana")
	assert_true(target_dir.dot(Vector3.FORWARD) > 0.9, str(target_dir))
	player.targeting.clear()
	_stick(0.0, 0.0)
	await tree.physics_frame


func test_mouse_ray_hits_ground_under_screen_point() -> void:
	var setup: Array = await _load()
	var player: PlayerCharacter = setup[1]
	var camera := player.get_viewport().get_camera_3d()
	var on_screen := camera.unproject_position(player.global_position + Vector3(2, 1, -1))
	var hit: Vector3 = player.aim.mouse_on_ground(on_screen)
	assert_true(hit.distance_to(player.global_position + Vector3(2, 1, -1)) < 0.05, str(hit))


func _move(x: float, y: float) -> void:
	for pair in [[JOY_AXIS_LEFT_X, x], [JOY_AXIS_LEFT_Y, y]]:
		var motion := InputEventJoypadMotion.new()
		motion.axis = pair[0]
		motion.axis_value = pair[1]
		Input.parse_input_event(motion)


func test_aiming_turns_model() -> void:
	var setup: Array = await _load()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	player.model.rotation = Vector3.ZERO
	player.aim.aiming = true
	player.aim.move_aims = true
	_move(1.0, 0.0)
	for i in 30:
		await tree.physics_frame
	var forward := player.model.global_basis.z
	assert_true(forward.dot(Vector3.RIGHT) > 0.9, "el modelo mira hacia donde apunta: %s" % forward)
	player.aim.aiming = false
	player.aim.move_aims = false
	_move(0.0, 0.0)


func test_mouse_stops_aiming_once_the_gamepad_is_used() -> void:
	var setup: Array = await _load()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(20, 0)
	tree.root.get_node(^"InputDevice")._input(motion)
	player.aim._input(motion)
	assert_true(player.aim.mouse_aims(), "con el mouse apunta el mouse")
	_stick(0.8, 0.0)
	await tree.process_frame
	_stick(0.0, 0.0)
	await tree.process_frame
	assert_eq(player.aim.mouse_aims(), false, "al tocar el gamepad deja de apuntar el mouse")


func test_right_stick_moves_the_camera() -> void:
	var setup: Array = await _load()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var camera := tree.get_first_node_in_group(&"room_camera") as TopDownCamera
	if camera == null:
		camera = player.get_viewport().get_camera_3d() as TopDownCamera
	player.targeting.clear()
	for i in 30:
		await tree.physics_frame
	var before := camera.focus
	_stick(0.0, -1.0)
	for i in 60:
		await tree.physics_frame
	assert_true(before.z - camera.focus.z > 2.0, "el foco se corre hacia arriba (%.1f m)" % (before.z - camera.focus.z))
	_stick(0.0, 0.0)
	for i in 90:
		await tree.physics_frame
	assert_true(absf(camera.focus.z - before.z) < 0.3, "y vuelve al soltar")
