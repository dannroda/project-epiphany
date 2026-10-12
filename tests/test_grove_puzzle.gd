extends "res://tests/test_case.gd"

const LEVEL := "res://levels/overworld.tscn"


func _enter() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	for i in 2:
		await tree.physics_frame
	return tree.current_scene


func _stand(tree: SceneTree, player: PlayerCharacter, at: Vector3) -> void:
	player.global_position = at + Vector3.UP * 0.1
	for i in 6:
		await tree.physics_frame


func test_stepping_on_the_plates_does_not_open_the_gate() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	var level := await _enter()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var a := level.get_node(^"GroveSwitchA") as FloorSwitch
	var b := level.get_node(^"GroveSwitchB") as FloorSwitch
	var gate := level.get_node(^"GroveGate") as Gate
	await _stand(tree, player, a.global_position)
	assert_true(not a.active, "el player no la baja: solo un bloque")
	await _stand(tree, player, b.global_position)
	assert_true(not b.active, "ni la otra")
	await _stand(tree, player, b.global_position + Vector3(0, 0, 3))
	assert_true(not gate.is_open, "pisar las dos placas no abre la reja")
	assert_true(not state.get_flag(&"ow_grove_switch_a") and not state.get_flag(&"ow_grove_switch_b"), "ni queda resuelto")
	state.reset()


func test_blocks_on_the_plates_open_the_gate_and_stay_there() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	var level := await _enter()
	var a := level.get_node(^"GroveSwitchA") as FloorSwitch
	var b := level.get_node(^"GroveSwitchB") as FloorSwitch
	for pair in [[^"GroveBlockA", a], [^"GroveBlockB", b]]:
		var block := level.get_node(pair[0] as NodePath) as PushBlock
		block.global_position = (pair[1] as FloorSwitch).global_position
	for i in 6:
		await tree.physics_frame
	var gate := level.get_node(^"GroveGate") as Gate
	assert_true(gate.is_open, "con un bloque en cada placa se abre")
	level = await _enter()
	assert_true((level.get_node(^"GroveGate") as Gate).is_open, "y sigue abierta al volver")
	for pair in [[^"GroveBlockA", ^"GroveSwitchA"], [^"GroveBlockB", ^"GroveSwitchB"]]:
		var block := level.get_node(pair[0] as NodePath) as Node3D
		var plate := level.get_node(pair[1] as NodePath) as Node3D
		assert_true(block.global_position.distance_to(plate.global_position) < 0.5, "%s vuelve sobre su placa (%s)" % [pair[0], block.global_position])
	state.reset()
