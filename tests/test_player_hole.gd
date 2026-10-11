extends "res://tests/test_case.gd"

const WALL := preload("res://data/kits/materials/epiphany_wall.tres")
const PLAIN := preload("res://data/kits/materials/epiphany_outdoor.tres")


func test_overworld_walls_cut_a_hole_but_not_at_the_edge_of_the_world() -> void:
	var overworld: Node = load("res://levels/overworld.tscn").instantiate()
	var grid := overworld.get_node(^"GridMap") as GridMap
	var library := grid.mesh_library
	var terrain := overworld.get_node(^"Terreno")
	assert_eq((terrain.get_node(^"riscos") as MeshInstance3D).get_active_material(0), WALL, "la roca del terreno se recorta alrededor del player")
	assert_eq((terrain.get_node(^"suelo") as MeshInstance3D).get_active_material(0), PLAIN, "el piso no")
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


func test_the_camera_follows_the_player_with_the_hole() -> void:
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
	assert_true(Vector3(camera.player_hole.x, camera.player_hole.y, camera.player_hole.z).distance_to(player.global_position) < 0.5, "sigue al player")
	assert_eq(camera.player_hole.w, 0.0, "en el claro nada lo tapa: sin agujero")
	player.global_position = Vector3(-54, player.global_position.y, 6.2)
	await tree.create_timer(0.1).timeout
	assert_true(camera.player_hole.w > 0.0 and camera.player_hole.w < 1.0, "detrás del muro el agujero se va abriendo (%.2f)" % camera.player_hole.w)
	await tree.create_timer(0.3).timeout
	assert_eq(camera.player_hole.w, 1.0, "y queda abierto")
	player.global_position = Vector3(-54, player.global_position.y, 3.0)
	await tree.create_timer(0.4).timeout
	assert_eq(camera.player_hole.w, 0.0, "lejos del muro se cierra")


func test_clouds_only_while_in_the_overworld() -> void:
	assert_true(ProjectSettings.has_setting("shader_globals/cloud_shadows"), "uniform global registrada")
	var overworld: Node = load("res://levels/overworld.tscn").instantiate()
	var clouds := overworld.get_node_or_null(^"CloudShadows")
	assert_true(clouds != null, "el overworld tiene nubes")
	if clouds:
		var shade: Vector4 = clouds.value()
		assert_true(shade.x > 0.0 and shade.y > 0.0, "fuerza y tamaño")
	overworld.free()
	var temple: Node = load("res://levels/temple.tscn").instantiate()
	assert_true(temple.get_node_or_null(^"CloudShadows") == null, "el templo no")
	temple.free()
