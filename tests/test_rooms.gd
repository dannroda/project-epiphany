extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test_rooms.tscn"


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
	var entry: Vector3 = state.room_entry
	assert_true(room_b.bounds().has_point(Vector2(entry.x, entry.z)), "la entrada queda dentro de la sala B")
	player.global_position = Vector3(15, 0.25, -30)
	player.health.invulnerability_time = 0.0
	player.health.damage(999)
	await tree.create_timer(4.5).timeout
	player = tree.get_first_node_in_group(&"player")
	assert_true(player.global_position.distance_to(entry) < 0.5, "reaparece en la entrada de la sala")
	camera = tree.current_scene.get_node(^"TopDownCamera")
	assert_eq(camera.room, tree.current_scene.get_node(^"RoomB"), "con la cámara en esa sala")
	state.reset()
