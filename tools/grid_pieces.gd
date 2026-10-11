extends RefCounted
## Elección de piezas por vecinos para los vary_*.gd: un patrón de cuatro lados (en el orden de SIDES) por pieza,
## y se busca la pieza y el giro que coinciden con lo que rodea a la celda.

## Cada giro de 90° pasa un lado al siguiente.
const SIDES: Array[Vector3i] = [Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(0, 0, -1)]


static func ids_by_name(library: MeshLibrary) -> Dictionary:
	var ids := {}
	for id in library.get_item_list():
		ids[library.get_item_name(id)] = id
	return ids


## Los ids base más los de las piezas de pieces.
static func family(ids: Dictionary, base: Array, pieces: Dictionary) -> Array:
	var result := base.duplicate()
	for piece: String in pieces:
		result.append(ids[piece])
	return result


## Por cada lado, si el vecino es uno de items.
static func sides(grid: GridMap, cell: Vector3i, items: Array) -> Array:
	var result := []
	for k in 4:
		result.append(grid.get_cell_item(cell + SIDES[k]) in items)
	return result


## [id, cuartos de giro] de la pieza cuyo patrón, girado, es pattern; si ninguna, fallback.
static func match(ids: Dictionary, pieces: Dictionary, pattern: Array, fallback: Array) -> Array:
	for piece: String in pieces:
		for turn in 4:
			var turned := []
			for k in 4:
				turned.append(pieces[piece][(k - turn + 4) % 4])
			if turned == pattern:
				return [ids[piece], turn]
	return fallback


## Cada celda de la familia del pozo → la pieza con pared hacia donde no sigue el pozo (open: lo que cuenta como pozo
## de vecino además de la familia).
static func pits(grid: GridMap, ids: Dictionary, base: int, pieces: Dictionary, open: Array = []) -> Dictionary:
	var pit := family(ids, [base], pieces)
	var result := {}
	for cell in grid.get_used_cells():
		if grid.get_cell_item(cell) in pit:
			var walls := sides(grid, cell, pit + open).map(func(inside: bool) -> bool: return not inside)
			result[cell] = match(ids, pieces, walls, [base, 0])
	return result


static func turn(grid: GridMap, quarters: int) -> int:
	return grid.get_orthogonal_index_from_basis(Basis(Vector3.UP, PI / 2.0 * quarters))


## Reescribe las celdas del GridMap en el .tscn sin tocar el resto del archivo.
static func save_cells(level: String, grid: GridMap, replacements: Dictionary = {}) -> Error:
	var text := FileAccess.get_file_as_string(level)
	var cells := var_to_str(grid.get("data")["cells"])
	text = RegEx.create_from_string('"cells": PackedInt32Array\\([^)]*\\)').sub(text, '"cells": ' + cells)
	for old: String in replacements:
		text = text.replace(old, replacements[old])
	var file := FileAccess.open(level, FileAccess.WRITE)
	file.store_string(text)
	var err := file.get_error()
	file.close()
	return err
