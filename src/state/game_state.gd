# Autoload
extends Node

signal flag_changed(id: StringName, value: Variant)
signal equipment_changed(category: ItemData.Category, id: StringName)
signal item_buttons_changed
signal loaded

const FLAGS: FlagRegistry = preload("res://data/flag_registry.tres")
const NEW_GAME_EQUIPMENT: Array[StringName] = [&"sword_basic", &"shield_wood", &"tunic"]
const NEW_GAME_MAX_HEALTH := 12
const DUNGEON_PREFIX := "dungeon_"

var inventory := Inventory.new()
var equipment: Dictionary[ItemData.Category, StringName] = {}
var item_buttons: Array[StringName] = [&"", &""] ## X / Y
var max_health: int = NEW_GAME_MAX_HEALTH
var flags: Dictionary[StringName, Variant] = {}
var dungeons: Dictionary[StringName, DungeonState] = {}
var current_dungeon: StringName = &""
var spawn_scene: String = ""
var spawn_point: StringName = &""
var player_position: Variant = null ## Vector3 hasta que haya puntos de aparición con nombre
var save_tampered := false


func _ready() -> void:
	reset()


func reset() -> void:
	_clear()
	for id in NEW_GAME_EQUIPMENT:
		var item := Items.get_item(id)
		inventory.add(id)
		equipment[item.category] = id
	loaded.emit()


func get_flag(id: StringName) -> Variant:
	return flags.get(id, FLAGS.default_of(id))


func set_flag(id: StringName, value: Variant) -> void:
	assert(FLAGS.has(id), "Flag no registrada: %s" % id)
	flags[id] = value
	flag_changed.emit(id, value)


func equip(item: ItemData) -> void:
	assert(item.is_equipment())
	equipment[item.category] = item.id
	equipment_changed.emit(item.category, item.id)


## Si el ítem ya estaba en el otro botón, se intercambian.
func assign_button(index: int, id: StringName) -> void:
	if item_buttons[index] == id:
		return
	var other := 1 - index
	if item_buttons[other] == id:
		item_buttons[other] = item_buttons[index]
	item_buttons[index] = id
	item_buttons_changed.emit()


func current_dungeon_state() -> DungeonState:
	if not dungeons.has(current_dungeon):
		dungeons[current_dungeon] = DungeonState.new()
	return dungeons[current_dungeon]


## Punto único de entrada para cofres, drops y recompensas.
func give(item: ItemData, amount: int = 1) -> void:
	match item.id:
		&"small_key": current_dungeon_state().small_keys += amount
		&"boss_key": current_dungeon_state().has_boss_key = true
		&"dungeon_map": current_dungeon_state().has_map = true
		&"compass": current_dungeon_state().has_compass = true
		&"heart_container": max_health += 4 * amount
		_:
			inventory.add(item.id, amount)
			_auto_place(item)


## Primer equipo de una categoría: se equipa. Primer usable: va al primer botón libre.
func _auto_place(item: ItemData) -> void:
	if item.is_equipment() and equipment.get(item.category, &"") == &"":
		equip(item)
	elif item.category == ItemData.Category.USABLE and not item_buttons.has(item.id):
		var free := item_buttons.find(&"")
		if free != -1:
			assign_button(free, item.id)


func write_to(cfg: ConfigFile) -> void:
	cfg.set_value("player", "max_health", max_health)
	cfg.set_value("player", "spawn_scene", spawn_scene)
	cfg.set_value("player", "spawn_point", spawn_point)
	cfg.set_value("player", "current_dungeon", current_dungeon)
	if player_position != null:
		cfg.set_value("player", "position", player_position)
	for id in inventory.ids():
		cfg.set_value("inventory", id, inventory.count(id))
	for category in equipment:
		cfg.set_value("equipment", ItemData.Category.find_key(category), equipment[category])
	cfg.set_value("equipment", "buttons", item_buttons.duplicate())
	for id in flags:
		cfg.set_value("flags", id, flags[id])
	for dungeon_id in dungeons:
		var dungeon := dungeons[dungeon_id]
		var section := DUNGEON_PREFIX + dungeon_id
		cfg.set_value(section, "small_keys", dungeon.small_keys)
		cfg.set_value(section, "has_map", dungeon.has_map)
		cfg.set_value(section, "has_compass", dungeon.has_compass)
		cfg.set_value(section, "has_boss_key", dungeon.has_boss_key)
		cfg.set_value(section, "visited_rooms", dungeon.visited_rooms)


func read_from(cfg: ConfigFile) -> void:
	_clear()
	max_health = cfg.get_value("player", "max_health", NEW_GAME_MAX_HEALTH)
	spawn_scene = cfg.get_value("player", "spawn_scene", "")
	spawn_point = cfg.get_value("player", "spawn_point", &"")
	current_dungeon = cfg.get_value("player", "current_dungeon", &"")
	if cfg.has_section_key("player", "position"):
		player_position = cfg.get_value("player", "position")
	for id in _keys(cfg, "inventory"):
		if Items.get_item(id):
			inventory.add(id, cfg.get_value("inventory", id))
		else:
			Log.warning(&"save", "Ítem inexistente en la partida:", id)
	for key in _keys(cfg, "equipment"):
		if key == &"buttons":
			item_buttons.assign(cfg.get_value("equipment", key))
		elif ItemData.Category.has(key):
			equipment[ItemData.Category[key]] = cfg.get_value("equipment", key)
	for id in _keys(cfg, "flags"):
		flags[id] = cfg.get_value("flags", id)
	for section in cfg.get_sections():
		if not section.begins_with(DUNGEON_PREFIX):
			continue
		var dungeon := DungeonState.new()
		dungeon.small_keys = cfg.get_value(section, "small_keys", 0)
		dungeon.has_map = cfg.get_value(section, "has_map", false)
		dungeon.has_compass = cfg.get_value(section, "has_compass", false)
		dungeon.has_boss_key = cfg.get_value(section, "has_boss_key", false)
		dungeon.visited_rooms = cfg.get_value(section, "visited_rooms", 0)
		dungeons[StringName(section.trim_prefix(DUNGEON_PREFIX))] = dungeon
	loaded.emit()


func _clear() -> void:
	inventory.clear()
	equipment.clear()
	item_buttons.assign([&"", &""])
	max_health = NEW_GAME_MAX_HEALTH
	flags.clear()
	dungeons.clear()
	current_dungeon = &""
	spawn_scene = ""
	spawn_point = &""
	player_position = null
	save_tampered = false


func _keys(cfg: ConfigFile, section: String) -> Array[StringName]:
	var keys: Array[StringName] = []
	if cfg.has_section(section):
		for key in cfg.get_section_keys(section):
			keys.append(StringName(key))
	return keys
