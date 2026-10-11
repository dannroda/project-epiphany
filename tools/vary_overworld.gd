extends SceneTree
## Pasa levels/overworld.tscn al kit propio y reparte variantes de pasto, tierra, andenes, pircas y árboles
## con un hash de la celda (siempre da lo mismo). Sólo toca celdas que todavía tienen el ítem base.
## godot --headless --path . --script res://tools/vary_overworld.gd

const LEVEL := "res://levels/overworld.tscn"
const KIT := preload("res://data/kits/overworld_kit.tres")

## id base → [[variante, probabilidad acumulada], …]; lo que sobra queda como el base.
const RULES := {
	0: [["Tierra piedras", 0.12]],
	5: [["Pasto flores", 0.12], ["Pasto piedras", 0.2], ["Pasto ichu", 0.3], ["Pasto tola", 0.34]],
	6: [["Risco", 0.3]],
	8: [["Queñoa chica", 0.3], ["Cardón", 0.42], ["Cardón brazos", 0.5]],
}
## Los que pueden girar sin que se note la costura.
const SPIN := [5, 0]
const DIRT := 0
const GRASS := 5
## Lado con tierra de las piezas de borde sin girar; cada giro de 90° lo pasa al siguiente.
const SIDES: Array[Vector3i] = [Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(0, 0, -1)]
## Abismo según los lados que dan a algo que no es abismo (sin girar, en el orden de SIDES).
const ABYSS := 9
const PIT := 10
const ABYSS_PIECES := {
	"Abismo borde": [true, false, false, false],
	"Abismo esquina": [true, true, false, false],
	"Abismo pasillo": [true, false, true, false],
	"Abismo punta": [true, true, true, false],
	"Abismo pozo": [true, true, true, true],
}
## Pirca según los lados donde sigue otra pirca; con tres o cuatro queda recta.
const FENCE := 7
const FENCE_PIECES := {
	"Cerco": [true, false, true, false],
	"Pirca esquina": [false, false, true, true],
	"Pirca final": [true, false, false, false],
	"Pirca poste": [false, false, false, false],
}
const BROKEN_FENCE := 0.3
## Borde del mundo: celdas de meseta alrededor del mapa, hasta donde llega a ver la cámara (oeste, norte, este, sur).
const OUTSIDE_MARGIN := [9, 6, 9, 3]
const OUTSIDE := [["Monte queñoa", 0.14], ["Monte queñoa chica", 0.24], ["Monte cardón", 0.3], ["Monte ichu", 0.5], ["Monte piedras", 0.6], ["Monte flores", 0.68], ["Monte", 1.0]]
## Del lado de la cámara (al sur del mapa) un árbol taparía al player: ahí solo meseta baja.
const OUTSIDE_SOUTH := [["Monte ichu", 0.3], ["Monte piedras", 0.45], ["Monte flores", 0.55], ["Monte", 1.0]]


func _initialize() -> void:
	var root := (load(LEVEL) as PackedScene).instantiate()
	var grid := root.get_node("GridMap") as GridMap
	grid.mesh_library = KIT
	var ids := {}
	for id in KIT.get_item_list():
		ids[KIT.get_item_name(id)] = id
	var changed := 0
	var borders := _borders(grid, ids)
	borders.merge(_abyss(grid, ids))
	borders.merge(_fences(grid, ids))
	borders.merge(_outside(grid, ids))
	for cell: Vector3i in borders:
		grid.set_cell_item(cell, borders[cell][0], _turn(grid, borders[cell][1]))
		changed += 1
	for cell in grid.get_used_cells():
		var item := grid.get_cell_item(cell)
		if not RULES.has(item) or borders.has(cell):
			continue
		var roll := _hash(cell / 3 if item == 6 else cell)
		var orientation := grid.get_cell_item_orientation(cell)
		if item in SPIN:
			orientation = _turn(grid, _hash(cell + Vector3i(7, 0, 3)) * 4.0 as int)
		var target := item
		for rule: Array in RULES[item]:
			if roll < rule[1]:
				target = ids[rule[0]]
				break
		if target != item or orientation != grid.get_cell_item_orientation(cell):
			grid.set_cell_item(cell, target, orientation)
			changed += 1
	var text := FileAccess.get_file_as_string(LEVEL)
	var cells := var_to_str(grid.get("data")["cells"])
	text = RegEx.create_from_string('"cells": PackedInt32Array\\([^)]*\\)').sub(text, '"cells": ' + cells)
	text = text.replace('path="res://data/kits/gray_kit.tres"', 'path="%s"' % KIT.resource_path)
	text = text.replace('uid="uid://cgeqghyjch420" path="%s"' % KIT.resource_path, 'path="%s"' % KIT.resource_path)
	var file := FileAccess.open(LEVEL, FileAccess.WRITE)
	file.store_string(text)
	var err := file.get_error()
	file.close()
	print("vary_overworld: ", error_string(err), " · ", changed, " celdas")
	root.free()
	quit(0 if err == OK else 1)


## Pasto pegado a tierra → pieza de borde (o esquina) girada hacia la tierra. Se calcula antes de tocar nada.
func _borders(grid: GridMap, ids: Dictionary) -> Dictionary:
	var result := {}
	for cell in grid.get_used_cells_by_item(GRASS):
		var dirt := []
		for k in 4:
			dirt.append(grid.get_cell_item(cell + SIDES[k]) == DIRT)
		var count := dirt.count(true)
		for k in 4:
			var next := (k + 1) % 4
			if count == 1 and dirt[k]:
				result[cell] = [ids["Tierra borde"], k]
			elif count == 2 and dirt[k] and dirt[next]:
				result[cell] = [ids["Tierra esquina int"], k]
			elif count == 0 and grid.get_cell_item(cell + SIDES[k] + SIDES[next]) == DIRT:
				result[cell] = [ids["Tierra esquina"], k]
	return result


## Cada celda de abismo (base o variante; los huecos no, que no tienen colisión) → la pieza con pared hacia donde no sigue el abismo.
func _abyss(grid: GridMap, ids: Dictionary) -> Dictionary:
	var abyss := _ids(ids, [ABYSS], ABYSS_PIECES)
	var result := {}
	for cell in grid.get_used_cells():
		if grid.get_cell_item(cell) in abyss:
			var walls := _sides(grid, cell, abyss + [PIT]).map(func(open: bool) -> bool: return not open)
			result[cell] = _match(ids, ABYSS_PIECES, walls, [ABYSS, 0])
	return result


## Cada pirca → recta, esquina, final o poste según dónde sigue la pirca; las rectas salen rotas a veces.
func _fences(grid: GridMap, ids: Dictionary) -> Dictionary:
	var fences := _ids(ids, [FENCE, ids["Pirca rota"]], FENCE_PIECES)
	var result := {}
	for cell in grid.get_used_cells():
		if grid.get_cell_item(cell) in fences:
			var fallback := [FENCE, 0 if grid.get_cell_item_orientation(cell) == 0 else 1]
			var choice: Array = _match(ids, FENCE_PIECES, _sides(grid, cell, fences), fallback)
			if choice[0] == FENCE and _hash(cell) < BROKEN_FENCE:
				choice[0] = ids["Pirca rota"]
			result[cell] = choice
	return result


## Cada celda vacía (o ya de meseta) del rectángulo del mapa agrandado por OUTSIDE_MARGIN → una meseta al azar.
func _outside(grid: GridMap, ids: Dictionary) -> Dictionary:
	var outside := []
	for entry: Array in OUTSIDE:
		outside.append(ids[entry[0]])
	var low := Vector2i(1 << 20, 1 << 20)
	var high := -low
	for cell in grid.get_used_cells():
		if cell.y == 0 and not grid.get_cell_item(cell) in outside:
			low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.z))
			high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.z))
	var result := {}
	for x in range(low.x - OUTSIDE_MARGIN[0], high.x + OUTSIDE_MARGIN[2] + 1):
		for z in range(low.y - OUTSIDE_MARGIN[1], high.y + OUTSIDE_MARGIN[3] + 1):
			var cell := Vector3i(x, 0, z)
			var item := grid.get_cell_item(cell)
			if item != GridMap.INVALID_CELL_ITEM and not item in outside:
				continue
			var roll := _hash(cell + Vector3i(11, 0, 5))
			for entry: Array in OUTSIDE_SOUTH if z > high.y else OUTSIDE:
				if roll < entry[1]:
					result[cell] = [ids[entry[0]], _hash(cell + Vector3i(3, 0, 9)) * 4.0 as int]
					break
	return result


func _ids(ids: Dictionary, base: Array, pieces: Dictionary) -> Array:
	var result := base.duplicate()
	for piece: String in pieces:
		result.append(ids[piece])
	return result


func _sides(grid: GridMap, cell: Vector3i, items: Array) -> Array:
	var result := []
	for k in 4:
		result.append(grid.get_cell_item(cell + SIDES[k]) in items)
	return result


## La pieza (y cuántos cuartos de giro) cuyo patrón de lados, girado, es sides.
func _match(ids: Dictionary, pieces: Dictionary, sides: Array, fallback: Array) -> Array:
	for piece: String in pieces:
		for turn in 4:
			var turned := []
			for k in 4:
				turned.append(pieces[piece][(k - turn + 4) % 4])
			if turned == sides:
				return [ids[piece], turn]
	return fallback


func _turn(grid: GridMap, quarters: int) -> int:
	return grid.get_orthogonal_index_from_basis(Basis(Vector3.UP, PI / 2.0 * quarters))


func _hash(cell: Vector3i) -> float:
	return float(absi(hash(cell)) % 10000) / 10000.0
