extends RefCounted
## Lo que leen del nivel la pestaña Mapa y el minimapa: sala actual, puertas, cofres y la distancia entre salas.

## Puertas del kit sin nodo Door (pasos libres entre salas); con paredes LA, las piezas de corte (una por sala, juntas).
const DOORWAY_ITEM := "Puerta"
const DOORWAY_LA_PREFIX := "Paso LA "
const DOOR_MERGE_DISTANCE := 2.5


static func current_room(tree: SceneTree) -> Room:
	var camera := tree.get_first_node_in_group(&"room_camera") as TopDownCamera
	return camera.room if camera else null


static func find(tree: SceneTree, type: Variant) -> Node:
	var scene := tree.current_scene
	if scene == null:
		return null
	for child in scene.get_children():
		if is_instance_of(child, type):
			return child
	return null


static func chests_in(tree: SceneTree, room: Room) -> Array:
	return tree.get_nodes_in_group(&"chests").filter(func(chest: Chest) -> bool: return room.contains(chest.global_position))


## Puertas con nodo Door (con llave, jefe, persianas, interruptor), escaleras y pasos libres del kit: [[posición, MapMark.Kind], …].
static func doors(tree: SceneTree) -> Array:
	var found: Array = []
	if tree.current_scene == null:
		return found
	for door: Door in tree.current_scene.find_children("*", "Door", true, false):
		found.append([door.global_position, door_kind(door)])
	for stairs: Stairs in tree.current_scene.find_children("*", "Stairs", true, false):
		found.append([stairs.global_position, MapMark.Kind.DOOR_OPEN])
	for grid: GridMap in tree.current_scene.find_children("*", "GridMap", true, false):
		if grid.mesh_library == null:
			continue
		for cell in grid.get_used_cells():
			var item_name := grid.mesh_library.get_item_name(grid.get_cell_item(cell))
			if item_name != DOORWAY_ITEM and not item_name.begins_with(DOORWAY_LA_PREFIX):
				continue
			var point := grid.to_global(grid.map_to_local(cell))
			if found.any(func(other: Array) -> bool: return (other[0] as Vector3).distance_to(point) < DOOR_MERGE_DISTANCE):
				continue
			found.append([point, MapMark.Kind.DOOR_OPEN])
	return found


static func door_kind(door: Door) -> MapMark.Kind:
	if door.is_open:
		return MapMark.Kind.DOOR_OPEN
	match door.kind:
		Door.Kind.LOCKED:
			return MapMark.Kind.DOOR_LOCKED
		Door.Kind.BOSS:
			return MapMark.Kind.DOOR_BOSS
		Door.Kind.SHUTTER, Door.Kind.SWITCH:
			return MapMark.Kind.DOOR_SEALED
	return MapMark.Kind.DOOR_OPEN


## Las salas de un piso (en una mazmorra de un solo piso, todas).
static func rooms_on(tree: SceneTree, level: int) -> Array:
	return tree.get_nodes_in_group(Room.GROUP).filter(func(room: Room) -> bool: return room.floor_level() == level)


## Si un punto (una puerta) está en el borde de la sala, en su piso.
static func near_room(room: Room, point: Vector3) -> bool:
	return room.bounds().grow(2.0).has_point(Vector2(point.x, point.z)) and absf(point.y - room.floor_y()) < 3.0


## Distancia en el mundo entre centros de salas vecinas (la sala más la pared compartida).
static func room_pitch(tree: SceneTree, fallback: Vector2) -> Vector2:
	var rooms := tree.get_nodes_in_group(Room.GROUP)
	var pitch := fallback
	for a: Room in rooms:
		for b: Room in rooms:
			var cells_apart := b.map_cell - a.map_cell
			var apart := b.bounds().get_center() - a.bounds().get_center()
			if cells_apart.x != 0 and cells_apart.y == 0:
				pitch.x = absf(apart.x / cells_apart.x)
			elif cells_apart.y != 0 and cells_apart.x == 0:
				pitch.y = absf(apart.y / cells_apart.y)
	return pitch


## Un punto del mundo en la grilla de salas: celda (fraccionaria) usando la sala `near` como referencia.
static func room_grid_point(tree: SceneTree, point: Vector3, near: Room) -> Vector2:
	var bounds := near.bounds()
	return Vector2(near.map_cell) + (Vector2(point.x, point.z) - bounds.get_center()) / room_pitch(tree, bounds.size)
