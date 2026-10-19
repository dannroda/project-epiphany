class_name SaveKeys
## Secciones y claves del save. Las usan GameState, SaveCodec, SaveManager y el Save Inspector: un nombre cambia acá.

const META := "meta"
const VERSION := "version"
const TIMESTAMP := "timestamp"
const CHECKSUM := "checksum"
const SLOT := "slot"

const PLAYER := "player"
const MAX_HEALTH := "max_health"
const HEALTH := "health"
const PLAY_TIME := "play_time"
const SPAWN_SCENE := "spawn_scene"
const SPAWN_UID := "spawn_uid"
const SPAWN_POINT := "spawn_point"
const CURRENT_DUNGEON := "current_dungeon"
const POSITION := "position"
const LOCATION := "location"

const INVENTORY := "inventory"
const BOTTLES := "bottles"
const EQUIPMENT := "equipment"
const BUTTONS := "buttons"
const FLAGS := "flags"

const MAP := "map"
const VISITED_ZONES := "visited_zones"
const PINS := "pins"
const REVEALED_SIZE := "revealed_size"
const REVEALED := "revealed"
const REVEALS := "reveals"

## Una sección por mazmorra: dungeon_<id>.
const DUNGEON_PREFIX := "dungeon_"
const SMALL_KEYS := "small_keys"
const HAS_MAP := "has_map"
const HAS_COMPASS := "has_compass"
const HAS_BOSS_KEY := "has_boss_key"
const BOSS_KEY_PIECES := "boss_key_pieces"
const VISITED_ROOMS := "visited_rooms"


static func dungeon_section(id: StringName) -> String:
	return DUNGEON_PREFIX + id


static func is_dungeon_section(section: String) -> bool:
	return section.begins_with(DUNGEON_PREFIX)


static func dungeon_id(section: String) -> StringName:
	return StringName(section.trim_prefix(DUNGEON_PREFIX))
