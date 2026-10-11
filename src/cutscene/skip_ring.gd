class_name SkipRing
extends Control
## El aro que se llena mientras se mantiene saltar.

@export var track_color := Color("#3a3d46")
@export var fill_color := Color("#d9a441")
@export var width := 3.0

var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - width
	draw_arc(center, radius, 0.0, TAU, 32, track_color, width, true)
	if progress > 0.0:
		draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * progress, 32, fill_color, width, true)
