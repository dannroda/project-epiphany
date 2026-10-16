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
var boss_key_pieces: int = 0:
	set(value):
		boss_key_pieces = value
		changed.emit()
var visited_rooms: int = 0: ## Bitmask: bit N = sala con room_index N
	set(value):
		visited_rooms = value
		changed.emit()


func write_to(cfg: ConfigFile, section: String) -> void:
	cfg.set_value(section, SaveKeys.SMALL_KEYS, small_keys)
	cfg.set_value(section, SaveKeys.HAS_MAP, has_map)
	cfg.set_value(section, SaveKeys.HAS_COMPASS, has_compass)
	cfg.set_value(section, SaveKeys.HAS_BOSS_KEY, has_boss_key)
	if boss_key_pieces > 0:
		cfg.set_value(section, SaveKeys.BOSS_KEY_PIECES, boss_key_pieces)
	cfg.set_value(section, SaveKeys.VISITED_ROOMS, visited_rooms)


static func read_from(cfg: ConfigFile, section: String) -> DungeonState:
	var dungeon := DungeonState.new()
	dungeon.small_keys = SaveCodec.typed(cfg, section, SaveKeys.SMALL_KEYS, 0)
	dungeon.has_map = SaveCodec.typed(cfg, section, SaveKeys.HAS_MAP, false)
	dungeon.has_compass = SaveCodec.typed(cfg, section, SaveKeys.HAS_COMPASS, false)
	dungeon.has_boss_key = SaveCodec.typed(cfg, section, SaveKeys.HAS_BOSS_KEY, false)
	dungeon.boss_key_pieces = SaveCodec.typed(cfg, section, SaveKeys.BOSS_KEY_PIECES, 0)
	dungeon.visited_rooms = SaveCodec.typed(cfg, section, SaveKeys.VISITED_ROOMS, 0)
	return dungeon


func visit(room_index: int) -> void:
	visited_rooms |= 1 << room_index


func was_visited(room_index: int) -> bool:
	return (visited_rooms & (1 << room_index)) != 0
