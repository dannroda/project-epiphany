@tool
class_name WallTops
extends RefCounted
## Navmesh (11.9): lo de un GridMap más alto que un agente (paredes, columnas, acantilados) no deja islas arriba. Cada
## celda así suma al horneado una obstrucción proyectada en la franja de su techo. Lo registran el plugin
## epiphany_tools (Bake del editor) y tools/bake_overworld_nav.gd.

const BAND := 0.3

static var _parser: RID


static func register() -> void:
	if _parser.is_valid():
		return
	_parser = NavigationServer3D.source_geometry_parser_create()
	NavigationServer3D.source_geometry_parser_set_callback(_parser, _parse)


static func unregister() -> void:
	if _parser.is_valid():
		NavigationServer3D.free_rid(_parser)
		_parser = RID()


static func _parse(navmesh: NavigationMesh, data: NavigationMeshSourceGeometryData3D, node: Node) -> void:
	var grid := node as GridMap
	if grid == null or grid.mesh_library == null:
		return
	var tall := _tall_boxes(grid.mesh_library, navmesh.agent_height)
	for cell in grid.get_used_cells():
		var item := grid.get_cell_item(cell)
		if not tall.has(item):
			continue
		var cell_xf := grid.global_transform * Transform3D(grid.get_basis_with_orthogonal_index(grid.get_cell_item_orientation(cell)), grid.map_to_local(cell))
		for box: AABB in tall[item]:
			var top := cell_xf * box
			var outline := PackedVector3Array([
				Vector3(top.position.x, 0, top.position.z), Vector3(top.end.x, 0, top.position.z),
				Vector3(top.end.x, 0, top.end.z), Vector3(top.position.x, 0, top.end.z)])
			data.add_projected_obstruction(outline, top.end.y - BAND, BAND * 2.0, false)


## Por ítem, las cajas de colisión que se alzan más que un agente sobre el fondo del ítem.
static func _tall_boxes(library: MeshLibrary, height: float) -> Dictionary:
	var found := {}
	for item in library.get_item_list():
		var shapes := library.get_item_shapes(item)
		var boxes: Array[AABB] = []
		var bottom := INF
		for i in range(0, shapes.size(), 2):
			var box := shapes[i] as BoxShape3D
			if box == null:
				continue
			var aabb := (shapes[i + 1] as Transform3D) * AABB(-box.size / 2.0, box.size)
			bottom = minf(bottom, aabb.position.y)
			boxes.append(aabb)
		boxes = boxes.filter(func(aabb: AABB) -> bool: return aabb.end.y - bottom >= height)
		if not boxes.is_empty():
			found[item] = boxes
	return found
