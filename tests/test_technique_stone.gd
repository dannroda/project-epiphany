extends "res://tests/test_case.gd"
## 11.34 paso 6: piedras de técnica y muñeco de práctica. Leer la piedra enseña la técnica y muestra el cartel; el
## muñeco se fija, avisa golpes de mentira para el contraataque y aguanta lo que le peguen.

const LEVEL := "res://levels/test.tscn"
const STONE := preload("res://src/world/technique_stone.tscn")
const DUMMY := preload("res://src/world/practice_dummy.tscn")
const COUNTER := preload("res://data/techniques/counter.tres")


func _level() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state := tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	use_gamepad()
	for i in 300:
		if player.movement_state.get_active_state().name == &"Idle":
			break
		await tree.physics_frame
	return [tree, player, state]


func _until(tree: SceneTree, done: Callable, frames := 240) -> bool:
	for i in frames:
		if done.call():
			return true
		await tree.physics_frame
	return done.call()


func test_reading_the_stone_teaches_the_technique() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var state: Node = setup[2]
	var stone := STONE.instantiate() as TechniqueStone
	stone.technique = COUNTER
	tree.current_scene.add_child(stone)
	stone.global_position = player.global_position + Vector3(0, 0, 2)
	await tree.process_frame
	assert_eq(stone.glow.current_animation, &"idle", "brilla mientras no se aprendió")
	stone._read(player)
	await tree.process_frame
	assert_true(state.get_flag(&"ow_tech_counter") == true, "enseña el contraataque")
	var stack: Node = tree.root.get_node(^"MenuStack")
	var screen: Node = stack.top()
	assert_true(screen != null and screen.get(&"technique") == COUNTER, "con el cartel de técnica nueva")
	assert_eq(screen.text_box.cue, "counter", "y su texto")
	assert_true(not stone.glow.is_playing() or stone.glow.current_animation != &"idle", "ya no brilla")
	stack.pop()
	await tree.process_frame
	stone._read(player)
	await tree.process_frame
	assert_true(stack.top() != null and stack.top().get(&"technique") == COUNTER, "releerla lo vuelve a mostrar")
	stack.pop()
	state.reset()


func test_the_dummy_can_be_countered() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var state: Node = setup[2]
	state.set_flag(&"ow_tech_counter", true)
	var dummy := DUMMY.instantiate() as PracticeDummy
	tree.current_scene.add_child(dummy)
	dummy.global_position = player.global_position + Vector3(0, 0, 2.2)
	dummy.look_at(dummy.global_position + Vector3(0, 0, 1), Vector3.UP)
	for i in 3:
		await tree.physics_frame
	var lock := InputEventAction.new()
	lock.action = &"z-lock"
	lock.pressed = true
	Input.parse_input_event(lock)
	Input.action_press(&"z-lock")
	assert_true(await _until(tree, func() -> bool: return player.targeting.current == dummy, 30), "el muñeco se fija")
	assert_true(await _until(tree, func() -> bool: return player.counter.is_open(), 300), "avisa un golpe y abre la ventana")
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = &"attack"
		event.pressed = pressed
		Input.parse_input_event(event)
	assert_true(await _until(tree, func() -> bool: return dummy.hits > 0, 90), "el contraataque le pega")
	Input.action_release(&"z-lock")
	TimeScale.clear()
	await tree.physics_frame
	state.reset()


func test_the_dummy_takes_the_sword_beam() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var state: Node = setup[2]
	state.set_flag(&"ow_tech_beam", true)
	var dummy := DUMMY.instantiate() as PracticeDummy
	dummy.period = 1000.0
	tree.current_scene.add_child(dummy)
	dummy.global_position = player.global_position + Vector3(4, 0, 0)
	player.model.look_at(player.model.global_position - Vector3(1, 0, 0), Vector3.UP)
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = &"attack"
		event.pressed = pressed
		Input.parse_input_event(event)
	assert_true(await _until(tree, func() -> bool: return dummy.hits > 0, 60), "el rayo le llega")
	state.reset()
