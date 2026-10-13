extends "res://tests/test_case.gd"

const LEVEL := "res://levels/overworld.tscn"
const CAVE := "res://levels/bomb_cave.tscn"


func _press(tree: SceneTree, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)
	for i in 3:
		await tree.physics_frame


func _face(player: PlayerCharacter, direction: Vector3) -> void:
	player.model.look_at(player.model.global_position - direction, Vector3.UP)


func test_get_the_bombs_and_break_the_practice_wall() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var saves: Node = tree.root.get_node(^"SaveManager")
	var stack: Node = tree.root.get_node(^"MenuStack")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	assert_eq(await saves.load_scenario("start"), OK)
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var shrine_wall := tree.current_scene.get_node(^"ShrineCrackedWall") as CrackedWall
	assert_eq(state.inventory.has(&"bomb_bag"), false, "el escenario start no trae bombas")
	assert_eq(shrine_wall.is_broken, false, "el paso al santuario está cerrado")
	tree.change_scene_to_file(CAVE)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	await tree.physics_frame
	var level := tree.current_scene
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	var practice := level.get_node(^"CavePracticeWall") as CrackedWall

	var chest := level.get_node(^"CaveChest") as Chest
	player.global_position = chest.global_position + Vector3(0, 0, 1.2)
	_face(player, Vector3.FORWARD)
	await tree.physics_frame
	chest.interactable.interact(player)
	await tree.create_timer(1.0).timeout
	while stack.is_open():
		stack.pop()
	await tree.create_timer(1.2).timeout
	assert_eq(state.inventory.has(&"bomb_bag"), true, "el cofre da la bolsa de bombas")
	assert_true(state.inventory.count(&"bomb") > 0, "con bombas adentro")
	assert_eq(state.get_flag(&"ow_cave_bombs_chest"), true)
	assert_eq(state.item_buttons[0], &"bomb_bag", "queda en un botón")

	player.global_position = practice.global_position + Vector3(0, 0, -1.3)
	_face(player, Vector3.BACK)
	await tree.physics_frame
	await _press(tree, &"item_1")
	await tree.create_timer(1.0).timeout
	assert_eq(tree.get_nodes_in_group(&"bombs").size(), 1, "pone una bomba frente al muro")
	player.global_position = practice.global_position + Vector3(0, 0, -6)
	await tree.create_timer(2.6).timeout
	assert_eq(practice.is_broken, true, "la bomba rompe el muro de práctica")
	assert_eq(state.get_flag(&"ow_cave_practice_wall"), true)
	assert_true(level.get_node_or_null(^"CaveHeartPot") != null, "detrás espera la vasija de corazones")
	state.reset()
