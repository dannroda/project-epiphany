extends Control
## Minimapa del HUD (mockups HUD_Minimap_Dungeon y HUD_Minimap_Overworld). En mazmorra: las salas alrededor de la
## actual (3×3) con sus puertas, los cofres (con brújula) y el player. En el overworld: la foto cenital alrededor del
## player, que se va descubriendo a medida que se recorre (lo demás se funde en tinta), y las marcas cercanas. Se oculta con un menú, una caja de texto o el
## item get abiertos, en la sala del jefe y si se apaga en Opciones.

const MapData := preload("res://src/ui/menus/map_data.gd")
const CELL := Vector2(46, 34)
const PITCH := Vector2(53, 38)
const GRID_ORIGIN := Vector2(10, 8)
const DOOR_SIZE := 7.0
## Píxeles del minimapa por metro en el overworld.
const OVERWORLD_SCALE := 5.0

## Los marcos de la pestaña Mapa, a esta escala.
@export var frame_scale := 0.5
@export var room_style: StyleBox
@export var mapped_style: StyleBox
@export var current_style: StyleBox
## Con un player debajo en pantalla, el minimapa baja a esta opacidad para no taparlo.
@export var covered_alpha := 0.3
@export var fade_rate := 10.0
## Alto del player que tiene que quedar a la vista (m) y margen alrededor del minimapa (px).
@export var player_height := 1.8
@export var covered_margin := 12.0

@onready var view: Control = %View
## Las marcas y la flecha del overworld van aparte, fuera de la niebla.
@onready var marks: Control = %Marks
@onready var fog: ShaderMaterial = view.material
@onready var floor_tag: Control = %FloorTag
@onready var floor_code: Label = %Code
@onready var floor_name: Label = %FloorName

var _scene: Node
var _map: OverworldMap
var _doors: Array = []
## Lo de la escena que no cambia, leído una vez en `_bind`: puertas con nodo, pasos libres, paso entre salas, marcas.
var _door_nodes: Array = []
var _passages: Array = []
var _passages_read := false
var _pitch := Vector2.ZERO
var _portals: Array = []
var _tablets: Array = []
var _zones: Array = []
var _revealed: ImageTexture


func _ready() -> void:
	view.draw.connect(_draw_view)
	marks.draw.connect(_draw_marks)
	fog.set_shader_parameter(&"ink", MapRoomCell.INK)
	GameState.loaded.connect(_setup_reveal)
	GameState.map_revealed_changed.connect(func() -> void:
		if _revealed and GameState.map_revealed:
			_revealed.update(GameState.map_revealed))


func _process(delta: float) -> void:
	var tree := get_tree()
	if tree.current_scene != _scene:
		_bind(tree.current_scene)
	var room := MapData.current_room(tree)
	visible = Settings.get_value(&"minimap") and not MenuStack.is_open() and Players.lead() != null \
		and (_in_dungeon() and room != null or not _in_dungeon() and _map != null) and not (room and room.boss_room)
	_show_floor(room if visible and _in_dungeon() else null)
	if not visible:
		return
	modulate.a = lerpf(modulate.a, covered_alpha if covers_a_player() else 1.0, 1.0 - exp(-fade_rate * delta))
	if _in_dungeon():
		if not _passages_read:
			_passages = MapData.passages(tree, _door_nodes)
			_passages_read = true
		_doors = MapData.door_marks(_door_nodes) + _passages
	view.queue_redraw()
	marks.queue_redraw()


func covers_a_player() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var rect := get_global_rect().grow(covered_margin)
	for player in Players.all:
		for height in [0.0, player_height]:
			var point: Vector3 = player.global_position + Vector3.UP * height
			if not camera.is_position_behind(point) and rect.has_point(camera.unproject_position(point)):
				return true
	return false


## Etiqueta del piso arriba del minimapa (solo en mazmorras de varios pisos).
func _show_floor(room: Room) -> void:
	var dungeon_floor := DungeonFloor.of(room) if room else null
	if get_tree().get_nodes_in_group(DungeonFloor.GROUP).size() < 2:
		dungeon_floor = null
	floor_tag.visible = dungeon_floor != null
	if dungeon_floor:
		floor_code.text = dungeon_floor.code()
		floor_name.text = dungeon_floor.display_name


func _bind(scene: Node) -> void:
	_scene = scene
	var tree := get_tree()
	_map = MapData.find(tree, OverworldMap) as OverworldMap if scene else null
	_door_nodes = MapData.door_nodes(tree)
	_passages = []
	_passages_read = false
	_pitch = MapData.room_pitch(tree, Vector2.ZERO)
	_portals = scene.find_children("*", "Portal", true, false) if scene else []
	_tablets = scene.find_children("*", "Tablet", true, false) if scene else []
	_zones = scene.find_children("*", "AreaZone", true, false) if scene else []
	if _map:
		_map.snapshot()
	_setup_reveal()


## Lo descubierto del overworld (GameState.map_revealed, lo pinta OverworldMap): el shader funde la foto en tinta donde
## todavía no se pasó.
func _setup_reveal() -> void:
	view.material = fog if is_instance_valid(_map) and not _in_dungeon() else null
	if view.material == null:
		return
	var rect := _map.world_rect
	GameState.ensure_map_revealed(_map.reveal_key(), rect)
	_revealed = ImageTexture.create_from_image(GameState.map_revealed)
	fog.set_shader_parameter(&"explored", _revealed)
	fog.set_shader_parameter(&"world_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))


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
	var around := current.map_rect().grow(1)
	for room: Room in MapData.rooms_on(get_tree(), current.floor_level()):
		if around.intersects(room.map_rect()) and (room == current or dungeon.has_map or dungeon.was_visited(room.room_index)):
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
		var visited := dungeon.was_visited(room.room_index)
		var rect := room_rect(room, current)
		var style := current_style if room == current else room_style if visited else mapped_style
		view.draw_set_transform(rect.position, 0.0, Vector2.ONE * frame_scale)
		view.draw_style_box(style, Rect2(Vector2.ZERO, rect.size / frame_scale))
		view.draw_set_transform(Vector2.ZERO)
		if dungeon.has_compass:
			_draw_room_icons(room, rect)
	for door: Array in _doors:
		_draw_door(door[0], door[1], shown, current)
	var player := Players.lead()
	if player:
		var at := MapData.grid_point(player.global_position, current, _pitch) - current.map_center()
		var forward := player.model.global_basis.z
		var here := room_rect(current, current)
		var point := (_cell_origin(at) + CELL / 2.0).clamp(here.position + Vector2(7, 7), here.end - Vector2(7, 7))
		_draw_small(view, func() -> void: MapRoomCell.draw_arrow(view, Vector2.ZERO, atan2(forward.x, -forward.z)), point, 0.8)


## Celda `apart` (relativa al centro de la sala actual) → esquina de su rectángulo.
func _cell_origin(apart: Vector2) -> Vector2:
	return GRID_ORIGIN + (apart + Vector2.ONE) * PITCH


## El rectángulo de una sala entera (todas sus celdas), con la actual centrada.
func room_rect(room: Room, current: Room) -> Rect2:
	var size := Vector2(room.map_rect().size)
	return Rect2(_cell_origin(Vector2(room.map_cell) - current.map_center()), size * PITCH - (PITCH - CELL))


func _draw_room_icons(room: Room, rect: Rect2) -> void:
	var center := rect.get_center()
	if room.boss_room:
		_draw_small(view, func() -> void: MapRoomCell.draw_eye(view, Vector2.ZERO), center, 0.7)
		return
	var closed := MapData.chests_in(get_tree(), room).filter(func(chest: Chest) -> bool: return not chest.is_opened())
	if not closed.is_empty():
		_draw_small(view, func() -> void: MapRoomCell.draw_chest(view, Vector2.ZERO, MapRoomCell.GOLD), center, 0.7)


func _draw_door(point: Vector3, kind: MapMark.Kind, shown: Array[Room], current: Room) -> void:
	var near := shown.filter(func(room: Room) -> bool: return MapData.near_room(room, point))
	if near.is_empty():
		return
	var on_grid := MapData.grid_point(point, near[0], _pitch)
	var at := on_grid - current.map_center()
	var reach := Vector2(1.6, 1.6) + Vector2(current.map_rect().size - Vector2i.ONE) / 2.0
	if absf(at.x) > reach.x or absf(at.y) > reach.y:
		return
	var center := _cell_origin(at) + CELL / 2.0
	var side := on_grid - on_grid.round()
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
func _draw_small(canvas: Control, draw: Callable, at: Vector2, scale_factor: float) -> void:
	canvas.draw_set_transform(at, 0.0, Vector2.ONE * scale_factor)
	draw.call()
	canvas.draw_set_transform(Vector2.ZERO)


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


func _draw_marks() -> void:
	if _in_dungeon() or _map == null:
		return
	var player := Players.lead()
	if player == null:
		return
	var center := marks.size / 2.0
	var here := Vector2(player.global_position.x, player.global_position.z)
	var world_view := Rect2(here - center / OVERWORLD_SCALE, marks.size / OVERWORLD_SCALE)
	for portal: Portal in _portals.filter(is_instance_valid):
		_draw_mark(func() -> void: MapRoomCell.draw_entrance(marks, Vector2.ZERO, MapRoomCell.TEXT), portal.global_position, here, world_view)
	for chest: Chest in get_tree().get_nodes_in_group(Chest.GROUP):
		if chest.is_opened():
			_draw_mark(func() -> void: MapRoomCell.draw_chest(marks, Vector2.ZERO, MapRoomCell.GREY), chest.global_position, here, world_view)
	for tablet: Tablet in _tablets.filter(is_instance_valid):
		if tablet.is_read():
			_draw_mark(func() -> void: MapRoomCell.draw_tablet(marks, Vector2.ZERO, MapRoomCell.NAME), tablet.global_position, here, world_view)
	for pin: Vector2 in GameState.map_pins:
		_draw_mark(func() -> void: MapRoomCell.draw_pin(marks, Vector2.ZERO), Vector3(pin.x, 0, pin.y), here, world_view)
	var forward := player.model.global_basis.z
	_draw_small(marks, func() -> void: MapRoomCell.draw_arrow(marks, Vector2.ZERO, atan2(forward.x, -forward.z)), center, 0.8)


func _to_view(rect: Rect2, here: Vector2) -> Rect2:
	return Rect2(view.size / 2.0 + (rect.position - here) * OVERWORLD_SCALE, rect.size * OVERWORLD_SCALE)


## Las marcas de zonas sin explorar no se muestran (como en la pestaña Mapa).
func _draw_mark(draw: Callable, point: Vector3, here: Vector2, world_view: Rect2) -> void:
	var flat := Vector2(point.x, point.z)
	if not world_view.grow(1.0).has_point(flat):
		return
	for zone in _zones:
		if is_instance_valid(zone) and not zone.is_visited() and zone.bounds().has_point(flat):
			return
	_draw_small(marks, draw, marks.size / 2.0 + (flat - here) * OVERWORLD_SCALE, 0.75)
