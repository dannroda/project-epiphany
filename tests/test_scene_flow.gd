extends "res://tests/test_case.gd"
## SceneFlow (14.9): los cambios de escena salieron de SaveManager; la pantalla de carga aparece si el viaje tarda.


func test_save_manager_only_handles_saves() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var saves: Node = tree.root.get_node(^"SaveManager")
	for method in [&"travel_to", &"respawn", &"new_game", &"quit_to_title", &"with_fade", &"location"]:
		assert_true(not saves.has_method(method), "SaveManager ya no tiene %s" % method)
		assert_true(tree.root.get_node(^"SceneFlow").has_method(method), "SceneFlow sí")


func test_a_slow_trip_shows_the_eye_loading_in_the_corner() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var flow: Node = tree.root.get_node(^"SceneFlow")
	state.reset()
	tree.change_scene_to_file("res://levels/overworld.tscn")
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	var door: Portal = tree.current_scene.get_node(^"ChullpaDoor")
	var after: float = flow.show_loading_after
	flow.show_loading_after = 0.0
	door.travel()
	var until := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < until and not flow.loading_screen.visible:
		await tree.process_frame
	assert_true(flow.loading_screen.visible, "aparece la pantalla de carga")
	var busy := flow.get_node(^"Loading/Busy") as Control
	assert_eq(flow.get_node(^"Loading").get_children().map(func(node: Node) -> StringName: return node.name), [&"Background", &"Busy"], "solo el ojo y Cargando, sin destino ni barra")
	assert_true(busy.get_global_rect().end.x > 1100 and busy.get_global_rect().end.y > 600, "en la esquina inferior derecha (%s)" % busy.get_global_rect())
	var dots := flow.get_node(^"Loading/Busy/Text/Dots") as Label
	var seen := {}
	for i in 60:
		seen[dots.visible_characters] = true
		await tree.process_frame
	assert_true(seen.size() >= 2, "los puntos se animan (%s)" % seen.keys())
	while flow.traveling:
		await tree.process_frame
	flow.show_loading_after = after
	assert_true(not flow.loading_screen.visible, "y se va al llegar")
	assert_eq(tree.current_scene.scene_file_path, "res://levels/chullpa.tscn")
	assert_eq(flow.get_node(^"Rect").color.a, 0.0, "sin fundido")
	state.reset()


func test_a_fast_trip_skips_it() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var flow: Node = tree.root.get_node(^"SceneFlow")
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/test.tscn")
	await tree.scene_changed
	var shown := false
	flow.travel_to("res://levels/test.tscn", &"start")
	while flow.traveling:
		shown = shown or flow.loading_screen.visible
		await tree.process_frame
	assert_true(not shown, "una escena ya cargada no muestra la pantalla")


func test_loading_a_save_of_the_same_scene_reloads_it() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var saves: Node = tree.root.get_node(^"SaveManager")
	state.reset()
	tree.change_scene_to_file("res://levels/test.tscn")
	await tree.scene_changed
	state.spawn_scene = "res://levels/test.tscn"
	state.player_position = Vector3(2, 0, 2)
	assert_eq(saves.save_game(9), OK)
	var before := tree.current_scene
	state.set_flag(&"ow_test_cracked_wall", true)
	assert_eq(await saves.load_game(9), OK)
	assert_true(tree.current_scene != before, "la escena es otra instancia, no la del mundo que se tocó")
	assert_eq(state.get_flag(&"ow_test_cracked_wall"), false)
	assert_eq((tree.current_scene.get_node(^"CrackedWall") as CrackedWall).is_broken, false, "el muro vuelve a estar entero")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(9)))
	saves.current_slot = 1
	state.reset()
