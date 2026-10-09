extends Control
## Pestaña Mapa. En mazmorra: las salas (visitadas; con mapa, todas; con brújula, cofres sin abrir y el jefe)
## y dónde está el player. En el overworld: el mapa simple de la zona con la posición del player.

const STEP := MapRoomCell.SIZE + Vector2(12, 12)

## Lo lee el menú de pausa: esta pestaña no usa el botón de aceptar.
var accept_label := ""

@onready var cells: Control = %Cells
@onready var overworld: Control = %Overworld
@onready var overworld_image: TextureRect = %OverworldImage
@onready var marker: Control = %Marker
@onready var title: Label = %MapTitle
@onready var subtitle: Label = %MapSubtitle
@onready var stats: VBoxContainer = %MapStats
@onready var legend: VBoxContainer = %Legend

var _dungeon: DungeonState


func _ready() -> void:
	GameState.dungeon_changed.connect(refresh)
	GameState.loaded.connect(refresh)
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree():
			refresh())
	marker.draw.connect(func() -> void: MapRoomCell.draw_arrow(marker, Vector2.ZERO, 0.0))
	refresh()


func refresh() -> void:
	if _dungeon and _dungeon.changed.is_connected(refresh):
		_dungeon.changed.disconnect(refresh)
	_dungeon = null
	for child in cells.get_children():
		cells.remove_child(child)
		child.queue_free()
	for child in stats.get_children():
		stats.remove_child(child)
		child.queue_free()
	var in_dungeon := GameState.current_dungeon != &""
	cells.visible = in_dungeon
	legend.visible = in_dungeon
	overworld.visible = not in_dungeon
	if in_dungeon:
		_dungeon = GameState.current_dungeon_state()
		_dungeon.changed.connect(refresh)
		_show_dungeon()
	else:
		_show_overworld()


func _show_dungeon() -> void:
	var dungeon_node := _find(Dungeon) as Dungeon
	title.text = dungeon_node.display_name if dungeon_node and not dungeon_node.display_name.is_empty() else "Mazmorra"
	subtitle.text = dungeon_node.floor_name if dungeon_node else ""
	_stat("Mapa", "Obtenido" if _dungeon.has_map else "No")
	_stat("Brújula", "Obtenida" if _dungeon.has_compass else "No")
	_stat("Llave del jefe", "Sí" if _dungeon.has_boss_key else "No")
	_stat("Llaves chicas", str(_dungeon.small_keys))
	var rooms := get_tree().get_nodes_in_group(Room.GROUP)
	if rooms.is_empty():
		return
	var low := Vector2i(1 << 20, 1 << 20)
	var high := -low
	for room: Room in rooms:
		low = low.min(room.map_cell)
		high = high.max(room.map_cell)
	cells.custom_minimum_size = Vector2(high - low + Vector2i.ONE) * STEP - Vector2(12, 12)
	var current := _current_room()
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
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
			for chest: Chest in get_tree().get_nodes_in_group(&"chests"):
				if room.contains(chest.global_position):
					if chest.interactable.enabled:
						cell.closed_chests += 1
					else:
						cell.opened_chests += 1
		cell.position = Vector2(room.map_cell - low) * STEP
		cells.add_child(cell)


func _show_overworld() -> void:
	var map := _find(OverworldMap) as OverworldMap
	title.text = map.display_name if map and not map.display_name.is_empty() else "Overworld"
	subtitle.text = ""
	overworld_image.texture = map.texture if map else null
	marker.visible = map != null
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	if map == null or player == null:
		return
	var at := Vector2(player.global_position.x, player.global_position.z) - map.world_rect.position
	var normalized := at / map.world_rect.size
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(player):
		return
	marker.position = overworld_image.position + normalized.clamp(Vector2.ZERO, Vector2.ONE) * overworld_image.size
	var forward := player.model.global_basis.z
	marker.rotation = atan2(forward.x, -forward.z)
	marker.queue_redraw()


func _current_room() -> Room:
	var camera := get_tree().get_first_node_in_group(&"room_camera") as TopDownCamera
	return camera.room if camera else null


func _find(type: Variant) -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for child in scene.get_children():
		if is_instance_of(child, type):
			return child
	return null


func _stat(label: String, value: String) -> void:
	stats.add_child(StatRow.create(label, value, value == "No"))
