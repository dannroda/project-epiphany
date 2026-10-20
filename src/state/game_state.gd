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
## Empieza otra partida o se carga una (reset y read_from): SceneFlow borra su Session.
signal cleared
## Una botella cambió de contenido (la llenaron, la tomaron).
signal bottle_changed(bottle: StringName, content: StringName)
## Zonas del overworld visitadas o pines del mapa.
signal map_changed
## Se pintó más de lo descubierto del overworld (map_revealed).
signal map_revealed_changed

const FLAGS: FlagRegistry = preload(FlagRegistry.PATH)
## La vida de una partida nueva es la de player.tres.
const PLAYER_CONFIG := preload("res://data/entities/player.tres")
const HP_PER_HEART := 4
const PIECES_PER_HEART := 4
const PIECES_PER_BOSS_KEY := 4
const MAX_MAP_PINS := 4
const BOTTLES := ItemDatabase.BOTTLES
const EMPTY_BOTTLE := ItemDatabase.EMPTY_BOTTLE
## Radio (m) dentro del cual poner un pin quita el que ya está.
const PIN_PICK_RADIUS := 3.0
## Las partidas de antes guardaban un solo mapa descubierto, sin su origen: era el del overworld en ese lugar.
const LEGACY_REVEAL := [&"overworld", Vector2(-101, -49)]
const MAX_REVEAL_PIXELS := 4096 * 4096

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
## Lo recorrido de cada mapa (OverworldMap.reveal_key): imagen L8 de 1 px por metro (0 = sin descubrir) que arranca en
## `map_reveal_origins` (XZ del mundo).
var map_reveals: Dictionary[StringName, Image] = {}
var map_reveal_origins: Dictionary[StringName, Vector2] = {}
## Lo recorrido del mapa en que se está (el último que pidió ensure_map_revealed).
var map_revealed: Image
var _reveal_key: StringName = &""
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
## Segundos jugados (con player en escena y sin pausa): los suma Players.
var play_time := 0.0


static func new_game_max_health() -> int:
	return PLAYER_CONFIG.max_health


func _ready() -> void:
	reset()


func reset() -> void:
	_set_bulk(true)
	_clear()
	for item in Items.database.new_game_equipment:
		inventory.add(item.id)
		equipment[item.category] = item.id
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


## Deja en map_revealed lo recorrido del mapa `key` sobre `rect`; si el mapa cambió de rectángulo, lo descubierto que
## cae adentro se conserva.
func ensure_map_revealed(key: StringName, rect: Rect2) -> void:
	var size := Vector2i(rect.size.ceil())
	var image: Image = map_reveals.get(key)
	var origin: Vector2 = map_reveal_origins.get(key, rect.position)
	if image == null or image.get_size() != size or not origin.is_equal_approx(rect.position):
		var moved := Image.create_empty(size.x, size.y, false, Image.FORMAT_L8)
		if image:
			var shift := Vector2i((origin - rect.position).round())
			var overlap := Rect2i(shift, image.get_size()).intersection(Rect2i(Vector2i.ZERO, size))
			if overlap.has_area():
				moved.blit_rect(image, Rect2i(overlap.position - shift, overlap.size), overlap.position)
		image = moved
		map_reveals[key] = image
		map_reveal_origins[key] = rect.position
	_reveal_key = key
	map_revealed = image


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
	match item.on_get:
		ItemData.OnGet.SMALL_KEY: current_dungeon_state().small_keys += amount
		ItemData.OnGet.BOSS_KEY: current_dungeon_state().has_boss_key = true
		ItemData.OnGet.BOSS_KEY_PIECE:
			var dungeon := current_dungeon_state()
			dungeon.boss_key_pieces += amount
			if dungeon.boss_key_pieces >= PIECES_PER_BOSS_KEY:
				dungeon.has_boss_key = true
		ItemData.OnGet.DUNGEON_MAP: current_dungeon_state().has_map = true
		ItemData.OnGet.COMPASS: current_dungeon_state().has_compass = true
		ItemData.OnGet.HEART_CONTAINER:
			_add_hearts(amount)
		ItemData.OnGet.HEART_PIECE:
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
		bottle_changed.emit(bottle, content)


## Un contenido llena la primera botella vacía; si no hay, llega en una botella nueva (hasta cuatro).
func _bottle(content: ItemData) -> StringName:
	var bottle := bottle_with(EMPTY_BOTTLE) if content.id != EMPTY_BOTTLE else &""
	if bottle != &"":
		fill(bottle, content.id)
		return bottle
	for candidate in BOTTLES:
		if not bottles.has(candidate):
			bottles[candidate] = content.id
			inventory.add(candidate)
			_auto_place(Items.get_item(candidate))
			return candidate
	return &""


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
	cfg.set_value(SaveKeys.PLAYER, SaveKeys.MAX_HEALTH, max_health)
	cfg.set_value(SaveKeys.PLAYER, SaveKeys.HEALTH, player_health.duplicate())
	cfg.set_value(SaveKeys.PLAYER, SaveKeys.PLAY_TIME, play_time)
	cfg.set_value(SaveKeys.PLAYER, SaveKeys.SPAWN_SCENE, spawn_scene)
	var uid := ResourceLoader.get_resource_uid(spawn_scene) if not spawn_scene.is_empty() else ResourceUID.INVALID_ID
	if uid != ResourceUID.INVALID_ID:
		cfg.set_value(SaveKeys.PLAYER, SaveKeys.SPAWN_UID, ResourceUID.id_to_text(uid))
	cfg.set_value(SaveKeys.PLAYER, SaveKeys.SPAWN_POINT, spawn_point)
	cfg.set_value(SaveKeys.PLAYER, SaveKeys.CURRENT_DUNGEON, current_dungeon)
	if player_position != null:
		cfg.set_value(SaveKeys.PLAYER, SaveKeys.POSITION, player_position)
	for id in inventory.ids():
		cfg.set_value(SaveKeys.INVENTORY, id, inventory.count(id))
	for bottle in bottles:
		cfg.set_value(SaveKeys.BOTTLES, bottle, bottles[bottle])
	for category in equipment:
		cfg.set_value(SaveKeys.EQUIPMENT, ItemData.Category.find_key(category), equipment[category])
	cfg.set_value(SaveKeys.EQUIPMENT, SaveKeys.BUTTONS, item_buttons.duplicate())
	for id in flags:
		cfg.set_value(SaveKeys.FLAGS, id, flags[id])
	cfg.set_value(SaveKeys.MAP, SaveKeys.VISITED_ZONES, visited_zones.duplicate())
	cfg.set_value(SaveKeys.MAP, SaveKeys.PINS, map_pins.duplicate())
	var reveals := {}
	for key in map_reveals:
		var image := map_reveals[key]
		reveals[key] = [map_reveal_origins[key], image.get_size(), image.get_data().compress(FileAccess.COMPRESSION_ZSTD)]
	if not reveals.is_empty():
		cfg.set_value(SaveKeys.MAP, SaveKeys.REVEALS, reveals)
	for dungeon_id in dungeons:
		dungeons[dungeon_id].write_to(cfg, SaveKeys.dungeon_section(dungeon_id))


func read_from(cfg: ConfigFile) -> void:
	_set_bulk(true)
	_clear()
	var get_typed := func(section: String, key: String, default: Variant) -> Variant: return SaveCodec.typed(cfg, section, key, default)
	max_health = maxi(get_typed.call(SaveKeys.PLAYER, SaveKeys.MAX_HEALTH, new_game_max_health()), HP_PER_HEART)
	player_health.assign(get_typed.call(SaveKeys.PLAYER, SaveKeys.HEALTH, {}))
	play_time = get_typed.call(SaveKeys.PLAYER, SaveKeys.PLAY_TIME, 0.0)
	spawn_scene = _scene_path(get_typed.call(SaveKeys.PLAYER, SaveKeys.SPAWN_UID, ""), get_typed.call(SaveKeys.PLAYER, SaveKeys.SPAWN_SCENE, ""))
	spawn_point = get_typed.call(SaveKeys.PLAYER, SaveKeys.SPAWN_POINT, &"")
	current_dungeon = get_typed.call(SaveKeys.PLAYER, SaveKeys.CURRENT_DUNGEON, &"")
	if cfg.has_section_key(SaveKeys.PLAYER, SaveKeys.POSITION) and cfg.get_value(SaveKeys.PLAYER, SaveKeys.POSITION) is Vector3:
		player_position = cfg.get_value(SaveKeys.PLAYER, SaveKeys.POSITION)
	for id in _keys(cfg, SaveKeys.INVENTORY):
		var count: int = get_typed.call(SaveKeys.INVENTORY, id, 0)
		if Items.get_item(id) == null:
			Log.warning(&"save", "Ítem inexistente en la partida:", id)
		elif count > 0:
			inventory.add(id, count)
	for key in _keys(cfg, SaveKeys.EQUIPMENT):
		if key == SaveKeys.BUTTONS:
			_read_buttons(get_typed.call(SaveKeys.EQUIPMENT, key, []))
		elif ItemData.Category.has(key):
			var category: ItemData.Category = ItemData.Category[key]
			var id: StringName = get_typed.call(SaveKeys.EQUIPMENT, key, &"")
			var item := Items.get_item(id) if id != &"" else null
			if item and item.category == category:
				equipment[category] = id
			elif id != &"":
				Log.warning(&"save", "Equipo que no corresponde en la partida:", key, id)
				_equip_new_game(category)
	for bottle in _keys(cfg, SaveKeys.BOTTLES):
		var content: StringName = get_typed.call(SaveKeys.BOTTLES, bottle, &"")
		if bottle not in BOTTLES:
			Log.warning(&"save", "Botella inexistente en la partida:", bottle)
			continue
		var item := Items.get_item(content) if content != &"" else null
		if item == null or (content != EMPTY_BOTTLE and item.liquid.a <= 0.0):
			Log.warning(&"save", "Botella con algo que no es un líquido:", bottle, content)
			content = EMPTY_BOTTLE
		bottles[bottle] = content
	for id in _keys(cfg, SaveKeys.FLAGS):
		var value: Variant = cfg.get_value(SaveKeys.FLAGS, id)
		var default: Variant = FLAGS.default_of(id)
		if default != null and typeof(value) != typeof(default):
			Log.warning(&"save", "Flag con otro tipo en la partida:", id, value)
			continue
		flags[id] = value
	visited_zones.assign(get_typed.call(SaveKeys.MAP, SaveKeys.VISITED_ZONES, []))
	map_pins.assign(get_typed.call(SaveKeys.MAP, SaveKeys.PINS, []))
	var reveals: Dictionary = get_typed.call(SaveKeys.MAP, SaveKeys.REVEALS, {})
	for key: Variant in reveals:
		var entry: Variant = reveals[key]
		if entry is Array and entry.size() == 3 and entry[0] is Vector2 and entry[1] is Vector2i and entry[2] is PackedByteArray:
			_read_reveal(StringName(str(key)), entry[0], entry[1], entry[2])
		else:
			Log.warning(&"save", "Mapa descubierto con otro formato:", key)
	var legacy_size: Vector2i = get_typed.call(SaveKeys.MAP, SaveKeys.REVEALED_SIZE, Vector2i.ZERO)
	if not map_reveals.has(LEGACY_REVEAL[0]) and legacy_size.x > 0:
		_read_reveal(LEGACY_REVEAL[0], LEGACY_REVEAL[1], legacy_size, get_typed.call(SaveKeys.MAP, SaveKeys.REVEALED, PackedByteArray()))
	map_revealed = map_reveals.get(_reveal_key)
	for section in cfg.get_sections():
		if SaveKeys.is_dungeon_section(section):
			dungeons[SaveKeys.dungeon_id(section)] = DungeonState.read_from(cfg, section)
	_set_bulk(false)
	loaded.emit()


## Lo del equipo inicial para esa categoría (la partida traía algo que no existe o no corresponde).
func _equip_new_game(category: ItemData.Category) -> void:
	for item in Items.database.new_game_equipment:
		if item.category == category:
			equipment[category] = item.id
			if not inventory.has(item.id):
				inventory.add(item.id)
			return


func _read_reveal(key: StringName, origin: Vector2, size: Vector2i, packed: PackedByteArray) -> void:
	if size.x <= 0 or size.y <= 0 or size.x * size.y > MAX_REVEAL_PIXELS or packed.is_empty():
		return
	var data := packed.decompress(size.x * size.y, FileAccess.COMPRESSION_ZSTD)
	if data.size() == size.x * size.y:
		map_reveals[key] = Image.create_from_data(size.x, size.y, false, Image.FORMAT_L8, data)
		map_reveal_origins[key] = origin


## Siempre dos botones; lo que no es un ítem ni una botella queda vacío (escenarios editados a mano).
func _read_buttons(saved: Array) -> void:
	item_buttons.assign([&"", &""])
	for index in mini(saved.size(), 2):
		var id: Variant = saved[index]
		if (id is StringName or id is String) and Items.get_item(id) != null:
			item_buttons[index] = StringName(id)
		elif str(id) != "":
			Log.warning(&"save", "Botón con algo que no es un ítem:", id)


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
	map_reveals.clear()
	map_reveal_origins.clear()
	map_revealed = null
	dungeons.clear()
	current_dungeon = &""
	spawn_scene = ""
	spawn_point = &""
	player_position = null
	cleared.emit()


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
