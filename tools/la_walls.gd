extends SceneTree
## Prueba de paredes inclinadas a lo Link's Awakening sobre la Chullpa: cada celda de pared baja en rampa hacia los vecinos con piso.
## export: tools/paredes_la.json con las formas que usa el nivel (luego blender -b -P tools/blender/build_paredes_la.py).
## build: data/kits/chullpa_la_kit.tres (kit chullpa + piezas de paredes_la.glb) y debug/la/chullpa_la.tscn.
## Las celdas Puerta llevan un corte (paso) o, si tienen escalera, un corte ciego con escalones (sube, baja).
## godot --headless --path . --script res://tools/la_walls.gd -- export|build

const LEVEL := "res://levels/chullpa.tscn"
const KIT := "res://data/kits/chullpa_kit.tres"
const OUT_KIT := "res://data/kits/chullpa_la_kit.tres"
const OUT_LEVEL := "res://debug/la/chullpa_la.tscn"
const SHAPES := "res://tools/paredes_la.json"
const MESHES := "res://assets/epiphany/meshes/paredes_la/%s_la_%s.res"
const STONE := preload("res://data/kits/materials/epiphany_stone.tres")
const BRAZIER := preload("res://assets/epiphany/meshes/templo_chullpa/brasero.res")
const WALLS := ["Pared", "Pared nicho", "Pared ojo"]
const DOOR := "Puerta"
## kind de la pieza → [nombre del ítem, ítem del kit de donde copia colisión y navmesh].
const KINDS := {"pared": ["Pared LA ", "Pared"], "paso": ["Paso LA ", "Puerta"], "sube": ["Sube LA ", "Piso"], "baja": ["Baja LA ", "Piso"]}
const SIDES := {"n": Vector3i(0, 0, -1), "e": Vector3i(1, 0, 0), "s": Vector3i(0, 0, 1), "o": Vector3i(-1, 0, 0)}
const CORNERS := ["ne", "se", "so", "no"]
## Rampa por lado con piso y alto de las paredes (como en build_paredes_la.py); la cámara tapa más allá de MASK_MARGIN.
const WALL_RUN := {"n": 0.8, "s": 0.8, "e": 1.4, "o": 1.4}
const WALL_HEIGHT := 2.0
## Alto de los pilares (PILLAR en build_paredes_la.py): hasta ahí tapa la cámara.
const PILLAR_HEIGHT := 3.0
const MASK_MARGIN := 2.0
const BRAZIER_SCALE := 0.55
## Sobre el borde, pegado al frente: más atrás queda en la franja que la sala de al norte ve por encima de su pared sur.
const BRAZIER_SETBACK := 0.15
const BRAZIER_FLAME := 1.07
const DOOR_LEAF_SCALE := Vector3(0.7, 0.8, 1.0)
## Cámara ortográfica (como LA): las paredes de los costados tienen el mismo ancho arriba y abajo.
const CAMERA_OFFSET := Vector3(0, 68.9, 57.9)
const ORTHO_SIZE := 19.0


func _initialize() -> void:
	var mode := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "export"
	var level: Node = (load(LEVEL) as PackedScene).instantiate()
	_spread(level)
	var cells := {}
	for grid: GridMap in level.find_children("*", "GridMap", true, false):
		cells[grid] = _shapes(grid)
	if mode == "export":
		var codes := {}
		for kind: String in KINDS:
			codes[kind] = {}
		for grid: GridMap in cells:
			for shape: Array in cells[grid].values():
				codes[shape[0]][shape[1]] = true
		var out := {}
		for kind: String in codes:
			out[kind] = codes[kind].keys()
			out[kind].sort()
		FileAccess.open(SHAPES, FileAccess.WRITE).store_string(JSON.stringify(out, "\t") + "\n")
		print(SHAPES, ": ", out)
	else:
		var kit := _kit()
		for grid: GridMap in cells:
			grid.mesh_library = kit
			for cell: Vector3i in cells[grid]:
				var shape: Array = cells[grid][cell]
				grid.set_cell_item(cell, kit.find_item_by_name(KINDS[shape[0]][0] + shape[1]))
		_dress(level)
		var packed := PackedScene.new()
		packed.pack(level)
		print(OUT_LEVEL, ": ", error_string(ResourceSaver.save(packed, OUT_LEVEL)))
	level.free()
	quit()


## Antorchas a braseros sobre el borde, puertas a la medida del corte, sin los escalones viejos y la cámara casi sin perspectiva.
func _dress(level: Node) -> void:
	for node: Node in level.find_children("*", "", true, false):
		var path := node.scene_file_path
		if path.ends_with("wall_torch.tscn"):
			var torch := node as Node3D
			var facing := torch.transform.basis.z.normalized()
			var side := "s" if facing.z > 0.5 else "n" if facing.z < -0.5 else "e" if facing.x > 0.5 else "o"
			torch.position = torch.position - facing * (WALL_RUN[side] + BRAZIER_SETBACK)
			torch.position.y = WALL_HEIGHT
			var model := torch.get_node("Model") as MeshInstance3D
			model.mesh = BRAZIER
			model.position = Vector3.ZERO
			model.scale = Vector3.ONE * BRAZIER_SCALE
			for part: String in ["Flame", "Light"]:
				torch.get_node(part).position = Vector3(0, BRAZIER_FLAME * BRAZIER_SCALE, 0)
			level.set_editable_instance(torch, true)
		elif path.ends_with("door.tscn"):
			node.set("depth", 0.0)
			for leaf: String in ["Leaf/LeafMesh", "Leaf/LeafBack"]:
				(node.get_node(leaf) as Node3D).scale = DOOR_LEAF_SCALE
			level.set_editable_instance(node, true)
		elif _stairs_kind(node) != "":
			(node.get_node("Visual") as Node3D).visible = false
			level.set_editable_instance(node, true)
		elif node is Camera3D and "cuts_south_wall" in node:
			node.set("offset", CAMERA_OFFSET)
			node.set("orthographic", true)
			node.set("ortho_size", ORTHO_SIZE)
			node.set("cuts_south_wall", false)
			node.set("wall_height", PILLAR_HEIGHT)
			node.set("mask_margin", MASK_MARGIN)


func _stairs_kind(node: Node) -> String:
	if node.scene_file_path.ends_with("stairs_down.tscn"):
		return "baja"
	if node.scene_file_path.ends_with("stairs.tscn"):
		return "sube"
	return ""


func _shapes(grid: GridMap) -> Dictionary:
	var lib := grid.mesh_library
	var stairs := {}
	for node: Node in grid.get_parent().get_children():
		if node is Node3D and _stairs_kind(node) != "":
			stairs[grid.local_to_map(grid.transform.affine_inverse() * (node as Node3D).position)] = _stairs_kind(node)
	var open := func(cell: Vector3i) -> bool:
		var item := grid.get_cell_item(cell)
		return item != GridMap.INVALID_CELL_ITEM and lib.get_item_name(item) not in WALLS and lib.get_item_name(item) != DOOR and not stairs.has(cell)
	var out := {}
	for cell in grid.get_used_cells():
		var item_name := lib.get_item_name(grid.get_cell_item(cell))
		if item_name not in WALLS and item_name != DOOR and not stairs.has(cell):
			continue
		var code := ""
		for side: String in SIDES:
			if open.call(cell + SIDES[side]):
				code += side
		var corners := ""
		for corner: String in CORNERS:
			if not code.contains(corner[0]) and not code.contains(corner[1]) and open.call(cell + SIDES[corner[0]] + SIDES[corner[1]]):
				corners += "_" + corner
		if item_name in WALLS and code.length() == 1:
			for side: String in SIDES:
				var beside := grid.get_cell_item(cell + SIDES[side])
				if not code.contains(side) and SIDES[side] != -SIDES[code] and beside != GridMap.INVALID_CELL_ITEM and lib.get_item_name(beside) == DOOR:
					corners += "_p" + side
		var kind: String = "pared" if item_name in WALLS else stairs.get(cell, "paso")
		out[cell] = [kind, (code if code else "x") + corners]
	return out


func _kit() -> MeshLibrary:
	var kit: MeshLibrary = (load(KIT) as MeshLibrary).duplicate(true)
	var next := kit.get_last_unused_item_id()
	var shapes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHAPES))
	for kind: String in KINDS:
		var source := kit.find_item_by_name(KINDS[kind][1])
		for code: String in shapes[kind]:
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			var mesh: Mesh = load(MESHES % [kind, code])
			for surface in mesh.get_surface_count():
				tool.append_from(mesh, surface, Transform3D.IDENTITY)
			tool.set_material(STONE)
			kit.create_item(next)
			kit.set_item_name(next, KINDS[kind][0] + code)
			kit.set_item_mesh(next, tool.commit())
			kit.set_item_shapes(next, kit.get_item_shapes(source))
			kit.set_item_navigation_mesh(next, kit.get_item_navigation_mesh(source))
			next += 1
	var uid := ResourceLoader.get_resource_uid(OUT_KIT) if ResourceLoader.exists(OUT_KIT) else ResourceUID.INVALID_ID
	ResourceSaver.save(kit, OUT_KIT)
	if uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(OUT_KIT, uid)
	return load(OUT_KIT)


## Duplica cada línea de pared entre salas (y la del borde), para que cada sala tenga su propia pared de 2 m: corre las celdas
## y los nodos. Lo que está sobre una línea (puertas) queda en el medio de la pared doble; las escaleras, del lado de su sala.
func _spread(level: Node) -> void:
	var covered := [{}, {}]
	for room: Node in level.find_children("*", "Area3D", true, false):
		var shape := room.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
		if not "map_cell" in room or shape == null or not shape.shape is BoxShape3D:
			continue
		var size := (shape.shape as BoxShape3D).size
		var center: Vector3 = (room as Node3D).position + shape.position
		for axis in 2:
			var c := center.x if axis == 0 else center.z
			var half := (size.x if axis == 0 else size.z) / 2.0
			for cell in range(ceili((c - half + 1.0) / 2.0 - 0.01), floori((c + half - 1.0) / 2.0 + 0.01) + 1):
				covered[axis][cell] = true
	var grids := level.find_children("*", "GridMap", true, false)
	var low := Vector2i(1 << 20, 1 << 20)
	var high := -low
	for grid: GridMap in grids:
		for cell in grid.get_used_cells():
			low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.z))
			high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.z))
	var seps := [[], []]
	for axis in 2:
		for cell in range(low[axis], high[axis] + 1):
			if not covered[axis].has(cell):
				seps[axis].append(cell)
	for grid: GridMap in grids:
		var old := {}
		for cell in grid.get_used_cells():
			old[cell] = [grid.get_cell_item(cell), grid.get_cell_item_orientation(cell)]
		grid.clear()
		for cell: Vector3i in old:
			for x in _copies(seps[0], cell.x):
				for z in _copies(seps[1], cell.z):
					grid.set_cell_item(Vector3i(x, cell.y, z), old[cell][0], old[cell][1])
	for floor_node: Node in level.get_children():
		for node: Node in floor_node.get_children() if floor_node.get_children().any(func(n: Node) -> bool: return n is GridMap) else []:
			if node is GridMap or not node is Node3D:
				continue
			var spot := node as Node3D
			var facing := spot.transform.basis.z
			var stairs := _stairs_kind(node) != ""
			spot.position.x = 2.0 * _shift(seps[0], spot.position.x / 2.0, facing.x if stairs else 0.0)
			spot.position.z = 2.0 * _shift(seps[1], spot.position.z / 2.0, facing.z if stairs else 0.0)
			if stairs:
				var grid := floor_node.find_children("*", "GridMap", false, false)[0] as GridMap
				var cell := grid.local_to_map(spot.position)
				grid.set_cell_item(cell - Vector3i(roundi(facing.x), 0, roundi(facing.z)), grid.mesh_library.find_item_by_name(WALLS[0]))


func _copies(seps: Array, cell: int) -> Array:
	var at := cell + seps.filter(func(s: int) -> bool: return s < cell).size()
	return [at, at + 1] if cell in seps else [at]


## Coordenada (en celdas) corrida. Sobre una línea de pared: al medio de la doble, o, con `toward`, a la copia de ese lado.
func _shift(seps: Array, u: float, toward: float) -> float:
	for s: int in seps:
		if absf(u - s) < 0.3:
			var base := s + seps.filter(func(t: int) -> bool: return t < s).size()
			if absf(toward) > 0.5:
				return base + (1.0 if toward > 0.0 else 0.0)
			return base + 0.5
	return u + seps.filter(func(t: int) -> bool: return t < u).size()
