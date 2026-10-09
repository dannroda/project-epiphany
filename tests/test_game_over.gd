extends "res://tests/test_case.gd"

const TEST_DIR := "user://test_saves/"


func _die(tree: SceneTree) -> GameOver:
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	player.health.damage(100)
	var stack: Node = tree.root.get_node(^"MenuStack")
	for i in 400:
		if stack.top() is GameOver:
			break
		await tree.process_frame
	return stack.top() as GameOver


func test_continue_in_the_overworld_and_in_a_room() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var saves: Node = tree.root.get_node(^"SaveManager")
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	await saves.load_scenario("start")
	var screen := await _die(tree)
	assert_true(screen != null, "morir abre el game over")
	var caption := screen.find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.text.begins_with("Desde"))
	assert_eq(caption[0].text, "Desde el último punto de control", "en el overworld")
	tree.root.get_node(^"MenuStack").pop()

	await saves.load_scenario("dungeon_no_bow")
	await tree.create_timer(0.5).timeout
	screen = await _die(tree)
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	Input.parse_input_event(event)
	await tree.process_frame
	assert_eq(tree.root.get_node(^"MenuStack").top(), screen, "atrás no lo cierra: hay que elegir")
	screen._continue.pressed.emit()
	await tree.scene_changed
	await tree.create_timer(1.0).timeout
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	assert_eq(player.is_dead, false, "continuar: de pie")
	assert_true(player.global_position.distance_to(Vector3(24, 0, 50)) < 2.5, "en la entrada de la sala donde cayó (%s)" % player.global_position)
	state.reset()


func test_save_and_quit_keeps_the_checkpoint() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var saves: Node = tree.root.get_node(^"SaveManager")
	var state: Node = tree.root.get_node(^"GameState")
	saves.save_dir = TEST_DIR
	saves.delete_slot(0)
	state.reset()
	await saves.new_game(0)
	var player := tree.get_first_node_in_group(&"player") as Node3D
	player.global_position = Vector3(0, 0, 0)
	var screen := await _die(tree)
	screen.find_children("*", "MenuItem", true, false).filter(func(item: MenuItem) -> bool: return item.label == "Guardar y salir")[0].pressed.emit()
	await tree.scene_changed
	assert_eq(tree.current_scene.scene_file_path, "res://src/ui/title/title_screen.tscn", "vuelve al título")
	assert_eq(tree.paused, false)
	state.reset()
	await saves.load_game(0)
	player = tree.get_first_node_in_group(&"player") as Node3D
	assert_true(player.global_position.distance_to(Vector3(0, 0, 16)) < 0.6, "carga en el punto de control, no donde cayó")
	saves.delete_slot(0)
	saves.save_dir = "user://saves/"
	state.reset()
