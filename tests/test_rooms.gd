extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test/test_rooms.tscn"


func _setup() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 4:
		await tree.physics_frame
	var level := tree.current_scene
	level.get_node(^"Skeleton").free()
	return [tree, state, tree.get_first_node_in_group(&"player"), level.get_node(^"TopDownCamera"), level.get_node(^"RoomA"), level.get_node(^"RoomB"), level.get_node(^"HUD")]


## La vista sobre el suelo queda dentro de la sala; si la sala es más chica que la vista, centrada en ella.
func _assert_framed(camera: TopDownCamera, room: Room, label: String) -> void:
	var view := camera.view_extents()
	var bounds := room.bounds()
	var seen := Rect2(Vector2(camera.focus.x, camera.focus.z) + view.position, view.size)
	for axis in 2:
		var fits := view.size[axis] <= bounds.size[axis] + 0.01
		if fits:
			assert_true(seen.position[axis] >= bounds.position[axis] - 0.05 and seen.end[axis] <= bounds.end[axis] + 0.05, "%s: la vista no sale de la sala (eje %d)" % [label, axis])
		elif axis == 0:
			assert_true(absf(camera.focus.x - bounds.get_center().x) < 0.05, "%s: sala más angosta que la vista, centrada" % label)
		else:
			var floor_y := camera.target_node.global_position.y
			var eye := camera.focus + camera.offset
			var north := Vector3(bounds.get_center().x, floor_y + camera.wall_height, bounds.position.y)
			var south := Vector3(bounds.get_center().x, floor_y, bounds.end.y)
			assert_true(absf(camera._screen_height(north, eye) + camera._screen_height(south, eye)) < 0.01, "%s: sala más baja que la vista, centrada en pantalla" % label)


func _walk(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0
	Input.parse_input_event(event)


func _walk_until(tree: SceneTree, action: StringName, done: Callable, seconds := 9.0) -> void:
	_walk(action, true)
	var until := Time.get_ticks_msec() + seconds * 1000.0
	while Time.get_ticks_msec() < until and not done.call():
		await tree.physics_frame
	_walk(action, false)


func test_crossing_slides_camera_and_keeps_it_inside() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	var camera: TopDownCamera = setup[3]
	var room_a: Room = setup[4]
	var room_b: Room = setup[5]
	var hud: Node = setup[6]
	assert_eq(camera.room, room_a, "arranca en la sala A")
	_assert_framed(camera, room_a, "sala A")
	assert_eq(hud.area_label.text, "Vestíbulo", "nombre al entrar por primera vez")

	var saw_transition := [false]
	await _walk_until(tree, &"move_forward", func() -> bool:
		if player.movement_state.get_active_state().name == &"Transition":
			saw_transition[0] = true
		return camera.room == room_b and not camera.transitioning)
	assert_true(saw_transition[0], "al cruzar, el player camina solo (Transition)")
	assert_eq(camera.room, room_b, "la cámara pasa a la sala B")
	assert_eq(hud.area_label.text, "Galería")
	var dungeon: DungeonState = state.current_dungeon_state()
	assert_true(dungeon.was_visited(0) and dungeon.was_visited(1), "las dos salas quedan visitadas")

	await _walk_until(tree, &"move_forward", func() -> bool: return player.global_position.z < -38.0)
	for i in 30:
		await tree.physics_frame
	assert_true(camera.view_extents().size.x <= room_b.bounds().size.x and camera.view_extents().size.y <= room_b.bounds().size.y, "la sala B es más grande que la vista: la cámara la recorre")
	_assert_framed(camera, room_b, "sala B, al fondo")
	await _walk_until(tree, &"move_right", func() -> bool: return player.global_position.x > 19.0)
	for i in 30:
		await tree.physics_frame
	_assert_framed(camera, room_b, "sala B, en la esquina")

	hud.area_label.text = ""
	player.global_position = Vector3(0, 0.25, -7)
	await _walk_until(tree, &"move_backward", func() -> bool: return camera.room == room_a and not camera.transitioning)
	assert_eq(hud.area_label.text, "", "volver a una sala visitada no repite el nombre")
	state.reset()


func test_dying_in_dungeon_respawns_at_room_entrance() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	var camera: TopDownCamera = setup[3]
	var room_b: Room = setup[5]
	await _walk_until(tree, &"move_forward", func() -> bool: return camera.room == room_b and not camera.transitioning)
	var entry: Vector3 = SceneFlow.session.room_entry
	assert_true(room_b.bounds().has_point(Vector2(entry.x, entry.z)), "la entrada queda dentro de la sala B")
	player.global_position = Vector3(15, 0.25, -30)
	player.health.invulnerability_time = 0.0
	player.health.damage(999)
	var stack: Node = tree.root.get_node(^"MenuStack")
	for i in 400:
		if stack.top() is GameOver:
			break
		await tree.process_frame
	assert_true(stack.top() is GameOver, "game over")
	(stack.top() as GameOver)._continue.pressed.emit()
	await tree.process_frame
	var flow: Node = tree.root.get_node(^"SceneFlow")
	var until := Time.get_ticks_msec() + 6000
	while flow.traveling and Time.get_ticks_msec() < until:
		await tree.process_frame
	await tree.create_timer(0.3).timeout
	player = tree.get_first_node_in_group(&"player")
	assert_true(player.global_position.distance_to(entry) < 0.5, "reaparece en la entrada de la sala")
	camera = tree.current_scene.get_node(^"TopDownCamera")
	assert_eq(camera.room, tree.current_scene.get_node(^"RoomB"), "con la cámara en esa sala")
	state.reset()


func test_only_rooms_with_a_player_run() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var level := tree.current_scene
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var rooms: Array[Room] = [level.get_node(^"RoomA"), level.get_node(^"RoomB")]
	var skeleton := level.get_node(^"Skeleton") as Node3D
	var home: Room = rooms[0] if rooms[0].contains(skeleton.global_position) else rooms[1]
	var away: Room = rooms[1] if home == rooms[0] else rooms[0]
	var spikes: Node3D = load("res://src/world/spike_trap.tscn").instantiate()
	level.add_child(spikes)
	var center := home.bounds().get_center()
	spikes.global_position = Vector3(center.x, home.floor_y(), center.y)
	for pair in [[away, false], [home, true], [away, false]]:
		var room: Room = pair[0]
		var spot := room.bounds().get_center()
		player.global_position = Vector3(spot.x, room.floor_y() + 0.1, spot.y)
		for i in 4:
			await tree.physics_frame
		var running: bool = pair[1]
		var label := "con el player en %s" % room.name
		if running:
			assert_eq(skeleton.process_mode, Node.PROCESS_MODE_DISABLED, "apenas entra, lo de la sala sigue quieto")
			for i in int(room.wake_delay * Engine.physics_ticks_per_second) + 2:
				await tree.physics_frame
		assert_eq(skeleton.process_mode != Node.PROCESS_MODE_DISABLED, running, "el enemigo de %s corre solo %s" % [home.name, label])
		assert_eq(spikes.process_mode != Node.PROCESS_MODE_DISABLED, running, "los pinchos también")
	assert_true(home.occupied == false and away.occupied, "la sala sabe si tiene un player")
	assert_true(not home.is_processing(), "en el juego no corre el _process del contorno del editor")
	state.reset()


func test_enemies_keep_running_while_the_player_stands_in_a_doorway() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var level := tree.current_scene
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var rooms: Array[Room] = [level.get_node(^"RoomA"), level.get_node(^"RoomB")]
	var skeleton := level.get_node(^"Skeleton") as Node3D
	var home: Room = rooms[0] if rooms[0].contains(skeleton.global_position) else rooms[1]
	var spot := home.bounds().get_center()
	player.global_position = Vector3(spot.x, home.floor_y() + 0.1, spot.y)
	for i in int(home.wake_delay * Engine.physics_ticks_per_second) + 30:
		await tree.physics_frame
	assert_true(skeleton.process_mode != Node.PROCESS_MODE_DISABLED, "con el player adentro, el enemigo corre")
	var box := home.bounds()
	var doorway := Vector3.INF
	for edge: Vector2 in [Vector2(box.position.x - 0.5, spot.y), Vector2(box.end.x + 0.5, spot.y), Vector2(spot.x, box.position.y - 0.5), Vector2(spot.x, box.end.y + 0.5)]:
		var point := Vector3(edge.x, home.floor_y() + 0.1, edge.y)
		if tree.get_nodes_in_group(Room.GROUP).all(func(room: Room) -> bool: return not room.contains(point)):
			doorway = point
	assert_true(doorway != Vector3.INF, "hay un borde de la sala que no es de otra sala")
	player.global_position = doorway
	for i in 10:
		await tree.physics_frame
	assert_true(skeleton.process_mode != Node.PROCESS_MODE_DISABLED, "parado en la puerta, fuera de las dos salas, el enemigo sigue corriendo")
	state.reset()


## La sala que pidió despertar a las demás se libera antes de que corra el pedido: no queda trabado para las siguientes.
func test_a_room_freed_before_its_wake_does_not_block_the_next_ones() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var room := Room.new()
	tree.root.add_child(room)
	room._request_wake()
	room.free()
	await tree.process_frame
	await tree.process_frame
	assert_true(not Room._waking, "el pedido corrió aunque la sala ya no está")
