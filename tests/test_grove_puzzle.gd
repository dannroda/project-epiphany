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


func _push_until(tree: SceneTree, action: StringName, done: Callable) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	event.strength = 1.0
	Input.parse_input_event(event)
	var until := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < until and not done.call():
		await tree.physics_frame
	event = event.duplicate()
	event.pressed = false
	event.strength = 0.0
	Input.parse_input_event(event)
	for i in 10:
		await tree.physics_frame


func test_stepping_on_the_plates_does_not_bring_the_chest() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	var level := await _enter()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var a := level.get_node(^"GroveSwitchA") as FloorSwitch
	var b := level.get_node(^"GroveSwitchB") as FloorSwitch
	var chest := level.get_node(^"GroveChest") as Chest
	await _stand(tree, player, a.global_position)
	assert_true(not a.active, "el player no la baja: solo un bloque")
	await _stand(tree, player, b.global_position)
	assert_true(not b.active, "ni la otra")
	await _stand(tree, player, b.global_position + Vector3(0, 0, 3))
	assert_true(not chest.visible, "pisar las dos placas no trae el cofre")
	assert_true(not state.get_flag(&"ow_grove_switch_a") and not state.get_flag(&"ow_grove_switch_b"), "ni queda resuelto")
	state.reset()


func test_pushing_the_blocks_onto_the_plates_brings_the_chest_and_they_stay() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	var level := await _enter()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var a := level.get_node(^"GroveSwitchA") as FloorSwitch
	var b := level.get_node(^"GroveSwitchB") as FloorSwitch
	var block_a := level.get_node(^"GroveBlockA") as PushBlock
	var block_b := level.get_node(^"GroveBigPot") as PushBlock
	for push: Array in [
		[block_a, Vector3(0, 0, -2), &"move_backward", a.global_position],
		[block_b, Vector3(-2, 0, 0), &"move_right", Vector3(-31, 0, 2)],
		[block_b, Vector3(0, 0, -2), &"move_backward", b.global_position],
	]:
		var block := push[0] as PushBlock
		var target := push[3] as Vector3
		await _stand(tree, player, block.global_position + push[1])
		await _push_until(tree, push[2], func() -> bool: return not block.moving and block.global_position.distance_to(target) < 0.05)
		assert_true(block.global_position.distance_to(target) < 0.05, "%s llega empujando a %s (quedó en %s)" % [block.name, target, block.global_position])
	for i in 6:
		await tree.physics_frame
	assert_true((level.get_node(^"GroveChest") as Chest).visible, "con un bloque en cada placa aparece el cofre")
	level = await _enter()
	assert_true((level.get_node(^"GroveChest") as Chest).visible, "y sigue ahí al volver")
	for pair in [[^"GroveBlockA", ^"GroveSwitchA"], [^"GroveBigPot", ^"GroveSwitchB"]]:
		var block := level.get_node(pair[0] as NodePath) as Node3D
		var plate := level.get_node(pair[1] as NodePath) as Node3D
		assert_true(block.global_position.distance_to(plate.global_position) < 0.5, "%s vuelve sobre su placa (%s)" % [pair[0], block.global_position])
	state.reset()
