extends SceneTree
## Pasa el GridMap de levels/overworld.tscn a tools/terreno_overworld.json para build_terreno_organico.py: una letra por
## celda (H alto, ~ abismo, : tierra, . pasto), los puntos fijos (lo jugable y las piezas que quedan en el GridMap), donde
## el terreno no se mueve ni tiene lomas, la decoración, donde el piso queda plano y la roca no avanza, y las paredes
## rompibles, que se arman con la misma roca.
## godot --headless --path . --script res://tools/export_terreno_overworld.gd

const LEVEL := "res://levels/overworld.tscn"
const OUT := "res://tools/terreno_overworld.json"
const HIGH := ["Acantilado", "Risco", "Pared", "Andén", "Monte", "Cueva pared"]
const ABYSS := ["Abismo", "Hueco"]
const DIRT := ["Piso", "Tierra", "Lajas", "Cueva piso"]
const GRASS := ["Pasto"]
const IGNORED := ["GridMap", "WorldEnvironment", "DirectionalLight3D", "NavigationRegion3D", "Camera3D", "Decor", "Player", "HUD", "OverworldMap", "CloudShadows"]


func _initialize() -> void:
	var level: Node3D = (load(LEVEL) as PackedScene).instantiate()
	var grid: GridMap = level.get_node("GridMap")
	var lib := grid.mesh_library
	var cells := grid.get_used_cells()
	var lo := Vector2i(cells[0].x, cells[0].z)
	var hi := lo
	for cell in cells:
		lo = Vector2i(mini(lo.x, cell.x), mini(lo.y, cell.z))
		hi = Vector2i(maxi(hi.x, cell.x), maxi(hi.y, cell.z))
	var rows: Array[String] = []
	var fixed := []
	var decor := []
	var cracked := []
	for z in range(lo.y, hi.y + 1):
		var row := ""
		for x in range(lo.x, hi.x + 1):
			var id := grid.get_cell_item(Vector3i(x, 0, z))
			var item := lib.get_item_name(id) if id >= 0 else ""
			var letter := _letter(item)
			if letter == "":
				letter = _under(grid, Vector3i(x, 0, z))
				fixed.append([x * 2.0, z * 2.0, 1.4])
			row += letter
		rows.append(row)
	for child in level.get_children():
		if child is Node3D and not (child.get_class() in IGNORED or child.name in IGNORED) and not String(child.name).begins_with("Zone_"):
			var at := (child as Node3D).position
			fixed.append([at.x, at.z, 1.6])
			if child.scene_file_path.begins_with("res://src/world/cracked_wall"):
				var t := (child as Node3D).transform
				cracked.append({"name": String(child.name), "x": at.x, "z": at.z, "yaw": t.basis.get_euler().y})
			if "solved_position" in child:
				fixed.append([child.solved_position.x, child.solved_position.z, 1.6])
	for piece in level.get_node("Decor").find_children("*", "MeshInstance3D", true, false):
		var at := _placed(piece, level)
		decor.append([at.x, at.z, 0.8])
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"origin": [lo.x, lo.y], "cell": 2.0, "rows": rows, "fixed": fixed, "decor": decor, "cracked": cracked}, "\t"))
	print("export_terreno_overworld: %d × %d celdas, %d puntos fijos, %d de decoración" % [hi.x - lo.x + 1, hi.y - lo.y + 1, fixed.size(), decor.size()])
	level.free()
	quit()


func _placed(node: Node3D, level: Node3D) -> Vector3:
	var at := node.transform
	var parent := node.get_parent() as Node3D
	while parent != level:
		at = parent.transform * at
		parent = parent.get_parent() as Node3D
	return at.origin


## Piso de una pieza que queda en el GridMap: el que más tiene alrededor.
func _under(grid: GridMap, cell: Vector3i) -> String:
	var dirt := 0
	for side: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		var id := grid.get_cell_item(cell + side)
		if id >= 0 and _letter(grid.mesh_library.get_item_name(id)) == ":":
			dirt += 1
	return ":" if dirt >= 2 else "."


func _letter(item: String) -> String:
	for group: Array in [[HIGH, "H"], [ABYSS, "~"], [DIRT, ":"], [GRASS, "."]]:
		for prefix: String in group[0]:
			if item.begins_with(prefix):
				return group[1]
	return "." if item == "" else ""
