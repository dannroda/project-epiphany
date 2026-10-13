extends "res://tests/test_case.gd"
## Huecos a otro piso (11.117): cada hueco sin Pit cae sobre el piso de abajo (piso firme, o un foso como el del Mirador al
## Abismo), y los que hay son los del diseño. La Agrietada es el piso que rompe la momia.

const DESIGN := {
	"res://levels/chullpa.tscn": ["Agrietada", "Mirador", "SalaCofre", "Saltos"],
	"res://levels/quenoa.tscn": ["Arco", "Nido"],
	"res://levels/templo.tscn": [],
	"res://levels/totora.tscn": ["Tejedores"],
}


func test_every_drop_hole_lands_on_the_floor_below() -> void:
	for path: String in DESIGN:
		var level := (load(path) as PackedScene).instantiate()
		var floors := DropHoles.floors(level)
		floors.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.level > b.level)
		var rooms := {}
		for i in floors.size():
			for at in DropHoles.of_floor(level, floors[i]):
				var below := floors[i + 1] if i + 1 < floors.size() else null
				assert_true(below != null and _lands(below, at), "%s: el hueco %s cae sobre el piso de abajo" % [path.get_file(), at])
				rooms[_room(floors[i], at)] = true
		var found := rooms.keys()
		found.sort()
		var expected: Array = DESIGN[path].duplicate()
		expected.sort()
		assert_eq(found, expected, "%s: salas con huecos a otro piso" % path.get_file())
		level.free()


func _lands(floor: Node3D, at: Vector3) -> bool:
	for map: GridMap in floor.find_children("*", "GridMap", true, false):
		var cell := map.local_to_map(DropHoles.transform_of(map).affine_inverse() * Vector3(at.x, DropHoles.transform_of(map).origin.y, at.z))
		var item := map.get_cell_item(cell)
		if item != GridMap.INVALID_CELL_ITEM:
			return not map.mesh_library.get_item_name(item).begins_with("Pared")
	return false


func _room(floor: Node3D, at: Vector3) -> String:
	for room: Room in floor.find_children("*", "Room", true, false):
		for shape in room.find_children("*", "CollisionShape3D", false, false):
			var local := DropHoles.transform_of(shape).affine_inverse() * Vector3(at.x, DropHoles.transform_of(shape).origin.y, at.z)
			var half: Vector3 = (shape.shape as BoxShape3D).size / 2
			if absf(local.x) <= half.x and absf(local.z) <= half.z:
				return room.name
	return "?"
