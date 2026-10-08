extends "res://tests/test_case.gd"
## Prueba de 6.5: una puerta que necesita dos interruptores.

const LEVEL := "res://levels/test_rooms.tscn"


func test_door_needs_both_switches() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	var level := tree.current_scene
	level.get_node(^"Skeleton").free()
	var door: Door = level.get_node(^"NicheDoor")
	var block_switch: FloorSwitch = level.get_node(^"BlockSwitch")
	var player_switch: FloorSwitch = level.get_node(^"PlayerSwitch")
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	assert_eq(door.is_open, false)
	var camera: TopDownCamera = level.get_node(^"TopDownCamera")
	player.global_position = Vector3(-10, 0.25, -12)
	while camera.room != level.get_node(^"RoomB") or camera.transitioning:
		await tree.physics_frame
	await tree.create_timer(0.2).timeout
	player.global_position = player_switch.global_position
	for i in 6:
		await tree.physics_frame
	assert_eq(player_switch.active, true, "el player pisa uno")
	assert_eq(door.is_open, false, "pisar uno no abre")
	var block: PushBlock = level.get_node(^"Block")
	for i in 2:
		assert_true(block.try_push(Vector3.FORWARD), "el bloque avanza hacia su interruptor")
		await tree.create_timer(0.5).timeout
	assert_eq(block_switch.active, true, "el bloque queda sobre el otro")
	assert_eq(door.is_open, true, "con los dos, la puerta se abre")
	state.reset()
