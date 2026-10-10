@tool
class_name MapMark
extends Control
## Una marca sobre el mapa (entrada, cofre abierto, tablilla leída, pin, puerta de mazmorra), centrada en `position`.

enum Kind { ENTRANCE, CHEST_OPEN, TABLET, PIN, DOOR_OPEN, DOOR_LOCKED, DOOR_BOSS, DOOR_SEALED }

const SCENE_PATH := "res://src/ui/menus/map_mark.tscn"
const DOOR_SIZE := 16.0

@export var kind := Kind.ENTRANCE:
	set(value):
		kind = value
		queue_redraw()


static func create(mark_kind: Kind, at: Vector2) -> MapMark:
	var mark: MapMark = load(SCENE_PATH).instantiate()
	mark.kind = mark_kind
	mark.position = at - mark.custom_minimum_size / 2.0
	return mark


func _draw() -> void:
	var center := size / 2.0
	var door := Rect2(center - Vector2.ONE * DOOR_SIZE / 2.0, Vector2.ONE * DOOR_SIZE)
	match kind:
		Kind.ENTRANCE:
			MapRoomCell.draw_entrance(self, center, MapRoomCell.TEXT)
		Kind.CHEST_OPEN:
			MapRoomCell.draw_chest(self, center + Vector2(0, 2), MapRoomCell.GREY)
		Kind.TABLET:
			MapRoomCell.draw_tablet(self, center, MapRoomCell.NAME)
		Kind.PIN:
			MapRoomCell.draw_pin(self, center)
		Kind.DOOR_OPEN:
			draw_rect(door, MapRoomCell.DOOR)
		Kind.DOOR_LOCKED:
			draw_rect(door, MapRoomCell.GOLD)
			MapRoomCell.draw_lock(self, center, MapRoomCell.INK)
		Kind.DOOR_BOSS:
			draw_rect(door, MapRoomCell.BOSS)
		Kind.DOOR_SEALED:
			draw_rect(door, MapRoomCell.INK)
			draw_rect(door.grow(-1), MapRoomCell.SEALED, false, 2.0)
