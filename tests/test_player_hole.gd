extends "res://tests/test_case.gd"

const WALL := preload("res://data/kits/materials/epiphany_wall.tres")
const PLAIN := preload("res://data/kits/materials/epiphany.tres")


func _material(library: MeshLibrary, item_name: String) -> Material:
	return library.get_item_mesh(library.find_item_by_name(item_name)).surface_get_material(0)


func test_overworld_walls_cut_a_hole_but_not_at_the_edge_of_the_world() -> void:
	var overworld: Node = load("res://levels/overworld.tscn").instantiate()
	var grid := overworld.get_node(^"GridMap") as GridMap
	var library := grid.mesh_library
	for item_name in ["Pared", "Acantilado", "Risco"]:
		assert_eq(_material(library, item_name), WALL, "%s se recorta alrededor del player" % item_name)
	for item_name in ["Pared borde", "Andén borde", "Risco borde"]:
		assert_eq(_material(library, item_name), PLAIN, "%s no" % item_name)
	assert_eq(_material(library, "Pasto"), PLAIN, "el piso no")
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
	var player := tree.get_first_node_in_group(&"player") as Node3D
	var hole: Vector4 = (tree.current_scene.get_node(^"TopDownCamera") as TopDownCamera).player_hole
	assert_true(Vector3(hole.x, hole.y, hole.z).distance_to(player.global_position) < 0.5, "sigue al player")
	assert_eq(hole.w, 1.0)
