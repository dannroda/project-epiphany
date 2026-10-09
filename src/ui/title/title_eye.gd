extends Control
## El ojo del título y del game over, como en el mockup: un contorno ovalado, el iris y la pupila.

@export var outline := Color("#3a2a22")
@export var iris := Color("#4a1a13")
@export var iris_border := Color("#6e2a1e")
@export var pupil := Color("#0b0d10")
@export var iris_radius := 85.0
@export var pupil_radius := 29.0


func _draw() -> void:
	var center := size / 2.0
	var points := PackedVector2Array()
	for i in 73:
		var angle := TAU * i / 72.0
		points.append(center + Vector2(cos(angle) * size.x / 2.0, sin(angle) * size.y / 2.0))
	draw_polyline(points, outline, 2.0, true)
	draw_circle(center, iris_radius, iris)
	draw_arc(center, iris_radius, 0.0, TAU, 64, iris_border, 2.0, true)
	draw_circle(center, pupil_radius, pupil)
