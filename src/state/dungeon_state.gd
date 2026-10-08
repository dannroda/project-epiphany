class_name DungeonState
extends RefCounted

var small_keys: int = 0
var has_map := false
var has_compass := false
var has_boss_key := false
var visited_rooms: int = 0 ## Bitmask: bit N = sala con room_index N


func visit(room_index: int) -> void:
	visited_rooms |= 1 << room_index


func was_visited(room_index: int) -> bool:
	return (visited_rooms & (1 << room_index)) != 0
