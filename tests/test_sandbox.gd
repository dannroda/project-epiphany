extends "res://tests/test_case.gd"
## Prueba de 5.8: desde el escenario full_inventory se resuelven los cuatro puzzles del sandbox.


func _action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _stick(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _face(player: PlayerCharacter, direction: Vector3) -> void:
	player.model.look_at(player.model.global_position - direction, Vector3.UP)


func _wait_for(tree: SceneTree, seconds: float, done: Callable) -> void:
	var until := Engine.get_physics_frames() + int(seconds * Engine.physics_ticks_per_second)
	while Engine.get_physics_frames() < until and not done.call():
		await tree.physics_frame


func _guard(player: PlayerCharacter, on: bool) -> void:
	hold_block(player, on)


func test_solve_all_four_from_scenario() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var saves: Node = tree.root.get_node(^"SaveManager")
	state.reset()
	assert_eq(await saves.load_scenario("full_inventory"), OK)
	for i in 3:
		await tree.physics_frame
	var level: Node = tree.current_scene
	assert_eq(level.scene_file_path, "res://levels/sandbox_items.tscn", "el escenario entra al sandbox")
	assert_eq(level.solved(), 0)
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	player.health.make_invulnerable(999.0)
	assert_eq(state.equipment[ItemData.Category.SHIELD], &"shield_mirror")

	# Bombas: colocar una contra el muro agrietado.
	state.assign_button(1, &"bomb_bag")
	player.global_position = level.get_node(^"CrackedWall").global_position + Vector3(0, 0, 2.2)
	_face(player, Vector3.FORWARD)
	await tree.physics_frame
	_action(&"item_2", true)
	await tree.physics_frame
	_action(&"item_2", false)
	await _wait_for(tree, 4.0, func() -> bool: return level.cracked_wall.is_broken)
	assert_true(level.cracked_wall.is_broken, "bombas: el muro se rompe")

	# Arco: el ojo está dentro de un corral; se le tira desde afuera.
	state.assign_button(0, &"bow")
	var eye: Node3D = level.get_node(^"EyeSwitch")
	player.global_position = eye.global_position + Vector3(-6, 0, 0)
	_face(player, Vector3.RIGHT)
	await tree.physics_frame
	_action(&"item_1", true)
	await tree.create_timer(0.5).timeout
	_action(&"item_1", false)
	await _wait_for(tree, 2.0, func() -> bool: return level.gate_bow.is_open)
	assert_true(level.gate_bow.is_open, "arco: la flecha activa el ojo y abre la reja")

	# Luz: pararse en el haz, cubrirse mirando a la fuente y apuntar al cristal.
	player.global_position = Vector3(-9, 0.25, 10)
	_face(player, Vector3(-1, 0, -1).normalized())
	_guard(player, true)
	await _wait_for(tree, 2.0, func() -> bool: return level.gate_light.is_open)
	assert_true(level.gate_light.is_open, "luz: el escudo espejo lleva el haz al cristal")

	# Orbe: cubrirse frente a la torreta y devolverle sus orbes.
	var turret: Turret = level.get_node(^"Turret")
	player.global_position = turret.global_position + Vector3(-5, 0, 0)
	_face(player, Vector3.RIGHT)
	await _wait_for(tree, 16.0, func() -> bool: return level.gate_orb.is_open)
	_guard(player, false)
	assert_true(level.gate_orb.is_open, "orbe: reflejar sus orbes destruye la torreta")
	assert_eq(level.solved(), 4, "los cuatro puzzles resueltos")
	state.reset()
