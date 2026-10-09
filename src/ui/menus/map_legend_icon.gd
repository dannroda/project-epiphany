@tool
extends Control
## Ícono de la leyenda del mapa: el mismo dibujo que usan las salas.

enum Kind { VISITED, MAPPED, HERE, CHEST, BOSS }

@export var kind := Kind.VISITED:
	set(value):
		kind = value
		queue_redraw()


func _draw() -> void:
	match kind:
		Kind.VISITED:
			draw_style_box(get_theme_stylebox(&"legend", &"MapRoomCell"), Rect2(0, 5, 26, 18))
		Kind.MAPPED:
			MapRoomCell.draw_dashed_rect(self, Rect2(1, 6, 24, 16), MapRoomCell.BORDER)
		Kind.HERE:
			MapRoomCell.draw_arrow(self, Vector2(13, 14), 0.0)
		Kind.CHEST:
			MapRoomCell.draw_chest(self, Vector2(13, 16), MapRoomCell.GOLD)
		Kind.BOSS:
			MapRoomCell.draw_eye(self, Vector2(13, 14))
