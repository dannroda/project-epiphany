@tool
extends Control
## El ojo dorado de la pantalla de carga (mockup Loading); `open` lo parpadea el AnimationPlayer.

@export_range(0.0, 1.0) var open := 1.0:
	set(value):
		open = value
		queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var half := Vector2(size.x * 0.42, size.y * 0.27 * open)
	var outline := PackedVector2Array()
	for i in 25:
		var t := float(i) / 24.0
		outline.append(center + Vector2(lerpf(-half.x, half.x, t), -sin(t * PI) * half.y))
	for i in range(23, 0, -1):
		var t := float(i) / 24.0
		outline.append(center + Vector2(lerpf(-half.x, half.x, t), sin(t * PI) * half.y))
	outline.append(outline[0])
	draw_polyline(outline, MapRoomCell.GOLD, 1.8, true)
	if open > 0.3:
		draw_circle(center, size.x * 0.125, MapRoomCell.GOLD)
