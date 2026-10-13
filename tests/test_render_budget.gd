extends "res://tests/test_case.gd"
## Presupuesto de dibujo con la cámara cenital (10.25, 10.26).

const LEVELS := ["res://levels/overworld.tscn", "res://levels/temple.tscn"]


func test_the_sun_shadows_only_what_the_camera_sees() -> void:
	for path in LEVELS:
		var scene: Node = (load(path) as PackedScene).instantiate()
		var sun := scene.get_node(^"Sun") as DirectionalLight3D
		assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "%s: dos cascadas" % path.get_file())
		assert_true(sun.directional_shadow_max_distance <= 40.0, "%s: hasta donde llega la cámara" % path.get_file())
		scene.free()


func test_walls_carry_no_faces_nobody_sees() -> void:
	var walls := {
		"res://data/kits/overworld_kit.tres": {"Acantilado": 960, "Andén borde": 960},
		"res://data/kits/temple_kit.tres": {"Pared": 700, "Pared nicho": 750, "Pared ojo": 750},
		"res://data/kits/chullpa_kit.tres": {"Pared": 2100, "Pared nicho": 2000, "Pared ojo": 2000},
		"res://data/kits/laguna_kit.tres": {"Pared": 750, "Pared nicho": 750, "Pared ojo": 850},
		"res://data/kits/cumbre_kit.tres": {"Pared": 950, "Pared nicho": 950, "Pared ojo": 1050},
	}
	for path: String in walls:
		var kit: MeshLibrary = load(path)
		for id in kit.get_item_list():
			var item := kit.get_item_name(id)
			if walls[path].has(item):
				var mesh := kit.get_item_mesh(id)
				var tris := 0
				var down := 0
				for surface in mesh.get_surface_count():
					var arrays := mesh.surface_get_arrays(surface)
					var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
					var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					tris += index.size() / 3
					for t in range(0, index.size(), 3):
						if (normals[index[t]] + normals[index[t + 1]] + normals[index[t + 2]]).normalized().y < -0.9:
							down += 1
				assert_true(tris <= walls[path][item], "%s: %d triángulos" % [item, tris])
				assert_eq(down, 0, "%s: sin caras hacia abajo" % item)
