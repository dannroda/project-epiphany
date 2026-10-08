class_name DungeonState
extends RefCounted

## Cualquier cambio (llaves, mapa, brújula, salas): lo escucha el HUD.
signal changed

var small_keys: int = 0:
	set(value):
		small_keys = value
		changed.emit()
var has_map := false:
	set(value):
		has_map = value
		changed.emit()
var has_compass := false:
	set(value):
		has_compass = value
		changed.emit()
var has_boss_key := false:
	set(value):
		has_boss_key = value
		changed.emit()
var visited_rooms: int = 0: ## Bitmask: bit N = sala con room_index N
	set(value):
		visited_rooms = value
		changed.emit()


func visit(room_index: int) -> void:
	visited_rooms |= 1 << room_index


func was_visited(room_index: int) -> bool:
	return (visited_rooms & (1 << room_index)) != 0
