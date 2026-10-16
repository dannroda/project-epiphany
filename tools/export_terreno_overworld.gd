extends SceneTree
## Pasa el GridMap de levels/overworld.tscn a tools/terreno_overworld.json para build_terreno_organico.py: por columna,
## su nivel (el y de su celda más alta: 0 a 2 se caminan, 3 es montaña) y una letra (H alto, ~ abismo, W agua honda,
## S escalinata, v salto, : tierra, . pasto, w agua baja: las celdas bajo un ShallowWater), los puntos fijos (lo jugable y las piezas que quedan en el GridMap), donde
## el terreno no se mueve ni tiene lomas, la decoración, donde el piso queda plano y la roca no avanza, y las paredes
## rompibles, que se arman con la misma roca.
## También las regiones: cada TerrainStyleArea de TerrainStyles. Para probar sin tocar la escena, los estilos se pueden
## pasar por nombre: … -- quebrada=necropolis risco=cumbre
## godot --headless --path . --script res://tools/export_terreno_overworld.gd

const LEVEL := "res://levels/overworld.tscn"
const OUT := "res://tools/terreno_overworld.json"
const HIGH := ["Acantilado", "Risco", "Pared", "Andén", "Monte", "Cueva pared"]
const ABYSS := ["Abismo"]
const DIRT := ["Piso", "Tierra", "Lajas", "Cueva piso"]
const GRASS := ["Pasto"]
## Escalinata (sube hacia el nivel de al lado), salto (borde de una vía, se baja hacia el sur) y agua honda.
const SPECIAL := {"Escalón": "S", "Andén borde": "v", "Hueco": "W"}
const MOUNTAIN := 3
## Las plantas de la grilla apenas aplanan el terreno: si no, una hilera de árboles deja el borde de la terraza en escalera.
const PLANTS := ["Árbol", "Queñoa chica", "Cardón", "Cardón brazos"]
const IGNORED := ["GridMap", "WorldEnvironment", "DirectionalLight3D", "NavigationRegion3D", "Camera3D", "Decor", "Player", "HUD", "OverworldMap", "TerrainStyles"]


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
	var levels: Array[String] = []
	var fixed := []
	var decor := []
	var cracked := []
	var mouths := []
	var posts := []
	var regions := []
	for z in range(lo.y, hi.y + 1):
		var row := ""
		var heights := ""
		for x in range(lo.x, hi.x + 1):
			var y := _top(grid, x, z)
			var id := grid.get_cell_item(Vector3i(x, y, z))
			var item := lib.get_item_name(id) if id >= 0 else ""
			var letter := _letter(item)
			if letter == "":
				letter = _under(grid, Vector3i(x, y, z))
				fixed.append([x * 2.0, z * 2.0, 0.4 if item in PLANTS else 1.4])
			row += letter
			heights += str(y)
		rows.append(row)
		levels.append(heights)
	for water in level.get_children():
		if not "wade_speed" in water:
			continue
		var rect := Rect2(Vector2(water.position.x, water.position.z) - water.size / 2.0, water.size)
		for r in rows.size():
			var row := rows[r]
			for c in row.length():
				if row[c] in ".:" and rect.has_point(Vector2((lo.x + c) * 2.0, (lo.y + r) * 2.0)):
					row = row.substr(0, c) + "w" + row.substr(c + 1)
			rows[r] = row
	var forced := {}
	for arg in OS.get_cmdline_user_args():
		forced[arg.get_slice("=", 0)] = arg.get_slice("=", 1)
	for area in level.get_node("TerrainStyles").get_children():
		var style := String(forced.get(String(area.name), area.style))
		if style.is_empty():
			continue
		var center: Vector3 = area.position
		var half: Vector2 = area.size / 2.0
		regions.append({"style": style, "rect": [center.x - half.x, center.z - half.y, center.x + half.x, center.z + half.y]})
	for child in level.get_children():
		if child is Node3D and not (child.get_class() in IGNORED or child.name in IGNORED) and not String(child.name).begins_with("Zone_") and not "wade_speed" in child:
			var at := (child as Node3D).position
			fixed.append([at.x, at.z, 1.6])
			if child.scene_file_path.begins_with("res://src/world/cracked_wall"):
				var t := (child as Node3D).transform
				cracked.append({"name": String(child.name), "x": at.x, "z": at.z, "yaw": t.basis.get_euler().y})
			if child.scene_file_path == "res://src/world/hook_post.tscn":
				posts.append([at.x, at.z])
			if String(child.name).ends_with("Mouth"):
				mouths.append({"name": String(child.name), "x": at.x, "y": at.y, "z": at.z, "yaw": (child as Node3D).transform.basis.get_euler().y})
			if "solved_position" in child:
				fixed.append([child.solved_position.x, child.solved_position.z, 1.6])
	var plants := level.get_node_or_null("Decor/Plantas")
	for piece in level.get_node("Decor").find_children("*", "MeshInstance3D", true, false):
		if plants and plants.is_ancestor_of(piece):
			continue
		var at := _placed(piece, level)
		decor.append([at.x, at.z, 0.8])
	var eyes := []
	for eye in level.find_children("*", "Node3D", true, false):
		if eye.scene_file_path == "res://src/world/eye_switch.tscn":
			var t := _xform(eye, level)
			eyes.append({"x": t.origin.x, "z": t.origin.z, "dx": -t.basis.z.x, "dz": -t.basis.z.z})
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"origin": [lo.x, lo.y], "cell": 2.0, "rows": rows, "levels": levels, "fixed": fixed, "decor": decor, "cracked": cracked, "mouths": mouths, "posts": posts, "eyes": eyes, "regions": regions}, "\t"))
	print("export_terreno_overworld: %d × %d celdas, %d puntos fijos, %d de decoración, %d regiones" % [hi.x - lo.x + 1, hi.y - lo.y + 1, fixed.size(), decor.size(), regions.size()])
	level.free()
	quit()


func _placed(node: Node3D, level: Node3D) -> Vector3:
	return _xform(node, level).origin


func _xform(node: Node3D, level: Node3D) -> Transform3D:
	var at := node.transform
	var parent := node.get_parent() as Node3D
	while parent != level:
		at = parent.transform * at
		parent = parent.get_parent() as Node3D
	return at


## Piso de una pieza que queda en el GridMap: el que más tiene alrededor.
func _under(grid: GridMap, cell: Vector3i) -> String:
	var dirt := 0
	for side: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		var id := grid.get_cell_item(cell + side)
		if id >= 0 and _letter(grid.mesh_library.get_item_name(id)) == ":":
			dirt += 1
	return ":" if dirt >= 2 else "."


## Nivel de la columna: el y de su celda más alta (el GridMap lleva un nivel de terraza por celda en y).
func _top(grid: GridMap, x: int, z: int) -> int:
	for y in range(MOUNTAIN, -1, -1):
		if grid.get_cell_item(Vector3i(x, y, z)) != GridMap.INVALID_CELL_ITEM:
			return y
	return MOUNTAIN


func _letter(item: String) -> String:
	if SPECIAL.has(item):
		return SPECIAL[item]
	for group: Array in [[HIGH, "H"], [ABYSS, "~"], [DIRT, ":"], [GRASS, "."]]:
		for prefix: String in group[0]:
			if item.begins_with(prefix):
				return group[1]
	return "." if item == "" else ""
