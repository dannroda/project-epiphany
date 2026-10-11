extends "res://tests/test_case.gd"
## Co-op (13.3): la cámara encuadra a todos, no los deja separarse más que la pantalla y el que cruza a otra sala
## se lleva a los demás.

const PLAYER := preload("res://player/player.tscn")
const PAD_1 := 0
const PAD_2 := 1


func _rooms() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/test_rooms.tscn")
	await tree.scene_changed
	for i in 4:
		await tree.physics_frame
	var level := tree.current_scene
	level.get_node(^"Skeleton").free()
	var first: PlayerCharacter = tree.root.get_node(^"Players").lead()
	var second := PLAYER.instantiate() as PlayerCharacter
	level.add_child(second)
	return [tree, level, level.get_node(^"TopDownCamera"), first, second]


## Si los lleva a otra sala, la cámara los junta al cruzar: se espera y se los vuelve a poner.
func _place(tree: SceneTree, camera: TopDownCamera, spots: Dictionary) -> void:
	for attempt in 2:
		for player: PlayerCharacter in spots:
			player.global_position = spots[player]
		for i in 3:
			await tree.physics_frame
		if not camera.transitioning:
			break
		await tree.create_timer(camera.transition_time + 0.2).timeout
	camera.snap_to_target()


func _seen(camera: TopDownCamera, player: PlayerCharacter) -> bool:
	var view := camera.view_extents()
	var seen := Rect2(Vector2(camera.focus.x, camera.focus.z) + view.position, view.size)
	return seen.has_point(Vector2(player.global_position.x, player.global_position.z))


func test_frames_both_and_holds_them_within_the_screen() -> void:
	var setup: Array = await _rooms()
	var tree: SceneTree = setup[0]
	var camera: TopDownCamera = setup[2]
	var first: PlayerCharacter = setup[3]
	var second: PlayerCharacter = setup[4]
	await _place(tree, camera, {first: Vector3(-2, 0, -20), second: Vector3(2, 0, -20)})
	for i in 30:
		await tree.physics_frame
	assert_eq(camera.room, setup[1].get_node(^"RoomB"), "los dos en la sala grande")
	assert_true(absf(camera.focus.x) < 0.3, "mira al medio de los dos (%.2f)" % camera.focus.x)

	for i in 300:
		second.global_position.x += 0.08
		await tree.physics_frame
	var fits := camera.view_extents().size.x - camera.leash_margin * 2.0
	var span := second.global_position.x - first.global_position.x
	assert_true(span <= fits + 0.1, "un borde invisible lo frena (%.1f de %.1f m)" % [span, fits])
	assert_true(span > fits - 1.0, "pero llega hasta el borde")
	for i in 30:
		await tree.physics_frame
	assert_true(_seen(camera, first) and _seen(camera, second), "los dos quedan en cuadro")

	second.global_position = Vector3(first.global_position.x, first.global_position.y, -38)
	await tree.physics_frame
	assert_true(second.global_position.distance_to(first.global_position) > 15.0, "un salto en la misma sala (reaparecer) no se deshace")
	second.free()


func test_crossing_into_another_room_brings_the_other_along() -> void:
	var setup: Array = await _rooms()
	var tree: SceneTree = setup[0]
	var level: Node = setup[1]
	var camera: TopDownCamera = setup[2]
	var first: PlayerCharacter = setup[3]
	var second: PlayerCharacter = setup[4]
	await _place(tree, camera, {first: Vector3(-2, 0, 2), second: Vector3(2, 0, 2)})
	await tree.physics_frame
	assert_eq(camera.room, level.get_node(^"RoomA"))

	second.global_position = Vector3(0, 0, -5.4)
	await tree.physics_frame
	await tree.physics_frame
	assert_true(camera.transitioning, "el segundo cruza y la cámara se desliza")
	await tree.create_timer(camera.transition_time + 0.3).timeout
	var room_b: Room = level.get_node(^"RoomB")
	assert_eq(camera.room, room_b, "la cámara pasa a la sala nueva")
	assert_true(room_b.contains(first.global_position) and room_b.contains(second.global_position), "con los dos adentro")
	assert_true(first.global_position.distance_to(second.global_position) < 2.5, "el primero llega al lado del que cruzó")
	for i in 30:
		await tree.physics_frame
	assert_eq(camera.room, room_b, "y no vuelve atrás")
	second.free()


func test_both_travel_between_the_overworld_and_the_temple() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var save: Node = tree.root.get_node(^"SaveManager")
	var players: Node = tree.root.get_node(^"Players")
	state.reset()
	tree.change_scene_to_file("res://levels/overworld.tscn")
	await tree.scene_changed
	for i in 5:
		await tree.physics_frame
	players.lead_pad = PAD_1
	players.join(PAD_2)
	for trip: Array in [["res://levels/temple.tscn", &"start"], ["res://levels/overworld.tscn", &"templo"]]:
		await save.travel_to(trip[0], trip[1])
		for i in 10:
			await tree.physics_frame
		var camera := tree.get_first_node_in_group(&"room_camera") as TopDownCamera
		assert_eq(players.all.size(), 2, "%s: llegan los dos" % trip[0].get_file())
		assert_true(players.all[0].global_position.distance_to(players.all[1].global_position) < 3.0, "%s: juntos en la entrada" % trip[0].get_file())
		assert_true(_seen(camera, players.all[0]) and _seen(camera, players.all[1]), "%s: los dos en cuadro" % trip[0].get_file())
	for slot in players.guests.keys():
		players.leave(slot)
	players.lead_pad = -1
	await tree.process_frame
	state.reset()
