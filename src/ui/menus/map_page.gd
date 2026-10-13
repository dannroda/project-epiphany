extends Control
## Pestaña Mapa. En mazmorra: las salas (visitadas; con mapa, todas; con brújula, cofres sin abrir y el jefe), las
## puertas y dónde está el player; el cursor salta de sala en sala. En el overworld: la foto cenital con las zonas sin
## explorar en sombra, las marcas (entradas, cofres abiertos, tablillas leídas, portales prendidos), los pines del
## jugador y un cursor libre que muestra qué falta en cada zona; cerca de un portal se engancha a él y X viaja.

## Cambió lo que muestra la barra de ayudas (zoom).
signal hints_changed

const MapData := preload("res://src/ui/menus/map_data.gd")
const STEP := MapRoomCell.SIZE + Vector2(12, 12)
const CURSOR_SPEED := 420.0
const ZONE_NAME_SCENE := preload("res://src/ui/menus/map_zone_name.tscn")
const PLACE_NAME_SCENE := preload("res://src/ui/menus/map_place_name.tscn")
const ZOOM := 2.0
const PORTAL_SNAP := 14.0
const TRAVEL_DIALOG := "res://src/ui/menus/travel_dialog.tscn"
const DIRECTIONS := [
	[&"move_left", Vector2i.LEFT], [&"move_right", Vector2i.RIGHT], [&"move_forward", Vector2i.UP], [&"move_backward", Vector2i.DOWN],
	[&"ui_left", Vector2i.LEFT], [&"ui_right", Vector2i.RIGHT], [&"ui_up", Vector2i.UP], [&"ui_down", Vector2i.DOWN],
]

## Lo leen el menú de pausa (ayudas) y los tests.
var accept_label: String:
	get:
		return ""
var extra_hints: Array:
	get:
		var move := [[&"move_left", &"move_right"], "MAP_HINT_MOVE"]
		if _in_dungeon():
			return [move, [[&"map_floor_up", &"map_floor_down"], "MAP_HINT_FLOOR"]] if _levels().size() > 1 else [move]
		var hints := [move]
		if can_travel():
			hints.append([&"ui_accept", "MAP_HINT_TRAVEL"])
		return hints + [[&"item_1", "MAP_HINT_PIN"], [&"item_2", "MAP_HINT_ZOOM_OUT" if _zoomed else "MAP_HINT_ZOOM_IN"]]

@onready var map_card: Control = %MapCard
@onready var cells: Control = %Cells
@onready var rooms_layer: Control = %Rooms
@onready var doors_layer: Control = %Doors
@onready var room_cursor: MapCursor = %RoomCursor
@onready var door_legend: Control = %DoorLegendBox
@onready var floors_box: Control = %FloorsBox
@onready var floor_buttons: VBoxContainer = %FloorButtons
@onready var up_icon: TextureRect = %UpIcon
@onready var down_icon: TextureRect = %DownIcon
@onready var overworld: Control = %Overworld
@onready var canvas: Control = %Canvas
@onready var overworld_image: TextureRect = %OverworldImage
@onready var marks: Control = %Marks
@onready var pins: Control = %Pins
@onready var marker: Control = %Marker
@onready var cursor: MapCursor = %Cursor
@onready var title: Label = %MapTitle
@onready var subtitle: Label = %MapSubtitle
@onready var focus_title: Label = %FocusTitle
@onready var portal_title: Control = %PortalTitle
@onready var portal_name: Label = %PortalName
@onready var travel_button: Button = %Travel
@onready var focus_text: Label = %FocusText
@onready var focus_stats: VBoxContainer = %FocusStats
@onready var map_items: GridContainer = %MapItems
@onready var legend: VBoxContainer = %Legend
@onready var overworld_legend: VBoxContainer = %OverworldLegend
@onready var pins_label: Label = %PinsLabel

var _dungeon: DungeonState
var _map: OverworldMap
## Mazmorra: celdas visibles por sala.
var _room_cells: Dictionary[Room, MapRoomCell] = {}
var _focused_room: Room
var _zoomed := false
## Overworld: dónde está el cursor antes de engancharse a un portal, y el portal enganchado.
var _cursor_point := Vector2.ZERO
var _focused_portal: TravelPortal
## Lo que muestra el panel (zona y portal): mover el cursor dentro de la misma zona no lo rehace.
var _focus_key: Array = []
## Zonas, tablillas y fragmentos del overworld, leídos una vez por escena.
var _cached_scene: Node
var _zone_list: Array = []
var _tablets: Array = []
var _pieces: Array = []
## Piso que se mira (null = el de la sala actual, al abrir el mapa) y la celda del cursor al cambiar de piso.
var _view_level: Variant = null
var _keep_cell: Variant = null


func _ready() -> void:
	GameState.dungeon_changed.connect(refresh)
	GameState.loaded.connect(refresh)
	GameState.map_changed.connect(_refresh_pins)
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree():
			_view_level = null
			_keep_cell = null
			refresh())
	InputDevice.input_device_changed.connect(func(_device: int) -> void: _refresh_floor_icons())
	marker.draw.connect(func() -> void: MapRoomCell.draw_arrow(marker, Vector2.ZERO, 0.0))
	overworld_image.resized.connect(_place_overworld)
	travel_button.pressed.connect(_ask_travel)
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh.call_deferred()


func refresh() -> void:
	if _dungeon and _dungeon.changed.is_connected(refresh):
		_dungeon.changed.disconnect(refresh)
	_dungeon = null
	for layer in [rooms_layer, doors_layer, focus_stats, marks, floor_buttons]:
		_clear(layer)
	_room_cells.clear()
	_focused_portal = null
	_focus_key = []
	portal_title.visible = false
	focus_title.visible = true
	travel_button.visible = false
	var in_dungeon := _in_dungeon()
	cells.visible = in_dungeon
	legend.visible = in_dungeon
	map_items.visible = in_dungeon
	door_legend.visible = in_dungeon
	overworld.visible = not in_dungeon
	overworld_legend.visible = not in_dungeon
	floors_box.visible = false
	if in_dungeon:
		_dungeon = GameState.current_dungeon_state()
		_dungeon.changed.connect(refresh)
		_show_dungeon()
	else:
		_show_overworld()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _in_dungeon() or _map == null:
		return
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backward")
	direction += Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	if direction:
		direction = direction.limit_length()
		_move_cursor(_cursor_point + direction * CURSOR_SPEED / canvas.scale.x * delta)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _in_dungeon():
		_dungeon_input(event)
	elif _map:
		_overworld_input(event)


# --- Mazmorra ---

func _show_dungeon() -> void:
	var dungeon_node := _find(Dungeon) as Dungeon
	title.text = dungeon_node.display_name if dungeon_node and not dungeon_node.display_name.is_empty() else "MAP_TITLE_DUNGEON"
	subtitle.text = dungeon_node.floor_name if dungeon_node else ""
	(%MapItem as MapDungeonItem).show_owned(_dungeon.has_map)
	(%CompassItem as MapDungeonItem).show_owned(_dungeon.has_compass)
	(%BossKeyItem as MapDungeonItem).show_owned(_dungeon.has_boss_key)
	(%KeysItem as MapDungeonItem).show_owned(_dungeon.small_keys > 0, _dungeon.small_keys)
	var current := _current_room()
	var levels := _levels()
	if _view_level == null or not _view_level in levels:
		_view_level = current.floor_level() if current else 0
	var level: int = _view_level
	var dungeon_floor := _floor_node(level)
	if dungeon_floor and not dungeon_floor.display_name.is_empty():
		subtitle.text = dungeon_floor.display_name
	_show_floors(levels, current)
	var rooms := MapData.rooms_on(get_tree(), level)
	if rooms.is_empty():
		return
	var low := Vector2i(1 << 20, 1 << 20)
	var high := -low
	for room: Room in rooms:
		low = low.min(room.map_cell)
		high = high.max(room.map_cell)
	cells.custom_minimum_size = Vector2(high - low + Vector2i.ONE) * STEP - Vector2(12, 12)
	var player := Players.lead()
	for room: Room in rooms:
		var visited := _dungeon.was_visited(room.room_index)
		if not visited and not _dungeon.has_map and room != current:
			continue
		var cell := MapRoomCell.create()
		cell.name = "Cell_%s" % room.name
		cell.room_name = room.display_name
		cell.state = MapRoomCell.State.CURRENT if room == current else (MapRoomCell.State.VISITED if visited else MapRoomCell.State.MAPPED)
		cell.here = room == current
		if cell.here and player:
			var forward := player.model.global_basis.z
			cell.facing = atan2(forward.x, -forward.z)
		if _dungeon.has_compass:
			cell.boss = room.boss_room
			for chest in _chests_in(room):
				if chest.interactable.enabled:
					cell.closed_chests += 1
				else:
					cell.opened_chests += 1
		cell.position = Vector2(room.map_cell - low) * STEP
		rooms_layer.add_child(cell)
		_room_cells[room] = cell
	_show_doors(low)
	var kept: Array = _room_cells.keys().filter(func(room: Room) -> bool: return room.map_cell == _keep_cell)
	_keep_cell = null
	_focus_room(kept[0] if not kept.is_empty() else current if _room_cells.has(current) else _room_cells.keys().front() if not _room_cells.is_empty() else null)


## Columna de pisos (solo si la mazmorra tiene más de uno), de arriba abajo.
func _show_floors(levels: Array, current: Room) -> void:
	floors_box.visible = levels.size() > 1
	if not floors_box.visible:
		return
	for level: int in levels:
		var button := MapFloorButton.create()
		button.name = "Floor_%d" % level
		button.level = level
		button.code = _floor_node(level).code()
		button.floor_name = _floor_node(level).display_name
		button.selected = level == _view_level
		button.here = current != null and current.floor_level() == level
		if _dungeon.has_compass:
			var rooms := MapData.rooms_on(get_tree(), level)
			button.boss = rooms.any(func(room: Room) -> bool: return room.boss_room)
			button.chest = rooms.any(func(room: Room) -> bool: return _chests_in(room).any(func(chest: Chest) -> bool: return chest.interactable.enabled))
		button.pressed.connect(view_floor.bind(level))
		floor_buttons.add_child(button)
	_refresh_floor_icons()


func _refresh_floor_icons() -> void:
	up_icon.texture = InputPrompts.icon_for_current(&"map_floor_up")
	down_icon.texture = InputPrompts.icon_for_current(&"map_floor_down")


## Pisos de la mazmorra, de arriba abajo.
func _levels() -> Array:
	var levels := get_tree().get_nodes_in_group(DungeonFloor.GROUP).map(func(node: DungeonFloor) -> int: return node.level)
	levels.sort()
	levels.reverse()
	return levels


func _floor_node(level: int) -> DungeonFloor:
	for node: DungeonFloor in get_tree().get_nodes_in_group(DungeonFloor.GROUP):
		if node.level == level:
			return node
	return null


func viewed_level() -> int:
	return _view_level if _view_level != null else 0


## Mira otro piso; el cursor queda en la misma celda (los pisos comparten planta).
func view_floor(level: int) -> void:
	if level == _view_level:
		return
	_keep_cell = _focused_room.map_cell if _focused_room else null
	_view_level = level
	Feel.ui(&"ui_move")
	refresh()


## Puertas con nodo Door (con llave, jefe, persianas, interruptor) y pasos libres del kit, junto a las salas que se ven.
func _show_doors(low: Vector2i) -> void:
	for door: Array in MapData.doors(get_tree()):
		var point: Vector3 = door[0]
		var shown := _room_cells.keys().filter(func(room: Room) -> bool: return MapData.near_room(room, point))
		if shown.is_empty():
			continue
		var on_grid := MapData.room_grid_point(get_tree(), point, shown[0]) - Vector2(low)
		doors_layer.add_child(MapMark.create(door[1], on_grid * STEP + MapRoomCell.SIZE / 2.0))


func _dungeon_input(event: InputEvent) -> void:
	for pair in [[&"map_floor_up", 1], [&"map_floor_down", -1]]:
		if event.is_action_pressed(pair[0]):
			var levels := _levels()
			var next: int = levels.find(_view_level) - pair[1]
			if next >= 0 and next < levels.size():
				view_floor(levels[next])
			get_viewport().set_input_as_handled()
			return
	if _focused_room == null:
		return
	var direction := Vector2i.ZERO
	for pair in DIRECTIONS:
		if event.is_action_pressed(pair[0], true):
			direction = pair[1]
	if direction:
		var next := _neighbor(_focused_room, direction)
		if next:
			_focus_room(next)
			Feel.ui(&"ui_move")
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		for room in _room_cells:
			var cell := _room_cells[room]
			if Rect2(cell.global_position, cell.size).has_point(event.global_position) and room != _focused_room:
				_focus_room(room)


## La sala visible más cercana en esa dirección.
func _neighbor(from: Room, direction: Vector2i) -> Room:
	var best: Room
	var best_distance := INF
	for room in _room_cells:
		var apart := Vector2(room.map_cell - from.map_cell)
		if room == from or apart.normalized().dot(Vector2(direction)) < 0.7:
			continue
		if apart.length() < best_distance:
			best_distance = apart.length()
			best = room
	return best


func focused_room() -> Room:
	return _focused_room


func _focus_room(room: Room) -> void:
	_focused_room = room
	room_cursor.visible = room != null
	_clear(focus_stats)
	if room == null:
		focus_title.text = ""
		focus_text.text = ""
		return
	var cell := _room_cells[room]
	room_cursor.frame_size = MapRoomCell.SIZE + Vector2(20, 20)
	room_cursor.place(cell.position + MapRoomCell.SIZE / 2.0)
	focus_title.text = room.display_name
	var notes: Array[String] = []
	if not _dungeon.was_visited(room.room_index):
		notes.append(tr("MAP_NOT_VISITED"))
	if room.boss_room and _dungeon.has_compass:
		notes.append(tr("MAP_BOSS"))
	if _dungeon.has_compass:
		var closed := _chests_in(room).filter(func(chest: Chest) -> bool: return chest.interactable.enabled).size()
		if closed > 0:
			notes.append(tr_n("MAP_CHESTS_CLOSED", "MAP_CHESTS_CLOSED_PLURAL", closed).format({count = closed}))
	if notes.is_empty():
		notes.append(tr("MAP_NOTHING_PENDING"))
	focus_text.text = " · ".join(notes)


func _chests_in(room: Room) -> Array:
	return MapData.chests_in(get_tree(), room)


# --- Overworld ---

func _show_overworld() -> void:
	_map = _find(OverworldMap) as OverworldMap
	title.text = _map.display_name if _map and not _map.display_name.is_empty() else "MAP_TITLE_OVERWORLD"
	overworld_image.texture = _map.texture if _map else null
	var reveal := overworld_image.material as ShaderMaterial
	reveal.set_shader_parameter(&"explored", ImageTexture.create_from_image(GameState.map_revealed) if GameState.map_revealed else null)
	if _map:
		_map.snapshot()
	marker.visible = _map != null
	cursor.visible = _map != null
	focus_title.text = ""
	focus_text.text = ""
	subtitle.text = ""
	if _map == null:
		return
	var regions := {}
	for zone: AreaZone in _zones():
		regions[zone.display_name] = regions.get(zone.display_name, false) or zone.is_visited()
	subtitle.text = tr("MAP_ZONES_EXPLORED").format({done = regions.values().count(true), total = regions.size()})
	var portals := TravelPortal.all(get_tree())
	if not portals.is_empty():
		subtitle.text += " · " + tr("MAP_PORTALS_LIT").format({done = portals.filter(func(portal: TravelPortal) -> bool: return portal.lit).size(), total = portals.size()})
	_place_overworld()


## Marcas, pines, flecha y cursor sobre la foto; se rehace cuando la foto cambia de tamaño.
func _place_overworld() -> void:
	if not is_instance_valid(_map) or _in_dungeon() or not is_inside_tree() or get_tree().current_scene == null:
		return
	_clear(marks)
	if _image_rect().size == Vector2.ZERO:
		return
	_set_zoom(_zoomed)
	var zones := _zones()
	var visited_regions := zones.filter(func(zone: AreaZone) -> bool: return zone.is_visited()).map(func(zone: AreaZone) -> String: return zone.display_name)
	for zone: AreaZone in zones:
		var bounds := zone.bounds()
		if zone.region_label and not zone.display_name.is_empty() and zone.display_name in visited_regions:
			var label: Label = ZONE_NAME_SCENE.instantiate()
			label.text = tr(zone.display_name)
			var rect := _world_rect_to_map(bounds)
			label.position = rect.position
			label.size = rect.size
			marks.add_child(label)
	for place: MapPlace in get_tree().current_scene.find_children("*", "MapPlace", true, false):
		var zone := _zone_at(Vector2(place.global_position.x, place.global_position.z))
		if zone and not zone.is_visited() or not place.is_revealed():
			continue
		var at := world_to_map(Vector2(place.global_position.x, place.global_position.z))
		marks.add_child(MapMark.create(MapMark.Kind.CAVE if place.kind == MapPlace.Kind.CAVE else MapMark.Kind.ENTRANCE, at))
		var name_label: Label = PLACE_NAME_SCENE.instantiate()
		name_label.text = tr(place.display_name)
		marks.add_child(name_label)
		name_label.position = at + Vector2(-name_label.get_minimum_size().x / 2.0, 10.0)
	for portal in TravelPortal.all(get_tree()):
		if portal.lit:
			marks.add_child(MapMark.create(MapMark.Kind.PORTAL, _portal_point(portal)))
	for chest: Chest in get_tree().get_nodes_in_group(&"chests"):
		if not chest.interactable.enabled:
			_add_mark(MapMark.Kind.CHEST_OPEN, chest.global_position)
	_cache_scene()
	for tablet: Tablet in _tablets:
		if tablet.is_read():
			_add_mark(MapMark.Kind.TABLET, tablet.global_position)
	_refresh_pins()
	var player := Players.lead()
	if player:
		marker.position = world_to_map(Vector2(player.global_position.x, player.global_position.z))
		var forward := player.model.global_basis.z
		marker.rotation = atan2(forward.x, -forward.z)
		marker.queue_redraw()
		_move_cursor(marker.position)
	else:
		_move_cursor(_image_rect().get_center())


func _overworld_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		if can_travel():
			_ask_travel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"item_1"):
		if GameState.toggle_pin(map_to_world(cursor.position)):
			Feel.ui(&"ui_accept")
		else:
			Feel.sfx(&"deny", Vector3.ZERO)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"item_2"):
		_set_zoom(not _zoomed)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_set_zoom(event.button_index == MOUSE_BUTTON_WHEEL_UP)
	elif event is InputEventMouseMotion and overworld.get_global_rect().has_point(event.global_position):
		_move_cursor(canvas.get_global_transform().affine_inverse() * event.global_position)


func _set_zoom(zoomed: bool) -> void:
	_zoomed = zoomed
	canvas.scale = Vector2.ONE * (ZOOM if zoomed else 1.0)
	_follow_cursor()
	hints_changed.emit()


func _move_cursor(point: Vector2) -> void:
	var image := _image_rect()
	_cursor_point = point.clamp(image.position, image.end)
	var portal := _portal_near(_cursor_point)
	cursor.place(_portal_point(portal) if portal else _cursor_point)
	_follow_cursor()
	var changed := portal != _focused_portal
	_focused_portal = portal
	_focus_zone(_zone_at(map_to_world(cursor.position)))
	if changed:
		hints_changed.emit()


func _portal_near(point: Vector2) -> TravelPortal:
	var best: TravelPortal
	var best_distance := PORTAL_SNAP / canvas.scale.x
	for portal in TravelPortal.all(get_tree()):
		var distance := _portal_point(portal).distance_to(point)
		if portal.lit and distance <= best_distance:
			best = portal
			best_distance = distance
	return best


func _portal_point(portal: TravelPortal) -> Vector2:
	return world_to_map(Vector2(portal.global_position.x, portal.global_position.z))


func focused_portal() -> TravelPortal:
	return _focused_portal


## Hay un portal enganchado y no es de la región donde ya está el player.
func can_travel() -> bool:
	if _focused_portal == null or _in_dungeon():
		return false
	var player := Players.lead()
	if player == null:
		return true
	var here := _zone_at(Vector2(player.global_position.x, player.global_position.z))
	var there := _zone_at(Vector2(_focused_portal.global_position.x, _focused_portal.global_position.z))
	return here == null or there == null or here.display_name != there.display_name


func _ask_travel() -> void:
	var portal := _focused_portal
	if not can_travel():
		return
	var dialog := ConfirmDialog.ask(tr("MAP_TRAVEL_ASK").format({name = tr(portal.display_name)}), "MAP_TRAVEL", TRAVEL_DIALOG)
	dialog.answered.connect(func(confirmed: bool) -> void:
		if confirmed:
			MenuStack.clear()
			portal.travel())


## Con zoom, el lienzo se corre para que el cursor no salga de la tarjeta.
func _follow_cursor() -> void:
	if not _zoomed:
		canvas.position = Vector2.ZERO
		return
	var view := overworld.size
	var target := view / 2.0 - cursor.position * canvas.scale
	canvas.position = target.clamp(view - view * canvas.scale, Vector2.ZERO)


func _focus_zone(zone: AreaZone) -> void:
	var key := [zone, _focused_portal]
	if key == _focus_key:
		return
	_focus_key = key
	_clear(focus_stats)
	focus_text.text = ""
	portal_title.visible = _focused_portal != null
	focus_title.visible = _focused_portal == null
	travel_button.visible = can_travel()
	if _focused_portal:
		portal_name.text = tr("MAP_PORTAL").format({name = tr(_focused_portal.display_name)})
	if zone == null:
		focus_title.text = ""
		return
	focus_title.text = zone.display_name
	if not zone.is_visited():
		focus_text.text = "MAP_UNEXPLORED"
		return
	var region := _zones().filter(func(other: AreaZone) -> bool: return other.display_name == zone.display_name and other.is_visited())
	var inside := func(point: Vector3) -> bool: return region.any(func(other: AreaZone) -> bool: return other.contains(point))
	var chests := get_tree().get_nodes_in_group(&"chests").filter(func(chest: Chest) -> bool: return inside.call(chest.global_position))
	_count_row("MAP_CHESTS", chests.filter(func(chest: Chest) -> bool: return not chest.interactable.enabled).size(), chests.size())
	var tablets := _tablets.filter(func(tablet: Tablet) -> bool: return inside.call(tablet.global_position))
	_count_row("MAP_TABLETS_READ", tablets.filter(func(tablet: Tablet) -> bool: return tablet.is_read()).size(), tablets.size())
	var pieces := _pieces.filter(func(piece: HeartPiece) -> bool: return inside.call(piece.global_position))
	_count_row("MAP_HEART_PIECES", pieces.filter(func(piece: HeartPiece) -> bool: return piece.taken).size(), pieces.size())
	if _focused_portal and not can_travel():
		focus_text.text = "MAP_TRAVEL_HERE"
	elif focus_stats.get_child_count() == 0:
		focus_text.text = "MAP_NOTHING_HIDDEN"


func _count_row(label: String, done: int, total: int) -> void:
	if total > 0:
		_stat(focus_stats, label, tr("MAP_COUNT").format({done = done, total = total}), done < total)


func _refresh_pins() -> void:
	if _map == null or not is_inside_tree() or _image_rect().size == Vector2.ZERO:
		return
	_clear(pins)
	for pin in GameState.map_pins:
		pins.add_child(MapMark.create(MapMark.Kind.PIN, world_to_map(pin)))
	pins_label.text = tr("MAP_PINS").format({count = GameState.map_pins.size(), max = GameState.MAX_MAP_PINS})


func _add_mark(kind: MapMark.Kind, point: Vector3) -> void:
	var zone := _zone_at(Vector2(point.x, point.z))
	if zone and not zone.is_visited():
		return
	marks.add_child(MapMark.create(kind, world_to_map(Vector2(point.x, point.z))))


func _zones() -> Array:
	_cache_scene()
	return _zone_list


func _cache_scene() -> void:
	var scene := get_tree().current_scene
	if scene == _cached_scene:
		return
	_cached_scene = scene
	_zone_list = scene.find_children("*", "AreaZone", true, false) if scene else []
	_tablets = scene.find_children("*", "Tablet", true, false) if scene else []
	_pieces = scene.find_children("*", "HeartPiece", true, false) if scene else []


func _zone_at(point: Vector2) -> AreaZone:
	for zone: AreaZone in _zones():
		if zone.bounds().has_point(point):
			return zone
	return null


## Dónde se dibuja la foto dentro de su TextureRect (mantiene la proporción, centrada).
func _image_rect() -> Rect2:
	var rect := Rect2(overworld_image.position, overworld_image.size)
	var texture := overworld_image.texture
	if texture == null:
		return rect
	var fit := minf(rect.size.x / texture.get_width(), rect.size.y / texture.get_height())
	var drawn := texture.get_size() * fit
	return Rect2(rect.position + (rect.size - drawn) / 2.0, drawn)


## XZ del mundo → coordenadas del lienzo del mapa.
func world_to_map(point: Vector2) -> Vector2:
	var image := _image_rect()
	return image.position + (point - _map.world_rect.position) / _map.world_rect.size * image.size


func map_to_world(point: Vector2) -> Vector2:
	var image := _image_rect()
	return _map.world_rect.position + (point - image.position) / image.size * _map.world_rect.size


func _world_rect_to_map(rect: Rect2) -> Rect2:
	var start := world_to_map(rect.position)
	return Rect2(start, world_to_map(rect.end) - start)


# --- Común ---

func _in_dungeon() -> bool:
	return GameState.current_dungeon != &""


func _current_room() -> Room:
	return MapData.current_room(get_tree())


func _find(type: Variant) -> Node:
	return MapData.find(get_tree(), type)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _stat(container: Container, label: String, value: String, muted := false) -> void:
	container.add_child(StatRow.create(label, value, muted or value == "COMMON_NO"))
