extends "res://tests/test_case.gd"

const SLOT := 1


func _start(tree: SceneTree) -> Cutscene:
	var saves: Node = tree.root.get_node(^"SaveManager")
	saves.save_dir = saves_dir
	await saves.new_game(SLOT, true)
	await tree.process_frame
	await tree.process_frame
	return tree.current_scene.find_children("*", "Cutscene", true, false).front()


func _cleanup(tree: SceneTree) -> void:
	var saves: Node = tree.root.get_node(^"SaveManager")
	saves.delete_slot(0)
	saves.delete_slot(SLOT)
	tree.root.get_node(^"GameState").reset()


func _player(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group(&"player")


func test_new_game_plays_the_intro_over_the_overworld() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var intro := await _start(tree)
	assert_true(intro != null, "la intro arranca con la partida nueva")
	assert_true(intro.playing, "está corriendo")
	assert_eq(tree.root.get_viewport().get_camera_3d(), intro.camera, "manda la cámara de la intro")
	assert_eq(_player(tree).controls.captured, true, "el player no se mueve")
	assert_eq(tree.get_first_node_in_group(&"hud").visible, false, "sin HUD")
	assert_eq(GameState.get_flag(&"ow_intro_seen"), true, "queda vista")
	assert_true(intro.skip_hint.visible, "se ve cómo saltearla")
	intro.player.seek(intro.player.current_animation_length - 0.05, true)
	await intro.finished
	await tree.process_frame
	assert_true(not is_instance_valid(intro), "se va al terminar")
	var room_camera := tree.get_first_node_in_group(&"room_camera")
	assert_eq(tree.root.get_viewport().get_camera_3d(), room_camera, "vuelve la cámara de juego")
	assert_eq(_player(tree).controls.captured, false, "el player vuelve a moverse")
	assert_eq(tree.get_first_node_in_group(&"hud").visible, true, "vuelve el HUD")
	_cleanup(tree)


func test_shots_frame_the_meadow_the_temple_and_the_player() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var intro := await _start(tree)
	var level := tree.current_scene
	var door := (level.get_node(^"TempleDoor") as Node3D).global_position
	var start := (level.get_node(^"Spawn_start") as Node3D).global_position
	var pradera := (level.get_node(^"Zone_pradera") as AreaZone).bounds().get_center()
	var shows := func(at: float, point: Vector3) -> bool:
		intro.player.seek(at, true)
		return intro.camera.is_position_in_frustum(point)
	assert_true(shows.call(3.0, Vector3(pradera.x, 0, pradera.y)) or shows.call(5.0, Vector3(pradera.x, 0, pradera.y)), "el primero pasa por la Pradera")
	assert_true(shows.call(13.5, door), "el segundo llega a la puerta del templo")
	assert_true(shows.call(17.0, door), "el tercero, la puerta que tiembla")
	assert_true(shows.call(23.0, start), "el cuarto, el claro con el player")
	intro.player.seek(intro.player.current_animation_length - 0.05, true)
	await intro.finished
	_cleanup(tree)


func test_holding_accept_skips_it() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var intro := await _start(tree)
	Input.action_press(&"ui_accept")
	await tree.create_timer(intro.skip_hold * 0.5).timeout
	assert_true(intro.skip_ring.progress > 0.2, "el anillo se llena mientras se mantiene")
	await intro.finished
	Input.action_release(&"ui_accept")
	await tree.process_frame
	assert_true(not is_instance_valid(intro), "se salteó")
	assert_eq(_player(tree).controls.captured, false, "el player vuelve a moverse")
	assert_eq(tree.root.get_viewport().get_camera_3d(), tree.get_first_node_in_group(&"room_camera"))
	_cleanup(tree)


func test_tapping_accept_does_not_skip_it() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var intro := await _start(tree)
	Input.action_press(&"ui_accept")
	await tree.create_timer(intro.skip_hold * 0.3).timeout
	Input.action_release(&"ui_accept")
	await tree.create_timer(intro.skip_hold).timeout
	assert_true(is_instance_valid(intro) and intro.playing, "un toque no la saltea")
	assert_eq(intro.skip_ring.progress, 0.0, "el anillo se vacía al soltar")
	intro.skip()
	await intro.finished
	_cleanup(tree)


func test_loading_or_continuing_never_replays_it() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var saves: Node = tree.root.get_node(^"SaveManager")
	var intro := await _start(tree)
	intro.skip()
	await intro.finished
	assert_eq(await saves.load_game(SLOT), OK)
	await tree.process_frame
	assert_eq(tree.current_scene.find_children("*", "Cutscene", true, false).size(), 0, "cargar no la repite")
	assert_eq(GameState.get_flag(&"ow_intro_seen"), true)
	assert_eq(await saves.new_game(SLOT), OK)
	await tree.process_frame
	assert_eq(tree.current_scene.find_children("*", "Cutscene", true, false).size(), 0, "sin with_intro no hay intro (tests y escenarios)")
	_cleanup(tree)
