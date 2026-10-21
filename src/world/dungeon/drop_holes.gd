class_name DropHoles
## Qué huecos de una mazmorra llevan al piso de abajo (11.117): un hueco sin Pit debajo es una caída a otro piso; con Pit,
## es un foso. Sin dependencias de autoloads, para que lo usen también las herramientas (la_walls).

const PIT_SCRIPT := "res://src/world/dungeon/pit.gd"
const FLOOR_SCRIPT := "res://src/world/dungeon/dungeon_floor.gd"
const HOLE_PREFIX := "Hueco"
const PIT_DEPTH := 1.2


## Celdas (posición en el mundo, a la altura del piso) de los huecos de `floor` que caen al piso de abajo.
static func of_floor(level_root: Node, floor: Node3D) -> Array[Vector3]:
	var pits := _pits(level_root)
	var drops: Array[Vector3] = []
	for map: GridMap in floor.find_children("*", "GridMap", true, false):
		for at in holes(map):
			if not pits.any(func(pit: Array) -> bool: return _inside(pit, at - Vector3.UP * PIT_DEPTH)):
				drops.append(at)
	return drops


## Todas las celdas de hueco de un GridMap, en el mundo.
static func holes(map: GridMap) -> Array[Vector3]:
	var xf := transform_of(map)
	var cells: Array[Vector3] = []
	for cell: Vector3i in map.get_used_cells():
		var item := map.get_cell_item(cell)
		if map.mesh_library and map.mesh_library.get_item_name(item).begins_with(HOLE_PREFIX):
			var at := xf * map.map_to_local(cell)
			cells.append(Vector3(at.x, xf.origin.y, at.z))
	return cells


static func floors(level_root: Node) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for node in level_root.find_children("*", "Node3D", true, false):
		var script: Script = node.get_script()
		if script and script.resource_path == FLOOR_SCRIPT:
			found.append(node)
	return found


## Funciona también con la escena instanciada fuera del árbol.
static func transform_of(node: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	while node:
		if node is Node3D:
			xf = (node as Node3D).transform * xf
		node = node.get_parent()
	return xf


static func _pits(level_root: Node) -> Array:
	var boxes := []
	for area in level_root.find_children("*", "Area3D", true, false):
		var script: Script = area.get_script()
		if not script or script.resource_path != PIT_SCRIPT:
			continue
		for shape in area.find_children("*", "CollisionShape3D", false, false):
			if shape.shape is BoxShape3D:
				boxes.append([transform_of(shape).affine_inverse(), (shape.shape as BoxShape3D).size / 2])
	return boxes


static func _inside(pit: Array, at: Vector3) -> bool:
	var local: Vector3 = pit[0] * at
	var half: Vector3 = pit[1]
	return absf(local.x) <= half.x and absf(local.y) <= half.y + 0.3 and absf(local.z) <= half.z
