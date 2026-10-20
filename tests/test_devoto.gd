extends "res://tests/test_case.gd"
## 11.115 paso 5: Devotos del Ojo. La IA del centinela (alerta con !, búsqueda y vuelta) y una estocada de lanza con
## aviso largo que se puede contraatacar.

const LEVEL := "res://levels/test.tscn"
const DEVOTO := preload("res://src/entities/devoto/devoto.tscn")


func _level() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var other := tree.get_first_node_in_group(&"enemies") as Enemy
	var devoto := DEVOTO.instantiate() as Enemy
	other.add_sibling(devoto)
	devoto.global_position = other.global_position
	for enemy in tree.get_nodes_in_group(&"enemies"):
		if enemy != devoto:
			enemy.free()
	return [tree, player, devoto]


func _wait(tree: SceneTree, frames: int, done: Callable) -> bool:
	for i in frames:
		if done.call():
			return true
		await tree.physics_frame
	return done.call()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_it_alerts_searches_and_returns() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var devoto: Enemy = setup[2]
	var home := devoto.global_position
	var mark := devoto.get_node(^"%Alert") as Label3D
	var blackboard := devoto.bt_player.blackboard
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = home + Vector3(0, 60, 0)
	for i in 30:
		await tree.physics_frame
	assert_true(not mark.visible, "sin verte, tranquilo")
	player.global_position = home + Vector3(0, 0, 7)
	assert_true(await _wait(tree, 30, func() -> bool: return mark.visible), "al verte muestra el !")
	assert_true(await _wait(tree, 90, func() -> bool: return blackboard.get_var(&"alerted", false)), "termina la alerta")
	assert_true(await _wait(tree, 30, func() -> bool: return devoto.desired_velocity.length() > 0.5), "persigue")
	var seen := player.global_position
	player.global_position = home + Vector3(0, 60, 0)
	assert_true(await _wait(tree, 300, func() -> bool: return _flat(devoto.global_position, seen) < 0.6), "va a donde te vio")
	assert_true(await _wait(tree, 600, func() -> bool: return _flat(devoto.global_position, home) < 0.6), "y vuelve a su puesto")
	tree.root.get_node(^"GameState").reset()


func test_its_long_thrust_can_be_countered() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var devoto: Enemy = setup[2]
	var state := tree.root.get_node(^"GameState")
	state.set_flag(Counter.LEARNED, true)
	var thrust := devoto.config.attack
	assert_true(thrust != null and thrust.resource_path.ends_with("devoto_thrust.tres"), "ataca con la estocada de lanza")
	assert_true(thrust.windup_time >= 0.8, "con aviso largo (%.2f s)" % thrust.windup_time)
	use_gamepad()
	await tree.physics_frame
	devoto.bt_player.active = false
	devoto.global_position = player.global_position + Vector3(0, 0, 2.0)
	devoto.face_towards(player.global_position)
	for i in 3:
		await tree.physics_frame
	var lock := InputEventAction.new()
	lock.action = player.controls.action(&"z-lock")
	lock.pressed = true
	Input.parse_input_event(lock)
	Input.action_press(lock.action)
	assert_true(await _wait(tree, 30, func() -> bool: return player.targeting.current == devoto), "fijado")
	devoto.bt_player.active = true
	assert_true(await _wait(tree, 300, func() -> bool: return devoto.strike_in() < INF), "avisa la estocada")
	assert_true(await _wait(tree, 120, func() -> bool: return player.counter.is_open()), "se abre la ventana del contraataque")
	var before := devoto.health.current
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = player.controls.action(&"attack")
		event.pressed = pressed
		Input.parse_input_event(event)
	assert_true(await _wait(tree, 10, func() -> bool: return player.movement_state.get_active_state().name == &"Countering"), "contraataca")
	assert_true(await _wait(tree, 120, func() -> bool: return devoto.health.current < before), "y le pega")
	Input.action_release(lock.action)
	TimeScale.clear()
	await tree.physics_frame
	state.reset()
