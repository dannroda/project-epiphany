extends "res://tests/test_case.gd"
## SceneFlow (14.9): los cambios de escena salieron de SaveManager; la pantalla de carga aparece si el viaje tarda.


func test_save_manager_only_handles_saves() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var saves: Node = tree.root.get_node(^"SaveManager")
	for method in [&"travel_to", &"respawn", &"new_game", &"quit_to_title", &"with_fade", &"location"]:
		assert_true(not saves.has_method(method), "SaveManager ya no tiene %s" % method)
		assert_true(tree.root.get_node(^"SceneFlow").has_method(method), "SceneFlow sí")


func test_a_slow_trip_shows_the_loading_screen_with_the_destination() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var flow: Node = tree.root.get_node(^"SceneFlow")
	state.reset()
	tree.change_scene_to_file("res://levels/overworld.tscn")
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	var door: Portal = tree.current_scene.get_node(^"ChullpaDoor")
	assert_eq(door.destination, "PLACE_CHULLPA", "la puerta dice adónde lleva")
	var after: float = flow.show_loading_after
	flow.show_loading_after = 0.0
	door.travel()
	var until := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < until and not flow.loading_screen.visible:
		await tree.process_frame
	assert_true(flow.loading_screen.visible, "aparece la pantalla de carga")
	assert_eq(flow.get_node(^"%Name").text, "PLACE_CHULLPA", "con el destino")
	assert_eq(flow.get_node(^"%Kind").text, "LOADING_DUNGEON")
	assert_true(flow.get_node(^"%Header").visible)
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
