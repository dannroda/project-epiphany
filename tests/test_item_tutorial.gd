extends "res://tests/test_case.gd"
## 11.105: mini tutoriales. Después del item get, una tarjeta (qué hace, botón, probalo) que sale una sola vez; el chip
## del HUD muestra la tarea hasta hacerla y, a los 30 s sin usar el ítem, marca el objetivo más cercano. Los controles
## básicos son solo el chip: moverse desde el arranque y atacar, fijar y rodar con el primer enemigo cerca.

const LEVEL := "res://levels/test.tscn"
const CATALOG := preload("res://data/tutorials/catalog.tres")
const BASICS: Array[StringName] = [&"move", &"attack", &"lock", &"dodge"]


func _level(basics_done := true, keep_enemies := false) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state := tree.root.get_node(^"GameState")
	state.reset()
	if basics_done:
		for id in BASICS:
			state.set_flag(StringName("tut_%s_done" % id), true)
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	if not keep_enemies:
		for enemy in tree.get_nodes_in_group(&"enemies"):
			enemy.free()
	for i in 300:
		if player.movement_state.get_active_state().name == &"Idle":
			break
		await tree.physics_frame
	var tutor := tree.current_scene.get_node(^"HUD/%Tutor") as Tutor
	return [tree, player, state, tutor]


func _until(tree: SceneTree, done: Callable, frames := 240) -> bool:
	for i in frames:
		if done.call():
			return true
		await tree.physics_frame
	return done.call()


func _done(tree: SceneTree) -> void:
	var stack: Node = tree.root.get_node(^"MenuStack")
	while stack.top():
		stack.pop()
	await tree.physics_frame
	tree.root.get_node(^"GameState").reset()


func test_the_card_follows_the_item_get_once() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var state: Node = setup[2]
	var stack: Node = tree.root.get_node(^"MenuStack")
	var bow := Items.get_item(&"bow")
	state.give(bow)
	player.play_item_get(bow)
	assert_true(await _until(tree, func() -> bool: return stack.top() != null), "caja de item get")
	stack.pop()
	assert_true(await _until(tree, func() -> bool: return stack.top() != null and stack.top().get(&"tutorial") != null, 10), "después, la tarjeta")
	var card: UiScreen = stack.top()
	assert_eq(card.get(&"tutorial"), CATALOG.for_item(&"bow"), "la del arco")
	assert_eq((card.get_node(^"%Title") as Label).text, tr(bow.display_name), "con el nombre del ítem")
	assert_eq(player.movement_state.get_active_state().name, &"ItemGet", "con el ítem en alto mientras se lee")
	assert_true(not (tree.current_scene.get_node(^"HUD/%Tutor") as Tutor).chip.visible, "el chip espera a que se cierre")
	stack.pop()
	await tree.process_frame
	assert_true(state.get_flag(&"tut_bow_shown") == true, "queda vista")
	assert_true(await _until(tree, func() -> bool: return player.movement_state.get_active_state().name == &"Idle"), "y baja las manos")
	player.play_item_get(bow)
	assert_true(await _until(tree, func() -> bool: return stack.top() != null), "otra caja")
	stack.pop()
	for i in 5:
		await tree.physics_frame
	assert_true(stack.top() == null, "la tarjeta no vuelve")
	await _done(tree)


func test_the_chip_shows_the_task_until_the_eye_wakes() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var state: Node = setup[2]
	var tutor: Tutor = setup[3]
	assert_true(not tutor.chip.visible, "sin tarjeta vista no hay chip")
	state.give(Items.get_item(&"bow"))
	state.assign_button(1, &"bow")
	state.set_flag(&"tut_bow_shown", true)
	await tree.process_frame
	assert_true(tutor.chip.visible, "chip con la tarea")
	assert_eq(tutor.chip_task.text, tr("TUT_BOW_TASK"), "dispará al ojo")
	assert_true(tutor.chip_keys.visible, "con el botón del arco")
	var eye := tree.current_scene.get_node(^"EyeSwitch") as EyeSwitch
	eye._show(true)
	eye.activated.emit()
	await tree.process_frame
	assert_true(state.get_flag(&"tut_bow_done") == true, "hecha")
	assert_true(not tutor.chip.visible, "y el chip se va")
	await _done(tree)


func test_a_feather_jump_completes_its_task() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var state: Node = setup[2]
	var tutor: Tutor = setup[3]
	state.give(Items.get_item(&"feather"))
	state.assign_button(0, &"feather")
	state.set_flag(&"tut_feather_shown", true)
	await tree.process_frame
	assert_eq(tutor.current, CATALOG.for_item(&"feather"), "tarea de la pluma")
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = &"item_1"
		event.pressed = pressed
		Input.parse_input_event(event)
	assert_true(await _until(tree, func() -> bool: return state.get_flag(&"tut_feather_done") == true, 30), "saltar la completa")
	assert_true(not tutor.chip.visible, "sin chip")
	await _done(tree)


func test_after_idle_seconds_the_nearest_eye_is_marked() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var state: Node = setup[2]
	var tutor: Tutor = setup[3]
	var eye := tree.current_scene.get_node(^"EyeSwitch") as EyeSwitch
	eye.global_position = player.global_position + Vector3(2, 0, -2)
	state.give(Items.get_item(&"bow"))
	state.set_flag(&"tut_bow_shown", true)
	await tree.process_frame
	await tree.process_frame
	assert_true(not tutor.marker.visible, "al principio no marca nada")
	tutor.idle = tutor.hint_delay
	await tree.process_frame
	assert_true(tutor.marker.visible, "a los 30 s marca el ojo")
	player.item_used.emit(Items.get_item(&"bow"))
	await tree.process_frame
	assert_true(not tutor.marker.visible and tutor.idle < 1.0, "usar el arco vuelve a contar")
	tutor.idle = tutor.hint_delay
	eye._show(true)
	await tree.process_frame
	assert_true(not tutor.marker.visible, "resuelto, no lo marca")
	await _done(tree)


func _press(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


func test_the_basic_controls_are_taught_in_context() -> void:
	var setup: Array = await _level(false, true)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var state: Node = setup[2]
	var tutor: Tutor = setup[3]
	var enemies := tree.get_nodes_in_group(&"enemies").filter(func(node: Node) -> bool: return node is Enemy)
	for other in tree.get_nodes_in_group(&"enemies"):
		if not other is Enemy:
			other.free()
	for enemy: Enemy in enemies:
		enemy.bt_player.active = false
		enemy.global_position = player.global_position + Vector3(30, 0, 30)
	await tree.process_frame
	assert_eq(tutor.current, CATALOG.tutorials[0], "al arrancar, moverse")
	assert_true(tutor.chip.visible and not tutor.chip_icon.visible, "el chip sin ícono de ítem")
	_press(&"move_left")
	await tree.process_frame
	assert_true(state.get_flag(&"tut_move_done") == true, "caminar lo completa")
	assert_true(not tutor.chip.visible, "sin enemigos cerca no hay más avisos")
	(enemies[0] as Node3D).global_position = player.global_position + Vector3(4, 0, 0)
	await tree.process_frame
	for id in [&"attack", &"lock", &"dodge"]:
		assert_eq(tutor.current.id, id, "con un enemigo cerca, de a uno: %s" % id)
		_press((tutor.current as TutorialData).done_actions[0])
		await tree.process_frame
	assert_true(not tutor.chip.visible, "y listo")
	await _done(tree)
