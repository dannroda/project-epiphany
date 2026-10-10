class_name OverworldMap
extends Node
## Va en las escenas del overworld: el mapa simple de la zona (imagen fija) y qué rectángulo del mundo (XZ) cubre.

@export var display_name: String = ""
@export var texture: Texture2D
@export var world_rect := Rect2(-20, -20, 40, 40)
## Sus paredes se recortan alrededor del player (player_hole), salvo en el borde del mundo: ahí el agujero
## mostraría el vacío, así que se cambian por su variante "borde" y queda la silueta.
@export var grid: GridMap


func _ready() -> void:
	if grid:
		use_edge_walls(grid)


static func use_edge_walls(map: GridMap) -> void:
	var library := map.mesh_library
	var edge_of := {}
	for id in library.get_item_list():
		var edge := library.find_item_by_name(library.get_item_name(id) + " borde")
		if edge >= 0:
			edge_of[id] = edge
	edge_of[library.find_item_by_name("Acantilado")] = library.find_item_by_name("Andén borde")
	for cell in map.get_used_cells():
		var item := map.get_cell_item(cell)
		if edge_of.has(item) and edge_of[item] >= 0 and map.get_cell_item(cell + Vector3i(0, 0, 1)) == GridMap.INVALID_CELL_ITEM:
			map.set_cell_item(cell, edge_of[item], map.get_cell_item_orientation(cell))
