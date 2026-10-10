@tool
extends Control
## Ícono de la leyenda del mapa: el mismo dibujo que usan las salas.

enum Kind { VISITED, MAPPED, HERE, CHEST, BOSS, FOG, ENTRANCE, CHEST_OPEN, TABLET, PIN }

@export var kind := Kind.VISITED:
	set(value):
		kind = value
		queue_redraw()
## Marco de sala para VISITED y MAPPED; se dibuja a media escala.
@export var style: StyleBox:
	set(value):
		style = value
		queue_redraw()


func _draw() -> void:
	match kind:
		Kind.VISITED, Kind.MAPPED:
			if style:
				draw_set_transform(Vector2(0, 4), 0.0, Vector2.ONE * 0.5)
				draw_style_box(style, Rect2(0, 0, 52, 40))
				draw_set_transform(Vector2.ZERO)
		Kind.HERE:
			MapRoomCell.draw_arrow(self, Vector2(13, 14), 0.0)
		Kind.CHEST:
			MapRoomCell.draw_chest(self, Vector2(13, 16), MapRoomCell.GOLD)
		Kind.BOSS:
			MapRoomCell.draw_eye(self, Vector2(13, 14))
		Kind.FOG:
			MapRoomCell.draw_fog(self, Rect2(0, 5, 26, 18))
		Kind.ENTRANCE:
			MapRoomCell.draw_entrance(self, Vector2(13, 14), MapRoomCell.TEXT)
		Kind.CHEST_OPEN:
			MapRoomCell.draw_chest(self, Vector2(13, 16), MapRoomCell.GREY)
		Kind.TABLET:
			MapRoomCell.draw_tablet(self, Vector2(13, 14), MapRoomCell.NAME)
		Kind.PIN:
			MapRoomCell.draw_pin(self, Vector2(13, 14))
