@tool
class_name MapCursor
extends Control
## Cursor del mapa: escuadras en las esquinas, alrededor de la sala (mazmorra) o de un punto con su centro (overworld).
## Se dibuja centrado.

const DOT := Color("#d9a441")

@export var frame_size := Vector2(136, 100):
	set(value):
		frame_size = value
		queue_redraw()
@export var frame_style: StyleBox
## Punto en el centro, para apuntar en el overworld.
@export var dot := false:
	set(value):
		dot = value
		queue_redraw()


## Mueve el cursor para que su centro quede en `point`.
func place(point: Vector2) -> void:
	position = point


func _draw() -> void:
	if frame_style:
		draw_style_box(frame_style, Rect2(-frame_size / 2.0, frame_size))
	if dot:
		draw_rect(Rect2(-3, -3, 6, 6), MapRoomCell.INK)
		draw_rect(Rect2(-2, -2, 4, 4), DOT)
