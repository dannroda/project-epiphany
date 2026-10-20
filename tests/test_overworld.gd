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
	state.set_flag(&"ow_grotto_cracked_wall", true)
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	await tree.create_timer(0.5).timeout
	assert_eq(AreaZone._current.region_name(), "PLACE_FIRST_CLEARING", "arranca en el claro")
	var at := func(axis: int, sign_: float, value: float) -> Callable:
		return func() -> bool: return (player.global_position[axis] - value) * sign_ >= 0.0
	var route := [
		[&"move_forward", at.call(2, -1.0, -4.0), "PLACE_MEADOW"],
		[&"move_right", at.call(0, 1.0, -41.0), "PLACE_MEADOW"],
		[&"move_forward", at.call(2, -1.0, -30.0), "PLACE_TEMPLE_ESPLANADE"],
		[&"move_backward", at.call(2, 1.0, -4.0), "PLACE_MEADOW"],
		[&"move_right", at.call(0, 1.0, -24.0), "PLACE_MEADOW"],
		[&"move_left", at.call(0, -1.0, -62.0), "PLACE_MEADOW"],
		[&"move_backward", at.call(2, 1.0, 28.0), "PLACE_FIRST_CLEARING"],
		[&"move_right", at.call(0, 1.0, -50.0), "PLACE_FIRST_CLEARING"],
		[&"move_backward", at.call(2, 1.0, 31.5), "PLACE_LAGOON"],
		[&"move_forward", at.call(2, -1.0, 28.0), "PLACE_FIRST_CLEARING"],
		[&"move_left", at.call(0, -1.0, -62.0), "PLACE_FIRST_CLEARING"],
		[&"move_forward", at.call(2, -1.0, 16.0), "PLACE_FIRST_CLEARING"],
		[&"move_left", at.call(0, -1.0, -76.0), "PLACE_FIRST_CLEARING"],
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
	player.global_position = Vector3(40, 2.7, -3)
	await tree.create_timer(0.5).timeout
	assert_eq(AreaZone._current.region_name(), "PLACE_NECROPOLIS", "arranca en la Necrópolis")
	var at := func(axis: int, sign_: float, value: float) -> Callable:
		return func() -> bool: return (player.global_position[axis] - value) * sign_ >= 0.0
	var route := [
		[&"move_right", at.call(0, 1.0, 78.0), "PLACE_LOOKOUT"],
		[&"move_backward", at.call(2, 1.0, 16.0), "PLACE_CACTUS_FIELD"],
		[&"move_left", at.call(0, -1.0, 70.0), "PLACE_CACTUS_FIELD"],
		[&"move_backward", at.call(2, 1.0, 36.0), "PLACE_MARSH"],
		[&"move_forward", at.call(2, -1.0, 17.0), "PLACE_CACTUS_FIELD"],
		[&"move_left", at.call(0, -1.0, 54.0), "PLACE_CACTUS_FIELD"],
		[&"move_backward", at.call(2, 1.0, 18.0), "PLACE_CACTUS_FIELD"],
		[&"move_left", at.call(0, -1.0, 24.5), "PLACE_CACTUS_FIELD"],
		[&"move_forward", at.call(2, -1.0, 2.0), "PLACE_NECROPOLIS"],
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
	player.global_position = Vector3(-11, 0, -6)
	await tree.create_timer(0.3).timeout
	assert_eq(bridge.is_up, false, "sin flecha el puente está abajo")
	assert_eq((bridge.get_node(^"CollisionShape3D") as CollisionShape3D).disabled, true, "y no se pisa")
	var eye := level.get_node(^"RavineEye") as EyeSwitch
	var arrow: Projectile = load("res://src/items/arrow/arrow.tscn").instantiate()
	level.add_child(arrow)
	var info := Items.get_item(&"bow").make_damage(player)
	info.team = EntityConfig.Team.PLAYER
	var from := player.global_position + Vector3(0, 1.0, 0)
	var camera := tree.get_first_node_in_group(&"room_camera") as TopDownCamera
	TopDownCamera.unlock_reveals = true
	assert_true(absf(eye.eye.global_position.z - from.z) < 0.4, "el ojo queda en la línea del puente")
	arrow.launch(from, Vector3.RIGHT * 20.0, info)
	var until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until and not camera.revealing:
		await tree.process_frame
	assert_true(camera.revealing and tree.paused, "la cámara muestra el puente subiendo")
	while camera.revealing:
		await tree.process_frame
	assert_eq(bridge.is_up, true, "una flecha desde la Pradera al ojo de la otra orilla sube el puente")
	assert_eq(state.flags.get(&"ow_ravine_bridge_eye"), true, "y queda guardado")
	await tree.create_timer(1.6).timeout
	var crossed := await _walk_until(tree, player, &"move_right", func() -> bool: return player.global_position.x > 3.5)
	assert_true(crossed[0], "cruza el puente (quedó en %s)" % player.global_position.snappedf(0.1))
	assert_eq(crossed[1], false, "sin caerse")
	var at := func(axis: int, sign_: float, value: float) -> Callable:
		return func() -> bool: return (player.global_position[axis] - value) * sign_ >= 0.0
	await _walk_route(tree, player, [
		[&"move_forward", at.call(2, -1.0, -11.0), "PLACE_NECROPOLIS"],
		[&"move_right", at.call(0, 1.0, 14.0), "PLACE_NECROPOLIS"],
	])
	assert_true(player.global_position.y > 2.0, "y sube por la escalinata a la Necrópolis")
	state.reset()


func test_the_chullpa_door_leads_into_the_dungeon_and_back() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var level := (load(LEVEL) as PackedScene).instantiate()
	var door := level.get_node(^"ChullpaDoor") as Portal
	var spawn := level.get_node(^"Spawn_chullpa") as Node3D
	assert_eq(door.target_scene, "res://levels/chullpa.tscn", "la puerta lleva a la Chullpa")
	assert_true(spawn.position.distance_to(door.position) > 2.5, "la llegada desde la Chullpa queda afuera de la puerta")
	level.free()


func test_the_condor_frames_the_cumbre_door_and_lets_the_player_in() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var condor := tree.current_scene.get_node(^"CumbreCondor") as Node3D
	var door := tree.current_scene.get_node(^"CumbreDoor") as Node3D
	assert_true(absf(condor.global_position.x - door.global_position.x) < 0.1, "el cóndor está centrado en la puerta")
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.global_position = (tree.current_scene.get_node(^"Spawn_cumbre") as Node3D).global_position
	for i in 20:
		await tree.physics_frame
	_walk(&"move_forward", true)
	var until := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < until and tree.current_scene and tree.current_scene.scene_file_path == LEVEL:
		await tree.physics_frame
	_walk(&"move_forward", false)
	while Time.get_ticks_msec() < until and not (tree.current_scene and tree.current_scene.scene_file_path != LEVEL):
		await tree.physics_frame
	assert_eq(tree.current_scene.scene_file_path if tree.current_scene else "", "res://levels/cumbre.tscn", "entre las alas se entra a la Cumbre")
	state.reset()


func test_nothing_grows_on_the_travel_portals() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var level := tree.current_scene
	var portals := level.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.scene_file_path == "res://src/world/travel_portal.tscn")
	assert_eq(portals.size(), 6, "seis portales")
	var crowded := []
	for decor: Node in level.find_children("Decor", "", true, false):
		for piece: Node in decor.find_children("*", "Node3D", true, false):
			if piece.get_parent() is Node3D and piece.get_parent().get_parent() == decor:
				for portal: Node3D in portals:
					var at := (piece as Node3D).global_position
					if Vector2(at.x - portal.global_position.x, at.z - portal.global_position.z).length() < 2.0 and absf(at.y - portal.global_position.y) < 2.0:
						crowded.append("%s en %s" % [piece.name, portal.name])
	assert_eq(crowded, [], "ni plantas ni decoración encima de un portal")


func _walk_route(tree: SceneTree, player: PlayerCharacter, route: Array) -> void:
	for leg in route:
		var result: Array = await _walk_until(tree, player, leg[0], leg[1])
		assert_true(result[0], "llega a %s sin trabarse (quedó en %s)" % [leg[2], player.global_position.snappedf(0.1)])
		assert_eq(result[1], false, "no cae camino a %s" % leg[2])
		assert_eq(AreaZone._current.region_name() if AreaZone._current else "", leg[2], "el HUD nombra la zona (en %s)" % player.global_position.snappedf(0.1))



func test_abyss_has_no_floor_but_a_pit() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.physics_frame
	var space := (tree.current_scene as Node3D).get_world_3d().direct_space_state
	for point: Vector3 in [Vector3(-2, 0, -30), Vector3(-2, 0, -12), Vector3(2, 0, 4), Vector3(80, 5.2, -25)]:
		var down := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 0.8, 1)
		assert_true(space.intersect_ray(down).is_empty(), "el abismo no tiene piso (%s)" % point)
	var high := PhysicsRayQueryParameters3D.create(Vector3(-9, 1.0, -30), Vector3(5, 1.0, -30), 1)
	assert_true(space.intersect_ray(high).is_empty(), "a la altura de una flecha pasa por arriba")
	assert_true(tree.current_scene.get_node(^"QuebradaPit") is Pit, "abajo hay un Pit")
	assert_true(tree.current_scene.get_node(^"RiscoPit") is Pit, "y otro en el abismo del Risco")
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
	player.global_position = Vector3(-60, 0.1, 28)
	for i in 10:
		await tree.physics_frame
	player.global_position = Vector3(-60, 0.5, 38)
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
	var water := tree.current_scene.get_node(^"BanadoWater1") as ShallowWater
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
	player.global_position = water.global_position + Vector3(0, 0.3, -10)
	for i in 10:
		await tree.physics_frame
	assert_eq(player.ground_speed, 1.0, "afuera vuelve a la velocidad de siempre")
	tree.root.get_node(^"GameState").reset()

## Las piezas de hueco orientadas (punta, pasillo…) tienen pared justo hacia los lados que dan a piso; el Hueco suelto del kit LA las tiene hundidas en los cuatro y el de caída no tiene.
func test_pit_walls_face_the_ground() -> void:
	var root := (load("res://levels/chullpa.tscn") as PackedScene).instantiate()
	var cells := 0
	for grid: GridMap in root.find_children("GridMap", "GridMap", true, false):
		var lib := grid.mesh_library
		for cell in grid.get_used_cells():
			var piece := lib.get_item_name(grid.get_cell_item(cell))
			if not piece.begins_with("Hueco ") or piece.begins_with("Hueco caída"):
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
				assert_eq(wall, not open, "%s %s %s lado %d" % [grid.get_parent().name, lib.get_item_name(grid.get_cell_item(cell)), cell, k])
	assert_true(cells > 0, "la chullpa tiene huecos orientados")
	root.free()


## En el overworld las paredes del abismo son parte del terreno (12.15): desde adentro, a 1 m de hondo, hay roca hacia cada lado que da a tierra (no hacia la Laguna, donde desemboca la Quebrada).
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
			var neighbor := grid.get_cell_item(cell + side)
			if abyss.call(neighbor) or neighbor != -1 and lib.get_item_name(neighbor) == "Hueco":
				continue
			sides += 1
			var from := grid.to_global(grid.map_to_local(cell)) + Vector3.DOWN * (grid.cell_size.y / 2.0 + 1.0)
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
	for at in [Vector3(-60, 0, 26), Vector3(-80, 0, 16), Vector3(-40, 0, -4), Vector3(-65, 0, -4)]:
		hud.area_label.text = ""
		player.global_position = at
		await tree.create_timer(0.3).timeout
		shown.append(hud.area_label.text)
	assert_eq(AreaZone._current.name, &"Zone_pradera_4", "termina en el oeste de la Pradera")
	assert_eq(shown, ["", "", tr("PLACE_MEADOW"), ""], "entre pantallas del Claro sin cartel; a la Pradera sí; a otra pantalla de la Pradera, no")
	state.reset()


## Alguna parte de la zona, en alguno de los tres niveles de terraza, tiene un camino por la navmesh desde el inicio (con el link del puente si está arriba).
func _reachable_zones(tree: SceneTree) -> Array[String]:
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var map := player.get_world_3d().navigation_map
	var from := NavigationServer3D.map_get_closest_point(map, player.global_position)
	var reached: Array[String] = []
	for zone: AreaZone in tree.current_scene.find_children("Zone_*", "AreaZone", false, false):
		var bounds := zone.bounds()
		for fx in [0.25, 0.5, 0.75]:
			for fz in [0.25, 0.5, 0.75]:
				for level in 3:
					var target := Vector3(bounds.position.x + bounds.size.x * fx, level * 2.6, bounds.position.y + bounds.size.y * fz)
					var closest := NavigationServer3D.map_get_closest_point(map, target)
					var path := NavigationServer3D.map_get_path(map, from, closest, true)
					if closest.distance_to(target) < 3.0 and not path.is_empty() and path[-1].distance_to(closest) < 0.6:
						reached.append(String(zone.name))
						break
				if String(zone.name) in reached:
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
	var west: Array[String] = ["Zone_cerros", "Zone_cerros_2", "Zone_cerros_3", "Zone_laguna", "Zone_pradera", "Zone_pradera_10", "Zone_pradera_11", "Zone_pradera_12", "Zone_pradera_13", "Zone_pradera_2", "Zone_pradera_3", "Zone_pradera_4", "Zone_pradera_5", "Zone_pradera_6", "Zone_pradera_7", "Zone_pradera_8", "Zone_start", "Zone_start_2", "Zone_templo", "Zone_vertiente"]
	assert_eq(_reachable_zones(tree), west, "sin el puente, solo el oeste de la quebrada, sin la Arboleda (pluma)")
	(tree.current_scene.get_node(^"RavineBridge") as Bridge).raise(false)
	for i in 4:
		await tree.physics_frame
	var all := west.duplicate()
	all.append_array(["Zone_banado", "Zone_cardonal", "Zone_mirador", "Zone_mirador_2", "Zone_mirador_3", "Zone_mirador_4", "Zone_mirador_5", "Zone_necropolis", "Zone_necropolis_2", "Zone_pradera_9", "Zone_risco"])
	all.sort()
	assert_eq(_reachable_zones(tree), all, "con el puente, todo menos la Arboleda (pluma) y la Cumbre (gancho o escalera)")
	state.reset()


## La guarida de los guardias (11.195): un peñón con cueva sobre un descanso en la laguna, rodeado de agua honda; la boca
## mira a la cámara y está tapada hasta que la cueva tenga interior.
func test_the_guard_lair_waits_across_the_water() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.physics_frame
	var mouth := tree.current_scene.get_node(^"LairMouth") as Node3D
	assert_true(mouth.global_basis.z.z > 0.9, "la boca mira al sur, a la cámara")
	var space := (tree.current_scene as Node3D).get_world_3d().direct_space_state
	var landing := mouth.global_position + Vector3(0, 0, 2)
	assert_true(absf(_floor_at(space, landing)) < 0.5, "delante de la boca hay piso")
	for side in [Vector3(-7, 0, 0), Vector3(7, 0, 0), Vector3(0, 0, -9)]:
		assert_true(_floor_at(space, landing + side) < -2.0, "alrededor, agua honda (%s)" % (landing + side))
	var walk_in := PhysicsRayQueryParameters3D.create(landing + Vector3.UP, mouth.global_position + Vector3(0, 1, -1.5))
	assert_true(not space.intersect_ray(walk_in).is_empty(), "la boca está tapada")


## Manadas de atoq en la explanada de la D4 (11.196): de a 2-3 y lejos del camino del poste del gancho a la puerta del
## cóndor y de los portales, más que lo que pasean (4 m), así no tapan el paso ni la llegada.
func test_atoq_packs_roam_the_cumbre_beside_the_path() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.physics_frame
	var level := tree.current_scene
	var foxes := level.get_children().filter(func(n: Node) -> bool: return n.scene_file_path == "res://src/entities/atoq/atoq.tscn")
	assert_true(foxes.size() >= 4 and foxes.size() <= 9, "dos o tres manadas (%d atoq)" % foxes.size())
	var space := (level as Node3D).get_world_3d().direct_space_state
	var post := (level.get_node(^"RiscoBackPost") as Node3D).global_position
	var door := (level.get_node(^"CumbreDoor") as Node3D).global_position
	for fox: Node3D in foxes:
		var at := fox.global_position
		var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 6.0, 1, [(fox as CollisionObject3D).get_rid()])
		var floor_hit := space.intersect_ray(down)
		assert_true(floor_hit and absf((floor_hit.position as Vector3).y - 5.2) < 0.3, "%s parado en la nieve" % fox.name)
		var mates := foxes.filter(func(other: Node3D) -> bool: return other != fox and other.global_position.distance_to(at) < 3.0)
		assert_true(mates.size() >= 1 and mates.size() <= 2, "%s anda en manada" % fox.name)
		var near := Geometry3D.get_closest_point_to_segment(at, post, door)
		assert_true(Vector2(at.x - near.x, at.z - near.z).length() > 6.0, "%s lejos del camino a la puerta" % fox.name)
		for portal: Node3D in level.get_node(^"TravelPortals").get_children():
			assert_true(portal.global_position.distance_to(at) > 6.0, "%s lejos de %s" % [fox.name, portal.name])


func _floor_at(space: PhysicsDirectSpaceState3D, at: Vector3) -> float:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 6.0))
	return (hit.position as Vector3).y if hit else -INF


## La baranda choca solo de frente (11.131, 11.147): cada cara tiene que frenar a quien viene de su terraza.
func test_every_rail_faces_its_terrace() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 5:
		await tree.physics_frame
	var space := (tree.current_scene as Node3D).get_world_3d().direct_space_state
	var rails := tree.current_scene.find_children("baranda", "", true, false)
	assert_true(not rails.is_empty(), "el terreno tiene baranda")
	var checked := 0
	var open: Array[Vector3] = []
	for shape: CollisionShape3D in rails[0].find_children("*", "CollisionShape3D", true, false):
		var faces := (shape.shape as ConcavePolygonShape3D).get_faces()
		for i in range(0, faces.size(), 3):
			var a := shape.global_transform * faces[i]
			var b := shape.global_transform * faces[i + 1]
			var c := shape.global_transform * faces[i + 2]
			var across := (b - a).cross(c - a)
			across.y = 0.0
			if across.length() < 0.001:
				continue
			across = across.normalized()
			var mid := (a + b + c) / 3.0
			var ahead := _floor_at(space, mid + across * 0.6)
			var behind := _floor_at(space, mid - across * 0.6)
			if absf(ahead - behind) < 1.0:
				continue
			var side := 1.0 if ahead > behind else -1.0
			var query := PhysicsRayQueryParameters3D.create(mid + across * side * 0.6, mid - across * side * 0.3)
			query.hit_back_faces = false
			query.exclude = []
			var hit := space.intersect_ray(query)
			while hit and hit.collider != rails[0]:
				query.exclude = query.exclude + [hit.rid]
				hit = space.intersect_ray(query)
			checked += 1
			if not hit:
				open.append(mid)
	assert_true(checked > 1000, "revisó la baranda entera (%d caras)" % checked)
	assert_eq(open.slice(0, 5), [], "%d caras de baranda no frenan desde arriba" % open.size())


## 11.164: con la pared entera se camina sobre la tapa del nicho de la pieza de corazón (sin baranda invisible ni caída
## a un pozo sin salida); rota, la tapa y su piso se van y el nicho se sale por la pared.
func test_the_hills_niche_is_walked_over_until_the_wall_breaks() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.global_position = Vector3(-74, 2.7, -8)
	for i in 20:
		await tree.physics_frame
	var result: Array = await _walk_until(tree, player, &"move_backward", func() -> bool: return player.global_position.z > -3.6)
	assert_true(result[0], "cruza por encima del nicho (quedó en %s)" % player.global_position)
	assert_true(player.global_position.y > 2.4, "sobre la tapa, a la altura de la terraza (y %.2f)" % player.global_position.y)
	player.global_position = Vector3(-74, 2.7, -8)
	var space := player.get_world_3d().direct_space_state
	var down := PhysicsRayQueryParameters3D.create(Vector3(-74, 4, -4.6), Vector3(-74, 1, -4.6), 1)
	assert_true(not space.intersect_ray(down).is_empty(), "entera, hay piso sobre el nicho")
	state.set_flag(&"ow_secret_hills_wall", true)
	for i in 3:
		await tree.physics_frame
	assert_true(space.intersect_ray(down).is_empty(), "rota la pared, el nicho ya no tiene piso arriba")
	state.reset()


func test_the_risco_low_corridor_has_stairs_up() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.global_position = Vector3(63, 0.2, -21)
	for i in 20:
		await tree.physics_frame
	var result: Array = await _walk_until(tree, player, &"move_backward", func() -> bool: return player.global_position.z > -12.0)
	assert_true(result[0], "sale de la zanja por la escalinata (quedó en %s)" % player.global_position)
	assert_true(player.global_position.y > 2.4, "arriba, en la Necrópolis (y %.2f)" % player.global_position.y)
	state.reset()


## 11.164: lo que esconde una pared agrietada del overworld no se ve desde arriba hasta romperla.
func test_cracked_wall_niches_are_roofed_until_the_wall_breaks() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file("res://levels/overworld.tscn")
	await tree.scene_changed
	await tree.process_frame
	var level := tree.current_scene
	var hidden := {"SecretHillsWall": "HeartPieceHills", "SecretCactusWall": "SecretCactusChest", "SecretLookoutWall": "SecretLookoutChest",
		"SecretRavineWall": "SecretRavineChest", "SecretSummitWall": "SecretSummitChest"}
	for wall_name: String in hidden:
		var wall := level.get_node(wall_name) as CrackedWall
		var prize := level.get_node(hidden[wall_name]) as Node3D
		assert_eq(wall.covers.size(), 1, "%s tapa su nicho" % wall_name)
		var lid := wall.get_node_or_null(wall.covers[0]) as MeshInstance3D if wall.covers.size() == 1 else null
		if lid == null:
			continue
		var box := lid.global_transform * lid.get_aabb()
		var at := prize.global_position
		assert_true(lid.visible and box.position.x < at.x and at.x < box.end.x and box.position.z < at.z and at.z < box.end.z,
			"la tapa de %s está sobre %s" % [wall_name, prize.name])
		assert_true(box.position.y > at.y + 2.0, "a la altura de la terraza (%.2f)" % box.position.y)
		wall.smash()
		assert_true(not lid.visible, "rota %s, el nicho se ve" % wall_name)
	state.reset()


func _zone_box(zone: AreaZone) -> AABB:
	var shape := zone.get_node(^"CollisionShape3D") as CollisionShape3D
	var size := (shape.shape as BoxShape3D).size
	return shape.global_transform * AABB(-size / 2.0, size)


## 16.46: las zonas no se pisan y todo el piso al que se llega caminando (con el puente arriba) cae en alguna.
func test_the_zones_cover_the_map_without_overlapping() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 10:
		await tree.physics_frame
	var level := tree.current_scene
	var zones: Array[AreaZone] = []
	zones.assign(level.find_children("*", "AreaZone", true, false))
	var boxes: Array[AABB] = []
	boxes.assign(zones.map(_zone_box))
	var overlaps: Array[String] = []
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var common := boxes[i].intersection(boxes[j])
			if common.size.x > 0.01 and common.size.y > 0.01 and common.size.z > 0.01:
				overlaps.append("%s/%s" % [zones[i].name, zones[j].name])
	assert_eq(overlaps, [], "zonas que se pisan")
	(level.get_node(^"RavineBridge") as Bridge).raise(false)
	for i in 4:
		await tree.physics_frame
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var map := player.get_world_3d().navigation_map
	var from := NavigationServer3D.map_get_closest_point(map, player.global_position)
	var navmesh := level.get_node(^"NavigationRegion3D") as NavigationRegion3D
	var mesh := navmesh.navigation_mesh
	var vertices := mesh.get_vertices()
	var walked := 0
	var outside: Array[String] = []
	for p in mesh.get_polygon_count():
		var polygon := mesh.get_polygon(p)
		var center := Vector3.ZERO
		for index in polygon:
			center += vertices[index]
		center = navmesh.global_transform * (center / polygon.size())
		var closest := NavigationServer3D.map_get_closest_point(map, center)
		var path := NavigationServer3D.map_get_path(map, from, closest, true)
		if closest.distance_to(center) > 0.5 or path.is_empty() or path[-1].distance_to(closest) > 0.6:
			continue
		walked += 1
		if not boxes.any(func(box: AABB) -> bool: return box.grow(0.05).has_point(center)):
			outside.append("(%.1f, %.1f, %.1f)" % [center.x, center.y, center.z])
	assert_true(walked > 500, "se llega a casi todo el piso (%d polígonos)" % walked)
	assert_eq(outside.slice(0, 8), [], "%d polígonos a los que se llega fuera de toda zona" % outside.size())
	state.reset()


## 16.45: cada zona es de una región, y cada región pone su nombre en el mapa sobre una sola de sus zonas.
func test_every_zone_has_a_region_labeled_once() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var zones: Array[AreaZone] = []
	zones.assign(tree.current_scene.find_children("*", "AreaZone", true, false))
	assert_eq(zones.filter(func(zone: AreaZone) -> bool: return zone.region == null).map(func(zone: AreaZone) -> StringName: return zone.name), [], "zonas sin región")
	var labels := {}
	for zone in zones:
		if zone.region and zone.has_region_label():
			labels[zone.region.id] = labels.get(zone.region.id, 0) + 1
	var regions := {}
	for zone in zones:
		if zone.region:
			regions[zone.region.id] = labels.get(zone.region.id, 0)
	assert_eq(regions.size(), 13, "13 regiones")
	assert_eq(regions.keys().filter(func(id: StringName) -> bool: return regions[id] != 1), [], "regiones sin etiqueta o con más de una")


## 16.47: tools/terreno_overworld.json es el export del nivel actual; si no, el terreno se armó con otro nivel (volver a
## exportar y a armarlo con build_terreno_organico.py).
func test_the_terrain_json_matches_the_level() -> void:
	var export := preload("res://tools/export_terreno_overworld.gd")
	var level: Node3D = (load(LEVEL) as PackedScene).instantiate()
	var built: Dictionary = JSON.parse_string(JSON.stringify(export.build(level)))
	level.free()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(export.OUT))
	var stale: Array[String] = []
	for key: String in built.keys() + saved.keys().filter(func(key: String) -> bool: return not built.has(key)):
		var now: Variant = built.get(key)
		var then: Variant = saved.get(key)
		if now is Array and then is Array:
			for i in maxi(now.size(), then.size()):
				if i >= now.size() or i >= then.size() or now[i] != then[i]:
					stale.append("%s[%d]: %s → %s" % [key, i, then[i] if i < then.size() else null, now[i] if i < now.size() else null])
					break
		elif now != then:
			stale.append("%s: %s → %s" % [key, then, now])
	assert_eq(stale, [], "el JSON del terreno quedó viejo")


## 16.48: cada pared agrietada del overworld nombra su roca del terreno con `terrain_id`, no con el nombre del nodo.
func test_every_cracked_wall_has_its_terrain_rock() -> void:
	var level: Node3D = (load(LEVEL) as PackedScene).instantiate()
	var missing: Array[String] = []
	var walls := level.find_children("*", "CrackedWall", false, false)
	assert_eq(walls.size(), 7, "las siete paredes agrietadas del overworld")
	for wall: CrackedWall in walls:
		var rock := "res://assets/epiphany/meshes/muros_organicos/muro_%s.res" % wall.terrain_id
		if wall.terrain_id.is_empty() or not ResourceLoader.exists(rock):
			missing.append(String(wall.name))
	assert_eq(missing, [], "paredes agrietadas sin su roca")
	level.free()


## 16.50: los estilos de TerrainStyleArea son las claves de STYLES en build_terreno_organico.py, y todas las áreas usan uno.
func test_terrain_styles_match_the_build() -> void:
	var probe := TerrainStyleArea.new()
	var hint: String = probe.get_property_list().filter(func(p: Dictionary) -> bool: return p.name == "style")[0].hint_string
	probe.free()
	var options := hint.split(",")
	var source := FileAccess.get_file_as_string("res://tools/blender/build_terreno_organico.py")
	var block := source.substr(source.find("\nSTYLES = {"), source.find("\n}\n", source.find("\nSTYLES = {")) - source.find("\nSTYLES = {"))
	var styles: Array[String] = []
	var key := RegEx.create_from_string("\\n\\t\"(\\w+)\": \\{")
	for found in key.search_all(block):
		styles.append(found.get_string(1))
	assert_eq(Array(options), Array(styles), "el enum de style es STYLES de Python")
	var level: Node3D = (load(LEVEL) as PackedScene).instantiate()
	var wrong: Array[String] = []
	for area: TerrainStyleArea in level.get_node(^"TerrainStyles").get_children():
		if not area.style.is_empty() and not area.style in styles:
			wrong.append("%s: %s" % [area.name, area.style])
	level.free()
	assert_eq(wrong, [], "áreas con un estilo que el build no conoce")
