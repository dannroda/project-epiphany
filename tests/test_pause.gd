extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"


func _key(tree: SceneTree, keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		event.keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame


func test_pause_freezes_and_resumes() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var stack: Node = tree.root.get_node(^"MenuStack")
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var enemy := tree.get_first_node_in_group(&"enemies") as Enemy
	player.global_position = enemy.global_position - Vector3(0, 0, 5)
	for i in 90:
		await tree.physics_frame
	await _key(tree, KEY_TAB)
	assert_eq(stack.is_open(), true, "Tab abre la pausa")
	assert_eq(tree.paused, true)
	var frozen := enemy.global_position
	var anim_time := enemy.anim_player.current_animation_position
	for i in 30:
		await tree.physics_frame
	assert_true(enemy.global_position.is_equal_approx(frozen), "el esqueleto no se mueve")
	assert_eq(enemy.anim_player.current_animation_position, anim_time, "la animación está congelada")
	var fired_paused := [false]
	tree.create_timer(0.1, false).timeout.connect(func() -> void: fired_paused[0] = true)
	for i in 20:
		await tree.physics_frame
	assert_eq(fired_paused[0], false, "en pausa un timer pausable no avanza")

	var menu: Control = stack.top()
	assert_eq(menu.current, 0)
	assert_true(menu.prev_key.texture != null and menu.next_key.texture != null, "íconos de pestaña")
	assert_true(menu.hints.get_child_count() > 0, "ayudas de botones")
	await _key(tree, KEY_E)
	assert_eq(menu.current, 1, "E: pestaña siguiente")
	await _key(tree, KEY_Q)
	await _key(tree, KEY_Q)
	assert_eq(menu.current, 3, "Q da la vuelta")

	await _key(tree, KEY_ESCAPE)
	assert_eq(stack.is_open(), false, "Esc cierra")
	assert_eq(tree.paused, false)
	var fired := [false]
	tree.create_timer(0.1, false).timeout.connect(func() -> void: fired[0] = true)
	for i in 30:
		await tree.physics_frame
	assert_eq(fired[0], true, "el juego sigue (un timer pausable se dispara)")


func test_no_pause_menu_while_something_else_paused_the_game() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var stack: Node = tree.root.get_node(^"MenuStack")
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	tree.paused = true
	await _key(tree, KEY_TAB)
	assert_eq(stack.is_open(), false, "durante un reveal o un fundido, Tab no abre la pausa")
	tree.paused = false
	await _key(tree, KEY_TAB)
	assert_eq(stack.is_open(), true, "después sí")
	await _key(tree, KEY_ESCAPE)


func test_dying_while_paused_waits_for_the_game_to_resume() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var stack: Node = tree.root.get_node(^"MenuStack")
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.get_node(^"MovementState/Dead").delay = 0.2
	player.health.damage(player.health.current)
	await tree.physics_frame
	tree.paused = true
	await tree.create_timer(0.6, true).timeout
	assert_true(not (stack.top() is GameOver), "con el juego pausado no aparece el game over")
	tree.paused = false
	await tree.create_timer(0.6).timeout
	assert_true(stack.top() is GameOver, "al seguir, sí")
	stack.clear()
	tree.root.get_node(^"GameState").reset()
