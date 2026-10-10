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


func test_block_mode_player_holds_and_block_solves() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	var level := tree.current_scene
	level.get_node(^"Skeleton").free()
	var switch: FloorSwitch = level.get_node(^"BlockSwitch")
	switch.mode = FloorSwitch.Mode.BLOCK
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var block: PushBlock = level.get_node(^"Block")
	player.global_position = switch.global_position
	for i in 6:
		await tree.physics_frame
	assert_eq(switch.active, true, "el player lo activa")
	player.global_position = switch.global_position + Vector3(0, 0, 3)
	for i in 6:
		await tree.physics_frame
	assert_eq(switch.active, false, "al bajarse se apaga")
	block.global_position = switch.global_position
	for i in 6:
		await tree.physics_frame
	assert_eq(switch.active, true, "el bloque lo activa")
	block.global_position = switch.global_position + Vector3(4, 0, 0)
	for i in 6:
		await tree.physics_frame
	assert_eq(switch.active, true, "y queda resuelto")
	state.reset()


func test_reveal_pauses_and_shows_only_the_first_time() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	var level := tree.current_scene
	level.get_node(^"Skeleton").free()
	var camera: TopDownCamera = level.get_node(^"TopDownCamera")
	var door: Door = level.get_node(^"NicheDoor")
	door.reveal_on_open = true
	door.stays_open = false
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var block: PushBlock = level.get_node(^"Block")
	var block_switch: FloorSwitch = level.get_node(^"BlockSwitch")
	var player_switch: FloorSwitch = level.get_node(^"PlayerSwitch")
	player.global_position = Vector3(-10, 0.25, -12)
	while camera.room != level.get_node(^"RoomB") or camera.transitioning:
		await tree.physics_frame
	await tree.create_timer(0.2).timeout
	block.global_position = block_switch.global_position
	player.global_position = player_switch.global_position
	var until := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < until and not camera.revealing:
		await tree.physics_frame
	assert_true(camera.revealing, "la cámara muestra la puerta")
	var view := camera.view_extents()
	var focus := camera.reveal_focus(door)
	var shown := Rect2(Vector2(focus.x, focus.z) + view.position * camera.reveal_zoom, view.size * camera.reveal_zoom)
	assert_true(camera.room.bounds().grow(0.01).encloses(shown), "el acercamiento no sale de la sala: %s en %s" % [shown, camera.room.bounds()])
	assert_true(tree.paused, "con el juego en pausa")
	while camera.revealing:
		await tree.process_frame
	assert_eq(door.is_open, true, "la abrió")
	assert_eq(tree.paused, false, "y sigue el juego")
	player.global_position = player_switch.global_position + Vector3(0, 0, 3)
	for i in 6:
		await tree.physics_frame
	assert_eq(door.is_open, false, "se cierra al bajarse")
	player.global_position = player_switch.global_position
	for i in 6:
		await tree.physics_frame
	assert_eq(camera.revealing, false, "la segunda vez no la muestra")
	assert_eq(door.is_open, true)
	state.reset()
