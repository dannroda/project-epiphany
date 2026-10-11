extends SceneTree
## Pone en levels/temple.tscn la pieza de hueco que corresponde a cada celda: pared de piedra hacia donde no sigue el hueco.
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


func _initialize() -> void:
	var root := (load(LEVEL) as PackedScene).instantiate()
	var grid := root.get_node("GridMap") as GridMap
	var ids := Pieces.ids_by_name(grid.mesh_library)
	var pits := Pieces.pits(grid, ids, PIT, PIT_PIECES)
	for cell: Vector3i in pits:
		grid.set_cell_item(cell, pits[cell][0], Pieces.turn(grid, pits[cell][1]))
	var err := Pieces.save_cells(LEVEL, grid)
	print("vary_temple: ", error_string(err), " · ", pits.size(), " celdas")
	root.free()
	quit(0 if err == OK else 1)
