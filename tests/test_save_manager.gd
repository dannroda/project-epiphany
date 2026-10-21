extends "res://tests/test_case.gd"

const SLOT := 99
const LEVEL := "res://levels/test/test.tscn"


func test_save_and_load_restore_player_and_state() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var save_manager: Node = tree.root.get_node(^"SaveManager")
	var game_state: Node = tree.root.get_node(^"GameState")
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as Node3D
	player.global_position = Vector3(3, 0, -2)
	game_state.reset()
	game_state.give(Items.get_item(&"bomb"), 4)
	assert_eq(save_manager.save_game(SLOT), OK)

	player.global_position = Vector3(-5, 0, 5)
	game_state.give(Items.get_item(&"bomb"), 4)
	assert_eq(await save_manager.load_game(SLOT), OK)

	player = tree.get_first_node_in_group(&"player") as Node3D
	assert_true(player.global_position.is_equal_approx(Vector3(3, 0, -2)), str(player.global_position))
	assert_eq(game_state.inventory.count(&"bomb"), 4)
	assert_eq(game_state.spawn_scene, LEVEL)
	for suffix in ["", ".bak"]:
		DirAccess.remove_absolute(save_manager.slot_path(SLOT) + suffix)
	game_state.reset()


func test_failed_load_keeps_the_current_slot() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var save_manager: Node = tree.root.get_node(^"SaveManager")
	var missing := 97
	for suffix in ["", ".bak"]:
		DirAccess.remove_absolute(save_manager.slot_path(missing) + suffix)
	var before: int = save_manager.current_slot
	assert_true(await save_manager.load_game(missing) != OK, "una partida que no se puede leer no carga")
	assert_eq(save_manager.current_slot, before, "y no cambia la ranura en la que se guarda")


func test_missing_scene_loads_at_the_start_instead_of_hanging() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var save_manager: Node = tree.root.get_node(^"SaveManager")
	var game_state: Node = tree.root.get_node(^"GameState")
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	game_state.reset()
	game_state.give(Items.get_item(&"bomb"), 4)
	game_state.spawn_scene = "res://levels/ya_no_existe.tscn"
	assert_eq(save_manager.save_game(SLOT, false), OK)
	var loaded := [false]
	(func() -> void:
		await save_manager.load_game(SLOT)
		loaded[0] = true).call()
	await tree.process_frame
	assert_true(tree.paused, "mientras carga, la escena vieja queda en pausa: no lo matan en el medio")
	while not loaded[0]:
		await tree.process_frame
	assert_true(not tree.paused and not MenuStack.is_open(), "y al llegar sigue el juego, sin game over")
	assert_eq(tree.current_scene.scene_file_path, SceneFlow.NEW_GAME_SCENE, "en la escena del comienzo")
	assert_eq(save_manager.loading, false, "y termina de cargar")
	assert_eq(game_state.inventory.count(&"bomb"), 4, "con lo que tenía")
	for suffix in ["", ".bak"]:
		DirAccess.remove_absolute(save_manager.slot_path(SLOT) + suffix)
	game_state.reset()


func test_a_scene_that_does_not_load_falls_back_to_the_start() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var save_manager: Node = tree.root.get_node(^"SaveManager")
	var game_state: Node = tree.root.get_node(^"GameState")
	var broken := "user://test_broken_level.tscn"
	var file := FileAccess.open(broken, FileAccess.WRITE)
	file.store_string("[gd_scene format=3]\n[node name=")
	file.close()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	game_state.reset()
	game_state.give(Items.get_item(&"bomb"), 4)
	game_state.spawn_scene = broken
	assert_eq(save_manager.save_game(SLOT, false), OK)
	assert_eq(await save_manager.load_game(SLOT), OK, "una escena que existe pero no carga no deja la pantalla vacía")
	assert_true(tree.current_scene != null and tree.current_scene.scene_file_path == SceneFlow.NEW_GAME_SCENE, "arranca en la escena del comienzo")
	assert_eq(game_state.inventory.count(&"bomb"), 4, "con lo que tenía")
	assert_true(not tree.paused and not SceneFlow.traveling, "y el juego sigue")
	DirAccess.remove_absolute(broken)
	for suffix in ["", ".bak"]:
		DirAccess.remove_absolute(save_manager.slot_path(SLOT) + suffix)
	game_state.reset()


func test_loading_again_while_loading_is_refused() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var save_manager: Node = tree.root.get_node(^"SaveManager")
	var game_state: Node = tree.root.get_node(^"GameState")
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	game_state.reset()
	game_state.spawn_scene = LEVEL
	assert_eq(save_manager.save_game(SLOT, false), OK)
	var first := [ERR_UNAVAILABLE]
	(func() -> void: first[0] = await save_manager.load_game(SLOT)).call()
	assert_eq(await save_manager.load_game(SLOT), ERR_BUSY, "una segunda carga en medio de otra no entra")
	assert_eq(await SceneFlow.quit_to_title(), ERR_BUSY, "ni volver al título")
	while first[0] == ERR_UNAVAILABLE:
		await tree.process_frame
	assert_eq(first[0], OK, "y la primera termina")
	assert_true(not SceneFlow.is_busy(), "sin quedar trabado")
	for suffix in ["", ".bak"]:
		DirAccess.remove_absolute(save_manager.slot_path(SLOT) + suffix)
	game_state.reset()


func test_a_moved_level_loads_by_its_uid() -> void:
	var game_state: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"GameState")
	game_state.reset()
	game_state.spawn_scene = LEVEL
	var cfg := ConfigFile.new()
	game_state.write_to(cfg)
	cfg.set_value("player", "spawn_scene", "res://niveles/viejo/test.tscn")
	game_state.read_from(cfg)
	assert_eq(game_state.spawn_scene, LEVEL, "el uid encuentra el nivel aunque la ruta guardada ya no exista")
	cfg.erase_section_key("player", "spawn_uid")
	cfg.set_value("player", "spawn_scene", LEVEL)
	game_state.read_from(cfg)
	assert_eq(game_state.spawn_scene, LEVEL, "un save viejo sin uid sigue usando la ruta")
	game_state.reset()
