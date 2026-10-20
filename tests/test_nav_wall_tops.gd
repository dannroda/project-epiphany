extends "res://tests/test_case.gd"
## 11.9: la navmesh horneada no deja islas arriba de paredes ni columnas (WallTops).

const KIT := preload("res://data/kits/templo_la_kit.tres")


func test_walls_leave_no_islands_on_top() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var grid := GridMap.new()
	grid.mesh_library = KIT
	grid.cell_size = Vector3(2, 1, 2)
	grid.cell_center_y = false
	grid.add_to_group(&"wall_tops_test")
	var floor := KIT.find_item_by_name("Piso")
	var wall := KIT.find_item_by_name("Pared LA x")
	for x in 8:
		for z in 8:
			grid.set_cell_item(Vector3i(x, 0, z), wall if x in [3, 4] and z > 1 else floor)
	tree.root.add_child(grid)
	await tree.physics_frame
	WallTops.register()
	var navmesh := NavigationMesh.new()
	navmesh.cell_height = 0.05
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	navmesh.geometry_source_group_name = &"wall_tops_test"
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navmesh, source, grid)
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source)
	assert_true(floor >= 0 and wall >= 0, "el kit tiene Piso y Pared LA x")
	var heights := Array(navmesh.vertices).map(func(v: Vector3) -> float: return v.y)
	assert_true(not heights.is_empty(), "hay navmesh en el piso")
	assert_true(heights.max() < 0.2, "pegada al piso y sin nada arriba de la pared (%.2f)" % heights.max())
	grid.free()
