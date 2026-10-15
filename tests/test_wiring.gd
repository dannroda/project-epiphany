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


func test_block_mode_only_a_block_solves_it() -> void:
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
	assert_eq(switch.active, false, "el player no lo aprieta: solo un bloque")
	player.global_position = switch.global_position + Vector3(0, 0, 6)
	var stone: RigidBody3D = load("res://src/world/physics_box.tscn").instantiate()
	stone.freeze = true
	level.add_child(stone)
	stone.global_position = switch.global_position + Vector3.UP * 0.5
	for i in 6:
		await tree.physics_frame
	assert_eq(switch.active, false, "ni un objeto encima")
	switch.mode = FloorSwitch.Mode.WEIGHT
	for i in 6:
		await tree.physics_frame
	assert_eq(switch.active, true, "el de peso sí lo toma")
	switch.mode = FloorSwitch.Mode.BLOCK
	switch._set_active(false, false)
	switch._solved = false
	stone.free()
	block.global_position = switch.global_position
	for i in 6:
		await tree.physics_frame
	assert_eq(switch.active, true, "el bloque lo activa")
	block.global_position = switch.global_position + Vector3(4, 0, 0)
	for i in 6:
		await tree.physics_frame
	assert_eq(switch.active, true, "y queda resuelto")
	assert_true(not switch.is_physics_processing(), "resuelto, deja de mirar qué tiene encima")
	switch._set_active(false, false)
	assert_true(switch.is_physics_processing(), "si se reinicia, vuelve a mirar")
	state.reset()


func test_reveal_pauses_and_shows_only_the_first_time() -> void:
	TopDownCamera.unlock_reveals = true
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
	assert_true(tree.paused, "con el juego en pausa")
	var elapsed := 0.0
	while camera.revealing and elapsed < camera.reveal_pan_time + 0.05:
		await tree.process_frame
		elapsed += tree.root.get_process_delta_time()
	var ahead := -camera.global_basis.z
	var looked := camera.global_position + ahead * (player.global_position.y - camera.global_position.y) / ahead.y
	assert_true(Vector2(looked.x - door.global_position.x, looked.z - door.global_position.z).length() < 0.3, "se acerca a la puerta, no hacia adelante (mira %s, la puerta en %s)" % [looked.snappedf(0.1), door.global_position.snappedf(0.1)])
	while camera.revealing:
		await tree.process_frame
		elapsed += tree.root.get_process_delta_time()
	var expected := camera.reveal_pan_time * 2.0 + door.open_time
	assert_true(elapsed > expected and elapsed < expected + 0.25, "vuelve al terminar de abrirse (%.2f s; abrir e ir y volver, %.2f s)" % [elapsed, expected])
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
