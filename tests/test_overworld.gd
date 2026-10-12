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
		[&"move_forward", at.call(2, -1.0, -16.0), "PLACE_MEADOW"],
		[&"move_left", at.call(0, -1.0, -72.0), "PLACE_HILLS"],
		[&"move_forward", at.call(2, -1.0, -32.0), "PLACE_SANCTUARY"],
		[&"move_right", at.call(0, 1.0, -48.0), "PLACE_TEMPLE_ENTRANCE"],
		[&"move_backward", at.call(2, 1.0, -16.0), "PLACE_MEADOW"],
		[&"move_right", at.call(0, 1.0, -24.0), "PLACE_MEADOW"],
		[&"move_backward", at.call(2, 1.0, 16.0), "PLACE_GROVE"],
		[&"move_left", at.call(0, -1.0, -48.0), "PLACE_FIRST_CLEARING"],
		[&"move_backward", at.call(2, 1.0, 32.0), "PLACE_LAGOON"],
		[&"move_forward", at.call(2, -1.0, 16.0), "PLACE_FIRST_CLEARING"],
		[&"move_left", at.call(0, -1.0, -72.0), "PLACE_HIDDEN_GROTTO"],
		[&"move_backward", at.call(2, 1.0, 32.0), "PLACE_SPRING"],
	]
	await _walk_route(tree, player, route)
	assert_eq(tree.get_first_node_in_group(&"hud").area_label.text, tr("PLACE_SPRING"), "el cartel muestra la última zona")
	state.reset()


func test_walk_the_east_bank() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.global_position = Vector3(48, 0, -16)
	await tree.create_timer(0.5).timeout
	assert_eq(AreaZone._current.display_name, "PLACE_NECROPOLIS", "arranca en la Necrópolis")
	var at := func(axis: int, sign_: float, value: float) -> Callable:
		return func() -> bool: return (player.global_position[axis] - value) * sign_ >= 0.0
	var route := [
		[&"move_right", at.call(0, 1.0, 72.0), "PLACE_LOOKOUT"],
		[&"move_forward", at.call(2, -1.0, -30.0), "PLACE_EYE_CRAG"],
		[&"move_backward", at.call(2, 1.0, -16.0), "PLACE_LOOKOUT"],
		[&"move_left", at.call(0, -1.0, 48.0), "PLACE_NECROPOLIS"],
		[&"move_backward", at.call(2, 1.0, 16.0), "PLACE_CACTUS_FIELD"],
		[&"move_right", at.call(0, 1.0, 72.0), "PLACE_CACTUS_FIELD"],
		[&"move_backward", at.call(2, 1.0, 32.0), "PLACE_MARSH"],
		[&"move_left", at.call(0, -1.0, 24.0), "PLACE_LAGOON"],
	]
	await _walk_route(tree, player, route)
	state.reset()


func _walk_route(tree: SceneTree, player: PlayerCharacter, route: Array) -> void:
	for leg in route:
		var result: Array = await _walk_until(tree, player, leg[0], leg[1])
		assert_true(result[0], "llega a %s sin trabarse (quedó en %s)" % [leg[2], player.global_position.snappedf(0.1)])
		assert_eq(result[1], false, "no cae camino a %s" % leg[2])
		assert_eq(AreaZone._current.display_name if AreaZone._current else "", leg[2], "el HUD nombra la zona")



func test_abyss_has_no_floor_but_a_pit() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.physics_frame
	var space := (tree.current_scene as Node3D).get_world_3d().direct_space_state
	for point: Vector3 in [Vector3(72, 0, -36), Vector3(72, 0, -34), Vector3(0, 0, -16), Vector3(0, 0, 0), Vector3(-30, 0, 32)]:
		var down := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 0.8, 1)
		assert_true(space.intersect_ray(down).is_empty(), "el abismo no tiene piso (%s)" % point)
	var high := PhysicsRayQueryParameters3D.create(Vector3(72, 1.0, -30), Vector3(72, 1.0, -37), 1)
	assert_true(space.intersect_ray(high).is_empty(), "a la altura de una flecha pasa por arriba")
	assert_true(tree.current_scene.get_node(^"RiscoPit") is Pit, "abajo hay un Pit")
	tree.root.get_node(^"GameState").reset()



func test_falling_in_the_lagoon_splashes_and_returns_to_the_shore() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	await tree.physics_frame
	var before := player.health.current
	player.global_position = Vector3(-30, 0.5, 32)
	var splashed := false
	for i in 90:
		await tree.physics_frame
		splashed = splashed or tree.current_scene.find_children("Splash*", "CPUParticles3D", false, false).size() > 0
	assert_true(splashed, "salpica")
	assert_true(player.health.current < before, "caer al agua saca vida")
	assert_true(player.global_position.x < -40.0 and player.global_position.y > -0.5, "y vuelve a la orilla oeste (%s)" % player.global_position)
	tree.root.get_node(^"GameState").reset()


func test_the_marsh_water_slows_and_splashes_but_holds() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var water := tree.current_scene.get_node(^"BanadoWaterA") as ShallowWater
	player.global_position = water.global_position + Vector3(-2, 0.3, 0)
	for i in 20:
		await tree.physics_frame
	assert_eq(player.ground_speed, water.wade_speed, "adentro del agua baja frena")
	_walk(&"move_right", true)
	var splashed := false
	var lowest := player.global_position.y
	for i in 30:
		await tree.physics_frame
		lowest = minf(lowest, player.global_position.y)
		splashed = splashed or tree.current_scene.find_children("Wade*", "CPUParticles3D", false, false).size() > 0
	_walk(&"move_right", false)
	assert_true(splashed, "al andar salpica")
	assert_true(lowest > -0.5, "se camina: no cae (y mín %.2f)" % lowest)
	assert_true(player.global_position.y < -0.15, "y se hunde hasta el fondo (y %.2f)" % player.global_position.y)
	player.global_position = water.global_position + Vector3(0, 0.3, -8)
	for i in 10:
		await tree.physics_frame
	assert_eq(player.ground_speed, 1.0, "afuera vuelve a la velocidad de siempre")
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
