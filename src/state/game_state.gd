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
## Se pintó más de lo descubierto del overworld (map_revealed).
signal map_revealed_changed

const FLAGS: FlagRegistry = preload("res://data/flag_registry.tres")
const NEW_GAME_EQUIPMENT: Array[StringName] = [&"sword_basic", &"shield_wood", &"tunic"]
## La vida de una partida nueva es la de player.tres.
const PLAYER_CONFIG := preload("res://data/entities/player.tres")
const HP_PER_HEART := 4
const PIECES_PER_HEART := 4
const PIECES_PER_BOSS_KEY := 4
const DUNGEON_PREFIX := "dungeon_"
const MAX_MAP_PINS := 4
const BOTTLES: Array[StringName] = [&"bottle_1", &"bottle_2", &"bottle_3", &"bottle_4"]
const EMPTY_BOTTLE := &"bottle_empty"
## Radio (m) dentro del cual poner un pin quita el que ya está.
const PIN_PICK_RADIUS := 3.0

var inventory := Inventory.new()
var equipment: Dictionary[ItemData.Category, StringName] = {}
var item_buttons: Array[StringName] = [&"", &""] ## X / Y del P1
## X / Y de los demás players (13.4): el inventario es de todos pero cada uno asigna los suyos y un ítem lo lleva uno
## solo (13.9). No se guardan.
var guest_buttons: Dictionary[int, Array] = {}
var max_health: int = PLAYER_CONFIG.max_health
## Vida actual de cada player por slot: es global, se mantiene al cambiar de escena y va en la partida.
var player_health: Dictionary[int, int] = {}
## La bendición (agua bendita) que le quedaba a cada player al viajar: la retoma en la escena nueva.
var player_ward: Dictionary[int, float] = {}
## Botella → lo que tiene (bottle_empty, potion, holy_water…): son cuatro y cada una lleva cualquier contenido.
var bottles: Dictionary[StringName, StringName] = {}
var flags: Dictionary[StringName, Variant] = {}
var dungeons: Dictionary[StringName, DungeonState] = {}
var visited_zones: Array[StringName] = []
## Marcas del jugador en el mapa del overworld (XZ del mundo).
var map_pins: Array[Vector2] = []
## Lo recorrido del overworld para el minimapa: imagen L8 sobre OverworldMap.world_rect (0 = sin descubrir).
var map_revealed: Image
## Cargando en bloque (partida nueva o guardada): las señales finas se callan y solo sale `loaded`.
var _bulk := false
var current_dungeon: StringName = &"":
	set(value):
		if value != current_dungeon:
			current_dungeon = value
			if not _bulk:
				dungeon_changed.emit()
var spawn_scene: String = ""
var spawn_point: StringName = &""
var player_position: Variant = null ## Vector3 hasta que haya puntos de aparición con nombre
## Mazmorra: dónde quedó el player al entrar a la sala actual; ahí reaparece al morir. No se guarda.
var room_entry: Variant = null
## Revancha contra el jefe ya vencido (10.19): la arena lo trae de vuelta hasta ganarle. No se guarda.
var boss_rematch := false
## Presentaciones de jefe ya vistas (por su flag): la próxima vez se pueden saltear. No se guarda.
var seen_boss_intros := {}
var save_tampered := false
## Segundos jugados (con player en escena y sin pausa).
var play_time := 0.0


static func new_game_max_health() -> int:
	return PLAYER_CONFIG.max_health


func _ready() -> void:
	reset()


func reset() -> void:
	_set_bulk(true)
	_clear()
	for id in NEW_GAME_EQUIPMENT:
		var item := Items.get_item(id)
		inventory.add(id)
		equipment[item.category] = id
	_set_bulk(false)
	loaded.emit()


func _set_bulk(on: bool) -> void:
	_bulk = on
	inventory.quiet = on


func get_flag(id: StringName) -> Variant:
	return flags.get(id, FLAGS.default_of(id))


## Sin vida guardada, o caído (0), vuelve llena.
func health_of(slot: int) -> int:
	var stored: int = player_health.get(slot, 0)
	return max_health if stored <= 0 else mini(stored, max_health)


func set_health_of(slot: int, value: int) -> void:
	player_health[slot] = value


func ward_of(slot: int) -> float:
	return player_ward.get(slot, 0.0)


func set_ward_of(slot: int, seconds: float) -> void:
	player_ward[slot] = seconds


func ensure_map_revealed(size: Vector2i) -> void:
	if map_revealed == null or map_revealed.get_size() != size:
		map_revealed = Image.create_empty(size.x, size.y, false, Image.FORMAT_L8)


func set_flag(id: StringName, value: Variant) -> void:
	assert(FLAGS.has(id), "Flag no registrada: %s" % id)
	if flags.has(id) and typeof(flags[id]) == typeof(value) and flags[id] == value:
		return
	flags[id] = value
	flag_changed.emit(id, value)


func equip(item: ItemData) -> void:
	assert(item.is_equipment())
	equipment[item.category] = item.id
	equipment_changed.emit(item.category, item.id)


## Si el ítem ya estaba en el otro botón, se intercambian.
## Falso si el ítem lo lleva otro player.
func assign_button(index: int, id: StringName, slot := 0) -> bool:
	var buttons := buttons_of(slot)
	if buttons[index] == id:
		return true
	if id != &"" and owner_of(id) not in [-1, slot]:
		return false
	var other := 1 - index
	if buttons[other] == id:
		buttons[other] = buttons[index]
	buttons[index] = id
	item_buttons_changed.emit()
	return true


## El slot del player que lleva el ítem en su X o Y; -1 si nadie.
func owner_of(id: StringName) -> int:
	for slot in _button_slots():
		if buttons_of(slot).has(id):
			return slot
	return -1


## El que sale de la partida suelta sus ítems.
func release_buttons(slot: int) -> void:
	if guest_buttons.erase(slot):
		item_buttons_changed.emit()


## Los X / Y del player en `slot`; uno que se suma arranca con las manos vacías.
func buttons_of(slot: int) -> Array[StringName]:
	if slot == 0:
		return item_buttons
	if not guest_buttons.has(slot):
		guest_buttons[slot] = [&"", &""] as Array[StringName]
	return guest_buttons[slot]


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


## Si `item` es munición y no tiene con qué llevarla (las bombas sin la bolsa, las flechas sin el arco), lo que le falta.
func missing_holder(item: ItemData) -> ItemData:
	var holders := Items.database.items.filter(func(other: ItemData) -> bool: return other.behavior != null and other.behavior.ammo == item)
	if holders.is_empty() or holders.any(func(other: ItemData) -> bool: return inventory.has(other.id)):
		return null
	return holders[0]


## Punto único de entrada para cofres, drops y recompensas.
func give(item: ItemData, amount: int = 1) -> void:
	if item.bottled:
		for i in amount:
			_bottle(item)
		return
	match item.id:
		&"small_key": current_dungeon_state().small_keys += amount
		&"boss_key": current_dungeon_state().has_boss_key = true
		&"boss_key_piece":
			var dungeon := current_dungeon_state()
			dungeon.boss_key_pieces += amount
			if dungeon.boss_key_pieces >= PIECES_PER_BOSS_KEY:
				dungeon.has_boss_key = true
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


## Cambia una unidad de un ítem por otro (botella vacía ↔ llena) y el botón X/Y que tenía el viejo pasa al nuevo si ya
## no queda ninguno del viejo.
func swap_item(from: StringName, to: ItemData) -> void:
	if bottles.has(from):
		fill(from, to.id)
		return
	inventory.remove(from)
	inventory.add(to.id)
	for slot in _button_slots():
		var buttons := buttons_of(slot)
		var index := buttons.find(from)
		if index >= 0 and not inventory.has(from):
			assign_button(index, to.id, slot)
		elif not buttons.has(to.id):
			_auto_place(to, slot)


## Lo que hay detrás de un ítem del inventario: una botella da su contenido.
func item_for(id: StringName) -> ItemData:
	if id == &"":
		return null
	return Items.get_item(bottles.get(id, id))


## La primera botella con ese contenido (&"" si ninguna).
func bottle_with(content: StringName) -> StringName:
	for bottle in BOTTLES:
		if bottles.get(bottle, &"") == content:
			return bottle
	return &""


func fill(bottle: StringName, content: StringName) -> void:
	bottles[bottle] = content
	if not inventory.quiet:
		inventory.changed.emit(bottle, inventory.count(bottle))


## Un contenido llena la primera botella vacía; si no hay, llega en una botella nueva (hasta cuatro).
func _bottle(content: ItemData, place := true) -> StringName:
	var bottle := bottle_with(EMPTY_BOTTLE) if content.id != EMPTY_BOTTLE else &""
	if bottle != &"":
		fill(bottle, content.id)
		return bottle
	for candidate in BOTTLES:
		if not bottles.has(candidate):
			bottles[candidate] = content.id
			inventory.add(candidate)
			if place:
				_auto_place(Items.get_item(candidate))
			return candidate
	return &""


## Partidas de antes de las botellas únicas: cada poción, agua bendita o botella vacía pasa a una botella.
func _migrate_bottles() -> void:
	for id in inventory.ids():
		var item := Items.get_item(id)
		if item == null or not item.bottled:
			continue
		var count := inventory.count(id)
		inventory.remove(id, count)
		for i in count:
			var bottle := _bottle(item, false)
			for slot in _button_slots():
				var buttons := buttons_of(slot)
				var index := buttons.find(id)
				if index >= 0:
					buttons[index] = bottle


## Las que todavía no completan un corazón.
func heart_pieces() -> int:
	return inventory.count(&"heart_piece")


func _add_hearts(count: int) -> void:
	max_health += HP_PER_HEART * count
	max_health_changed.emit(max_health)


## Primer equipo de una categoría (o una mejora con `equip_on_get`): se equipa. Primer usable: al primer botón libre,
## del primer player que tenga uno.
func _auto_place(item: ItemData, only_slot := -1) -> void:
	if item.is_equipment() and (item.equip_on_get or equipment.get(item.category, &"") == &""):
		equip(item)
	elif item.category == ItemData.Category.USABLE:
		for slot in _button_slots():
			var buttons := buttons_of(slot)
			if (only_slot == -1 or slot == only_slot) and not buttons.has(item.id) and buttons.has(&""):
				assign_button(buttons.find(&""), item.id, slot)


func _button_slots() -> Array[int]:
	var slots: Array[int] = [0]
	slots.append_array(guest_buttons.keys())
	return slots


func write_to(cfg: ConfigFile) -> void:
	cfg.set_value("player", "max_health", max_health)
	cfg.set_value("player", "health", player_health.duplicate())
	cfg.set_value("player", "play_time", play_time)
	cfg.set_value("player", "spawn_scene", spawn_scene)
	var uid := ResourceLoader.get_resource_uid(spawn_scene) if not spawn_scene.is_empty() else ResourceUID.INVALID_ID
	if uid != ResourceUID.INVALID_ID:
		cfg.set_value("player", "spawn_uid", ResourceUID.id_to_text(uid))
	cfg.set_value("player", "spawn_point", spawn_point)
	cfg.set_value("player", "current_dungeon", current_dungeon)
	if player_position != null:
		cfg.set_value("player", "position", player_position)
	for id in inventory.ids():
		cfg.set_value("inventory", id, inventory.count(id))
	for bottle in bottles:
		cfg.set_value("bottles", bottle, bottles[bottle])
	for category in equipment:
		cfg.set_value("equipment", ItemData.Category.find_key(category), equipment[category])
	cfg.set_value("equipment", "buttons", item_buttons.duplicate())
	for id in flags:
		cfg.set_value("flags", id, flags[id])
	cfg.set_value("map", "visited_zones", visited_zones.duplicate())
	cfg.set_value("map", "pins", map_pins.duplicate())
	if map_revealed:
		cfg.set_value("map", "revealed_size", map_revealed.get_size())
		cfg.set_value("map", "revealed", map_revealed.get_data().compress(FileAccess.COMPRESSION_ZSTD))
	for dungeon_id in dungeons:
		var dungeon := dungeons[dungeon_id]
		var section := DUNGEON_PREFIX + dungeon_id
		cfg.set_value(section, "small_keys", dungeon.small_keys)
		cfg.set_value(section, "has_map", dungeon.has_map)
		cfg.set_value(section, "has_compass", dungeon.has_compass)
		cfg.set_value(section, "has_boss_key", dungeon.has_boss_key)
		if dungeon.boss_key_pieces > 0:
			cfg.set_value(section, "boss_key_pieces", dungeon.boss_key_pieces)
		cfg.set_value(section, "visited_rooms", dungeon.visited_rooms)


func read_from(cfg: ConfigFile) -> void:
	_set_bulk(true)
	_clear()
	var get_typed := func(section: String, key: String, default: Variant) -> Variant: return SaveCodec.typed(cfg, section, key, default)
	max_health = get_typed.call("player", "max_health", new_game_max_health())
	player_health.assign(get_typed.call("player", "health", {}))
	play_time = get_typed.call("player", "play_time", 0.0)
	spawn_scene = _scene_path(get_typed.call("player", "spawn_uid", ""), get_typed.call("player", "spawn_scene", ""))
	spawn_point = get_typed.call("player", "spawn_point", &"")
	current_dungeon = get_typed.call("player", "current_dungeon", &"")
	if cfg.has_section_key("player", "position") and cfg.get_value("player", "position") is Vector3:
		player_position = cfg.get_value("player", "position")
	for id in _keys(cfg, "inventory"):
		var count: int = get_typed.call("inventory", id, 0)
		if Items.get_item(id) == null:
			Log.warning(&"save", "Ítem inexistente en la partida:", id)
		elif count > 0:
			inventory.add(id, count)
	for key in _keys(cfg, "equipment"):
		if key == &"buttons":
			item_buttons.assign(get_typed.call("equipment", key, []))
		elif ItemData.Category.has(key):
			equipment[ItemData.Category[key]] = get_typed.call("equipment", key, &"")
	for bottle in _keys(cfg, "bottles"):
		bottles[bottle] = get_typed.call("bottles", bottle, &"")
	_migrate_bottles()
	for id in _keys(cfg, "flags"):
		flags[id] = cfg.get_value("flags", id)
	visited_zones.assign(get_typed.call("map", "visited_zones", []))
	map_pins.assign(get_typed.call("map", "pins", []))
	var size: Vector2i = get_typed.call("map", "revealed_size", Vector2i.ZERO)
	var packed: PackedByteArray = get_typed.call("map", "revealed", PackedByteArray())
	if size.x > 0 and not packed.is_empty():
		var data := packed.decompress(size.x * size.y, FileAccess.COMPRESSION_ZSTD)
		if data.size() == size.x * size.y:
			map_revealed = Image.create_from_data(size.x, size.y, false, Image.FORMAT_L8, data)
	for section in cfg.get_sections():
		if not section.begins_with(DUNGEON_PREFIX):
			continue
		var dungeon := DungeonState.new()
		dungeon.small_keys = get_typed.call(section, "small_keys", 0)
		dungeon.has_map = get_typed.call(section, "has_map", false)
		dungeon.has_compass = get_typed.call(section, "has_compass", false)
		dungeon.has_boss_key = get_typed.call(section, "has_boss_key", false)
		dungeon.boss_key_pieces = get_typed.call(section, "boss_key_pieces", 0)
		dungeon.visited_rooms = get_typed.call(section, "visited_rooms", 0)
		dungeons[StringName(section.trim_prefix(DUNGEON_PREFIX))] = dungeon
	_set_bulk(false)
	loaded.emit()


func _clear() -> void:
	inventory.clear()
	equipment.clear()
	item_buttons.assign([&"", &""])
	guest_buttons.clear()
	max_health = new_game_max_health()
	player_health.clear()
	player_ward.clear()
	bottles.clear()
	play_time = 0.0
	flags.clear()
	visited_zones.clear()
	map_pins.clear()
	map_revealed = null
	dungeons.clear()
	current_dungeon = &""
	spawn_scene = ""
	spawn_point = &""
	player_position = null
	room_entry = null
	boss_rematch = false
	seen_boss_intros.clear()
	save_tampered = false


## El uid sigue al nivel si se movió o se renombró; la ruta queda para saves viejos sin uid.
func _scene_path(uid_text: String, path: String) -> String:
	var uid := ResourceUID.text_to_id(uid_text) if not uid_text.is_empty() else ResourceUID.INVALID_ID
	if uid != ResourceUID.INVALID_ID and ResourceUID.has_id(uid):
		return ResourceUID.get_id_path(uid)
	return path


func _keys(cfg: ConfigFile, section: String) -> Array[StringName]:
	var keys: Array[StringName] = []
	if cfg.has_section(section):
		for key in cfg.get_section_keys(section):
			keys.append(StringName(key))
	return keys


func _process(delta: float) -> void:
	if not get_tree().paused and not Players.all.is_empty():
		play_time += delta
