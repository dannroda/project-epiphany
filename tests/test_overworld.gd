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
		[&"move_left", at.call(0, -1.0, -72.0), "PLACE_MEADOW"],
		[&"move_forward", at.call(2, -1.0, -32.0), "PLACE_TEMPLE_ESPLANADE"],
		[&"move_right", at.call(0, 1.0, -48.0), "PLACE_TEMPLE_ESPLANADE"],
		[&"move_backward", at.call(2, 1.0, -16.0), "PLACE_MEADOW"],
		[&"move_right", at.call(0, 1.0, -24.0), "PLACE_MEADOW"],
		[&"move_backward", at.call(2, 1.0, 16.0), "PLACE_FIRST_CLEARING"],
		[&"move_left", at.call(0, -1.0, -48.0), "PLACE_FIRST_CLEARING"],
		[&"move_backward", at.call(2, 1.0, 32.0), "PLACE_LAGOON"],
		[&"move_forward", at.call(2, -1.0, 16.0), "PLACE_FIRST_CLEARING"],
		[&"move_left", at.call(0, -1.0, -72.0), "PLACE_FIRST_CLEARING"],
		[&"move_backward", at.call(2, 1.0, 32.0), "PLACE_FIRST_CLEARING"],
	]
	await _walk_route(tree, player, route)
	assert_eq(tree.get_first_node_in_group(&"hud").area_label.text, tr("PLACE_FIRST_CLEARING"), "el cartel muestra la última zona")
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
		[&"move_right", at.call(0, 1.0, 72.0), "PLACE_NECROPOLIS"],
		[&"move_forward", at.call(2, -1.0, -30.0), "PLACE_SUMMIT"],
		[&"move_backward", at.call(2, 1.0, -16.0), "PLACE_NECROPOLIS"],
		[&"move_left", at.call(0, -1.0, 48.0), "PLACE_NECROPOLIS"],
		[&"move_backward", at.call(2, 1.0, 16.0), "PLACE_MARSH"],
		[&"move_right", at.call(0, 1.0, 72.0), "PLACE_MARSH"],
		[&"move_backward", at.call(2, 1.0, 32.0), "PLACE_MARSH"],
		[&"move_left", at.call(0, -1.0, 24.0), "PLACE_LAGOON"],
	]
	await _walk_route(tree, player, route)
	state.reset()


func test_an_arrow_at_the_eye_raises_the_bridge_to_the_necropolis() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var level := tree.current_scene
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var bridge := level.get_node(^"RavineBridge") as Bridge
	player.global_position = Vector3(-10, 0, -16)
	await tree.create_timer(0.3).timeout
	assert_eq(bridge.is_up, false, "sin flecha el puente está abajo")
	assert_eq((bridge.get_node(^"CollisionShape3D") as CollisionShape3D).disabled, true, "y no se pisa")
	var eye := level.get_node(^"RavineEye") as EyeSwitch
	var arrow: Projectile = load("res://src/items/arrow/arrow.tscn").instantiate()
	level.add_child(arrow)
	var info := Items.get_item(&"bow").make_damage(player)
	info.team = EntityConfig.Team.PLAYER
	var from := Vector3(-8, 1.2, -16)
	var camera := tree.get_first_node_in_group(&"room_camera") as TopDownCamera
	TopDownCamera.unlock_reveals = true
	arrow.launch(from, (eye.eye.global_position - from).normalized() * 20.0, info)
	var until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until and not camera.revealing:
		await tree.process_frame
	assert_true(camera.revealing and tree.paused, "la cámara muestra el puente subiendo")
	while camera.revealing:
		await tree.process_frame
	assert_eq(bridge.is_up, true, "una flecha desde la Pradera al ojo de la otra orilla sube el puente")
	assert_eq(state.flags.get(&"ow_ravine_bridge_eye"), true, "y queda guardado")
	await tree.create_timer(1.6).timeout
	var crossed := await _walk_until(tree, player, &"move_right", func() -> bool: return player.global_position.x > 14.0)
	assert_true(crossed[0], "cruza el puente (quedó en %s)" % player.global_position.snappedf(0.1))
	assert_eq(crossed[1], false, "sin caerse")
	assert_eq(AreaZone._current.display_name, "PLACE_NECROPOLIS", "y llega a la Necrópolis")
	state.reset()


func test_the_chullpa_door_leads_into_the_dungeon_and_back() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var level := (load(LEVEL) as PackedScene).instantiate()
	var door := level.get_node(^"ChullpaDoor") as Portal
	var spawn := level.get_node(^"Spawn_chullpa") as Node3D
	assert_eq(door.target_scene, "res://levels/chullpa.tscn", "la puerta lleva a la Chullpa")
	assert_true(spawn.position.distance_to(door.position) > 2.5, "la llegada desde la Chullpa queda afuera de la puerta")
	level.free()


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


func test_the_hud_names_a_region_once_while_walking_its_screens() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var hud := tree.get_first_node_in_group(&"hud")
	await tree.create_timer(0.3).timeout
	var shown: Array[String] = []
	for at in [Vector3(-24, 0, 16), Vector3(-72, 0, 16), Vector3(-36, 0, -8), Vector3(-72, 0, -8)]:
		var before: Tween = hud._area_tween
		player.global_position = at
		await tree.create_timer(0.3).timeout
		shown.append(hud.area_label.text if hud._area_tween != before else "")
	assert_eq(AreaZone._current.name, &"Zone_cueva", "termina en los Cerros")
	assert_eq(shown, ["", "", tr("PLACE_MEADOW"), ""], "Claro → Arboleda → Gruta sin cartel; a la Pradera sí; a los Cerros, que también son Pradera, no")
	state.reset()


## Alguna parte de la zona tiene un camino por la navmesh desde el inicio (con el link del puente si está arriba).
func _reachable_zones(tree: SceneTree) -> Array[String]:
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var map := player.get_world_3d().navigation_map
	var from := NavigationServer3D.map_get_closest_point(map, player.global_position)
	var reached: Array[String] = []
	for zone: AreaZone in tree.current_scene.find_children("Zone_*", "AreaZone", false, false):
		var bounds := zone.bounds()
		for fx in [0.25, 0.5, 0.75]:
			for fz in [0.25, 0.5, 0.75]:
				var target := Vector3(bounds.position.x + bounds.size.x * fx, 0, bounds.position.y + bounds.size.y * fz)
				var closest := NavigationServer3D.map_get_closest_point(map, target)
				var path := NavigationServer3D.map_get_path(map, from, closest, true)
				if Vector2(closest.x, closest.z).distance_to(Vector2(target.x, target.z)) < 3.0 and not path.is_empty() and path[-1].distance_to(closest) < 0.6:
					reached.append(String(zone.name))
					break
			if String(zone.name) in reached:
				break
	reached.sort()
	return reached


func test_every_region_is_reachable_except_the_item_gated() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 10:
		await tree.physics_frame
	var west: Array[String] = ["Zone_arboleda", "Zone_cueva", "Zone_gruta", "Zone_pradera", "Zone_santuario", "Zone_start", "Zone_templo", "Zone_vertiente"]
	assert_eq(_reachable_zones(tree), west, "sin el puente, solo el oeste de la quebrada")
	(tree.current_scene.get_node(^"RavineBridge") as Bridge).raise(false)
	for i in 4:
		await tree.physics_frame
	var all := west.duplicate()
	all.append_array(["Zone_banado", "Zone_cardonal", "Zone_mirador", "Zone_necropolis", "Zone_risco"])
	all.sort()
	assert_eq(_reachable_zones(tree), all, "con el puente, todo menos la Cumbre (gancho), la isla de la Laguna (gancho) y las franjas de la Quebrada (11.90)")
	state.reset()
