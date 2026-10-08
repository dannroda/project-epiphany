extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"


func _load(tree: SceneTree) -> void:
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.queue_free()


func _swing_at(tree: SceneTree, player: PlayerCharacter, target: Vector3) -> void:
	var from := target + Vector3(0, 0, 1.0)
	player.global_position = from
	player.model.look_at(player.model.global_position + Vector3.BACK, Vector3.UP)
	for i in 3:
		await tree.physics_frame
	var event := InputEventAction.new()
	event.action = &"attack"
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = &"attack"
	Input.parse_input_event(release)
	await tree.create_timer(0.9).timeout


func test_sword_breaks_pot_and_it_returns_on_reload() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	await _load(tree)
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var pot: Breakable = tree.current_scene.get_node(^"Pot1")
	var always := DropTable.new()
	var heart := DropEntry.new()
	heart.heal = 4
	always.entries.assign([heart])
	pot.drops = always
	for other in [^"Pot2", ^"Pot3"]:
		tree.current_scene.get_node(other).drops = null
	var spawned: Array = []
	var watch := func(node: Node) -> void:
		if node is Pickup:
			spawned.append(node)
	tree.node_added.connect(watch)
	await _swing_at(tree, player, pot.global_position)
	tree.node_added.disconnect(watch)
	assert_eq(is_instance_valid(pot), false, "la espada rompe la vasija")
	assert_eq(spawned.size(), 1, "suelta un corazón")
	await _load(tree)
	assert_true(tree.current_scene.has_node(^"Pot1"), "vuelve al recargar la escena")
	state.reset()


func test_sword_cuts_grass() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	await _load(tree)
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var patch: Node3D = tree.current_scene.get_node(^"GrassPatch")
	assert_eq(patch.get_child_count(), 50, "campo de 50 matas")
	var first := patch.get_child(patch.columns * (patch.rows - 1) + 4) as Node3D
	await _swing_at(tree, player, first.global_position)
	assert_true(patch.get_child_count() < 50, "la espada corta pasto")
	state.reset()
