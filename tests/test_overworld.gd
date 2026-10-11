extends "res://tests/test_case.gd"

const SIDES: Array[Vector3i] = [Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(0, 0, -1)]
const LEVEL := "res://levels/overworld.tscn"


func _walk(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0
	Input.parse_input_event(event)


## Camina hasta que `done` se cumpla. Devuelve si llegó y si en algún momento cayó por debajo del piso.
func _walk_until(tree: SceneTree, player: PlayerCharacter, action: StringName, done: Callable) -> Array:
	_walk(action, true)
	var until := Time.get_ticks_msec() + 12000
	var fell := false
	while Time.get_ticks_msec() < until and not done.call():
		await tree.physics_frame
		fell = fell or player.global_position.y < -0.5
	_walk(action, false)
	for i in 3:
		await tree.physics_frame
	return [done.call(), fell]


func test_walk_every_zone_without_falling_or_sticking() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	state.set_flag(&"ow_shrine_cracked_wall", true)
	state.set_flag(&"ow_shrine_shortcut", true)
	state.set_flag(&"ow_grotto_cracked_wall", true)
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	await tree.create_timer(0.5).timeout
	assert_eq(AreaZone._current.display_name, "PLACE_FIRST_CLEARING", "arranca en el claro")
	var at := func(axis: int, sign_: float, value: float) -> Callable:
		return func() -> bool: return (player.global_position[axis] - value) * sign_ >= 0.0
	var route := [
		[&"move_forward", at.call(2, -1.0, 0.0), "PLACE_MEADOW"],
		[&"move_left", at.call(0, -1.0, -24.0), "PLACE_CAVE"],
		[&"move_forward", at.call(2, -1.0, -16.0), "PLACE_SANCTUARY"],
		[&"move_right", at.call(0, 1.0, 0.0), "PLACE_TEMPLE_ENTRANCE"],
		[&"move_backward", at.call(2, 1.0, 0.0), "PLACE_MEADOW"],
		[&"move_right", at.call(0, 1.0, 24.0), "PLACE_GROVE"],
		[&"move_forward", at.call(2, -1.0, -14.0), "PLACE_EYE_CRAG"],
		[&"move_backward", at.call(2, 1.0, 0.0), "PLACE_GROVE"],
		[&"move_left", at.call(0, -1.0, 0.0), "PLACE_MEADOW"],
		[&"move_backward", at.call(2, 1.0, 16.0), "PLACE_FIRST_CLEARING"],
		[&"move_left", at.call(0, -1.0, -24.0), "PLACE_HIDDEN_GROTTO"],
	]
	for leg in route:
		var result: Array = await _walk_until(tree, player, leg[0], leg[1])
		assert_true(result[0], "llega a %s sin trabarse (quedó en %s)" % [leg[2], player.global_position.snappedf(0.1)])
		assert_eq(result[1], false, "no cae camino a %s" % leg[2])
		assert_eq(AreaZone._current.display_name if AreaZone._current else "", leg[2], "el HUD nombra la zona")
	assert_eq(tree.get_first_node_in_group(&"hud").area_label.text, tr("PLACE_HIDDEN_GROTTO"), "el cartel muestra la última zona")
	state.reset()


func test_abyss_has_no_floor_but_a_pit() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.physics_frame
	var space := (tree.current_scene as Node3D).get_world_3d().direct_space_state
	for z in [-20.0, -18.0]:
		var down := PhysicsRayQueryParameters3D.create(Vector3(24, 2, z), Vector3(24, -0.8, z), 1)
		assert_true(space.intersect_ray(down).is_empty(), "el abismo no tiene piso (z %.0f)" % z)
	var high := PhysicsRayQueryParameters3D.create(Vector3(24, 1.0, -14), Vector3(24, 1.0, -21), 1)
	assert_true(space.intersect_ray(high).is_empty(), "a la altura de una flecha pasa por arriba")
	assert_true(tree.current_scene.get_node(^"RiscoPit") is Pit, "abajo hay un Pit")
	tree.root.get_node(^"GameState").reset()


func test_pit_walls_face_the_ground() -> void:
	var root := (load("res://levels/temple.tscn") as PackedScene).instantiate()
	var grid := root.get_node(^"GridMap") as GridMap
	var lib := grid.mesh_library
	var cells := 0
	for cell in grid.get_used_cells():
		if not lib.get_item_name(grid.get_cell_item(cell)).begins_with("Hueco"):
			continue
		cells += 1
		var basis := grid.get_cell_item_basis(cell)
		var faces := lib.get_item_mesh(grid.get_cell_item(cell)).get_faces()
		for k in 4:
			var neighbor := grid.get_cell_item(cell + SIDES[k])
			var open := neighbor != -1 and lib.get_item_name(neighbor).begins_with("Hueco")
			var wall := false
			for t in range(0, faces.size(), 3):
				var p := basis * ((faces[t] + faces[t + 1] + faces[t + 2]) / 3.0)
				var along := Vector3(SIDES[k]) * p.dot(Vector3(SIDES[k]))
				wall = wall or (p.y > -0.05 and along.length() > 0.8 and Vector2(p.x - along.x, p.z - along.z).length() < 0.5 and p.dot(Vector3(SIDES[k])) > 0)
			assert_eq(wall, not open, "Hueco %s lado %d" % [cell, k])
	assert_true(cells > 0, "el templo tiene huecos")
	root.free()


## En el overworld las paredes del abismo son parte del terreno (12.15): desde adentro, a 1 m de hondo, hay roca hacia cada lado que da a tierra.
func test_abyss_walls_face_the_ground() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.physics_frame
	await tree.physics_frame
	var grid := tree.current_scene.get_node(^"GridMap") as GridMap
	var lib := grid.mesh_library
	var space := (tree.current_scene as Node3D).get_world_3d().direct_space_state
	var abyss := func(item: int) -> bool: return item != -1 and lib.get_item_name(item).begins_with("Abismo")
	var sides := 0
	for cell in grid.get_used_cells():
		if not abyss.call(grid.get_cell_item(cell)):
			continue
		for side in SIDES:
			if abyss.call(grid.get_cell_item(cell + side)):
				continue
			sides += 1
			var from := grid.to_global(grid.map_to_local(cell)) * Vector3(1, 0, 1) + Vector3.DOWN
			var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3(side) * 1.6, 1)
			assert_true(not space.intersect_ray(ray).is_empty(), "abismo %s: pared hacia %s" % [cell, side])
	assert_true(sides > 0, "el overworld tiene abismo")
	tree.root.get_node(^"GameState").reset()


func test_fence_ends_have_a_post() -> void:
	var root := (load(LEVEL) as PackedScene).instantiate()
	var grid := root.get_node(^"GridMap") as GridMap
	var lib := grid.mesh_library
	var sides: Array[Vector3i] = [Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(0, 0, -1)]
	var fence := func(item: int) -> bool: return item != -1 and (lib.get_item_name(item) == "Cerco" or lib.get_item_name(item).begins_with("Pirca"))
	var ends := 0
	for cell in grid.get_used_cells():
		if not fence.call(grid.get_cell_item(cell)):
			continue
		var neighbors := 0
		for side in sides:
			neighbors += 1 if fence.call(grid.get_cell_item(cell + side)) else 0
		if neighbors < 2:
			ends += 1
			assert_true(lib.get_item_name(grid.get_cell_item(cell)) in ["Pirca final", "Pirca poste"], "pirca %s termina con poste" % cell)
	assert_true(ends > 0, "el overworld tiene puntas de pirca")
	root.free()
