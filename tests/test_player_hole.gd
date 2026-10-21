extends "res://tests/test_case.gd"

const WALL := preload("res://data/kits/materials/epiphany_wall.tres")
const PLAIN := preload("res://data/kits/materials/epiphany_outdoor.tres")


func test_overworld_walls_cut_a_hole_but_not_at_the_edge_of_the_world() -> void:
	var overworld: Node = load("res://levels/overworld.tscn").instantiate()
	var grid := overworld.get_node(^"GridMap") as GridMap
	var library := grid.mesh_library
	var terrain := overworld.get_node(^"Terreno")
	var rocks := terrain.find_children("riscos_*", "MeshInstance3D", true, false)
	var floors := terrain.find_children("suelo_*", "MeshInstance3D", true, false)
	assert_true(rocks.size() > 12 and floors.size() > 12, "el terreno va en bloques (%d riscos, %d suelos)" % [rocks.size(), floors.size()])
	assert_true(rocks.all(func(m: MeshInstance3D) -> bool: return m.get_active_material(0) == WALL), "la roca del terreno se recorta alrededor del player")
	assert_true(floors.all(func(m: MeshInstance3D) -> bool: return m.get_active_material(0) == PLAIN), "el piso no")
	assert_true((overworld.get_node(^"OverworldMap") as OverworldMap).grid == grid)
	OverworldMap.use_edge_walls(grid)
	var edges := 0
	for cell in grid.get_used_cells():
		var item_name := library.get_item_name(grid.get_cell_item(cell))
		var open_south := grid.get_cell_item(cell + Vector3i(0, 0, 1)) == GridMap.INVALID_CELL_ITEM
		if item_name in ["Pared", "Acantilado", "Risco"]:
			assert_eq(open_south, false, "%s %s tiene algo del lado de la cámara" % [item_name, cell])
		if item_name.ends_with(" borde"):
			edges += 1
	assert_true(edges > 0, "el borde del mundo usa las paredes sin agujero")
	overworld.free()


## 11.134: detrás de un risco la cámara se pone encima del player en vez de recortar un agujero, y vuelve al salir.
func test_a_hidden_player_turns_the_camera_overhead() -> void:
	assert_true(ProjectSettings.has_setting("shader_globals/player_hole"), "uniform global registrada")
	var tree := Engine.get_main_loop() as SceneTree
	tree.change_scene_to_file("res://levels/overworld.tscn")
	await tree.scene_changed
	await tree.process_frame
	await tree.process_frame
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var player := tree.get_first_node_in_group(&"player") as Node3D
	var camera := tree.current_scene.get_node(^"TopDownCamera") as TopDownCamera
	var tilt := func() -> float: return rad_to_deg(camera.global_basis.z.angle_to(Vector3.UP))
	var normal_tilt: float = rad_to_deg(camera.offset.angle_to(Vector3.UP))
	assert_true(Vector3(camera.player_hole.x, camera.player_hole.y, camera.player_hole.z).distance_to(player.global_position) < 0.5, "sigue al player")
	assert_true(not camera.occluded and absf(tilt.call() - normal_tilt) < 1.0, "en el claro, el ángulo normal (%.1f°)" % tilt.call())
	player.global_position = Vector3(-88, 0.1, -37.8)
	await tree.create_timer(0.1).timeout
	assert_true(camera.occluded, "detrás del muro lo tapa")
	assert_true(tilt.call() < normal_tilt - 1.0, "y la cámara empieza a subir (%.1f°)" % tilt.call())
	await tree.create_timer(1.8).timeout
	assert_true(tilt.call() < 1.0, "hasta quedar encima (%.1f°)" % tilt.call())
	assert_eq(camera.player_hole.w, 0.0, "sin agujero en las paredes")
	player.global_position = Vector3(-88, 0.1, -41.0)
	await tree.create_timer(0.3).timeout
	assert_true(camera.occluded and tilt.call() < 1.0, "recién salido sigue encima un rato (%.1f°)" % tilt.call())
	await tree.create_timer(2.6).timeout
	assert_true(not camera.occluded and absf(tilt.call() - normal_tilt) < 1.0, "lejos del muro vuelve al ángulo normal (%.1f°)" % tilt.call())


## Playtest de 11.134: los árboles, cardones y objetos no suben la cámara (detrás de esos está la silueta); solo las paredes.
func test_only_walls_turn_the_camera_overhead() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.change_scene_to_file("res://levels/overworld.tscn")
	await tree.scene_changed
	await tree.process_frame
	await tree.process_frame
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var level := tree.current_scene
	var camera := level.get_node(^"TopDownCamera") as TopDownCamera
	var risco := level.get_node(^"Terreno/Parte0/riscos_0_3").find_children("*", "StaticBody3D", true, false)
	assert_true(not risco.is_empty() and camera.occlusion.call(&"_is_wall", risco[0]), "la roca del terreno es pared")
	var props := 0
	for body in level.find_children("Body", "StaticBody3D", true, false):
		if String(body.get_parent().name).rstrip("0123456789_") in ["Arbol", "Cardon", "QuenoaChica"]:
			assert_true(not camera.occlusion.call(&"_is_wall", body), "%s no es pared" % body.get_parent().name)
			props += 1
	assert_true(props > 100, "revisó los árboles y cardones (%d)" % props)
	var player := tree.get_first_node_in_group(&"player") as Node3D
	var space := camera.get_world_3d().direct_space_state
	var behind := Vector3.INF
	for body in level.find_children("Body", "StaticBody3D", true, false):
		if not String(body.get_parent().name).begins_with("Arbol"):
			continue
		var at := (body as Node3D).global_position + Vector3(0, 0, -1.0)
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.8 + camera.offset, at + Vector3.UP * 0.8, 1)
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and hit.collider == body:
			behind = at
			break
	assert_true(behind != Vector3.INF, "hay un árbol que tapa a alguien parado detrás")
	player.global_position = behind + Vector3.UP * 0.1
	camera.snap_to_target()
	await tree.create_timer(0.4).timeout
	assert_true(not camera.occluded, "detrás del árbol la cámara no sube")


func test_clouds_only_while_in_the_overworld() -> void:
	var nubes := load("res://src/world/look/nubes_la.gd")
	var has_clouds := func(path: String) -> bool:
		var level: Node = load(path).instantiate()
		var found := false
		for world: WorldEnvironment in level.find_children("*", "WorldEnvironment", true, false):
			for effect in world.compositor.compositor_effects if world.compositor else []:
				found = found or (effect and effect.get_script() == nubes and effect.strength > 0.0)
		level.free()
		return found
	assert_true(has_clouds.call("res://levels/overworld.tscn"), "el overworld tiene nubes")
	assert_true(not has_clouds.call("res://levels/templo.tscn"), "el templo no")


## Playtest 2026-10-14: en una sala (cueva de las bombas) los bordes y los muros bajos no suben la cámara.
func test_rooms_never_turn_the_camera_overhead() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.change_scene_to_file("res://levels/bomb_cave.tscn")
	await tree.scene_changed
	await tree.process_frame
	await tree.process_frame
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var camera := TopDownCamera.find(tree)
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	assert_true(camera.room != null, "la cámara está en la sala")
	var bounds := camera.room.bounds()
	var spot := Vector3.INF
	for x in range(int(bounds.position.x), int(bounds.end.x)):
		for z in range(int(bounds.position.y), int(bounds.end.y)):
			player.global_position = Vector3(x + 0.5, camera.room.floor_y() + 0.1, z + 0.5)
			if camera.occlusion.call(&"_player_hidden", player):
				spot = player.global_position
				break
		if spot != Vector3.INF:
			break
	assert_true(spot != Vector3.INF, "hay un lugar donde una pared lo taparía")
	player.global_position = spot
	await tree.create_timer(0.4).timeout
	assert_true(not camera.occluded, "en la sala la cámara no sube")
