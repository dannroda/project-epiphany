extends Control
## Minimapa del HUD (mockups HUD_Minimap_Dungeon y HUD_Minimap_Overworld). En mazmorra: las salas alrededor de la
## actual (3×3) con sus puertas, los cofres (con brújula) y el player. En el overworld: la foto cenital alrededor del
## player, que se va descubriendo a medida que se recorre (lo demás se funde en tinta), y las marcas cercanas. Se oculta con un menú, una caja de texto o el
## item get abiertos, en la sala del jefe y si se apaga en Opciones.

const MapData := preload("res://src/ui/menus/map_data.gd")
const CELL := Vector2(46, 34)
const PITCH := Vector2(53, 38)
const GRID_ORIGIN := Vector2(10, 8)
const ROOM_FILL := Color("#3a4250")
const DOOR_SIZE := 7.0
## Píxeles del minimapa por metro en el overworld.
const OVERWORLD_SCALE := 5.0
## Cada cuánto se vuelven a leer las puertas (se abren y se cierran).
const DOORS_REFRESH := 0.5
## Lo que cada player deja descubierto a su alrededor en el overworld (m); el borde se funde en REVEAL_FADE.
const REVEAL_RADIUS := 11.0
const REVEAL_FADE := 5.0
## Cuánto tiene que moverse un player para volver a pintar lo descubierto (m).
const REVEAL_STEP := 1.0

@onready var view: Control = %View
@onready var fog: ShaderMaterial = view.material

var _scene: Node
var _map: OverworldMap
var _doors: Array = []
var _doors_age := INF
var _room_style := _room_box(MapRoomCell.BORDER)
var _current_style := _room_box(MapRoomCell.GOLD)
var _revealed: ImageTexture
var _painted_at: Dictionary[PlayerCharacter, Vector2] = {}


func _ready() -> void:
	view.draw.connect(_draw_view)
	fog.set_shader_parameter(&"ink", MapRoomCell.INK)
	GameState.loaded.connect(_setup_reveal)


static func _room_box(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ROOM_FILL
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style


func _process(delta: float) -> void:
	var tree := get_tree()
	if tree.current_scene != _scene:
		_bind(tree.current_scene)
	var room := MapData.current_room(tree)
	visible = Settings.get_value(&"minimap") and not MenuStack.is_open() and Players.lead() != null \
		and (_in_dungeon() and room != null or not _in_dungeon() and _map != null) and not (room and room.boss_room)
	_reveal()
	if not visible:
		return
	_doors_age += delta
	if _in_dungeon() and _doors_age >= DOORS_REFRESH:
		_doors = MapData.doors(tree)
		_doors_age = 0.0
	view.queue_redraw()


func _bind(scene: Node) -> void:
	_scene = scene
	_doors_age = INF
	_map = MapData.find(get_tree(), OverworldMap) as OverworldMap if scene else null
	if _map:
		_map.snapshot()
	_setup_reveal()


## Lo descubierto del overworld (GameState.map_revealed, 1 px por metro): el shader funde la foto en tinta donde
## todavía no se pasó.
func _setup_reveal() -> void:
	_painted_at.clear()
	view.material = fog if is_instance_valid(_map) and not _in_dungeon() else null
	if view.material == null:
		return
	var rect := _map.world_rect
	var size := Vector2i(rect.size.ceil())
	if GameState.map_revealed == null or GameState.map_revealed.get_size() != size:
		GameState.map_revealed = Image.create_empty(size.x, size.y, false, Image.FORMAT_L8)
	_revealed = ImageTexture.create_from_image(GameState.map_revealed)
	fog.set_shader_parameter(&"explored", _revealed)
	fog.set_shader_parameter(&"world_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))


func _reveal() -> void:
	if view.material == null or GameState.map_revealed == null:
		return
	var changed := false
	for player in Players.all:
		var here := Vector2(player.global_position.x, player.global_position.z)
		if _painted_at.has(player) and _painted_at[player].distance_to(here) < REVEAL_STEP:
			continue
		_painted_at[player] = here
		_paint_reveal(GameState.map_revealed, here - _map.world_rect.position)
		changed = true
	if changed:
		_revealed.update(GameState.map_revealed)


static func _paint_reveal(image: Image, center: Vector2) -> void:
	var low := (center - Vector2.ONE * REVEAL_RADIUS).floor().max(Vector2.ZERO)
	var high := (center + Vector2.ONE * REVEAL_RADIUS).ceil().min(Vector2(image.get_size()) - Vector2.ONE)
	for y in range(int(low.y), int(high.y) + 1):
		for x in range(int(low.x), int(high.x) + 1):
			var value := 1.0 - smoothstep(REVEAL_RADIUS - REVEAL_FADE, REVEAL_RADIUS, center.distance_to(Vector2(x + 0.5, y + 0.5)))
			if value > image.get_pixel(x, y).r:
				image.set_pixel(x, y, Color(value, value, value))


func _in_dungeon() -> bool:
	return GameState.current_dungeon != &""


func _draw_view() -> void:
	if _in_dungeon():
		_draw_dungeon()
	elif _map:
		_draw_overworld()


# --- Mazmorra ---

## Las salas que muestra: la actual y las de alrededor (3×3) visitadas, o todas con el mapa.
func rooms_around() -> Array[Room]:
	var shown: Array[Room] = []
	var current := MapData.current_room(get_tree())
	var dungeon := GameState.current_dungeon_state() if _in_dungeon() else null
	if current == null or dungeon == null:
		return shown
	for room: Room in get_tree().get_nodes_in_group(Room.GROUP):
		var apart := room.map_cell - current.map_cell
		if absi(apart.x) <= 1 and absi(apart.y) <= 1 and (room == current or dungeon.has_map or dungeon.was_visited(room.room_index)):
			shown.append(room)
	return shown


func _draw_dungeon() -> void:
	var tree := get_tree()
	var current := MapData.current_room(tree)
	var dungeon := GameState.current_dungeon_state()
	var shown := rooms_around()
	if shown.is_empty():
		return
	for room in shown:
		var apart := room.map_cell - current.map_cell
		var visited := dungeon.was_visited(room.room_index)
		var rect := Rect2(_cell_origin(Vector2(apart)), CELL)
		if visited or room == current:
			view.draw_style_box(_current_style if room == current else _room_style, rect)
		else:
			MapRoomCell.draw_dashed_rect(view, rect.grow(-1), MapRoomCell.BORDER)
		if dungeon.has_compass:
			_draw_room_icons(room, rect)
	for door: Array in _doors:
		_draw_door(door[0], door[1], shown, current)
	var player := Players.lead()
	if player:
		var at := MapData.room_grid_point(tree, player.global_position, current) - Vector2(current.map_cell)
		var forward := player.model.global_basis.z
		var point := (_cell_origin(at) + CELL / 2.0).clamp(_cell_origin(Vector2.ZERO) + Vector2(7, 7), _cell_origin(Vector2.ZERO) + CELL - Vector2(7, 7))
		_draw_small(func() -> void: MapRoomCell.draw_arrow(view, Vector2.ZERO, atan2(forward.x, -forward.z)), point, 0.8)


## Celda `apart` (relativa a la sala actual) → esquina de su rectángulo.
func _cell_origin(apart: Vector2) -> Vector2:
	return GRID_ORIGIN + (apart + Vector2.ONE) * PITCH


func _draw_room_icons(room: Room, rect: Rect2) -> void:
	var center := rect.get_center()
	if room.boss_room:
		_draw_small(func() -> void: MapRoomCell.draw_eye(view, Vector2.ZERO), center, 0.7)
		return
	var closed := MapData.chests_in(get_tree(), room).filter(func(chest: Chest) -> bool: return chest.interactable.enabled)
	if not closed.is_empty():
		_draw_small(func() -> void: MapRoomCell.draw_chest(view, Vector2.ZERO, MapRoomCell.GOLD), center, 0.7)


func _draw_door(point: Vector3, kind: MapMark.Kind, shown: Array[Room], current: Room) -> void:
	var near := shown.filter(func(room: Room) -> bool: return room.bounds().grow(2.0).has_point(Vector2(point.x, point.z)))
	if near.is_empty():
		return
	var at := MapData.room_grid_point(get_tree(), point, near[0]) - Vector2(current.map_cell)
	if absf(at.x) > 1.6 or absf(at.y) > 1.6:
		return
	var center := _cell_origin(at) + CELL / 2.0
	var side := at - at.round()
	var size := Vector2(DOOR_SIZE, DOOR_SIZE) if absf(side.x) >= absf(side.y) else Vector2(DOOR_SIZE, 4)
	var rect := Rect2(center - size / 2.0, size)
	match kind:
		MapMark.Kind.DOOR_LOCKED:
			view.draw_rect(rect, MapRoomCell.GOLD)
		MapMark.Kind.DOOR_BOSS:
			view.draw_rect(rect, MapRoomCell.BOSS)
		MapMark.Kind.DOOR_SEALED:
			view.draw_rect(rect, MapRoomCell.INK)
			view.draw_rect(rect, MapRoomCell.SEALED, false, 1.5)
		_:
			view.draw_rect(rect, MapRoomCell.DOOR)


## Los íconos de la pestaña Mapa, achicados.
func _draw_small(draw: Callable, at: Vector2, scale_factor: float) -> void:
	view.draw_set_transform(at, 0.0, Vector2.ONE * scale_factor)
	draw.call()
	view.draw_set_transform(Vector2.ZERO)


# --- Overworld ---

func _draw_overworld() -> void:
	var player := Players.lead()
	if player == null or _map.texture == null:
		return
	var center := view.size / 2.0
	var here := Vector2(player.global_position.x, player.global_position.z)
	view.draw_rect(Rect2(Vector2.ZERO, view.size), MapRoomCell.INK)
	var world_view := Rect2(here - center / OVERWORLD_SCALE, view.size / OVERWORLD_SCALE)
	fog.set_shader_parameter(&"view_world", Vector4(world_view.position.x, world_view.position.y, world_view.size.x, world_view.size.y))
	fog.set_shader_parameter(&"view_size", view.size)
	var shown := world_view.intersection(_map.world_rect)
	if shown.has_area():
		var texture_scale := _map.texture.get_size() / _map.world_rect.size
		view.draw_texture_rect_region(_map.texture, _to_view(shown, here), Rect2((shown.position - _map.world_rect.position) * texture_scale, shown.size * texture_scale))
	for portal: Portal in get_tree().current_scene.find_children("*", "Portal", true, false):
		_draw_mark(func() -> void: MapRoomCell.draw_entrance(view, Vector2.ZERO, MapRoomCell.TEXT), portal.global_position, here, world_view)
	for chest: Chest in get_tree().get_nodes_in_group(&"chests"):
		if not chest.interactable.enabled:
			_draw_mark(func() -> void: MapRoomCell.draw_chest(view, Vector2.ZERO, MapRoomCell.GREY), chest.global_position, here, world_view)
	for tablet: Tablet in get_tree().current_scene.find_children("*", "Tablet", true, false):
		if tablet.is_read():
			_draw_mark(func() -> void: MapRoomCell.draw_tablet(view, Vector2.ZERO, MapRoomCell.NAME), tablet.global_position, here, world_view)
	for pin: Vector2 in GameState.map_pins:
		_draw_mark(func() -> void: MapRoomCell.draw_pin(view, Vector2.ZERO), Vector3(pin.x, 0, pin.y), here, world_view)
	var forward := player.model.global_basis.z
	_draw_small(func() -> void: MapRoomCell.draw_arrow(view, Vector2.ZERO, atan2(forward.x, -forward.z)), center, 0.8)


func _to_view(rect: Rect2, here: Vector2) -> Rect2:
	return Rect2(view.size / 2.0 + (rect.position - here) * OVERWORLD_SCALE, rect.size * OVERWORLD_SCALE)


## Las marcas de zonas sin explorar no se muestran (como en la pestaña Mapa).
func _draw_mark(draw: Callable, point: Vector3, here: Vector2, world_view: Rect2) -> void:
	var flat := Vector2(point.x, point.z)
	if not world_view.grow(1.0).has_point(flat):
		return
	for zone: AreaZone in get_tree().current_scene.find_children("*", "AreaZone", true, false):
		if not zone.is_visited() and zone.bounds().has_point(flat):
			return
	_draw_small(draw, view.size / 2.0 + (flat - here) * OVERWORLD_SCALE, 0.75)
