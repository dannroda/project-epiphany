extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test_rooms.tscn"


func _setup() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	var level := tree.current_scene
	level.get_node(^"Skeleton").free()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.global_position = Vector3(-6, 0.25, -13.6)
	for i in 30:
		await tree.physics_frame
	return [tree, state, player, level]


func _hold(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func test_push_onto_switch_and_reset_when_leaving() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var level: Node = setup[3]
	var block: PushBlock = level.get_node(^"Block")
	var switch: FloorSwitch = level.get_node(^"BlockSwitch")
	var start := block.global_position
	assert_eq(level.get_node(^"TopDownCamera").room, level.get_node(^"RoomB"))
	var saw_pushing := [false]
	_hold(&"move_forward", true)
	var until := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < until and not switch.active:
		if player.movement_state.get_active_state().name == &"Pushing":
			saw_pushing[0] = true
		await tree.physics_frame
	_hold(&"move_forward", false)
	assert_true(saw_pushing[0], "caminar contra el bloque pasa a Pushing")
	await tree.create_timer(0.5).timeout
	assert_true(block.global_position.distance_to(start + Vector3.FORWARD * 4.0) < 0.05, "avanzó dos celdas, justas en la grilla")
	assert_eq(switch.active, true, "empujarlo sobre el interruptor lo activa")

	player.global_position = Vector3(0, 0.25, 2)
	for i in 10:
		await tree.physics_frame
	assert_eq(level.get_node(^"TopDownCamera").room, level.get_node(^"RoomA"))
	assert_true(block.global_position.distance_to(start) < 0.01, "al salir de la sala vuelve a su lugar")
	setup[1].reset()


func test_block_does_not_go_into_walls() -> void:
	var setup: Array = await _setup()
	var level: Node = setup[3]
	var block: PushBlock = level.get_node(^"WallBlock")
	var start := block.global_position
	assert_eq(block.try_push(Vector3.LEFT), false, "contra la pared no se mueve")
	assert_eq(block.global_position, start)
	assert_eq(level.get_node(^"Block").try_push(Vector3.FORWARD), true, "en el medio de la sala sí")
	setup[1].reset()


func test_solved_flag_keeps_it_in_place() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var level: Node = setup[3]
	var block: PushBlock = level.get_node(^"Block")
	block.solved_flag = &"d1_test_block_solved"
	assert_true(block.try_push(Vector3.FORWARD))
	await tree.create_timer(0.6).timeout
	state.set_flag(&"d1_test_block_solved", true)
	var moved := block.global_position
	block.reset_position()
	assert_eq(block.global_position, moved, "con el puzzle resuelto no vuelve")
	state.reset()
