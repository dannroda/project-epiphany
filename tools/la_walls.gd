extends SceneTree
## Prueba de paredes inclinadas a lo Link's Awakening sobre la Chullpa: cada celda de pared baja en rampa hacia los vecinos con piso.
## export: tools/paredes_la.json con las formas que usa el nivel (luego blender -b -P tools/blender/build_paredes_la.py).
## build: data/kits/chullpa_la_kit.tres (kit chullpa + paredes de paredes_la.glb) y debug/la/chullpa_la.tscn.
## godot --headless --path . --script res://tools/la_walls.gd -- export|build

const LEVEL := "res://levels/chullpa.tscn"
const KIT := "res://data/kits/chullpa_kit.tres"
const OUT_KIT := "res://data/kits/chullpa_la_kit.tres"
const OUT_LEVEL := "res://debug/la/chullpa_la.tscn"
const SHAPES := "res://tools/paredes_la.json"
const MESHES := "res://assets/epiphany/meshes/paredes_la/pared_la_%s.res"
const STONE := preload("res://data/kits/materials/epiphany_stone.tres")
const WALLS := ["Pared", "Pared nicho", "Pared ojo"]
const SIDES := {"n": Vector3i(0, 0, -1), "e": Vector3i(1, 0, 0), "s": Vector3i(0, 0, 1), "o": Vector3i(-1, 0, 0)}
const CORNERS := ["ne", "se", "so", "no"]
const CAMERA_OFFSET := Vector3(0, 28, 10.6)


func _initialize() -> void:
	var mode := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "export"
	var level: Node = (load(LEVEL) as PackedScene).instantiate()
	var walls := {}
	for grid: GridMap in level.find_children("*", "GridMap", true, false):
		walls[grid] = _shapes(grid)
	if mode == "export":
		var codes := {}
		for grid: GridMap in walls:
			for code: String in walls[grid].values():
				codes[code] = true
		var sorted := codes.keys()
		sorted.sort()
		FileAccess.open(SHAPES, FileAccess.WRITE).store_string(JSON.stringify(sorted, "\t") + "\n")
		print(SHAPES, ": ", sorted.size(), " formas")
	else:
		var kit := _kit()
		for grid: GridMap in walls:
			grid.mesh_library = kit
			for cell: Vector3i in walls[grid]:
				grid.set_cell_item(cell, kit.find_item_by_name("Pared LA " + walls[grid][cell]))
		for camera: Camera3D in level.find_children("*", "Camera3D", true, false):
			if "cuts_south_wall" in camera:
				camera.set("offset", CAMERA_OFFSET)
				camera.set("cuts_south_wall", false)
		var packed := PackedScene.new()
		packed.pack(level)
		print(OUT_LEVEL, ": ", error_string(ResourceSaver.save(packed, OUT_LEVEL)))
	level.free()
	quit()


func _shapes(grid: GridMap) -> Dictionary:
	var lib := grid.mesh_library
	var open := func(cell: Vector3i) -> bool:
		var item := grid.get_cell_item(cell)
		return item != GridMap.INVALID_CELL_ITEM and lib.get_item_name(item) not in WALLS
	var out := {}
	for cell in grid.get_used_cells():
		if lib.get_item_name(grid.get_cell_item(cell)) not in WALLS:
			continue
		var code := ""
		for side: String in SIDES:
			if open.call(cell + SIDES[side]):
				code += side
		var corners := ""
		for corner: String in CORNERS:
			if not code.contains(corner[0]) and not code.contains(corner[1]) and open.call(cell + SIDES[corner[0]] + SIDES[corner[1]]):
				corners += "_" + corner
		out[cell] = (code if code else "x") + corners
	return out


func _kit() -> MeshLibrary:
	var kit: MeshLibrary = (load(KIT) as MeshLibrary).duplicate(true)
	var wall := kit.find_item_by_name("Pared")
	var next := kit.get_last_unused_item_id()
	for code: String in JSON.parse_string(FileAccess.get_file_as_string(SHAPES)):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var mesh: Mesh = load(MESHES % code)
		for surface in mesh.get_surface_count():
			tool.append_from(mesh, surface, Transform3D.IDENTITY)
		tool.set_material(STONE)
		kit.create_item(next)
		kit.set_item_name(next, "Pared LA " + code)
		kit.set_item_mesh(next, tool.commit())
		kit.set_item_shapes(next, kit.get_item_shapes(wall))
		kit.set_item_navigation_mesh(next, kit.get_item_navigation_mesh(wall))
		next += 1
	var uid := ResourceLoader.get_resource_uid(OUT_KIT) if ResourceLoader.exists(OUT_KIT) else ResourceUID.INVALID_ID
	ResourceSaver.save(kit, OUT_KIT)
	if uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(OUT_KIT, uid)
	return load(OUT_KIT)
