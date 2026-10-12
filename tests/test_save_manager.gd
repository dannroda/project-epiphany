extends "res://tests/test_case.gd"

const SLOT := 99
const LEVEL := "res://levels/test.tscn"


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
	assert_eq(await save_manager.load_game(SLOT), OK, "carga igual")
	assert_eq(tree.current_scene.scene_file_path, save_manager.NEW_GAME_SCENE, "en la escena del comienzo")
	assert_eq(save_manager.loading, false, "y termina de cargar")
	assert_eq(game_state.inventory.count(&"bomb"), 4, "con lo que tenía")
	for suffix in ["", ".bak"]:
		DirAccess.remove_absolute(save_manager.slot_path(SLOT) + suffix)
	game_state.reset()
