extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"


func _quarters(tree: SceneTree) -> Array:
	var hud: Node = tree.current_scene.get_node(^"HUD")
	return hud.hearts.get_children().map(func(h: HeartIcon) -> int: return h.quarters)


func test_hearts_follow_health() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var game_state: Node = tree.root.get_node(^"GameState")
	game_state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.process_frame
	await tree.process_frame
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	assert_eq(_quarters(tree), [4, 4, 4], "3 corazones llenos")
	player.health.invulnerability_time = 0.0
	player.health.damage(1)
	assert_eq(_quarters(tree), [4, 4, 3], "un cuarto menos")
	player.health.damage(4)
	assert_eq(_quarters(tree), [4, 3, 0], "un corazón menos")
	player.health.heal(2)
	assert_eq(_quarters(tree), [4, 4, 1])
	game_state.max_health = 20
	game_state.loaded.emit()
	assert_eq(_quarters(tree), [4, 4, 4, 4, 4], "más vida máxima, más corazones")
	game_state.reset()
