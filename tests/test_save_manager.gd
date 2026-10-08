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
