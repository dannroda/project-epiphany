# Autoload
extends Node

## Contenedor de corazón: el player rellena la vida con el nuevo máximo.
signal max_health_changed(value: int)
signal flag_changed(id: StringName, value: Variant)
signal equipment_changed(category: ItemData.Category, id: StringName)
signal item_buttons_changed
## Al entrar o salir de una mazmorra.
signal dungeon_changed
signal loaded
## Zonas del overworld visitadas o pines del mapa.
signal map_changed

const FLAGS: FlagRegistry = preload("res://data/flag_registry.tres")
const NEW_GAME_EQUIPMENT: Array[StringName] = [&"sword_basic", &"shield_wood", &"tunic"]
const NEW_GAME_MAX_HEALTH := 12
const HP_PER_HEART := 4
const PIECES_PER_HEART := 4
const DUNGEON_PREFIX := "dungeon_"
const MAX_MAP_PINS := 4
## Radio (m) dentro del cual poner un pin quita el que ya está.
const PIN_PICK_RADIUS := 3.0

var inventory := Inventory.new()
var equipment: Dictionary[ItemData.Category, StringName] = {}
var item_buttons: Array[StringName] = [&"", &""] ## X / Y
var max_health: int = NEW_GAME_MAX_HEALTH
var flags: Dictionary[StringName, Variant] = {}
var dungeons: Dictionary[StringName, DungeonState] = {}
var visited_zones: Array[StringName] = []
## Marcas del jugador en el mapa del overworld (XZ del mundo).
var map_pins: Array[Vector2] = []
var current_dungeon: StringName = &"":
	set(value):
		if value != current_dungeon:
			current_dungeon = value
			dungeon_changed.emit()
var spawn_scene: String = ""
var spawn_point: StringName = &""
var player_position: Variant = null ## Vector3 hasta que haya puntos de aparición con nombre
## Mazmorra: dónde quedó el player al entrar a la sala actual; ahí reaparece al morir. No se guarda.
var room_entry: Variant = null
var save_tampered := false
## Segundos jugados (con player en escena y sin pausa).
var play_time := 0.0


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


func visit_zone(id: StringName) -> void:
	if not visited_zones.has(id):
		visited_zones.append(id)
		map_changed.emit()


## Quita el pin cercano o pone uno nuevo si queda lugar. Devuelve si cambió algo.
func toggle_pin(point: Vector2) -> bool:
	for pin in map_pins:
		if pin.distance_to(point) <= PIN_PICK_RADIUS:
			map_pins.erase(pin)
			map_changed.emit()
			return true
	if map_pins.size() >= MAX_MAP_PINS:
		return false
	map_pins.append(point)
	map_changed.emit()
	return true


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
		&"heart_container":
			_add_hearts(amount)
		&"heart_piece":
			inventory.add(item.id, amount)
			var hearts := heart_pieces() / PIECES_PER_HEART
			if hearts > 0:
				inventory.remove(item.id, hearts * PIECES_PER_HEART)
				_add_hearts(hearts)
		_:
			inventory.add(item.id, amount)
			_auto_place(item)
			if item.bundled and item.bundled_amount > 0:
				inventory.add(item.bundled.id, item.bundled_amount * amount)


## Las que todavía no completan un corazón.
func heart_pieces() -> int:
	return inventory.count(&"heart_piece")


func _add_hearts(count: int) -> void:
	max_health += HP_PER_HEART * count
	max_health_changed.emit(max_health)


## Primer equipo de una categoría (o una mejora con `equip_on_get`): se equipa. Primer usable: va al primer botón libre.
func _auto_place(item: ItemData) -> void:
	if item.is_equipment() and (item.equip_on_get or equipment.get(item.category, &"") == &""):
		equip(item)
	elif item.category == ItemData.Category.USABLE and not item_buttons.has(item.id):
		var free := item_buttons.find(&"")
		if free != -1:
			assign_button(free, item.id)


func write_to(cfg: ConfigFile) -> void:
	cfg.set_value("player", "max_health", max_health)
	cfg.set_value("player", "play_time", play_time)
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
	cfg.set_value("map", "visited_zones", visited_zones.duplicate())
	cfg.set_value("map", "pins", map_pins.duplicate())
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
	play_time = cfg.get_value("player", "play_time", 0.0)
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
	visited_zones.assign(cfg.get_value("map", "visited_zones", []))
	map_pins.assign(cfg.get_value("map", "pins", []))
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
	play_time = 0.0
	flags.clear()
	visited_zones.clear()
	map_pins.clear()
	dungeons.clear()
	current_dungeon = &""
	spawn_scene = ""
	spawn_point = &""
	player_position = null
	room_entry = null
	save_tampered = false


func _keys(cfg: ConfigFile, section: String) -> Array[StringName]:
	var keys: Array[StringName] = []
	if cfg.has_section(section):
		for key in cfg.get_section_keys(section):
			keys.append(StringName(key))
	return keys


func _process(delta: float) -> void:
	if not get_tree().paused and not Players.all.is_empty():
		play_time += delta
