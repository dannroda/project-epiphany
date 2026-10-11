extends SceneTree
## Pone en levels/temple.tscn la pieza de hueco que corresponde a cada celda (pared de piedra hacia donde no sigue el hueco)
## y reparte nichos y ojos tallados en las paredes que miran a la cámara, lejos de lo que ya cuelga o está delante.
## godot --headless --path . --script res://tools/vary_temple.gd

const LEVEL := "res://levels/temple.tscn"
const Pieces := preload("res://tools/grid_pieces.gd")
const PIT := 10
## Hueco según los lados que dan a algo que no es hueco (sin girar, en el orden de Pieces.SIDES).
const PIT_PIECES := {
	"Hueco borde": [true, false, false, false],
	"Hueco esquina": [true, true, false, false],
	"Hueco pasillo": [true, false, true, false],
	"Hueco punta": [true, true, true, false],
	"Hueco pozo": [true, true, true, true],
}

const WALL := 1
const FLOORS := ["Piso", "Piso roto", "Piso grieta", "Piso musgo", "Piso arena"]
## Variantes de la pared con piso al sur → probabilidad acumulada (con un hash de la celda); el resto queda lisa.
const WALL_RULES := [["Pared nicho", 0.14], ["Pared ojo", 0.2]]
## Metros (en planta) desde el frente de la pared en los que algo de la escena la deja lisa.
const CLEAR := 1.6


func _initialize() -> void:
	var root := (load(LEVEL) as PackedScene).instantiate()
	var grid := root.get_node("GridMap") as GridMap
	var ids := Pieces.ids_by_name(grid.mesh_library)
	var pits := Pieces.pits(grid, ids, PIT, PIT_PIECES)
	for cell: Vector3i in pits:
		grid.set_cell_item(cell, pits[cell][0], Pieces.turn(grid, pits[cell][1]))
	var walls := _walls(root, grid, ids)
	for cell: Vector3i in walls:
		grid.set_cell_item(cell, walls[cell], 0)
	var err := Pieces.save_cells(LEVEL, grid)
	print("vary_temple: ", error_string(err), " · ", pits.size(), " huecos, ", walls.values().filter(func(id: int) -> bool: return id != WALL).size(), " paredes con nicho u ojo")
	root.free()
	quit(0 if err == OK else 1)


## Cada pared (lisa o variante) con piso al sur → su variante o la lisa.
func _walls(root: Node, grid: GridMap, ids: Dictionary) -> Dictionary:
	var family := [WALL]
	for rule: Array in WALL_RULES:
		family.append(ids[rule[0]])
	var floors := FLOORS.map(func(item_name: String) -> int: return ids[item_name])
	var taken := _decor(root, grid)
	var result := {}
	for cell in grid.get_used_cells():
		if not grid.get_cell_item(cell) in family or not grid.get_cell_item(cell + Vector3i(0, 0, 1)) in floors:
			continue
		var center := grid.map_to_local(cell)
		var front := Vector2(center.x, center.z + grid.cell_size.z * 0.5)
		var target := WALL
		if not taken.any(func(point: Vector2) -> bool: return point.distance_to(front) < CLEAR):
			var roll := float(absi(hash(cell + Vector3i(5, 0, 17))) % 10000) / 10000.0
			for rule: Array in WALL_RULES:
				if roll < rule[1]:
					target = ids[rule[0]]
					break
		result[cell] = target
	return result


## Dónde hay algo de la escena (en planta, coordenadas del GridMap): todo lo visible menos la grilla.
func _decor(root: Node, grid: GridMap) -> Array:
	var points := []
	for node in root.find_children("*", "VisualInstance3D", true, false):
		if node != grid and node is Node3D:
			var p := _global(node as Node3D, root)
			points.append(Vector2(p.x, p.z))
	return points


func _global(node: Node3D, root: Node) -> Vector3:
	var xform := node.transform
	var parent := node.get_parent()
	while parent != root and parent is Node3D:
		xform = (parent as Node3D).transform * xform
		parent = parent.get_parent()
	return xform.origin
